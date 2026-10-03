local Health = require("common.engine.Health")
require("common.lib.mathExtensions")

local function testHealthDamageBaseCase()
  local secondsToppedOutToLose = 10
  local lineClearGPM = 0
  local lineHeightToKill = 6
  local riseLevel = 10
  local health = Health(secondsToppedOutToLose, lineClearGPM, lineHeightToKill, riseLevel)

  assert(health ~= nil)
  assertEqual(health:damageForHeight(1), 1)
  assertEqual(health:damageForHeight(2), 2)
  assertEqual(health:damageForHeight(3), 3)
  assertEqual(health:damageForHeight(4), 4)
  assertEqual(health:damageForHeight(5), 5)
end

testHealthDamageBaseCase()

local function testHealthDamageReducedForBigChains()
  local secondsToppedOutToLose = 10
  local lineClearGPM = 0
  local lineHeightToKill = 6
  local riseLevel = 10
  local health = Health(secondsToppedOutToLose, lineClearGPM, lineHeightToKill, riseLevel)

  assert(health ~= nil)
  assert(math.floatsEqualWithPrecision(health:damageForHeight(6), 5.8, 10))
  assert(math.floatsEqualWithPrecision(health:damageForHeight(7), 6.4, 10))
  assert(math.floatsEqualWithPrecision(health:damageForHeight(8), 6.8, 10))
  assert(math.floatsEqualWithPrecision(health:damageForHeight(9), 7, 10))
  assert(math.floatsEqualWithPrecision(health:damageForHeight(10), 7, 10))
  assert(math.floatsEqualWithPrecision(health:damageForHeight(13), 7, 10))
end

testHealthDamageReducedForBigChains()
-- A rollback puts the health engine back on the frame it was rolled back to, clock included.
-- run reads clock for the rise speed step and the stamina curve and then increments it itself, so a
-- clock left where the rollback found it makes the engine score the same frame differently the
-- second time it is simulated - a divergence between two clients that never resolves.
local function testRollbackRestoresTheClockWithTheRestOfIt()
  local health = Health(10, 0, 6, 1)
  for _ = 1, 900 do
    health:run()
  end

  local copy = {}
  health:saveIntoRollbackCopy(copy)
  local savedClock = health.clock

  for _ = 1, 5 do
    health:run()
  end
  health:restoreFromRollbackCopy(copy, savedClock, false)

  assertEqual(health.clock, savedClock)
end

testRollbackRestoresTheClockWithTheRestOfIt()

-- And the point of restoring it: the frames after a rollback have to be simulated identically to
-- the frames before one. The rise speed steps every 15 seconds off clock, so an engine that kept a
-- clock five frames ahead steps at the wrong frame and never catches up.
local function testResimulatedFramesMatchAnUninterruptedRun()
  local rolledBack = Health(10, 0, 6, 1)
  for _ = 1, 900 do
    rolledBack:run()
  end

  local copy = {}
  rolledBack:saveIntoRollbackCopy(copy)
  local savedClock = rolledBack.clock
  for _ = 1, 5 do
    rolledBack:run()
  end
  rolledBack:restoreFromRollbackCopy(copy, savedClock, false)

  local uninterrupted = Health(10, 0, 6, 1)
  for _ = 1, 900 do
    uninterrupted:run()
  end

  for _ = 1, 5 do
    rolledBack:run()
    uninterrupted:run()
    assertEqual(rolledBack.currentRiseSpeed, uninterrupted.currentRiseSpeed)
    assert(math.floatsEqualWithPrecision(rolledBack.currentLines, uninterrupted.currentLines, 10))
    assertEqual(rolledBack.framesToppedOutToLose, uninterrupted.framesToppedOutToLose)
  end
end

testResimulatedFramesMatchAnUninterruptedRun()
