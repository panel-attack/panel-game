-- TraceReplayTests.lua
--
-- Two halves:
--
--   1. Sanity round-trip. Hand-crafts a tiny trace, drives it through
--      a TestClient against a freshly-spun E2E Harness, asserts the
--      server processed the captured sends. Proves the replay loop is
--      wired end-to-end with no captured fixture needed. Always runs.
--
--   2. Fixture sweep. Scans `common/tests/fixtures/trace_replays/` for
--      bundle directories and replays each. One Harness per bundle,
--      one TestClient per publicId, merged-by-ts send stream. No-op
--      when the directory is empty (the case today).
--
-- See docs/TRACE_LOGS_GUIDE.md for the bundle layout. The replay model
-- is "drive captured sends back through TestClient against a local
-- Server in tests" — see docs/CRASH_REPLAY_PLAN.md "Recreation" plus
-- the design conversation that pivoted from engine-driven to
-- server-driven replay.

---@diagnostic disable: invisible
local Harness     = require("server.tests.E2E.Harness")
local TraceReplay = require("server.tests.E2E.TraceReplay")
local logger      = require("common.lib.logger")
local json        = require("common.lib.dkjson")
local socket      = require("common.lib.socket")

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function jsonLine(entry) return json.encode(entry) .. "\n" end

-- Step a TestClient through its handshake (version + login).
-- replayTrace deliberately skips H and replays J payloads as-is, so a
-- trace's original login_request would attempt to log in TWICE if we
-- did the handshake AND replayed. For the sanity test we drive the
-- handshake manually and start the trace AFTER login.
local function loginClient(h, client)
  client:sendVersionCheck()
  assert(h:waitUntil(function() return client.versionConfirmed end, 5,
    "version check"))
  client:sendLogin()
  assert(h:waitUntil(function() return client.loggedIn end, 5, "login"))
end

----------------------------------------------------------------------
-- (1) Sanity round-trip
----------------------------------------------------------------------

-- Confirms TestClient:replayTrace walks `send` events and dispatches to
-- the right sendX method. Hand-crafted trace asks for a 2p-VS room;
-- after replay the harness should have one room.
local function test_replay_drives_send_events()
  logger.info("test_replay_drives_send_events")
  local h = Harness():start()
  local ok, err = pcall(function()
    local bot = h:addClient("Repl")
    loginClient(h, bot)

    -- Hand-crafted trace: one J send carrying a roomRequest. Mirrors
    -- exactly what TraceWriter would have written when the original
    -- client clicked "create room" for two-player VS.
    local trace = jsonLine({
      ts = socket.gettime(),
      dir = "send",
      prefix = "J",
      body = {
        type = "roomRequest",
        content = {
          gameMode = { gameModeId = "TWO_PLAYER_VS", name = "TWO_PLAYER_VS" },
          latencyTolerance = "relaxed",
        },
      },
    })

    local replayed = bot:replayTrace(trace)
    assert(replayed == 1,
      "expected 1 send event replayed, got " .. tostring(replayed))

    -- The harness should now have a room.
    assert(h:waitUntil(function() return h:firstRoom() ~= nil end, 5,
      "room created from replayed roomRequest"),
      "room was not created — replay didn't drive the send")
  end)
  h:stop()
  if not ok then error(err) end
end

-- Confirms the dispatcher accepts each prefix and skips H/E.
local function test_replay_dispatcher_handles_each_prefix()
  logger.info("test_replay_dispatcher_handles_each_prefix")
  local h = Harness():start()
  local ok, err = pcall(function()
    local bot = h:addClient("Disp")
    loginClient(h, bot)

    -- One line per supported prefix. Bodies are minimal but the right
    -- type for each — the dispatcher's job is structural, not semantic.
    local lines = table.concat({
      jsonLine({ ts=1, dir="send", prefix="H", body=""    }),  -- skipped
      jsonLine({ ts=2, dir="send", prefix="E", body=""    }),  -- skipped
      jsonLine({ ts=3, dir="send", prefix="I", body="A"   }),  -- input
      jsonLine({ ts=4, dir="send", prefix="J", body={ leave_room = true } }),
      jsonLine({ ts=5, dir="send", prefix="G", body={ senderFrame=1, recipients={}, garbage={} } }),
      jsonLine({ ts=6, dir="send", prefix="D", body={ senderFrame=1, reason="topOut" } }),
      jsonLine({ ts=7, dir="recv", prefix="J", body={ type="ignored" } }),  -- recv events never replayed
    }, "")

    local replayed = bot:replayTrace(lines)
    -- 4 dispatched: I, J(leave_room), G, D. H/E intentionally skipped;
    -- recv lines never count.
    assert(replayed == 4,
      "expected 4 send events replayed, got " .. tostring(replayed))
  end)
  h:stop()
  if not ok then error(err) end
