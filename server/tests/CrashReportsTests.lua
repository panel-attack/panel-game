-- CrashReportsTests.lua — unit tests for server/CrashReports.lua.
--
-- The module is purely additive infrastructure (see plan), so the test
-- bar is high: every public method must be no-throw, and a failure
-- inside the module must NEVER let game state get mutated. Tests exercise
-- the happy path, the rejection paths, and the self-disable threshold.

---@diagnostic disable: undefined-field, invisible
local CrashReports = require("server.CrashReports")
local logger       = require("common.lib.logger")

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

-- Minimal Room-shaped table for the tests. CrashReports only reads —
-- it never writes to anything passed in here, so a plain table is enough.
local function makeRoom(opts)
  opts = opts or {}
  local roomNumber = opts.roomNumber or 1
  local gameId     = opts.gameId or 100
  local startTs    = opts.startTs or 1000
  return {
    roomNumber = roomNumber,
    game = {
      id           = gameId,
      creationTime = startTs,
    },
    players    = opts.players    or { [1] = { publicPlayerID = 7001 } },
    spectators = opts.spectators or {},
  }
end

-- A "poisoned" room whose game.id read raises. Lets us force flagGame
-- to hit its pcall recovery path so we can test the self-disable threshold
-- without invasive monkey-patching.
local function poisonedRoom()
  local game = setmetatable({}, {
    __index = function(_, k)
      if k == "id" then error("poisoned game access for test") end
      return nil
    end,
  })
  return {
    roomNumber = 9,
    game       = game,
    players    = {},
    spectators = {},
  }
end

-- Test clock that returns a controlled value. The closure exposes a
-- bump() method so a single test can advance the clock multiple times.
local function makeFakeClock(start)
  local now = start or 1000
  return function() return now end, function(delta) now = now + (delta or 1) end
end

local function newCR(opts)
  opts = opts or {}
  -- Silence the logger.warn calls from the failure-path tests so they
  -- don't pollute the test-run output.
  local origWarn = logger.warn
  logger.warn = function() end
  local cr = CrashReports({
    bucketCap = opts.bucketCap or 100,
    clock     = opts.clock     or function() return 1000 end,
  })
  logger.warn = origWarn
  return cr
end

----------------------------------------------------------------------
-- Tests
----------------------------------------------------------------------

