local class = require("common.lib.class")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local NetworkProtocol = require("common.network.NetworkProtocol")
local time = os.time
local utf8 = require("common.lib.utf8Additions")
local Player = require("server.Player")
local ClientMessages = require("server.ClientMessages")
local ServerProtocol = require("common.network.ServerProtocol")
local Signal = require("common.lib.signal")

-- Represents a connection to a specific player. Responsible for sending and receiving messages
Connection =
  class(
  function(self, socket, index, server)
    self.index = index -- the connection number
    self.socket = socket -- the socket object
    self.leftovers = "" -- remaining data from the socket that hasn't been processed yet

    -- connections current state, whether they are logged in, playing, spectating etc.
    -- "not_logged_in" -> "lobby" -> "character select" -> "playing" or "spectating" -> "lobby"
    self.state = "not_logged_in"
    self.room = nil -- the room object the connection currently is in
    self.lastCommunicationTime = time()
    self.player_number = 0 -- 0 if not a player in a room, 1 if player "a" in a room, 2 if player "b" in a room
    self.user_id = nil -- private user ID of the connection
    self.wants_ranked_match = false
    self.server = server
    self.player = nil -- the player object for this connection
    self.opponent = nil -- the opponents connection object
    self.name = nil

    -- Player Settings
    self.character = nil
    self.character_is_random = nil
    self.character_display_name = nil
    self.cursor = nil
    self.inputMethod = "controller"
    self.level = nil
    self.panels_dir = nil
    self.ready = nil
    self.stage = nil
    self.stage_is_random = nil
    self.wants_ranked_match = nil

    Signal.turnIntoEmitter(self)
    self:createSignal("settingsUpdated")
  end
)

function Connection:getSettings()
  return ServerProtocol.toSettings(
    self.ready,
    self.level,
    self.inputMethod,
    self.stage,
    self.stage_is_random,
    self.character,
    self.character_is_random,
    self.panels_dir,
    self.wants_ranked_match
  )
end

function Connection:getDumbSettings(rating)
  return ServerProtocol.toDumbSettings(
    self.character,
    self.level,
    self.panels_dir,
    self.player_number,
    self.inputMethod,
    rating
  )
end

function Connection:menu_state()
  local state = {
    cursor = self.cursor,
    stage = self.stage,
    stage_is_random = self.stage_is_random,
    ready = self.ready,
    character = self.character,
    character_is_random = self.character_is_random,
    character_display_name = self.character_display_name,
    panels_dir = self.panels_dir,
    level = self.level,
    ranked = self.wants_ranked_match,
    inputMethod = self.inputMethod
  }
  return state
  --note: player_number here is the player_number of the connection as according to the server, not the "which" of any Stack
end

local function send(connection, message)
  local retryCount = 0
  local retryLimit = 5
  local success, error

  while not success and retryCount <= retryLimit do
    success, error, lastSent = connection.socket:send(message)
    if not success then
      logger.debug("Connection.send failed with " .. error .. ". will retry...")
      retryCount = retryCount + 1
    end
  end
  if not success then
    logger.debug("Closing connection for " .. (connection.name or "nil") .. ". Connection.send failed after " .. retryLimit .. " retries were attempted")
    connection:close()
  end
end

-- dedicated method for sending JSON messages
function Connection:sendJson(messageInfo)
  if messageInfo.messageType ~= NetworkProtocol.serverMessageTypes.jsonMessage then
    logger.error("Trying to send a message of type " .. messageInfo.messageType.prefix .. " via sendJson")
  end

  local json = json.encode(messageInfo.messageText)
  logger.debug("Connection " .. self.index .. " Sending JSON: " .. json)
  local message = NetworkProtocol.markedMessageForTypeAndBody(messageInfo.messageType.prefix, json)

  send(self, message)
end

-- dedicated method for sending inputs and magic prefixes
-- this function avoids overhead by not logging outside of failure and accepting the message directly
function Connection:send(message)
--   if type(message) == "string" then
--     local type = message:sub(1, 1)
--     if type ~= nil and NetworkProtocol.isMessageTypeVerbose(type) == false then
--       logger.debug("Connection " .. self.index .. " sending " .. message)
--     end
--   end

  send(self, message)
end

function Connection:leaveRoom()
  self.opponent = nil
  self.state = "lobby"
  self.server:setLobbyChanged()
  if self.room then
    logger.debug("Closing room for " .. (self.name or "nil") .. " because opponent disconnected.")
    self.server:closeRoom(self.room)
  end
  self:sendJson(ServerProtocol.leaveRoom())
end

function Connection:setup_game()
  if self.state ~= "spectating" then
    self.state = "playing"
  end
  self.server:setLobbyChanged()
end

function Connection:close()
  logger.debug("Closing connection to " .. self.index)
  if self.state == "lobby" then
    self.server:setLobbyChanged()
  end
  if self.room and (self.room.a.name == self.name or self.room.b.name == self.name) then
    logger.trace("about to close room for " .. (self.name or "nil") .. ".  Connection.close was called")
    self.server:closeRoom(self.room)
  elseif self.room then
    self.server:removeSpectator(self.room, self)
  end
  self.server:clear_proposals(self.name)
  if self.opponent then
    self.opponent:leaveRoom()
  end
  if self.name then
    self.server.nameToConnectionIndex[self.name] = nil
  end
  self.server.socketToConnectionIndex[self.socket] = nil
  self.server.connections[self.index] = nil
  self.socket:close()
