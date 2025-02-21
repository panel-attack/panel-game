local consts = require("common.engine.consts")
local StackReplayTestingUtils = require("common.tests.engine.StackReplayTestingUtils")
local GameModes = require("common.engine.GameModes")
local Puzzle = require("common.engine.Puzzle")
local LevelPresets = require("common.data.LevelPresets")

local function puzzleTest()
  -- to stop rising
  local match = StackReplayTestingUtils.createSinglePlayerMatch(GameModes.getPreset("ONE_PLAYER_PUZZLE"))
  local puzzle = Puzzle(nil, nil, 1, "011010")
  local stack = match.stacks[1]
  stack:setPuzzleState(puzzle)

  assert(stack.panels[1][1].color == 0, "wrong color")
  assert(stack.panels[1][2].color == 1, "wrong color")

  stack:receiveConfirmedInput("AA") -- can't swap on first two frames ?!
  match:run()
  match:run()
  local leftPanel = stack.panels[1][4]
  local rightPanel = stack.panels[1][5]
  assert(stack:canSwap(leftPanel, rightPanel), "should be able to swap")
  StackReplayTestingUtils:cleanup(match)
end

puzzleTest()

local function clearPuzzleTest()
  local match = StackReplayTestingUtils.createSinglePlayerMatch(GameModes.getPreset("ONE_PLAYER_PUZZLE"))
  local puzzle = Puzzle("clear", false, 0, "[============================][====]246260[====]600016514213466313451511124242", 60, 0)
  local stack = match.stacks[1]
  stack:setPuzzleState(puzzle)

  assert(stack.panels[1][1].color == 1, "wrong color")
  assert(stack.panels[1][2].color == 2, "wrong color")

  stack:receiveConfirmedInput("AA") -- can't swap on first two frames ?!
  match:run()
  match:run()
  local leftPanel = stack.panels[1][4]
  local rightPanel = stack.panels[1][5]
  assert(stack:canSwap(leftPanel, rightPanel), "should be able to swap")
  StackReplayTestingUtils:cleanup(match)
end

clearPuzzleTest()

local function basicSwapTest()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10)
  local stack = match.stacks[1]

  stack.do_countdown = false

  stack:receiveConfirmedInput("AA") -- can't swap on first two frames
  StackReplayTestingUtils:simulateMatchUntil(match, 2)

  local leftPanel = stack.panels[1][1]
  local rightPanel = stack.panels[1][2]
  assert(stack:canSwap(leftPanel, rightPanel), "should be able to swap")
  stack:setQueuedSwapPosition(1, 1)
  assert(stack.queuedSwapRow == 1)
  stack:new_row()
  assert(stack.queuedSwapRow == 2)
  StackReplayTestingUtils:cleanup(match)
end

basicSwapTest()

local function moveAfterCountdownV46Test()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10)
  match:setEngineVersion(consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE)
  local stack = match.stacks[1]
  stack.do_countdown = true
  assert(characters ~= nil, "no characters")
  local lastBlockedCursorMovementFrame = 33
  stack:receiveConfirmedInput(string.rep(stack:idleInput(), lastBlockedCursorMovementFrame + 1))

  StackReplayTestingUtils:simulateMatchUntil(match, lastBlockedCursorMovementFrame)
  assert(stack.cursorLock ~= nil, "Cursor should be locked up to last frame of countdown")

  StackReplayTestingUtils:simulateMatchUntil(match, lastBlockedCursorMovementFrame + 1)
  assert(stack.cursorLock == nil, "Cursor should not be locked after countdown")
  StackReplayTestingUtils:cleanup(match)
end

moveAfterCountdownV46Test()

