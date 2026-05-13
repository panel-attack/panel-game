-- CrashReports.lua — server-side incident registry.
--
-- Implements the trigger + registry side of docs/CRASH_REPLAY_PLAN.md.
-- Disk writes and the wire shape (crashSlice / flagGame messages) live
-- elsewhere; this module is the in-memory truth for "what incidents are
-- collecting right now."
--
-- Failure model: collection is auxiliary. Every public entry point is
-- wrapped in pcall so a bug in this module CAN'T propagate into game
-- code. On internal error the module logs a warning, records the failure
-- toward a self-disable threshold, and returns false. Game state is
-- NEVER mutated from here — the only reads we do on Room/Game are for
-- assembling identifiers and (eventually) snapshotting the replay.
--
-- The module is purely additive — a Server that never calls flagGame
-- behaves identically to one without this module loaded.

local class  = require("common.lib.class")
local logger = require("common.lib.logger")
local FileIO = require("server.FileIO")

local DEFAULT_BUCKET_CAP     = 100
local FAILURE_THRESHOLD      = 5
local FAILURE_WINDOW_SECONDS = 60
local DEFAULT_ROOT_DIR       = "crash_reports"
local SCHEMA_VER             = 1

---@class CrashReports
---@field bucketCap integer
---@field clock fun(): number wall-clock source in seconds
---@field incidents table<string, table> incidentId → registry entry
---@field disabled boolean true after FAILURE_THRESHOLD failures within window
---@field recentFailures number[] timestamps of recent flagGame errors
local CrashReports = class(function(self, opts)
  opts = opts or {}
  self.bucketCap = opts.bucketCap or DEFAULT_BUCKET_CAP
  self.clock     = opts.clock or os.time
  -- Test isolation: every test creates its own subdir so runs don't
  -- contaminate each other. Default points at the production location
  -- next to logs/ — gitignored.
  self.rootDir   = opts.rootDir or DEFAULT_ROOT_DIR

  self.incidents      = {}
  self.disabled       = false
  self.recentFailures = {}
end)

-- ---------------------------------------------------------------------
-- Helpers (local to this file)
-- ---------------------------------------------------------------------

-- gameKey is the cross-machine identifier in the plan. roomNumber alone
-- isn't enough (rooms get recycled); roomNumber + gameId + a start
-- timestamp uniquely identifies one match across the whole server lifetime.
local function gameKeyFromRoom(room)
  local gameId = room.game and room.game.id or 0
  return {
    roomNumber = room.roomNumber or 0,
    gameId     = gameId,
    startTs    = room.game and room.game.creationTime or 0,
  }
end

local function gameKeyMatches(a, b)
  return a and b
     and a.roomNumber == b.roomNumber
     and a.gameId     == b.gameId
     and a.startTs    == b.startTs
end

