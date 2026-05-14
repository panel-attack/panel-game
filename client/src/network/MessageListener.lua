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
  local messagesOut = {}
  for _, client in ipairs({nc.lobbyClient, nc.gameplayClient, nc.spectateClient}) do
    if client then
      for _, m in ipairs(client.receivedMessageQueue:pop_all_with(self.messageHeader)) do
        messagesOut[#messagesOut+1] = m
      end
    end
  end
  for i = 1, #messagesOut do
    local message = messagesOut[i]
    for subscriber, callback in pairs(self.subscriptionList) do
      callback(subscriber, message)
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