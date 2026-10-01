local consts = require("common.engine.consts")
local StackReplayTestingUtils = require("common.tests.engine.StackReplayTestingUtils")
local Puzzle = require("common.engine.Puzzle")
local LevelPresets = require("common.data.LevelPresets")
local KeyDataEncoding = require("common.data.KeyDataEncoding")
local TestUtils = require("common.tests.TestUtils")

local function puzzleTest()
  -- to stop rising
  local puzzle = Puzzle({puzzleType = Puzzle.PUZZLE_TYPES.moves, moves = 1, stack = "011010"})
  local match = StackReplayTestingUtils.createSinglePlayerMatch(puzzle:toGameMode(), puzzle:toPanelSource())
  local stack = match.stacks[1]
  ---@cast stack Stack

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
  local puzzle = Puzzle({puzzleType = Puzzle.PUZZLE_TYPES.clear,
                         stack = "[============================][====]246260[====]600016514213466313451511124242",
                         stopTime = 60, garbagePanelBuffer = "999999"})
  local match = StackReplayTestingUtils.createSinglePlayerMatch(puzzle:toGameMode(), puzzle:toPanelSource())
  local stack = match.stacks[1]
  ---@cast stack Stack

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
---@cast stack Stack

  stack:setCountdown(false)

  stack:receiveConfirmedInput("AA") -- can't swap on first two frames
  StackReplayTestingUtils:simulateMatchUntil(match, 2)

  local leftPanel = stack.panels[1][1]
  local rightPanel = stack.panels[1][2]
  assert(stack:tryQueueSwap(leftPanel, rightPanel), "should be able to swap")
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
  ---@cast stack Stack
  stack:setCountdown(true)
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
  match.engineVersion = consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE
  local stack = match.stacks[1]
  ---@cast stack Stack

  -- imaginary garbage should crash
  local success1, errorMessage1 = TestUtils.expectErrorQuiet(function()
    stack:shakeFramesForGarbageSize(6, 0)
  end)
  assert(success1, errorMessage1)

  local success2, errorMessage2 = TestUtils.expectErrorQuiet(function()
    stack:shakeFramesForGarbageSize(6, -1)
  end)
  assert(success2, errorMessage2)

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
  local puzzle = Puzzle({puzzleType = Puzzle.PUZZLE_TYPES.clear,
                         stack = "[======================][====]246260[====]600016514213461336451511124242",
                         garbagePanelBuffer = "999999999999999999"})
  local match = StackReplayTestingUtils.createSinglePlayerMatch(puzzle:toGameMode(), puzzle:toPanelSource(), "controller", LevelPresets.getModern(10))
  local stack = match.stacks[1]
  ---@cast stack Stack
  stack.behaviours.swapStallingMode = 1

  local left = KeyDataEncoding.left
  local down = KeyDataEncoding.down
  local right = KeyDataEncoding.right
  local swap = KeyDataEncoding.swap

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
  -- wiggling starts at frame 252 for 28 frames on every 3rd frame with swaps on 255, 258, 261, 264, 267, the latter 2 are after landing so the swap at 267 should get denied
  -- following which it takes 2 more frames until passive raise kills us
  assert(stack.game_over_clock == 269)
end

swapStalling1Test1()

-- counts every garbage panel on the board, whatever state it is in, including rows above the visible height
local function countGarbagePanels(stack)
  local count = 0
  for row = 1, #stack.panels do
    for column = 1, stack.width do
      if stack.panels[row][column].isGarbage then
        count = count + 1
      end
    end
  end
  return count
end

