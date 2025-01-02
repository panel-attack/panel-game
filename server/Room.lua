local class = require("common.lib.class")
local logger = require("common.lib.logger")
local Replay = require("common.data.Replay")
local ReplayPlayer = require("common.data.ReplayPlayer")
local ServerProtocol = require("common.network.ServerProtocol")
local NetworkProtocol = require("common.network.NetworkProtocol")
local GameModes = require("common.engine.GameModes")
-- heresy, remove once communication of levelData is established
local LevelPresets = require("common.data.LevelPresets")
local tableUtils = require("common.lib.tableUtils")
local ServerPlayer = require("server.Player")
local Signal = require("common.lib.signal")

local sep = package.config:sub(1, 1) --determines os directory separator (i.e. "/" or "\")

-- Object that represents a current session of play between two connections
-- Players alternate between the character select state and playing, and spectators can join and leave
---@class Room : Signal
---@field players ServerPlayer[]
---@field database ServerDB
---@field leaderboard Leaderboard?
---@field name string
---@field roomNumber integer
---@field stage string? stage for the game, randomly picked from both players
---@field spectators ServerPlayer[] array of spectator connection objects
---@field win_counts integer[] win counts by player number
---@field ratings table[] ratings by player number
---@field game_outcome_reports integer[] game outcome reports by player number; transient, is cleared inbetween games
---@field matchCount integer
---@field replay Replay?
---@overload fun(roomNumber: integer, players: ServerPlayer[], database: ServerDB, leaderboard: Leaderboard?): Room
local Room = class(
---@param self Room
---@param roomNumber integer
---@param players ServerPlayer[]
---@param database ServerDB
---@param leaderboard Leaderboard?
function(self, roomNumber, players, database, leaderboard)
  self.players = players
  self.database = database
  self.leaderboard = leaderboard
  self.roomNumber = roomNumber
  self.name = table.concat(tableUtils.map(self.players, function(p) return p.name end), " vs ")
  self.spectators = {}
  self.win_counts = {}
  self.ratings = {}
  self.matchCount = 0

  for i, player in ipairs(self.players) do
    player:connectSignal("settingsUpdated", self, self.onPlayerSettingsUpdate)
    player:setRoom(self)
    self.win_counts[i] = 0
    if self.leaderboard then
      local rating = self.leaderboard:getRating(player) or 0
      local placementProgress = self.leaderboard:getPlacementProgress(player)
      self.ratings[i] = {old = rating, new = rating, difference = 0, league = self.leaderboard:get_league(rating), placement_match_progress = placementProgress}
    end
    player.cursor = "__Ready"
    player.player_number = i
  end

  self.game_outcome_reports = {}

  -- don't want this dependency but current leaderboard updates rely on it so keep it until getting there
  for i, p1 in ipairs(self.players) do
    for j, p2 in ipairs(self.players) do
      if i ~= j then
        p1.opponent = p2
      end
    end
  end

  self:prepare_character_select()

  self:sendRoomCreationMessage()

  Signal.turnIntoEmitter(self)
  self:createSignal("matchStart")
  self:createSignal("matchEnd")
end
)

function Room:sendRoomCreationMessage()
  local messageForA = ServerProtocol.createRoom(
    self.roomNumber,
    self.players[1]:getSettings(),
    self.players[2]:getSettings(),
    self.ratings[1],
    self.ratings[2],
    self.players[2].name,
    2
  )
  self.players[1]:sendJson(messageForA)

  local messageForB = ServerProtocol.createRoom(
    self.roomNumber,
    self.players[1]:getSettings(),
    self.players[2]:getSettings(),
    self.ratings[1],
    self.ratings[2],
    self.players[1].name,
    1
  )
  self.players[2]:sendJson(messageForB)
end

function Room:onPlayerSettingsUpdate(player)
  if self:state() == "character select" then
    logger.debug("about to check for rating_adjustment_approval for " .. player.name .. " and " .. player.name)
    if tableUtils.trueForAll(self.players, "wants_ranked_match") then
      local ranked_match_approved, reasons = self:rating_adjustment_approved()
      self:broadcastJson(ServerProtocol.updateRankedStatus(ranked_match_approved, reasons))
    end

    if tableUtils.trueForAll(self.players, ServerPlayer.isReady) then
      self:start_match()
    else
      local settings = player:getSettings()
      local msg = ServerProtocol.menuState(settings, tableUtils.indexOf(self.players, player))
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

  self.replay = Replay(ENGINE_VERSION, math.random(1,9999999), GameModes.getPreset("TWO_PLAYER_VS"))
  self.replay:setStage(self.stageId)

  self.inputs = {}
  for i, player in ipairs(self.players) do
    self.inputs[i] = {}
    local replayPlayer = ReplayPlayer(player.name, player.publicPlayerID, true)
    replayPlayer:setWins(self.win_counts[i])
    replayPlayer:setCharacterId(player.character)
    replayPlayer:setPanelId(player.panels_dir)
    if player.levelData then
      replayPlayer:setLevelData(player.levelData)
    else
      replayPlayer:setLevelData(LevelPresets.getModern(player.level))
    end
    replayPlayer:setInputMethod(player.inputMethod)
    -- TODO: pack the adjacent color setting with level data or send it with player settings
    -- this is not something for the server to decide, it should just take what it gets
    if self.replay.gameMode.StackInteractions == GameModes.StackInteractions.NONE then
      replayPlayer:setAllowAdjacentColors(true)
    else
      replayPlayer:setAllowAdjacentColors(player.level < 8)
    end
    -- this is a display-only prop, the true info is stored in levelData
    replayPlayer:setLevel(player.level)

    self.replay:updatePlayer(i, replayPlayer)
  end

  local roomIsRanked, reasons = self:rating_adjustment_approved()

  self.replay:setRanked(roomIsRanked)

  for i, recipient in ipairs(self.players) do
    for j, player in ipairs(self.players) do
      if i ~= j then
        local message = ServerProtocol.startMatch(
          self.replay.seed,
          self.replay.ranked,
          self.replay.stageId,
          recipient:getDumbSettings((self.leaderboard and self.ratings[i].new or 0), i),
          player:getDumbSettings((self.leaderboard and self.ratings[j].new or 0), j)
        )
        recipient:sendJson(message)
        if i == 1 then
          self:sendJsonToSpectators(message)
        end
      end
    end
  end

  for i, player in ipairs(self.players) do
    player:setup_game()
  end

  for _, v in pairs(self.spectators) do
    v:setup_game()
  end

  self:emitSignal("matchStart")
end

function Room:character_select()
  self:prepare_character_select()
  self:broadcastJson(
    ServerProtocol.characterSelect(
      self.ratings[1],
      self.ratings[2],
      self.players[1]:getSettings(),
      self.players[2]:getSettings()
    )
  )
end

function Room:prepare_character_select()
  logger.debug("Called Server.lua Room.character_select")
  for i, player in ipairs(self.players) do
    player.state = "character select"
    player.cursor = "__Ready"
    player.ready = false
  end
end

---@return "character select"|"lobby"|"not_logged_in"|"playing"|"spectating"
function Room:state()
  if self.players[1].state == "character select" then
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
  newSpectator:setRoom(self)
  self.spectators[#self.spectators + 1] = newSpectator
  logger.debug(newSpectator.name .. " joined " .. self.name .. " as a spectator")

  if self.replay then
    for i, player in ipairs(self.replay.players) do
      player.settings.inputs = table.concat(self.inputs[i])
      if COMPRESS_REPLAYS_ENABLED then
        player.settings.inputs = ReplayPlayer.compressInputString(player.settings.inputs)
      end
    end
  end

  local message = ServerProtocol.spectateRequestGranted(
    self.roomNumber,
    self.players[1]:getSettings(),
    self.players[2]:getSettings(),
    self.ratings[1],
    self.ratings[2],
    self.players[1].name,
    self.players[2].name,
    self.win_counts,
    self.stage,
    self.replay,
    self.replay and self.replay.ranked or nil,
    self.players[1]:getDumbSettings((self.leaderboard and self.ratings[1].new or 0), 1),
    self.players[2]:getDumbSettings((self.leaderboard and self.ratings[2].new or 0), 2)
  )

  newSpectator:sendJson(message)
  local spectatorList = self:spectator_names()
  logger.debug("sending spectator list: " .. json.encode(spectatorList))
  self:broadcastJson(ServerProtocol.updateSpectators(spectatorList))
end

function Room:spectator_names()
  local list = {}
  for i, spectator in ipairs(self.spectators) do
    list[#list + 1] = spectator.name
  end
  return list
end

function Room:remove_spectator(spectator)
  local lobbyChanged = false
  for i, v in ipairs(self.spectators) do
    if v.name == spectator.name then
      self.spectators[i].state = "lobby"
      logger.debug(spectator.name .. " left " .. self.name .. " as a spectator")
      table.remove(self.spectators, i)
      spectator:setRoom()
      lobbyChanged = true
      break
    end
  end
  local spectatorList = self:spectator_names()
  logger.debug("sending spectator list: " .. json.encode(spectatorList))
  self:broadcastJson(ServerProtocol.updateSpectators(spectatorList))
  return lobbyChanged
end

function Room:close()
  logger.info("Closing room " .. self.roomNumber .. " " .. self.name)

  for i = #self.players, 1, -1 do
    local player = self.players[i]
    player:setRoom()
    self.players[i] = nil
  end

  for i = #self.spectators, 1, -1 do
    local spectator = self.spectators[i]
    if spectator.room then
      spectator.state = "lobby"
      spectator:setRoom()
    end
  end

  self.signalSubscriptions = nil
  self.spectators = nil
end

function Room:sendJsonToSpectators(message)
  for i, spectator in ipairs(self.spectators) do
    if spectator then
      spectator:sendJson(message)
    end
  end
end

---@param input string
---@param sender ServerPlayer
function Room:broadcastInput(input, sender)
  self.inputs[sender.player_number][#self.inputs[sender.player_number] + 1] = input

  local inputMessage = NetworkProtocol.markedMessageForTypeAndBody(NetworkProtocol.serverMessageTypes.opponentInput.prefix, input)
  sender.opponent:send(inputMessage)

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
  for i, player in ipairs(self.players) do
    if player ~= sender then
      player:sendJson(message)
    end
  end

  self:sendJsonToSpectators(message)
end

---@param player ServerPlayer
---@param outcome integer
function Room:reportOutcome(player, outcome)
  self.game_outcome_reports[player.player_number] = outcome
  if self:resolve_game_outcome() then
    logger.debug("\n*******************************")
    logger.debug("***" .. self.players[1].name .. " " .. self.win_counts[1] .. " - " .. self.win_counts[2] .. " " .. self.players[2].name .. "***")
    logger.debug("*******************************\n")
    self.game_outcome_reports = {}
    self:character_select()
  end
end

---@return boolean # whether the outcome could be resolved
function Room:resolve_game_outcome()
  for i, _ in ipairs(self.players) do
    if not self.game_outcome_reports[i] then
      return false
    end
  end

  -- outcome is the player number of the winner, or 0 for a tie
  local outcome = nil
  for i, outcomeA in ipairs(self.game_outcome_reports) do
    for j, outcomeB in ipairs(self.game_outcome_reports) do
      if i ~= j then
        if outcomeA ~= outcomeB then
          --if clients disagree, the server needs to decide the outcome, perhaps by watching a replay it had created during the game.
          --for now though...
          logger.warn("clients " .. self.players[1].name .. " and " .. self.players[2].name .. " disagree on their game outcome. So the server will declare a tie.")
          outcome = 0
          break
        end
      end
    end
  end

  if not outcome then
    -- everyone agrees on the outcome
    outcome = self.game_outcome_reports[1]
  end
  local gameID = self.database:insertGame(self.replay.ranked)
  self.replay.gameId = gameID

  if outcome ~= 0 then
    self.replay.winnerIndex = outcome
    self.replay.winnerId = self.replay.players[outcome].publicId
    for i, player in ipairs(self.players) do
      local level = not player:usesModifiedLevelData() and player.level or nil
      self.database:insertPlayerGameResult(player.userId, gameID, level, (player.player_number == outcome) and 1 or 2)
    end
  else
    for i, player in ipairs(self.players) do
      local level = not player:usesModifiedLevelData() and player.level or nil
      self.database:insertPlayerGameResult(player.userId, gameID, level, 0)
    end
  end

  logger.info(self.roomNumber .. " " .. self.name .. " match " .. self.matchCount .. " ended with outcome " .. outcome)

  self:finalizeReplay()
  self:saveReplay()
  self.replay = nil

  --check that it's ok to adjust ratings
  local shouldAdjustRatings, reasons = self:rating_adjustment_approved()

  -- record the game result for statistics, record keeping, and testing new features
  local resultValue = 0.5
  if self.players[1].player_number == outcome then
    resultValue = 1
  elseif self.players[2].player_number == outcome then
    resultValue = 0
  end
  local rankedValue = 0
  if shouldAdjustRatings then
    rankedValue = 1
  end
  FileIO.logGameResult(self.players[1].userId, self.players[2].userId, resultValue, rankedValue)

  if outcome == 0 then
    logger.debug("tie.  Nobody scored")
    --do nothing. no points or rating adjustments for ties.
    self:emitSignal("matchEnd")
    return true
  else
    local someone_scored = false

    for i = 1, #self.players do
      logger.debug("checking if player " .. i .. " scored...")
      if outcome == i then
        logger.trace("Player " .. i .. " scored")
        self.win_counts[i] = self.win_counts[i] + 1
        if shouldAdjustRatings then
          -- if the DB insert fails gameID is nil so maybe we should take a different branch then
          self.leaderboard:adjust_ratings(self, i, gameID)
        else
          logger.debug("Not adjusting ratings because: " .. reasons[1])
        end
        someone_scored = true
      end
    end

    if someone_scored then
      local message = ServerProtocol.winCounts(self.win_counts[1], self.win_counts[2])
      self:broadcastJson(message)
    end
    self:emitSignal("matchEnd")
    return true
  end
end

function Room:finalizeReplay()
  for i, player in ipairs(self.replay.players) do
    player.settings.inputs = table.concat(self.inputs[i])
    if COMPRESS_REPLAYS_ENABLED then
      player.settings.inputs = ReplayPlayer.compressInputString(player.settings.inputs)
    end
  end

  for i, player in ipairs(self.players) do
    if player.save_replays_publicly == "anonymously" then
      self.replay.players[i].name = "anonymous"
      if self.replay.players[i].publicId == self.replay.winnerId then
        self.replay.winnerId = - i
      end
      self.replay.players[i].publicId = - i
    end
  end
end

function Room:saveReplay()
  for i, player in ipairs(self.players) do
    if player.save_replays_publicly == "not at all" then
      logger.debug("replay not saved because a player didn't want it saved")
      return
    end
  end

  local path = "ftp" .. sep .. self.replay:generatePath(sep)
  local filename = self.replay:generateFileName() .. ".json"

  logger.debug("saving replay as " .. path .. sep .. filename)
  FileIO.write_replay_file(self.replay, path, filename)
end

---@return boolean # if the players may play ranked
---@return string[] reasons why or why not they may play ranked or what caveats apply to playing ranked
function Room:rating_adjustment_approved()
  if not self.leaderboard then
    return false, {"Room has no leaderboard"}
  end

  for i, player in ipairs(self.players) do
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
  for i, player in ipairs(self.players) do
    info = info .. "\n" .. player.name .. " settings:"
    info = info .. "\n" .. table_to_string(player:getSettings())
  end

  return info
end

---@param message table
---@param sender ServerPlayer
function Room:handleTaunt(message, sender)
  local msg = ServerProtocol.taunt(sender.player_number, message.type, message.index)
  self:broadcastJson(msg, sender)
end

---@param message table
---@param sender ServerPlayer
function Room:handleGameOverOutcome(message, sender)
  self:reportOutcome(sender, message.outcome)
end

return Room