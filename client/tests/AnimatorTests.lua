local Animator = require("client.src.graphics.Animator")
local logger = require("common.lib.logger")

local function assertApproxEqual(actual, expected, message)
  if math.abs(actual - expected) > 0.0001 then
    error(string.format("%s: expected %f, got %f", message, expected, actual))
  end
end

local function testUpdatingMovesATrackAlong()
  local animator = Animator()
  local target = {value = 0}
  animator:to(target, 1, {value = 1}):ease("linear")

  animator:update(0.25)

  assertApproxEqual(target.value, 0.25, "a quarter of the track should have run")
  logger.trace("passed test testUpdatingMovesATrackAlong")
end

local function testAdvanceRunsOneTrack()
  local animator = Animator()
  local advanced = {value = 0}
  local other = {value = 0}
  local track = animator:to(advanced, 1, {value = 1}):ease("linear")
  animator:to(other, 1, {value = 1}):ease("linear")

  animator:advance(track, 0.5)

  assertApproxEqual(advanced.value, 0.5, "the advanced track should be half way")
  assertApproxEqual(other.value, 0, "the other track should not have moved")
  logger.trace("passed test testAdvanceRunsOneTrack")
end

local function testStopEndsEveryTrackOnTheTarget()
  local animator = Animator()
  local target = {x = 0, y = 0}
  animator:to(target, 1, {x = 1}):ease("linear")
  animator:to(target, 1, {y = 1}):ease("linear"):delay(0.5)

  animator:stop(target)
  animator:update(1)

  assert(target.x == 0 and target.y == 0, "a stopped target should not move")
  logger.trace("passed test testStopEndsEveryTrackOnTheTarget")
end

local function testStopKeepsOtherTargetsRunning()
  local animator = Animator()
  local stopped = {value = 0}
  local running = {value = 0}
  animator:to(stopped, 1, {value = 1}):ease("linear")
  animator:to(running, 1, {value = 1}):ease("linear")

  animator:stop(stopped)
  animator:update(0.5)

  assertApproxEqual(running.value, 0.5, "the other target's track should keep running")
  logger.trace("passed test testStopKeepsOtherTargetsRunning")
end

local function testStopEndsAChainedTrackBeforeItStarts()
  local animator = Animator()
  local target = {value = 0}
  animator:to(target, 1, {value = 1}):ease("linear"):after(1, {value = 2}):ease("linear")

  animator:stop(target)
  animator:update(2)

  assert(target.value == 0, "neither the track nor the one after it should run")
  logger.trace("passed test testStopEndsAChainedTrackBeforeItStarts")
end

testUpdatingMovesATrackAlong()
testAdvanceRunsOneTrack()
testStopEndsEveryTrackOnTheTarget()
testStopKeepsOtherTargetsRunning()
testStopEndsAChainedTrackBeforeItStarts()