-- a clear puzzle with a garbage buffer is won once every row of the buffer has been revealed, however much garbage is left
local function clearPuzzleWinsWhenTheGarbageBufferIsUsedUpTest()
  local puzzle = Puzzle({puzzleType = Puzzle.PUZZLE_TYPES.clear, stack = "[================]112122", garbagePanelBuffer = "334344556566",
                         stopTime = 2000, startTiming = Puzzle.START_TIMINGS.immediately, cursorStartLeft = {row = 1, column = 3}})
  local match = StackReplayTestingUtils.createSinglePlayerMatch(puzzle:toGameMode(), puzzle:toPanelSource(), "controller",
                                                                LevelPresets.getModern(10))
  local stack = match.stacks[1]
  ---@cast stack Stack

  local secondSwapFrame = 400
  stack:receiveConfirmedInput("AA" .. KeyDataEncoding.swap .. string.rep(KeyDataEncoding.idle, secondSwapFrame - 4)
                              .. KeyDataEncoding.swap .. string.rep(KeyDataEncoding.idle, 600))
  StackReplayTestingUtils:simulateMatchUntil(match, 10)
  assert(stack.panels[2][1].state == "matched", "the block should be hit by the swap")
  assert(not stack:checkGameWin(), "one row revealed of two is not a win")
  StackReplayTestingUtils:simulateMatchUntil(match, secondSwapFrame - 1)
  assert(stack.panels[1][3].color == 4 and stack.panels[1][4].color == 3, "the revealed row has landed as 334344")
  assert(not stack:checkGameWin(), "the second buffer row is still to be revealed")
  while not match:hasEnded() and stack.clock < secondSwapFrame + 20 do
    match:run()
  end
  assert(stack:checkGameWin(), "the second hit reveals the last buffer row, which wins")
  assert(stack.game_over_clock <= 0, "the stack should not have lost")
  assert(countGarbagePanels(stack) > 0,"garbage is still on the board when the buffer is used up")
  StackReplayTestingUtils:cleanup(match)
end

clearPuzzleWinsWhenTheGarbageBufferIsUsedUpTest()

-- revealing every panel of the buffer is the whole goal, a block left unhit does not matter
local function clearPuzzleWinsOnTheBufferWithABlockLeftUnhitTest()
  local puzzle = Puzzle({puzzleType = Puzzle.PUZZLE_TYPES.clear, stack = "[================]112199999[=]",
                         garbagePanelBuffer = "121333556566", stopTime = 3000, startTiming = Puzzle.START_TIMINGS.immediately,
                         cursorStartLeft = {row = 2, column = 3}})
  local match = StackReplayTestingUtils.createSinglePlayerMatch(puzzle:toGameMode(), puzzle:toPanelSource(), "controller",
                                                                LevelPresets.getModern(10))
  local stack = match.stacks[1]
  ---@cast stack Stack

  stack:receiveConfirmedInput("AA" .. KeyDataEncoding.swap .. string.rep(KeyDataEncoding.idle, 1200))
  -- the first hit reveals 121333, whose 333 lands under the block and hits it again on its own
  while not match:hasEnded() and stack.clock < 900 do
    match:run()
  end
  assert(stack.panelSource.garbagePanelBuffer == "", "both buffer rows should be revealed")
  assert(stack.panels[1][4].isGarbage and stack.panels[1][4].state == "normal", "the small block at the bottom was never hit")
  assert(stack:checkGameWin(), "the buffer is revealed, so the puzzle is won")
  StackReplayTestingUtils:cleanup(match)
end

clearPuzzleWinsOnTheBufferWithABlockLeftUnhitTest()

-- A buffer longer than the board can ever reveal is a puzzle that cannot be won. The engine has no
-- way to know that, so this records what the author gets rather than a rule: the same board that is
-- won at two rows of buffer is never won at three, which is what the buffer audit exists to catch.
local function clearPuzzleWithABufferTheBoardCannotRevealIsNeverWonTest()
  local puzzle = Puzzle({puzzleType = Puzzle.PUZZLE_TYPES.clear, stack = "[================]112122",
                         garbagePanelBuffer = "334344556566998899", stopTime = 2000,
                         startTiming = Puzzle.START_TIMINGS.immediately, cursorStartLeft = {row = 1, column = 3}})
  local match = StackReplayTestingUtils.createSinglePlayerMatch(puzzle:toGameMode(), puzzle:toPanelSource(), "controller",
                                                                LevelPresets.getModern(10))
  local stack = match.stacks[1]
  ---@cast stack Stack

  local secondSwapFrame = 400
  stack:receiveConfirmedInput("AA" .. KeyDataEncoding.swap .. string.rep(KeyDataEncoding.idle, secondSwapFrame - 4)
                              .. KeyDataEncoding.swap .. string.rep(KeyDataEncoding.idle, 600))
  while not match:hasEnded() and stack.clock < secondSwapFrame + 20 do
    match:run()
  end

  -- the same board wins at two rows of buffer, so the third is the one it can never spend
  assert(stack.panelSource.garbagePanelBuffer == "998899", "the board can only spend two of the three rows, got '"
         .. stack.panelSource.garbagePanelBuffer .. "'")
  assert(not stack:checkGameWin(), "a buffer the board cannot finish is never revealed, so the puzzle is never won")
  StackReplayTestingUtils:cleanup(match)
end

clearPuzzleWithABufferTheBoardCannotRevealIsNeverWonTest()
