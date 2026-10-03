local tableUtils = require("common.lib.tableUtils")
local StackReplayTestingUtils = require("common.tests.engine.StackReplayTestingUtils")
local logger = require("common.lib.logger")
local LevelPresets = require("common.data.LevelPresets")

local testReplayFolder = "common/tests/engine/replays/"

-- Vs rollback one player way behind
-- We need to make sure we remove garbage sent "in the future" so its not duplicated
local function rollbackPastAttackTest()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "v046-2023-01-28-02-39-32-JamBox-L10-vs-Galadic97-L10-Casual-P1wins.txt")
  local startClock = 462
  local aheadTime = 500
  local garbageTelegraphPopTime = 463
  local rollbackTime = garbageTelegraphPopTime
  StackReplayTestingUtils:simulateMatchUntil(match, startClock)
  local stack1 = match.stacks[1]
  local stack2 = match.stacks[2]
  ---@cast stack1 Stack
  ---@cast stack2 Stack
  StackReplayTestingUtils:simulateStack(stack1, aheadTime)

  -- Simulate to a point P1 has sent an attack to P2
  assert(#stack1.outgoingGarbage.garbageInTransit[335] == 1)

  -- Rollback P1 past the time the attack popped off the garbage queue
  match:debugRollbackAndCaptureState(rollbackTime)

  -- This should cause the attack to be undone
  assert(stack1.outgoingGarbage.garbageInTransit[335] == nil)

  -- Simulate again, attack should pop off again
  StackReplayTestingUtils:simulateMatchUntil(match, aheadTime)

  assert(stack1.outgoingGarbage.garbageInTransit[335] ~= nil and #stack1.outgoingGarbage.garbageInTransit[335] == 1)

  StackReplayTestingUtils:fullySimulateMatch(match)

  assert(match ~= nil)
  assert(match.garbageTargets[1][1] == match.stacks[2])
  assert(match.garbageTargets[2][1] == match.stacks[1])
  assert(match.panelSource.seed == 2992240)
  assert(stack1.game_over_clock == 2039)
  assert(stack1.levelData == LevelPresets.getModern(10))
  assert(tableUtils.count(stack1.outgoingGarbage.history, function(g) return g.isChain end) == 4)
  assert(tableUtils.count(stack1.outgoingGarbage.history, function(g) return not g.isChain end) == 4)
  assert(stack2.game_over_clock <= 0)
  assert(stack2.levelData == LevelPresets.getModern(10))
  assert(tableUtils.count(stack2.outgoingGarbage.history, function(g) return g.isChain end) == 4)
  assert(tableUtils.count(stack2.outgoingGarbage.history, function(g) return not g.isChain end) == 4)
  StackReplayTestingUtils:cleanup(match)
end

-- Vs rollback just one frame on both stacks
-- We need to make sure we don't remove garbage if we didn't rollback far enough to mess with it.
local function rollbackNotPastAttackTest()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "v046-2023-01-28-02-39-32-JamBox-L10-vs-Galadic97-L10-Casual-P1wins.txt")
  local startClock = 462
  local aheadTime = 500
  local garbageTelegraphPopTime = 463
  local rollbackTime = garbageTelegraphPopTime + 1
  StackReplayTestingUtils:simulateMatchUntil(match, startClock)
  local stack1 = match.stacks[1]
  local stack2 = match.stacks[2]
  ---@cast stack1 Stack
  ---@cast stack2 Stack
  StackReplayTestingUtils:simulateStack(stack1, aheadTime)

  -- Simulate to a point P1 has sent an attack to P2
  assert(#stack1.outgoingGarbage.garbageInTransit[335] == 1)

  -- Rollback P1 but not past the time the attack popped off the garbage queue
  match:debugRollbackAndCaptureState(rollbackTime)
  assert(stack1.outgoingGarbage.garbageInTransit[335] ~= nil and #stack1.outgoingGarbage.garbageInTransit[335] == 1)

  -- Simulate again, attack shouldn't pop off again
  StackReplayTestingUtils:simulateMatchUntil(match, aheadTime)

  assert(stack1.outgoingGarbage.garbageInTransit[335] ~= nil and #stack1.outgoingGarbage.garbageInTransit[335] == 1)

  StackReplayTestingUtils:fullySimulateMatch(match)

  assert(match ~= nil)
  assert(match.garbageTargets[1][1] == match.stacks[2])
  assert(match.garbageTargets[2][1] == match.stacks[1])
  assert(match.panelSource.seed == 2992240)
  assert(stack1.game_over_clock == 2039)
  assert(stack1.levelData == LevelPresets.getModern(10))
  assert(tableUtils.count(stack1.outgoingGarbage.history, function(g) return g.isChain end) == 4)
  assert(tableUtils.count(stack1.outgoingGarbage.history, function(g) return not g.isChain end) == 4)
  assert(stack2.game_over_clock <= 0)
  assert(stack2.levelData == LevelPresets.getModern(10))
  assert(tableUtils.count(stack2.outgoingGarbage.history, function(g) return g.isChain end) == 4)
  assert(tableUtils.count(stack2.outgoingGarbage.history, function(g) return not g.isChain end) == 4)
  StackReplayTestingUtils:cleanup(match)
end

-- Vs rollback before attack even happened
-- Make sure the attack only happens once and only once if we rollback before it happened
local function rollbackFullyPastAttack()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "v046-2023-02-01-05-38-16-vsSelf-L8.txt")
  local stack = match.stacks[1]
  ---@cast stack Stack
  local outgoingGarbage = stack.outgoingGarbage

  StackReplayTestingUtils:simulateMatchUntil(match, 360)
  -- combo got queued
  assert(not outgoingGarbage.stagedGarbage[1].isChain and outgoingGarbage.stagedGarbage[1].width == 3
      and outgoingGarbage.stagedGarbage[1].frameEarned == 156)

  match:debugRollbackAndCaptureState(344)
  -- combo disappeared after rollback (344 means frame 343 has just completed and 344 has yet to run; combo is earned on 344 so shouldn't be in yet)
  assert(outgoingGarbage.stagedGarbage[1] == nil)

  StackReplayTestingUtils:simulateMatchUntil(match, 480)

  -- first chain link is queued
  assert(outgoingGarbage.stagedGarbage[2] ~= nil and outgoingGarbage.stagedGarbage[2].isChain
     and outgoingGarbage.stagedGarbage[2].frameEarned == 240 and outgoingGarbage.stagedGarbage[2].height == 1)
  -- combo is queued
  assert(not outgoingGarbage.stagedGarbage[1].isChain and outgoingGarbage.stagedGarbage[1].width == 3
      and outgoingGarbage.stagedGarbage[1].frameEarned == 156)

  match:debugRollbackAndCaptureState(420)
  -- first chain link got removed by rollback (only earned 8 frames later)
  assert(outgoingGarbage.stagedGarbage[2] == nil)
  -- combo is still queued
  assert(not outgoingGarbage.stagedGarbage[1].isChain and outgoingGarbage.stagedGarbage[1].width == 3
      and outgoingGarbage.stagedGarbage[1].frameEarned == 156)

  StackReplayTestingUtils:simulateMatchUntil(match, 480)
  -- first chain link is queued
  assert(outgoingGarbage.stagedGarbage[2] ~= nil and outgoingGarbage.stagedGarbage[2].isChain
     and outgoingGarbage.stagedGarbage[2].frameEarned == 240 and outgoingGarbage.stagedGarbage[2].height == 1)
  -- combo is queued
  assert(not outgoingGarbage.stagedGarbage[1].isChain and outgoingGarbage.stagedGarbage[1].width == 3
      and outgoingGarbage.stagedGarbage[1].frameEarned == 156)
      -- no other garbage in here either
  assert(#outgoingGarbage.stagedGarbage == 2)

  StackReplayTestingUtils:simulateMatchUntil(match, 637)
  local chainGarbage = outgoingGarbage.stagedGarbage[2]
  ---@cast chainGarbage ChainGarbage
  assert(chainGarbage ~= nil)
  assert(chainGarbage.height == 3)
  assert(chainGarbage.linkTimes[1] == 240)
  assert(chainGarbage.linkTimes[2] == 311)
  assert(chainGarbage.linkTimes[3] == 383)
  assert(chainGarbage.finalizedClock == 448)

  match:debugRollbackAndCaptureState(570)
  chainGarbage = outgoingGarbage.stagedGarbage[2]
  ---@cast chainGarbage ChainGarbage
  assert(chainGarbage ~= nil)
  assert(chainGarbage.height == 2)
  assert(chainGarbage.linkTimes[1] == 240)
  assert(chainGarbage.linkTimes[2] == 311)
  assert(chainGarbage.linkTimes[3] == nil)
  assert(chainGarbage.finalizedClock == nil)

  StackReplayTestingUtils:fullySimulateMatch(match)
  local t = outgoingGarbage.garbageInTransit[534]
  assert(t[1] ~= nil)
  assert(t[1].isChain)
  ---@cast t ChainGarbage
  assert(t[1].height == 3)
  assert(t[1].linkTimes[1] == 240)
  assert(t[1].linkTimes[2] == 311)
  assert(t[1].linkTimes[3] == 383)
  assert(t[1].finalizedClock == 448)
  assert(not t[2].isChain and t[2].width == 3 and t[2].frameEarned == 156)
  assert(match ~= nil)
  assert(match.garbageTargets[1][1] == match.stacks[1])
  assert(match.panelSource.seed == 3917661)
  assert(stack.game_over_clock == 797)
  assert(stack.levelData == LevelPresets.getModern(8))
  assert(tableUtils.count(stack.outgoingGarbage.history, function(g) return g.isChain end) == 1)
  assert(tableUtils.count(stack.outgoingGarbage.history, function(g) return not g.isChain end) == 1)
  StackReplayTestingUtils:cleanup(match)
end

local function rollbackFromDeath()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "rollbackFromDeath.json")
  local stack = match.stacks[1]
  StackReplayTestingUtils:fullySimulateMatch(match)
  assert(stack.game_over_clock == 652)

  match:rewindToFrame(613)
  assert(stack.outgoingGarbage.garbageInTransit[443], "expected +4 in transit")
  StackReplayTestingUtils:fullySimulateMatch(match)
  assert(stack.game_over_clock == 652)

  match:rewindToFrame(481)
  assert(stack.outgoingGarbage.stagedGarbage[1].frameEarned == 292, "expected +4 queued")
  StackReplayTestingUtils:fullySimulateMatch(match)
  assert(stack.game_over_clock == 652)
end

local function liveDesync()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "v046-2023-01-28-02-39-32-JamBox-L10-vs-Galadic97-L10-Casual-P1wins.txt")
  match.debug.vsFramesBehind = 120

  StackReplayTestingUtils:fullySimulateMatch(match)

  assert(match.ended and not match.aborted)
  assert(not match:isIrrecoverablyDesynced())
  assert(match.stacks[1].rollbackCount == 5)
  assert(match.gameOverClock == 2039)
end

-- rolling back to the same frame twice has to restore identical stack and garbage queue state
-- because the rollback buffer keeps the copy it hands out so it can be rolled back to again
local function testRollbackDeterminism()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "v046-2023-01-28-02-39-32-JamBox-L10-vs-Galadic97-L10-Casual-P1wins.txt")
  local startClock = 462
  local aheadTime = 500
  local rollbackTarget = 463
  local captureTime = 485

  StackReplayTestingUtils:simulateMatchUntil(match, startClock)
  local stack1 = match.stacks[1]
  ---@cast stack1 Stack
  local outgoingGarbage = stack1.outgoingGarbage

  local function captureState()
    local state = {
      clock = stack1.clock,
      garbageDropIndexes = {},
      stagedCount = #outgoingGarbage.stagedGarbage,
      stagedGarbage = {},
      hasCurrentChain = outgoingGarbage.currentChain ~= nil,
      historyCount = #outgoingGarbage.history,
    }
    for i = 1, #stack1.currentGarbageDropColumnIndexes do
      state.garbageDropIndexes[i] = stack1.currentGarbageDropColumnIndexes[i]
    end
    for i = 1, #outgoingGarbage.stagedGarbage do
      state.stagedGarbage[i] = outgoingGarbage.stagedGarbage[i]
    end
    return state
  end

  StackReplayTestingUtils:simulateStack(stack1, aheadTime)
  match:debugRollbackAndCaptureState(rollbackTarget)
  local state1 = captureState()

  -- simulating past the target again overwrites everything after it in the buffer, but not the copy for the target itself
  StackReplayTestingUtils:simulateStack(stack1, captureTime)
  match:debugRollbackAndCaptureState(rollbackTarget)
  local state2 = captureState()

  assertEqual(state1.clock, state2.clock)

  for i = 1, math.max(#state1.garbageDropIndexes, #state2.garbageDropIndexes) do
    assert(state1.garbageDropIndexes[i] == state2.garbageDropIndexes[i],
           "garbageDropIndexes[" .. i .. "] differed between rollbacks: "
           .. tostring(state1.garbageDropIndexes[i]) .. " then " .. tostring(state2.garbageDropIndexes[i]))
  end

  assertEqual(state1.stagedCount, state2.stagedCount)
  for i = 1, state1.stagedCount do
    assertEqual(state1.stagedGarbage[i].frameEarned, state2.stagedGarbage[i].frameEarned)
  end

  assert(state1.hasCurrentChain == state2.hasCurrentChain, "currentChain existence differed between rollbacks")
  assertEqual(state1.historyCount, state2.historyCount)

  StackReplayTestingUtils:cleanup(match)
end

logger.info("running rollbackFromDeath")
rollbackFromDeath()

local function testRewindTransitDataPreservation()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "rollbackFromDeath.json")
  local stack = match.stacks[1]
  StackReplayTestingUtils:fullySimulateMatch(match)
  assert(stack.game_over_clock == 652)

  -- Rewind to frame 613 where garbage is in transit
  match:rewindToFrame(613)
  local transitGarbage = stack.outgoingGarbage.garbageInTransit[443]
  assert(transitGarbage, "expected garbage in transit at frame 443")
  -- snapshot by value: the rewind hands back the same table so comparing against it could never fail
  local transitSizes = {}
  for i = 1, #transitGarbage do
    transitSizes[i] = {width = transitGarbage[i].width, height = transitGarbage[i].height}
  end
  local transitTimersLen1 = stack.outgoingGarbage.transitTimers:len()
  assert(transitTimersLen1 > 0, "expected transit timers to have entries")

  -- Simulate forward so the garbage changes
  StackReplayTestingUtils:simulateMatchUntil(match, 652)

  -- Rewind to the SAME frame again - this should restore identical data
  match:rewindToFrame(613)
  local transitGarbage2 = stack.outgoingGarbage.garbageInTransit[443]
  assert(transitGarbage2, "expected garbage in transit at frame 443 after second rewind")
  assertEqual(#transitGarbage2, #transitSizes)
  for i = 1, #transitSizes do
    assertEqual(transitGarbage2[i].width, transitSizes[i].width)
    assertEqual(transitGarbage2[i].height, transitSizes[i].height)
  end
  local transitTimersLen2 = stack.outgoingGarbage.transitTimers:len()
  assert(transitTimersLen2 == transitTimersLen1, "transit timers length should match after rewind")

  StackReplayTestingUtils:cleanup(match)
end

logger.info("running rollbackPastAttackTest")
rollbackPastAttackTest()

logger.info("running rollbackNotPastAttackTest")
rollbackNotPastAttackTest()

logger.info("running rollbackFullyPastAttack")
rollbackFullyPastAttack()

logger.info("running liveDesync1")
liveDesync()

testRollbackDeterminism()

testRewindTransitDataPreservation()

-- prev_shake_time is display only, but both of its consumers compare it to a number - the shake
-- offset interpolation and the garbage thud SFX - so a rollback that leaves it nil crashes the
-- client on the next draw rather than merely looking wrong. The stack's own fields live under
-- stackData in a rollback copy, and the frame wanted here is the one before the frame being
-- restored to, which is not the slot rollbackToFrame leaves the buffer pointing at.
local function testRollbackRestoresPreviousShakeTime()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "v046-2023-01-28-02-39-32-JamBox-L10-vs-Galadic97-L10-Casual-P1wins.txt")
  -- the replay's first stretch of shake, so the interpolation runs against a non zero value
  local rollbackFrame = 560

  StackReplayTestingUtils:simulateMatchUntil(match, rollbackFrame - 1)
  local stack1 = match.stacks[1]
  ---@cast stack1 Stack
  local shakeTimeOnPreviousFrame = stack1.shake_time
  assert(shakeTimeOnPreviousFrame > 0, "picked a frame the stack is not shaking on")

  StackReplayTestingUtils:simulateMatchUntil(match, rollbackFrame + 20)
  assert(stack1:rollbackRewindToFrame(rollbackFrame, false))

  assert(type(stack1.prev_shake_time) == "number",
         "prev_shake_time was " .. tostring(stack1.prev_shake_time) .. " after a rollback")
  assertEqual(stack1.prev_shake_time, shakeTimeOnPreviousFrame)

  StackReplayTestingUtils:cleanup(match)
end

testRollbackRestoresPreviousShakeTime()

-- deinit hands the panel tables in the rollback buffer back to the shared pool the save path
-- allocates from. Those are the biggest allocations a stack makes - one table per panel per stored
-- frame - so a deinit that walks the buffer and does nothing with what it finds means every match
-- played in a session allocates its panel storage from scratch.
local function testDeinitReturnsPanelStorageToThePool()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "v046-2023-01-28-02-39-32-JamBox-L10-vs-Galadic97-L10-Casual-P1wins.txt")
  StackReplayTestingUtils:simulateMatchUntil(match, 300)
  local stack1 = match.stacks[1]
  ---@cast stack1 Stack

  local storedWithPanels = 0
  for i = 1, stack1.rollbackBuffer.size do
    local copy = stack1.rollbackBuffer.buffer[i]
    if copy and copy.stackData and #copy.stackData.panels > 0 then
      storedWithPanels = storedWithPanels + 1
    end
  end
  assert(storedWithPanels > 0, "the buffer held no panel data to hand back")

  stack1:deinit()

  for i = 1, stack1.rollbackBuffer.size do
    local copy = stack1.rollbackBuffer.buffer[i]
    if copy and copy.stackData then
      assertEqual(#copy.stackData.panels, 0)
    end
  end

  StackReplayTestingUtils:cleanup(match)
end

testDeinitReturnsPanelStorageToThePool()


-- scrubbing back and forth in the replay viewer rewinds to a frame and then plays it again
-- so the copy a rewind hands out has to stay usable for the next rewind to the same stretch
local function testRepeatedRewindAndPlayback()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "v046-2023-01-28-02-39-32-JamBox-L10-vs-Galadic97-L10-Casual-P1wins.txt")
  StackReplayTestingUtils:simulateMatchUntil(match, 600)

  for cycle = 1, 20 do
    for i = 1, 5 do
      local clockBeforeRewind = match.clock
      match:rewindToFrame(match.clock - 1)
      assert(match.clock == clockBeforeRewind - 1,
             "Rewind number " .. i .. " of cycle " .. cycle .. " did not move the clock from " .. clockBeforeRewind)
    end

    for i = 1, 5 do
      match:run()
    end
  end

  assert(match.clock == 600, "Expected to be back at frame 600 but was at " .. match.clock)

  StackReplayTestingUtils:cleanup(match)
end

testRepeatedRewindAndPlayback()

-- the divergence check only ever passes in the other tests, so a comparison that always said
-- "equal" would go unnoticed. Tamper with the board after the rollback and expect it to be caught
-- the moment the stack catches back up to the frame the copy was taken on.
local function testDivergenceCheckCatchesATamperedBoard()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "v046-2023-01-28-02-39-32-JamBox-L10-vs-Galadic97-L10-Casual-P1wins.txt")
  local captureFrame = 500
  StackReplayTestingUtils:simulateMatchUntil(match, captureFrame)
  local stack1 = match.stacks[1]
  ---@cast stack1 Stack

  match:debugRollbackAndCaptureState(captureFrame - 20)
  local panel = stack1.panels[1][1]
  panel.color = panel.color == 1 and 2 or 1

  local ok, err = pcall(StackReplayTestingUtils.simulateMatchUntil, StackReplayTestingUtils, match, captureFrame)
  assert(not ok, "the tampered stack caught up without the divergence check noticing")
  assert(tostring(err):find("P1 has diverged after rollback", 1, true),
         "expected a divergence error but got: " .. tostring(err))

  StackReplayTestingUtils:cleanup(match)
