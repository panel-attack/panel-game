local logger = require("common.lib.logger")
---@diagnostic disable-next-line: different-requires
local socket = require("socket")
local NetworkProtocol = require("common.network.NetworkProtocol")
local ClientMessages = require("common.network.ClientProtocol")
require("client.src.TimeQueue")
local class = require("common.lib.class")
local Request = require("client.src.network.Request")
local ServerMessages = require("client.src.network.ServerMessages")
local Queue = require("common.lib.Queue")
local TraceWriter = require("client.src.network.TraceWriter")

---@class GameplayTcpClient
---@field data string
---@field connectionUptime integer
---@field receivedMessageQueue ServerQueue
---@field sendNetworkQueue TimeQueue
---@field receiveNetworkQueue TimeQueue
---@field delayedProcessing boolean
---@field ip string
---@field port integer
---@field socket TcpSocket
---@field outgoingMessageQueue Queue
---@field sendRetryCount integer
---@field sendRetryLimit integer
local GameplayTcpClient = class(function(tcpClient)
  tcpClient.data = ""
  tcpClient.connectionUptime = 0
  tcpClient.receivedMessageQueue = ServerQueue()
  tcpClient.outgoingMessageQueue = Queue()
  tcpClient.sendRetryCount = 0
  tcpClient.sendRetryLimit = 5
  tcpClient.delayedProcessing = false
  math.randomseed(os.time())
  for i = 1, 4 do
    math.random()
  end
end)

---@param ip string
---@param port integer
---@return boolean success
function GameplayTcpClient:connectToServer(ip, port)
  self.ip = ip
  self.port = port or 49569
  self.socket = socket.tcp()
  self.socket:settimeout(7)
  local result, err = self.socket:connect(self.ip, self.port)
  if not result then
    return err == "already connected"
  end
  self.socket:setoption("tcp-nodelay", true)
  self.socket:settimeout(0)
  return true
end

---@return boolean
function GameplayTcpClient:isConnected()
  return self.socket and self.socket:getpeername() ~= nil
end

---@return boolean?
function GameplayTcpClient:readSocket()
  if not self.socket then
    return
  end
  local data, error, partialData = self.socket:receive("*a")
  if error == "timeout" then
    data = partialData
  end
  if data and data:len() > 0 then
    self.data = self.data .. data
  end
  if error == "closed" then
    logger.warn("GameplayTcpClient: the connection was closed while trying to stream data")
    return false
  end
  return true
end

function GameplayTcpClient:resetNetwork()
  self.connectionUptime = 0
  self.ip = ""
  self.port = 0
  if self.socket then
    self.socket:close()
  end
  self.socket = nil
  self.outgoingMessageQueue:clear()
end

