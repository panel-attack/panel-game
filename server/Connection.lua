local class = require("common.lib.class")
local logger = require("common.lib.logger")
local NetworkProtocol = require("common.network.NetworkProtocol")
local time = os.time
local Queue = require("common.lib.Queue")

-- Represents a connection to a specific player. Responsible for sending and receiving messages
---@class Connection
---@field index integer the unique identifier of the connection
---@field socket TcpSocket the luasocket object
---@field leftovers string remaining data from the socket that hasn't been processed yet
---@field loggedIn boolean 
---@field lastCommunicationTime integer timestamp when the last message was received; for dropping the connection if heartbeats aren't returned
---@field lastPingTime integer when the last ping was sent
---@field player ServerPlayer? the player object for this connection
---@field incomingMessageQueue Queue
---@field outgoingMessageQueue Queue
---@field sendRetryCount integer
---@field sendRetryLimit integer
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
    self.player = nil
    self.incomingMessageQueue = Queue()
    self.outgoingMessageQueue = Queue()
    self.sendRetryCount = 0
    self.sendRetryLimit = 5
  end
)

local function send(connection, message)
  local success, error = connection.socket:send(message)
  if not success then
    logger.debug("Connection.send failed with " .. error .. ". will retry next update...")
  end

  return success
end

-- dedicated method for sending JSON messages
function Connection:sendJson(messageInfo)
  if messageInfo.messageType ~= NetworkProtocol.serverMessageTypes.jsonMessage then
    logger.error("Trying to send a message of type " .. messageInfo.messageType.prefix .. " via sendJson")
  end

  local json = json.encode(messageInfo.messageText)
  logger.debug("Connection " .. self.index .. " Sending JSON: " .. json)
  local message = NetworkProtocol.markedMessageForTypeAndBody(messageInfo.messageType.prefix, json)

  if not send(self, message) then
    self.outgoingMessageQueue:push(message)
  end
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

  if not send(self, message) then
    self.outgoingMessageQueue:push(message)
  end
end

function Connection:close()
  self.loggedIn = false
  self.incomingMessageQueue:clear()
  self.outgoingMessageQueue:clear()
  self.socket:close()
  self.socket = nil
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
  if self.room == nil then
    return
  end

  self.room:broadcastInput(message, self.player)
end

-- Handle clientMessageTypes.acknowledgedPing
function Connection:E(message)
  -- Nothing to do here, the fact we got a message from the client updates the lastCommunicationTime
end

---@return boolean
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
    return false
  end
  return true
end

---@param t integer
function Connection:update(t)
  if not self:read() then
    logger.info("Closing connection " .. self.index .. ". Connection.read failed with closed error.")
    return false
  end

  self:sendQueuedMessages()

  if self.sendRetryCount >= self.sendRetryLimit then
    logger.info("Closing connection " .. self.index .. ". Connection.send failed after " .. self.sendRetryLimit .. " retries were attempted")
    return false
  end

  if t ~= self.lastCommunicationTime then
    if t - self.lastCommunicationTime > 10 then
      logger.info("Closing connection for " .. self.index .. ". Connection timed out (>10 sec)")
      return false
    elseif t > self.lastPingTime and t - self.lastCommunicationTime > 1 then
      -- Request a ping to make sure the connection is still active
      self:send(NetworkProtocol.serverMessageTypes.ping.prefix)
      -- we don't want to ping for every run we're waiting for an answer
      self.lastPingTime = t
    end
  end
  return true
end

function Connection:sendQueuedMessages()
  for i = self.outgoingMessageQueue.first, self.outgoingMessageQueue.last do
    local message = self.outgoingMessageQueue[i]
    if not send(self, message) then
      self.sendRetryCount = self.sendRetryCount + 1
      break
    else
      self.sendRetryCount = 0
    end
  end

  if self.sendRetryCount == 0 and self.outgoingMessageQueue:len() > 0 then
    self.outgoingMessageQueue:clear()
  end
end

function Connection:data_received(data)
  self.lastCommunicationTime = time()
  self.leftovers = self.leftovers .. data

  while true do
    local type, message, remaining = NetworkProtocol.getMessageFromString(self.leftovers, false)
    if type then
      -- when type is not nil, the others are most certainly not nil too
      ---@cast remaining string
      ---@cast message string
      if type == "J" then
        self.incomingMessageQueue:push(message)
      else
        --TODO: inputs cannot be routed like this in the future
        -- maybe implement a way to set a target for inputs on the connection so it stays dumb
        self:processMessage(type, message)
      end
      self.leftovers = remaining
    else
      break
    end
  end
end

function Connection:processMessage(messageType, data)
  -- if messageType ~= NetworkProtocol.clientMessageTypes.acknowledgedPing.prefix then
  --   logger.trace(self.index .. "- processing message:" .. messageType .. " data: " .. data)
  -- end
  local status, error = pcall(
      function()
        self[messageType](self, data)
      end
    )
  if status == false and error and type(error) == "string" then
    logger.error("Incoming message from " .. self.index .. " caused an error:\n" ..
                 " pcall error results: " .. tostring(error) ..
                 "\nMessage " .. messageType .. ":\n" .. data)
  end
end

return Connection