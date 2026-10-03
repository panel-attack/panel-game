local StackReplayTestingUtils = require("common.tests.engine.StackReplayTestingUtils")
local Player = require("client.src.Player")
local GameModes = require("common.data.GameModes")
local LevelPresets = require("common.data.LevelPresets")
local Match = require("common.engine.Match")
local GeneratorSource = require("common.engine.GeneratorSource")

local function createAnalyticsMatch(inputCount)
  local endless = GameModes.getPreset("ONE_PLAYER_ENDLESS")
  local match = Match(GeneratorSource(1, false), endless.matchRules)
  local engineStack = match:createStackWithSettings(LevelPresets.getModern(10), false, "controller")

  local player = Player.createLocalPlayerFromConfig()
  player.isLocal = false
  local playerStack = player:createClientStack(engineStack)

  match:setAlwaysSaveRollbacks(true)
  match:start()
  engineStack:setMaxRunsPerFrame(1)
  engineStack:receiveConfirmedInput(string.rep(engineStack:idleInput(), inputCount))

  return match, engineStack, playerStack, playerStack.analytic
end

local function testRewindToFrame()
  local match, _, playerStack, analytic = createAnalyticsMatch(200)
  StackReplayTestingUtils:simulateMatchUntil(match, 119)

  -- Manually set analytics and save at frame 120
  analytic.data.move_count = 100
  match:run() -- Run to frame 120, which will save rollback

  StackReplayTestingUtils:simulateMatchUntil(match, 179)
  analytic.data.move_count = 150
  match:run() -- Run to frame 180, which will save rollback

  playerStack:rewindToFrame(120)

  assert(playerStack.engine.clock == 120, "engine should be at frame 120")
  assert(analytic.data.move_count == 100, "analytics should be rewound to frame 120")
end

local function testMultipleRollbacksToSameFrame()
  local match, engineStack, _, analytic = createAnalyticsMatch(300)
  StackReplayTestingUtils:simulateMatchUntil(match, 119)

  -- Manually set analytics and save at frame 120
  analytic.data.swap_count = 50
  analytic.data.move_count = 100
  analytic.data.destroyed_panels = 30
  match:run() -- Run to frame 120, which will save rollback

  -- Simulate forward and change analytics
  analytic.data.swap_count = 75
  analytic.data.move_count = 150
  analytic.data.destroyed_panels = 45
  StackReplayTestingUtils:simulateMatchUntil(match, 180)

  -- First rollback to frame 120
  engineStack:rollbackRewindToFrame(120, false)
  assert(analytic.data.swap_count == 50, "swap_count should be rolled back to 50 (first rollback)")
  assert(analytic.data.move_count == 100, "move_count should be rolled back to 100 (first rollback)")
  assert(analytic.data.destroyed_panels == 30, "destroyed_panels should be rolled back to 30 (first rollback)")

  -- Simulate forward again and change analytics
  analytic.data.swap_count = 90
  analytic.data.move_count = 200
  analytic.data.destroyed_panels = 60
  StackReplayTestingUtils:simulateMatchUntil(match, 200)

  -- Second rollback to the SAME frame 120
  engineStack:rollbackRewindToFrame(120, false)
  assert(analytic.data.swap_count == 50, "swap_count should be rolled back to 50 (second rollback)")
  assert(analytic.data.move_count == 100, "move_count should be rolled back to 100 (second rollback)")
  assert(analytic.data.destroyed_panels == 30, "destroyed_panels should be rolled back to 30 (second rollback)")
end

-- analytics has to be told which of the two it is for the same reason the engine does: a rewind
-- stays on the frame it restored while a rollback runs back up to where it came from
local function testRewindIsForwardedToAnalyticsAsARewind()
  local match, engineStack, playerStack, analytic = createAnalyticsMatch(300)
  StackReplayTestingUtils:simulateMatchUntil(match, 180)

  local rewindFlags = {}
  local originalRollbackRewindToFrame = analytic.rollbackRewindToFrame
  analytic.rollbackRewindToFrame = function(self, clock, isRewind)
    rewindFlags[#rewindFlags + 1] = isRewind
    return originalRollbackRewindToFrame(self, clock, isRewind)
  end

  playerStack:rewindToFrame(120)
  assert(rewindFlags[1] == true, "a rewind has to reach analytics as a rewind")

  engineStack:rollbackRewindToFrame(60, false)
  assert(rewindFlags[2] == false, "a rollback has to reach analytics as a rollback")
end

testRewindToFrame()
testMultipleRollbacksToSameFrame()
testRewindIsForwardedToAnalyticsAsARewind()
