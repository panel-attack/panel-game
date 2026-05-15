local Queue = require("common.lib.Queue")
local class = require("common.lib.class")

local index = 0
local MockConnection = class(function(self, channel)
  index = index + 1
  self.index = index
  self.channel = channel or "gameplay"
  self.socket = {close = function() end, getpeername = function() return "170.46.23.4", math.random(40000,60000) end}
  self.outgoingMessageQueue = Queue()
  self.outgoingInputQueue = Queue()
  self.incomingMessageQueue = Queue()
  self.incomingInputQueue = Queue()
  -- Loose-sync queues; match the real Connection's field set so
  -- Server:processMessages doesn't crash dereferencing them.
  self.incomingGarbageQueue = Queue()
  self.incomingDeathQueue = Queue()
end)

function MockConnection:update(t) end

function MockConnection:send(message)
  -- v009 framing: [4-byte BE length][prefix][body]. Prefix sits at byte 5.
  -- Tests sometimes pass un-framed strings like "Iabc"; fall back to byte 1
  -- so routing-level tests work without rebuilding wire frames.
  local prefix = #message >= 5 and message:sub(5, 5) or message:sub(1, 1)
  -- I = unified input prefix (v008+); G/D = loose-sync event prefixes
  -- (GarbageEvent, DeathEvent). J = JSON message.
  if prefix == "I" or prefix == "J" or prefix == "G" or prefix == "D" then
    self.outgoingInputQueue:push(message)
  end
end

function MockConnection:sendJson(messageInfo)
  -- need a deepcpy due to the implementation detail of messageInfo generation
  self.outgoingMessageQueue:push(deepcpy(messageInfo))
end

function MockConnection:close()
  self.socket = false
end

function MockConnection:restore()
  self.socket = {close = function() end, getpeername = function() return "170.46.23.4", math.random(40000,60000) end}
end

function MockConnection:processMessage(messageType, data) end

function MockConnection:receiveInput(input)
  self.incomingInputQueue:push(input)
end

function MockConnection:receiveMessage(message)
  self.incomingMessageQueue:push(message)
end

function MockConnection:enableNoDelay(enable) end

return MockConnection