local logger = require("common.lib.logger")
local json = require("common.lib.dkjson")

local NetworkProtocol = {}

-- Version 001 was super legacy
-- Version 002 we supported unicode JSON
-- Version 003 we updated login requirements and started sending the network version
-- Version 004 server communicates replays in a new standardised format
-- Version 008 unified input message: single "I" prefix with JSON body {playerNumber, input},
--             replacing the per-slot prefixes (I,U,V,W,X,Y,Z,Q). No 8-player wire cap.
-- Version 009 length-prefixed framing: every frame is [4-byte BE length][1-byte prefix][body].
--             Length includes the prefix byte (so length == 1 + #body, minimum 1).
--             Replaces the prior "←J← UTF-8 sentinel for variable types, fixed-size table for
--             H/E" mix with a single uniform wire shape. Cannot interop with <=008 clients.
NetworkProtocol.NETWORK_VERSION = "009"

-- All the types sent by clients and servers. Length-prefixed framing means
-- we don't need a `size` table — the wire tells us how big each frame is.
NetworkProtocol.clientMessageTypes = {
  jsonMessage = {prefix="J"},      -- Generic JSON message sent from the client
  playerInput = {prefix="I"},      -- Player input (raw encoded input string).
  garbageEvent = {prefix="G"},     -- Loose-sync GarbageEvent (JSON body)
  deathEvent = {prefix="D"},       -- Loose-sync DeathEvent (JSON body)
  rewindEvent = {prefix="R"},      -- Pause-mode rewind commit (JSON body)
  acknowledgedPing = {prefix="E"}, -- Ping ack (empty body)
  versionCheck = {prefix="H"},     -- Initial handshake; body is NETWORK_VERSION
}
NetworkProtocol.clientPrefixToMessageType = {}
for _, value in pairs(NetworkProtocol.clientMessageTypes) do
  NetworkProtocol.clientPrefixToMessageType[value.prefix] = value
end

NetworkProtocol.serverMessageTypes = {
  jsonMessage = {prefix="J"},                        -- Generic JSON message from the server
  input = {prefix="I", verbose=true},                -- Relayed player input
  garbageEvent = {prefix="G", verbose=true},         -- Relayed GarbageEvent
  deathEvent = {prefix="D"},                         -- Relayed DeathEvent
  rewindEvent = {prefix="R"},                        -- Relayed RewindEvent
  versionCorrect = {prefix="H"},                     -- Sent if client's NETWORK_VERSION matches
  versionWrong = {prefix="N"},                       -- Sent if client's NETWORK_VERSION mismatches
  ping = {prefix="E", verbose=true},                 -- Ping (empty body); client replies with E
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
  local ok, decoded = pcall(json.decode, body)
  if not ok or type(decoded) ~= "table" then return nil, nil end
  local pn = decoded.playerNumber
  local input = decoded.input
  if type(pn) ~= "number" or type(input) ~= "string" then return nil, nil end
  return pn, input
end

-- 4-byte big-endian length codec. Avoids `bit` so it works on plain Lua 5.1
-- without LuaJIT's bitops. 32-bit unsigned range; we cap practical frame size
-- via the receive-buffer guard in TcpClient/Connection.
local function packLengthBE(len)
  return string.char(
    math.floor(len / 16777216) % 256,
    math.floor(len / 65536) % 256,
    math.floor(len / 256) % 256,
    len % 256)
end

local function unpackLengthBE(s, offset)
  return string.byte(s, offset)     * 16777216
       + string.byte(s, offset + 1) * 65536
       + string.byte(s, offset + 2) * 256
       + string.byte(s, offset + 3)
end

NetworkProtocol.packLengthBE = packLengthBE
NetworkProtocol.unpackLengthBE = unpackLengthBE

-- Build a wire frame: [4-byte BE length][1-byte prefix][body].
-- `length` covers prefix + body, so it's always >= 1.
function NetworkProtocol.markedMessageForTypeAndBody(prefix, body)
  body = body or ""
  return packLengthBE(1 + #body) .. prefix .. body
end

-- Parse one frame from the head of `messageBuffer`.
-- Returns (prefix, body, remaining) on success.
-- Returns nil on "need more data".
-- A frame with length < 1 logs an error and is dropped (returns nil); the
-- caller's receive-buffer cap catches a cascade of malformed frames.
---@overload fun(messageBuffer: string, isServerMessage: boolean?): nil, nil, nil
---@overload fun(messageBuffer: string, isServerMessage: boolean?): string, string, string
function NetworkProtocol.getMessageFromString(messageBuffer, isServerMessage)
  assert(isServerMessage ~= nil)
  if #messageBuffer < 4 then return nil end
  local frameLen = unpackLengthBE(messageBuffer, 1)
  if frameLen < 1 then
    logger.error("NetworkProtocol: invalid frame length " .. tostring(frameLen) .. "; dropping buffer head")
    return nil
  end
  if #messageBuffer < 4 + frameLen then return nil end  -- partial frame; wait
  local prefix = string.sub(messageBuffer, 5, 5)
  local body = string.sub(messageBuffer, 6, 4 + frameLen)
  local remaining = string.sub(messageBuffer, 5 + frameLen)
  return prefix, body, remaining
end

return NetworkProtocol