end

----------------------------------------------------------------------
-- (2) Fixture sweep
----------------------------------------------------------------------

local FIXTURE_ROOT = "common/tests/fixtures/trace_replays"

local function listBundles()
  local out = {}
  local items
  if love and love.filesystem then
    items = love.filesystem.getDirectoryItems(FIXTURE_ROOT) or {}
  else
    local lfs = require("lfs")
    local attr = lfs.attributes(FIXTURE_ROOT)
    if not attr or attr.mode ~= "directory" then return out end
    for name in lfs.dir(FIXTURE_ROOT) do
      if name ~= "." and name ~= ".." then items = items or {}; items[#items + 1] = name end
    end
    items = items or {}
  end
  for _, name in ipairs(items) do
    local path = FIXTURE_ROOT .. "/" .. name
    local isdir
    if love and love.filesystem then
      local info = love.filesystem.getInfo(path)
      isdir = info and info.type == "directory"
    else
      local lfs = require("lfs")
      local a = lfs.attributes(path)
      isdir = a and a.mode == "directory"
    end
    if isdir then out[#out + 1] = name end
  end
  table.sort(out)
  return out
end

-- Replays one bundle directory against a fresh Harness. Pretty bare
-- assertion shape — the only thing we universally check is "no
-- server-side error was logged." Bug-specific assertions belong in
-- per-bundle test files that the author writes alongside the fixture.
local function replayBundle(bundleName)
  logger.info("replayBundle: " .. bundleName)
  local bundleDir = FIXTURE_ROOT .. "/" .. bundleName
  local clients, merged = TraceReplay.loadAndMerge(bundleDir)
  if not next(clients) then
    logger.warn("bundle " .. bundleName .. " has no client trace dirs — skipping")
    return
  end

  local h = Harness():start()
  local ok, err = pcall(function()
    -- One TestClient per publicId in the bundle.
    local botByPid = {}
    -- Names are capped at NAME_LENGTH_LIMIT (16) by the server, and the
    -- Harness appends a "_<6hex>" suffix per run. That leaves ~9 chars
    -- for our prefix; "P<publicId>" keeps the publicId visible in logs
    -- while staying well under the cap for any sane integer publicId.
    for publicId in pairs(clients) do
      local bot = h:addClient("P" .. tostring(publicId))
      loginClient(h, bot)
      botByPid[publicId] = bot
    end

    -- Drive every captured send through the right TestClient, in
    -- chronological order. Tick the harness between events so the
    -- server processes each before the next arrives.
    for _, entry in ipairs(merged) do
      local bot = botByPid[entry.publicId]
      if bot then
        bot:_replaySendEvent(entry.prefix, entry.body)
        h:tick()
      end
    end

    -- Let the server settle.
    h:tickFor(0.2)
  end)
  h:stop()
  if not ok then error("bundle " .. bundleName .. " failed: " .. tostring(err)) end
end

local function fixture_sweep()
  local bundles = listBundles()
  if #bundles == 0 then
    logger.info("TraceReplayTests: no bundles under " .. FIXTURE_ROOT
                .. " — fixture sweep is a no-op until traces are added")
    return
  end
  for _, name in ipairs(bundles) do
    replayBundle(name)
  end
end

----------------------------------------------------------------------
-- Runner
----------------------------------------------------------------------

local function runAll()
  test_replay_drives_send_events()
  test_replay_dispatcher_handles_each_prefix()
  fixture_sweep()
  logger.info("All TraceReplayTests passed!")
end

if not package.loaded["server.tests.E2E.TraceReplayTests"] then
  runAll()
end

return {
  runAll = runAll,
  test_replay_drives_send_events           = test_replay_drives_send_events,
  test_replay_dispatcher_handles_each_prefix = test_replay_dispatcher_handles_each_prefix,
  fixture_sweep                            = fixture_sweep,
}
