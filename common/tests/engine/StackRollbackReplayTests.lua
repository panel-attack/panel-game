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

logger.info("running rollbackFromDeath")
rollbackFromDeath()

logger.info("running rollbackPastAttackTest")
rollbackPastAttackTest()

logger.info("running rollbackNotPastAttackTest")
rollbackNotPastAttackTest()

logger.info("running rollbackFullyPastAttack")
rollbackFullyPastAttack()