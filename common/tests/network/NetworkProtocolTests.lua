local NetworkProtocol = require("common.network.NetworkProtocol")

local function testGetMessage(messageBuffer, expectedTypes, expectedMessages, isServerMessage)
  local buffer = messageBuffer
  local typeResults = {}
  local messageResults = {}
  while buffer ~= nil do
    local type, message, remaining = NetworkProtocol.getMessageFromString(buffer, isServerMessage)
    if type then
      typeResults[#typeResults+1] = type
      messageResults[#messageResults+1] = message
      buffer = remaining
    else
      buffer = nil
    end
  end

  assert(#expectedTypes == #typeResults)
  assert(#expectedMessages == #messageResults)

  for i = 1, #typeResults do
    assert(expectedTypes[i] == typeResults[i])
    assert(expectedMessages[i] == messageResults[i])
  end
end

-- Test we can send I unicode messages with part of the next message after
testGetMessage("H048" .. NetworkProtocol.markedMessageForTypeAndBody("I", "Ā") .. "I", {"H", "I"}, {"048", "Ā"}, false)
testGetMessage("H" .. NetworkProtocol.markedMessageForTypeAndBody("I", "Ā") .. "I", {"H", "I"}, {"", "Ā"}, true)

-- Test we can send a J and then H message
testGetMessage(NetworkProtocol.markedMessageForTypeAndBody("J", "{body=1}") .. "H", {"J", "H"}, {"{body=1}", ""}, true)

-- Test we can send a J and then part of the next message after
testGetMessage(NetworkProtocol.markedMessageForTypeAndBody("J", "{body=1}") .. "J" .. string.char(128), {"J"}, {"{body=1}"}, true)

-- Loose-sync: G (GarbageEvent), D (DeathEvent), K (KOArbitration) round-trip
testGetMessage(NetworkProtocol.markedMessageForTypeAndBody("G", '{"sender":1}'), {"G"}, {'{"sender":1}'}, true)
testGetMessage(NetworkProtocol.markedMessageForTypeAndBody("D", '{"sender":2}'), {"D"}, {'{"sender":2}'}, true)
testGetMessage(NetworkProtocol.markedMessageForTypeAndBody("K", '{"tie":true}'), {"K"}, {'{"tie":true}'}, true)
-- And client→server direction for G and D
testGetMessage(NetworkProtocol.markedMessageForTypeAndBody("G", '{"sender":1}'), {"G"}, {'{"sender":1}'}, false)
testGetMessage(NetworkProtocol.markedMessageForTypeAndBody("D", '{"sender":2}'), {"D"}, {'{"sender":2}'}, false)

-- Confirm the registration tables agree
assert(NetworkProtocol.serverPrefixToMessageType["G"] ~= nil, "G must be a registered server prefix")
assert(NetworkProtocol.serverPrefixToMessageType["D"] ~= nil, "D must be a registered server prefix")
assert(NetworkProtocol.serverPrefixToMessageType["K"] ~= nil, "K must be a registered server prefix")
assert(NetworkProtocol.clientPrefixToMessageType["G"] ~= nil, "G must be a registered client prefix")
assert(NetworkProtocol.clientPrefixToMessageType["D"] ~= nil, "D must be a registered client prefix")
assert(NetworkProtocol.clientPrefixToMessageType["K"] == nil, "K is server-to-client only")

-- Unified input message: single "I" server prefix with JSON body {playerNumber, input}
assert(NetworkProtocol.serverMessageTypes.input.prefix == "I", "unified input prefix is I")
assert(NetworkProtocol.serverPrefixToMessageType["I"] ~= nil, "I must be a registered server prefix")

-- encodeInput / decodeInput round-trip across the full plausible slot range
for _, pn in ipairs({1, 2, 3, 4, 5, 6, 7, 8, 16}) do
  local body = NetworkProtocol.encodeInput(pn, "abc")
  local decodedPn, decodedInput = NetworkProtocol.decodeInput(body)
  assert(decodedPn == pn, "decodeInput should round-trip playerNumber=" .. pn .. ", got " .. tostring(decodedPn))
  assert(decodedInput == "abc", "decodeInput should round-trip input, got " .. tostring(decodedInput))
end

-- decodeInput tolerates malformed bodies without throwing
do
  local pn, input = NetworkProtocol.decodeInput("not json")
  assert(pn == nil and input == nil, "malformed JSON should decode to nil, nil")
end
do
  local pn, input = NetworkProtocol.decodeInput('{"playerNumber":"oops","input":"abc"}')
  assert(pn == nil and input == nil, "non-integer playerNumber should decode to nil, nil")
end