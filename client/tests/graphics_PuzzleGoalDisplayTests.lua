local PuzzleGoalDisplay = require("client.src.graphics.PuzzleGoalDisplay")
local ChainComboTally = require("common.engine.ChainComboTally")
local Puzzle = require("common.engine.Puzzle")
local Stack = require("common.engine.Stack")

-- minimal stub for the stack properties read by the goal display, judging win conditions with the stack's own rules
local function fakeStack(panelsLeft)
  return {
    tally = ChainComboTally(),
    stackOverConditions = {},
    swapCount = 0,
    panelSource = {garbagePanelBuffer = "", garbageGenCount = 0},
    matchablePanelCount = function()
      return panelsLeft
    end,
    meetsWinCondition = Stack.meetsWinCondition
  }
end

local function goalDisplay(goals, stack)
  local puzzle = Puzzle({goals = goals, moves = 2, stack = "011010"})
  return PuzzleGoalDisplay({puzzle = puzzle, stack = stack, x = 0, y = 0, width = 0, height = 0})
end

local function aCardIsShownForEveryChainAndComboGoal()
  local display = goalDisplay({"Empty Board", "x2", "+6", "+6"}, fakeStack(6))

  assert(#display.cards == 3, "a goal asked for twice gets two cards")
  assert(display.cards[1].isChain and display.cards[1].size == 2)
  assert(not display.cards[2].isChain and display.cards[2].size == 6)
  assert(not display.cards[3].isChain and display.cards[3].size == 6)
  assert(display:getHeadingKey() == "puzzle_goal_combo_chain_heading")
end

local function cardsCompleteOneAtATimeAsTheStackMakesThem()
  local stack = fakeStack(6)
  local display = goalDisplay({"x2", "+6", "+6"}, stack)

  stack.tally:addCombo(6)
  display:update(0.016)
  assert(not display.cards[1].complete, "no chain has ended yet")
  assert(display.cards[2].complete, "the first +6 card is the one that completes")
  assert(not display.cards[3].complete, "one +6 of the two is still to be made")

  stack.tally:addCombo(6)
  stack.tally:addChain(2)
  display:update(0.016)
  assert(display.cards[1].complete and display.cards[2].complete and display.cards[3].complete)
end

local function aCompletedCardIsTakenBackWhenTheTallyIs()
  local stack = fakeStack(6)
  local display = goalDisplay({"+6"}, stack)
  stack.tally:addCombo(6)
  display:update(0.016)

  ChainComboTally():copyTo(stack.tally)
  display:update(0.016)

  assert(not display.cards[1].complete, "the box shows what the stack holds, so a rollback or reset undoes the card")
end

local function aPuzzleOfAnOldTypeHasNoCards()
  local puzzle = Puzzle({puzzleType = "moves", moves = 2, stack = "011010"})
  local display = PuzzleGoalDisplay({puzzle = puzzle, stack = fakeStack(3), x = 0, y = 0, width = 0, height = 0})

  assert(#display.cards == 0)
  assert(display:getHeadingKey() == "puzzle_goal_move_heading")
end

local function anEmptyBoardRowCompletesOnceNoPanelIsLeft()
  local display = goalDisplay({"Empty Board", "x2"}, fakeStack(0))
  display:update(0.016)

  local emptyBoardRow
  for _, row in ipairs(display.rows) do
    if row.goalKind == "emptyBoard" then
      emptyBoardRow = row
    end
  end
  assert(emptyBoardRow and emptyBoardRow.complete)
end

local function aClearPuzzleWithASwapLimitShowsTheSwapsLeft()
  local puzzle = Puzzle({goals = {"Clear"}, moves = 2, stack = "[====]011010"})
  local display = PuzzleGoalDisplay({puzzle = puzzle, stack = fakeStack(3), x = 0, y = 0, width = 0, height = 0})

  local hasSwapsRow = false
  for _, row in ipairs(display.rows) do
    hasSwapsRow = hasSwapsRow or row.goalKind == "swaps"
  end
  assert(hasSwapsRow, "the swap limit ends the puzzle whatever its goals are, so the box has to show it")
end

aCardIsShownForEveryChainAndComboGoal()
aClearPuzzleWithASwapLimitShowsTheSwapsLeft()
cardsCompleteOneAtATimeAsTheStackMakesThem()
aCompletedCardIsTakenBackWhenTheTallyIs()
aPuzzleOfAnOldTypeHasNoCards()
anEmptyBoardRowCompletesOnceNoPanelIsLeft()

local function anEmptyBoardPuzzleWithoutASwapLimitNamesNoSwapCount()
  local puzzle = Puzzle({goals = {"Empty Board"}, moves = 0, stack = "011010"})
  local display = PuzzleGoalDisplay({puzzle = puzzle, stack = fakeStack(3), x = 0, y = 0, width = 0, height = 0})

  assert(#display.rows == 1)
  assert(display.rows[1].key == "puzzle_goal_empty_board_objective", "there is no limit to count down from")
end

local function emptyBoardWithClearIsHeadedAsAClearPuzzle()
  local puzzle = Puzzle({goals = {"Empty Board", "Clear"}, stack = "[====]011010", garbagePanelBuffer = "334344"})
  local display = PuzzleGoalDisplay({puzzle = puzzle, stack = fakeStack(3), x = 0, y = 0, width = 0, height = 0})

  assert(display:getHeadingKey() == "puzzle_goal_clear_heading")
end

anEmptyBoardPuzzleWithoutASwapLimitNamesNoSwapCount()
emptyBoardWithClearIsHeadedAsAClearPuzzle()

---@param display PuzzleGoalDisplay
---@return PuzzleGoalRow?
local function clearRow(display)
  for _, row in ipairs(display.rows) do
    if row.goalKind == "clear" then
      return row
    end
  end
end

local function aClearRowWaitsForARowPastItsBuffer()
  local stack = fakeStack(3)
  local puzzle = Puzzle({goals = {"Clear", "x2"}, stack = "[====]011010", garbagePanelBuffer = "334344"})
  local display = PuzzleGoalDisplay({puzzle = puzzle, stack = stack, x = 0, y = 0, width = 0, height = 0})
  display:update(0.016)

  assert(not clearRow(display).complete, "revealing the buffer's last row does not clear the puzzle, the row after it does")
end

local function aClearRowCompletesOnceARowIsRevealedPastItsBuffer()
  local stack = fakeStack(3)
  stack.panelSource.garbageGenCount = 1
  local puzzle = Puzzle({goals = {"Clear", "x2"}, stack = "[====]011010"})
  local display = PuzzleGoalDisplay({puzzle = puzzle, stack = stack, x = 0, y = 0, width = 0, height = 0})
  display:update(0.016)

  assert(clearRow(display).complete, "without a buffer the first revealed row is already past it")
end

aClearRowWaitsForARowPastItsBuffer()
aClearRowCompletesOnceARowIsRevealedPastItsBuffer()

local function near(a, b)
  return math.abs(a - b) < 0.001
end

local function aCardJustMadeShowsNoCheckYet()
  local dim, _, checkAlpha, glow = PuzzleGoalDisplay.checkAnimationAt(0)
  assert(near(dim, 0) and near(checkAlpha, 0) and near(glow, 0), "the card is still in full color with no check")
end

local function theCheckIsBiggestAndBrightestHalfwayThroughTheCheckAnimation()
  local _, checkScale, checkAlpha, glow = PuzzleGoalDisplay.checkAnimationAt(0.2)
  assert(near(checkScale, 1.12), "the check peaks at 112%, got " .. checkScale)
  assert(near(checkAlpha, 1) and near(glow, 1))
end

local function theCheckAnimationSettlesAtFullSizeWithoutGlow()
  local dim, checkScale, checkAlpha, glow = PuzzleGoalDisplay.checkAnimationAt(0.4)
  assert(near(dim, 1) and near(checkScale, 1) and near(checkAlpha, 1) and near(glow, 0))
end

local function theCheckNeverDipsBelowFullSizeAfterItsPeak()
  for elapsed = 0.2, 0.4, 0.01 do
    local _, checkScale = PuzzleGoalDisplay.checkAnimationAt(elapsed)
    assert(checkScale >= 1 - 0.001, "the check settles from above, got " .. checkScale .. " at " .. elapsed)
  end
end

local function makingACardStartsItsCheckAnimationAndTheAnimationEnds()
  local stack = fakeStack(6)
  local display = goalDisplay({"+6"}, stack)
  stack.tally:addCombo(6)
  display:update(0.016)
  assert(display.cards[1].checkAnimationElapsed == 0, "the check animation starts the frame the card is made")

  display:update(0.5)
  assert(display.cards[1].checkAnimationElapsed == nil, "the check animation is over after 0.4s")
end

aCardJustMadeShowsNoCheckYet()
theCheckIsBiggestAndBrightestHalfwayThroughTheCheckAnimation()
theCheckAnimationSettlesAtFullSizeWithoutGlow()
theCheckNeverDipsBelowFullSizeAfterItsPeak()
makingACardStartsItsCheckAnimationAndTheAnimationEnds()

local function theCheckAnimationEasesOutTheWayTheCssDemoDoes()
  -- CSS ease-out, cubic-bezier(0, 0, 0.58, 1), is 0.6846 of the way at half its time
  local _, checkScale = PuzzleGoalDisplay.checkAnimationAt(0.1)
  assert(near(checkScale, 0.4 + 0.72 * 0.6846), "got " .. checkScale)
end

theCheckAnimationEasesOutTheWayTheCssDemoDoes()

local function makingACardLeavesTheBoxUnlit()
  local stack = fakeStack(6)
  local display = goalDisplay({"+6"}, stack)
  display:update(3.1)
  stack.tally:addCombo(6)
  display:update(0.016)
  assert(display.highlightTimer <= 0, "the card's check animation is the whole celebration")
end

makingACardLeavesTheBoxUnlit()

local function theGlowFadesInWithTheCheck()
  -- in the CSS demo the check's opacity applies on top of its glow filter
  local _, _, checkAlpha, glow = PuzzleGoalDisplay.checkAnimationAt(0.05)
  assert(near(glow, checkAlpha * checkAlpha), "got glow " .. glow .. " at alpha " .. checkAlpha)
end

theGlowFadesInWithTheCheck()

local function aSettledCheckAnimationLeavesNoGlowToDraw()
  local dim, _, _, glow = PuzzleGoalDisplay.checkAnimationAt(0.4)
  assert(glow == 0, "a finished card would draw its glow layers every frame, glow " .. glow)
  assert(dim == 1)
end

local function aCheckAnimationJustStartedHasNotDimmedTheCard()
  local dim = PuzzleGoalDisplay.checkAnimationAt(0)
  assert(dim == 0, "got " .. dim)
end

aSettledCheckAnimationLeavesNoGlowToDraw()
aCheckAnimationJustStartedHasNotDimmedTheCard()
