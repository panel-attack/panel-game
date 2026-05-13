-- CrashReplayRegressionTests.lua
--
-- Two halves:
--   1. Bootstrap self-test (always runs). Programmatically builds a
--      tiny match, captures its replay, wraps it as a fixture in memory,
--      JSON-round-trips it, then runs it through the same loadFixture /
--      runPerspective / assertFixtureClean path real fixtures use.
--      Proves the harness works end-to-end with no disk artifact.
--   2. Disk-fixture sweep (no-op when empty). Replays every JSON under
--      common/tests/fixtures/crash_replays/ — the artifacts produced by
--      the capture pipeline (see docs/CRASH_REPLAY_PLAN.md). Each
--      fixture is one incident, one or more per-client perspectives.
--      Asserts the captured incident no longer reproduces.
--
-- TDD contract:
--   - Bootstrap green ⇒ the harness can load + drive + assert. If it
--     ever goes red, every fixture-based test result is suspect.
--   - Fixture red ⇒ the captured bug still reproduces in production.
--     Fix the bug, fixture goes green. Fix + fixture land in one commit.
--   - Silently-green new fixture ⇒ slice is under-specified; fix the
--     capture step, not the runner.

require("client.src.globals")

local logger      = require("common.lib.logger")
local json        = require("common.lib.dkjson")
local fileUtils   = require("client.src.FileUtils")
local Match       = require("common.engine.Match")
local ReplayV3    = require("common.data.ReplayV3")
local GeneratorSource = require("common.engine.GeneratorSource")
local LevelPresets    = require("common.data.LevelPresets")
local StateVector = require("common.tests.engine.StateVector")

local FIXTURE_DIR = "common/tests/fixtures/crash_replays"

-- Frame cap on any one perspective so a broken replay can't hang the
-- whole test suite. 30 minutes of sim at 60 fps is well past any
-- realistic match length.
local MAX_FRAMES = 60 * 60 * 30

----------------------------------------------------------------------
-- Runner internals (used by both bootstrap and disk-sweep)
----------------------------------------------------------------------

-- Re-hydrate every slice.replay into a real ReplayV3 (sets metatable,
-- backfills missing fields). Operates in-place so callers can pass an
-- in-memory fixture as well as one freshly decoded from JSON.
local function rehydrate(fixture)
  assert(type(fixture) == "table",
    "rehydrate: expected fixture table, got " .. type(fixture))
  assert(type(fixture.perspectives) == "table",
    "rehydrate: fixture missing perspectives table")
  for key, slice in pairs(fixture.perspectives) do
    assert(slice.replay, "rehydrate: perspective "
      .. tostring(key) .. " has no replay")
    slice.replay = ReplayV3.createFromV3Data(slice.replay)
  end
  return fixture
end

---@param filename string fixture filename (no path)
---@return table fixture with each perspective.replay re-hydrated as ReplayV3
local function loadFixture(filename)
  local raw = fileUtils.readJsonFile(FIXTURE_DIR .. "/" .. filename)
  assert(raw, "fixture " .. filename .. " missing or unreadable")
  return rehydrate(raw)
end

---Runs one perspective's replay through Match. Returns the match so the
---caller can read a state-vector. stopAtFrame defaults to the slice's
---gameContext.frame so we don't run past the captured suspect frame.
---@param slice table
---@param stopAtFrameOverride integer?
---@return Match
local function runPerspective(slice, stopAtFrameOverride)
  local match = Match.createFromReplay(slice.replay)
  match:start()

  -- Per-stack max-runs-per-frame = 1 so we can stop with frame precision.
  for _, stack in ipairs(match.stacks) do
    if stack.setMaxRunsPerFrame then stack:setMaxRunsPerFrame(1) end
  end

  local stopAt = stopAtFrameOverride
              or (slice.gameContext and slice.gameContext.frame)
              or MAX_FRAMES

  local frame = 0
  while not match:isLocallyEnded() do
    match:run()
    frame = frame + 1
    if frame >= stopAt then break end
    if frame > MAX_FRAMES then
      error("replay didn't terminate within " .. MAX_FRAMES .. " frames")
    end
  end
  return match
