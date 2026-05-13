-- Scripted protocol-level client for end-to-end multiplayer tests.
--
-- One TestClient owns one luasocket TCP connection and speaks the real
-- on-the-wire protocol (NetworkProtocol.lua). It is NOT a LÖVE client —
-- no rendering, no engine, no audio. The harness owns the Server side and
-- pumps both ends cooperatively in a single LuaJIT process.
--
-- Lifecycle (call in order):
--   c = TestClient("BotA")
--   c:connect("127.0.0.1", 49580)
--   c:sendVersionCheck()
--   -- harness:tick() until c.versionConfirmed
--   c:sendLogin()
--   -- harness:tick() until c.loggedIn
--   c:sendRoomRequest("OPEN_FFA", "relaxed")
--   -- harness:tick() until c.roomNumber ~= nil
--   c:sendReady()
--   ...
--   c:close()

---@diagnostic disable-next-line: different-requires
local socket = require("common.lib.socket")
local json = require("common.lib.dkjson")
local class = require("common.lib.class")
local NetworkProtocol = require("common.network.NetworkProtocol")
local logger = require("common.lib.logger")

---@class TestClient
---@field name string                  display name for log lines + login
---@field socket TcpSocket?            luasocket client; nil after close
---@field buffer string                raw byte buffer of unparsed receive data
---@field versionConfirmed boolean     server accepted our NETWORK_VERSION
---@field loggedIn boolean             server sent login_successful
---@field publicId integer?            assigned on login
---@field userId string                "need a new user id" until server assigns one
---@field roomNumber integer?          set when we receive addToRoom
---@field gameStarted boolean          set when we receive startMatch
---@field matchEnded boolean           set when we receive a leaveRoom/game-end signal
---@field lastStartMatch table?        the full startMatch payload (includes replay)
---@field lastSpectateGranted table?   most recent spectateRequestGranted content (includes replay)
---@field inbox table                  routed messages by kind
local TestClient = class(function(self, name)
  self.name = name or "Bot"
  self.socket = nil
  self.buffer = ""

  self.versionConfirmed = false
  self.loggedIn = false
  self.publicId = nil
  self.userId = "need a new user id"
  self.roomNumber = nil
  self.gameStarted = false
  self.matchEnded = false
  self.lastStartMatch = nil
  self.lastSpectateGranted = nil

  -- One inbox per message kind so scenarios can express assertions
  -- like "wait until c.inbox.json has a startMatch message".
  self.inbox = {
    json = {},       -- decoded JSON tables (J prefix)
    input = {},      -- {prefix=<I|U|V|...>, body=<raw>} relayed peer inputs
    garbage = {},    -- decoded GarbageEvent payloads (G prefix)
    death = {},      -- decoded DeathEvent payloads (D prefix)
    ko = {},         -- decoded KO arbitration payloads (K prefix)
    pings = 0,       -- count of E pings (auto-acknowledged)
  }
end)

-- ----------------------------------------------------------------------------
-- Connection
-- ----------------------------------------------------------------------------

function TestClient:connect(ip, port)
  self.socket = socket.tcp()
  self.socket:settimeout(3) -- block briefly while connecting
  local ok, err = self.socket:connect(ip, port)
  if not ok then
    error(self.name .. ": connect to " .. ip .. ":" .. port .. " failed: " .. tostring(err))
  end
  self.socket:settimeout(0) -- non-blocking from here on
  return self
end

function TestClient:close()
  if self.socket then
    self.socket:close()
    self.socket = nil
  end
end

-- ----------------------------------------------------------------------------
-- Low-level send (raw bytes / prefixed frames)
-- ----------------------------------------------------------------------------

-- Internal: send raw bytes. Asserts on partial/failed send.
-- For e2e tests we keep this strict — silently dropping bytes would be a
-- much worse failure mode than crashing the scenario.
function TestClient:_sendRaw(bytes)
  assert(self.socket, self.name .. ": send on closed socket")
  local sent, err, partial = self.socket:send(bytes)
  if not sent then
    -- Partial send: retry the tail (rare for these tiny test messages
    -- but harmless to handle).
    if partial and partial > 0 and partial < #bytes then
      return self:_sendRaw(bytes:sub(partial + 1))
    end
    error(self.name .. ": socket send failed: " .. tostring(err))
  end
  if sent < #bytes then
    return self:_sendRaw(bytes:sub(sent + 1))
  end
