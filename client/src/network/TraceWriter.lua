-- TraceWriter — always-on JSONL recorder for client-side traffic.
--
-- See docs/CRASH_REPLAY_PLAN.md "The trace format" and "Phase D — Client
-- trace tap". The goal: every byte we send or receive, plus local input
-- and lifecycle markers, lands in an append-only JSONL file. The
-- assembler script turns those files into runnable Match fixtures later.
--
-- Failure model: capture is auxiliary. Every public entry is pcall-
-- wrapped. A disk error logs a warning and disables writes for the
-- current game; it never throws into the caller's hot path. Game state
-- is NEVER mutated from here.
--
-- Singleton on purpose: there's one client process and one save-dir
-- root. The module-level table holds all state. Tests inject a fresh
-- rootDir via configure().

local logger = require("common.lib.logger")
local json   = require("common.lib.dkjson")

-- A real love.filesystem under the love runtime; tests inject a stub.
local function loveFS()
  return _G.love and _G.love.filesystem
end

local DEFAULT_ROOT          = "trace_archive"
local DEFAULT_FLUSH_EVENTS  = 64
local DEFAULT_FLUSH_SECONDS = 1.0
-- Pre-game ring buffer: capture activity before a game starts (mostly
-- the matchStart frame itself plus the lobby chatter that led up to it).
-- The buffer is drained verbatim into the game file at beginGame() so the
-- file starts with full context.
local PREGAME_BUFFER_CAP    = 100

---@class TraceWriter
---@field rootDir string                       relative to love.filesystem save dir
---@field session string?                      e.g. "session_<loginTs>"
---@field match string?                        e.g. "match_<room>_<joinedTs>"
---@field gamePath string?                     full file path of the open game JSONL
---@field gameOpen boolean                     true between beginGame and endGame
---@field disabled boolean                     true after repeated write failures
---@field pendingLines string[]                buffered JSONL lines awaiting flush
---@field preGameRing string[]                 ring buffer for pre-beginGame events
---@field preGameRingHead integer              next write index into the ring
---@field flushEvents integer                  flush threshold (event count)
---@field flushSeconds number                  flush threshold (seconds since last)
---@field lastFlush number                     monotonic-ish ts of last flush
---@field clock fun(): number                  wall clock source
---@field fs table                             love.filesystem (or test stub)
local M = {}

local function freshState()
  return {
    rootDir          = DEFAULT_ROOT,
    session          = nil,
    match            = nil,
    gamePath         = nil,
    gameOpen         = false,
    disabled         = false,
    pendingLines     = {},
    preGameRing      = {},
    preGameRingHead  = 1,
    flushEvents      = DEFAULT_FLUSH_EVENTS,
    flushSeconds     = DEFAULT_FLUSH_SECONDS,
    lastFlush        = 0,
    clock            = function() return os.time() end,
    fs               = loveFS(),
  }
end

local state = freshState()

----------------------------------------------------------------------
-- Configuration / lifecycle
----------------------------------------------------------------------

---Test seam. Replaces internal state with the given opts merged in.
---Call before any tap or beginX call. Production wiring leaves this alone.
---@param opts table? { rootDir, flushEvents, flushSeconds, clock, fs }
function M.configure(opts)
  state = freshState()
  if opts then
    state.rootDir      = opts.rootDir      or state.rootDir
    state.flushEvents  = opts.flushEvents  or state.flushEvents
    state.flushSeconds = opts.flushSeconds or state.flushSeconds
    state.clock        = opts.clock        or state.clock
    state.fs           = opts.fs           or state.fs
  end
end

---@param loginTs integer wall-clock seconds at successful login
function M.beginSession(loginTs)
  pcall(function()
    state.session = "session_" .. tostring(loginTs)
    state.match   = nil
    state.gamePath = nil
    state.gameOpen = false
  end)
end

function M.endSession()
  M.endGame()
  state.session = nil
  state.match   = nil
end

---@param roomNumber integer
---@param joinedTs integer wall-clock seconds at room-join
function M.beginMatch(roomNumber, joinedTs)
  pcall(function()
    if not state.session then return end -- pre-login taps are silent
    state.match = string.format("match_%d_%d", roomNumber, joinedTs)
    state.gamePath = nil
    state.gameOpen = false
  end)
end

function M.endMatch()
  M.endGame()
  state.match = nil
end

