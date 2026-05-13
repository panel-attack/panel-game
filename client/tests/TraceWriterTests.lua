-- TraceWriterTests.lua — unit tests for client/src/network/TraceWriter.
--
-- Uses a stub `fs` that captures appends in-memory, so the suite runs
-- under run_tests.sh without writing to the real love save dir.

require("client.src.globals")
local logger      = require("common.lib.logger")
local json        = require("common.lib.dkjson")
local TraceWriter = require("client.src.network.TraceWriter")

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

-- In-memory love.filesystem stub. Captures appends + createDirectory
-- calls; supports a fail-mode for the disk-failure test.
local function makeFsStub(opts)
  opts = opts or {}
  return {
    _files       = {},
    _createdDirs = {},
    _failAppend  = opts.failAppend or false,
    append = function(self, path, blob)
      if self._failAppend then error("simulated disk failure") end
      self._files[path] = (self._files[path] or "") .. blob
    end,
    createDirectory = function(self, path)
      self._createdDirs[path] = true
    end,
  }
end

-- Allow the .append / .createDirectory called as functions (not methods)
-- per TraceWriter's call style: love.filesystem.append(path, ...) is
-- equivalent to love.filesystem.append(love.filesystem, path, ...) in
-- Lua only via method-call syntax with `:`. TraceWriter uses dot-call,
-- so the stub's methods take (path, blob) not (self, path, blob). Wrap:
local function makeFs(opts)
  opts = opts or {}
  local store = { files = {}, dirs = {}, failAppend = opts.failAppend or false }
  return {
    _store = store,
    append = function(path, blob)
      if store.failAppend then error("simulated disk failure") end
      store.files[path] = (store.files[path] or "") .. blob
    end,
    createDirectory = function(path)
      store.dirs[path] = true
    end,
  }
end

local function clockMaker(start)
  local t = start or 1000
  return function() return t end, function(dt) t = t + (dt or 1) end
end

----------------------------------------------------------------------
-- Tests
----------------------------------------------------------------------

local function test_disabled_until_beginGame()
  logger.info("test_disabled_until_beginGame")
  local fs = makeFs()
  TraceWriter.configure({ fs = fs })
  -- No session/match/game yet. recv() should be a silent no-op as far
  -- as files go — but it does land in the pre-game ring.
  TraceWriter.recv("J", { type = "lobbyStateV2" })
  assert(TraceWriter.preGameCount() == 1, "pre-game ring should hold one event")
  assert(not TraceWriter.isWriting(), "no file open yet")
  assert(next(fs._store.files) == nil, "no files written yet")
end

local function test_beginGame_drains_pregame_ring()
  logger.info("test_beginGame_drains_pregame_ring")
  local clock, _bump = clockMaker(1000)
  local fs = makeFs()
  TraceWriter.configure({ fs = fs, clock = clock })
  TraceWriter.beginSession(1000)
  TraceWriter.beginMatch(7, 1001)
  -- Pre-game events that should land in the file when game starts.
  TraceWriter.recv("J", { type = "lobbyStateV2" })
  TraceWriter.recv("J", { type = "matchStart", content = { seed = 42 } })

  TraceWriter.beginGame(1002)

  local path = "trace_archive/session_1000/match_7_1001/game_1002.jsonl"
  assert(TraceWriter.currentPath() == path,
    "currentPath = " .. tostring(TraceWriter.currentPath()) .. " expected " .. path)
  local blob = fs._store.files[path]
  assert(blob, "expected pre-game flush to write " .. path)
  -- Both lines drained. Pre-game ring is now empty.
  assert(blob:find('"lobbyStateV2"'),  "lobbyState line should be in file")
  assert(blob:find('"matchStart"'),    "matchStart line should be in file")
  assert(TraceWriter.preGameCount() == 0, "ring should be drained")
end

local function test_taps_write_after_beginGame()
  logger.info("test_taps_write_after_beginGame")
  local clock, _bump = clockMaker(2000)
  local fs = makeFs()
  TraceWriter.configure({ fs = fs, clock = clock, flushEvents = 1 })
  TraceWriter.beginSession(2000)
  TraceWriter.beginMatch(1, 2000)
  TraceWriter.beginGame(2001)

  TraceWriter.send("I", "AAAA")
  TraceWriter.recv("G", { sender = 1, recipients = { 2 }, garbage = {} })
  TraceWriter.input("A", 60)
  TraceWriter.localEvent("sceneTransition", { from = "Lobby", to = "Game" })

  local path = TraceWriter.currentPath()
  local blob = fs._store.files[path]
  assert(blob)

  -- Count newlines to confirm 4 lines were appended.
  local lines = 0
  for _ in blob:gmatch("[^\n]+") do lines = lines + 1 end
  assert(lines == 4, "expected 4 lines in trace, got " .. lines)

  -- Each line is valid JSON with the expected `dir`.
  local seenDirs = {}
  for line in blob:gmatch("[^\n]+") do
    local entry = json.decode(line)
    assert(entry, "line should decode as JSON: " .. line)
    seenDirs[entry.dir] = true
  end
  assert(seenDirs["send"]  and seenDirs["recv"]
     and seenDirs["input"] and seenDirs["local"],
    "all four tap kinds should be present in the trace")
