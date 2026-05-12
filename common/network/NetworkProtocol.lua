local logger = require("common.lib.logger")

local NetworkProtocol = {}

-- Version 001 was super legacy
-- Version 002 we supported unicode JSON
-- Version 003 we updated login requirements and started sending the network version
-- Version 004 server communicates replays in a new standardised format
NetworkProtocol.NETWORK_VERSION = "006"

local messageEndMarker = "←J←"

-- All the types sent by clients and servers
-- Prefix is what is put at the front of the message
-- Then size data follows in normal single byte sequence.
-- if size is nil then a variable utf8 byte sequence follows terminated by messageEndMarker
NetworkProtocol.clientMessageTypes = {
  jsonMessage = {prefix="J", size=nil}, -- Generic JSON message sent from the client
  playerInput = {prefix="I", size=nil}, -- Player input (touch or controller) from the client
  garbageEvent = {prefix="G", size=nil}, -- Loose-sync: sender-emitted garbage delivery event (JSON body)
  deathEvent = {prefix="D", size=nil}, -- Loose-sync: sender-emitted death notification (JSON body)
  acknowledgedPing = {prefix="E", size=1}, -- Respond back from the servers ping to confirm we are still connected
  versionCheck = {prefix="H", size=4} -- Sent on initial connection with the NETWORK_VERSION number to confirm client and server agree
}
NetworkProtocol.clientPrefixToMessageType = {}
for _, value in pairs(NetworkProtocol.clientMessageTypes) do
  NetworkProtocol.clientPrefixToMessageType[value.prefix] = value
end

-- Input prefixes for each player slot (server → client). Reserves I,U,V,W for slots 1-4
-- and extends with X,Y,Z,Q for slots 5-8. Non-input prefixes in use: J,E,H,N,G,D,K.
NetworkProtocol.playerInputPrefixes = {"I", "U", "V", "W", "X", "Y", "Z", "Q"}

NetworkProtocol.serverMessageTypes = {
  jsonMessage = {prefix="J", size=nil}, -- Generic JSON message sent from the server
  opponentInput = {prefix="I", size=nil, verbose = true}, -- Player input (touch or controller) sent to the client about it's opponent
  secondOpponentInput = {prefix="U", size=nil, verbose = true}, -- Player input (touch or controller) sent to the client for player two if spectating
  thirdOpponentInput = {prefix="V", size=nil, verbose = true}, -- Player input for player three in 3-4 player games
  fourthOpponentInput = {prefix="W", size=nil, verbose = true}, -- Player input for player four in 4 player games
  fifthOpponentInput = {prefix="X", size=nil, verbose = true},
  sixthOpponentInput = {prefix="Y", size=nil, verbose = true},
  seventhOpponentInput = {prefix="Z", size=nil, verbose = true},
  eighthOpponentInput = {prefix="Q", size=nil, verbose = true},
  garbageEvent = {prefix="G", size=nil, verbose = true}, -- Loose-sync: relayed sender-emitted garbage delivery event
  deathEvent = {prefix="D", size=nil}, -- Loose-sync: relayed sender-emitted death notification
  koArbitration = {prefix="K", size=nil}, -- Loose-sync: server-authored simultaneous-KO arbitration result
  versionCorrect = {prefix="H", size=1}, -- Sent to the client if the NETWORK_VERSION they sent is allowed
  versionWrong = {prefix="N", size=1}, -- Sent to the client if the NETWORK_VERSION they sent is not allowed
  ping = {prefix="E", size=1, verbose = true} -- Sent to the client to confirm they are still connected
}
NetworkProtocol.serverPrefixToMessageType = {}
for _, value in pairs(NetworkProtocol.serverMessageTypes) do
  NetworkProtocol.serverPrefixToMessageType[value.prefix] = value
end

local inputPrefixSet = {}
for _, p in ipairs(NetworkProtocol.playerInputPrefixes) do
  inputPrefixSet[p] = true
end

NetworkProtocol.playerIndexForInputPrefix = {}
for i, p in ipairs(NetworkProtocol.playerInputPrefixes) do
  NetworkProtocol.playerIndexForInputPrefix[p] = i
end

function NetworkProtocol.isInputPrefix(prefix)
  return inputPrefixSet[prefix] == true
end

function NetworkProtocol.getInputPrefixForPlayer(playerNumber)
  return NetworkProtocol.playerInputPrefixes[playerNumber]
end

function NetworkProtocol.isMessageTypeVerbose(type)
  return type == NetworkProtocol.serverMessageTypes.ping.prefix or NetworkProtocol.isInputPrefix(type)
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