---Open a per-game JSONL file. Drains the pre-game ring buffer into it
---so the file starts with the matchStart frame + the lobby context that
---led to it. After this call, tap events write directly (modulo buffer).
---
---Auto-initializes session + match if they're missing — convenient for
---single-player flows where there's no login or room to anchor against.
---For multiplayer, lifecycle hooks call beginSession/beginMatch first so
---the directory layout reflects the real flow.
---@param gameStartTs integer wall-clock seconds at the matchStart event
function M.beginGame(gameStartTs)
  pcall(function()
    if state.disabled then return end
    local fs = state.fs
    if not fs then return end

    -- Auto-init session/match for local-only play. Real lifecycle calls
    -- in NetClient/LoginRoutine override these with real values.
    if not state.session then
      state.session = "session_" .. tostring(state.clock())
    end
    if not state.match then
      state.match = "match_local_" .. tostring(state.clock())
    end

    -- Make the directory tree relative to the save dir. love.filesystem
    -- doesn't have mkdir-recursive; love.filesystem.createDirectory
    -- handles intermediates for us.
    local dir = state.rootDir .. "/" .. state.session .. "/" .. state.match
    fs.createDirectory(dir)

    state.gamePath = dir .. "/game_" .. tostring(gameStartTs) .. ".jsonl"
    state.gameOpen = true
    state.lastFlush = state.clock()

    -- Drain the pre-game ring into the file. Walk the ring in
    -- insertion order — newer entries follow older.
    local ring = state.preGameRing
    if #ring > 0 then
      local seed = {}
      local count = #ring
      local head  = state.preGameRingHead
      for i = 0, count - 1 do
        local idx = ((head - count + i) - 1) % count + 1
        seed[#seed + 1] = ring[idx]
      end
      if #seed > 0 then
        local ok, err = pcall(fs.append, state.gamePath, table.concat(seed, "\n") .. "\n")
        if not ok then
          logger.warn("[TraceWriter] pre-game flush failed: " .. tostring(err))
          state.disabled = true
        end
      end
    end
    state.preGameRing = {}
    state.preGameRingHead = 1
  end)
end

---Close the open game file. Force-flush any pending lines.
function M.endGame()
  pcall(M.flush)
  state.gameOpen = false
  state.gamePath = nil
end

----------------------------------------------------------------------
-- Internal: line emit + flush
----------------------------------------------------------------------

local function emit(line)
  if state.disabled then return end
  if state.gameOpen then
    state.pendingLines[#state.pendingLines + 1] = line
    local now = state.clock()
    if #state.pendingLines >= state.flushEvents
        or (now - state.lastFlush) >= state.flushSeconds then
      M.flush()
    end
  else
    -- Pre-game: keep in a bounded ring so beginGame's flush has context.
    local cap = PREGAME_BUFFER_CAP
    state.preGameRing[state.preGameRingHead] = line
    state.preGameRingHead = (state.preGameRingHead % cap) + 1
  end
end

---Force-flush any buffered pendingLines to the open game file.
function M.flush()
  if state.disabled or not state.gameOpen or not state.gamePath then
    return
  end
  if #state.pendingLines == 0 then return end
  local fs = state.fs
  if not fs then return end
  local blob = table.concat(state.pendingLines, "\n") .. "\n"
  state.pendingLines = {}
  state.lastFlush    = state.clock()
  local ok, err = pcall(fs.append, state.gamePath, blob)
  if not ok then
    logger.warn("[TraceWriter] append failed for " .. tostring(state.gamePath)
                .. ": " .. tostring(err))
    state.disabled = true
  end
end

local function encodeLine(entry)
  local ok, encoded = pcall(json.encode, entry)
  if not ok then
    logger.warn("[TraceWriter] encode failed: " .. tostring(encoded))
    return nil
  end
  return encoded
end

----------------------------------------------------------------------
-- The taps. All four are no-throw. Lines categorize themselves via dir.
----------------------------------------------------------------------

---Inbound frame from the server.
---@param prefix string single-char wire prefix (J/I/U/V/G/D/K/E/H/F)
---@param body any decoded table (for J/G/D/K) or raw string (for I/U/V/E)
function M.recv(prefix, body)
  if state.disabled then return end
  pcall(function()
    local line = encodeLine({
      ts     = state.clock(),
      dir    = "recv",
      prefix = prefix,
      body   = body,
    })
    if line then emit(line) end
  end)
end

---Outbound frame to the server.
---@param prefix string single-char wire prefix
---@param body any same shape as recv
function M.send(prefix, body)
  if state.disabled then return end
  pcall(function()
    local line = encodeLine({
      ts     = state.clock(),
      dir    = "send",
      prefix = prefix,
      body   = body,
    })
    if line then emit(line) end
  end)
end

---Local input event — the engine input char produced by a love key/touch.
---Captured before wire compression so it reflects user intent independent
---of network state.
---@param raw string single-char engine input
---@param frame integer? engine frame counter when known
function M.input(raw, frame)
  if state.disabled then return end
  pcall(function()
    local line = encodeLine({
      ts    = state.clock(),
      dir   = "input",
      raw   = raw,
      frame = frame,
    })
    if line then emit(line) end
  end)
end

---Lifecycle / forensic marker. Not load-bearing for engine replay —
---scene transitions, local stack-elimination, connection state changes.
---@param kind string e.g. "sceneTransition", "stackEliminated", "connState"
---@param data table? optional payload
function M.localEvent(kind, data)
  if state.disabled then return end
  pcall(function()
    local line = encodeLine({
      ts   = state.clock(),
      dir  = "local",
      kind = kind,
      data = data,
    })
    if line then emit(line) end
  end)
end

----------------------------------------------------------------------
-- Introspection (for tests + observability)
----------------------------------------------------------------------

function M.isWriting()  return state.gameOpen and not state.disabled end
function M.isDisabled() return state.disabled end
function M.currentPath() return state.gamePath end
function M.pendingCount() return #state.pendingLines end
function M.preGameCount() return #state.preGameRing end

return M
