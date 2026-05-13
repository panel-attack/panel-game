-- TraceWriterTests.lua — unit tests for server/TraceWriter.lua.
--
-- Bar: every public method must be no-throw, every failure must
-- self-disable without taking down callers. Tests cover the lifecycle
-- (beginSession → recv/send/localEvent → endSession), the per-publicId
-- isolation invariant, and the disabled-on-bad-state path.

---@diagnostic disable: undefined-field, invisible
local TraceWriter = require("server.TraceWriter")
local logger      = require("common.lib.logger")
local json        = require("common.lib.dkjson")
local lfs         = require("lfs")

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local _testDirCounter = 0
local function freshTestDir()
  _testDirCounter = _testDirCounter + 1
  return "trace_archive_test/run_" .. os.time() .. "_" .. _testDirCounter
end

local function readFile(path)
  local f, err = io.open(path, "r")
  if not f then return nil, err end
  local s = f:read("*a"); f:close()
  return s
end

local function readJsonLines(path)
  local body = readFile(path)
  if not body then return {} end
  local out = {}
  for line in body:gmatch("[^\n]+") do
    local ok, obj = pcall(json.decode, line)
    if ok then out[#out + 1] = obj end
  end
  return out
end

local function configureFresh(opts)
  opts = opts or {}
  TraceWriter.configure({
    rootDir      = opts.rootDir      or freshTestDir(),
    flushEvents  = opts.flushEvents  or 1,         -- write-through for tests
    flushSeconds = opts.flushSeconds or 0,
    clock        = opts.clock        or function() return 1000 end,
  })
end

----------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------

local function test_beginSession_opens_file_path()
  logger.info("test_beginSession_opens_file_path")
  configureFresh()
  TraceWriter.beginSession(7, 1234)
  assert(TraceWriter.isWriting(7), "session should be active for publicId 7")
  local path = TraceWriter.currentPath(7)
  assert(path and path:match("/7/session_1234%.jsonl$"),
    "expected per-publicId session path, got " .. tostring(path))
end

local function test_endSession_drops_state()
  logger.info("test_endSession_drops_state")
  configureFresh()
  TraceWriter.beginSession(7, 1234)
  TraceWriter.recv(7, "J", { messageType = "lobby" })
  TraceWriter.endSession(7)
  assert(not TraceWriter.isWriting(7), "endSession should drop player state")
end

local function test_recv_send_localEvent_round_trip_to_disk()
  logger.info("test_recv_send_localEvent_round_trip_to_disk")
  configureFresh()
  TraceWriter.beginSession(11, 1234)
  TraceWriter.recv(11, "J", { messageType = "login_successful" })
  TraceWriter.send(11, "J", { messageType = "lobby_changed" })
  TraceWriter.localEvent(11, "matchStart", { roomNumber = 9 })
  TraceWriter.flush(11)

  local path  = TraceWriter.currentPath(11)
  local lines = readJsonLines(path)
  assert(#lines == 3, "expected 3 lines on disk, got " .. tostring(#lines))
  assert(lines[1].dir == "recv" and lines[1].prefix == "J")
  assert(lines[2].dir == "send" and lines[2].prefix == "J")
  assert(lines[3].dir == "local" and lines[3].kind == "matchStart")
end

local function test_per_publicId_isolation()
  logger.info("test_per_publicId_isolation")
  configureFresh()
  TraceWriter.beginSession(1, 1000)
  TraceWriter.beginSession(2, 2000)
  TraceWriter.recv(1, "J", { only = "for one" })
  TraceWriter.recv(2, "J", { only = "for two" })
  TraceWriter.flush(1); TraceWriter.flush(2)

  local l1 = readJsonLines(TraceWriter.currentPath(1))
  local l2 = readJsonLines(TraceWriter.currentPath(2))
  assert(#l1 == 1 and l1[1].body.only == "for one")
  assert(#l2 == 1 and l2[1].body.only == "for two")
end

local function test_recv_with_no_active_session_is_noop()
  logger.info("test_recv_with_no_active_session_is_noop")
  configureFresh()
  -- No beginSession for publicId 99 — should silently drop, NOT throw.
  TraceWriter.recv(99, "J", { messageType = "login" })
  TraceWriter.send(99, "J", { messageType = "login_successful" })
  TraceWriter.localEvent(99, "boom", { x = 1 })
  assert(not TraceWriter.isWriting(99))
end

local function test_nil_publicId_is_noop()
  logger.info("test_nil_publicId_is_noop")
  configureFresh()
  -- Pre-login messages arrive before a publicId is assigned. The taps
  -- in server.lua route through nil in that window; must not throw.
  TraceWriter.recv(nil, "J", { messageType = "login" })
  TraceWriter.send(nil, "J", { messageType = "login_failure" })
  TraceWriter.localEvent(nil, "preLoginThing", {})
end

local function test_beginSession_idempotent()
  logger.info("test_beginSession_idempotent")
  configureFresh()
  TraceWriter.beginSession(5, 1234)
  local pathFirst = TraceWriter.currentPath(5)
  TraceWriter.beginSession(5, 9999) -- second call should NOT clobber
  local pathSecond = TraceWriter.currentPath(5)
  assert(pathFirst == pathSecond,
    "beginSession should be idempotent; got " ..
    tostring(pathFirst) .. " then " .. tostring(pathSecond))
end

----------------------------------------------------------------------
-- Failure isolation — a regression in TraceWriter must never disturb
-- the caller. We deliberately feed it garbage and verify it returns.
----------------------------------------------------------------------

local function test_no_throw_on_unencodable_body()
  logger.info("test_no_throw_on_unencodable_body")
  configureFresh()
  TraceWriter.beginSession(3, 1000)
  -- A cyclic table is not JSON-encodable. The tap must swallow the
  -- encode failure and keep going on subsequent calls.
  local cycle = {}; cycle.self = cycle
  TraceWriter.recv(3, "J", cycle)            -- should not throw
  TraceWriter.recv(3, "J", { ok = true })    -- next call still works
  TraceWriter.flush(3)
  local lines = readJsonLines(TraceWriter.currentPath(3))
  assert(#lines == 1, "encodable line should still land; got " .. tostring(#lines))
  assert(lines[1].body.ok == true)
end

local function test_flush_no_throw_when_no_session()
  logger.info("test_flush_no_throw_when_no_session")
  configureFresh()
  TraceWriter.flush(123) -- never opened — must just return
end

----------------------------------------------------------------------
-- Run
----------------------------------------------------------------------

test_beginSession_opens_file_path()
test_endSession_drops_state()
test_recv_send_localEvent_round_trip_to_disk()
test_per_publicId_isolation()
test_recv_with_no_active_session_is_noop()
test_nil_publicId_is_noop()
test_beginSession_idempotent()
test_no_throw_on_unencodable_body()
test_flush_no_throw_when_no_session()

logger.info("All TraceWriterTests passed!")