end

-- Handle NetworkProtocol.clientMessageTypes.versionCheck
function Connection:H(version)
  if version ~= NetworkProtocol.NETWORK_VERSION then
    self:send(NetworkProtocol.serverMessageTypes.versionWrong.prefix)
  else
    self:send(NetworkProtocol.serverMessageTypes.versionCorrect.prefix)
  end
end

-- Handle NetworkProtocol.clientMessageTypes.playerInput
function Connection:I(message)
  if self.opponent == nil then
    return
  end
  if self.room == nil then
    return
  end

  self.room:broadcastInput(message, self)
end

-- Handle clientMessageTypes.acknowledgedPing
function Connection:E(message)
  -- Nothing to do here, the fact we got a message from the client updates the lastCommunicationTime
end

-- Handle clientMessageTypes.jsonMessage
function Connection:J(message)
  message = json.decode(message)
  message = ClientMessages.sanitizeMessage(message)
  if message.error_report then -- Error report is checked for first so that a full login is not required
    self:handleErrorReport(message.error_report)
  elseif self.state == "not_logged_in" then
    if message.login_request then
      local IP_logging_in, port = self.socket:getpeername()
      self:login(message.user_id, message.name, IP_logging_in, port, message.engine_version, message)
    end
  elseif message.logout then
    self:close()
  elseif self.state == "lobby" and message.game_request then
    if message.game_request.sender == self.name then
      self.server:propose_game(message.game_request.sender, message.game_request.receiver, message)
    end
  elseif message.leaderboard_request then
    self:sendJson(ServerProtocol.sendLeaderboard(leaderboard:get_report(self)))
  elseif message.spectate_request then
    self:handleSpectateRequest(message)
  elseif self.state == "character select" and message.menu_state then
    -- Note this also starts the game if everything is ready from both players character select settings
    self:handleMenuStateMessage(message)
  elseif self.state == "playing" and message.taunt then
    self:handleTaunt(message)
  elseif self.state == "playing" and message.game_over then
    self:handleGameOverOutcome(message)
  elseif (self.state == "playing" or self.state == "character select") and message.leave_room then
    self:handlePlayerRequestedToLeaveRoom(message)
  elseif (self.state == "spectating") and message.leave_room then
    self.server:removeSpectator(self.room, self)
  elseif message.unknown then
    self:close()
  end
end

function Connection:handleErrorReport(errorReport)
  logger.warn("Received an error report.")
  if not write_error_report(errorReport) then
    logger.error("The error report was either too large or had an I/O failure when attempting to write the file.")
  end
  self:close() -- After sending the error report, the client will throw the error, so end the connection.
end

--returns whether the login was successful
function Connection:login(user_id, name, IP_logging_in, port, engineVersion, playerSettings)
  local logged_in = false
  local message = {}

  logger.debug("New login attempt:  " .. IP_logging_in .. ":" .. port)

  local denyReason, playerBan = self:canLogin(user_id, name, IP_logging_in, engineVersion)

  if denyReason ~= nil or playerBan ~= nil then
    self.server:denyLogin(self, denyReason, playerBan)
  else
    logged_in = true

    if user_id == "need a new user id" then
      assert(self.server.playerbase:nameTaken("", name) == false)
      user_id = self.server:createNewUser(name)
      logger.info("New user: " .. name .. " was created")
      message.new_user_id = user_id
    end

    -- Name change is allowed because it was already checked above
    if self.server.playerbase.players[user_id] ~= name then
      local oldName = self.server.playerbase.players[user_id]
      self.server:changeUsername(user_id, name)
      
      logger.warn(user_id .. " changed name " .. oldName .. " to " .. name)

      message.name_changed = true
      message.old_name = oldName
      message.new_name = name
    end
    
    self.name = name
    self.server.nameToConnectionIndex[name] = self.index
    self:updatePlayerSettings(playerSettings)
    self.user_id = user_id
    self.player = Player(user_id)
    assert(self.player.publicPlayerID ~= nil)
    self.state = "lobby"
    leaderboard:update_timestamp(user_id)
    self.server.database:insertIPID(IP_logging_in, self.player.publicPlayerID)
    self.server:setLobbyChanged()

    local serverNotices = self.server.database:getPlayerMessages(self.player.publicPlayerID)
    local serverUnseenBans = self.server.database:getPlayerUnseenBans(self.player.publicPlayerID)
    if tableUtils.length(serverNotices) > 0 or tableUtils.length(serverUnseenBans) > 0 then
      local noticeString = ""
      for messageID, serverNotice in pairs(serverNotices) do
        noticeString = noticeString .. serverNotice .. "\n\n"
        self.server.database:playerMessageSeen(messageID)
      end
      for banID, reason in pairs(serverUnseenBans) do
        noticeString = noticeString .. "A ban was issued to you for: " .. reason .. "\n\n"
        self.server.database:playerBanSeen(banID)
      end
      message.server_notice = noticeString
    end

    message.login_successful = true
    self:sendJson(ServerProtocol.approveLogin(message.server_notice, message.new_user_id, message.new_name, message.old_name))

    logger.warn("Login from " .. name .. " with ip: " .. IP_logging_in .. " publicPlayerID: " .. self.player.publicPlayerID)
  end

  return logged_in
