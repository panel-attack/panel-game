local class = require("common.lib.class")
local logger = require("common.lib.logger")
local ServerProtocol = require("common.network.ServerProtocol")
local NetworkProtocol = require("common.network.NetworkProtocol")
local GameModes = require("common.engine.GameModes")
-- heresy, remove once communication of levelData is established
local tableUtils = require("common.lib.tableUtils")
local ServerPlayer = require("server.Player")
local Signal = require("common.lib.signal")
local ServerGame = require("server.Game")

-- Object that represents a current session of play between two connections
-- Players alternate between the character select state and playing, and spectators can join and leave
---@class Room : Signal
---@field players ServerPlayer[]
---@field leaderboard Leaderboard?
---@field name string
---@field roomNumber integer
---@field stage string? stage for the game, randomly picked from both players
---@field spectators ServerPlayer[] array of spectator connection objects
---@field win_counts integer[] win counts by player number
---@field ratings table[] ratings by player number
---@field matchCount integer
---@field game ServerGame?
---@field gameMode GameMode
---@field ranked boolean if the next match is anticipated to be ranked 
---@field rankedReasons string[]
---@overload fun(roomNumber: integer, players: ServerPlayer[], gameMode: GameMode, leaderboard: Leaderboard?): Room
local Room = class(
---@param self Room
---@param roomNumber integer
---@param players ServerPlayer[]
---@param gameMode GameMode
---@param leaderboard Leaderboard?
function(self, roomNumber, players, gameMode, leaderboard)
  self.players = players
  self.leaderboard = leaderboard
  self.roomNumber = roomNumber
  self.name = table.concat(tableUtils.map(self.players, function(p) return p.name end), " vs ")
  self.spectators = {}
  self.win_counts = {}
  self.ratings = {}
  self.matchCount = 0
  self.gameMode = gameMode

  for i, player in ipairs(self.players) do
    player:connectSignal("settingsUpdated", self, self.onPlayerSettingsUpdate)
    player:addToRoom(self)
    self.win_counts[i] = 0
    if self.leaderboard then
      local rating = math.round(self.leaderboard:getRating(player) or 0)
      local placementProgress = self.leaderboard:getPlacementProgress(player)
      self.ratings[i] = {
        old = rating,
        new = rating,
        difference = 0,
        placement_match_progress = placementProgress
      }
      if placementProgress then
        self.ratings[i].league = self.leaderboard:get_league(0)
      else
        self.ratings[i].league = self.leaderboard:get_league(rating)
      end
    end
    player.cursor = "__Ready"
    player.player_number = i
  end

  -- don't want this dependency but current leaderboard updates rely on it so keep it until getting there
  for i, p1 in ipairs(self.players) do
    for j, p2 in ipairs(self.players) do
      if i ~= j then
        p1.opponent = p2
      end
    end
  end

  if self.leaderboard then
    self.ranked, self.rankedReasons = self:rating_adjustment_approved()
  else
    self.ranked = false
    self.rankedReasons = { "No leaderboard attached to the room" }
  end

  self:prepare_character_select()

  local message = ServerProtocol.createRoom(self)
  self:broadcastJson(message)

  Signal.turnIntoEmitter(self)
  self:createSignal("matchStart")
  self:createSignal("matchEnd")
end
)



function Room:onPlayerSettingsUpdate(player)
  if self:state() == "character select" then
    if self.leaderboard then
      if self.ranked or player.wants_ranked_match then
        logger.debug("about to check for rating_adjustment_approval for " .. player.name)
        local ranked_match_approved, reasons = self:rating_adjustment_approved()
        self:broadcastJson(ServerProtocol.updateRankedStatus(self.roomNumber, ranked_match_approved, reasons))
      end
    end

    if tableUtils.trueForAll(self.players, ServerPlayer.isReady) then
      self:start_match()
    else
      local settings = player:getSettings()
      local msg = ServerProtocol.settingsUpdate(player, settings)
      self:broadcastJson(msg, player)
    end
  end
end

