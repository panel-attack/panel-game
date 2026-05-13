-- Server-side trace writer — mirrors client/src/network/TraceWriter.lua
-- onto the server. Per-publicId state, one JSONL file per session
-- (player's login lifetime). Match/game subdivision deferred to a
-- follow-up; v1 is flat-per-session which is enough for the diff util
-- to cross-check "did the server see what the client says it sent."
--
-- File layout: <rootDir>/<publicId>/session_<loginTs>.jsonl
--
-- Failure model: same contract as client TraceWriter. Every public
-- entry is pcall'd internally so a tap regression cannot disturb the
-- server's hot path. Disk errors self-disable for that publicId only —
-- one player's bad disk state doesn't take down the others.

local logger = require("common.lib.logger")
local json   = require("common.lib.dkjson")
local lfs    = require("lfs")

local DEFAULT_ROOT          = "trace_archive"
local DEFAULT_FLUSH_EVENTS  = 64
local DEFAULT_FLUSH_SECONDS = 1.0

local M = {}

local state = {
  rootDir      = DEFAULT_ROOT,
  flushEvents  = DEFAULT_FLUSH_EVENTS,
  flushSeconds = DEFAULT_FLUSH_SECONDS,
  clock        = function() return os.time() end,
  -- [publicId] = {
  --   path           = "trace_archive/<id>/session_<ts>.jsonl"
  --   pending        = []
  --   lastFlush      = ts
  --   disabled       = bool (per-player kill switch)
  -- }
  byPublicId   = {},
  globallyDisabled = false,
}

----------------------------------------------------------------------
-- Configuration (test seam)
----------------------------------------------------------------------

---Replace internal state. For tests; production wiring leaves this alone.
---@param opts table? { rootDir, flushEvents, flushSeconds, clock }
function M.configure(opts)
  state = {
    rootDir          = (opts and opts.rootDir)      or DEFAULT_ROOT,
    flushEvents      = (opts and opts.flushEvents)  or DEFAULT_FLUSH_EVENTS,
    flushSeconds     = (opts and opts.flushSeconds) or DEFAULT_FLUSH_SECONDS,
    clock            = (opts and opts.clock)        or function() return os.time() end,
    byPublicId       = {},
    globallyDisabled = false,
  }
end

----------------------------------------------------------------------
-- Internal: per-player state mgmt
----------------------------------------------------------------------

local function makePlayerState()
  return {
    path      = nil,
    pending   = {},
    lastFlush = 0,
    disabled  = false,
  }
end

local function makeDirRecursive(path)
  -- lfs has no -p mkdir; walk components and try to create each.
  local sep, accum = "/", ""
  for chunk in path:gmatch("[^" .. sep .. "]+") do
    accum = accum .. chunk .. sep
    -- mkdir errors if the dir already exists. Swallow that case; surface
    -- any other failure on the actual write later.
    local ok, _err = lfs.mkdir(accum)
    if not ok then
      -- pcall'd, no need to propagate; let the write try and fail loudly.
    end
  end
end

local function ensureFile(publicId, loginTs)
  local p = state.byPublicId[publicId]
  if p and p.path then return p end

  p = makePlayerState()
  state.byPublicId[publicId] = p

  local dir = state.rootDir .. "/" .. tostring(publicId)
  local ok, err = pcall(makeDirRecursive, dir)
  if not ok then
    logger.warn("[ServerTrace] makedir failed for "
                .. tostring(publicId) .. ": " .. tostring(err))
    p.disabled = true
    return p
  end

  p.path = dir .. "/session_" .. tostring(loginTs or state.clock()) .. ".jsonl"
  p.lastFlush = state.clock()
  return p
end

----------------------------------------------------------------------
-- Internal: line emit + flush per-player
----------------------------------------------------------------------

local function encodeLine(entry)
  local ok, encoded = pcall(json.encode, entry)
  if not ok then
    logger.warn("[ServerTrace] encode failed: " .. tostring(encoded))
    return nil
  end
  return encoded
end

local function flushPlayer(publicId)
  local p = state.byPublicId[publicId]
  if not p or p.disabled or not p.path or #p.pending == 0 then return end
  local blob = table.concat(p.pending, "\n") .. "\n"
  p.pending = {}
  p.lastFlush = state.clock()
  local ok, err = pcall(function()
    local f = assert(io.open(p.path, "a"))
    f:write(blob)
    f:close()
  end)
  if not ok then
    logger.warn("[ServerTrace] append failed for " .. tostring(publicId)
                .. ": " .. tostring(err))
    p.disabled = true
  end
end

local function emit(publicId, entry)
  if state.globallyDisabled then return end
  if not publicId then return end
  local p = state.byPublicId[publicId]
  if not p or not p.path or p.disabled then return end
  local line = encodeLine(entry)
  if not line then return end
  p.pending[#p.pending + 1] = line
  local now = state.clock()
  if #p.pending >= state.flushEvents
      or (now - p.lastFlush) >= state.flushSeconds then
    flushPlayer(publicId)
  end
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

---Open this player's session file. Idempotent — calling twice is a no-op.
---@param publicId integer
---@param loginTs integer? wall-clock seconds at successful login
function M.beginSession(publicId, loginTs)
  pcall(function()
    ensureFile(publicId, loginTs)
  end)
end

---Close this player's session file. Force-flushes pending lines.
---@param publicId integer
function M.endSession(publicId)
  pcall(function()
    flushPlayer(publicId)
    state.byPublicId[publicId] = nil
  end)
end

---Inbound: server received `body` from `publicId` over the wire.
---@param publicId integer
---@param prefix string single-char wire prefix
---@param body any decoded message
function M.recv(publicId, prefix, body)
  pcall(function()
    emit(publicId, {
      ts     = state.clock(),
      dir    = "recv",
      prefix = prefix,
      body   = body,
    })
  end)
end

---Outbound: server sent `body` to `publicId`.
---@param publicId integer
---@param prefix string single-char wire prefix
---@param body any decoded message (table for J/G/D, string for I/E/H)
function M.send(publicId, prefix, body)
  pcall(function()
    emit(publicId, {
      ts     = state.clock(),
      dir    = "send",
      prefix = prefix,
      body   = body,
    })
  end)
end

---Lifecycle / forensic marker, scoped to one publicId.
---@param publicId integer
---@param kind string
---@param data table?
function M.localEvent(publicId, kind, data)
  pcall(function()
    emit(publicId, {
      ts   = state.clock(),
      dir  = "local",
      kind = kind,
      data = data,
    })
  end)
end

---Force-flush this player's pending lines.
---@param publicId integer
function M.flush(publicId)
  pcall(flushPlayer, publicId)
end

----------------------------------------------------------------------
-- Introspection (tests + observability)
----------------------------------------------------------------------

function M.isWriting(publicId)
  local p = state.byPublicId[publicId]
  return p ~= nil and p.path ~= nil and not p.disabled
end

function M.currentPath(publicId)
  local p = state.byPublicId[publicId]
  return p and p.path or nil
end

function M.pendingCount(publicId)
  local p = state.byPublicId[publicId]
  return p and #p.pending or 0
end

return M
