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
require("server.server_file_io")
local Connection = require("server.Connection")
local Leaderboard = require("server.Leaderboard")
require("server.PlayerBase")
local Room = require("server.Room")
local ClientMessages = require("server.ClientMessages")
local utf8 = require("common.lib.utf8Additions")
local tableUtils = require("common.lib.tableUtils")
local Player = require("server.Player")

local pairs = pairs
local ipairs = ipairs
local time = os.time

---@alias privateUserId integer | string

-- Represents the full server object.
-- Currently we are transitioning variables into this, but to start we will use this to define API
---@class Server
---@field socket TcpSocket the master socket for accepting incoming client connections
---@field database table the database object
---@field connectionNumberIndex integer GLOBAL counter of the next available connection index
---@field roomNumberIndex integer the next available room number
---@field rooms Room[] mapping of room number to room
---@field proposals table<ServerPlayer, table<ServerPlayer, table>> mapping of player name to a mapping of the players they have challenged
---@field connections Connection[] mapping of connection number to connection
---@field nameToConnectionIndex table<string, integer> mapping of player names to their unique connectionNumberIndex
---@field socketToConnectionIndex table<TcpSocket, integer> mapping of sockets to their unique connectionNumberIndex
---@field connectionToPlayer table<Connection, ServerPlayer> Mapping of connections to the player they send for
---@field playerToRoom table<ServerPlayer, Room>
---@field spectatorToRoom table<ServerPlayer, Room>
---@field nameToPlayer table<string, ServerPlayer>
---@field lastProcessTime integer
---@field lastFlushTime integer timestamp for when logs were last flushed to file
---@field lobbyChanged boolean if new lobby data should be sent out on the next loop
---@field playerbase table
local Server =
  class(
  function(self, databaseParam)
    self.connectionNumberIndex = 1
    self.roomNumberIndex = 1
    self.rooms = {}
    self.proposals = {}
    self.connections = {}
    self.players = {}
    self.nameToConnectionIndex = {}
    self.socketToConnectionIndex = {}
    self.connectionToPlayer = {}
    self.playerToRoom = {}
    self.spectatorToRoom = {}
    self.nameToPlayer = {}
    assert(databaseParam ~= nil)
    self.database = databaseParam
    self.lastProcessTime = time()
    self.lastFlushTime = self.lastProcessTime
    self.lobbyChanged = false

    logger.info("Starting up server with port: " .. (SERVER_PORT or 49569))
    self.socket = socket.bind("*", SERVER_PORT or 49569)
    self.socket:settimeout(0)
    if TCP_NODELAY_ENABLED then
      self.socket:setoption("tcp-nodelay", true)
    end

    self.playerbase = Playerbase("playerbase", "players.txt")
    read_players_file(self.playerbase)
    leaderboard = Leaderboard("leaderboard")
    read_leaderboard_file()

    local isPlayerTableEmpty = self.database:getPlayerRecordCount() == 0
    if isPlayerTableEmpty then
      self:importDatabase()
    end

    logger.debug("leaderboard json:")
    logger.debug(json.encode(leaderboard.players))
    write_leaderboard_file()
    logger.debug(os.time())
    logger.debug("playerbase: " .. json.encode(self.playerbase.players))
    logger.debug("leaderboard report: " .. json.encode(leaderboard:get_report(self)))
    read_csprng_seed_file()
    initialize_mt_generator(csprng_seed)
    seed_from_mt(extract_mt())
    --timezone testing
    -- print("server_UTC_offset (in seconds) is "..tzoffset)
    -- print("that's "..(tzoffset/3600).." hours")
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
    -- print("get_timezone() output: "..get_timezone())
    -- print("get_timezone_offset(os.time()) output: "..get_timezone_offset(os.time()))
    -- print("get_tzoffset(get_timezone()) output:"..get_tzoffset(get_timezone()))    
  end
)

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
    if leaderboard.players[k] then
      rating = leaderboard.players[k].rating
    end
    self.database:insertNewPlayer(k, v)
    self.database:insertPlayerELOChange(k, rating, 0)
  end

  local gameMatches = readGameResults()
  if gameMatches then -- only do it if there was a gameResults file to begin with
    logger.info("Importing GameResults.csv to database")
    for _, result in ipairs(gameMatches) do
      local player1ID = result[1]
      local player2ID = result[2]
      local player1Won = result[3] == 1
      local ranked = result[4] == 1
      local gameID = self.database:insertGame(ranked)
      if player1Won then
        self.database:insertPlayerGameResult(player1ID, gameID, nil,  1)
        self.database:insertPlayerGameResult(player2ID, gameID, nil,  2)
      else
        self.database:insertPlayerGameResult(player2ID, gameID, nil,  1)
        self.database:insertPlayerGameResult(player1ID, gameID, nil,  2)
      end
    end
  end
  self.database:commitTransaction() -- bulk commit every statement from the start of beginTransaction
