-- socket is bundled with love so the client requires love's socket
-- and the server requires the socket from common/lib
---@diagnostic disable-next-line: different-requires
local socket = require("common.lib.socket")
local logger = require("common.lib.logger")
local class = require("common.lib.class")
local ServerProtocol = require("common.network.ServerProtocol")
json = require("common.lib.dkjson")
require("common.lib.mathExtensions")
require("common.lib.util")
require("common.lib.timezones")
require("common.lib.csprng")
require("server.stridx")
require("server.server_globals")
local Connection = require("server.Connection")
local Leaderboard = require("server.Leaderboard")
local Playerbase = require("server.PlayerBase")
local Room = require("server.Room")
local ClientMessages = require("server.ClientMessages")
local utf8 = require("common.lib.utf8Additions")
local tableUtils = require("common.lib.tableUtils")
local Player = require("server.Player")
local util = require("common.lib.util")
local FileIO = require("server.FileIO")
local GameModes = require("common.data.GameModes")

local function resolveRequestedGameMode(requestedGameMode)
  if type(requestedGameMode) == "table" then
    local requestedId = requestedGameMode.gameModeId or requestedGameMode.id
    if requestedId and GameModes.IDs[requestedId] then
      return GameModes.getPreset(requestedId)
    end

    local requestedName = requestedGameMode.name
    if requestedName then
      local canonicalId = GameModes.nameToGameModeId[requestedName]
      if canonicalId then
        return GameModes.getPreset(canonicalId)
      end
    end

    if requestedGameMode.gameMode then
      return resolveRequestedGameMode(requestedGameMode.gameMode)
    end
  elseif type(requestedGameMode) == "string" then
    if GameModes.IDs[requestedGameMode] then
      return GameModes.getPreset(requestedGameMode)
    end

    local canonicalId = GameModes.nameToGameModeId[requestedGameMode]
    if canonicalId then
      return GameModes.getPreset(canonicalId)
    end
  end

  return nil
end

local function resolveConnectionWatchdogSettings(latencyTolerance, playerCount)
  local count = tonumber(playerCount) or 2
  local tolerance = latencyTolerance
  if tolerance ~= "strict" and tolerance ~= "normal" and tolerance ~= "relaxed" then
    tolerance = "normal"
  end

  if count >= 3 then
    if tolerance == "strict" then
      return 30, 10
    elseif tolerance == "relaxed" then
      return 120, 20
    else
      return 60, 15
    end
  else
    if tolerance == "strict" then
      return 20, 8
    elseif tolerance == "relaxed" then
      return 90, 15
    else
      return 45, 10
    end
  end
end

local pairs = pairs
local ipairs = ipairs
local time = os.time

---@alias privateUserId string

-- Represents the full server object.
-- Currently we are transitioning variables into this, but to start we will use this to define API
---@class Server
---@field socket TcpSocket the master socket for accepting incoming client connections
---@field database ServerDB the database object
---@field connectionNumberIndex integer GLOBAL counter of the next available connection index
---@field roomNumberIndex integer the next available room number
---@field rooms Room[] mapping of room number to room
---@field proposals table<PublicPlayerID, table<PublicPlayerID, table<GameModeID, boolean>>> mapping of player name to a mapping of the players they have challenged for each game mode
---@field connections Connection[] mapping of connection number to connection
---@field nameToConnectionIndex table<string, integer> mapping of player names to their unique connectionNumberIndex
---@field socketToConnectionIndex table<TcpSocket, integer> mapping of sockets to their unique connectionNumberIndex
---@field connectionToPlayer table<Connection, ServerPlayer> Mapping of connections to the player they send for
---@field publicIdToPlayer table<PublicPlayerID, ServerPlayer> Mapping of publicId to the logged in ServerPlayer
---@field playerToRoom table<ServerPlayer, Room>
---@field spectatorToRoom table<ServerPlayer, Room>
---@field nameToPlayer table<string, ServerPlayer>
---@field lastProcessTime integer
---@field lastFlushTime integer timestamp for when logs were last flushed to file
---@field lobbyChanged boolean if new lobby data should be sent out on the next loop
---@field playerbase table
---@field leaderboard Leaderboard
---@field persistence Persistence
---@field _shuttingDown boolean
---@field recentJoinRequests table<string, number> last timestamp of join request per player (key: "playerId_roomNumber")
local Server = class(
---@param self Server
---@param databaseParam ServerDB
  function(self, databaseParam, persistence)
    self.connectionNumberIndex = 1
    self.roomNumberIndex = 1
    self.rooms = {}
    self.proposals = {}
    self.connections = {}
    self.nameToConnectionIndex = {}
    self.socketToConnectionIndex = {}
    self.connectionToPlayer = {}
    self.publicIdToPlayer = {}
    self.playerToRoom = {}
    self.spectatorToRoom = {}
    self.nameToPlayer = {}
    self.recentJoinRequests = {}  -- Track timestamps of recent join requests for idempotency
    assert(databaseParam ~= nil)
    self.database = databaseParam
    self.persistence = persistence
    self.lastProcessTime = time()
    self.lastFlushTime = self.lastProcessTime
    self.lobbyChanged = false
    self._shuttingDown = false

    FileIO.read_csprng_seed_file()
    initialize_mt_generator(csprng_seed)
    seed_from_mt(extract_mt())
    -- local server_start_time = os.time()
    -- print("current local time: "..server_start_time)
    -- print("current UTC time: "..to_UTC(server_start_time))
    -- local now = os.date("*t")
    -- local formatted_local_time = string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec)
    -- print("formatted local time: "..formatted_local_time)
    -- now = os.date("*t",to_UTC(server_start_time))
    -- local formatted_UTC_time = string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec)
    -- print("formatted UTC time: "..formatted_UTC_time)
    logger.debug("COMPRESS_REPLAYS_ENABLED: " .. (COMPRESS_REPLAYS_ENABLED and "true" or "false"))
    logger.debug("initialized!")
  end
)

function Server:start()
  local port = SERVER_PORT or 49569
  logger.info("Starting up server with port: " .. port)

  -- Retrying helps when a previous local server instance just exited and the port
  -- is not yet immediately reusable on all platforms.
  local attempts = 50
  local s
  for i = 1, attempts do
    s = socket.bind("*", port)
    if s then
      break
    end
    if i < attempts then
      logger.warn("Port " .. port .. " not available yet (attempt " .. i .. "/" .. attempts .. "), retrying...")
      socket.sleep(0.25)
    end
  end

  if s then
    self.socket = s
  else
    error("Failed to create server socket on port " .. port .. ". Check for another running server instance.")
  end
  self.socket:settimeout(0)

  logger.debug(os.time())
end

function Server:stop()
  self._shuttingDown = true
  self.socket:close()
  self.socket = nil
end

---@param filePath string
---@param playerData table<privateUserId, string>?
function Server:initializePlayerData(filePath, playerData)
  if not self.playerbase then
    self.persistence.setPlayerIdsPath(filePath)
    if not playerData then
      playerData = self.persistence.getPlayerData()
    else
      -- do nothing, assume that's already parsed data
    end

    -- we don't want to design the API for persistence around the fact that we always need the entire playerData to write to disk
    -- so hand it a reference so the design can be more atomic
    self.persistence.setPlayerDataRef(playerData)

    self.playerbase = Playerbase(playerData, self.persistence)
    logger.debug("playerbase: " .. json.encode(self.playerbase.players))
  else
    logger.warn("Tried to load player data when the server already had player data loaded!\n" .. debug.traceback())
  end
