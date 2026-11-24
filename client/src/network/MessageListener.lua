local class = require("common.lib.class")
local util = require("common.lib.util")

-- a message listener listens to exactly ONE type of server message
---@class MessageListener
---@field messageHeader string
---@field subscriptionList table<any, fun(subscriber: any, message: table)>
---@overload fun(messageHeader: string): MessageListener
local MessageListener = class(
function(self, messageHeader)
  self.messageHeader = messageHeader
  self.subscriptionList = util.getWeaklyKeyedTable()
end)

-- passes a message with the listener's header to the registered events
---@param message table
function MessageListener:handle(message)
  for subscriber, callback in pairs(self.subscriptionList) do
    callback(subscriber, message)
  end
end

function MessageListener:subscribe(subscriber, callback)
  self.subscriptionList[subscriber] = callback
end

function MessageListener:unsubscribe(subscriber)
  self.subscriptionList[subscriber] = nil
end

function MessageListener:clearSubscriptions()
  self.subscriptionList = util.getWeaklyKeyedTable()
end

return MessageListener