function Room:start_match()
  self.matchCount = self.matchCount + 1
  logger.info("Starting match " .. self.matchCount .. " for " .. self.roomNumber .. " " .. self.name)

  for _, player in ipairs(self.players) do
    player.wantsReady = false
  end

  local stageIndex = math.random(1, #self.players)
  self.stageId = self.players[stageIndex].stage

  self.game = ServerGame.createFromRoomState(self)
  local replay = self.game:getPartialReplay(false)
  -- games generated via createFromRoomState always have a replay
  ---@cast replay -nil
  local message = ServerProtocol.startMatch(self.roomNumber, replay)
  self:broadcastJson(message)

  for i, player in ipairs(self.players) do
    player:setup_game()
  end

  for _, v in pairs(self.spectators) do
    v:setup_game()
  end

  self:emitSignal("matchStart")
end

function Room:prepare_character_select()
  logger.debug("Called Server.lua Room.character_select")
  for _, player in ipairs(self.players) do
    player.state = "character select"
    player.cursor = "__Ready"
    player.ready = false
  end
end

---@return "character select"|"lobby"|"not_logged_in"|"playing"|"spectating"|"closed"
function Room:state()
  if #self.players == 0 then
    return "closed"
  elseif self.players[1].state == "character select" then
    return "character select"
  elseif self.players[1].state == "playing" then
    return "playing"
  else
    return self.players[1].state
  end
end

---@param newSpectator ServerPlayer
function Room:add_spectator(newSpectator)
  newSpectator.state = "spectating"
  newSpectator:addToRoom(self)
  self.spectators[#self.spectators + 1] = newSpectator
  logger.debug(newSpectator.name .. " joined " .. self.name .. " as a spectator")

  local replay
  if self.game then
    replay = self.game:getPartialReplay(COMPRESS_REPLAYS_ENABLED)
  end

  local message = ServerProtocol.spectateRequestGranted(self, replay)

  newSpectator:sendJson(message)
  local spectatorList = self:spectator_names()
  logger.debug("sending spectator list: " .. json.encode(spectatorList))
  self:broadcastJson(ServerProtocol.updateSpectators(self.roomNumber, spectatorList))
end

---@return string[]
function Room:spectator_names()
  local list = {}
  for i, spectator in ipairs(self.spectators) do
    list[i] = spectator.name
  end
  return list
end

---@param spectator ServerPlayer
function Room:remove_spectator(spectator)
  local lobbyChanged = false
  for i, v in ipairs(self.spectators) do
    if v.name == spectator.name then
      self.spectators[i].state = "lobby"
      logger.debug(spectator.name .. " left " .. self.name .. " as a spectator")
      table.remove(self.spectators, i)
      spectator:removeFromRoom(self, spectator.name .. " left")
      lobbyChanged = true
      break
    end
  end

  if lobbyChanged then
    local spectatorList = self:spectator_names()
    logger.debug("sending spectator list: " .. json.encode(spectatorList))
    self:broadcastJson(ServerProtocol.updateSpectators(self.roomNumber, spectatorList))
  end

  return lobbyChanged
end

function Room:close(reason)
  logger.info("Closing room " .. self.roomNumber .. " " .. self.name)

  for i = #self.players, 1, -1 do
    local player = self.players[i]
    self.disconnectSignal(player, "settingsUpdated", self)
    player:removeFromRoom(self, reason)
    self.players[i] = nil
  end

  for i = #self.spectators, 1, -1 do
    local spectator = self.spectators[i]
    if spectator.room then
      spectator.state = "lobby"
      spectator:removeFromRoom(self, reason)
      self.spectators[i] = nil
    end
  end

  self.signalSubscriptions = nil
end

function Room:sendJsonToSpectators(message)
  for _, spectator in ipairs(self.spectators) do
    spectator:sendJson(message)
  end
end

---@param input string
---@param sender ServerPlayer
function Room:broadcastInput(input, sender)
  self.game:receiveInput(sender, input)

  local inputMessage = NetworkProtocol.markedMessageForTypeAndBody(NetworkProtocol.serverMessageTypes.opponentInput.prefix, input)
  if sender.opponent then
    sender.opponent:send(inputMessage)
  end

  if sender.player_number == 1 then
    inputMessage = NetworkProtocol.markedMessageForTypeAndBody(NetworkProtocol.serverMessageTypes.secondOpponentInput.prefix, input)
  end

  for _, v in pairs(self.spectators) do
    if v then
      v:send(inputMessage)
    end
  end
end

-- broadcasts the message to everyone in the room
-- if an optional sender is specified, they are excluded from the broadcast
function Room:broadcastJson(message, sender)
  for _, player in ipairs(self.players) do
    if player ~= sender then
      player:sendJson(message)
    end
  end

  self:sendJsonToSpectators(message)
end

---@return boolean # if the players may play ranked
---@return string[] reasons why or why not they may play ranked or what caveats apply to playing ranked
function Room:rating_adjustment_approved()
  if not self.leaderboard then
    return false, {"Room has no leaderboard"}
  end

  for _, player in ipairs(self.players) do
    if not player.wants_ranked_match then
      return false, {player.name .. " doesn't want ranked"}
    end
  end

  return self.leaderboard:rating_adjustment_approved(self.players)
end

---@return string
function Room:toString()
  local info = self.name
  info = info .. "\nRoom number:" .. self.roomNumber
  info = info .. "\nWin Counts" .. table_to_string(self.win_counts)
  for _, player in ipairs(self.players) do
    info = info .. "\n" .. player.name .. " settings:"
    info = info .. "\n" .. table_to_string(player:getSettings())
  end

  return info
end

---@param message table
---@param sender ServerPlayer
function Room:handleTaunt(message, sender)
  local msg = ServerProtocol.taunt(sender, message.type, message.index)
  self:broadcastJson(msg, sender)
end

---@param message { outcome: integer, [any]: any }
---@param sender ServerPlayer
function Room:handleGameOverOutcome(message, sender)
  logger.debug(self.roomNumber .. ": Received game result from " .. sender.name .. ": " .. message.outcome)
  self.game:receiveOutcomeReport(sender, message.outcome)

  if self.game.complete then
    self:updateWinCounts(self.game)
    logger.info(self.roomNumber .. " " .. self.name .. " match " .. self.matchCount .. " ended with winner " .. (self.game.winnerIndex or ""))
    self:emitSignal("matchEnd", self.game)

    if self.game.ranked and self.game.winnerId then
      local ratingUpdates = self.leaderboard:processGameResult(self.game)
      for i, _ in ipairs(self.players) do
        ratingUpdates[i].userId = nil
      end
      self.ratings = ratingUpdates
    end

    logger.debug("*******************************")
    for i, player in ipairs(self.players) do
      logger.debug("***" .. player.name .. " " .. self.win_counts[i] .. "***")
    end
    logger.debug("*******************************\n")

    self:prepare_character_select()
    self:broadcastJson(
      ServerProtocol.gameResult(
        self.game,
        self
      )
    )
    self.game = nil
  end
end

---@param game ServerGame
function Room:updateWinCounts(game)
  for i, player in ipairs(self.players) do
    logger.debug("checking if player " .. i .. " scored...")
    if player.player_number == game.winnerIndex then
      logger.trace("Player " .. i .. " scored")
      self.win_counts[i] = self.win_counts[i] + 1
    end
  end
  if not game.winnerId then
    logger.debug("tie.  Nobody scored")
  end
end

function Room:handleGameAbort(sender)
  if #self.players == 1 and self.players[1] == sender then
    logger.debug(sender.name .. " aborted the game")
    self:abortGame(sender)
  elseif #self.players == 2 and tableUtils.contains(self.players, sender) then
    -- aborts in multiplayer room are a bigger deal so we should log them as info
    logger.info(sender.name .. " aborted the game")

    -- there is obviously some abuse potential here, e.g. by sending aborts instead of a game result
    -- the room should only accept the abort if there is a significant difference in inputs on Game, suggesting the abort is legitimate
    local inputCountDifference = self.game:getInputCountDifference()
    if inputCountDifference > 100 then
      logger.info("abort was judged as legitimate with an inputCountDifference of " .. inputCountDifference)
      self:abortGame(sender)
    else
      logger.info("abort was judged as illegitimate with an inputCountDifference of " .. inputCountDifference)
      -- if that is not the case, we're in a bit of a pickle as the sender already stopped the match client side
      --  but there is no indication for the abort actually being legitimate
      -- I don't think there is a truly fair way to resolve that situation as the assumption of manipulation makes it impossible to make a correct decision
      --  as long as clients are given the "power" to abort (and realistically they can always do that just by Alt+F4)
      -- ; up to now closing the room was the effective outcome either way
      -- even running a simulation of the game to the end to see if there was a winner would not resolve it as clients could be modified to not send an input that leads to a game over

      -- I think the fair thing is to assume that the client reported a loss in that scenario
      -- if both clients end up sending an abort that is denied by above criteria they'll both report a loss
      -- this leads to the outcome resolving as a tie which is fair as long as ties are discarded for the ladder (currently they are)
      -- that would be a scenario in which the above condition was simply not enough to validate the abort
      local outcome
      if sender.player_number == 1 then
        outcome = 2
      else
        outcome = 1
      end
      self:handleGameOverOutcome({outcome = outcome}, sender)

      -- it could naturally still happen that one player aborts and the other reports a win leading to a win instead of a tie
      -- while clients could be manipulated to just report a win instead of an abort in this scenario,
      --  the general occurence of the situation should be rare enough that consequences of abuse in this manner should be minimal
      --  as the abuser does only have control over their own connection to the server
    end
  end

end

function Room:abortGame(sender)
  self:broadcastJson(ServerProtocol.sendGameAbort(sender), sender)
  self:emitSignal("matchEnd", self.game)
  self:prepare_character_select()
  self.game = nil
end

return Room