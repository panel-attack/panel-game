-- socket is bundled with love so the client requires love's socket
-- and the server requires the socket from common/lib
---@diagnostic disable-next-line: different-requires
local socket = require("common.lib.socket")
local logger = require("common.lib.logger")
local class = require("common.lib.class")
local NetworkProtocol = require("common.network.NetworkProtocol")
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
require("server.Leaderboard")
require("server.PlayerBase")
require("server.Room")

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
---@field proposals table mapping of player name to a mapping of the players they have challenged
---@field connections Connection[] mapping of connection number to connection
---@field nameToConnectionIndex table<string, integer> mapping of player names to their unique connectionNumberIndex
---@field socketToConnectionIndex table<TcpSocket, integer> mapping of sockets to their unique connectionNumberIndex
---@field lastProcessTime integer
---@field lastFlushTime integer timestamp for when logs were last flushed to file
---@field lobbyChanged boolean if new lobby data should be sent out on the next loop
---@field playerbase table
Server =
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
    leaderboard = Leaderboard("leaderboard", self)
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
    logger.debug("leaderboard report: " .. json.encode(leaderboard:get_report()))
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
  for _, v in pairs(self.connections) do
    if v.state == "lobby" then
      names[#names + 1] = v.name
      addPublicPlayerData(players, v.name, leaderboard.players[v.user_id])
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

---@param senderName string
---@param receiverName string
function Server:propose_game(senderName, receiverName)
  logger.debug("propose game: " .. senderName .. " " .. receiverName)
  local senderConnection = self.nameToConnectionIndex[senderName]
  local receiverConnection = self.nameToConnectionIndex[receiverName]
  if senderConnection then
---@diagnostic disable-next-line: cast-local-type
    senderConnection = self.connections[senderConnection]
  end
  if receiverConnection then
---@diagnostic disable-next-line: cast-local-type
    receiverConnection = self.connections[receiverConnection]
  end
  local proposals = self.proposals
  if senderConnection and senderConnection.state == "lobby" and receiverConnection and receiverConnection.state == "lobby" then
    proposals[senderName] = proposals[senderName] or {}
    proposals[receiverName] = proposals[receiverName] or {}
    if proposals[senderName][receiverName] then
      if proposals[senderName][receiverName][receiverName] then
        self:create_room(senderConnection.player, receiverConnection.player)
      end
    else
      receiverConnection:sendJson(ServerProtocol.sendChallenge(senderName, receiverName))
      local prop = {[senderName] = true}
      proposals[senderName][receiverName] = prop
      proposals[receiverName][senderName] = prop
    end
  end
end

---@param name string
function Server:clear_proposals(name)
  local proposals = self.proposals
  if proposals[name] then
    for othername, _ in pairs(proposals[name]) do
      proposals[name][othername] = nil
      if proposals[othername] then
        proposals[othername][name] = nil
      end
    end
    proposals[name] = nil
  end
end

---@param ... ServerPlayer
function Server:create_room(...)
  self:setLobbyChanged()
  local players = {...}
  for _, player in ipairs(players) do
    self:clear_proposals(player.name)
  end
  local new_room = Room(self.roomNumberIndex, leaderboard, self, players)
  self.roomNumberIndex = self.roomNumberIndex + 1
  self.rooms[new_room.roomNumber] = new_room
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
  room:close()
  if self.rooms[room.roomNumber] then
    self.rooms[room.roomNumber] = nil
  end
  self:setLobbyChanged()
end

function Server:update()

  self:acceptNewConnections()

  self:readSockets()

  -- Only check once a second to avoid over checking
  -- (we are relying on time() returning a number rounded to the second)
  local currentTime = time()
  if currentTime ~= self.lastProcessTime then
    self:pingConnections(currentTime)

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
    local connection = Connection(newConnectionSocket, self.connectionNumberIndex, self)
    logger.debug("Accepted connection " .. self.connectionNumberIndex)
    self.connections[self.connectionNumberIndex] = connection
    self.socketToConnectionIndex[newConnectionSocket] = self.connectionNumberIndex
    self.connectionNumberIndex = self.connectionNumberIndex + 1
  end
end

-- Process any data on all active connections
function Server:readSockets()
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
      self.connections[connectionIndex]:read()
    end
  end
end

-- Check all active connections to make sure they have responded timely
function Server:pingConnections(currentTime)
  for _, connection in pairs(self.connections) do
    if currentTime - connection.lastCommunicationTime > 10 then
      logger.debug("Closing connection for " .. (connection.name or "nil") .. ". Connection timed out (>10 sec)")
      connection:close()
    elseif currentTime - connection.lastCommunicationTime > 1 then
      connection:send(NetworkProtocol.serverMessageTypes.ping.prefix) -- Request a ping to make sure the connection is still active
    end
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
      if connection.state == "lobby" then
        connection:sendJson(message)
      end
    end
    self.lobbyChanged = false
  end
end

return Server
