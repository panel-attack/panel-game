-- One TcpClient class, instantiated three times by NetClient — one per
-- channel (gameplay / lobby / spectate). The three sockets stay independent
-- (separate TCP connections, separate buffers, separate failure paths). This
-- class just replaces the three near-identical copies of socket plumbing.

local logger = require("common.lib.logger")
---@diagnostic disable-next-line: different-requires
local socket = require("socket")
local NetworkProtocol = require("common.network.NetworkProtocol")
require("client.src.TimeQueue")
local class = require("common.lib.class")
local Request = require("client.src.network.Request")
local ServerMessages = require("client.src.network.ServerMessages")
local Queue = require("common.lib.Queue")
local TraceWriter = require("client.src.network.TraceWriter")

-- Cap on un-parseable leftovers after the parse loop runs. A peer that never
-- terminates a frame would otherwise grow the buffer unboundedly. We only
-- check the leftovers (what's left after all complete frames are consumed),
-- so a burst of legitimate small messages doesn't trip the cap — only an
-- incomplete frame that just keeps growing does.
-- 4 MB is comfortably above any legitimate single-frame size in this protocol.
local MAX_LEFTOVERS_BYTES = 4 * 1024 * 1024

local NP = NetworkProtocol

-- Shared handler table. Every prefix decodes the body, optionally side-effects,
-- and pushes onto receivedMessageQueue for the NetClient drain layer. All
-- three channels use the same table; the gameplay/lobby/spectate split is a
-- socket-isolation concern, not a message-shape concern.
local function decodeJson(data, name, prefix)
  local decoded = json.decode(data)
  if not decoded then
    logger.warn(name .. " failed to decode " .. prefix .. " body: " .. tostring(data))
  end
  return decoded
end

local handlers = {
  [NP.serverMessageTypes.input.prefix] = function(self, data)
    local playerNumber, input = NP.decodeInput(data)
    if not playerNumber then
      logger.warn(self.name .. " failed to decode input body: " .. tostring(data))
      return
    end
    local prefix = NP.serverMessageTypes.input.prefix
    local msg = {[prefix] = {playerNumber = playerNumber, input = input}}
    TraceWriter.recv(prefix, msg[prefix])
    self.receivedMessageQueue:push(msg)
  end,

  [NP.serverMessageTypes.garbageEvent.prefix] = function(self, data)
    local prefix = NP.serverMessageTypes.garbageEvent.prefix
    local body = decodeJson(data, self.name, prefix)
    if not body then return end
    TraceWriter.recv(prefix, body)
    self.receivedMessageQueue:push({[prefix] = body})
  end,

  [NP.serverMessageTypes.deathEvent.prefix] = function(self, data)
    local prefix = NP.serverMessageTypes.deathEvent.prefix
    local body = decodeJson(data, self.name, prefix)
    if not body then return end
    TraceWriter.recv(prefix, body)
    self.receivedMessageQueue:push({[prefix] = body})
  end,

  [NP.serverMessageTypes.rewindEvent.prefix] = function(self, data)
    local prefix = NP.serverMessageTypes.rewindEvent.prefix
    local body = decodeJson(data, self.name, prefix)
    if not body then return end
    TraceWriter.recv(prefix, body)
    self.receivedMessageQueue:push({[prefix] = body})
  end,

  [NP.serverMessageTypes.jsonMessage.prefix] = function(self, data)
    local prefix = NP.serverMessageTypes.jsonMessage.prefix
    local msg = decodeJson(data, self.name, prefix)
    if not msg then return end
    -- serverTimeMs piggybacks on some lobby J messages; sample the max to
    -- estimate server-time offset (max = lowest-latency sample = most accurate).
    if type(msg.serverTimeMs) == "number" then
      local localReceiveMs = math.floor(socket.gettime() * 1000)
      local sample = msg.serverTimeMs - localReceiveMs
      if not self.serverOffsetMs or sample > self.serverOffsetMs then
        self.serverOffsetMs = sample
      end
    end
    local sanitized = ServerMessages.sanitizeMessage(msg)
    TraceWriter.recv(prefix, sanitized)
    self.receivedMessageQueue:push(sanitized)
  end,

  [NP.serverMessageTypes.versionCorrect.prefix] = function(self, _)
    TraceWriter.recv(NP.serverMessageTypes.versionCorrect.prefix, true)
    self.receivedMessageQueue:push({versionCompatible = true})
  end,

  [NP.serverMessageTypes.versionWrong.prefix] = function(self, _)
    TraceWriter.recv(NP.serverMessageTypes.versionWrong.prefix, false)
    self.receivedMessageQueue:push({versionCompatible = false})
  end,

  [NP.serverMessageTypes.ping.prefix] = function(self, _)
    self:send(NP.markedMessageForTypeAndBody(NP.clientMessageTypes.acknowledgedPing.prefix, ""))
    self.connectionUptime = self.connectionUptime + 1
  end,
}

---@class TcpClient
---@field name string
---@field defaultPort integer
---@field data string
---@field connectionUptime integer
---@field receivedMessageQueue ServerQueue
---@field outgoingMessageQueue Queue
---@field sendNetworkQueue TimeQueue
---@field receiveNetworkQueue TimeQueue
---@field delayedProcessing boolean
---@field ip string
---@field port integer
---@field socket TcpSocket
---@field sendRetryCount integer
---@field sendRetryLimit integer
---@field sendMinLag number
---@field sendMaxLag number
---@field receiveMinLag number
---@field receiveMaxLag number
---@field serverOffsetMs integer?
local TcpClient = class(function(self, opts)
  opts = opts or {}
  self.name = opts.name or "TcpClient"
  self.defaultPort = opts.defaultPort or 49569
  self.data = ""
  self.connectionUptime = 0
  self.receivedMessageQueue = ServerQueue()
  self.outgoingMessageQueue = Queue()
  self.sendRetryCount = 0
  self.sendRetryLimit = 5
  self.delayedProcessing = false
  self.sendMinLag = 0
  self.sendMaxLag = 0
  self.receiveMinLag = 0
  self.receiveMaxLag = 0
  -- Loss-as-RTO: with `lossPct` probability a packet eats +rtoSec on top of
  -- its normal lag (TCP retransmit timeout proxy). HOL in TimeQueue drags
  -- subsequent packets too, so one "lost" packet stalls the stream.
  self.lossPct = 0
  self.rtoSec = 0.250
  -- Stall: every ~1/stallHz seconds, hold both queues for stallSec.
  self.stallHz = 0
  self.stallSec = 0
  self.nextStallAt = math.huge
  -- Burst: when one packet draws a spike (top of the lag range), bias
  -- subsequent packets up for `burstSec` so spikes cluster (real WiFi /
  -- microwave / handoff pattern) instead of being statistically independent.
  self.burstSec = 0
  self.burstActiveUntil = 0
  -- Bandwidth cap in bytes/sec applied to BOTH directions. 0 = unlimited.
  self.bandwidthBytesPerSec = 0
  -- Sim clock for stall/burst tracking; advances with updateNetwork(dt).
  self.simNow = 0
  math.randomseed(os.time())
  for i = 1, 4 do math.random() end
end)

function TcpClient:setNetworkLag(sendMin, sendMax, recvMin, recvMax)
  self.sendMinLag = sendMin or 0
  self.sendMaxLag = sendMax or self.sendMinLag
  self.receiveMinLag = recvMin or 0
  self.receiveMaxLag = recvMax or self.receiveMinLag
end

function TcpClient:setLossParams(lossPct, rtoSec)
  self.lossPct = math.max(0, math.min(100, lossPct or 0)) / 100
  self.rtoSec = rtoSec or self.rtoSec
end

function TcpClient:setStallParams(stallHz, stallSec)
  self.stallHz = stallHz or 0
  self.stallSec = stallSec or 0
  if self.stallHz > 0 and self.stallSec > 0 then
    self.nextStallAt = self.simNow + (1 / self.stallHz) * (0.5 + math.random())
  else
    self.nextStallAt = math.huge
  end
end

function TcpClient:setBurstSeconds(burstSec)
  self.burstSec = burstSec or 0
end

function TcpClient:setBandwidthBytesPerSec(bps)
  self.bandwidthBytesPerSec = bps or 0
end

-- Exponential-skewed delay in [minLag, maxLag]: most samples land near minLag
-- with occasional large spikes toward maxLag. Burst mode biases the
-- distribution up for a window after a spike fires; loss-as-RTO can stack an
-- extra retransmit delay on top.
function TcpClient:_skewedLag(minLag, maxLag)
  local range = maxLag - minLag
  local lag
  if range <= 0 then
    lag = minLag
  else
    local bias = (self.burstSec > 0 and self.simNow < self.burstActiveUntil) and 0.3 or 0
    local variate = -math.log(1 - math.random() * 0.9933) / 5  -- ≈ exp(5), P(>1)≈0.7%
    variate = math.min(variate + bias, 1)
    lag = minLag + variate * range
    if variate > 0.7 and self.burstSec > 0 then
      self.burstActiveUntil = self.simNow + self.burstSec
    end
  end
  if self.lossPct > 0 and math.random() < self.lossPct then
    lag = lag + self.rtoSec
  end
  return lag
end

---@param ip string
---@param port integer
---@return boolean success
function TcpClient:connectToServer(ip, port)
  self.ip = ip
  self.port = port or self.defaultPort
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
function TcpClient:isConnected()
  return self.socket and self.socket:getpeername() ~= nil
end

---@return boolean?
function TcpClient:readSocket()
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
    logger.warn(self.name .. ": the connection was closed while trying to stream data")
    return false
  end
  return true
end

function TcpClient:resetNetwork()
  self.connectionUptime = 0
  self.ip = ""
  self.port = 0
  if self.socket then
    self.socket:close()
  end
  self.socket = nil
  self.outgoingMessageQueue:clear()
  self.data = ""
end

---@return boolean
function TcpClient:sendQueuedMessages()
  while self.outgoingMessageQueue:len() > 0 do
    local message = self.outgoingMessageQueue:peek()
    local fullMessageSent, error, partialBytesSent = self.socket:send(message)
    if fullMessageSent then
      self.outgoingMessageQueue:pop()
      if self.sendRetryCount > 0 then
        logger.debug(self.name .. " retry succeeded after " .. self.sendRetryCount)
        self.sendRetryCount = 0
      end
    elseif error == "closed" then
      return false
    elseif error == "timeout" and partialBytesSent and partialBytesSent > 0 then
      local remaining = message:sub(partialBytesSent + 1)
      self.outgoingMessageQueue[self.outgoingMessageQueue.first] = remaining
      logger.trace(self.name .. " partial send: " .. partialBytesSent .. "/"
        .. #message .. " bytes sent. " .. #remaining .. " bytes remain in queue.")
      break
    else
      self.sendRetryCount = self.sendRetryCount + 1
      logger.trace(self.name .. " send timeout with no progress (retry "
        .. self.sendRetryCount .. "/" .. self.sendRetryLimit .. ")")
      break
    end
  end

  if self.sendRetryCount >= self.sendRetryLimit then
    logger.info(self.name .. " send failed after " .. self.sendRetryLimit
      .. " retries were attempted")
    return false
  end

  return true
end

function TcpClient:sendMessage(stringData)
  if self:isConnected() then
    self.outgoingMessageQueue:push(stringData)
    return self:sendQueuedMessages()
  else
    return false
  end
end

function TcpClient:updateNetwork(dt)
  if self.delayedProcessing then
    self.simNow = self.simNow + dt
    self.sendNetworkQueue:update(dt)
    self.receiveNetworkQueue:update(dt)

    -- Stall trigger: hold both queues for stallSec, schedule next stall.
    if self.simNow >= self.nextStallAt then
      self.sendNetworkQueue:hold(self.stallSec)
      self.receiveNetworkQueue:hold(self.stallSec)
      self.nextStallAt = self.simNow + (1 / self.stallHz) * (0.5 + math.random())
    end

    -- Drain send queue, optionally bandwidth-capped (over-budget single
    -- packet still flushes; nothing else after).
    local budget = self.bandwidthBytesPerSec > 0
      and (self.bandwidthBytesPerSec * dt) or math.huge
    while budget > 0 do
      local data = self.sendNetworkQueue:popIfReady()
      if not data then break end
      self:sendMessage(data)
      budget = budget - #data
    end

    local data = self.receiveNetworkQueue:popIfReady()
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

function TcpClient:send(stringData)
  if not self.socket then
    return false
  end
  pcall(function()
    local prefix, body = NP.getMessageFromString(stringData, false)
    if prefix then
      local decoded
      if body and #body > 0 and body:sub(1, 1) == "{" then
        decoded = json.decode(body)
      end
      TraceWriter.send(prefix, decoded or body)
    end
  end)
  if self.delayedProcessing then
    local lagSeconds = self:_skewedLag(self.sendMinLag, self.sendMaxLag)
    self.sendNetworkQueue:push(stringData, lagSeconds)
    return true
  else
    return self:sendMessage(stringData)
  end
end

function TcpClient:activateDelayedProcessing()
  self.sendNetworkQueue = TimeQueue()
  self.receiveNetworkQueue = TimeQueue()
  self.delayedProcessing = true
end

function TcpClient:deactivateDelayedProcessing()
  self.sendNetworkQueue:clear()
  self.receiveNetworkQueue:clear()
  self:updateNetwork(0)
  self.delayedProcessing = false
end

---Dispatch a single decoded frame via the handler table. Each handler is
---wrapped in pcall — one malformed frame must not kill the loop or take down
---the socket.
function TcpClient:queueMessage(prefix, data)
  local handler = handlers[prefix]
  if not handler then
    logger.warn(self.name .. " received unexpected prefix '" .. tostring(prefix) .. "'; dropping.")
    return
  end
  local ok, err = pcall(handler, self, data)
  if not ok then
    logger.warn(self.name .. " handler for '" .. prefix .. "' errored: " .. tostring(err))
  end
end

-- Drop all gameplay-channel messages (I, G, D) from the receive queue.
-- Used at match boundaries so events from a previous match don't get
-- applied to the next match's stacks. Without dropping G and D, a death
-- event for slot 3 from match N could fire on slot 3's fresh stack in
-- match N+1 — the "started out dead" bug.
function TcpClient:dropOldInputMessages()
  self.receivedMessageQueue:pop_all_with(
    NP.serverMessageTypes.input.prefix,
    NP.serverMessageTypes.garbageEvent.prefix,
    NP.serverMessageTypes.deathEvent.prefix)
end

function TcpClient:processIncomingMessages()
  if not self:readSocket() then
    return false
  end
  while true do
    local type, message, remaining = NP.getMessageFromString(self.data, true)
    if type then
      ---@cast message -nil
      ---@cast remaining -nil
      if self.delayedProcessing then
        local lagSeconds = self:_skewedLag(self.receiveMinLag, self.receiveMaxLag)
        self.receiveNetworkQueue:push({type, message}, lagSeconds)
      else
        self:queueMessage(type, message)
      end
      self.data = remaining
    else
      break
    end
  end
  if #self.data > MAX_LEFTOVERS_BYTES then
    logger.warn(self.name .. ": leftover unparsed buffer exceeded "
      .. MAX_LEFTOVERS_BYTES .. " bytes (no frame terminator in sight). Dropping socket.")
    return false
  end
  return true
end

function TcpClient:sendRequest(requestData)
  local request = Request(self, requestData.messageType, requestData.messageText, requestData.responseTypes)
  return request:send()
end

return TcpClient
