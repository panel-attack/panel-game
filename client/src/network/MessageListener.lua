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
  -- Drain JSON messages from BOTH sockets. Each socket runs its own login
  -- (shared-auth) so login responses land on whichever socket initiated
  -- them. In steady state J traffic goes to lobby (Player:sendJson routes
  -- to lobbyConnection), but the gameplay queue can still receive J
  -- during login or via the cross-channel fallback. Drain both to be safe.
  local nc = GAME.netClient
  local messagesOut = {}
  if nc.lobbyClient then
    for _, m in ipairs(nc.lobbyClient.receivedMessageQueue:pop_all_with(self.messageHeader)) do
      messagesOut[#messagesOut+1] = m
    end
  end
  if nc.gameplayClient then
    for _, m in ipairs(nc.gameplayClient.receivedMessageQueue:pop_all_with(self.messageHeader)) do
      messagesOut[#messagesOut+1] = m
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