-- Snapshot the participant + spectator roster at flag time. Server already
-- knows publicPlayerID per slot; freeze it so a player leaving the room
-- after the flag doesn't shrink expectedReporters.
local function snapshotExpectedReporters(room)
  local out = {}
  for _, player in pairs(room.players or {}) do
    if player and player.publicPlayerID then
      out[#out + 1] = player.publicPlayerID
    end
  end
  for _, spec in pairs(room.spectators or {}) do
    if spec and spec.publicPlayerID then
      out[#out + 1] = spec.publicPlayerID
    end
  end
  return out
end

local function countIncidents(self)
  local n = 0
  for _ in pairs(self.incidents) do n = n + 1 end
  return n
end

-- Self-disable bookkeeping. Called on every internal failure to decide
-- whether the module should stop accepting new work.
local function recordFailure(self)
  local now = self.clock()
  local kept = {}
  for _, ts in ipairs(self.recentFailures) do
    if (now - ts) < FAILURE_WINDOW_SECONDS then
      kept[#kept + 1] = ts
    end
  end
  kept[#kept + 1] = now
  self.recentFailures = kept

  if #kept >= FAILURE_THRESHOLD and not self.disabled then
    self.disabled = true
    logger.warn(string.format(
      "[CrashReports] disabled after %d failures within %ds — collection"
      .. " will stay off for the rest of this process",
      #kept, FAILURE_WINDOW_SECONDS))
  end
end

-- ---------------------------------------------------------------------
-- Disk writers. Both are pcall-internal so a write failure is logged
-- but never propagates — the in-memory registry stays the source of
-- truth and a later gather_logs run misses this one incident's files
-- rather than crashing the server.
-- ---------------------------------------------------------------------

local function writeRegistryEntry(self, entry)
  local ok, err = pcall(function()
    local dir = self.rootDir .. "/pending_incidents"
    FileIO.makeDirectoryRecursive(dir)
    local path = dir .. "/" .. entry.incidentId .. ".json"
    FileIO.writeAsJson(entry, path)
  end)
  if not ok then
    logger.warn("[CrashReports] failed to write registry entry "
      .. entry.incidentId .. ": " .. tostring(err))
  end
end

local function writeServerSlice(self, room, incidentId)
  -- Two failure modes to soft-handle:
  --   (1) getPartialReplay errors. Some game shapes (pre-match,
  --       puzzle, etc.) may not have a usable replay; log + skip.
  --   (2) Disk write errors. Same pattern as registry above.
  local replayOk, replay = pcall(function()
    if room.game and room.game.getPartialReplay then
      return room.game:getPartialReplay(true)
    end
    return nil
  end)

  if not replayOk then
    logger.warn("[CrashReports] getPartialReplay errored for "
      .. incidentId .. ": " .. tostring(replay))
    return
  end
  if replay == nil then
    logger.warn("[CrashReports] no replay available for incident "
      .. incidentId .. " — skipping server.json snapshot")
    return
  end

  local slice = {
    incidentId  = incidentId,
    publicId    = "server",
    schemaVer   = SCHEMA_VER,
    gameContext = {
      roomNumber   = room.roomNumber,
      gameId       = room.game and room.game.id,
      gameModeName = room.gameMode and room.gameMode.name,
    },
    replay      = replay,
    capturedAt  = self.clock(),
  }

  local writeOk, err = pcall(function()
    local dir = self.rootDir .. "/" .. incidentId
    FileIO.makeDirectoryRecursive(dir)
    local path = dir .. "/server.json"
    FileIO.writeAsJson(slice, path)
  end)
  if not writeOk then
    logger.warn("[CrashReports] failed to write server.json for "
      .. incidentId .. ": " .. tostring(err))
  end
end

-- ---------------------------------------------------------------------
-- The core flag implementation (can throw — caller wraps in pcall)
-- ---------------------------------------------------------------------

local function flagGameImpl(self, room, reason, traceHash)
  if self.disabled then
    return false, "disabled"
  end
  if type(room) ~= "table" or not room.game then
    return false, "no_game"
  end
  if countIncidents(self) >= self.bucketCap then
    return false, "bucket_full"
  end

  local gameKey = gameKeyFromRoom(room)

  -- Dedup. If we've already flagged this game with the same traceHash
  -- (or no traceHash at all), return the existing incidentId — flagGame
  -- is idempotent so a crash-looping client doesn't multiply incidents.
  local dedupHash = traceHash or ""
  for existingId, entry in pairs(self.incidents) do
    if gameKeyMatches(entry.gameKey, gameKey) and entry.traceHash == dedupHash then
      return true, existingId
    end
  end

  local incidentId = string.format("%d_%d_%04x",
    self.clock(), gameKey.roomNumber, math.random(0, 0xffff))

  local entry = {
    incidentId         = incidentId,
    gameKey            = gameKey,
    reason             = reason,
    traceHash          = dedupHash,
    expectedReporters  = snapshotExpectedReporters(room),
    collectedReporters = {},
    status             = "collecting",
    createdAt          = self.clock(),
  }
  self.incidents[incidentId] = entry

  -- Eager forensic writes. Failures here are logged but never bubble: the
  -- in-memory registry stays authoritative, and a missing slice file just
  -- means the next gather_logs run sees an incomplete incident.
  writeRegistryEntry(self, entry)
  writeServerSlice(self, room, incidentId)

  return true, incidentId
end

-- ---------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------

---Flag a game as an interesting incident. Idempotent; safe to call
---repeatedly. Never throws. Returns (true, incidentId) on success or
---(false, reason) on rejection.
---@param room table the Room whose game just went weird
---@param reason string e.g. "server_disconnect" or "client_crash"
---@param traceHash string? optional dedup key for client-nominated flags
---@return boolean, string accepted, incidentId|rejectionReason
function CrashReports:flagGame(room, reason, traceHash)
  local ok, a, b = pcall(flagGameImpl, self, room, reason, traceHash)
  if not ok then
    logger.warn("[CrashReports] flagGame errored: " .. tostring(a))
    recordFailure(self)
    return false, "internal_error"
  end
  return a, b
end

---Look up an incident by id. Returns nil if not found. Read-only.
---@param incidentId string
---@return table?
function CrashReports:getIncident(incidentId)
  return self.incidents[incidentId]
end

---Count of currently-tracked incidents. For tests + observability.
---@return integer
function CrashReports:incidentCount()
  return countIncidents(self)
end

return CrashReports
