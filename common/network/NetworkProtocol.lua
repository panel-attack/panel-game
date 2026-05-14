local logger = require("common.lib.logger")
local json = require("common.lib.dkjson")

local NetworkProtocol = {}

-- Version 001 was super legacy
-- Version 002 we supported unicode JSON
-- Version 003 we updated login requirements and started sending the network version
-- Version 004 server communicates replays in a new standardised format
-- Version 008 unified input message: single "I" prefix with JSON body {playerNumber, input},
--             replacing the per-slot prefixes (I,U,V,W,X,Y,Z,Q). No 8-player wire cap.
NetworkProtocol.NETWORK_VERSION = "008"

local messageEndMarker = "←J←"

-- All the types sent by clients and servers
-- Prefix is what is put at the front of the message
-- Then size data follows in normal single byte sequence.
-- if size is nil then a variable utf8 byte sequence follows terminated by messageEndMarker
NetworkProtocol.clientMessageTypes = {
  jsonMessage = {prefix="J", size=nil}, -- Generic JSON message sent from the client
  playerInput = {prefix="I", size=nil}, -- Player input (raw encoded input string). Server stamps the sender's playerNumber and re-encodes via encodeInput before relaying to other players.
  garbageEvent = {prefix="G", size=nil}, -- Loose-sync: sender-emitted garbage delivery event (JSON body)
  deathEvent = {prefix="D", size=nil}, -- Loose-sync: sender-emitted death notification (JSON body)
  acknowledgedPing = {prefix="E", size=1}, -- Respond back from the servers ping to confirm we are still connected
  versionCheck = {prefix="H", size=4} -- Sent on initial connection with the NETWORK_VERSION number to confirm client and server agree
}
NetworkProtocol.clientPrefixToMessageType = {}
for _, value in pairs(NetworkProtocol.clientMessageTypes) do
  NetworkProtocol.clientPrefixToMessageType[value.prefix] = value
end

NetworkProtocol.serverMessageTypes = {
  jsonMessage = {prefix="J", size=nil}, -- Generic JSON message sent from the server
  input = {prefix="I", size=nil, verbose = true}, -- Relayed player input: JSON body {playerNumber, input}. Single prefix for all slots (no 8-player cap).
  garbageEvent = {prefix="G", size=nil, verbose = true}, -- Loose-sync: relayed sender-emitted garbage delivery event
  deathEvent = {prefix="D", size=nil}, -- Loose-sync: relayed sender-emitted death notification
  versionCorrect = {prefix="H", size=1}, -- Sent to the client if the NETWORK_VERSION they sent is allowed
  versionWrong = {prefix="N", size=1}, -- Sent to the client if the NETWORK_VERSION they sent is not allowed
  ping = {prefix="E", size=1, verbose = true} -- Sent to the client to confirm they are still connected
}
NetworkProtocol.serverPrefixToMessageType = {}
for _, value in pairs(NetworkProtocol.serverMessageTypes) do
  NetworkProtocol.serverPrefixToMessageType[value.prefix] = value
end

function NetworkProtocol.isMessageTypeVerbose(type)
  return type == NetworkProtocol.serverMessageTypes.ping.prefix
      or type == NetworkProtocol.serverMessageTypes.input.prefix
end

---Encode a relayed player input message body.
---@param playerNumber integer 1-based slot number of the sender
---@param input string encoded input string (controller/touch frames)
---@return string body JSON-encoded body for an "I" frame
function NetworkProtocol.encodeInput(playerNumber, input)
  return json.encode({playerNumber = playerNumber, input = input})
end

---Decode a relayed player input message body.
---@param body string JSON-encoded body from an "I" frame
---@return integer? playerNumber 1-based slot number of the sender, nil on failure
---@return string? input encoded input string, nil on failure
function NetworkProtocol.decodeInput(body)
  local decoded = json.decode(body)
  if type(decoded) ~= "table" then return nil, nil end
  local pn = decoded.playerNumber
  local input = decoded.input
  if type(pn) ~= "number" or type(input) ~= "string" then return nil, nil end
  return pn, input
end

-- Creates a UTF8 message string with the type at the beginning and the end marker at the end
function NetworkProtocol.markedMessageForTypeAndBody(type, body)
  return type .. body .. messageEndMarker
end

-- Returns the next message in the queue, or nil if none / error
---@overload fun(messageBuffer: string, isServerMessage: boolean?): nil, nil, nil
---@overload fun(messageBuffer: string, isServerMessage: boolean?): string, string, string
function NetworkProtocol.getMessageFromString(messageBuffer, isServerMessage)
  assert(isServerMessage ~= nil)

  if string.len(messageBuffer) == 0 then
    return nil
  end

  local type = string.sub(messageBuffer, 1, 1)

  local messageType = nil
  if isServerMessage then
    messageType = NetworkProtocol.serverPrefixToMessageType[type]
  else
    messageType = NetworkProtocol.clientPrefixToMessageType[type]
  end

  if messageType and messageType.size == nil then
    local finishStart, finishEnd = string.find(messageBuffer, messageEndMarker)
    if finishStart ~= nil then
      local message = string.sub(messageBuffer, 2, finishStart-1)
      local remainingBuffer = string.sub(messageBuffer, finishEnd+1)
      return type, message, remainingBuffer
    else
      logger.trace("not all UTF8 data received, waiting: " .. messageBuffer)
      return nil
    end
  else
    if messageType == nil then
      logger.error("Got invalid message type: " .. type)
      return nil
    end
    local len = messageType.size
    if len > string.len(messageBuffer) then
      logger.trace("not all base message for type " .. type .. ", waiting: " .. messageBuffer)
      return nil
    end

    local message = string.sub(messageBuffer, 2, len)
    local remainingBuffer = string.sub(messageBuffer, len+1)
    return type, message, remainingBuffer
  end
end

return NetworkProtocol
