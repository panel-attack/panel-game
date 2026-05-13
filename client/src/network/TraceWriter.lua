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
---@class TraceWriter
---Three scopes; each one has its own JSONL file:
---  - SESSION (login → logout)      → dir session_<loginTs>/
---  - MATCH   (room-join → leave)   → dir match_<room>_<joinedTs>/, file _match.jsonl
---  - GAME    (matchStart → end)    → file game_<gameStartTs>.jsonl
---Emit target is chosen by state: game file if open, else match file,
---else pre-match ring buffer (capped). Lifecycle calls flush pending
---lines before switching files so no line crosses scope boundaries.
---@field rootDir string
---@field session string?                      e.g. "session_<loginTs>"
---@field match string?                        e.g. "match_<room>_<joinedTs>"
---@field matchPath string?                    full path of _match.jsonl
---@field matchOpen boolean                    true between beginMatch + endMatch
---@field gamePath string?                     full path of game_<ts>.jsonl
---@field gameOpen boolean                     true between beginGame + endGame
---@field disabled boolean                     true after repeated write failures
---@field pendingLines string[]                buffered lines awaiting flush
---@field preMatchRing string[]                ring buffer for events before any match
---@field preMatchRingHead integer
---@field flushEvents integer
---@field flushSeconds number
---@field lastFlush number
---@field clock fun(): number
---@field fs table
local M = {}

local function freshState()
  return {
    rootDir          = DEFAULT_ROOT,
    session          = nil,
    match            = nil,
    matchPath        = nil,
    matchOpen        = false,
    gamePath         = nil,
    gameOpen         = false,
    disabled         = false,
    pendingLines     = {},
    preMatchRing     = {},
    preMatchRingHead = 1,
    flushEvents      = DEFAULT_FLUSH_EVENTS,
    flushSeconds     = DEFAULT_FLUSH_SECONDS,
    lastFlush        = 0,
    clock            = function() return os.time() end,
    fs               = loveFS(),
  }
end

local state = freshState()

-- Forward declarations so beginGame / endGame can call emit + encodeLine
-- which are defined further down (Lua locals are lexically scoped — a
-- function captures the upvalue at definition time, so the local must
-- exist before the function is defined).
local emit, encodeLine

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
    state.session   = "session_" .. tostring(loginTs)
    state.match     = nil
    state.matchPath = nil
    state.matchOpen = false
    state.gamePath  = nil
    state.gameOpen  = false
  end)
end

function M.endSession()
  M.endMatch()
  state.session = nil
end

---@return string? full path of whichever file is currently the emit target
local function currentTarget()
  if state.gameOpen then return state.gamePath end
  if state.matchOpen then return state.matchPath end
  return nil
end

