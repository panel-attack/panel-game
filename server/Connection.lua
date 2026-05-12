local class = require("common.lib.class")
local logger = require("common.lib.logger")
local NetworkProtocol = require("common.network.NetworkProtocol")
local time = os.time
local Queue = require("common.lib.Queue")

local DEFAULT_TIMEOUT_SECONDS = 10
local DEFAULT_SEND_RETRY_LIMIT = 5

---@alias InputProcessor { processInput: function }

-- Represents a connection to a specific player. Responsible for sending and receiving messages
---@class Connection
---@field index integer the unique identifier of the connection
---@field socket TcpSocket the luasocket object
---@field leftovers string remaining data from the socket that hasn't been processed yet
---@field loggedIn boolean if there exists a player owning this connection somewhere
---@field lastCommunicationTime integer timestamp when the last message was received; for dropping the connection if heartbeats aren't returned
---@field lastPingTime integer when the last ping was sent
---@field incomingMessageQueue Queue
---@field outgoingMessageQueue Queue
---@field incomingInputQueue Queue
---@field incomingGarbageQueue Queue loose-sync GarbageEvent bodies awaiting room relay
---@field incomingDeathQueue Queue loose-sync DeathEvent bodies awaiting room relay
---@field sendRetryCount integer
---@field sendRetryLimit integer
---@field timeoutSeconds integer
---@field inputProcessor InputProcessor?
---@overload fun(socket: any, index: integer) : Connection
local Connection = class(
---@param self Connection
---@param socket TcpSocket
---@param index integer
  function(self, socket, index)
    self.index = index
    self.socket = socket
    self.leftovers = ""
    self.loggedIn = false
    self.lastCommunicationTime = time()
    self.lastPingTime = self.lastCommunicationTime
    self.incomingMessageQueue = Queue()
    self.outgoingMessageQueue = Queue()
    self.incomingInputQueue = Queue()
    self.incomingGarbageQueue = Queue()
    self.incomingDeathQueue = Queue()
    self.sendRetryCount = 0
    self.sendRetryLimit = DEFAULT_SEND_RETRY_LIMIT
    self.timeoutSeconds = DEFAULT_TIMEOUT_SECONDS
  end
)

-- dedicated method for sending JSON messages
function Connection:sendJson(messageInfo)
  if messageInfo.messageType ~= NetworkProtocol.serverMessageTypes.jsonMessage then
    logger.error("Trying to send a message of type " .. messageInfo.messageType.prefix .. " via sendJson")
  end

  local json = json.encode(messageInfo.messageText)
  logger.debug("Connection " .. self.index .. " Sending JSON: " .. json)
  local message = NetworkProtocol.markedMessageForTypeAndBody(messageInfo.messageType.prefix, json)

  self.outgoingMessageQueue:push(message)
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

  self.outgoingMessageQueue:push(message)
end

function Connection:close()
  self.incomingMessageQueue:clear()
  self.outgoingMessageQueue:clear()
  self.incomingInputQueue:clear()
  self.incomingGarbageQueue:clear()
  self.incomingDeathQueue:clear()
  self.socket:close()
  self.socket = nil
end

-- Handle NetworkProtocol.clientMessageTypes.versionCheck
local function H(connection, version)
  if version ~= NetworkProtocol.NETWORK_VERSION then
    connection:send(NetworkProtocol.serverMessageTypes.versionWrong.prefix)
  else
    connection:send(NetworkProtocol.serverMessageTypes.versionCorrect.prefix)
  end
end

local function data_received(connection, data)
  connection.lastCommunicationTime = time()
  connection.leftovers = connection.leftovers .. data

  while true do
    local type, message, remaining = NetworkProtocol.getMessageFromString(connection.leftovers, false)
    if type then
      -- when type is not nil, the others are most certainly not nil too
      ---@cast remaining string
      ---@cast message string
      connection:processMessage(type, message)
      connection.leftovers = remaining
    else
      break
    end
  end
end

---@return boolean
local function read(connection)
  local data, error, partialData = connection.socket:receive("*a")
  -- "timeout" is a common "error" that just means there is currently nothing to read but the connection is still active
  if error then
    data = partialData
  end
  if data and data:len() > 0 then
    data_received(connection, data)
  end
  if error == "closed" then
    return false
  end
  return true
end

