local Queue = require("common.lib.Queue")
local class = require("common.lib.class")

local index = 0
local MockConnection = class(function(self)
  index = index + 1
  self.index = index
  self.socket = {close = function() end, getpeername = function() return "170.46.23.4", math.random(40000,60000) end}
  self.outgoingMessageQueue = Queue()
  self.outgoingInputQueue = Queue()
  self.incomingMessageQueue = Queue()
  self.incomingInputQueue = Queue()
end)

function MockConnection:update(t) end

function MockConnection:send(message)
  local prefix = message:sub(1, 1)
  if prefix == "I" or prefix == "J" then
    self.outgoingInputQueue:push(message)
  end
end

function MockConnection:sendJson(messageInfo)
  self.outgoingMessageQueue:push(messageInfo)
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

return MockConnection