end

---Per-perspective sim + cross-perspective state-vector check.
---@param fixture table
local function assertFixtureClean(fixture)
  local states = {}

  for key, slice in pairs(fixture.perspectives) do
    -- (1) Each perspective replays without exploding. If this slice was
    -- the crash-origin (slice.error is set), assert the captured error
    -- fragment does NOT re-fire. Empty/nil error means "no captured
    -- crash on this perspective" — just confirm it runs cleanly.
    local ok, err = pcall(runPerspective, slice)
    if slice.error and slice.error ~= "" then
      local fragment = slice.error:match("[^:]+:%s*(.+)$") or slice.error
      assert(not (not ok and tostring(err):find(fragment, 1, true)),
        "perspective " .. tostring(key)
        .. " still reproduces the captured crash: " .. tostring(err))
    else
      assert(ok,
        "perspective " .. tostring(key)
        .. " failed during replay: " .. tostring(err))
    end

    -- (2) Capture state-vector at the suspect frame for cross-perspective
    -- check. Re-run; pcall so a per-perspective failure doesn't sabotage
    -- the other comparisons.
    local sfok, m = pcall(runPerspective, slice, fixture.suspectFrame)
    if sfok then states[key] = StateVector.fromMatch(m) end
  end

  -- (3) Every perspective should agree with the server's view at the
  -- suspect frame. Disagreement IS the desync the fixture was meant to
  -- lock in — flagging it red catches regressions of B8/B10-class bugs.
  -- Skip when no server perspective is present (single-perspective
  -- fixtures, e.g. the bootstrap self-test).
  local serverState = states.server
  if serverState then
    for key, state in pairs(states) do
      if key ~= "server" then
        assert(StateVector.equal(serverState, state),
          "perspective " .. tostring(key) .. " diverges from server at frame "
          .. tostring(fixture.suspectFrame) .. ":\n"
          .. "  server: " .. StateVector.hash(serverState) .. "\n"
          .. "  " .. tostring(key) .. ": " .. StateVector.hash(state))
      end
    end
  end
end

----------------------------------------------------------------------
-- Part 1: Bootstrap self-test
----------------------------------------------------------------------
-- Build a real Match programmatically, capture its replay, wrap it in
-- the fixture envelope, and run it through the harness. Proves the
-- end-to-end path works without depending on the capture pipeline or
-- any on-disk artifact. If this fails, every disk-fixture verdict is
-- suspect — so it runs first.