local function test_flagGame_happy_path()
  logger.info("test_flagGame_happy_path")
  local cr = newCR()
  local ok, id = cr:flagGame(makeRoom(), "server_disconnect")
  assert(ok, "flagGame should accept a valid room")
  assert(type(id) == "string" and #id > 0, "incidentId must be a non-empty string")
  assert(cr:incidentCount() == 1, "registry should have one incident")
  assert(cr:getIncident(id),     "getIncident should return the entry")
  assert(cr:getIncident(id).reason == "server_disconnect")
end

local function test_flagGame_no_game_rejected()
  logger.info("test_flagGame_no_game_rejected")
  local cr = newCR()
  local ok, reason = cr:flagGame({ roomNumber = 1, game = nil }, "test")
  assert(not ok and reason == "no_game",
    "expected rejection no_game, got ok=" .. tostring(ok) .. " reason=" .. tostring(reason))
  assert(cr:incidentCount() == 0, "rejected flag must not register")
end

local function test_flagGame_idempotent_with_traceHash()
  logger.info("test_flagGame_idempotent_with_traceHash")
  local cr = newCR()
  local ok1, id1 = cr:flagGame(makeRoom(), "client_crash", "abc123")
  local ok2, id2 = cr:flagGame(makeRoom(), "client_crash", "abc123")
  assert(ok1 and ok2)
  assert(id1 == id2, "same gameKey + traceHash must return same incidentId")
  assert(cr:incidentCount() == 1, "dedup means no second registry entry")
end

local function test_flagGame_idempotent_with_no_traceHash()
  logger.info("test_flagGame_idempotent_with_no_traceHash")
  local cr = newCR()
  -- No traceHash supplied. Same (gameKey, empty-hash) pair should dedup
  -- so server-side detectors firing twice for the same incident don't
  -- pile up multiple registry entries.
  local ok1, id1 = cr:flagGame(makeRoom(), "server_disconnect")
  local ok2, id2 = cr:flagGame(makeRoom(), "server_disconnect")
  assert(ok1 and ok2)
  assert(id1 == id2, "same gameKey + nil traceHash must dedup")
end

local function test_flagGame_distinct_traceHashes_create_distinct_incidents()
  logger.info("test_flagGame_distinct_traceHashes_create_distinct_incidents")
  local cr = newCR()
  local _, id1 = cr:flagGame(makeRoom(), "client_crash", "hash_a")
  local _, id2 = cr:flagGame(makeRoom(), "client_crash", "hash_b")
  assert(id1 ~= id2, "different traceHash should make distinct incidents")
  assert(cr:incidentCount() == 2)
end

local function test_bucketCap_rejects_at_limit()
  logger.info("test_bucketCap_rejects_at_limit")
  -- Use a tiny cap so the test is cheap.
  local cr = newCR({ bucketCap = 3 })
  for i = 1, 3 do
    local ok = cr:flagGame(makeRoom({ gameId = i }), "test")
    assert(ok, "first " .. i .. " flags should succeed")
  end
  local ok, reason = cr:flagGame(makeRoom({ gameId = 99 }), "test")
  assert(not ok and reason == "bucket_full",
    "expected bucket_full, got ok=" .. tostring(ok) .. " reason=" .. tostring(reason))
  assert(cr:incidentCount() == 3, "bucket cap must be hard")
end

local function test_expected_reporters_snapshotted()
  logger.info("test_expected_reporters_snapshotted")
  local cr = newCR()
  local room = makeRoom({
    players    = { [1] = { publicPlayerID = 100 }, [2] = { publicPlayerID = 200 } },
    spectators = { { publicPlayerID = 300 } },
  })
  local _, id = cr:flagGame(room, "server_disconnect")
  local entry = cr:getIncident(id)
  -- We should see all three publicIds. Order is unspecified (pairs).
  local seen = {}
  for _, pid in ipairs(entry.expectedReporters) do seen[pid] = true end
  assert(seen[100] and seen[200] and seen[300],
    "expectedReporters should cover players + spectators")
end

local function test_flagGame_no_throw_on_bad_input()
  logger.info("test_flagGame_no_throw_on_bad_input")
  local cr = newCR()
  -- Non-table room. Should NOT throw — public API is no-throw.
  local ok1 = cr:flagGame(nil, "test")
  local ok2 = cr:flagGame(42,  "test")
  local ok3 = cr:flagGame("a", "test")
  assert(not ok1 and not ok2 and not ok3)
end

local function test_self_disable_after_threshold()
  logger.info("test_self_disable_after_threshold")
  local clock, _bump = makeFakeClock(1000)
  local cr = newCR({ clock = clock })

  -- This test intentionally trips the internal-error path 5 times. Silence
  -- the resulting logger.warn calls so they don't pollute the test output
  -- (and look like real failures to anyone scanning the log).
  local origWarn = logger.warn
  logger.warn = function() end

  -- Five failures inside the 60s window. recordFailure trips at 5 ⇒
  -- module disables itself.
  for i = 1, 5 do
    local ok, reason = cr:flagGame(poisonedRoom(), "test")
    assert(not ok)
    assert(reason == "internal_error" or reason == "disabled",
      "expected internal_error/disabled, got " .. tostring(reason))
  end

  -- Subsequent valid call must now hit the disabled gate, not run impl.
  local ok, reason = cr:flagGame(makeRoom(), "test")
  assert(not ok and reason == "disabled",
    "expected disabled after threshold, got " .. tostring(reason))

  logger.warn = origWarn
end

local function test_disabled_stays_disabled_within_window()
  logger.info("test_disabled_stays_disabled_within_window")
  local cr = newCR()
  cr.disabled = true
  local ok, reason = cr:flagGame(makeRoom(), "test")
  assert(not ok and reason == "disabled")
end

local function test_game_state_not_mutated()
  logger.info("test_game_state_not_mutated")
  local cr = newCR()
  local room = makeRoom()
  -- Freeze a shallow snapshot of the fields the module touches. After
  -- flagGame, those exact references must still be present and equal.
  local gameSnap     = room.game
  local gameIdSnap   = room.game.id
  local gameTsSnap   = room.game.creationTime
  local playersSnap  = room.players
  local roomNumSnap  = room.roomNumber

  cr:flagGame(room, "test")

  assert(room.game            == gameSnap)
  assert(room.game.id         == gameIdSnap)
  assert(room.game.creationTime == gameTsSnap)
  assert(room.players         == playersSnap)
  assert(room.roomNumber      == roomNumSnap)
end

----------------------------------------------------------------------
-- Run
----------------------------------------------------------------------

test_flagGame_happy_path()
test_flagGame_no_game_rejected()
test_flagGame_idempotent_with_traceHash()
test_flagGame_idempotent_with_no_traceHash()
test_flagGame_distinct_traceHashes_create_distinct_incidents()
test_bucketCap_rejects_at_limit()
test_expected_reporters_snapshotted()
test_flagGame_no_throw_on_bad_input()
test_self_disable_after_threshold()
test_disabled_stays_disabled_within_window()
test_game_state_not_mutated()

logger.info("All CrashReportsTests passed!")