end

local function test_flush_threshold_eventcount()
  logger.info("test_flush_threshold_eventcount")
  local fs = makeFs()
  TraceWriter.configure({ fs = fs, flushEvents = 3, flushSeconds = 999 })
  TraceWriter.beginSession(1); TraceWriter.beginMatch(1, 1); TraceWriter.beginGame(1)

  TraceWriter.send("I", "A")
  TraceWriter.send("I", "B")
  -- Two events, below threshold (3) — still buffered.
  assert(TraceWriter.pendingCount() == 2,
    "expected 2 buffered, got " .. TraceWriter.pendingCount())

  TraceWriter.send("I", "C")
  -- Threshold hit ⇒ buffer drained.
  assert(TraceWriter.pendingCount() == 0,
    "buffer should drain at flushEvents=" .. 3)
end

local function test_flush_threshold_time()
  logger.info("test_flush_threshold_time")
  local clock, bump = clockMaker(0)
  local fs = makeFs()
  TraceWriter.configure({ fs = fs, flushEvents = 999, flushSeconds = 1, clock = clock })
  TraceWriter.beginSession(0); TraceWriter.beginMatch(1, 0); TraceWriter.beginGame(0)

  TraceWriter.send("I", "A")
  assert(TraceWriter.pendingCount() == 1)

  bump(2) -- advance 2 seconds (past threshold)
  TraceWriter.send("I", "B")
  -- second send triggers the time check on emit, flush fires
  assert(TraceWriter.pendingCount() == 0,
    "buffer should drain after time threshold; pending=" .. TraceWriter.pendingCount())
end

local function test_endGame_force_flushes()
  logger.info("test_endGame_force_flushes")
  local fs = makeFs()
  TraceWriter.configure({ fs = fs, flushEvents = 999, flushSeconds = 999 })
  TraceWriter.beginSession(1); TraceWriter.beginMatch(1, 1); TraceWriter.beginGame(1)

  TraceWriter.send("I", "X")
  TraceWriter.send("I", "Y")
  assert(TraceWriter.pendingCount() == 2)

  TraceWriter.endGame()
  assert(not TraceWriter.isWriting(), "endGame closes the file")
  -- Buffered lines should be on disk now.
  local writtenSomething = false
  for _ in pairs(fs._store.files) do writtenSomething = true; break end
  assert(writtenSomething, "endGame should have flushed the buffer to disk")
end

local function test_disk_failure_disables_writer()
  logger.info("test_disk_failure_disables_writer")
  local fs = makeFs({ failAppend = true })
  -- Silence the warn we expect when the disk fails.
  local origWarn = logger.warn
  logger.warn = function() end

  TraceWriter.configure({ fs = fs, flushEvents = 1 })
  TraceWriter.beginSession(1); TraceWriter.beginMatch(1, 1); TraceWriter.beginGame(1)
  -- The beginGame call appended the pre-game ring (empty in this test) —
  -- so the failure doesn't fire there. Send triggers a fail.
  TraceWriter.send("I", "A")

  logger.warn = origWarn
  assert(TraceWriter.isDisabled(),
    "first disk error should self-disable the writer")
  -- Subsequent taps must not throw.
  TraceWriter.send("I", "B")
  TraceWriter.recv("J", { type = "fine" })
end

local function test_pregame_ring_caps_at_limit()
  logger.info("test_pregame_ring_caps_at_limit")
  local fs = makeFs()
  TraceWriter.configure({ fs = fs })
  -- Ring cap is 100. Send 150 events without beginGame — ring should
  -- hold at most 100, oldest evicted.
  for i = 1, 150 do
    TraceWriter.send("I", tostring(i))
  end
  assert(TraceWriter.preGameCount() == 100,
    "ring should cap at 100, got " .. TraceWriter.preGameCount())
end

----------------------------------------------------------------------
-- Run
----------------------------------------------------------------------

test_disabled_until_beginGame()
test_beginGame_drains_pregame_ring()
test_taps_write_after_beginGame()
test_flush_threshold_eventcount()
test_flush_threshold_time()
test_endGame_force_flushes()
test_disk_failure_disables_writer()
test_pregame_ring_caps_at_limit()

logger.info("All TraceWriterTests passed!")