end

function TestClient:_sendFrame(prefix, body)
  self:_sendRaw(NetworkProtocol.markedMessageForTypeAndBody(prefix, body))
end

function TestClient:sendJson(payload)
  local body = json.encode(payload)
  self:_sendFrame(NetworkProtocol.clientMessageTypes.jsonMessage.prefix, body)
end

-- ----------------------------------------------------------------------------
-- Handshake helpers (the canonical client flow)
-- ----------------------------------------------------------------------------

function TestClient:sendVersionCheck()
  -- Wire frame: "H" + 3-char NETWORK_VERSION, fixed 4-byte size.
  self:_sendRaw(NetworkProtocol.clientMessageTypes.versionCheck.prefix
                .. NetworkProtocol.NETWORK_VERSION)
end

function TestClient:sendLogin(opts)
  opts = opts or {}
  self:sendJson({
    login_request = true,
    user_id = opts.userId or self.userId,
    name = self.name,
    engine_version = NetworkProtocol.NETWORK_VERSION,
    level = opts.level or 5,
    inputMethod = opts.inputMethod or "controller",
    character = opts.character or "__default",
    stage = opts.stage or "__default",
    save_replays_publicly = opts.saveReplays or "not at all",
  })
end

-- Request the server create a room for this gameMode. Matches the wire shape
-- produced by ClientProtocol.sendRoomRequest -> ClientMessages.sanitizeRoomRequest.
-- gameModeIdOrName can be either an ID ("OPEN_FFA") or a name ("open_ffa"); the
-- server resolves both.
--
-- The optional seed argument exercises the dev-only seedOverride path added in
-- Game.createFromRoomState — when set, every run of the scenario gets the same
-- panel sequence, so scripted scenarios produce stable outcomes.
function TestClient:sendRoomRequest(gameModeIdOrName, latencyTolerance, seed)
  self:sendJson({
    type = "roomRequest",
    content = {
      gameMode = { gameModeId = gameModeIdOrName, name = gameModeIdOrName },
      latencyTolerance = latencyTolerance or "relaxed",
      seed = seed,
    },
  })
end

-- Drop into an existing room (the FFA-style "open" join path).
function TestClient:sendJoinRoomRequest(roomNumber, slotNumber)
  self:sendJson({
    joinRoomRequest = {
      roomNumber = roomNumber,
      slotNumber = slotNumber, -- nil = take any free slot
    },
  })
end

-- Signal "ready to start the match". The server starts the match once every
-- player in the room has sent ready=true + loaded=true.
function TestClient:sendReady()
  self:sendJson({
    menu_state = {
      ready = true,
      loaded = true,
      wants_ready = true,
      inputMethod = "controller",
      character = "__default",
      stage = "__default",
      level = 5,
    },
  })
end

function TestClient:sendLeaveRoom()
  self:sendJson({ leave_room = true })
end

-- ----------------------------------------------------------------------------
-- In-match send helpers
-- ----------------------------------------------------------------------------

-- Send one frame of input encoded as a single character (controller mode).
-- Multiple chars per call = multiple frames; server forwards the buffer verbatim.
function TestClient:sendInput(inputChars)
  self:_sendFrame(NetworkProtocol.clientMessageTypes.playerInput.prefix, inputChars)
end

function TestClient:sendStackEliminated(frame)
  self:sendJson({ stackEliminated = true, frame = frame })
end

-- Loose-sync: client-emitted garbage delivery event. Body shape mirrors
-- Match.lua's production emission (senderFrame, recipients, garbage). The
-- server stamps sender + serverWallClockMs in Room:broadcastGarbageEvent.
function TestClient:sendGarbageEvent(body)
  self:_sendFrame(NetworkProtocol.clientMessageTypes.garbageEvent.prefix, json.encode(body))
end

-- Loose-sync: client-emitted death notification. Same wire shape as G; the
-- server uses it to drive arbitration + survivor stop-waiting.
function TestClient:sendDeathEvent(body)
  self:_sendFrame(NetworkProtocol.clientMessageTypes.deathEvent.prefix, json.encode(body))
