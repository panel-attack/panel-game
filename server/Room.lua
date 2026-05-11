local class = require("common.lib.class")
local logger = require("common.lib.logger")
local ServerProtocol = require("common.network.ServerProtocol")
local NetworkProtocol = require("common.network.NetworkProtocol")
---@module "common.data.GameModes"
local tableUtils = require("common.lib.tableUtils")
local ServerPlayer = require("server.Player")
local Signal = require("common.lib.signal")
local ServerGame = require("server.Game")
local GameModes = require("common.data.GameModes")
local TeamUtils = require("common.data.TeamUtils")

---@alias roomNumber integer

-- Object that represents a current session of play between two connections
-- Players alternate between the character select state and playing, and spectators can join and leave
---@class Room : Signal
---@field players ServerPlayer[]
---@field maxPlayers integer maximum players for this room's game mode
---@field leaderboard Leaderboard?
---@field name string
---@field roomNumber roomNumber
---@field stage string? stage for the game, randomly picked from both players
---@field spectators ServerPlayer[] array of spectator connection objects
---@field win_counts integer[] win counts by player number (mirrors team wins for team-game players)
---@field team_win_counts integer[]? wins indexed by team_index, only for team games
---@field ratings table[] ratings by player number
---@field matchCount integer
---@field game ServerGame?
---@field gameMode table -- only the data portion of the game mode
---@field gameModeId GameModeID
---@field ranked boolean if the next match is anticipated to be ranked
---@field rankedReasons string[]
---@field recentGameAbort boolean tracks if the most recent game was ended by an abort
---@field abortInputGapThreshold integer threshold for treating abort as latency error
---@field teams Team[]? teams for team-based game modes
---@field voided boolean if true, the room is "dead" — no new matches can start.
---  Set when any player leaves/disconnects in a multi-player room. Remaining players
---  keep the room visible until they manually leave; the Server cleans the room up
---  when the last player leaves.
---@field voidReason string? human-readable reason this room was voided (e.g. "Bev left")
---@overload fun(roomNumber: integer, players: ServerPlayer[], gameMode: GameMode, leaderboard: Leaderboard?): Room
local Room = class(
---@param self Room
---@param roomNumber integer
---@param players ServerPlayer[]
---@param gameMode table -- only the data portion of the game mode
---@param leaderboard Leaderboard?
function(self, roomNumber, players, gameMode, leaderboard)
  self.players = players
  self.leaderboard = leaderboard
  self.roomNumber = roomNumber
  self.gameMode = gameMode
  self.gameModeId = gameMode and (gameMode.gameModeId or gameMode.id or GameModes.nameToGameModeId[gameMode.name]) or nil
  self.maxPlayers = (gameMode and gameMode.playerCount) or #players
  self.name = table.concat(tableUtils.map(self.players, function(p) return p.name end), " vs ")
  self.spectators = {}
  self.win_counts = {}
  self.ratings = {}
  self.matchCount = 0
  self.ranked = false
  self.rankedReasons = {}
  self.recentGameAbort = false
  self.voided = false
  self.voidReason = nil
  self.abortInputGapThreshold = (gameMode and gameMode.abortInputGapThreshold) or ((self.maxPlayers >= 3) and 220 or 100)

  Signal.turnIntoEmitter(self)
  self:createSignal("playerJoined")
  self:createSignal("matchStart")
  self:createSignal("matchEnd")
  self:createSignal("pauseToggled")
  -- Emitted after a match ends (cleanly, by abort, or by forfeit) to signal that the
  -- room should be torn down so server and client state cannot diverge. Listened to by
  -- the Server (Server:create_room wires this to closeRoom).
  self:createSignal("roomShouldClose")

  -- Initialize all initially passed players the same way addPlayer does.
  for i, player in ipairs(self.players) do
    player:connectSignal("settingsUpdated", self, self.onPlayerSettingsUpdate)
    player:addToRoom(self)
    player.state = "character select"
    self.win_counts[i] = 0
    player.cursor = "__Ready"
    player.player_number = i
  end

  -- Only create teams once room is full; partial rooms should not have teams yet.
  self.teams = nil
  self.team_win_counts = nil
  if gameMode
      and #self.players >= self.maxPlayers
      and gameMode.teamCount
      and gameMode.playersPerTeam then
    self.teams = TeamUtils.createTeams(#self.players, gameMode.teamCount, gameMode.playersPerTeam)
    self.team_win_counts = {}
    for teamIndex = 1, #self.teams do
      self.team_win_counts[teamIndex] = 0
    end
  end


  if self.leaderboard then
    self.ranked, self.rankedReasons = self:rating_adjustment_approved()
  else
    self.ranked = false
    self.rankedReasons = {"Room has no leaderboard"}
  end

  return self
end
)

---@return boolean true if room has all required players
function Room:isFull()
  return #self.players >= self.maxPlayers
end

---@return integer[] list of open slot indices
function Room:getOpenSlots()
  local slots = {}
  for i = #self.players + 1, self.maxPlayers do
    slots[#slots + 1] = i
  end
  return slots
end

---@param player ServerPlayer
---@return boolean success
function Room:addPlayer(player)
  if self:isFull() then
    logger.warn("Cannot add player " .. player.name .. " to full room " .. self.roomNumber)
    return false
  end

  local playerIndex = #self.players + 1
  self.players[playerIndex] = player
  player:connectSignal("settingsUpdated", self, self.onPlayerSettingsUpdate)
  player:addToRoom(self)
  player.state = "character select"
  self.win_counts[playerIndex] = 0
  player.cursor = "__Ready"
  player.player_number = playerIndex

  -- Update room name
  self.name = table.concat(tableUtils.map(self.players, function(p) return p.name end), " vs ")

  -- Initialize teams when room becomes full
  if self:isFull() and self.gameMode.teamCount and self.gameMode.playersPerTeam and not self.teams then
    self.teams = TeamUtils.createTeams(#self.players, self.gameMode.teamCount, self.gameMode.playersPerTeam)
    self.team_win_counts = {}
    for teamIndex = 1, #self.teams do
      self.team_win_counts[teamIndex] = 0
    end
  end

  -- Notify everyone in room about the new player
  self:broadcastJson(ServerProtocol.playerJoinedRoom(self, player))
  self:emitSignal("playerJoined", player)

  logger.info("Player " .. player.name .. " joined room " .. self.roomNumber .. " as player " .. playerIndex)
  return true
end

function Room:onPlayerSettingsUpdate(player)
  if self:state() == "character select" then
    if self.leaderboard then
      if self.ranked or player.wants_ranked_match then
        logger.debug("about to check for rating_adjustment_approval for " .. player.name)
        local ranked_match_approved, reasons = self:rating_adjustment_approved()
        self:broadcastJson(ServerProtocol.updateRankedStatus(self.roomNumber, ranked_match_approved, reasons))
      end
    end

    -- Diagnostic: print every player's readiness flags after every settings update so we
    -- can see exactly which player is blocking the match-start handshake.
    local readyParts = {}
    for i, p in ipairs(self.players) do
      readyParts[i] = string.format("%s[wantsReady=%s loaded=%s ready=%s isReady=%s]",
        tostring(p.name), tostring(p.wantsReady), tostring(p.loaded), tostring(p.ready), tostring(ServerPlayer.isReady(p)))
    end
    logger.info("Room " .. self.roomNumber .. " readiness after " .. tostring(player.name) .. " update: " .. table.concat(readyParts, " "))

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
  if not self:isFull() then
    logger.warn("Cannot start match in room " .. self.roomNumber .. " - waiting for " .. (self.maxPlayers - #self.players) .. " more players")
    return false
  end

  if self.voided then
    logger.warn("Cannot start match in voided room " .. self.roomNumber .. " (" .. tostring(self.voidReason) .. ")")
    return false
  end

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
  self.recentGameAbort = false
end

function Room:prepare_character_select()
  logger.debug("Called Server.lua Room.character_select")
  for _, player in ipairs(self.players) do
    player.state = "character select"
    player.cursor = "__Ready"
    player.ready = false
  end
end

---@return PlayerState | "closed"
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
---@return boolean success
function Room:add_spectator(newSpectator)
  if not self:isFull() then
    logger.warn("Cannot add spectator " .. newSpectator.name .. " to room " .. self.roomNumber .. " - room not full yet")
    return false
  end

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
  return true
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
      spectator:removeFromRoom(self)
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
  if not self.game then
    if self.recentGameAbort then
      -- there is latency for one player to receive the abort so they'll keep sending their inputs for a bit, just ignore them
      return
    else
      pcall(function()
        logger.warn(self.roomNumber .. ": Unexpected input received from " .. sender.userId .. " " .. sender.name .. " in state " .. sender.state)
        logger.warn("Room Info: " .. self:toString())
      end)
      return
    end
  end

  -- Buffer the input instead of broadcasting immediately
  self.game:bufferInput(sender, input)
end

---Flush all complete frames and broadcast them to players
function Room:flushBufferedInputs()
  if not self.game or self.game.complete then
    return
  end
  
  -- Keep flushing frames as long as all players have submitted inputs for them
  while self.game:canFlushNextFrame() do
    local frameInputs = self.game:flushNextFrame()
    
    logger.trace("Room " .. self.roomNumber .. " flushing frame " .. self.game.currentFrameNumber .. " with inputs: " .. json.encode(frameInputs))
    
    -- Broadcast frame inputs to all players
    -- For each player, send their input with the appropriate prefix
    for playerNum, inputData in pairs(frameInputs) do
      local inputPrefix = NetworkProtocol.getInputPrefixForPlayer(playerNum)
          or NetworkProtocol.getInputPrefixForPlayer(1)
      local inputMessage = NetworkProtocol.markedMessageForTypeAndBody(inputPrefix, inputData)
      
      -- Send to all OTHER players
      for i, player in ipairs(self.players) do
        if i ~= playerNum then
          player:send(inputMessage)
        end
      end
      
      -- Send to spectators (same prefix - identifies the sender)
      for _, v in pairs(self.spectators) do
        if v then
          v:send(inputMessage)
        end
      end
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
  if self.teams then
    return false, {"Team games are not ranked"}
  end

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
  -- Team games: track per-team. Each player's per-player win_counts mirrors their team's
  -- count so old per-player UI ("P1: 2 wins") shows the team total instead of individual
  -- contribution, and so a player who joined late displays the team's accumulated wins
  -- rather than their personal subset.
  if self.teams and self.team_win_counts then
    if game.winnerTeamIndex then
      self.team_win_counts[game.winnerTeamIndex] = (self.team_win_counts[game.winnerTeamIndex] or 0) + 1
    end
    for i, player in ipairs(self.players) do
      local playerTeamIndex = TeamUtils.getPlayerTeamIndex(self.teams, player.player_number)
      self.win_counts[i] = playerTeamIndex and self.team_win_counts[playerTeamIndex] or self.win_counts[i] or 0
    end
  else
    -- Non-team game: only the individual winner gets credit.
    for i, player in ipairs(self.players) do
      if player.player_number == game.winnerIndex then
        logger.trace("Player " .. i .. " scored")
        self.win_counts[i] = self.win_counts[i] + 1
      end
    end
  end

  if not game.winnerId then
    logger.debug("tie.  Nobody scored")
  end
end

---@param sender ServerPlayer
function Room:handleGameAbort(sender)
  local isPlayerInRoom = tableUtils.trueForAny(self.players, function(p) return p.publicPlayerID == sender.publicPlayerID end)

  if #self.players == 1 and self.players[1] == sender then
    logger.debug(sender.name .. " aborted the game")
    self:abortGame(sender)
  elseif #self.players >= 2 and isPlayerInRoom then
    logger.info(sender.name .. " aborted the game")

    local inputCountDifference = self.game:getInputCountDifference()
    if inputCountDifference > self.abortInputGapThreshold then
      logger.info("abort was judged as legitimate with an inputCountDifference of " .. inputCountDifference)
      self:handlePlayerDisconnect(sender, "latency_error")
    else
      logger.info("abort was judged as illegitimate with an inputCountDifference of " .. inputCountDifference)

      -- Mark the aborter as eliminated so the server stops waiting on their inputs.
      -- Without this, canFlushNextFrame stalls until the connection watchdog fires
      -- (~60s) because the aborter has stopped sending inputs but isn't disconnected.
      -- markPlayerEliminated only sets eliminatedPlayers; it does not touch
      -- outcomeReports, so the constructed loss-outcome below still applies.
      if self.game then
        self.game:markPlayerEliminated(sender, sender.player_number)
      end

      -- Illegitimate aborts:
      -- - 2p: keep legacy behavior (aborting player loses, opponent wins)
      -- - Team game: report self-team loss (2)
      -- - 3+p FFA: report self-loss using own player_number (no hardcoded winner)
      local outcome
      if #self.players == 2 then
        outcome = (sender.player_number == 1) and 2 or 1
      elseif self.teams then
        outcome = 2
      else
        outcome = sender.player_number
      end

      self:handleGameOverOutcome({outcome = outcome}, sender)
    end
  else
    logger.warn(self.roomNumber .. ": Unexpected abort from player with publicID " .. sender.publicPlayerID)
  end
end

---@param sender ServerPlayer
---@param frame integer? frame when sender's stack died
function Room:handleStackEliminated(sender, frame)
  if self.game then
    self.game:markPlayerEliminated(sender, frame)
    logger.info(self.roomNumber .. ": " .. sender.name .. " eliminated at frame " .. tostring(frame))
  end
end

---@param sender ServerPlayer
---@param reason string?
function Room:handlePlayerDisconnect(sender, reason)
  if self.game then
    self.game:markPlayerDisconnected(sender)
  end

  if reason then
    logger.info(self.roomNumber .. ": treating disconnect from " .. sender.name .. " as a forfeit (" .. reason .. ")")
  else
    logger.info(self.roomNumber .. ": treating disconnect from " .. sender.name .. " as a forfeit")
  end

  -- If every player has now disconnected mid-game, no one will ever submit an outcome
  -- report, so handleGameOverOutcome won't fire and the room would become a zombie.
  -- Force-close in that case so server state cannot drift.
  if self.game then
    local allDisconnected = true
    for i = 1, #self.players do
      if not self.game.disconnectedPlayers[i] then
        allDisconnected = false
        break
      end
    end
    if allDisconnected then
      logger.info(self.roomNumber .. ": all players disconnected mid-game, closing room")
      self:emitSignal("roomShouldClose", self, "all players disconnected")
    end
  end
end

---Mark the room as void (no further matches can start) because a player left or
---disconnected. If a match is in progress, abort it for the remaining players. The
---leaver is removed from the room (the caller is responsible for sending them their
---own leaveRoom). Remaining players + spectators are notified via playerLeftRoom so
---their clients can show "X left" and disable Ready.
---@param leaver ServerPlayer the player who is leaving / disconnected
---@param reason string? human-readable reason (forwarded to remaining clients)
function Room:voidByLeave(leaver, reason)
  if self.voided then
    -- already void; just log and return so subsequent leaves don't fight each other
    logger.debug(self.roomNumber .. ": voidByLeave called on already-voided room")
  else
    self.voided = true
    self.voidReason = (leaver.name or "A player") .. " left" .. (reason and (" (" .. reason .. ")") or "")
    logger.info(self.roomNumber .. ": voiding room (" .. self.voidReason .. ")")
  end

  -- If a match is in progress, abort it for remaining players. broadcastJson
  -- excludes the leaver (they get their own leaveRoom from the caller path).
  if self.game then
    self:broadcastJson(ServerProtocol.sendGameAbort(leaver, reason or "player left"), leaver)
    self:emitSignal("matchEnd", self.game)
    self:prepare_character_select()
    self.game = nil
    self.recentGameAbort = true
  end

  -- Remove the leaver from the room. Compact the players array so the remaining
  -- player_numbers stay 1..N-1 and indexes match win_counts entries.
  local leaverIndex
  for i, p in ipairs(self.players) do
    if p == leaver then
      leaverIndex = i
      break
    end
  end
  if leaverIndex then
    table.remove(self.players, leaverIndex)
    table.remove(self.win_counts, leaverIndex)
    for i, p in ipairs(self.players) do
      p.player_number = i
    end
  end
  -- Teams are no longer valid for this room (player count changed) but team_win_counts
  -- stays so the per-team scoreboard still shows the matches that already happened.
  self.teams = nil

  -- Notify remaining players + spectators. Spectators get the same broadcast since
  -- their UI also needs to show "X left."
  self:broadcastJson(ServerProtocol.playerLeftRoom(self.roomNumber, leaver.publicPlayerID, leaver.name, self.voidReason))
end

---@param sender ServerPlayer
---@param reason string?
function Room:abortGame(sender, reason)
  self:broadcastJson(ServerProtocol.sendGameAbort(sender, reason), sender)
  self:emitSignal("matchEnd", self.game)
  self:prepare_character_select()
  self.game = nil
  self.recentGameAbort = true
end

function Room:togglePause(sender, paused)
  if #self.players == 1 and self.players[1] == sender and paused ~= (self:state() == "paused") then
    self:broadcastJson(ServerProtocol.sendPauseNotification(self.roomNumber, sender, paused), sender)
    self:emitSignal("pauseToggled")

    for i, player in ipairs(self.players) do
      if paused then
        player:setState("paused")
      else
        player:setState("playing")
      end
    end
  end
end

return Room