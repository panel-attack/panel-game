-- CrashReportsTests.lua — unit tests for server/CrashReports.lua.
--
-- The module is purely additive infrastructure (see plan), so the test
-- bar is high: every public method must be no-throw, and a failure
-- inside the module must NEVER let game state get mutated. Tests exercise
-- the happy path, the rejection paths, and the self-disable threshold.

---@diagnostic disable: undefined-field, invisible
local CrashReports = require("server.CrashReports")
local FileIO       = require("server.FileIO")
local logger       = require("common.lib.logger")
local json         = require("common.lib.dkjson")
local lfs          = require("lfs")

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

-- Unique per-test directory so disk writes from one test never leak
-- into another. Lives under crash_reports_test/ (gitignored).
local _testDirCounter = 0
local function freshTestDir()
  _testDirCounter = _testDirCounter + 1
  return "crash_reports_test/run_" .. os.time() .. "_" .. _testDirCounter
end

-- Minimal Room-shaped table for the tests. CrashReports only reads —
-- it never writes to anything passed in here, so a plain table is enough.
-- Default ships a tiny ReplayV3-shaped stub so the disk-write path
-- succeeds silently. Tests that specifically want "no replay" pass
-- opts.withReplay = false to defeat the default.
local function defaultStubReplay()
  return {
    engineVersion  = "049",
    replayVersion  = 4,
    panelSource    = { sourceType = 3, seed = 1234 },
    rules          = {},
    stacks         = {},
    garbageFlows   = {},
    crossPlayerEvents = { garbage = {}, deaths = {} },
    metadata       = { stacks = {}, timestamp = 1000 },
  }
end