---@return boolean
function GameplayTcpClient:sendQueuedMessages()
  while self.outgoingMessageQueue:len() > 0 do
    local message = self.outgoingMessageQueue:peek()
    local fullMessageSent, error, partialBytesSent = self.socket:send(message)
    if fullMessageSent then
      self.outgoingMessageQueue:pop()
      if self.sendRetryCount > 0 then
        logger.debug("GameplayTcpClient retry succeeded after " .. self.sendRetryCount)
        self.sendRetryCount = 0
      end
    elseif error == "closed" then
      return false
    elseif error == "timeout" and partialBytesSent and partialBytesSent > 0 then
      local remaining = message:sub(partialBytesSent + 1)
      self.outgoingMessageQueue[self.outgoingMessageQueue.first] = remaining
      logger.trace("GameplayTcpClient partial send: " .. partialBytesSent .. "/" .. #message .. " bytes sent. " .. #remaining .. " bytes remain in queue.")
      break
    else
      self.sendRetryCount = self.sendRetryCount + 1
      logger.trace("GameplayTcpClient send timeout with no progress (retry " .. self.sendRetryCount .. "/" .. self.sendRetryLimit .. ")")
      break
    end
  end

  if self.sendRetryCount >= self.sendRetryLimit then
    logger.info("GameplayTcpClient send failed after " .. self.sendRetryLimit .. " retries were attempted")
    return false
  end

  return true
end

function GameplayTcpClient:sendMessage(stringData)
  if self:isConnected() then
    self.outgoingMessageQueue:push(stringData)
    return self:sendQueuedMessages()
  else
    return false
  end
end

function GameplayTcpClient:updateNetwork(dt)
  if self.delayedProcessing then
    self.sendNetworkQueue:update(dt)
    local data = self.sendNetworkQueue:popIfReady()
    while data do
      self:sendMessage(data)
      data = self.sendNetworkQueue:popIfReady()
    end

    self.receiveNetworkQueue:update(dt)
    data = self.receiveNetworkQueue:popIfReady()
    while data do
      self:queueMessage(data[1], data[2])
      data = self.receiveNetworkQueue:popIfReady()
    end
  else
    if self:isConnected() then
      self:sendQueuedMessages()
    end
  end
end

local sendMinLag = 0
local sendMaxLag = 0
local receiveMinLag = 3
local receiveMaxLag = receiveMinLag

function GameplayTcpClient:send(stringData)
  if not self.socket then
    return false
  end
  pcall(function()
    local prefix, body = NetworkProtocol.getMessageFromString(stringData, false)
    if prefix then
      local decoded
      if body and #body > 0 and body:sub(1, 1) == "{" then
        decoded = json.decode(body)
      end
      TraceWriter.send(prefix, decoded or body)
    end
  end)
  if self.delayedProcessing then
    local lagSeconds = (math.random() * (sendMaxLag - sendMinLag)) + sendMinLag
    self.sendNetworkQueue:push(stringData, lagSeconds)
    return true
  else
    return self:sendMessage(stringData)
  end
end

function GameplayTcpClient:activateDelayedProcessing()
  self.sendNetworkQueue = TimeQueue()
  self.receiveNetworkQueue = TimeQueue()
  self.delayedProcessing = true
end

function GameplayTcpClient:deactivateDelayedProcessing()
  self.sendNetworkQueue:clear()
  self.receiveNetworkQueue:clear()
  self:updateNetwork(0)
  self.delayedProcessing = false
end

function GameplayTcpClient:queueMessage(type, data)
  local traced = function(body) pcall(function() TraceWriter.recv(type, body) end) end

  if type == NetworkProtocol.serverMessageTypes.input.prefix then
    local playerNumber, input = NetworkProtocol.decodeInput(data)
    if not playerNumber then
      logger.warn("Failed to decode input body: " .. (data or "nil"))
      return
    end
    local dataMessage = {}
    dataMessage[type] = {playerNumber = playerNumber, input = input}
    logger.trace("Queuing: " .. type .. " for player " .. playerNumber)
    traced(dataMessage[type])
    self.receivedMessageQueue:push(dataMessage)
  elseif type == NetworkProtocol.serverMessageTypes.versionCorrect.prefix then
    traced(true)
    self.receivedMessageQueue:push({versionCompatible = true})
  elseif type == NetworkProtocol.serverMessageTypes.versionWrong.prefix then
    traced(false)
    self.receivedMessageQueue:push({versionCompatible = false})
  elseif type == NetworkProtocol.serverMessageTypes.ping.prefix then
    self:send(NetworkProtocol.clientMessageTypes.acknowledgedPing.prefix)
    self.connectionUptime = self.connectionUptime + 1
  elseif type == NetworkProtocol.serverMessageTypes.garbageEvent.prefix
      or type == NetworkProtocol.serverMessageTypes.deathEvent.prefix then
    local body = json.decode(data)
    if not body then
      logger.warn("Failed to decode " .. type .. " body: " .. (data or "nil"))
      return
    end
    local dataMessage = {}
    dataMessage[type] = body
    traced(body)
    self.receivedMessageQueue:push(dataMessage)
  elseif type == NetworkProtocol.serverMessageTypes.jsonMessage.prefix then
    -- Shared-auth: both sockets log in independently with the same credentials,
    -- so each socket sees its OWN login response as a J message. After login,
    -- in steady state, server-pushed J traffic goes to lobbyConnection (via
    -- Player:sendJson). So J on gameplay is a normal login-window message
    -- and the occasional cross-channel fallback. Queue it; MessageListener
    -- drains both clients' queues.
    local current_message = json.decode(data)
    if not current_message then
      error(loc("nt_msg_err", (data or "nil")))
    end
    local sanitized = ServerMessages.sanitizeMessage(current_message)
    traced(sanitized)
    self.receivedMessageQueue:push(sanitized)
  end
end

function GameplayTcpClient:dropOldInputMessages()
  local inputPrefix = NetworkProtocol.serverMessageTypes.input.prefix
  while true do
    local message = self.receivedMessageQueue:top()
    if not message then
      break
    end
    if message[inputPrefix] == nil then
      break
    else
      self.receivedMessageQueue:pop()
    end
  end
end

function GameplayTcpClient:processIncomingMessages()
  if not self:readSocket() then
    return false
  end
  while true do
    local type, message, remaining = NetworkProtocol.getMessageFromString(self.data, true)
    if type then
      ---@cast message -nil
      ---@cast remaining -nil
      if self.delayedProcessing then
        local lagSeconds = (math.random() * (receiveMaxLag - receiveMinLag)) + receiveMinLag
        self.receiveNetworkQueue:push({type, message}, lagSeconds)
      else
        self:queueMessage(type, message)
      end
      self.data = remaining
    else
      break
    end
  end
  return true
end

function GameplayTcpClient:sendRequest(requestData)
  local request = Request(self, requestData.messageType, requestData.messageText, requestData.responseTypes)
  return request:send()
end

return GameplayTcpClient