end

testDivergenceCheckCatchesATamperedBoard()

-- the pool is shared by every stack and the save path only overwrites the keys the live panel has,
-- so a table that still carries a previous panel's garbage fields would stamp them onto an ordinary
-- panel of the next match the moment it gets restored
local function testDeinitClearsPanelStorageBeforePoolingIt()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "v046-2023-01-28-02-39-32-JamBox-L10-vs-Galadic97-L10-Casual-P1wins.txt")
  StackReplayTestingUtils:simulateMatchUntil(match, 300)
  local stack1 = match.stacks[1]
  ---@cast stack1 Stack

  local pooledPanel
  for i = 1, stack1.rollbackBuffer.size do
    local copy = stack1.rollbackBuffer.buffer[i]
    if copy and copy.stackData and copy.stackData.panels[1] then
      pooledPanel = copy.stackData.panels[1]
      break
    end
  end
  assert(pooledPanel, "the buffer held no panel data to hand back")
  assert(next(pooledPanel), "the panel copy was already empty so the test proves nothing")

  stack1:deinit()

  assert(next(pooledPanel) == nil, "panel tables handed back to the shared pool must be cleared first")

  StackReplayTestingUtils:cleanup(match)
end

testDeinitClearsPanelStorageBeforePoolingIt()

-- the divergence check captures state on frames the stack would not otherwise have saved on, so a
-- capture that trimmed the board would change the stack purely because the check is enabled
local function testCapturingStateDoesNotMutateTheStack()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "v046-2023-01-28-02-39-32-JamBox-L10-vs-Galadic97-L10-Casual-P1wins.txt")
  StackReplayTestingUtils:simulateMatchUntil(match, 300)
  local stack1 = match.stacks[1]
  ---@cast stack1 Stack

  local extraRow = #stack1.panels + 1
  stack1.panels[extraRow] = {}
  for col = 1, stack1.width do
    stack1.panels[extraRow][col] = stack1.panelTemplate(extraRow, col)
  end

  stack1:saveIntoRollbackCopy({})

  assert(stack1.panels[extraRow], "capturing state trimmed a row off the live stack")

  StackReplayTestingUtils:cleanup(match)
end

testCapturingStateDoesNotMutateTheStack()

-- a stack that is already at the rollback target does not roll back, so its clock runs straight past
-- the captured one and the check could never consume the copy - capturing it would pin a full stack
-- copy, and its share of the panel pool, for the rest of the match
local function testDebugCaptureSkipsAStackThatDoesNotRollBack()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "v046-2023-01-28-02-39-32-JamBox-L10-vs-Galadic97-L10-Casual-P1wins.txt")
  local clockGoal = 480
  StackReplayTestingUtils:simulateMatchUntil(match, 500)
  local stack2 = match.stacks[2]
  ---@cast stack2 Stack

  assert(stack2:rollbackRewindToFrame(clockGoal, false), "could not put P2 on the rollback target")
  match:debugRollbackAndCaptureState(clockGoal)

  assert(match.savedStackP1, "P1 rolled back so its state has to be checked")
  assert(match.savedStackP2 == nil, "P2 did not roll back so its state must not be captured")

  StackReplayTestingUtils:cleanup(match)
end

testDebugCaptureSkipsAStackThatDoesNotRollBack()
