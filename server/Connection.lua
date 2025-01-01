local class = require("common.lib.class")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local NetworkProtocol = require("common.network.NetworkProtocol")
local time = os.time
local ClientMessages = require("server.ClientMessages")
local ServerProtocol = require("common.network.ServerProtocol")
local util = require("common.lib.util")
local LevelPresets = require("common.data.LevelPresets")
local Queue = require("common.lib.Queue")

-- Represents a connection to a specific player. Responsible for sending and receiving messages
---@class Connection
---@field index integer the unique identifier of the connection
---@field socket TcpSocket the luasocket object
---@field leftovers string remaining data from the socket that hasn't been processed yet
---@field loggedIn boolean 
---@field lastCommunicationTime integer timestamp when the last message was received; for dropping the connection if heartbeats aren't returned
---@field server Server the server managing this connection
---@field player ServerPlayer? the player object for this connection
---@field opponent Connection? the opponents connection object
---@field messageQueue Queue
---@overload fun(socket: any, index: integer, server: table) : Connection
local Connection = class(
---@param self Connection
---@param socket TcpSocket
---@param index integer
---@param server Server
  function(self, socket, index, server)
    self.index = index
    self.socket = socket
    self.leftovers = ""

    self.loggedIn = false
    self.lastCommunicationTime = time()
    self.server = server
    self.player = nil
    self.opponent = nil
    self.messageQueue = Queue()
  end
)

local function send(connection, message)
  local retryCount = 0
  local retryLimit = 5
  local success, error

  while not success and retryCount <= retryLimit do
    success, error, lastSent = connection.socket:send(message)
    if not success then
      logger.debug("Connection.send failed with " .. error .. ". will retry...")
      retryCount = retryCount + 1
    end
  end
  if not success then
    logger.info("Closing connection for " .. (connection.name or "nil") .. ". Connection.send failed after " .. retryLimit .. " retries were attempted")
    connection:close()
  end
end

-- dedicated method for sending JSON messages
function Connection:sendJson(messageInfo)
  if messageInfo.messageType ~= NetworkProtocol.serverMessageTypes.jsonMessage then
    logger.error("Trying to send a message of type " .. messageInfo.messageType.prefix .. " via sendJson")
  end

  local json = json.encode(messageInfo.messageText)
  logger.debug("Connection " .. self.index .. " Sending JSON: " .. json)
  local message = NetworkProtocol.markedMessageForTypeAndBody(messageInfo.messageType.prefix, json)

  send(self, message)
end

-- dedicated method for sending inputs and magic prefixes
-- this function avoids overhead by not logging outside of failure and accepting the message directly
function Connection:send(message)
--   if type(message) == "string" then
--     local type = message:sub(1, 1)
--     if type ~= nil and NetworkProtocol.isMessageTypeVerbose(type) == false then
--       logger.debug("Connection " .. self.index .. " sending " .. message)
--     end
--   end

  send(self, message)
end

function Connection:close()
  self.socket:close()
  self.socket = nil
end

-- Handle NetworkProtocol.clientMessageTypes.versionCheck
function Connection:H(version)
  if version ~= NetworkProtocol.NETWORK_VERSION then
    self:send(NetworkProtocol.serverMessageTypes.versionWrong.prefix)
  else
    self:send(NetworkProtocol.serverMessageTypes.versionCorrect.prefix)
  end
end

-- Handle NetworkProtocol.clientMessageTypes.playerInput
function Connection:I(message)
  if self.opponent == nil then
    return
  end
  if self.room == nil then
    return
  end

  self.room:broadcastInput(message, self.player)
end

-- Handle clientMessageTypes.acknowledgedPing
function Connection:E(message)
  -- Nothing to do here, the fact we got a message from the client updates the lastCommunicationTime
end

---@return boolean
function Connection:read()
  local data, error, partialData = self.socket:receive("*a")
  -- "timeout" is a common "error" that just means there is currently nothing to read but the connection is still active
  if error then
    data = partialData
  end
  if data and data:len() > 0 then
    self:data_received(data)
  end
  if error == "closed" then
    return false
  end
  return true
end

function Connection:data_received(data)
  self.lastCommunicationTime = time()
  self.leftovers = self.leftovers .. data

  while true do
    local type, message, remaining = NetworkProtocol.getMessageFromString(self.leftovers, false)
    if type then
      -- when type is not nil, the others are most certainly not nil too
      ---@cast remaining string
      ---@cast message string
      if type == "J" then
        self.messageQueue:push(message)
      else
        --TODO: inputs cannot be routed like this in the future
        -- maybe implement a way to set a target for inputs on the connection so it stays dumb
        self:processMessage(type, message)
      end
      self.leftovers = remaining
    else
      break
    end
  end
end

function Connection:processMessage(messageType, data)
  -- if messageType ~= NetworkProtocol.clientMessageTypes.acknowledgedPing.prefix then
  --   logger.trace(self.index .. "- processing message:" .. messageType .. " data: " .. data)
  -- end
  local status, error = pcall(
      function()
        self[messageType](self, data)
      end
    )
  if status == false and error and type(error) == "string" then
    logger.error("Incoming message from " .. self.index .. " caused an error:\n" ..
                 " pcall error results: " .. tostring(error) ..
                 "\nMessage " .. messageType .. ":\n" .. data)
  end
end

return Connection