end

-- Ask the server to spectate a room in progress. Server replies with a
-- spectateRequestGranted JSON message carrying a partial replay — captured
-- on self.lastSpectateGranted by the inbox router.
function TestClient:sendSpectateRequest(roomNumber)
  self:sendJson({
    spectate_request = {
      sender = self.name,
      roomNumber = roomNumber,
    },
  })
end

-- ----------------------------------------------------------------------------
-- Receive + inbox routing
-- ----------------------------------------------------------------------------

-- Drain whatever bytes the kernel has buffered, parse out complete frames,
-- and route each into the appropriate inbox. Safe to call repeatedly; never
-- blocks (socket is non-blocking).
function TestClient:poll()
  if not self.socket then return end

  -- Drain the kernel buffer in one go. luasocket signals "timeout" with the
  -- partial bytes — we want those even though no error meant "got a chunk".
  local chunk, err, partial = self.socket:receive("*a")
  if err == "timeout" then chunk = partial end
  if chunk and #chunk > 0 then
    self.buffer = self.buffer .. chunk
  end
  if err and err ~= "timeout" then
    -- "closed" is the normal end-of-stream marker after server-side close.
    if err == "closed" then
      self:close()
      return
    end
    error(self.name .. ": socket receive failed: " .. tostring(err))
  end

  while true do
    local prefix, body, rest = NetworkProtocol.getMessageFromString(self.buffer, true)
    if not prefix then break end
    self.buffer = rest
    self:_dispatch(prefix, body)
  end
end

function TestClient:_dispatch(prefix, body)
  local s = NetworkProtocol.serverMessageTypes
  if prefix == s.versionCorrect.prefix then
    -- "H" body is empty/1-byte; ignore content.
    self.versionConfirmed = true
  elseif prefix == s.versionWrong.prefix then
    error(self.name .. ": server rejected NETWORK_VERSION " .. NetworkProtocol.NETWORK_VERSION)
  elseif prefix == s.jsonMessage.prefix then
    local msg, _, decodeErr = json.decode(body)
    if not msg then
      error(self.name .. ": failed to decode JSON frame: " .. tostring(decodeErr) .. " :: " .. body:sub(1, 200))
    end
    table.insert(self.inbox.json, msg)
    self:_observeJson(msg)
  elseif prefix == s.ping.prefix then
    -- Keepalive — auto-acknowledge so the connection-watchdog doesn't kick us.
    self.inbox.pings = self.inbox.pings + 1
    self:_sendRaw(NetworkProtocol.clientMessageTypes.acknowledgedPing.prefix)
  elseif prefix == s.input.prefix then
    -- Unified input message: JSON body {playerNumber, input}. Decode so test
    -- scenarios can inspect playerNumber without re-parsing.
    local playerNumber, inputBody = NetworkProtocol.decodeInput(body)
    table.insert(self.inbox.input, { playerNumber = playerNumber, input = inputBody, body = body })
  elseif prefix == s.garbageEvent.prefix then
    local msg = json.decode(body)
    table.insert(self.inbox.garbage, msg)
  elseif prefix == s.deathEvent.prefix then
    local msg = json.decode(body)
    table.insert(self.inbox.death, msg)
  elseif prefix == s.koArbitration.prefix then
    local msg = json.decode(body)
    table.insert(self.inbox.ko, msg)
  else
    logger.warn(self.name .. ": ignoring unknown frame prefix '" .. tostring(prefix) .. "'")
  end
end

