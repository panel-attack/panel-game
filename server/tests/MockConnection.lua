local Queue = require("common.lib.Queue")
local class = require("common.lib.class")

local MockConnection = class(function(self)
  self.outgoingMessageQueue = Queue()
  self.outgoingInputQueue = Queue()
end)

function MockConnection:update(t) end

local function send(mockConnection, message)
end

function MockConnection:send(message)
  local prefix = message:sub(1, 1)
  if prefix == "I" or prefix == "J" then
    self.outgoingInputQueue:push(message)
  end
end

function MockConnection:sendJson(messageInfo)
  self.outgoingMessageQueue:push(messageInfo)
end

function MockConnection:close() end

function MockConnection:processMessage(messageType, data) end

return MockConnection