---@param connection Connection
---@return boolean # if the connection is still considered open
local function sendQueuedMessages(connection)
  while connection.outgoingMessageQueue:len() > 0 do
    local message = connection.outgoingMessageQueue:peek()
    local fullMessageSent, error, partialBytesSent = connection.socket:send(message)
    if fullMessageSent then
      connection.outgoingMessageQueue:pop()
      if connection.sendRetryCount > 0 then
        logger.debug(connection.index .. " Retry succeeded after " .. connection.sendRetryCount)
        connection.sendRetryCount = 0
      end
    elseif error == "closed" then
      return false
    elseif error == "timeout" and partialBytesSent and partialBytesSent > 0 then
      local remaining = message:sub(partialBytesSent + 1)
      connection.outgoingMessageQueue[connection.outgoingMessageQueue.first] = remaining
      logger.trace("Partial send: " .. partialBytesSent .. "/" .. #message .. " bytes sent. " .. #remaining .. " bytes remain in queue.")
      break
    else
      connection.sendRetryCount = connection.sendRetryCount + 1
      logger.trace("Send timeout with no progress (retry " .. connection.sendRetryCount .. "/" .. connection.sendRetryLimit .. ")")
      break
    end
  end

  if connection.sendRetryCount >= connection.sendRetryLimit then
    logger.info("Closing connection " .. connection.index .. ". Connection.send failed after " .. connection.sendRetryLimit .. " retries were attempted")
    return false
  end

  return true
end

---@param t integer
function Connection:update(t, canRead, canSend)
  if canRead then
    if not read(self) then
      logger.info("[DISCONNECT-PATH-1] Closing connection " .. self.index .. ". Socket read failed with closed error.")
      return false
    end
  end

  if canSend then
    if not sendQueuedMessages(self) then
      logger.info("[DISCONNECT-PATH-2] Closing connection " .. self.index .. ". Send failed (retries=" .. self.sendRetryCount .. "/" .. self.sendRetryLimit .. ")")
      return false
    end
  end

  if not canRead and not canSend then
    -- it is possible for the socket to "close" based on internal status as luasocket implements its own connection keeping
    -- luasocket does not give a good way to check this easily as closed sockets are ignored in socket.select so we need to check
    if (not self.socket) then
      logger.info("[DISCONNECT-PATH-3a] Closing connection " .. self.index .. ". Socket object is nil.")
      return false
    elseif (self.socket:getpeername() == nil) then
      logger.info("[DISCONNECT-PATH-3b] Closing connection " .. self.index .. ". Peer lookup failed (getpeername returned nil).")
      return false
    end
  end

  if t ~= self.lastCommunicationTime then
    local timeoutSeconds = self.timeoutSeconds or DEFAULT_TIMEOUT_SECONDS
    local timeSinceLastComm = t - self.lastCommunicationTime
    if timeSinceLastComm > timeoutSeconds then
      logger.info("[DISCONNECT-PATH-4] Closing connection " .. self.index .. ". Inactivity timeout (" .. timeSinceLastComm .. ">" .. timeoutSeconds .. " sec)")
      return false
    elseif t > self.lastPingTime and timeSinceLastComm > 1 then
      -- Request a ping to make sure the connection is still active
      self:send(NetworkProtocol.serverMessageTypes.ping.prefix)
      -- we don't want to ping for every run we're waiting for an answer
      self.lastPingTime = t
    end
  end

  return true
end

function Connection:processMessage(messageType, data)
  -- if messageType ~= NetworkProtocol.clientMessageTypes.acknowledgedPing.prefix then
  --   logger.trace(self.index .. "- processing message:" .. messageType .. " data: " .. data)
  -- end
  if messageType == "J" then
    self.incomingMessageQueue:push(data)
  elseif messageType == "I" then
    self.incomingInputQueue:push(data)
  elseif messageType == "G" then
    self.incomingGarbageQueue:push(data)
  elseif messageType == "D" then
    self.incomingDeathQueue:push(data)
  elseif messageType == "H" then
    H(self, data)
  elseif messageType == "E" then
    -- Nothing to do here, the fact we got a message from the client updates the lastCommunicationTime
  end
end

-- Disables Nagle's Algorithm for TCP. Decreases data packet delivery delay, but increases amount of bandwidth and data used.
-- We want this on for players in a room and off for everyone else
function Connection:enableNoDelay(enable)
  if self.socket then
    self.socket:setoption("tcp-nodelay", enable)
  end
end

return Connection