end

local function addPublicPlayerData(players, playerName, player)
  if not players or not player then
    return
  end

  if not players[playerName] then
    players[playerName] = {}
  end

  if player.rating then
    players[playerName].rating = math.round(player.rating)
  end

  if player.ranked_games_played then
    players[playerName].ranked_games_played = player.ranked_games_played
  end
end

function Server:setLobbyChanged()
  self.lobbyChanged = true
end

function Server:lobby_state()
  local names = {}
  local players = {}
  for _, connection in pairs(self.connections) do
    local player = self.connectionToPlayer[connection]
    if player.state == "lobby" then
      names[#names + 1] = player.name
      addPublicPlayerData(players, player.name, leaderboard.players[player.userId])
    end
  end
  local spectatableRooms = {}
  for _, room in pairs(self.rooms) do
    spectatableRooms[#spectatableRooms + 1] = {roomNumber = room.roomNumber, name = room.name, a = room.players[1].name, b = room.players[2].name, state = room:state()}
    for i, player in ipairs(room.players) do
      addPublicPlayerData(players, player.name, leaderboard.players[player.userId])
    end
  end
  return {unpaired = names, spectatable = spectatableRooms, players = players}
end

---@param sender ServerPlayer
---@param receiver ServerPlayer
function Server:proposeGame(sender, receiver)
  logger.debug("propose game: " .. sender.name .. " " .. receiver.name)

  local proposals = self.proposals
  if sender and sender.state == "lobby" and receiver and receiver.state == "lobby" then
    proposals[sender] = proposals[sender] or {}
    proposals[receiver] = proposals[receiver] or {}
    if proposals[sender][receiver] then
      if proposals[sender][receiver][receiver] then
        self:create_room(sender, receiver)
      end
    else
      receiver:sendJson(ServerProtocol.sendChallenge(sender.name, receiver.name))
      local prop = {[sender] = true}
      proposals[sender][receiver] = prop
      proposals[receiver][sender] = prop
    end
  end
end

---@param player ServerPlayer
function Server:clearProposals(player)
  local proposals = self.proposals
  if proposals[player] then
    for otherPlayer, _ in pairs(proposals[player]) do
      proposals[player][otherPlayer] = nil
      if proposals[otherPlayer] then
        proposals[otherPlayer][player] = nil
      end
    end
    proposals[player] = nil
  end
end

---@param ... ServerPlayer
function Server:create_room(...)
  self:setLobbyChanged()
  local players = {...}
  local newRoom = Room(self.roomNumberIndex, leaderboard, self, players)
  newRoom:connectSignal("matchStart", self, self.lobbyChanged)
  newRoom:connectSignal("matchEnd", self, self.lobbyChanged)
  self.roomNumberIndex = self.roomNumberIndex + 1
  self.rooms[newRoom.roomNumber] = newRoom
  for _, player in ipairs(players) do
    self:clearProposals(player)
    self.playerToRoom[player] = newRoom
  end
end

---@param roomNr integer
---@return Room? room
function Server:roomNumberToRoom(roomNr)
  for k, v in pairs(self.rooms) do
    if self.rooms[k].roomNumber and self.rooms[k].roomNumber == roomNr then
      return v
    end
  end
end

---@param name string
---@return privateUserId
function Server:createNewUser(name)
  local user_id = nil
  while not user_id or self.playerbase.players[user_id] do
    user_id = self:generate_new_user_id()
  end
  self.playerbase:updatePlayer(user_id, name)
  self.database:insertNewPlayer(user_id, name)
  self.database:insertPlayerELOChange(user_id, 0, 0)
  return user_id
end

function Server:changeUsername(privateUserID, username)
  self.playerbase:updatePlayer(privateUserID, username)
  if leaderboard.players[privateUserID] then
    leaderboard.players[privateUserID].user_name = username
  end
  self.database:updatePlayerUsername(privateUserID, username)
end

---@return privateUserId new_user_id
function Server:generate_new_user_id()
  local new_user_id = cs_random()
  return tostring(new_user_id)
end

-- Checks if a logging in player is banned based off their IP.
---@param ip string
---@return boolean
function Server:isPlayerBanned(ip)
  return self.database:isPlayerBanned(ip)
end

---@param ip string
---@param reason string?
---@param completionTime integer
---@return PlayerBan?
function Server:insertBan(ip, reason, completionTime)
  return self.database:insertBan(ip, reason, completionTime)
end

---@param connection Connection
---@param reason string?
---@param ban PlayerBan?
function Server:denyLogin(connection, reason, ban)
  assert(ban == nil or reason == nil)
  local banDuration
  if ban then
    local banRemainingString = "Ban Remaining: "
    local secondsRemaining = (ban.completionTime - os.time())
    local secondsPerDay = 60 * 60 * 24
    local secondsPerHour = 60 * 60
    local secondsPerMin = 60
    local detailCount = 0
    if secondsRemaining > secondsPerDay then
      banRemainingString = banRemainingString .. math.floor(secondsRemaining / secondsPerDay) .. " days "
      secondsRemaining = (secondsRemaining % secondsPerDay)
      detailCount = detailCount + 1
    end
    if secondsRemaining > secondsPerHour then
      banRemainingString = banRemainingString .. math.floor(secondsRemaining / secondsPerHour) .. " hours "
      secondsRemaining = (secondsRemaining % secondsPerHour)
      detailCount = detailCount + 1
    end
    if detailCount < 2 and secondsRemaining > secondsPerMin then
      banRemainingString = banRemainingString .. math.floor(secondsRemaining / secondsPerMin) .. " minutes "
      secondsRemaining = (secondsRemaining % secondsPerMin)
      detailCount = detailCount + 1
    end
    if detailCount < 2 then
      banRemainingString = banRemainingString .. math.floor(secondsRemaining) .. " seconds "
    end
    reason = ban.reason
    banDuration = banRemainingString

    self.database:playerBanSeen(ban.banID)
    logger.warn("Login denied because of ban: " .. ban.reason)
  end

  connection:sendJson(ServerProtocol.denyLogin(reason, banDuration))
end

---@param room Room
function Server:closeRoom(room)
  for _, player in ipairs(room.players) do
    self.playerToRoom[player] = nil
  end

  for _, player in ipairs(room.spectators) do
    self.spectatorToRoom[player] = nil
  end

  if self.rooms[room.roomNumber] then
    self.rooms[room.roomNumber] = nil
  end

  room:close()
  self:setLobbyChanged()
end

function Server:update()

  self:acceptNewConnections()

  self:updateConnections()
  self:processMessages()

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

-- Accept any new connections to the server
function Server:acceptNewConnections()
  local newConnectionSocket = self.socket:accept()
  if newConnectionSocket then
    newConnectionSocket:settimeout(0)
    if TCP_NODELAY_ENABLED then
      newConnectionSocket:setoption("tcp-nodelay", true)
    end
    local connection = Connection(newConnectionSocket, self.connectionNumberIndex)
    logger.debug("Accepted connection " .. self.connectionNumberIndex)
    self.connections[self.connectionNumberIndex] = connection
    self.socketToConnectionIndex[newConnectionSocket] = self.connectionNumberIndex
    self.connectionNumberIndex = self.connectionNumberIndex + 1
  end
end

-- Process any data on all active connections
function Server:updateConnections()
  -- Make a list of all the sockets to listen to
  local socketsToCheck = {self.socket}
  for _, v in pairs(self.connections) do
    socketsToCheck[#socketsToCheck + 1] = v.socket
  end

  -- Wait for up to 1 second to see if there is any data to read on all the given sockets
  local socketsWithData = socket.select(socketsToCheck, nil, 1)
  assert(type(socketsWithData) == "table")
  for _, currentSocket in ipairs(socketsWithData) do
    if self.socketToConnectionIndex[currentSocket] then
      local connectionIndex = self.socketToConnectionIndex[currentSocket]
      local success = self.connections[connectionIndex]:update(self.lastProcessTime)
      if not success then
        self:closeConnection(self.connections[connectionIndex])
      end
    end
  end
end

function Server:processMessages()
  for index, connection in pairs(self.connections) do
    if connection.incomingMessageQueue:len() > 0 then
      local q = connection.incomingMessageQueue
      for i = q.first, q.last do
        local status, continue = pcall(function() return self:processMessage(q[i], connection) end)
        if status then
          if not continue then
            break
          end
        else
          local error = continue
          local player = self.connectionToPlayer[connection]
          logger.error("Incoming message from " .. player.name .. " in state " .. player.state .. " caused an error:\n" ..
                 " pcall error results: " .. tostring(error) ..
                 "\nJ-Message:\n" .. q[i])
          if self.playerToRoom[player] then
            logger.error("Room state during error:\n" .. self.playerToRoom[player]:toString())
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
    self:closeConnection(connection)
    return false
  elseif not connection.loggedIn then
    if message.login_request then
      local IP_logging_in, port = self.socket:getpeername()
      return self:login(connection, message.user_id, message.name, IP_logging_in, port, message.engine_version, message)
    else
      self:closeConnection(connection)
      return false
    end
  else
    local player = self.connectionToPlayer[connection]
    if message.logout then
      self:closeConnection(connection)
      return false
    elseif player.state == "lobby" and message.game_request then
      if message.game_request.sender == player.name then
        self:proposeGame(player, self.nameToPlayer[message.game_request.receiver])
        return true
      end
    elseif message.leaderboard_request then
      connection:sendJson(ServerProtocol.sendLeaderboard(leaderboard:get_report(self, self.connectionToPlayer[connection].userId)))
      return true
    elseif message.spectate_request then
      self:handleSpectateRequest(message, player)
      return true
    elseif player.state == "character select" and message.playerSettings then
      -- Note this also starts the game if everything is ready from both players character select settings
      player:updateSettings(message.playerSettings)
      return true
    elseif player.state == "playing" and message.taunt then
      self.playerToRoom[player]:handleTaunt(message, player)
      return true
    elseif player.state == "playing" and message.game_over then
      self.playerToRoom[player]:handleGameOverOutcome(message)
      return true
    elseif (player.state == "playing" or player.state == "character select") and message.leave_room then
      self:handleLeaveRoom(player)
      return true
    elseif (player.state == "spectating") and message.leave_room then
      if self.playerToRoom[player]:remove_spectator(player) then
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
  if not write_error_report(errorReport) then
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
    local lobbyState = self:lobby_state()
    local message = ServerProtocol.lobbyState(lobbyState.unpaired, lobbyState.spectatable, lobbyState.players)
    for _, connection in pairs(self.connections) do
      if self.connectionToPlayer[connection].state == "lobby" then
        connection:sendJson(message)
      end
    end
    self.lobbyChanged = false
  end
end

---@param connection Connection
---@param userId privateUserId
---@param name string
---@param ipAddress string
---@param port integer
---@param engineVersion string
---@param playerSettings table
---@return boolean # whether the login was successful
function Server:login(connection, userId, name, ipAddress, port, engineVersion, playerSettings)
  local message = {}

  logger.debug("New login attempt:  " .. ipAddress .. ":" .. port)

  local denyReason, playerBan = self:canLogin(userId, name, ipAddress, engineVersion)

  if denyReason ~= nil or playerBan ~= nil then
    self:denyLogin(connection, denyReason, playerBan)
    return false
  else
    if userId == "need a new user id" then
      assert(self.playerbase:nameTaken("", name) == false)
      userId = self:createNewUser(name)
      logger.info("New user: " .. name .. " was created")
      message.new_user_id = userId
    end

    -- Name change is allowed because it was already checked above
    if self.playerbase.players[userId] ~= name then
      local oldName = self.playerbase.players[userId]
      self:changeUsername(userId, name)

      logger.warn(userId .. " changed name " .. oldName .. " to " .. name)

      message.name_changed = true
      message.old_name = oldName
      message.new_name = name
    end

    local player = Player(userId, connection, name)
    player:updateSettings(playerSettings)
    assert(connection.player.publicPlayerID ~= nil)
    self.nameToConnectionIndex[name] = connection.index
    self.connectionToPlayer[connection] = player
    self.nameToPlayer[name] = player
    connection.loggedIn = true
    connection.player = player
    leaderboard:update_timestamp(userId)
    self.database:insertIPID(ipAddress, connection.player.publicPlayerID)
    self:setLobbyChanged()

    local serverNotices = self.database:getPlayerMessages(connection.player.publicPlayerID)
    local serverUnseenBans = self.database:getPlayerUnseenBans(connection.player.publicPlayerID)
    if tableUtils.length(serverNotices) > 0 or tableUtils.length(serverUnseenBans) > 0 then
      local noticeString = ""
      for messageID, serverNotice in pairs(serverNotices) do
        noticeString = noticeString .. serverNotice .. "\n\n"
        self.database:playerMessageSeen(messageID)
      end
      for banID, reason in pairs(serverUnseenBans) do
        noticeString = noticeString .. "A ban was issued to you for: " .. reason .. "\n\n"
        self.database:playerBanSeen(banID)
      end
      message.server_notice = noticeString
    end

    message.login_successful = true
    connection:sendJson(ServerProtocol.approveLogin(message.server_notice, message.new_user_id, message.new_name, message.old_name, connection.player.publicPlayerID))

    logger.warn(connection.index .. " Login from " .. name .. " with ip: " .. ipAddress .. " publicPlayerID: " .. connection.player.publicPlayerID)
    return true
  end
end

---@return string? denyReason
---@return PlayerBan? playerBan
function Server:canLogin(userID, name, IP_logging_in, engineVersion)
  local playerBan = self:isPlayerBanned(IP_logging_in)
  local denyReason = nil
  if playerBan then
  elseif engineVersion ~= ENGINE_VERSION and not ANY_ENGINE_VERSION_ENABLED then
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
    playerBan = self:insertBan(IP_logging_in, "The user ID provided was not found on this server", os.time() + 60)
    logger.warn("Login failure: " .. name .. " specified an invalid user ID")
  elseif self.playerbase.players[userID] ~= name and self.playerbase:nameTaken(userID, name) then
    denyReason = "That player name is already taken"
    logger.warn("Login failure: Player (" .. userID .. ") tried to use already taken name: " .. name)
  elseif self.nameToConnectionIndex[name] then
    denyReason = "Cannot login with the same name twice"
  end

  return denyReason, playerBan
end

---@param message table
---@param player ServerPlayer
function Server:handleSpectateRequest(message, player)
  local requestedRoom = self:roomNumberToRoom(message.spectate_request.roomNumber)

  if requestedRoom then
    local roomState = requestedRoom:state()
    if (roomState == "character select" or roomState == "playing") then
      logger.debug("adding " .. player.name .. " to room nr " .. message.spectate_request.roomNumber)
      self.spectatorToRoom[player] = requestedRoom
      requestedRoom:add_spectator(player)
      self:setLobbyChanged()
    else
      logger.warn("tried to join room in invalid state " .. roomState)
    end
  else
    -- TODO: tell the client the join request failed, couldn't find the room.
    logger.warn("couldn't find room")
  end
end

function Server:handleLeaveRoom(player)
  local room = self.playerToRoom[player]
  if room then
    self:closeRoom(room)
  else
    room = self.spectatorToRoom[player]
    if room then
      room:remove_spectator(player)
      self.spectatorToRoom[player] = nil
    end
  end
end

---@param connection Connection
function Server:closeConnection(connection)
  local player = self.connectionToPlayer[connection]
  logger.info("Closing connection " .. connection.index .. " to " .. player and player.name or "noname")

  self.socketToConnectionIndex[connection.socket] = nil
  self.connections[connection.index] = nil
  self.connectionToPlayer[connection] = nil
  connection:close()
  if player then
    self:clearProposals(player)
    self:handleLeaveRoom(player)
    self.playerToRoom[player] = nil
    self.spectatorToRoom[player] = nil
    self.nameToPlayer[player.name] = nil
    self.nameToConnectionIndex[player.name] = nil
    self:setLobbyChanged()
  end
end

return Server