end

---@param gameMode GameMode
---@param filePath string
---@param data table?
function Server:initializeLeaderboard(gameMode, filePath, data)
  if not self.leaderboard then
    self.persistence.setLeaderboardPath(filePath)
    self.leaderboard = Leaderboard(gameMode, self.persistence)
    if not data then
      data = self.persistence.getLeaderboardData()
    else
      -- do nothing, assume that's already parsed data
    end
    if data then
      self.leaderboard:importData(data)
    end

    logger.debug("leaderboard json:")
    logger.debug(json.encode(self.leaderboard.players))
    self.persistence.persistLeaderboard(self.leaderboard)
    logger.debug("leaderboard report: " .. json.encode(self.leaderboard:get_report(self)))
  else
    logger.warn("Tried to load leaderboard data when the server already had its leaderboard loaded!\n" .. debug.traceback())
  end
end

function Server:importDatabase()
  local usedNames = {}
  local cleanedPlayerData = {}
  for key, value in pairs(self.playerbase.players) do
    local name = value
    while usedNames[name] ~= nil do
      name = name .. math.random(1, 9999)
    end
    cleanedPlayerData[key] = value
    usedNames[name] = true
  end

  self.database:beginTransaction() -- this stops the database from attempting to commit every statement individually 
  logger.info("Importing leaderboard.csv to database")
  for k, v in pairs(cleanedPlayerData) do
    local rating = 0
    if self.leaderboard.players[k] then
      rating = self.leaderboard.players[k].rating
    end
    self.database:insertNewPlayer(k, v)
    self.database:insertPlayerELOChange(k, rating, 0)
  end

  local gameMatches = FileIO.readCsvFile("GameResults.csv")
  if gameMatches then -- only do it if there was a gameResults file to begin with
    logger.info("Importing GameResults.csv to database")
    for _, result in ipairs(gameMatches) do
      local parsedPlayer1ID = tostring(result[1])
      local parsedPlayer2ID = tostring(result[2])
      local parsedOutcome = tonumber(result[3])
      local parsedRanked = tonumber(result[4])
      if parsedPlayer1ID and parsedPlayer2ID and parsedOutcome and parsedRanked then
        local player1Won = parsedOutcome == 1
        local ranked = parsedRanked == 1
        local gameID = self.database:insertGame(ranked)
        assert(gameID)
        if player1Won then
          self.database:insertPlayerGameResult(parsedPlayer1ID, gameID, nil,  1)
          self.database:insertPlayerGameResult(parsedPlayer2ID, gameID, nil,  2)
        else
          self.database:insertPlayerGameResult(parsedPlayer2ID, gameID, nil,  1)
          self.database:insertPlayerGameResult(parsedPlayer1ID, gameID, nil,  2)
        end
      else
        logger.warn("Skipping malformed GameResults.csv row: " .. json.encode(result))
      end
    end
  end
  self.database:commitTransaction() -- bulk commit every statement from the start of beginTransaction
end

function Server:setLobbyChanged()
  self.lobbyChanged = true
end

---@alias LobbyPlayerV2 { publicId: PublicPlayerID, name: string, state: string, ratings: table<GameModeID, number?>, roomNumber: roomNumber? }
---@alias LobbyRoomV2 { roomNumber: roomNumber, state: string, gameModeId: GameModeID, players: PublicPlayerID[], spectators: PublicPlayerID[], wins: integer[], teamWins: integer[]?, gameStartTime: integer? }
---@alias LobbyStateV2 { players: table<PublicPlayerID, LobbyPlayerV2>, rooms: table<roomNumber, LobbyRoomV2> }

