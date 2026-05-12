local class = require("common.lib.class")
local logger = require("common.lib.logger")
local socket = require("common.lib.socket")
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
  -- Dynamic-roster modes (e.g. open_ffa) carry minPlayers/maxPlayers on the preset.
  -- Fixed-roster modes use playerCount for both bounds.
  self.minPlayers = (gameMode and gameMode.minPlayers) or (gameMode and gameMode.playerCount) or #players
  self.maxPlayers = (gameMode and gameMode.maxPlayers) or (gameMode and gameMode.playerCount) or #players
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
  self.reservedSlots = {} -- publicId -> true for players allowed to rejoin
  -- Spectators who joined mid-match wanting to become players when the next
  -- match starts. Insertion-ordered for first-come-first-served promotion up
  -- to maxPlayers. Used by open FFA (dynamic-roster) modes only.
  self.pendingJoiners = {}

  -- Loose-sync KO arbitration state — populated by broadcastDeathEvent, drained
  -- by tickArbitration when the 200ms window closes.
  self.arbitrationDeaths = {}
  self.arbitrationWindowEndsAtMs = nil
  self.arbitrationEmitted = false

  Signal.turnIntoEmitter(self)
  self:createSignal("playerJoined")
  self:createSignal("matchStart")
  self:createSignal("matchEnd")
  self:createSignal("pauseToggled")
  -- Emitted after a match ends (cleanly, by abort, or by forfeit) to signal that the
  -- room should be torn down so server and client state cannot diverge. Listened to by
  -- the Server (Server:create_room wires this to closeRoom).
  self:createSignal("roomShouldClose")
  -- Emitted when prepare_character_select runs with queued mid-match joiners.
  -- Server listens and drains the queue via handleJoinRoom.
  self:createSignal("readyForPendingJoiners")

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

    if #self.players >= self.minPlayers and tableUtils.trueForAll(self.players, ServerPlayer.isReady) then
      self:start_match()
    else
      local settings = player:getSettings()
      local msg = ServerProtocol.settingsUpdate(player, settings)
      self:broadcastJson(msg, player)
    end
  end
end