-- Watch incoming JSON for state-shifting messages (login result, room join, match
-- start, match end) and project them onto the client's high-level state fields
-- so scenarios can read `c.loggedIn`, `c.roomNumber`, etc. without scanning the
-- inbox by hand.
--
-- We read the raw on-the-wire shape from common/network/ServerProtocol.lua —
-- not the post-sanitization form that client/src/network/ServerMessages.lua
-- produces (which the real LÖVE client uses). Bypassing the client-side
-- sanitizer means we have to recognize the original {type, content} envelope
-- shapes directly.
function TestClient:_observeJson(msg)
  local mtype = msg.type
  local content = msg.content

  if mtype == "loginResponse" and content then
    if content.approved then
      self.loggedIn = true
      self.publicId = content.publicId or self.publicId
      if content.newUserId then self.userId = content.newUserId end
    else
      error(self.name .. ": login denied: " .. tostring(content.reason))
    end
  end

  -- addToRoom (server -> all room members): payload has content.roomNumber.
  if mtype == "addToRoom" and content and content.roomNumber then
    self.roomNumber = content.roomNumber
  end

  -- matchStart (server -> all room members at match-start). The content IS the
  -- replay table (no nested .replay field). See ServerProtocol.startMatch.
  if mtype == "matchStart" then
    self.gameStarted = true
    self.lastStartMatch = content
  end

  -- leaveRoom from the server signals "match concluded, returning you to lobby".
  if mtype == "leaveRoom" then
    self.matchEnded = true
  end

  -- spectateRequestGranted carries a partial replay (content.replay) including
  -- crossPlayerEvents for catch-up. Store the raw content so scenarios can
  -- assert on the wire shape without re-walking the inbox.
  if mtype == "spectateRequestGranted" and content then
    self.lastSpectateGranted = content
  end
end

-- ----------------------------------------------------------------------------
-- Inbox query helpers (scenario sugar)
-- ----------------------------------------------------------------------------

-- Find the first JSON message satisfying predicate(msg) -> boolean.
-- Non-destructive; returns msg, index.
function TestClient:findJson(predicate)
  for i, msg in ipairs(self.inbox.json) do
    if predicate(msg) then return msg, i end
  end
end

-- Same as findJson but removes the matched message from the inbox.
function TestClient:consumeJson(predicate)
  local msg, i = self:findJson(predicate)
  if msg then table.remove(self.inbox.json, i) end
  return msg
end

-- Count the number of relayed input frames received from a specific peer
-- (identified by the player-input prefix the server uses for that peer:
-- "I" = player 1, "U" = player 2, "V" = player 3, etc.).
function TestClient:countInputsFromPrefix(prefix)
  local n = 0
  for _, frame in ipairs(self.inbox.input) do
    if frame.prefix == prefix then n = n + 1 end
  end
  return n
end

-- ----------------------------------------------------------------------------
-- Trace replay
-- ----------------------------------------------------------------------------

---Apply one captured `send` event back to the wire. The dispatcher is
---deliberately narrow: every prefix maps to one of the existing
---sendX methods so replay rides the same code path a real client would
---have used at capture time. Returns true if the event was handled,
---false if it was intentionally skipped (e.g. H/E, which are harness-
---managed).
---@param prefix string single-char wire prefix
---@param body any decoded JSON table (J/G/D) or raw input string (I)
---@return boolean handled
function TestClient:_replaySendEvent(prefix, body)
  if prefix == "J" then
    -- Every J-prefixed outbound is a JSON envelope. The body table is
    -- whatever the client originally sent (login_request, roomRequest,
    -- menu_state, leave_room, etc.) — sendJson takes it as-is.
    self:sendJson(body)
    return true
  elseif prefix == "I" and type(body) == "string" then
    self:sendInput(body)
    return true
  elseif prefix == "G" and type(body) == "table" then
    self:sendGarbageEvent(body)
    return true
  elseif prefix == "D" and type(body) == "table" then
    self:sendDeathEvent(body)
    return true
  end
  -- H (version check) and E (ping ack) are managed by the harness
  -- setup; replaying them would conflict with the connect handshake.
  return false
end

---Walk a JSONL blob and replay every `send` event through the wire.
---Ignores recv / input / local lines — those record what HAPPENED at
---capture time, not actions to drive. The harness's server is the
---thing that produces the equivalent recv stream during replay.
---@param blob string raw JSONL contents of one trace file
---@return integer replayed how many send events were dispatched
function TestClient:replayTrace(blob)
  local replayed = 0
  for line in blob:gmatch("[^\n]+") do
    if line:match("%S") then
      local ok, entry = pcall(json.decode, line)
      if ok and type(entry) == "table" and entry.dir == "send" then
        if self:_replaySendEvent(entry.prefix, entry.body) then
          replayed = replayed + 1
        end
      end
    end
  end
  return replayed
end

return TestClient
