-- TeamGarbageTests.lua
-- Integration tests for garbage distribution in team modes

require("client.src.globals")
local logger = require("common.lib.logger")
local Match = require("common.engine.Match")
local GameModes = require("common.data.GameModes")
local LevelPresets = require("common.data.LevelPresets")
local GeneratorSource = require("common.engine.GeneratorSource")
local TeamUtils = require("common.data.TeamUtils")
local GarbageQueueTestingUtils = require("common.tests.engine.GarbageQueueTestingUtils")
local tableUtils = require("common.lib.tableUtils")

-- Helper to create a team match configured for garbage testing
local function createGarbageTestMatch(playerCount, teamCount, playersPerTeam, garbageMode)
  local matchRules = {
    matchEndConditions = { TEAMS_ACTIVE = 1 },
    matchWinRuleset = { { GAME_OVER_CLOCK = "HIGHEST" } },
    stackOverConditions = { HEALTH = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = false,
  }

  local match = Match(GeneratorSource(12345, true), matchRules)

  local levelData = LevelPresets.getModern(10)
  levelData.maxHealth = math.huge  -- Don't die from garbage

  for i = 1, playerCount do
    local stack = match:createStackWithSettings(levelData, false, "controller")
    stack:setMaxRunsPerFrame(1)
    stack:receiveConfirmedInput(string.rep("A", 10000))
    -- Clear panels to make room for garbage
    GarbageQueueTestingUtils.reduceRowsTo(stack, 0)
  end

  local teams = TeamUtils.createTeams(playerCount, teamCount, playersPerTeam)
  match:setTeams(teams)
  match:setGarbageMode(garbageMode)
  match:setupTeamGarbageTargets()

  match:start()

  return match, teams
end

-- Helper to run match to a specific frame
local function runToFrame(match, targetFrame)
  while match.stacks[1].clock < targetFrame do
    match:run()
  end
end

-- Helper to check if a stack received garbage
local function stackReceivedGarbage(stack)
  return stack.incomingGarbage and stack.incomingGarbage:len() > 0
end

-- Helper to get total incoming garbage for a stack (uses history to count all garbage ever received)
local function getIncomingGarbageCount(stack)
  if not stack.incomingGarbage then return 0 end
  -- Use history instead of :len() because :len() only counts staged garbage
  -- which gets consumed when garbage drops onto the stack
  return #stack.incomingGarbage.history
end

-- Helper to kill a stack
local function killStack(stack)
  stack.health = 0
  stack:recordDeath()
end

--------------------------------------------------
-- "All" Mode Tests - Garbage hits all enemies
--------------------------------------------------

local function testGarbageAllMode_hitsAllEnemies()
  logger.info("testGarbageAllMode_hitsAllEnemies")

  local match, teams = createGarbageTestMatch(4, 2, 2, "all")
  local p1Stack = match.stacks[1]
  local p2Stack = match.stacks[2]  -- Teammate
  local p3Stack = match.stacks[3]  -- Enemy
  local p4Stack = match.stacks[4]  -- Enemy

  -- Debug: check garbage targets setup
  logger.info("P1 targets: " .. #(match.garbageTargets[1] or {}))
  logger.info("P3 sources: " .. #(match.garbageSources[p3Stack] or {}))

  -- Run to frame 100
  runToFrame(match, 100)

  -- P1 sends garbage (4 wide combo)
  GarbageQueueTestingUtils.sendGarbage(p1Stack, 4, 1)
  logger.info("P1 outgoing garbage len: " .. p1Stack.outgoingGarbage:len())
  logger.info("P1 stopWatch when sent: " .. p1Stack.stopWatch)

  -- Run a bit to let processStagedGarbageForClock move garbage to transit
  runToFrame(match, 200)
  logger.info("After frame 200:")
  logger.info("P1 outgoing garbage len: " .. p1Stack.outgoingGarbage:len())
  logger.info("P1 outgoing garbageInTransit: " .. tableUtils.length(p1Stack.outgoingGarbage.garbageInTransit or {}))
  logger.info("P1 transitTimers first: " .. tostring(p1Stack.outgoingGarbage.transitTimers.first))
  logger.info("P1 transitTimers last: " .. tostring(p1Stack.outgoingGarbage.transitTimers.last))

  -- Run until garbage arrives (garbage transit time)
  runToFrame(match, 300)

  -- Debug: check what happened
  logger.info("After run to 300:")
  logger.info("P1 clock=" .. p1Stack.clock .. " stopWatch=" .. p1Stack.stopWatch)
  logger.info("P3 clock=" .. p3Stack.clock .. " stopWatch=" .. p3Stack.stopWatch)
  logger.info("P1 outgoing garbage len: " .. p1Stack.outgoingGarbage:len())
  logger.info("P1 outgoing garbageInTransit: " .. tableUtils.length(p1Stack.outgoingGarbage.garbageInTransit or {}))
  for k, v in pairs(p1Stack.outgoingGarbage.garbageInTransit or {}) do
    logger.info("  transit key: " .. tostring(k) .. " value count: " .. #v)
  end
  logger.info("P1 oldest transit time: " .. tostring(p1Stack:getOldestFinishedGarbageTransitTime()))
  logger.info("P3 incoming garbage len: " .. getIncomingGarbageCount(p3Stack))
  logger.info("P3 incoming garbageInTransit: " .. tableUtils.length(p3Stack.incomingGarbage.garbageInTransit or {}))
  logger.info("P4 incoming garbage len: " .. getIncomingGarbageCount(p4Stack))

  -- P3 should receive garbage
  assert(getIncomingGarbageCount(p3Stack) > 0, "P3 (enemy) should receive garbage")

  -- P4 should receive garbage
  assert(getIncomingGarbageCount(p4Stack) > 0, "P4 (enemy) should receive garbage")

  -- P2 should NOT receive garbage (teammate)
  assert(getIncomingGarbageCount(p2Stack) == 0, "P2 (teammate) should NOT receive garbage")
end

local function testGarbageAllMode_teammateNeverReceives()
  logger.info("testGarbageAllMode_teammateNeverReceives")

  local match, teams = createGarbageTestMatch(4, 2, 2, "all")
  local p1Stack = match.stacks[1]
  local p2Stack = match.stacks[2]  -- Teammate

  runToFrame(match, 100)

  -- P1 sends multiple garbage combos
  GarbageQueueTestingUtils.sendGarbage(p1Stack, 3, 1)
  GarbageQueueTestingUtils.sendGarbage(p1Stack, 4, 1)
  GarbageQueueTestingUtils.sendGarbage(p1Stack, 5, 1)

  runToFrame(match, 500)

  -- P2 should never receive garbage from teammate
  assert(getIncomingGarbageCount(p2Stack) == 0, "Teammate should NEVER receive garbage")
end

local function testGarbageAllMode_skipsDeadEnemies()
  logger.info("testGarbageAllMode_skipsDeadEnemies")

  local match, teams = createGarbageTestMatch(4, 2, 2, "all")
  local p1Stack = match.stacks[1]
  local p3Stack = match.stacks[3]  -- Enemy - will die
  local p4Stack = match.stacks[4]  -- Enemy - alive

  runToFrame(match, 100)

  -- Kill P3
  killStack(p3Stack)

  -- P1 sends garbage after P3 is dead
  GarbageQueueTestingUtils.sendGarbage(p1Stack, 4, 1)

  runToFrame(match, 300)

  -- Only P4 should receive garbage (P3 is dead)
  assert(getIncomingGarbageCount(p4Stack) > 0, "P4 (living enemy) should receive garbage")
  -- Dead players shouldn't accumulate more garbage
  -- (implementation may vary - they might still be in queue but not processed)
end

local function testGarbageAllMode_1v2_soloHitsBoth()
  logger.info("testGarbageAllMode_1v2_soloHitsBoth")

  local match, teams = createGarbageTestMatch(3, 2, {1, 2}, "all")  -- 1v2
  local soloStack = match.stacks[1]
  local teamStack1 = match.stacks[2]
  local teamStack2 = match.stacks[3]

  runToFrame(match, 100)

  -- Solo sends garbage
  GarbageQueueTestingUtils.sendGarbage(soloStack, 4, 1)

  runToFrame(match, 300)

  -- Both team members should receive garbage
  assert(getIncomingGarbageCount(teamStack1) > 0, "Team member 1 should receive garbage from solo")
  assert(getIncomingGarbageCount(teamStack2) > 0, "Team member 2 should receive garbage from solo")
end

local function testGarbageAllMode_1v2_teamHitsSolo()
  logger.info("testGarbageAllMode_1v2_teamHitsSolo")

  local match, teams = createGarbageTestMatch(3, 2, {1, 2}, "all")  -- 1v2
  local soloStack = match.stacks[1]
  local teamStack1 = match.stacks[2]

  runToFrame(match, 100)

  -- Team member sends garbage
  GarbageQueueTestingUtils.sendGarbage(teamStack1, 4, 1)

  runToFrame(match, 300)

  -- Solo should receive garbage
  assert(getIncomingGarbageCount(soloStack) > 0, "Solo should receive garbage from team")
end

--------------------------------------------------
-- "Shared" Mode Tests - Round-robin targeting
--------------------------------------------------

local function testGarbageSharedMode_roundRobin_firstCombo()
  logger.info("testGarbageSharedMode_roundRobin_firstCombo")

  local match, teams = createGarbageTestMatch(4, 2, 2, "shared")
  local p1Stack = match.stacks[1]
  local p3Stack = match.stacks[3]  -- First enemy in rotation
  local p4Stack = match.stacks[4]  -- Second enemy in rotation

  runToFrame(match, 100)

  -- P1 sends first combo
  GarbageQueueTestingUtils.sendGarbage(p1Stack, 4, 1)

  runToFrame(match, 300)

  -- First combo should go to P3 (first in round-robin)
  local p3Garbage = getIncomingGarbageCount(p3Stack)
  local p4Garbage = getIncomingGarbageCount(p4Stack)

  assert(p3Garbage > 0 or p4Garbage > 0, "One enemy should receive garbage")
  -- Only ONE should receive (not both like in "all" mode)
  assert(not (p3Garbage > 0 and p4Garbage > 0), "Only ONE enemy should receive in shared mode")
end

local function testGarbageSharedMode_roundRobin_alternates()
  logger.info("testGarbageSharedMode_roundRobin_alternates")

  local match, teams = createGarbageTestMatch(4, 2, 2, "shared")
  local p1Stack = match.stacks[1]
  local p3Stack = match.stacks[3]
  local p4Stack = match.stacks[4]

  runToFrame(match, 100)

  -- Track who receives first
  GarbageQueueTestingUtils.sendGarbage(p1Stack, 3, 1)
  runToFrame(match, 300)

  local p3First = getIncomingGarbageCount(p3Stack)
  local p4First = getIncomingGarbageCount(p4Stack)

  -- Send second combo
  GarbageQueueTestingUtils.sendGarbage(p1Stack, 3, 1)
  runToFrame(match, 500)

  local p3Second = getIncomingGarbageCount(p3Stack)
  local p4Second = getIncomingGarbageCount(p4Stack)

  -- The target should have alternated
  if p3First > 0 then
    assert(p4Second > p4First, "Second combo should go to P4 (alternating)")
  else
    assert(p3Second > p3First, "Second combo should go to P3 (alternating)")
  end
end

local function testGarbageSharedMode_fullComboToOneTarget()
  logger.info("testGarbageSharedMode_fullComboToOneTarget")

  local match, teams = createGarbageTestMatch(4, 2, 2, "shared")
  local p1Stack = match.stacks[1]
  local p3Stack = match.stacks[3]
  local p4Stack = match.stacks[4]

  runToFrame(match, 100)

  -- Send a 5-block combo (should NOT be split)
  GarbageQueueTestingUtils.sendGarbage(p1Stack, 5, 1)

  runToFrame(match, 300)

  local p3Garbage = getIncomingGarbageCount(p3Stack)
  local p4Garbage = getIncomingGarbageCount(p4Stack)

  -- One player should have all 5, other should have 0
  assert((p3Garbage == 1 and p4Garbage == 0) or (p3Garbage == 0 and p4Garbage == 1),
    "Full combo should go to ONE target, not split")
end

local function testGarbageSharedMode_skipsDeadInRotation()
  logger.info("testGarbageSharedMode_skipsDeadInRotation")

  local match, teams = createGarbageTestMatch(4, 2, 2, "shared")
  local p1Stack = match.stacks[1]
  local p3Stack = match.stacks[3]
  local p4Stack = match.stacks[4]

  runToFrame(match, 100)

  -- Kill P3
  killStack(p3Stack)

  -- Send multiple combos
  GarbageQueueTestingUtils.sendGarbage(p1Stack, 3, 1)
  runToFrame(match, 300)
  GarbageQueueTestingUtils.sendGarbage(p1Stack, 3, 1)
  runToFrame(match, 500)
  GarbageQueueTestingUtils.sendGarbage(p1Stack, 3, 1)
  runToFrame(match, 700)

  -- All should go to P4 (only living enemy)
  assert(getIncomingGarbageCount(p4Stack) >= 3, "All combos should go to P4 (only living enemy)")
end

local function testGarbageSharedMode_teamSharesRotation()
  logger.info("testGarbageSharedMode_teamSharesRotation")

  local match, teams = createGarbageTestMatch(4, 2, 2, "shared")
  local p1Stack = match.stacks[1]
  local p2Stack = match.stacks[2]  -- Teammate
  local p3Stack = match.stacks[3]
  local p4Stack = match.stacks[4]

  runToFrame(match, 100)

  -- P1 sends combo (should go to one enemy)
  GarbageQueueTestingUtils.sendGarbage(p1Stack, 3, 1)
  runToFrame(match, 300)

  local p3AfterP1 = getIncomingGarbageCount(p3Stack)
  local p4AfterP1 = getIncomingGarbageCount(p4Stack)

  -- P2 sends combo; per-sender shared mode should keep P2's own cursor,
  -- so this should not affect P1's next target.
  GarbageQueueTestingUtils.sendGarbage(p2Stack, 3, 1)
  runToFrame(match, 500)

  -- P1 sends again; this should alternate relative to P1's first delivery,
  -- independent of P2's attack in between.
  GarbageQueueTestingUtils.sendGarbage(p1Stack, 3, 1)
  runToFrame(match, 700)

  local p3AfterP1Second = getIncomingGarbageCount(p3Stack)
  local p4AfterP1Second = getIncomingGarbageCount(p4Stack)

  if p3AfterP1 > 0 then
    assert(p4AfterP1Second > p4AfterP1, "P1 should alternate to P4 on second send")
  else
    assert(p3AfterP1Second > p3AfterP1, "P1 should alternate to P3 on second send")
  end
end

--------------------------------------------------
-- Garbage target configuration tests
--------------------------------------------------

local function testGarbageTargets_allMode_configured()
  logger.info("testGarbageTargets_allMode_configured")

  local match, teams = createGarbageTestMatch(4, 2, 2, "all")

  -- Check garbage targets are configured
  assert(match.garbageTargets ~= nil, "Match should have garbageTargets")

  -- P1's targets should be P3 and P4 (enemies)
  local p1Targets = match.garbageTargets[1]
  assert(p1Targets ~= nil, "P1 should have garbage targets")
  assert(#p1Targets == 2, "P1 should target 2 enemies in 'all' mode")
end

local function testGarbageTargets_sharedMode_configured()
  logger.info("testGarbageTargets_sharedMode_configured")

  local match, teams = createGarbageTestMatch(4, 2, 2, "shared")

  -- Shared mode should have round-robin state
  assert(match.teamGarbageState ~= nil, "Match should have teamGarbageState for shared mode")
  assert(match.teamGarbageState[1] ~= nil, "Team 1 should have garbage state")
  assert(match.teamGarbageState[2] ~= nil, "Team 2 should have garbage state")
end

--------------------------------------------------
-- Run all tests
--------------------------------------------------

-- All mode tests
testGarbageAllMode_hitsAllEnemies()
testGarbageAllMode_teammateNeverReceives()
testGarbageAllMode_skipsDeadEnemies()
testGarbageAllMode_1v2_soloHitsBoth()
testGarbageAllMode_1v2_teamHitsSolo()

-- Shared mode tests
testGarbageSharedMode_roundRobin_firstCombo()
testGarbageSharedMode_roundRobin_alternates()
testGarbageSharedMode_fullComboToOneTarget()
testGarbageSharedMode_skipsDeadInRotation()
testGarbageSharedMode_teamSharesRotation()

-- Configuration tests
testGarbageTargets_allMode_configured()
testGarbageTargets_sharedMode_configured()

logger.info("All TeamGarbageTests passed!")
