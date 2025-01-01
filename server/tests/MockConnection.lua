local Queue = require("common.lib.Queue")
local class = require("common.lib.class")

local index = 0
local MockConnection = class(function(self)
  index = index + 1
  self.index = index
  self.socket = true
  self.outgoingMessageQueue = Queue()
  self.outgoingInputQueue = Queue()
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

function MockConnection:processMessage(messageType, data) end

return MockConnection