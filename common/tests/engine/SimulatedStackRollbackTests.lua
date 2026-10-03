local StackReplayTestingUtils = require("common.tests.engine.StackReplayTestingUtils")
local Match = require("common.engine.Match")
local GameModes = require("common.data.GameModes")
local LevelPresets = require("common.data.LevelPresets")
local GeneratorSource = require("common.engine.GeneratorSource")

local function createMatchWithSimulatedStack(attackSettings, healthSettings)
  local mode = GameModes.getPreset("ONE_PLAYER_TRAINING")
  local match = Match(GeneratorSource(1, true), mode.matchRules)

  local levelData = LevelPresets.getModern(5)
  local stack1 = match:createStackWithSettings(levelData, false, "controller")
  stack1:setMaxRunsPerFrame(1)
  stack1:receiveConfirmedInput(string.rep("A", 10000))

  local simulatedStack = match:createSimulatedStackWithSettings(attackSettings, healthSettings)
  simulatedStack:setMaxRunsPerFrame(1)

  match:addTarget(simulatedStack, stack1)
  match:start()

  return match, stack1, simulatedStack
end

local function simulateSimulatedStackUntil(simulatedStack, clockGoal)
  while simulatedStack.clock < clockGoal do
    simulatedStack:run()
    simulatedStack:saveForRollback()
  end
  assert(simulatedStack.clock == clockGoal, "Expected clock=" .. clockGoal .. " but got clock=" .. simulatedStack.clock)
end

