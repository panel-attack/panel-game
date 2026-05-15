local NetworkProtocol = require("common.network.NetworkProtocol")
local class = require("common.lib.class")
local util = require("common.lib.util")

-- a message listener listens to exactly ONE type of server message
local MessageListener = class(function(self, messageHeader)
  self.messageHeader = messageHeader
  self.subscriptionList = util.getWeaklyKeyedTable()
end)


-- listens for messages with the specified header
-- passes any messages caught to the registered events
function MessageListener:listen()
  -- Drain JSON messages from ALL three sockets. Shared-auth means each
  -- socket's login response lands in its own queue. In steady state J only
  -- arrives on lobby (Player:sendJson routes to lobbyConnection), but
  -- gameplay/spectate may carry J during the login window.
  local nc = GAME.netClient
  for _, client in ipairs(nc.clients) do
    for _, message in ipairs(client.receivedMessageQueue:pop_all_with(self.messageHeader)) do
      for subscriber, callback in pairs(self.subscriptionList) do
        callback(subscriber, message)
      end
    end
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