local function makeRoom(opts)
  opts = opts or {}
  local roomNumber = opts.roomNumber or 1
  local gameId     = opts.gameId or 100
  local startTs    = opts.startTs or 1000
  local replay
  if opts.withReplay == false then
    replay = nil
  else
    replay = opts.withReplay or defaultStubReplay()
  end
  return {
    roomNumber = roomNumber,
    gameMode = { name = "VS" },
    game = {
      id           = gameId,
      creationTime = startTs,
      getPartialReplay = function(_, _compressInputs) return replay end,
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
    rootDir   = opts.rootDir   or freshTestDir(),
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
-- Disk-write tests
----------------------------------------------------------------------

-- Compact ReplayV3-shaped stub. The disk-writer doesn't validate the
-- replay's contents, just JSON-encodes whatever getPartialReplay
-- returns. Realistic enough that a downstream loadFixture would find
-- the load-bearing fields (seed, inputs, crossPlayerEvents).
local function stubReplay()
  return {
    engineVersion  = "049",
    replayVersion  = 4,
    panelSource    = { sourceType = 3, seed = 1234 },
    rules          = { matchEndConditions = { TEAMS_ACTIVE = 1 } },
    stacks         = { { stackType = 1, inputs = "AAAA" } },
    garbageFlows   = {},
    crossPlayerEvents = { garbage = {}, deaths = {} },
    metadata       = { stacks = {}, timestamp = 1000, gameModeName = "VS" },
  }
end

local function test_flagGame_writes_registry_entry()
  logger.info("test_flagGame_writes_registry_entry")
  local cr = newCR()
  local _, id = cr:flagGame(makeRoom(), "server_disconnect")
  local path = cr.rootDir .. "/pending_incidents/" .. id .. ".json"
  assert(FileIO.fileExists(path), "registry entry should be written at " .. path)

  local decoded = FileIO.readJson(path)
  assert(decoded.incidentId == id)
  assert(decoded.reason == "server_disconnect")
  assert(decoded.status == "collecting")
  assert(type(decoded.expectedReporters) == "table")
end

local function test_flagGame_writes_server_slice_when_replay_present()
  logger.info("test_flagGame_writes_server_slice_when_replay_present")
  local cr = newCR()
  local room = makeRoom({ withReplay = stubReplay() })
  local _, id = cr:flagGame(room, "server_disconnect")

  local path = cr.rootDir .. "/" .. id .. "/server.json"
  assert(FileIO.fileExists(path), "server slice should be written at " .. path)

  local decoded = FileIO.readJson(path)
  assert(decoded.incidentId == id)
  assert(decoded.publicId == "server")
  assert(decoded.replay,                       "slice should carry the replay")
  assert(decoded.replay.panelSource.seed == 1234, "replay seed preserved through JSON")
  assert(decoded.gameContext.roomNumber == room.roomNumber)
  assert(decoded.gameContext.gameModeName == "VS")
end

local function test_flagGame_skips_server_slice_when_no_replay()
  logger.info("test_flagGame_skips_server_slice_when_no_replay")
  local cr = newCR()
  -- withReplay=false defeats makeRoom's default stub so getPartialReplay
  -- returns nil. Silence the warn it triggers; we're testing skip
  -- behavior, not the log message.
  local origWarn = logger.warn
  logger.warn = function() end
  local _, id = cr:flagGame(makeRoom({ withReplay = false }), "test")
  logger.warn = origWarn

  -- Registry entry still written; server.json should NOT be there.
  local regPath   = cr.rootDir .. "/pending_incidents/" .. id .. ".json"
  local slicePath = cr.rootDir .. "/" .. id .. "/server.json"
  assert(FileIO.fileExists(regPath),
    "registry should be written even without replay")
  assert(not FileIO.fileExists(slicePath),
    "no replay ⇒ no slice file (server gracefully skips)")
end

local function test_flagGame_disk_failure_does_not_throw()
  logger.info("test_flagGame_disk_failure_does_not_throw")
  -- Point rootDir at an invalid path so directory creation / write
  -- fails. Module should soft-fail: incident stays in the in-memory
  -- registry, no exception propagates.
  local cr = CrashReports({
    rootDir = "/dev/null/cannot_mkdir_here",
    clock   = function() return 1000 end,
  })

  -- Silence BOTH levels: FileIO logs the actual mkdir/write failure as
  -- ERROR, and CrashReports logs its own WARN summary. Both are expected
  -- here; we're verifying the no-throw contract, not the log messages.
  local origWarn, origError = logger.warn, logger.error
  logger.warn, logger.error = function() end, function() end
  local ok, id = cr:flagGame(makeRoom({ withReplay = stubReplay() }), "test")
  logger.warn, logger.error = origWarn, origError

  assert(ok, "flagGame must return ok=true even on disk failure")
  assert(type(id) == "string", "incidentId should still be minted")
  assert(cr:incidentCount() == 1,
    "in-memory registry stays authoritative on disk failure")
end

----------------------------------------------------------------------
-- recordSlice tests
----------------------------------------------------------------------

local function test_recordSlice_writes_file_and_updates_registry()
  logger.info("test_recordSlice_writes_file_and_updates_registry")
  local cr = newCR()
  -- Two expected reporters; we'll record one of them.
  local room = makeRoom({
    players = { [1] = { publicPlayerID = 100 }, [2] = { publicPlayerID = 200 } },
  })
  local _, id = cr:flagGame(room, "server_disconnect")

  local slice = { incidentId = id, publicId = 100, replay = stubReplay() }
  local ok, status = cr:recordSlice(id, 100, slice)
  assert(ok, "expected ok, got " .. tostring(ok) .. " status=" .. tostring(status))
  assert(status == "recorded")

  local path = cr.rootDir .. "/" .. id .. "/100.json"
  assert(FileIO.fileExists(path), "slice file should exist at " .. path)

  local entry = cr:getIncident(id)
  assert(#entry.collectedReporters == 1)
  assert(entry.collectedReporters[1] == 100)
  assert(entry.status == "collecting",
    "single slice of two-expected should still be collecting")
end

local function test_recordSlice_transitions_to_complete()
  logger.info("test_recordSlice_transitions_to_complete")
  local cr = newCR()
  local room = makeRoom({
    players = { [1] = { publicPlayerID = 100 }, [2] = { publicPlayerID = 200 } },
  })
  local _, id = cr:flagGame(room, "server_disconnect")

  cr:recordSlice(id, 100, { replay = stubReplay() })
  local ok = cr:recordSlice(id, 200, { replay = stubReplay() })
  assert(ok)

  local entry = cr:getIncident(id)
  assert(entry.status == "complete",
    "after all expected reporters: status=complete, got " .. tostring(entry.status))

  -- File moved from pending → complete dirs.
  local pendingPath  = cr.rootDir .. "/pending_incidents/" .. id .. ".json"
  local completePath = cr.rootDir .. "/complete_incidents/" .. id .. ".json"
  assert(not FileIO.fileExists(pendingPath))
  assert(FileIO.fileExists(completePath))
end

local function test_recordSlice_idempotent()
  logger.info("test_recordSlice_idempotent")
  local cr = newCR()
  local _, id = cr:flagGame(
    makeRoom({ players = { [1] = { publicPlayerID = 100 } } }),
    "test")

  local ok1 = cr:recordSlice(id, 100, { replay = stubReplay() })
  local ok2, status = cr:recordSlice(id, 100, { replay = stubReplay() })
  assert(ok1 and ok2)
  assert(status == "already_collected",
    "second call must report already_collected, got " .. tostring(status))
  -- Single reporter ⇒ first call completed it. collectedReporters list size 1.
  local entry = cr:getIncident(id)
  assert(#entry.collectedReporters == 1)
end

local function test_recordSlice_rejects_unknown_incident()
  logger.info("test_recordSlice_rejects_unknown_incident")
  local cr = newCR()
  local ok, reason = cr:recordSlice("nope_not_real", 100, { replay = stubReplay() })
  assert(not ok and reason == "unknown_incident")
end

local function test_recordSlice_rejects_unexpected_reporter()
  logger.info("test_recordSlice_rejects_unexpected_reporter")
  local cr = newCR()
  local _, id = cr:flagGame(
    makeRoom({ players = { [1] = { publicPlayerID = 100 } } }),
    "test")
  -- publicId 999 was never in the room.
  local ok, reason = cr:recordSlice(id, 999, { replay = stubReplay() })
  assert(not ok and reason == "not_expected")
end

local function test_recordSlice_rejects_oversized_payload()
  logger.info("test_recordSlice_rejects_oversized_payload")
  local cr = newCR()
  local _, id = cr:flagGame(
    makeRoom({ players = { [1] = { publicPlayerID = 100 } } }),
    "test")
  -- 3 MB of inline string content blows past the 2 MB cap.
  local huge = { replay = stubReplay(), pad = string.rep("x", 3 * 1024 * 1024) }
  local origWarn = logger.warn
  logger.warn = function() end
  local ok, reason = cr:recordSlice(id, 100, huge)
  logger.warn = origWarn
  assert(not ok and reason == "too_large")
end

----------------------------------------------------------------------
-- Sweeper tests
----------------------------------------------------------------------

local function test_sweep_moves_aged_collecting_incident()
  logger.info("test_sweep_moves_aged_collecting_incident")
  local now = 1000000
  local cr  = newCR({ clock = function() return now end })
  local _, id = cr:flagGame(makeRoom(), "server_disconnect")

  -- Advance the wall clock by 8 days (sweeper threshold is 7).
  now = now + 8 * 24 * 60 * 60
  local moved = cr:sweep()

  assert(moved == 1, "expected 1 incident moved, got " .. moved)
  assert(cr:getIncident(id).status == "timed_out",
    "status should flip to timed_out, got " .. tostring(cr:getIncident(id).status))

  local pendingPath  = cr.rootDir .. "/pending_incidents/" .. id .. ".json"
  local completePath = cr.rootDir .. "/complete_incidents/" .. id .. ".json"
  assert(not FileIO.fileExists(pendingPath),
    "pending file should be gone after sweep")
  assert(FileIO.fileExists(completePath),
    "complete file should exist at " .. completePath)
end

local function test_sweep_leaves_fresh_incidents_alone()
  logger.info("test_sweep_leaves_fresh_incidents_alone")
  local now = 1000000
  local cr  = newCR({ clock = function() return now end })
  local _, id = cr:flagGame(makeRoom(), "server_disconnect")

  -- Only 1 day old — well below the 7-day threshold.
  now = now + 1 * 24 * 60 * 60
  local moved = cr:sweep()

  assert(moved == 0, "expected 0 incidents moved, got " .. moved)
  assert(cr:getIncident(id).status == "collecting",
    "fresh incident should stay collecting, got " .. tostring(cr:getIncident(id).status))
  local pendingPath  = cr.rootDir .. "/pending_incidents/" .. id .. ".json"
  local completePath = cr.rootDir .. "/complete_incidents/" .. id .. ".json"
  assert(FileIO.fileExists(pendingPath))
  assert(not FileIO.fileExists(completePath))
end

local function test_sweep_idempotent()
  logger.info("test_sweep_idempotent")
  local now = 1000000
  local cr  = newCR({ clock = function() return now end })
  cr:flagGame(makeRoom(), "test")
  now = now + 8 * 24 * 60 * 60

  local first  = cr:sweep()
  local second = cr:sweep()
  assert(first == 1)
  assert(second == 0, "second sweep should not re-move; already timed_out")
end

local function test_sweep_no_throw_when_disabled()
  logger.info("test_sweep_no_throw_when_disabled")
  local cr = newCR()
  cr.disabled = true
  local moved = cr:sweep()
  assert(moved == 0)
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
test_flagGame_writes_registry_entry()
test_flagGame_writes_server_slice_when_replay_present()
test_flagGame_skips_server_slice_when_no_replay()
test_flagGame_disk_failure_does_not_throw()
test_sweep_moves_aged_collecting_incident()
test_sweep_leaves_fresh_incidents_alone()
test_sweep_idempotent()
test_sweep_no_throw_when_disabled()
test_recordSlice_writes_file_and_updates_registry()
test_recordSlice_transitions_to_complete()
test_recordSlice_idempotent()
test_recordSlice_rejects_unknown_incident()
test_recordSlice_rejects_unexpected_reporter()
test_recordSlice_rejects_oversized_payload()

logger.info("All CrashReportsTests passed!")