---Drain the pre-match ring buffer into the given file. Used by the
---first transition into match/game scope so the file starts with the
---ambient context (lobby chatter, addToRoom, etc.) that led to the
---scope opening.
local function drainPreMatchRing(path)
  local fs = state.fs
  if not fs then return end
  local ring = state.preMatchRing
  if #ring == 0 then return end
  local seed = {}
  local count = #ring
  local head  = state.preMatchRingHead
  for i = 0, count - 1 do
    local idx = ((head - count + i) - 1) % count + 1
    seed[#seed + 1] = ring[idx]
  end
  if #seed > 0 then
    local ok, err = pcall(fs.append, path, table.concat(seed, "\n") .. "\n")
    if not ok then
      logger.warn("[TraceWriter] pre-match flush failed: " .. tostring(err))
      state.disabled = true
    end
  end
  state.preMatchRing = {}
  state.preMatchRingHead = 1
end

---@param roomNumber integer
---@param joinedTs integer wall-clock seconds at room-join
function M.beginMatch(roomNumber, joinedTs)
  pcall(function()
    if state.disabled then return end
    if not state.session then return end -- pre-login taps are silent
    local fs = state.fs
    if not fs then return end

    state.match = string.format("match_%d_%d", roomNumber, joinedTs)
    local dir  = state.rootDir .. "/" .. state.session .. "/" .. state.match
    fs.createDirectory(dir)
    state.matchPath = dir .. "/_match.jsonl"
    state.matchOpen = true
    state.lastFlush = state.clock()

    -- Pre-match ambient context (lobby chatter, addToRoom etc.) drains
    -- into the match file so we have the lead-up to this room-join.
    drainPreMatchRing(state.matchPath)
  end)
end

function M.endMatch()
  -- endGame first so any per-game pending lines land in the game file,
  -- not the match file.
  M.endGame()
  pcall(M.flush)
  state.matchOpen = false
  state.matchPath = nil
  state.match = nil
end

---Open a per-game JSONL file. Auto-initializes session + match if
---they're missing (single-player flows). For multiplayer the real
---lifecycle hooks have already opened the match.
---
---Emits a `local kind=gameBegin` marker into _match.jsonl BEFORE
---switching target, so the match file's timeline shows where each
---game in the match started. The gameStartTs links to the per-game
---filename (`game_<gameStartTs>.jsonl`).
---@param gameStartTs integer wall-clock seconds at the matchStart event
function M.beginGame(gameStartTs)
  pcall(function()
    if state.disabled then return end
    local fs = state.fs
    if not fs then return end

    -- Flush any pending match-scope lines BEFORE switching target. This
    -- guarantees no line crosses the match→game boundary.
    M.flush()

    if not state.session then
      state.session = "session_" .. tostring(state.clock())
    end
    if not state.match then
      -- Single-player path: no real room, but we still want a directory.
      state.match = "match_local_" .. tostring(state.clock())
      local dir = state.rootDir .. "/" .. state.session .. "/" .. state.match
      fs.createDirectory(dir)
      state.matchPath = dir .. "/_match.jsonl"
      state.matchOpen = true
      drainPreMatchRing(state.matchPath)
    end

    -- Connection marker: drop a "gameBegin" line into the match file
    -- pointing at the game file we're about to open. Match scope is
    -- still the current target so this writes to _match.jsonl.
    local beginMarker = encodeLine({
      ts          = state.clock(),
      dir         = "local",
      kind        = "gameBegin",
      gameStartTs = gameStartTs,
      gameFile    = "game_" .. tostring(gameStartTs) .. ".jsonl",
    })
    if beginMarker then
      emit(beginMarker)
      M.flush()
    end

    local dir = state.rootDir .. "/" .. state.session .. "/" .. state.match
    fs.createDirectory(dir)

    state.gamePath = dir .. "/game_" .. tostring(gameStartTs) .. ".jsonl"
    state.gameOpen = true
    state.lastFlush = state.clock()
  end)
end

---Close the open game file. Force-flush any pending lines. Match scope
---stays open — subsequent emits go back to _match.jsonl. Drops a
---"gameEnded" marker in the match file as the connection bread-crumb.
function M.endGame()
  pcall(function()
    if not state.gameOpen then return end
    M.flush()
    state.gameOpen = false
    state.gamePath = nil
    if state.matchOpen then
      local endMarker = encodeLine({
        ts   = state.clock(),
        dir  = "local",
        kind = "gameEnded",
      })
      if endMarker then
        emit(endMarker)
        M.flush()
      end
    end
  end)
end

----------------------------------------------------------------------
-- Internal: line emit + flush
----------------------------------------------------------------------

emit = function(line)
  if state.disabled then return end
  if state.gameOpen or state.matchOpen then
    state.pendingLines[#state.pendingLines + 1] = line
    local now = state.clock()
    if #state.pendingLines >= state.flushEvents
        or (now - state.lastFlush) >= state.flushSeconds then
      M.flush()
    end
  else
    -- No file open: keep in a bounded ring so the first beginMatch/Game
    -- has the immediate lead-up context.
    local cap = PREGAME_BUFFER_CAP
    state.preMatchRing[state.preMatchRingHead] = line
    state.preMatchRingHead = (state.preMatchRingHead % cap) + 1
  end
end

---Force-flush any buffered pendingLines to whichever file is the
---current emit target (game if open, else match). No-op if nothing's open.
function M.flush()
  if state.disabled then return end
  local target = currentTarget()
  if not target then return end
  if #state.pendingLines == 0 then return end
  local fs = state.fs
  if not fs then return end
  local blob = table.concat(state.pendingLines, "\n") .. "\n"
  state.pendingLines = {}
  state.lastFlush    = state.clock()
  local ok, err = pcall(fs.append, target, blob)
  if not ok then
    logger.warn("[TraceWriter] append failed for " .. tostring(target)
                .. ": " .. tostring(err))
    state.disabled = true
  end
end

encodeLine = function(entry)
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

---Local input event — the engine input char that was just fed to a
---local stack. Captures the per-frame input chars that are otherwise
---only visible in compressed/batched form on the wire (and not visible
---at all for single-player play).
---@param raw string single-char engine input
---@param frame integer? engine clock when the input landed
---@param stack integer? 1-based stack index this input feeds
function M.input(raw, frame, stack)
  if state.disabled then return end
  pcall(function()
    local line = encodeLine({
      ts    = state.clock(),
      dir   = "input",
      raw   = raw,
      frame = frame,
      stack = stack,
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

function M.isWriting()    return (state.gameOpen or state.matchOpen) and not state.disabled end
function M.isDisabled()   return state.disabled end
function M.currentPath()  return state.gameOpen and state.gamePath or state.matchPath end
function M.gamePath()     return state.gamePath end
function M.matchPath()    return state.matchPath end
function M.gameOpen()     return state.gameOpen end
function M.matchOpen()    return state.matchOpen end
function M.pendingCount() return #state.pendingLines end
function M.preMatchCount() return #state.preMatchRing end

return M
