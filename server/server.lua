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
local GameModes = require("common.engine.GameModes")

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
---@field leaderboard Leaderboard
---@field persistence Persistence
---@field _shuttingDown boolean
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
    self.playerToRoom = {}
    self.spectatorToRoom = {}
    self.nameToPlayer = {}
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

function Server:start()
  logger.info("Starting up server with port: " .. (SERVER_PORT or 49569))
  local s = socket.bind("*", SERVER_PORT or 49569)
  if s then
    self.socket = s
  else
    error("Failed to create server socket. Check if there are any other instances blocking the port")
  end
  self.socket:settimeout(0)
  if TCP_NODELAY_ENABLED then
    self.socket:setoption("tcp-nodelay", true)
  end

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

local function addPublicPlayerData(players, player, ratingInfo)
  if not players or not ratingInfo then
    return
  end

  if not players[player.name] then
    players[player.name] = { publicId = player.publicPlayerID }
  end

  if ratingInfo and ratingInfo.placement_done then
    players[player.name].rating = math.round(ratingInfo.rating)
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
    if player then
      logger.debug("Player " .. player.name .. " state is " .. player.state)
    end
    if player and player.state == "lobby" then
      names[#names + 1] = player.name
      addPublicPlayerData(players, player, (self.leaderboard and self.leaderboard.players[player.userId] or nil))
    end
  end
  local spectatableRooms = {}
  for _, room in pairs(self.rooms) do
    spectatableRooms[#spectatableRooms + 1] = {roomNumber = room.roomNumber, name = room.name, state = room:state()}
    for i, player in ipairs(room.players) do
      if i == 1 then
        spectatableRooms[#spectatableRooms].a = room.players[i].name
      else
        spectatableRooms[#spectatableRooms].b = room.players[i].name
      end
      addPublicPlayerData(players, player, (self.leaderboard and self.leaderboard.players[player.userId] or nil))
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
        self:create_room(GameModes.getPreset("TWO_PLAYER_VS"), sender, receiver)
      end
    else
      receiver:sendJson(ServerProtocol.sendChallenge(sender, receiver))
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

---@param gameMode GameMode
---@param ... ServerPlayer
function Server:create_room(gameMode, ...)
  self:setLobbyChanged()
  local players = {...}
  local leaderboard
  if self.leaderboard and deep_content_equal(gameMode, self.leaderboard.gameMode) then
    leaderboard = self.leaderboard
  end
  local newRoom = Room(self.roomNumberIndex, players, gameMode, leaderboard)
  newRoom:connectSignal("matchStart", self, self.setLobbyChanged)
  newRoom:connectSignal("matchEnd", self, self.processGameEnd)
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
  return tostring(new_user_id)
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

---@param room Room
function Server:closeRoom(room, reason)
  for _, player in ipairs(room.players) do
    self.playerToRoom[player] = nil
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

function Server:update()

  if not self._shuttingDown then
    self:acceptNewConnections()
  end

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
  local socketsToCheck = {self.socket}
  for _, v in pairs(self.connections) do
    socketsToCheck[#socketsToCheck + 1] = v.socket
  end

  -- Wait for up to 1 second to see if there is any data to read on all the given sockets
  -- as far as I understand the waiting time is only until at least one socket has data so it's not actually stalling unless there is no data anyway
  local socketsWithData = socket.select(socketsToCheck, nil, 1)
  assert(type(socketsWithData) == "table")
  for _, currentSocket in ipairs(socketsWithData) do
    local connectionIndex = self.socketToConnectionIndex[currentSocket]
    if connectionIndex then
      local connection = self.connections[connectionIndex]
      local success = connection:update(self.lastProcessTime)
      if not success then
        local player = self.connectionToPlayer[connection]
        local reason = "disconnect"
        if player then
          reason = player.name .. "'s connection failed"
        end
        self:closeConnection(self.connections[connectionIndex], reason)
      end
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
  local sanitizedmsg = {}
	for char in msg:gmatch(utf8.charpattern) do
		table.insert(sanitizedmsg, char)
	end
	sanitizedmsg = table.concat(sanitizedmsg)

	local err = {}

	table.insert(err, "Error\n")
	table.insert(err, sanitizedmsg)

	if #sanitizedmsg ~= #msg then
		table.insert(err, "Invalid UTF-8 string in error message.")
	end

	table.insert(err, "\n")

	for l in trace:gmatch("(.-)\n") do
		if not l:match("boot.lua") then
			l = l:gsub("stack traceback:", "Traceback\n")
			table.insert(err, l)
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
    self:closeConnection(connection, "crashed")
    return false
  elseif not connection.loggedIn then
    if message.login_request then
      local IP_logging_in, port = connection.socket:getpeername()
      if self:login(connection, message.user_id, message.name, IP_logging_in, port, message.engine_version, message) then
        return true
      else
        self:closeConnection(connection, "login while logged in")
        return false
      end
    else
      self:closeConnection(connection)
      return false
    end
  else
    local player = self.connectionToPlayer[connection]
    if message.logout then
      self:closeConnection(connection, player.name .. " logged out")
      return false
    elseif player.state == "lobby" and message.game_request then
      if message.game_request.sender == player.name then
        self:proposeGame(player, self.nameToPlayer[message.game_request.receiver])
        return true
      end
    elseif player.state == "lobby" and message.roomRequest then
      self:create_room(message.gameMode, player)
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
      self.playerToRoom[player]:handleGameOverOutcome(message, player)
      return true
    elseif (player.state == "playing") and message.matchAbort then
      self.playerToRoom[player]:abortGame(player)
    elseif (player.state == "playing" or player.state == "character select") and message.leave_room then
      self:handleLeaveRoom(player, player.name .. " left")
      return true
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
    local lobbyState = self:lobby_state()
    local message = ServerProtocol.lobbyState(lobbyState.unpaired, lobbyState.spectatable, lobbyState.players)
    for _, connection in pairs(self.connections) do
      local player = self.connectionToPlayer[connection]
      if player and player.state == "lobby" then
        connection:sendJson(message)
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
---@param playerSettings table
---@return boolean # whether the login was successful
function Server:login(connection, userId, name, ipAddress, port, engineVersion, playerSettings)
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
    player:setState("lobby")
    assert(player.publicPlayerID ~= nil)
    player:updateSettings(playerSettings)
    self.nameToConnectionIndex[name] = connection.index
    self.connectionToPlayer[connection] = player
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

function Server:handleLeaveRoom(player, reason)
  local room = self.playerToRoom[player]
  if room then
    self:closeRoom(room, reason)
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
    self:handleLeaveRoom(player, reason)
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
  if game and game.complete and #game.replay.players == 2 then
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
---@return table<integer, string>
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