end

function Connection:canLogin(userID, name, IP_logging_in, engineVersion)
  local playerBan = self.server:isPlayerBanned(IP_logging_in)
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
    if self.server.playerbase:nameTaken("", name) then
      denyReason = "That player name is already taken"
      logger.warn("Login failure: Player tried to create a new user with an already taken name: " .. name)
    end
  elseif not self.server.playerbase.players[userID] then
    playerBan = self.server:insertBan(IP_logging_in, "The user ID provided was not found on this server", os.time() + 60)
    logger.warn("Login failure: " .. name .. " specified an invalid user ID")
  elseif self.server.playerbase.players[userID] ~= name and self.server.playerbase:nameTaken(userID, name) then
    denyReason = "That player name is already taken"
    logger.warn("Login failure: Player (" .. userID .. ") tried to use already taken name: " .. name)
  end

  return denyReason, playerBan
end

function Connection:updatePlayerSettings(playerSettings)
  if playerSettings.character ~= nil then
    self.character = playerSettings.character
  end

  if playerSettings.character_is_random ~= nil then
    self.character_is_random = playerSettings.character_is_random
  end
  -- self.cursor = playerSettings.cursor -- nil when from login
  if playerSettings.inputMethod ~= nil then
    self.inputMethod = (playerSettings.inputMethod or "controller")
  end

  if playerSettings.level ~= nil then
    self.level = playerSettings.level
  end

  if playerSettings.panels_dir ~= nil then
    self.panels_dir = playerSettings.panels_dir
  end

  if playerSettings.ready ~= nil then
    self.ready = playerSettings.ready -- nil when from login
  end

  if playerSettings.stage ~= nil then
    self.stage = playerSettings.stage
  end

  if playerSettings.stage_is_random ~= nil then
    self.stage_is_random = playerSettings.stage_is_random
  end

  if playerSettings.ranked ~= nil then
    self.wants_ranked_match = playerSettings.ranked
  end

  self:emitSignal("settingsUpdated", self)
end

function Connection:handleSpectateRequest(message)
  local requestedRoom = self.server:roomNumberToRoom(message.spectate_request.roomNumber)
  if self.state ~= "lobby" then
    if requestedRoom then
      logger.debug("removing " .. self.name .. " from room nr " .. message.spectate_request.roomNumber)
      self.server:removeSpectator(requestedRoom, self)
    else
      logger.warn("could not find room to remove " .. self.name)
      self.state = "lobby"
    end
  end
  local roomState = requestedRoom:state()
  if requestedRoom and (roomState == "character select" or roomState == "playing") then
    logger.debug("adding " .. self.name .. " to room nr " .. message.spectate_request.roomNumber)
    self.server:addSpectator(requestedRoom, self)
  else
    -- TODO: tell the client the join request failed, couldn't find the room.
    logger.warn("couldn't find room")
  end
end

function Connection:handleMenuStateMessage(message)
  local playerSettings = message.menu_state
  self:updatePlayerSettings(playerSettings)
end

function Connection:handleTaunt(message)
  local msg = ServerProtocol.taunt(self.player_number, message.type, message.index)
  self.room:broadcastJson(msg, self)
end

function Connection:handleGameOverOutcome(message)
  self.room:reportOutcome(self, message.outcome)
end

function Connection:handlePlayerRequestedToLeaveRoom(message)
  local opponent = self.opponent
  self:leaveRoom()
  opponent:leaveRoom()
  if self.room and self.room.spectators then
    for _, v in pairs(self.room.spectators) do
      v:leaveRoom()
    end
  end
end

function Connection:read()
  local data, error, partialData = self.socket:receive("*a")
  -- "timeout" is a common "error" that just means there is currently nothing to read but the connection is still active
  if error then
    data = partialData
  end
  if data and data:len() > 0 then
    self:data_received(data)
  end
  if error == "closed" then
    self:close()
  end
end

function Connection:data_received(data)
  self.lastCommunicationTime = time()
  self.leftovers = self.leftovers .. data

  while true do
    local type, message, remaining = NetworkProtocol.getMessageFromString(self.leftovers, false)
    if type then
      self:processMessage(type, message)
      self.leftovers = remaining
    else
      break
    end
  end
end

function Connection:processMessage(messageType, data)
  if messageType ~= NetworkProtocol.clientMessageTypes.acknowledgedPing.prefix then
    logger.trace(self.index .. "- processing message:" .. messageType .. " data: " .. data)
  end
  local status, error = pcall(
      function()
        self[messageType](self, data)
      end
    )
  if status == false and error and type(error) == "string" then
    logger.error("pcall error results: " .. tostring(error))
  end
end