---@return LobbyStateV2
function Server:lobbyStateV2()
  local players = {}
  local rooms = {}

  for publicId, player in pairs(self.publicIdToPlayer) do
    players[publicId] = {
      publicId = publicId,
      name = player.name,
      state = player.state,
      ratings = { },
    }

    if self.leaderboard and self.leaderboard.players[player.userId] and self.leaderboard.players[player.userId].placement_done then
      players[publicId].ratings.TWO_PLAYER_VS = math.round(self.leaderboard.players[player.userId].rating)
    end
  end

  for _, room in pairs(self.rooms) do
    local roomState = room:state()
    local lobbyRoom = {
      roomNumber = room.roomNumber,
      state = roomState,
      gameModeId = room.gameModeId or (room.gameMode and GameModes.nameToGameModeId[room.gameMode.name]) or nil,
      ownerId = room.players[1] and room.players[1].publicPlayerID or nil,
      players = {},
      spectators = {},
      wins = {},
      minPlayers = room.minPlayers,
      maxPlayers = room.maxPlayers,
      openSlots = room:getOpenSlots(),
      slotRequests = {},
      pendingJoinerCount = (room.pendingJoiners and #room.pendingJoiners) or 0,
    }

    -- Iterate a shallow snapshot so clearProposals can safely mutate self.proposals
    -- elsewhere in the same tick without invalidating this traversal.
    local proposalsSnapshot = {}
    for senderId, receivers in pairs(self.proposals) do
      proposalsSnapshot[senderId] = {}
      for receiverId, proposals in pairs(receivers) do
        proposalsSnapshot[senderId][receiverId] = proposals
      end
    end

    for senderId, receivers in pairs(proposalsSnapshot) do
      for receiverId, proposals in pairs(receivers) do
        for proposalKey, active in pairs(proposals) do
          if active then
            local roomNumberStr, slotNumberStr = proposalKey:match("^room_(%d+)_(%d+)$")
            if roomNumberStr and tonumber(roomNumberStr) == room.roomNumber then
              lobbyRoom.slotRequests[tonumber(slotNumberStr)] = senderId
            end
          end
        end
      end
    end

    if room.game then
      lobbyRoom.gameStartTime = os.date("*t", to_UTC(room.game.creationTime))
    end

    for i, player in ipairs(room.players) do
      if players[player.publicPlayerID] then
        players[player.publicPlayerID].roomNumber = room.roomNumber
        players[player.publicPlayerID].state = roomState
      end
      lobbyRoom.players[i] = player.publicPlayerID
      lobbyRoom.wins[i] = room.win_counts[i]
    end

    if room.team_win_counts then
      lobbyRoom.teamWins = {}
      for teamIndex, wins in ipairs(room.team_win_counts) do
        lobbyRoom.teamWins[teamIndex] = wins
      end
    end

    for i, spectator in ipairs(room.spectators) do
      if players[spectator.publicPlayerID] then
        players[spectator.publicPlayerID].roomNumber = room.roomNumber
      end
      lobbyRoom.spectators[i] = spectator.publicPlayerID
    end

    rooms[lobbyRoom.roomNumber] = lobbyRoom
  end

  return { players = players, rooms = rooms }
end

---@param sender ServerPlayer
---@param receiver ServerPlayer
---@param gameModeId GameModeID
---@param challengeActive boolean
---@param roomNumber integer? optional room number for team room invites
---@param slotNumber integer? optional slot number for team room invites
function Server:processChallengeUpdate(sender, receiver, gameModeId, challengeActive, roomNumber, slotNumber)
      if not sender or not receiver then
        return
      end

      -- Reject malformed IDs defensively to avoid corrupt proposal keys/state.
      -- PublicPlayerID is integer in this codebase; keep string support only for safety.
      local function isValidPublicId(id)
        if id == nil then
          return false
        end
        local t = type(id)
        if t == "number" then
          return true
        end
        if t == "string" then
          return id ~= ""
        end
        return false
      end

      if not isValidPublicId(sender.publicPlayerID) then
        logger.debug("Invalid sender publicPlayerID, ignoring challenge update")
        return
      end
      if not isValidPublicId(receiver.publicPlayerID) then
        logger.debug("Invalid receiver publicPlayerID, ignoring challenge update")
        return
      end

      -- CRITICAL: Validate sender and receiver still exist before proceeding (#44)
      if not self.publicIdToPlayer[sender.publicPlayerID] then
        logger.debug("Sender no longer exists, ignoring challenge update")
        return
      end
      if not self.publicIdToPlayer[receiver.publicPlayerID] then
        logger.debug("Receiver no longer exists, ignoring challenge update")
        return
      end
      
      logger.debug(string.format("processChallengeUpdate: sender=%s, receiver=%s, gameMode=%s, active=%s, room=%s, slot=%s",
    sender and sender.name or "nil",
    receiver and receiver.name or "nil",
    tostring(gameModeId),
    tostring(challengeActive),
    tostring(roomNumber),
    tostring(slotNumber)))
  
  -- Idempotency: if this is a room invite (with roomNumber), reject duplicate requests within 2 seconds
  if roomNumber and challengeActive then
    roomNumber = tonumber(roomNumber)
    local requestedSlot = tonumber(slotNumber)
    if not roomNumber then
      logger.debug("Room invite rejected: invalid room number")
      return
    end
    -- Team-room invites are slot specific; require a sane positive integer slot.
    if not requestedSlot or requestedSlot < 1 or requestedSlot ~= math.floor(requestedSlot) then
      logger.debug("Room invite rejected: invalid slot number")
      return
    end
    local now = time()
    local inviteKey = roomNumber .. "_" .. requestedSlot
    local requestKey = sender.publicPlayerID .. "_" .. receiver.publicPlayerID .. "_invite_" .. inviteKey
    local lastRequestTime = self.recentJoinRequests[requestKey]
    if lastRequestTime and (now - lastRequestTime) < 2 then
      logger.debug("Player " .. sender.name .. " room invite to " .. receiver.name .. " rejected (duplicate within 2s)")
      return
    end
    self.recentJoinRequests[requestKey] = now
  end
  if sender and receiver then
    -- Check if this is a room invite (joining existing room)
    if roomNumber then
      roomNumber = tonumber(roomNumber)
      slotNumber = tonumber(slotNumber)
      logger.debug(string.format("Room invite: sender.state=%s, receiver.state=%s", sender.state, receiver.state))
      if sender.state ~= "lobby" and sender.state ~= "character select" then
        logger.debug("Rejecting: sender not in lobby or character select")
        return
      end
      if receiver.state ~= "lobby" and receiver.state ~= "character select" then
        logger.debug("Rejecting: receiver not in lobby or character select")
        return
      end
      local room = self.rooms[roomNumber]
      if room and not room:isFull() then
        if not slotNumber or slotNumber < 1 or slotNumber ~= math.floor(slotNumber) then
          logger.debug(string.format("Room invite rejected: invalid slot %s", tostring(slotNumber)))
          return
        end
        if room.maxPlayers and slotNumber > room.maxPlayers then
          logger.debug(string.format("Room invite rejected: requested slot %d exceeds max players %d", slotNumber, room.maxPlayers))
          return
        end
        local slotOpen = tableUtils.trueForAny(room:getOpenSlots(), function(openSlot)
          return tonumber(openSlot) == slotNumber
        end)
        if not slotOpen then
          logger.debug(string.format("Room invite rejected: requested slot %s is not open in room %d", tostring(slotNumber), roomNumber))
          return
        end

        logger.debug(string.format("%s invites %s to join room %d at slot %d", sender.name, receiver.name, roomNumber, slotNumber))

        -- Check if receiver has previously invited sender to this room (mutual acceptance)
        local proposalKey = "room_" .. roomNumber .. "_" .. slotNumber
        local previouslyProposed = self.proposals[receiver.publicPlayerID] and self.proposals[receiver.publicPlayerID][sender.publicPlayerID] and self.proposals[receiver.publicPlayerID][sender.publicPlayerID][proposalKey]

        if previouslyProposed then
            -- CRITICAL: Prevent simultaneous mutual acceptances (#59)
            -- Clear proposal BEFORE join to prevent race condition where both directions trigger join
            local proposalKey = "room_" .. roomNumber .. "_" .. slotNumber
            if self.proposals[receiver.publicPlayerID] and self.proposals[receiver.publicPlayerID][sender.publicPlayerID] then
              self.proposals[receiver.publicPlayerID][sender.publicPlayerID][proposalKey] = nil
            end
            
            -- Mutual acceptance - add whoever is not already in the *target room*.
          -- This mirrors vs/time-attack handshake for both directions:
          -- 1) room owner invites first, target accepts
          -- 2) target requests first, owner approves
          local senderInTargetRoom = tableUtils.trueForAny(room.players, function(p)
            return p and p.publicPlayerID == sender.publicPlayerID
          end)
          local receiverInTargetRoom = tableUtils.trueForAny(room.players, function(p)
            return p and p.publicPlayerID == receiver.publicPlayerID
          end)

          if senderInTargetRoom and not receiverInTargetRoom then
            self:handleJoinRoom(receiver, roomNumber, slotNumber)
          elseif receiverInTargetRoom and not senderInTargetRoom then
            self:handleJoinRoom(sender, roomNumber, slotNumber)
          else
            -- Fallback for unexpected state: default to sender (accepting/clicking side).
            self:handleJoinRoom(sender, roomNumber, slotNumber)
          end
        else
          -- Send invite to receiver
          logger.debug(string.format("Storing proposal and sending challengeUpdate to %s for slot %s", receiver.name, tostring(slotNumber)))
          self:updateChallenge(sender, receiver, proposalKey, challengeActive)
          receiver:sendJson(ServerProtocol.sendChallengeUpdate(sender, receiver, gameModeId, challengeActive, roomNumber, slotNumber))
        end
      else
        logger.debug(string.format("Room invite rejected: room=%s, isFull=%s", tostring(room ~= nil), tostring(room and room:isFull())))
      end
    elseif sender.state == "lobby" and receiver.state == "lobby" then
      -- Standard 2-player game challenge
      logger.debug(string.format("%s challenges %s to a game of %s", sender.name, receiver.name, gameModeId))
      local previouslyProposedGameModes = self.proposals[receiver.publicPlayerID] and self.proposals[receiver.publicPlayerID][sender.publicPlayerID]
      if previouslyProposedGameModes and previouslyProposedGameModes[gameModeId] then
        self:create_room(GameModes.getPreset(gameModeId), sender, receiver)
      else
        -- no existing challenge for this game mode
        self:updateChallenge(sender, receiver, gameModeId, challengeActive)
        receiver:sendJson(ServerProtocol.sendChallengeUpdate(sender, receiver, gameModeId, challengeActive))
      end
    end
  else
    -- this message won't be handled because one of the parties is no longer in lobby
    -- related things would be handled in the state change / logout
  end
end

---@param sender ServerPlayer
---@param receiver ServerPlayer
---@param gameModeId GameModeID
---@param challengeActive boolean
function Server:updateChallenge(sender, receiver, gameModeId, challengeActive)
  local senderChallenges = self.proposals[sender.publicPlayerID] or {}
  senderChallenges[receiver.publicPlayerID] = senderChallenges[receiver.publicPlayerID] or {}
  senderChallenges[receiver.publicPlayerID][gameModeId] = challengeActive
  
  self.proposals[sender.publicPlayerID] = senderChallenges
end

---@param player ServerPlayer
function Server:clearProposals(player)
  -- blanket reset for the player
  local playerId = player.publicPlayerID
  logger.debug(string.format("clearProposals(%s) called", player.name))
  
  -- Log what we're clearing
  if self.proposals[playerId] then
    for receiverId, keys in pairs(self.proposals[playerId]) do
      for key in pairs(keys) do
        logger.debug(string.format("  Clearing outgoing: [%s] → [%s] : %s", playerId, receiverId, key))
      end
    end
  end
  
  self.proposals[playerId] = {}
  
  -- reset all challenges to the player
  for senderId, challenges in pairs(self.proposals) do
    if challenges[playerId] then
      for key in pairs(challenges[playerId]) do
        logger.debug(string.format("  Clearing incoming: [%s] → [%s] : %s", senderId, playerId, key))
      end
      challenges[playerId] = nil
    end
  end
  
  logger.debug(string.format("clearProposals(%s) complete", player.name))
end

---@param gameMode GameMode
---@param ... ServerPlayer
function Server:create_room(gameMode, ...)
  self:setLobbyChanged()
  local players = {...}
  local leaderboard
  if self.leaderboard and tableUtils.deep_content_equal(gameMode, self.leaderboard.gameMode) then
    leaderboard = self.leaderboard
  end

  if #players > 1 then
    -- no delay is enabled only to reduce the chances of hitting rollback and rollback only exists in multiplayer
    for _, player in ipairs(players) do
---@diagnostic disable-next-line: invisible
      player.connection:enableNoDelay(true)
    end
  end

  local newRoom = Room(self.roomNumberIndex, players, gameMode, leaderboard)
  newRoom:connectSignal("matchStart", self, self.setLobbyChanged)
  newRoom:connectSignal("matchEnd", self, self.processGameEnd)
  newRoom:connectSignal("pauseToggled", self, self.setLobbyChanged)
  -- After every match (clean end or abort) the room emits roomShouldClose; the Server
  -- is the only thing that owns playerToRoom and self.rooms, so closing must happen here.
  newRoom:connectSignal("roomShouldClose", self, self.onRoomShouldClose)
  newRoom:connectSignal("readyForPendingJoiners", self, self.drainPendingJoiners)
  self.roomNumberIndex = self.roomNumberIndex + 1
  self.rooms[newRoom.roomNumber] = newRoom

  for _, player in ipairs(players) do
    self:clearProposals(player)
    self.playerToRoom[player] = newRoom
    player:sendJson(ServerProtocol.addToRoom(newRoom, nil))
  end
end

---Drain a dynamic-roster room's pendingJoiners queue once character select reopens.
---Each queued player is routed through handleJoinRoom so they pick up the normal
---addToRoom flow exactly as if they'd joined fresh.
---@param room Room the room asking to drain its queue
function Server:drainPendingJoiners(room)
  if not room or not room.pendingJoiners then return end
  local queue = room.pendingJoiners
  room.pendingJoiners = {}
  local spectatorListChanged = false
  for _, entry in ipairs(queue) do
    local player = entry.player
    if player and not room:isFull() then
      -- They were spectating while queued. Demote out of spectator state
      -- in-place so handleJoinRoom accepts them as a lobby joiner. We bypass
      -- Room:remove_spectator here so the client doesn't see a leaveRoom; the
      -- subsequent addPlayer/addToRoom transitions them straight into the
      -- player seat.
      if self.spectatorToRoom[player] == room then
        for i, s in ipairs(room.spectators) do
          if s == player then
            table.remove(room.spectators, i)
            break
          end
        end
        self.spectatorToRoom[player] = nil
        player.state = "lobby"
        player.room = nil
        spectatorListChanged = true
      end
      -- Idempotency check in handleJoinRoom would block back-to-back joins,
      -- so reset the rate-limit entry first.
      self.recentJoinRequests[player.publicPlayerID .. "_" .. room.roomNumber] = nil
      self:handleJoinRoom(player, room.roomNumber, nil)
    end
  end
  if spectatorListChanged then
    room:broadcastJson(ServerProtocol.updateSpectators(room.roomNumber, room:spectator_names()))
  end
end

---Signal handler for Room:roomShouldClose. Signal callbacks are invoked as
---callback(subscriber, ...emitArgs); Room emits with (self, reason), so we receive
---(server, room, reason). Idempotent against rooms that were already closed by
---another path (disconnect, explicit leave) since closeRoom checks self.rooms.
---@param room Room the room asking to be closed
---@param reason string? human-readable reason, forwarded to clients via leaveRoom
function Server:onRoomShouldClose(room, reason)
  if room and self.rooms[room.roomNumber] == room then
    self:closeRoom(room, reason)
  end
end

---@param room Room
function Server:closeRoom(room, reason)
  for _, player in ipairs(room.players) do
    self.playerToRoom[player] = nil
    ---@diagnostic disable-next-line: invisible
    player.connection:enableNoDelay(false)
  end

  for _, player in ipairs(room.spectators) do
    self.spectatorToRoom[player] = nil
  end

  if self.rooms[room.roomNumber] then
    self.rooms[room.roomNumber] = nil
  end

  room:close(reason)
  self:setLobbyChanged()
end

---@param player ServerPlayer
---@param roomNumber integer
---@param slotNumber integer
---@return boolean success
function Server:handleJoinRoom(player, roomNumber, slotNumber)
  roomNumber = tonumber(roomNumber)
  slotNumber = tonumber(slotNumber)
  if not roomNumber then
    logger.warn("Player " .. player.name .. " sent invalid room number for join request: " .. tostring(roomNumber))
    return false
  end

  -- Idempotency check: reject duplicate join requests within 2 seconds (button mashing protection)
  local requestKey = player.publicPlayerID .. "_" .. roomNumber
  local now = time()
  local lastRequestTime = self.recentJoinRequests[requestKey]
  if lastRequestTime and (now - lastRequestTime) < 2 then
    logger.debug("Player " .. player.name .. " join request to room " .. roomNumber .. " rejected (duplicate within 2s)")
    return false
  end
  self.recentJoinRequests[requestKey] = now

  local room = self.rooms[roomNumber]
  if not room then
    logger.warn("Player " .. player.name .. " tried to join non-existent room " .. roomNumber)
    return false
  end

  if room.voided then
    logger.warn("Player " .. player.name .. " tried to join voided room " .. roomNumber .. " (" .. tostring(room.voidReason) .. ")")
    return false
  end

  if next(room.reservedSlots) and not room.reservedSlots[player.publicPlayerID] then
    logger.warn("Player " .. player.name .. " tried to join room " .. roomNumber .. " with reserved slots (not their slot)")
    return false
  end

  if slotNumber ~= nil then
    if slotNumber < 1 or slotNumber ~= math.floor(slotNumber) then
      logger.warn("Player " .. player.name .. " sent invalid slot number for join request: " .. tostring(slotNumber))
      return false
    end
    if room.maxPlayers and slotNumber > room.maxPlayers then
      logger.warn("Player " .. player.name .. " sent out-of-range slot for join request: " .. tostring(slotNumber))
      return false
    end
  end

  if self.playerToRoom[player] == room then
    logger.warn("Player " .. player.name .. " is already in room " .. roomNumber .. "; ignoring duplicate join")
    return false
  end

  if room:isFull() then
    logger.warn("Player " .. player.name .. " tried to join full room " .. roomNumber)
    return false
  end

  -- Dynamic-roster modes (open FFA): mid-match join attempts are routed into
  -- the spectator seat and also queued for player promotion. add_spectator(_, true)
  -- handles both — pushes onto pendingJoiners and adds to spectators so the joiner
  -- watches the live match. drainPendingJoiners (called from prepare_character_select)
  -- promotes them to a player slot when character select reopens.
  local roomState = room:state()
  local isDynamicRoster = room.gameMode and room.gameMode.minPlayers ~= nil
  if roomState ~= "lobby" and roomState ~= "character select" then
    if isDynamicRoster and roomState == "playing" and not room:isFull() then
      -- Avoid duplicate queue entries.
      for _, entry in ipairs(room.pendingJoiners) do
        if entry.player == player then
          logger.debug("Player " .. player.name .. " already queued for room " .. roomNumber)
          return false
        end
      end
      if not room:add_spectator(player, true) then
        return false
      end
      self.spectatorToRoom[player] = room
      logger.info("Player " .. player.name .. " spectating + queued for open room " .. roomNumber .. " (match in progress)")
      self:setLobbyChanged()
      return true
    end
    logger.warn("Player " .. player.name .. " tried to join room " .. roomNumber .. " in state '" .. roomState .. "'")
    return false
  end

  -- Also check player state
  if player.state ~= "lobby" and player.state ~= "character select" then
    logger.warn("Player " .. player.name .. " cannot join room while in state '" .. player.state .. "'")
    return false
  end

  -- Slot number is informational - we always add to the next available position.
  -- (Note: slotNumber parameter is request intent, not enforced assignment)
  local actualSlot = #room.players + 1
  if slotNumber then
    logger.debug(string.format("Player %s requested slot %d, assigning to actual slot %d", player.name, slotNumber, actualSlot))
  end

  -- Enable no delay for multiplayer
  ---@diagnostic disable-next-line: invisible
  player.connection:enableNoDelay(true)

  -- Re-check room lifecycle before mutating it; the room may have closed between validation and join.
  if not self.rooms[roomNumber] or self.rooms[roomNumber] ~= room then
    logger.warn("Player " .. player.name .. " join aborted: room " .. roomNumber .. " no longer available")
    return false
  end

  -- Add player to the room
  local success = room:addPlayer(player)
  if success then
    -- Clear only proposals involving the joining player.
    -- Keep other players' pending slot requests intact.
    self:clearProposals(player)

    self.playerToRoom[player] = room
    self:setLobbyChanged()

    -- Clear the reserved slot for this player (rejoin complete)
    room.reservedSlots[player.publicPlayerID] = nil

    -- Send addToRoom message to the joining player
    player:sendJson(ServerProtocol.addToRoom(room, nil))

    logger.info("Player " .. player.name .. " joined room " .. roomNumber .. " as player " .. actualSlot)
  end

  return success
end

---@param name string
---@return privateUserId?
function Server:createNewUser(name)
  local user_id = nil
  while not user_id or self.playerbase.players[user_id] do
    user_id = self:generate_new_user_id()
  end
  if self.playerbase:addPlayer(user_id, name) then
    return user_id
  end
end

function Server:changeUsername(privateUserID, username)
  self.playerbase:updatePlayer(privateUserID, username)
  if self.leaderboard.players[privateUserID] then
    self.leaderboard.players[privateUserID].user_name = username
  end
end

---@return privateUserId new_user_id
function Server:generate_new_user_id()
  local new_user_id = cs_random()
  local result = tostring(new_user_id)
  assert(result)
  return result
end

-- Checks if a logging in player is banned based off their IP.
---@param ip string
---@return DB_Ban?
function Server:getBanByIP(ip)
  return self.database:getBanByIP(ip)
end

---@param ip string
---@param reason string
---@param completionTime integer
---@return DB_Ban?
function Server:insertBan(ip, reason, completionTime)
  return self.database:insertBan(ip, reason, completionTime)
end

function Server:update()

  if not self._shuttingDown then
    self:acceptNewConnections()
  end

  self:updateConnections()
  self:processMessages()
  self:tickArbitrations()

  -- Only check once a second to avoid over checking
  -- (we are relying on time() returning a number rounded to the second)
  local currentTime = time()
  if currentTime ~= self.lastProcessTime then
    self:flushLogs(currentTime)
    self.lastProcessTime = currentTime
  end

  -- If the lobby changed tell everyone
  self:broadCastLobbyIfChanged()
end

---Drain KO arbitration windows for any rooms whose window has closed.
function Server:tickArbitrations()
  local nowMs = math.floor(socket.gettime() * 1000)
  for _, room in pairs(self.rooms) do
    if room then
      room:tickArbitration(nowMs)
    end
  end
end

-- Accept any new connections to the server
function Server:acceptNewConnections()
  local newConnectionSocket = self.socket:accept()
  if newConnectionSocket then
    newConnectionSocket:settimeout(0)
    logger.debug("Accepted connection " .. self.connectionNumberIndex)
    local connection = Connection(newConnectionSocket, self.connectionNumberIndex)
    self.socketToConnectionIndex[newConnectionSocket] = self.connectionNumberIndex
    self:addConnection(connection)
  end
end

function Server:addConnection(connection)
  self.connections[self.connectionNumberIndex] = connection
  self.connectionNumberIndex = self.connectionNumberIndex + 1
end

-- Process any data on all active connections
function Server:updateConnections()
  -- Make a list of all the sockets to listen to
  local socketsToRead = {self.socket}
  -- Make a list of all the sockets we want to send messages to
  -- the server socket cannot "send" in the traditional sense, only accept incoming connections (which is in the read domain) so it is not added here
  local socketsToSend = {}
  for _, v in pairs(self.connections) do
    if v.outgoingMessageQueue:len() > 0 then
      -- socket.select(_, socketsToSend) only checks if at least one socket in the table is generally ready to send even if there is no data to be sent
      -- predictably that is immediately true for most client sockets most of the time
      -- so only check for sockets we actually have something to send for because sockets ready for sending will make the select return instantly
      --  causing us to loop very busily even though there is possibly nothing to do
      socketsToSend[#socketsToSend+1] = v.socket
    end
    -- whereas for read, we can check for all of them because they will only make select return if there is actually something to read
    socketsToRead[#socketsToRead + 1] = v.socket
  end

  -- Wait for up to 1 second to see if there is any socket to read / write on
  -- the waiting time is only until at least one socket has data to read or a socket we want to send data on is ready so it's not actually stalling unless there is no data anyway
  socketsToRead, socketsToSend = socket.select(socketsToRead, socketsToSend, 1)

  for _, connection in pairs(self.connections) do
    local canRead = not not socketsToRead[connection.socket]
    local canSend = not not socketsToSend[connection.socket]
    local success = connection:update(self.lastProcessTime, canRead, canSend)
    if not success then
      local player = self.connectionToPlayer[connection]
      local reason = "disconnect"
      if player then
        reason = player.name .. "'s connection failed"
      end
      self:closeConnection(connection, reason)
    end
  end
end

local function error_printer(msg, layer)
	logger.error((debug.traceback("Error: " .. tostring(msg), 1+(layer or 1)):gsub("\n[^\n]+$", "")))
end

local function handleError(msg)
  msg = tostring(msg)

	error_printer(msg, 2)

  local trace = debug.traceback()
  ---@type any
  local sanitizedMsgTable = {}
	for char in msg:gmatch(utf8.charpattern) do
		table.insert(sanitizedMsgTable, char)
	end
	local sanitizedmsg = table.concat(sanitizedMsgTable)

	local err = {}

	table.insert(err, "Error\n")
	table.insert(err, sanitizedmsg)

	if #sanitizedmsg ~= #msg then
		table.insert(err, "Invalid UTF-8 string in error message.")
	end

	table.insert(err, "\n")

  for line in trace:gmatch("(.-)\n") do
    if not line:match("boot.lua") then
      line = line:gsub("stack traceback:", "Traceback\n")
      table.insert(err, line)
		end
	end

	local p = table.concat(err, "\n")

	p = p:gsub("\t", "")
	p = p:gsub("%[string \"(.-)\"%]", "%1")

  logger.error(p)
end

function Server:processMessages()
  for index, connection in pairs(self.connections) do
    if connection.incomingInputQueue.last ~= -1 then
      local q = connection.incomingInputQueue
      local player = self.connectionToPlayer[connection]
      if player then
        local room = self.playerToRoom[player]
        if room then
          for i = q.first, q.last do
            self.playerToRoom[player]:broadcastInput(q[i], player)
          end
        end
      end
      q:shallowClear()
    end

    if connection.incomingGarbageQueue.last ~= -1 then
      local q = connection.incomingGarbageQueue
      local player = self.connectionToPlayer[connection]
      if player then
        local room = self.playerToRoom[player]
        if room then
          for i = q.first, q.last do
            room:broadcastGarbageEvent(player, q[i])
          end
        end
      end
      q:shallowClear()
    end

    if connection.incomingDeathQueue.last ~= -1 then
      local q = connection.incomingDeathQueue
      local player = self.connectionToPlayer[connection]
      if player then
        local room = self.playerToRoom[player]
        if room then
          for i = q.first, q.last do
            room:broadcastDeathEvent(player, q[i])
          end
        end
      end
      q:shallowClear()
    end

    if connection.incomingMessageQueue.last ~= -1 then
      local q = connection.incomingMessageQueue
      local player = self.connectionToPlayer[connection]
      for i = q.first, q.last do
        local status, continue = xpcall(function() return self:processMessage(q[i], connection) end, handleError)
        if status then
          if not continue then
            break
          end
        else
          if player then
            logger.error("Incoming message from " .. (player.name or connection.index) .. " in state " .. (player.state or "unknown") .. " caused an error." .. "\nJ-Message:\n" .. q[i])
            if self.playerToRoom[player] then
              logger.error("Room state during error:\n" .. self.playerToRoom[player]:toString())
            end
          else
            logger.error("Incoming message from " .. connection.index .. " caused an error." .. "\nJ-Message:\n" .. q[i])
          end
        end
      end
      q:clear()
    end
  end
end

---@param connection Connection
---@return boolean? # if messages from this connection should continue to get processed
function Server:processMessage(message, connection)
  message = json.decode(message)
  message = ClientMessages.sanitizeMessage(message)

  if message.error_report then -- Error report is checked for first so that a full login is not required
    self:handleErrorReport(message.error_report)
    -- After sending the error report, the client will throw the error, so end the connection.
    local player = self.connectionToPlayer[connection]
    if player then
      self:closeConnection(connection, player.name ..  " crashed")
    else
      self:closeConnection(connection)
    end
    return false
  elseif not connection.loggedIn then
    if message.login_request then
      local IP_logging_in, port = connection.socket:getpeername()
      if self:login(connection, message.user_id, message.name, IP_logging_in, port, message.engine_version, message) then
        return true
      else
        return false
      end
    else
      self:closeConnection(connection, "login while logged in")
      return false
    end
  else
    local player = self.connectionToPlayer[connection]
    if message.logout then
      self:closeConnection(connection, player.name .. " logged out")
      return false
    elseif message.challengeUpdate then
      local receiver = self.publicIdToPlayer[message.challengeUpdate.receiverId]
      local isRoomInvite = message.challengeUpdate.roomNumber ~= nil
      local senderCanSend = player.state == "lobby" or (isRoomInvite and player.state == "character select")
      if message.challengeUpdate.senderId == player.publicPlayerID and receiver and senderCanSend then
        self:processChallengeUpdate(
          player,
          receiver,
          message.challengeUpdate.gameModeId,
          message.challengeUpdate.challengeActive,
          message.challengeUpdate.roomNumber,
          message.challengeUpdate.slotNumber
        )
        return true
      end
    elseif message.roomRequest and (player.state == "lobby" or (player.state == "character select" and self.playerToRoom[player] and not self.playerToRoom[player]:isFull() and not self.playerToRoom[player].game)) then
      logger.warn("roomRequest received from " .. player.name .. " state=" .. player.state .. " mode=" .. tostring(message.gameMode and message.gameMode.name) .. " latency=" .. tostring(message.latencyTolerance))
      local requestedGameMode = resolveRequestedGameMode(message.gameMode)
      if requestedGameMode then
        -- If the player is in a partial (not-yet-full, no match started) room with
        -- no one else in it yet, close it first so they can switch room config
        -- from the lobby UI without having to explicitly leave.
        -- Reject the request when other players have already joined — otherwise
        -- closing the room here yanks invitees out of CharacterSelect and the
        -- team match never starts.
        local existingRoom = self.playerToRoom[player]
        if existingRoom then
          if #existingRoom.players > 1 then
            logger.warn("Rejected roomRequest from " .. player.name .. ": existing room " .. tostring(existingRoom.roomNumber) .. " has " .. #existingRoom.players .. " players")
            return false
          end
          self:closeRoom(existingRoom, "host changed room settings")
        end

        requestedGameMode.latencyTolerance = message.latencyTolerance
        -- For dynamic-roster modes (open_ffa) playerCount is nil at request time;
        -- fall back to maxPlayers. latencyTolerance still drives the connection
        -- watchdog (timeout/retry) — only the lockstep abort gap is gone.
        local effectiveCount = requestedGameMode.playerCount or requestedGameMode.maxPlayers or 2
        requestedGameMode.connectionTimeoutSeconds, requestedGameMode.sendRetryLimit = resolveConnectionWatchdogSettings(message.latencyTolerance, effectiveCount)
        self:create_room(requestedGameMode, player)
        return true
      else
        logger.warn("Rejected roomRequest from " .. player.name .. ": unknown/invalid game mode payload " .. tostring(message.gameMode and message.gameMode.name or message.gameMode and message.gameMode.gameModeId or message.gameMode))
        return false
      end

    elseif player.state == "lobby" and message.joinRoomRequest then
      logger.info("Received joinRoomRequest from " .. player.name .. " for room " .. tostring(message.joinRoomRequest.roomNumber) .. " slot " .. tostring(message.joinRoomRequest.slotNumber))
      self:handleJoinRoom(player, message.joinRoomRequest.roomNumber, message.joinRoomRequest.slotNumber)
      return true
    elseif message.leaderboard_request then
      connection:sendJson(ServerProtocol.sendLeaderboard(self.leaderboard:get_report(self, self.connectionToPlayer[connection].userId)))
      return true
    elseif message.spectate_request then
      self:handleSpectateRequest(message, player)
      return true
    elseif message.playerSettings then
      -- Note this also starts the game if everything is ready from both players character select settings
      player:updateSettings(message.playerSettings)
      return true
    elseif player.state == "playing" and message.taunt then
      self.playerToRoom[player]:handleTaunt(message, player)
      return true
    elseif player.state == "playing" and message.game_over then
      -- Revisit when we have real annotations on server
      ---@diagnostic disable-next-line: param-type-mismatch
      self.playerToRoom[player]:handleGameOverOutcome(message, player)
      return true
    elseif message.stackEliminated then
      -- Always consume — even if it arrives after the room transitioned out of "playing"
      -- (close-room race), it's a harmless no-op. Dropping the elseif's state check also
      -- prevents the message-processing loop from discarding everything queued behind it.
      if (player.state == "playing" or player.state == "paused") and self.playerToRoom[player] then
        self.playerToRoom[player]:handleStackEliminated(player, message.frame)
      end
      return true
    elseif (player.state == "playing" or player.state == "paused") and message.matchAbort then
      self.playerToRoom[player]:handleGameAbort(player)
    elseif (player.state == "playing" or player.state == "character select" or player.state == "paused") and message.leave_room then
      self:handleLeaveRoom(player, player.name .. " left")
      return true
    elseif (player.state == "playing" or player.state == "paused") and message.type == "pauseToggle" then
      self.rooms[message.roomNumber]:togglePause(player, message.paused)
    elseif (player.state == "spectating") and message.leave_room then
      if self.spectatorToRoom[player] and self.spectatorToRoom[player]:remove_spectator(player) then
        self:setLobbyChanged()
        return true
      end
    elseif message.unknown then
      self:closeConnection(connection)
      return false
    end
  end
  return false
end

function Server:handleErrorReport(errorReport)
  logger.warn("Received an error report.")
  if not FileIO.write_error_report(errorReport) then
    logger.error("The error report was either too large or had an I/O failure when attempting to write the file.")
  end
end

-- Flush the log so we can see new info periodically. The default caches for huge amounts of time.
function Server:flushLogs(currentTime)
  if currentTime - self.lastFlushTime > 60 then
    pcall(
      function()
        io.stdout:flush()
      end
    )
    self.lastFlushTime = currentTime
  end
end

function Server:broadCastLobbyIfChanged()
  if self.lobbyChanged then
    local lobbyStateV2 = self:lobbyStateV2()
    local messageV2 = ServerProtocol.lobbyStateV2(lobbyStateV2.players, lobbyStateV2.rooms)
    for _, connection in pairs(self.connections) do
      local player = self.connectionToPlayer[connection]
      if player then
        -- Send to lobby players and players in partial rooms.
        -- Full rooms should transition via room/game messages instead of another lobby snapshot.
        local inLobby = player.state == "lobby"
        local inPartialRoom = false
        local room = self.playerToRoom[player]
        if room and not room:isFull() then
          inPartialRoom = true
        end
        if inLobby or inPartialRoom then
          connection:sendJson(messageV2)
        end
      end
    end
    self.lobbyChanged = false
  end
end

---@param connection Connection
---@param userId privateUserId?
---@param name string
---@param ipAddress string
---@param port integer
---@param engineVersion string
---@param loginMessage ServerIncomingLoginMessage
---@return boolean # whether the login was successful
function Server:login(connection, userId, name, ipAddress, port, engineVersion, loginMessage)
  local message = {}

  logger.debug("New login attempt:  " .. ipAddress .. ":" .. port)

  local playerBan = self:getBanByIP(ipAddress)
  if playerBan then
    local secondsRemaining = (playerBan.completionTime - os.time())

    reason = playerBan.reason
    banDuration = "Ban Remaining: " .. util.toDayHourMinuteSecondString(secondsRemaining)

    self:markBanAsSeen(playerBan.banID)
    logger.warn("Login denied because of ban: " .. playerBan.reason)
    connection:sendJson(ServerProtocol.denyLogin(reason, banDuration))

    return false
  end

  local loginApproved, denyReason = self:canLogin(userId, name, ipAddress, engineVersion)

  if not loginApproved then
    connection:sendJson(ServerProtocol.denyLogin(denyReason))
    return false
  else
    if userId == "need a new user id" then
      assert(self.playerbase:nameTaken("", name) == false)
      userId = self:createNewUser(name)
      if not userId then
        connection:sendJson(ServerProtocol.denyLogin("Failed to assign public player ID, please try again"))
        return false
      else
        logger.info("New user: " .. name .. " was created")
        message.new_user_id = userId
      end
    end

    ---@cast userId -nil

    -- Name change is allowed because it was already checked above
    if self.playerbase.players[userId] ~= name then
      local oldName = self.playerbase.players[userId]
      self:changeUsername(userId, name)

      logger.warn(userId .. " changed name " .. oldName .. " to " .. name)

      message.name_changed = true
      message.old_name = oldName
      message.new_name = name
    end

    local player = Player(userId, connection, name, self.playerbase.privateIdToPublicId[userId])
    player.save_replays_publicly = loginMessage.save_replays_publicly
    player:setState("lobby")
    assert(player.publicPlayerID ~= nil)
    player:updateSettings(loginMessage.playerSettings)
    self.nameToConnectionIndex[name] = connection.index
    self.connectionToPlayer[connection] = player
    self.publicIdToPlayer[player.publicPlayerID] = player
    self.nameToPlayer[name] = player
    if self.leaderboard then
      self.leaderboard:update_timestamp(userId)
    end
    self:logIP(player, ipAddress)
    self:setLobbyChanged()

    local serverNotices = self:getMessages(player)
    local serverUnseenBans = self:getUnseenBans(player)
    if tableUtils.length(serverNotices) > 0 or tableUtils.length(serverUnseenBans) > 0 then
      local noticeString = ""
      for messageID, serverNotice in pairs(serverNotices) do
        noticeString = noticeString .. serverNotice .. "\n\n"
        self:markMessageAsSeen(messageID)
      end
      for banID, reason in pairs(serverUnseenBans) do
        noticeString = noticeString .. "A ban was issued to you for: " .. reason .. "\n\n"
        self:markBanAsSeen(banID)
      end
      message.server_notice = noticeString
    end

    message.login_successful = true
    connection:sendJson(ServerProtocol.approveLogin(player.publicPlayerID, message.server_notice, message.new_user_id, message.new_name, message.old_name))

    logger.warn(connection.index .. " Login from " .. name .. " with ip: " .. ipAddress .. " publicPlayerID: " .. player.publicPlayerID)
    return true
  end
end

---@return boolean loginApproved if the player can log in
---@return string denyReason why the player cannot log in, nil if login was approved
function Server:canLogin(userID, name, IP_logging_in, engineVersion)
  local denyReason = nil
  if engineVersion ~= ENGINE_VERSION and not ANY_ENGINE_VERSION_ENABLED then
    denyReason = "Please update your game, server expects engine version: " .. ENGINE_VERSION
  elseif not name or name == "" then
    denyReason = "Name cannot be blank"
  elseif string.lower(name) == "anonymous" then
    denyReason = 'Username cannot be "anonymous"'
  elseif name:lower():match("d+e+f+a+u+l+t+n+a+m+e?") then
    denyReason = 'Username cannot be "defaultname" or a variation of it'
  elseif name:find("[^_%w]") then
    denyReason = "Usernames are limited to alphanumeric and underscores"
  elseif utf8.len(name) > NAME_LENGTH_LIMIT then
    denyReason = "The name length limit is " .. NAME_LENGTH_LIMIT .. " characters"
  elseif not userID then
    denyReason = "Client did not send a user ID in the login request"
  elseif userID == "need a new user id" then
    if self.playerbase:nameTaken("", name) then
      denyReason = "That player name is already taken"
      logger.warn("Login failure: Player tried to create a new user with an already taken name: " .. name)
    end
  elseif not self.playerbase.players[userID] then
    denyReason = "The user ID provided was not found on this server"
    playerBan = self:insertBan(IP_logging_in, denyReason, os.time() + 60)
    logger.warn("Login failure: " .. name .. " specified an invalid user ID")
  elseif self.playerbase.players[userID] ~= name and self.playerbase:nameTaken(userID, name) then
    denyReason = "That player name is already taken"
    logger.warn("Login failure: Player (" .. userID .. ") tried to use already taken name: " .. name)
  elseif self.nameToConnectionIndex[name] then
    denyReason = "Cannot login with the same name twice"
  end

  if denyReason then
    return false, denyReason
  else
    return true, ""
  end
end

---@param message table
---@param player ServerPlayer
function Server:handleSpectateRequest(message, player)
  local requestedRoom = self.rooms[message.spectate_request.roomNumber]

  if self.playerToRoom[player] then
    logger.warn("Player " .. player.name .. " tried to spectate while being in room " .. self.playerToRoom[player].roomNumber)
    return
  end

  if requestedRoom then
    if requestedRoom.reservedSlots[player.publicPlayerID] then
      logger.info("Player " .. player.name .. " has a reserved slot in room " .. requestedRoom.roomNumber .. " — redirecting spectate to player join")
      self:handleJoinRoom(player, requestedRoom.roomNumber, nil)
      return
    end
    local roomState = requestedRoom:state()
    if (roomState == "character select" or roomState == "playing" or roomState == "paused") then
      logger.debug("adding " .. player.name .. " to room nr " .. message.spectate_request.roomNumber)
      local currentSpectatorRoom = self.spectatorToRoom[player]
      if currentSpectatorRoom and currentSpectatorRoom ~= requestedRoom then
        currentSpectatorRoom:remove_spectator(player)
        self.spectatorToRoom[player] = nil
      end

      if requestedRoom:add_spectator(player) then
        self.spectatorToRoom[player] = requestedRoom
        self:setLobbyChanged()
      else
        logger.warn("Failed to add spectator " .. player.name .. " to room " .. requestedRoom.roomNumber)
      end
    else
      logger.warn("tried to join room in invalid state " .. roomState)
    end
  else
    -- TODO: tell the client the join request failed, couldn't find the room.
    logger.warn("couldn't find room")
  end
end

function Server:handleLeaveRoom(player, reason)
  local room = self.playerToRoom[player]
  if room then
    -- Use voidByLeave when the room is multi-player (3+ at start) OR was already
    -- voided by a previous leave. The latter is important: once we void a room,
    -- subsequent leaves should keep removing players one at a time so survivors
    -- can keep viewing — not collapse the whole thing on the second leaver. Only
    -- 2-player VS rooms and solo rooms collapse immediately on a single leave.
    if #room.players >= 3 or room.voided then
      self.playerToRoom[player] = nil
      player:removeFromRoom(room, reason)  -- sends leaveRoom to leaver, sets state=lobby
      room:voidByLeave(player, reason)     -- aborts in-progress match, removes leaver, broadcasts playerLeftRoom
      if #room.players == 0 then
        self:closeRoom(room, "all players left")
      else
        self:setLobbyChanged()
      end
    else
      self:closeRoom(room, reason)
    end
  else
    room = self.spectatorToRoom[player]
    if room then
      room:remove_spectator(player)
      self.spectatorToRoom[player] = nil
    end
  end
end

---@param connection Connection
---@param reason string? why the player is getting disconnected
function Server:closeConnection(connection, reason)
  local player = self.connectionToPlayer[connection]
  logger.info("Closing connection " .. connection.index .. " to " .. (player and player.name or "noname"))

  self.socketToConnectionIndex[connection.socket] = nil
  self.connections[connection.index] = nil
  self.connectionToPlayer[connection] = nil
  connection.loggedIn = false
  connection:close()
  if player then
    self:clearProposals(player)
    -- All disconnects (mid-match or otherwise) route through handleLeaveRoom now.
    -- For 2P rooms it closes the whole room; for 3+ rooms it voids the room (aborts
    -- any in-progress match, removes the leaver, broadcasts playerLeftRoom) so
    -- remaining players can see the final state until they manually leave.
    self:handleLeaveRoom(player, reason)
    self.publicIdToPlayer[player.publicPlayerID] = nil
    self.playerToRoom[player] = nil
    self.spectatorToRoom[player] = nil
    self.nameToPlayer[player.name] = nil
    self.nameToConnectionIndex[player.name] = nil
    self:setLobbyChanged()
  end
end

---@param game ServerGame
function Server:processGameEnd(game)
  logger.debug("Processing game end")
  self:setLobbyChanged()

  -- this is a sufficient criteria only by incidence as it remains the only 2 player online game mode so far
  -- there needs to be a better mechanism to validate whether a game should be persisted / persisted for a leaderboard
  -- as the current persistGame somewhat assumes both (explicit player number and that the game was played to determine a winner/placement)
  if game and game.complete and game.replay.metadata.gameModeName == "VS" then
    self.persistence.persistGame(game)
  end
end

---@param player ServerPlayer
---@param ipAddress string
function Server:logIP(player, ipAddress)
  self.database:insertIPID(ipAddress, player.publicPlayerID)
end

-- gets the messages for that player
---@param player ServerPlayer
---@return table<integer, string>
function Server:getMessages(player)
  return self.database:getPlayerMessages(player.publicPlayerID)
end

-- gets the bans for that player they did not see yet
---@param player ServerPlayer
---@return table<BanID, string>
function Server:getUnseenBans(player)
  return self.database:getPlayerUnseenBans(player.publicPlayerID)
end

---@param banId integer
function Server:markBanAsSeen(banId)
  self.database:playerBanSeen(banId)
end

---@param messageId integer
function Server:markMessageAsSeen(messageId)
  self.database:playerMessageSeen(messageId)
end

return Server