local function buildBootstrapMatch()
  -- Minimal 2-player VS with infinite health so test garbage can't
  -- accidentally kill a stack. Same recipe as TeamGarbageTests.lua.
  local matchRules = {
    matchEndConditions = { TEAMS_ACTIVE = 1 },
    matchWinRuleset = { { GAME_OVER_CLOCK = "HIGHEST" } },
    stackOverConditions = { HEALTH = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = false,
  }

  local seed = 13579
  local match = Match(GeneratorSource(seed, true), matchRules)

  -- Default modern-10 maxHealth survives 30 frames of "do nothing" inputs.
  -- We deliberately don't override to math.huge here: math.huge serializes
  -- to JSON as null, comes back as nil, and the stack then trips
  -- `health <= value` with a nil health when checkGameOver runs. The
  -- bootstrap match is short enough that the real cap doesn't fire.
  local levelData = LevelPresets.getModern(10)

  for i = 1, 2 do
    local stack = match:createStackWithSettings(levelData, false, "controller")
    stack:setMaxRunsPerFrame(1)
    -- Pre-feed a buffer of "do nothing" inputs so :run can advance frames
    -- without an input shortage.
    stack:receiveConfirmedInput(string.rep("A", 200))
  end

  match:start()

  -- Run 30 frames so the replay carries some real progress.
  while match.stacks[1].clock < 30 do
    match:run()
  end
  return match, seed, matchRules
end

local function captureReplayFromMatch(match, seed, matchRules)
  -- Build a ReplayV3 that mirrors what server/Game.lua's getPartialReplay
  -- would have produced for this match. The fields below are the ones
  -- Match.createFromReplay reads at load time.
  local replay = ReplayV3("000", matchRules, {
    sourceType = ReplayV3.panelSourceTypes.seedV2,
    seed = seed,
    shockEnabled = true,
  })

  -- engineVersion = "000" — bootstrap fixture isn't engine-version
  -- pinned. Real fixtures from production pin this to the engine that
  -- captured them.
  for i, stack in ipairs(match.stacks) do
    ---@type ReplayStack
    local replayStack = {
      stackType = ReplayV3.stackTypes.Stack,
      levelData = stack.levelData,
      stackBehaviours = stack.behaviours or { delaySimulationUntil = nil },
      inputMethod = "controller",
      inputs = string.rep("A", 200), -- same buffer we fed in
    }
    replay.stacks[i] = replayStack
    replay.metadata.stacks[i] = {
      stackIndex = i,
      name = "BootstrapBot" .. i,
      panelId = "__default",
      characterId = "__default",
    }
  end
  replay.metadata.gameModeName = "VS"
  replay.metadata.duration = match.stacks[1].clock
  return replay
end

local function bootstrapSelfTest()
  logger.info("CrashReplayRegressionTests: bootstrap self-test")

  local match, seed, matchRules = buildBootstrapMatch()
  local replay = captureReplayFromMatch(match, seed, matchRules)

  -- Wrap as a fixture exactly as the capture pipeline would. Single
  -- "server" perspective is enough — cross-perspective check skips
  -- when no peer perspectives exist.
  local fixture = {
    incidentId  = "bootstrap_self_test",
    schemaVer   = 1,
    reason      = "bootstrap",
    suspectFrame = 20,
    perspectives = {
      server = {
        incidentId = "bootstrap_self_test",
        publicId   = "server",
        schemaVer  = 1,
        error      = "",
        trace      = "",
        traceHash  = "",
        clientMeta = { engineVersion = "000", os = "test" },
        gameContext = {
          roomNumber = 0, gameId = 0, frame = 25,
          gameModeName = "VS", matchCount = 1,
        },
        replay = replay,
        logTail = {},
      },
    },
  }

  -- JSON round-trip so we test exactly what the disk path will do.
  local encoded = assert(json.encode(fixture), "bootstrap fixture failed to encode")
  local decoded = assert(json.decode(encoded), "bootstrap fixture failed to decode")

  rehydrate(decoded)
  assertFixtureClean(decoded)
end

----------------------------------------------------------------------
-- Part 2: Disk-fixture sweep
----------------------------------------------------------------------

---@return string[] list of .json fixture filenames (no path), or empty
local function listFixtures()
  local items = love.filesystem.getDirectoryItems(FIXTURE_DIR)
  local out = {}
  for _, name in ipairs(items or {}) do
    if name:match("%.json$") then
      out[#out + 1] = name
    end
  end
  table.sort(out)
  return out
end

local function diskSweep()
  local files = listFixtures()
  if #files == 0 then
    logger.info("CrashReplayRegressionTests: no on-disk fixtures yet under "
                .. FIXTURE_DIR .. " — sweep is a no-op until the capture"
                .. " pipeline lands fixtures")
    return
  end

  for _, file in ipairs(files) do
    logger.info("CrashReplayRegressionTests: running fixture " .. file)
    local fixture = loadFixture(file)
    assertFixtureClean(fixture)
  end
end

----------------------------------------------------------------------
-- Entry
----------------------------------------------------------------------

bootstrapSelfTest()
diskSweep()
logger.info("All CrashReplayRegressionTests passed!")