-- a rolled back stack has to be indistinguishable from one that simulated the same frames without interruption
local function assertSameSimulatedState(rolledBack, uninterrupted)
  assertEqual(rolledBack.clock, uninterrupted.clock)
  assertEqual(rolledBack.stopWatch, uninterrupted.stopWatch)
  assert(rolledBack.stopWatchIsRunning == uninterrupted.stopWatchIsRunning,
         "stopWatchIsRunning was " .. tostring(rolledBack.stopWatchIsRunning) .. " after the rollback but "
         .. tostring(uninterrupted.stopWatchIsRunning) .. " without one")
  assert(rolledBack.countdown_timer == uninterrupted.countdown_timer,
         "countdown_timer was " .. tostring(rolledBack.countdown_timer) .. " after the rollback but "
         .. tostring(uninterrupted.countdown_timer) .. " without one")
  assertEqual(#rolledBack.outgoingGarbage.history, #uninterrupted.outgoingGarbage.history)
end

local ATTACK_SETTINGS = {
  delayBeforeStart = 0,
  delayBeforeRepeat = 0,
  countdownAdjusted = true,
  attackPatterns = {
    {width = 3, height = 1, startTime = 100},
    {width = 4, height = 1, startTime = 200},
  }
}

-- the countdown ends on clock 188, so the attack at stopWatch 100 is sent on clock 288
local function rollbackFromPastAnAttackIntoTheCountdownTest()

  local match, _, simulatedStack = createMatchWithSimulatedStack(ATTACK_SETTINGS)
  local referenceMatch, _, reference = createMatchWithSimulatedStack(ATTACK_SETTINGS)

  simulateSimulatedStackUntil(simulatedStack, 320)
  assert(#simulatedStack.outgoingGarbage.history == 1, "Expected the attack at stopWatch 100 to have been sent by clock 320")

  assert(simulatedStack:rollbackRewindToFrame(75, false))
  assertEqual(simulatedStack.clock, 75)
  assertEqual(simulatedStack.stopWatch, 0)
  assertEqual(#simulatedStack.outgoingGarbage.history, 0)

  simulateSimulatedStackUntil(simulatedStack, 150)
  simulateSimulatedStackUntil(reference, 150)
  assertSameSimulatedState(simulatedStack, reference)

  simulateSimulatedStackUntil(simulatedStack, 400)
  simulateSimulatedStackUntil(reference, 400)
  assertSameSimulatedState(simulatedStack, reference)

  StackReplayTestingUtils:cleanup(match)
  StackReplayTestingUtils:cleanup(referenceMatch)
end

local function rollbackWithinTheCountdownTest()

  local match, _, simulatedStack = createMatchWithSimulatedStack(ATTACK_SETTINGS)
  local referenceMatch, _, reference = createMatchWithSimulatedStack(ATTACK_SETTINGS)

  simulateSimulatedStackUntil(simulatedStack, 150)
  assert(simulatedStack:rollbackRewindToFrame(145, false))
  assertEqual(simulatedStack.clock, 145)

  simulateSimulatedStackUntil(simulatedStack, 200)
  simulateSimulatedStackUntil(reference, 200)
  assertSameSimulatedState(simulatedStack, reference)
  assertEqual(simulatedStack.stopWatch, 12)

  StackReplayTestingUtils:cleanup(match)
  StackReplayTestingUtils:cleanup(referenceMatch)
end

-- Match:debugCheckDivergence compares the copy's clock against the stack's, so a copy that omits
-- the clock can never be checked and silently passes any divergence
local function rollbackCopyRecordsTheClockTest()

  local match, _, simulatedStack = createMatchWithSimulatedStack(ATTACK_SETTINGS)

  simulateSimulatedStackUntil(simulatedStack, 50)
  local copy = {}
  simulatedStack:saveIntoRollbackCopy(copy)
  assertEqual(copy.stackData.clock, 50)

  StackReplayTestingUtils:cleanup(match)
end

-- the attack engine writes its fields into the table it is handed, like every other component
local function attackEngineCopyIsNotNestedTest()

  local match, _, simulatedStack = createMatchWithSimulatedStack(ATTACK_SETTINGS)

  simulateSimulatedStackUntil(simulatedStack, 50)
  local copy = {}
  simulatedStack:saveIntoRollbackCopy(copy)
  assertEqual(copy.attackEngineData.stopWatch, simulatedStack.attackEngine.stopWatch)
  assert(copy.attackEngineData.attackEngineData == nil, "attack engine state was nested one key deeper than its name")

  StackReplayTestingUtils:cleanup(match)
end

-- lastRollbackFrame has to hold the frame the stack was on before the rollback so it knows to catch back up
local function rollbackRemembersTheFrameItCameFromTest()

  local match, _, simulatedStack = createMatchWithSimulatedStack(ATTACK_SETTINGS)

  simulateSimulatedStackUntil(simulatedStack, 300)
  assert(simulatedStack:rollbackRewindToFrame(250, false))
  assertEqual(simulatedStack.clock, 250)
  assertEqual(simulatedStack.lastRollbackFrame, 300)
  assert(simulatedStack:behindRollback(), "a rolled back stack has to report being behind its rollback")
  assert(simulatedStack:shouldRun(simulatedStack.max_runs_per_frame), "a rolled back stack has to run past its usual run limit to catch up")

  StackReplayTestingUtils:cleanup(match)
end

-- a rewind stays on the target frame, so there is nothing to catch up to
local function rewindDoesNotLeaveTheStackBehindTest()

  local match, _, simulatedStack = createMatchWithSimulatedStack(ATTACK_SETTINGS)

  simulateSimulatedStackUntil(simulatedStack, 300)
  assert(simulatedStack:rollbackRewindToFrame(250, true))
  assertEqual(simulatedStack.clock, 250)
  assertEqual(simulatedStack.lastRollbackFrame, 250)
  assert(not simulatedStack:behindRollback(), "a rewound stack must not report being behind its rollback")

  StackReplayTestingUtils:cleanup(match)
end

rollbackFromPastAnAttackIntoTheCountdownTest()
rollbackWithinTheCountdownTest()
rollbackCopyRecordsTheClockTest()
attackEngineCopyIsNotNestedTest()
rollbackRemembersTheFrameItCameFromTest()
rewindDoesNotLeaveTheStackBehindTest()