function Room:start_match()
  if #self.players < self.minPlayers then
    logger.warn("Cannot start match in room " .. self.roomNumber .. " - waiting for " .. (self.minPlayers - #self.players) .. " more players (min " .. self.minPlayers .. ")")
    return false
  end

  if self.voided then
    logger.warn("Cannot start match in voided room " .. self.roomNumber .. " (" .. tostring(self.voidReason) .. ")")
    return false
  end

  self.matchCount = self.matchCount + 1
  logger.info("Starting match " .. self.matchCount .. " for " .. self.roomNumber .. " " .. self.name)

  -- Dynamic-roster modes resolve their final playerCount/teamCount at match start
  -- from the actual roster (e.g. open_ffa with 3 of 5 slots filled → 3-player FFA).
  if self.gameMode and not self.gameMode.playerCount then
    self.gameMode.playerCount = #self.players
    self.gameMode.teamCount = self.gameMode.teamCount or #self.players
  end
  -- Recompute teams every match so drop-ins / drop-outs are reflected.
  if self.gameMode and self.gameMode.teamCount and self.gameMode.playersPerTeam then
    self.teams = TeamUtils.createTeams(#self.players, self.gameMode.teamCount, self.gameMode.playersPerTeam)
    self.team_win_counts = self.team_win_counts or {}
    for teamIndex = 1, #self.teams do
      self.team_win_counts[teamIndex] = self.team_win_counts[teamIndex] or 0
    end
  end

  for _, player in ipairs(self.players) do
    player.wantsReady = false
  end

  local stageIndex = math.random(1, #self.players)
  self.stageId = self.players[stageIndex].stage

  self.game = ServerGame.createFromRoomState(self)
  -- Reset KO arbitration state for the new match.
  self.arbitrationDeaths = {}
  self.arbitrationWindowEndsAtMs = nil
  self.arbitrationEmitted = false
  -- Reset diagnostic flags so dropped-input warnings can fire once per slot per match.
  self._loggedInputDropDisconnect = nil
  self._loggedInputDropEliminated = nil

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

  -- Open FFA: mid-match joiners who queued up while a match was running get
  -- joined now that character select reopens. The server is the only thing
  -- that owns handleJoinRoom semantics, so emit and let it drain the queue.
  if self.pendingJoiners and #self.pendingJoiners > 0 then
    self:emitSignal("readyForPendingJoiners")
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
---@param pendingPromote boolean? if true, queue this spectator for promotion to
---  player at the next match end (open FFA mid-match join flow).
---@return boolean success
function Room:add_spectator(newSpectator, pendingPromote)
  -- Pending-promote (drop-in to become a player) requires a live match.
  -- Pure spectators can join any room that exists (character select or playing).
  local hasLiveMatch = self.game ~= nil
  if pendingPromote and not hasLiveMatch then
    logger.warn("Cannot queue " .. newSpectator.name .. " as pending player in room " .. self.roomNumber .. " - no live match")
    return false
  end

  newSpectator.state = "spectating"
  newSpectator:addToRoom(self)
  self.spectators[#self.spectators + 1] = newSpectator
  logger.debug(newSpectator.name .. " joined " .. self.name .. " as a spectator")

  if pendingPromote then
    self.pendingJoiners[#self.pendingJoiners + 1] = { player = newSpectator }
    logger.info(newSpectator.name .. " queued as pending player for room " .. self.roomNumber)
  end

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

-- True for an open_ffa-style mode where the roster is bounded by min/max
-- rather than a fixed playerCount; mid-match joiners go into pendingJoiners
-- and get promoted at prepare_character_select.
function Room:isDynamicRoster()
  return self.gameMode ~= nil and self.gameMode.minPlayers ~= nil
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

  -- Drop them from the pending-promote queue too, if they were waiting.
  for i = #self.pendingJoiners, 1, -1 do
    if self.pendingJoiners[i].player == spectator then
      table.remove(self.pendingJoiners, i)
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

  local senderNum = sender.player_number
  -- Loose-sync: skip inputs from eliminated/disconnected slots so they don't pollute the replay log.
  if self.game.disconnectedPlayers[senderNum] then
    -- Log the FIRST dropped input per disconnect so we can diagnose "P2 sees their own game
    -- but P1 never sees P2's moves" without spamming for every dropped frame.
    if not self._loggedInputDropDisconnect then
      self._loggedInputDropDisconnect = {}
    end
    if not self._loggedInputDropDisconnect[senderNum] then
      self._loggedInputDropDisconnect[senderNum] = true
      logger.warn(string.format(
        "%d: dropping input from %s (slot %d) — player is marked disconnected server-side",
        self.roomNumber, sender.name, senderNum))
    end
    return
  end
  if self.game.eliminatedPlayers[senderNum] then
    if not self._loggedInputDropEliminated then
      self._loggedInputDropEliminated = {}
    end
    if not self._loggedInputDropEliminated[senderNum] then
      self._loggedInputDropEliminated[senderNum] = true
      logger.warn(string.format(
        "%d: dropping input from %s (slot %d) — player is marked eliminated at frame %s",
        self.roomNumber, sender.name, senderNum,
        tostring(self.game.eliminatedPlayers[senderNum])))
    end
    return
  end

  -- Record for replay
  self.game:receiveInput(sender, input)

  -- Relay immediately to every other player + every spectator, tagged with the sender's slot prefix.
  local inputPrefix = NetworkProtocol.getInputPrefixForPlayer(senderNum)
      or NetworkProtocol.getInputPrefixForPlayer(1)
  local inputMessage = NetworkProtocol.markedMessageForTypeAndBody(inputPrefix, input)

  for i, player in ipairs(self.players) do
    if i ~= senderNum then
      player:send(inputMessage)
    end
  end

  for _, v in pairs(self.spectators) do
    if v then
      v:send(inputMessage)
    end
  end
end

---Walk forward through the sender's enemy team list to find a recipient that
---hasn't been eliminated. Returns nil if every member of the sender's enemy
---team is dead (the team is done; the garbage can be dropped on the floor).
---@param senderSlot integer
---@param originalRecipient integer the slot the client picked, may be dead
---@return integer? alive recipient slot, or nil if none
function Room:_redirectIfDead(senderSlot, originalRecipient)
  if not self.game then return nil end
  if not self.game.eliminatedPlayers[originalRecipient] then
    return originalRecipient
  end

  -- Original recipient is dead; walk forward looking for any living enemy.
  -- For FFA / no-teams, every-non-sender is an enemy. For teams, only the
  -- sender's enemy team members.
  local enemySlots
  if self.teams then
    enemySlots = TeamUtils.getEnemyPlayerIndices(self.teams, senderSlot)
  else
    enemySlots = {}
    for i = 1, #self.players do
      if i ~= senderSlot then
        enemySlots[#enemySlots + 1] = i
      end
    end
  end

  if #enemySlots == 0 then return nil end

  -- Find the original recipient's position in the enemy list, walk forward
  -- (with wrap) to find the next living. Walking from the original position
  -- (rather than from slot 1) is deterministic and matches the round-robin
  -- semantic — "if my pick is dead, give it to the next-living after them."
  local startIdx = 1
  for i, slot in ipairs(enemySlots) do
    if slot == originalRecipient then
      startIdx = i
      break
    end
  end

  for offset = 1, #enemySlots do
    local idx = ((startIdx - 1 + offset) % #enemySlots) + 1
    local candidate = enemySlots[idx]
    if not self.game.eliminatedPlayers[candidate] then
      return candidate
    end
  end

  return nil
end

---Relay a loose-sync GarbageEvent. Body is JSON sent from the client; we
---stamp serverWallClockMs, record it on the game for the replay log,
---redirect dead recipients to the next-living enemy (round-robin walk-
---forward), then forward to EVERY player (including the sender, so their
---view-of-the-target only renders the drop after the server confirms) and
---to all spectators.
---@param sender ServerPlayer
---@param body string raw JSON body from the client
function Room:broadcastGarbageEvent(sender, body)
  if not self.game or self.game.complete then
    return
  end

  local ok, parsed = pcall(json.decode, body)
  if not ok or type(parsed) ~= "table" then
    logger.warn(self.roomNumber .. ": malformed GarbageEvent from " .. (sender.name or sender.userId or "?"))
    return
  end

  parsed.sender = sender.player_number
  parsed.serverWallClockMs = math.floor(socket.gettime() * 1000)

  -- Authoritative dead-target redirect. Clients don't see the death
  -- before they emit, so we fix it server-side. If nobody alive remains in
  -- the sender's enemy pool, drop the event (the match will end shortly
  -- via the natural game-end check).
  if type(parsed.recipients) == "table" then
    local redirected = {}
    for _, originalRecipient in ipairs(parsed.recipients) do
      local actual = self:_redirectIfDead(sender.player_number, originalRecipient)
      if actual then
        redirected[#redirected + 1] = actual
        if actual ~= originalRecipient then
          logger.info(string.format(
            "%d: G from %s: recipient %d eliminated; redirected to %d",
            self.roomNumber, sender.name or "?", originalRecipient, actual))
        end
      end
    end
    parsed.recipients = redirected
    if #redirected == 0 then
      logger.info(string.format(
        "%d: G from %s: no living recipients, dropping",
        self.roomNumber, sender.name or "?"))
      return
    end
  end

  self.game:recordGarbageEvent(sender, parsed)

  do
    local rstr = {}
    for _, r in ipairs(parsed.recipients) do rstr[#rstr + 1] = tostring(r) end
    logger.info(string.format(
      "%d: G relay: sender=%d recipients=[%s] garbageCount=%d",
      self.roomNumber, sender.player_number,
      table.concat(rstr, ","),
      (type(parsed.garbage) == "table") and #parsed.garbage or 0))
  end

  local stamped = json.encode(parsed)
  local message = NetworkProtocol.markedMessageForTypeAndBody(
    NetworkProtocol.serverMessageTypes.garbageEvent.prefix, stamped)

  -- Send to EVERY player (including sender) and every spectator. The sender
  -- needs the relay back to drive the visual on their view-stack of the
  -- recipient. This is the only path that produces the visual, so nobody
  -- sees an unconfirmed hit.
  for _, player in ipairs(self.players) do
    player:send(message)
  end

  for _, spec in pairs(self.spectators) do
    if spec then
      spec:send(message)
    end
  end
end

-- Default arbitration window if the gameMode didn't supply one (e.g. offline
-- modes, older clients pre-loose-sync). The room host's latencyTolerance
-- choice overrides this via resolveLatencySettings.
local DEFAULT_ARBITRATION_WINDOW_MS = 200

---@return integer arbitration window in milliseconds for this room
function Room:_arbitrationWindowMs()
  return (self.gameMode and self.gameMode.arbitrationWindowMs) or DEFAULT_ARBITRATION_WINDOW_MS
end

---Relay a loose-sync DeathEvent. Same wire shape as GarbageEvent.
---Also marks the sender as eliminated server-side so we stop relaying their
---now-absent inputs (replacing the legacy J{stackEliminated} path) and starts
---(or extends) the KO arbitration window — see Room:tickArbitration.
---@param sender ServerPlayer
---@param body string raw JSON body from the client
function Room:broadcastDeathEvent(sender, body)
  if not self.game or self.game.complete then
    return
  end

  local ok, parsed = pcall(json.decode, body)
  if not ok or type(parsed) ~= "table" then
    logger.warn(self.roomNumber .. ": malformed DeathEvent from " .. (sender.name or sender.userId or "?"))
    return
  end

  parsed.sender = sender.player_number
  parsed.serverWallClockMs = math.floor(socket.gettime() * 1000)

  self.game:recordDeathEvent(sender, parsed)
  self.game:markPlayerEliminated(sender, parsed.senderFrame)
  logger.info(self.roomNumber .. ": " .. sender.name .. " died at frame " .. tostring(parsed.senderFrame))

  -- Start or extend the simultaneous-KO arbitration window. Each new death
  -- pushes the close-time another arbitration window into the future so a
  -- burst of nearly-simultaneous deaths is all captured. Window size is
  -- driven by the room's latencyTolerance (strict=100ms, normal=200ms,
  -- relaxed=400ms) — see resolveLatencySettings.
  self.arbitrationDeaths[#self.arbitrationDeaths + 1] = {
    slot = sender.player_number,
    senderFrame = parsed.senderFrame,
    serverArrivalMs = parsed.serverWallClockMs,
  }
  self.arbitrationWindowEndsAtMs = parsed.serverWallClockMs + self:_arbitrationWindowMs()

  local stamped = json.encode(parsed)
  local message = NetworkProtocol.markedMessageForTypeAndBody(
    NetworkProtocol.serverMessageTypes.deathEvent.prefix, stamped)

  for _, player in ipairs(self.players) do
    if player ~= sender then
      player:send(message)
    end
  end

  for _, spec in pairs(self.spectators) do
    if spec then
      spec:send(message)
    end
  end
end

---Returns the set of living team indices: teams with at least one player who
---is neither eliminated nor disconnected. For FFA (no teams) each slot is
---treated as its own team.
---@return integer[] # team indices (or slot indices in FFA) that still have a living member
---@return integer[] # representative slot for each living team (first survivor)
function Room:_livingTeams()
  if not self.game then
    return {}, {}
  end
  local livingTeams = {}
  local representatives = {}
  local seen = {}
  for slot = 1, #self.players do
    local dead = self.game.disconnectedPlayers[slot] or self.game.eliminatedPlayers[slot]
    if not dead then
      local teamKey
      if self.teams then
        teamKey = TeamUtils.getPlayerTeamIndex(self.teams, slot)
      else
        teamKey = slot
      end
      if not seen[teamKey] then
        seen[teamKey] = true
        livingTeams[#livingTeams + 1] = teamKey
        representatives[#representatives + 1] = slot
      end
    end
  end
  return livingTeams, representatives
end

---Drain the arbitration window if it has closed. Called from Server:update.
---Emits a single K message with the authoritative outcome and resets state.
---@param nowMs integer current wall-clock time in milliseconds
function Room:tickArbitration(nowMs)
  if not self.arbitrationWindowEndsAtMs or self.arbitrationEmitted then
    return
  end
  if nowMs < self.arbitrationWindowEndsAtMs then
    return
  end
  if not self.game or self.game.complete then
    -- Match already concluded via another path (outcomeReports); skip K.
    self.arbitrationDeaths = {}
    self.arbitrationWindowEndsAtMs = nil
    return
  end

  local livingTeams, representatives = self:_livingTeams()
  local arbitration = {
    deaths = self.arbitrationDeaths,
  }

  if #livingTeams == 1 then
    arbitration.tie = false
    arbitration.winnerSlot = representatives[1]
  elseif #livingTeams == 0 then
    arbitration.tie = true
    arbitration.winnerSlot = nil
  else
    -- More than one team is still alive — KO arbitration is informational
    -- only; the natural game-end logic will produce the final outcome.
    arbitration.tie = false
    arbitration.winnerSlot = nil
  end

  logger.info(string.format(
    "%d: KO arbitration: %d death(s) within %dms window, livingTeams=%d, winnerSlot=%s, tie=%s",
    self.roomNumber, #self.arbitrationDeaths, self:_arbitrationWindowMs(),
    #livingTeams, tostring(arbitration.winnerSlot), tostring(arbitration.tie)))

  local message = ServerProtocol.koArbitration(arbitration)
  local encoded = NetworkProtocol.markedMessageForTypeAndBody(
    message.messageType.prefix, json.encode(message.messageText))

  for _, player in ipairs(self.players) do
    player:send(encoded)
  end
  for _, spec in pairs(self.spectators) do
    if spec then
      spec:send(encoded)
    end
  end

  self.arbitrationEmitted = true
  self.arbitrationDeaths = {}
  self.arbitrationWindowEndsAtMs = nil
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

    -- Process leavers who left mid-match while their stack was already eliminated.
    -- We deferred their removal until now so player_number / disconnectedPlayers
    -- indexing stayed stable while the survivors finished out the match.
    if self.pendingLeaverRemovals then
      for _, leaver in ipairs(self.pendingLeaverRemovals) do
        self:_removeFromPlayersAndAnnounce(leaver)
      end
      self.pendingLeaverRemovals = nil
    end
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

    -- Loose-sync: per-player input counts diverge naturally with clock drift,
    -- so we can't distinguish a "latency timeout" from "user gave up" from the
    -- gap alone. Treat all aborts the same: eliminate the aborter and let the
    -- survivors finish.
    if self.game then
      self.game:markPlayerEliminated(sender, sender.player_number)
    end

    -- Outcome attribution:
    -- - 2p: aborting player loses, opponent wins
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

---Handle a player leaving or disconnecting. If a match is in progress, the room is
---voided and the match is aborted for remaining players. If no match is in progress,
---the player is simply removed and the room stays open so they can rejoin from the
---lobby. The leaver is removed from the room (the caller is responsible for sending
---them their own leaveRoom). Remaining players + spectators are notified via
---playerLeftRoom.
---@param leaver ServerPlayer the player who is leaving / disconnected
---@param reason string? human-readable reason (forwarded to remaining clients only when mid-game)
function Room:voidByLeave(leaver, reason)
  if not self.game then
    -- Pre-match: leave the room open so others (or the leaver) can fill the slot.
    -- Fixed-roster rooms reserve the slot for the leaver's rejoin. Open FFA is
    -- first-come-first-served — no reservation; the next lobby player to click
    -- Join takes the freed slot.
    if not self:isDynamicRoster() then
      self.reservedSlots[leaver.publicPlayerID] = true
      logger.info(self.roomNumber .. ": " .. leaver.name .. " left pre-match (slot reserved for rejoin)")
    else
      logger.info(self.roomNumber .. ": " .. leaver.name .. " left pre-match (open FFA, slot free for fcfs)")
    end
    self:_removeFromPlayersAndAnnounce(leaver)
    return
  end

  if self.voided then
    -- already void; just log and continue (subsequent leaver from a voided room)
    logger.debug(self.roomNumber .. ": voidByLeave called on already-voided room")
  else
    self.voided = true
    self.voidReason = (leaver.name or "A player") .. " left" .. (reason and (" (" .. reason .. ")") or "")
    logger.info(self.roomNumber .. ": voiding room (" .. self.voidReason .. ")")
  end

  -- Grace check: clients defer their stackEliminated message by 60 frames so a
  -- rollback can cancel a false death. If a player times out inside that window
  -- the server hasn't been told yet — but the leaver almost certainly died,
  -- because clients stop sending inputs once game_ended() is true. Detect this
  -- by looking at the gap between the leaver's confirmed input count and the
  -- rest of the room: a meaningful gap means they stopped sending. Mark them
  -- eliminated so we take the "continue match" branch below instead of aborting.
  if not self.game.eliminatedPlayers[leaver.player_number] then
    local DEATH_GAP_THRESHOLD = 30  -- frames; half a second at 60fps
    local leaverInputs = #self.game.inputs[leaver.player_number]
    local maxInputs = 0
    for i = 1, #self.game.players do
      if i ~= leaver.player_number
        and not self.game.disconnectedPlayers[i]
        and not self.game.eliminatedPlayers[i] then
        maxInputs = math.max(maxInputs, #self.game.inputs[i])
      end
    end
    if maxInputs - leaverInputs > DEATH_GAP_THRESHOLD then
      logger.info(self.roomNumber .. ": " .. leaver.name .. " left with " ..
        (maxInputs - leaverInputs) .. "-frame input gap; assuming they died and continuing the match")
      self.game:markPlayerEliminated(leaver, leaverInputs)
    end
  end

  -- Mid-match. Two cases:
  --   1. Leaver was already eliminated (their stack died, they were just
  --      spectating their own match). Don't interrupt the survivors — server
  --      idle-fills the leaver's input slot, the match plays out naturally,
  --      and we queue the leaver's removal for after the match ends so player_
  --      number / game.disconnectedPlayers indexing stays stable mid-flight.
  --   2. Leaver was alive. Their absence would stall input flow (they've
  --      stopped sending). Abort the match cleanly for the survivors.
  if self.game.eliminatedPlayers[leaver.player_number] then
    self.game:markPlayerDisconnected(leaver)
    self.pendingLeaverRemovals = self.pendingLeaverRemovals or {}
    self.pendingLeaverRemovals[#self.pendingLeaverRemovals + 1] = leaver
    -- Surface the void state to remaining players immediately so the banner
    -- shows up; their match keeps running.
    self:broadcastJson(ServerProtocol.playerLeftRoom(self.roomNumber, leaver.publicPlayerID, leaver.name, self.voidReason))
    return
  else
    self:broadcastJson(ServerProtocol.sendGameAbort(leaver, reason or "player left"), leaver)
    self:emitSignal("matchEnd", self.game)
    self:prepare_character_select()
    self.game = nil
    self.recentGameAbort = true
    -- Abort just collapsed the match. Any earlier dead-leavers we were waiting
    -- to remove at match-end won't get that signal, so flush them now.
    if self.pendingLeaverRemovals then
      for _, queuedLeaver in ipairs(self.pendingLeaverRemovals) do
        self:_removeFromPlayersAndAnnounce(queuedLeaver)
      end
      self.pendingLeaverRemovals = nil
    end
  end

  self:_removeFromPlayersAndAnnounce(leaver)
end

---Internal: removes a player from self.players, compacts win_counts, broadcasts
---playerLeftRoom. Caller is responsible for setting voided/voidReason.
function Room:_removeFromPlayersAndAnnounce(leaver)
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
  -- Teams are no longer valid (player count changed). team_win_counts stays so
  -- the per-team scoreboard keeps showing matches that already happened.
  self.teams = nil

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