local function testShakeFrames()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10)
  match.seed = 1 -- so we consistently have a panel to swap
  match.engineVersion = consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE
  local stack = match.stacks[1]

  -- imaginary garbage should crash
  assert(pcall(stack.shakeFrameForGarbageSize, 6, 0) == false)
  assert(pcall(stack.shakeFrameForGarbageSize, 6, -1) == false)

  assert(stack:shakeFramesForGarbageSize(1, 1) == 18)
  assert(stack:shakeFramesForGarbageSize(2, 1) == 18)
  assert(stack:shakeFramesForGarbageSize(1, 2) == 18)
  assert(stack:shakeFramesForGarbageSize(3, 1) == 18)
  assert(stack:shakeFramesForGarbageSize(4, 1) == 18)
  assert(stack:shakeFramesForGarbageSize(2, 2) == 18)
  assert(stack:shakeFramesForGarbageSize(5, 1) == 24)
  assert(stack:shakeFramesForGarbageSize(6, 1) == 42)
  assert(stack:shakeFramesForGarbageSize(3, 2) == 42)
  assert(stack:shakeFramesForGarbageSize(7, 1) == 42)
  assert(stack:shakeFramesForGarbageSize(4, 2) == 42)
  assert(stack:shakeFramesForGarbageSize(3, 3) == 42)
  assert(stack:shakeFramesForGarbageSize(5, 2) == 42)
  assert(stack:shakeFramesForGarbageSize(11, 1) == 42)
  assert(stack:shakeFramesForGarbageSize(6, 2) == 66)
  assert(stack:shakeFramesForGarbageSize(13, 1) == 66)
  assert(stack:shakeFramesForGarbageSize(7, 2) == 66)
  assert(stack:shakeFramesForGarbageSize(5, 3) == 66)
  assert(stack:shakeFramesForGarbageSize(4, 4) == 66)
  assert(stack:shakeFramesForGarbageSize(17, 1) == 66)
  assert(stack:shakeFramesForGarbageSize(6, 3) == 66)
  assert(stack:shakeFramesForGarbageSize(19, 1) == 66)
  assert(stack:shakeFramesForGarbageSize(5, 4) == 66)
  assert(stack:shakeFramesForGarbageSize(7, 3) == 66)
  assert(stack:shakeFramesForGarbageSize(11, 2) == 66)
  assert(stack:shakeFramesForGarbageSize(23, 1) == 66)
  assert(stack:shakeFramesForGarbageSize(6, 4) == 76)
  assert(stack:shakeFramesForGarbageSize(5, 5) == 76)
  assert(stack:shakeFramesForGarbageSize(6, 8) == 76)
  assert(stack:shakeFramesForGarbageSize(6, 1000) == 76)
  StackReplayTestingUtils:cleanup(match)
end

testShakeFrames()


local function swapStalling1Test1()
  local match = StackReplayTestingUtils.createSinglePlayerMatch(GameModes.getPreset("ONE_PLAYER_PUZZLE"), "controller", LevelPresets.getModern(10))
  local puzzle = Puzzle("clear", false, 0, "[======================][====]246260[====]600016514213461336451511124242", 0, 0)
  local stack = match.stacks[1]
  stack.behaviours.swapStallingMode = 1
  stack:setPuzzleState(puzzle)

  local left = base64encode[3]
  local down = base64encode[5]
  local right = base64encode[2]
  local swap = base64encode[17]

  local sequence1 = table.concat({
    -- +4 combo with the reds (color 1) in column 3
    down, down, right, swap, left, swap, down .. left, swap,
  }, "A")

  local sequence2 = table.concat({
    -- swap the right most panels in row 4 twice; this works, we got stop time; then prepare to move the dark blue panel over
    right, right, right, swap, swap, down
  }, "A")

  -- we wait until we're about out of invincibility frames
  local frameConstants = stack.levelData.frameConstants
  local invincibilityTime = frameConstants.FLASH + frameConstants.FACE + frameConstants.POP * (4 + 6) + stack:calculateStopTime(4, true)
  invincibilityTime = invincibilityTime - sequence2:len() + 2
  local sequence3 = string.rep("A", invincibilityTime)

  local sequence4 = table.concat({
    -- stealth over the dark blue for a horizontal match and move out of the clear wall so the wiggle is not intercepted
    swap, left, swap, right
  }, "A")

  -- wait until we're out of invincibility frames again
  invincibilityTime = frameConstants.FLASH + frameConstants.FACE + frameConstants.POP * 3
  local sequence5 = string.rep("A", invincibilityTime)

  local preWiggleInputs = sequence1 .. sequence2 .. sequence3 .. sequence4 .. sequence5
  local wiggle = table.concat({
    -- wiggle
    swap, swap, swap, swap, swap, swap, swap, swap, swap, swap
  }, "AA")

  -- can't swap on first two frames ?!
  local inputs = "AA" .. preWiggleInputs .. wiggle

  stack:receiveConfirmedInput(inputs) -- can't swap on first two frames
  StackReplayTestingUtils:fullySimulateMatch(match)
  assert(match.clock > preWiggleInputs:len(), "expected to live before starting to wiggle")
  assert(inputs:len() > match.clock and stack.game_over_clock > 0, "expected the stack to go game over")
  -- at clock time 197 we get 59 frames of prestop which have run out at 257, followed by 6 frames of hover and 2 frames until the frames have finished landing
  -- wiggling starts at frame 252 for 28 frames on every 3rd frame with swaps on 255, 258, 261, 264, 267, the latter 2 are after landing so the swap at 267 should kill us
  assert(stack.game_over_clock == 267)
end

swapStalling1Test1()