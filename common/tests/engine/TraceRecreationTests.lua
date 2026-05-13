-- TraceRecreationTests.lua — the Phase D gate.
--
-- Drive a real Match. Capture trace events alongside it via TraceWriter.
-- Read the captured JSONL back via TraceReader. Drive a fresh Match
-- through the recreated event stream. Assert the two engines agree.
--
-- If this test ever fails, the trace is under-specified: the writer
-- isn't capturing enough to reproduce the live match. Per the plan, the
-- fix lives in TcpClient's tap layer (or the input/lifecycle taps), NOT
-- in this test.

require("client.src.globals")
local logger      = require("common.lib.logger")
local json        = require("common.lib.dkjson")
local Match       = require("common.engine.Match")
local ReplayV3    = require("common.data.ReplayV3")
local GeneratorSource = require("common.engine.GeneratorSource")
local LevelPresets    = require("common.data.LevelPresets")
local NetworkProtocol = require("common.network.NetworkProtocol")
local TraceWriter = require("client.src.network.TraceWriter")
local TraceReader = require("client.src.network.TraceReader")
local StateVector = require("common.tests.engine.StateVector")

----------------------------------------------------------------------
-- Test fixtures
----------------------------------------------------------------------

-- Build a tiny live match: 2-player VS, no countdown, 200 frames of
-- "do nothing" inputs.
local function buildLiveMatch(seed)
  local matchRules = {
    matchEndConditions      = { TEAMS_ACTIVE = 1 },
    matchWinRuleset         = { { GAME_OVER_CLOCK = "HIGHEST" } },
    stackOverConditions     = { HEALTH = 0 },
    stackWinConditions      = {},
    stackSetupModifications = {},
    doCountdown             = false,
  }
  local match = Match(GeneratorSource(seed, true), matchRules)
  local levelData = LevelPresets.getModern(10)

  for i = 1, 2 do
    local stack = match:createStackWithSettings(levelData, false, "controller")
    stack:setMaxRunsPerFrame(1)
    stack:receiveConfirmedInput(string.rep("A", 500))
  end
  match:start()
  return match, matchRules
end

-- Synthesize the matchStart message payload the way the server would
-- have shipped it. Trace replay starts here.
local function matchStartContent(match, seed, matchRules)
  local replay = ReplayV3("000", matchRules, {
    sourceType = ReplayV3.panelSourceTypes.seedV2,
    seed = seed,
    shockEnabled = true,
  })
  for i, stack in ipairs(match.stacks) do
    replay.stacks[i] = {
      stackType = ReplayV3.stackTypes.Stack,
      levelData = stack.levelData,
      stackBehaviours = stack.behaviours or { delaySimulationUntil = nil },
      inputMethod = "controller",
      inputs = string.rep("A", 500),
    }
    replay.metadata.stacks[i] = {
      stackIndex = i,
      name = "BotP" .. i,
      panelId = "__default",
      characterId = "__default",
    }
  end
  replay.metadata.gameModeName = "VS"
  return replay
end

-- Minimal in-memory love.filesystem stub so TraceWriter has a place to
-- "append" to without touching real disk. We collect everything into a
-- single buffer keyed by path.
local function makeFs()
  local store = { files = {} }
  return store, {
    append = function(path, blob)
      store.files[path] = (store.files[path] or "") .. blob
    end,
    createDirectory = function(_path) end,
  }
end

----------------------------------------------------------------------
-- Test
----------------------------------------------------------------------

local function test_trace_roundtrip_reproduces_live_state()
  logger.info("test_trace_roundtrip_reproduces_live_state")

  local seed = 13579
  local live, matchRules = buildLiveMatch(seed)
  local startContent = matchStartContent(live, seed, matchRules)

  -- Stand up the writer. fixed clock so timestamps are deterministic.
  local fsStore, fsStub = makeFs()
  TraceWriter.configure({
    fs = fsStub,
    clock = function() return 1000 end,
    flushEvents = 1,  -- flush on every event so the buffer is irrelevant
  })
  TraceWriter.beginSession(1000)
  TraceWriter.beginMatch(1, 1000)
  TraceWriter.beginGame(1000)

  -- Capture the matchStart frame the way the wire would have. This is
  -- the only line load-bearing for recreation; everything else feeds
  -- the engine after it bootstraps.
  TraceWriter.recv(
    NetworkProtocol.serverMessageTypes.jsonMessage.prefix,
    { type = "matchStart", content = startContent })

  -- Drive the live match for 30 frames so there's real engine progress.
  while live.stacks[1].clock < 30 do
    live:run()
  end

  TraceWriter.endGame()

  -- Collect everything written. exactly one file in fsStore.files.
  local path, blob = next(fsStore.files)
  assert(path and blob, "TraceWriter should have written one file")

  -- Recreate from the trace.
  local recreated, err = TraceReader.recreateFromBlob(blob)
  assert(recreated, "TraceReader failed: " .. tostring(err))

  -- The trace only carries matchStart so the recreated match starts at
  -- clock 0. Advance the recreated match the same number of frames as
  -- the live one — recreation is "from matchStart + recorded events,"
  -- not "play the live timeline back."
  while recreated.stacks[1].clock < 30 do
    recreated:run()
  end

  -- State vectors should agree at frame 30.
  local liveVec = StateVector.fromMatch(live)
  local recVec  = StateVector.fromMatch(recreated)
  assert(StateVector.equal(liveVec, recVec),
    "live and recreated state diverge:\n"
    .. "  live: " .. StateVector.hash(liveVec) .. "\n"
    .. "  recr: " .. StateVector.hash(recVec))

  logger.info("recreation OK at frame 30: " .. StateVector.hash(liveVec))
end

----------------------------------------------------------------------
-- Run
----------------------------------------------------------------------

test_trace_roundtrip_reproduces_live_state()

logger.info("All TraceRecreationTests passed!")
