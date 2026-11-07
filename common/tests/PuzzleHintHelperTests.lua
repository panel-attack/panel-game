local PuzzleHintHelper = require("client.src.PuzzleHintHelper")
local PuzzleSet = require("client.src.PuzzleSet")
local Puzzle = require("common.engine.Puzzle")
local InputCompression = require("common.data.InputCompression")
local KeyDataEncoding = require("common.data.KeyDataEncoding")
local StackReplayTestingUtils = require("common.tests.engine.StackReplayTestingUtils")
local LevelPresets = require("common.data.LevelPresets")

local BUNDLED_PUZZLES_PATH = "client/assets/default_data/puzzles/Puzzles.json"
-- frames after a solution's last input for its last matches to clear
local SETTLE_FRAMES = 60 * 10

local PuzzleHintHelperTests = {}

-- Joins the keys into one input string, each followed by enough idle frames that the cursor moves exactly once
-- and the next swap is allowed
---@param ... string KeyDataEncoding inputs
---@return string
local function tapInputs(...)
  local inputs = {}
  for _, key in ipairs({...}) do
    inputs[#inputs + 1] = key .. string.rep(KeyDataEncoding.idle, 3)
  end
  return table.concat(inputs)
end

-- A three move puzzle on a one row stack that starts immediately and has the inputs as its solution
---@param solutionInputs string
---@param cursorStartLeft {row: integer, column: integer}
---@return Puzzle
local function movesPuzzleWithSolution(solutionInputs, cursorStartLeft)
  return Puzzle({
    puzzleType = "moves",
    startTiming = Puzzle.START_TIMINGS.immediately,
    stack = "123412",
    moves = 3,
    cursorStartLeft = cursorStartLeft,
    solution = InputCompression.compressInputString(solutionInputs)
  })
end

-- Plays the puzzle's solution at the level solutions are recorded at, then idles until the match ends
-- a solution that leaves moves unused and doesn't clear never ends the match, so the idling is capped
---@param puzzle Puzzle
---@return boolean won whether the solution solves the puzzle
local function solutionWins(puzzle)
  local match = StackReplayTestingUtils.createSinglePlayerMatch(puzzle:toGameMode(), puzzle:toPanelSource(), "controller",
                                                                LevelPresets.getModern(Puzzle.SOLUTION_LEVEL))
  local stack = match.stacks[1]
  ---@cast stack Stack
  local inputs = InputCompression.decompressInputString2(puzzle.solution)
  stack:receiveConfirmedInput(inputs .. string.rep(KeyDataEncoding.idle, SETTLE_FRAMES))
  while stack.clock < #stack.confirmedInput and not match:hasEnded() do
    match:run()
  end
  return match:hasEnded() and stack.game_over_clock <= 0
end

-- Adds every moves puzzle with a solution in the set and its nested sets to found
---@param puzzleSet PuzzleSet
---@param found {name: string, puzzle: Puzzle}[]
---@return {name: string, puzzle: Puzzle}[] found
local function collectMovesPuzzlesWithSolutions(puzzleSet, found)
  for index, puzzle in ipairs(puzzleSet.puzzles) do
    if puzzle.puzzleType == Puzzle.PUZZLE_TYPES.moves and puzzle.solution then
      found[#found + 1] = {name = puzzleSet.setName .. " #" .. index, puzzle = puzzle}
    end
  end
  for _, child in ipairs(puzzleSet.puzzleSets) do
    collectMovesPuzzlesWithSolutions(child, found)
  end
  return found
end

-- Every bundled moves puzzle that has a solution, named by its set and number
---@return {name: string, puzzle: Puzzle}[]
local function bundledMovesPuzzlesWithSolutions()
  local found = {}
  for _, puzzleSet in ipairs(PuzzleSet.loadFromFile(BUNDLED_PUZZLES_PATH)) do
    collectMovesPuzzlesWithSolutions(puzzleSet, found)
  end
  return found
end

-- The bundled puzzle at the index of the set with this setName, searching nested sets
---@param setName string
---@param index integer
---@return Puzzle?
local function findBundledPuzzle(setName, index)
  local function search(puzzleSet)
    if puzzleSet.setName == setName then
      return puzzleSet.puzzles[index]
    end
    for _, child in ipairs(puzzleSet.puzzleSets) do
      local puzzle = search(child)
      if puzzle then
        return puzzle
      end
    end
  end
  for _, puzzleSet in ipairs(PuzzleSet.loadFromFile(BUNDLED_PUZZLES_PATH)) do
    local puzzle = search(puzzleSet)
    if puzzle then
      return puzzle
    end
  end
end

-- Formats swap positions as "(row,column)" pairs for assertion messages
---@param positions {row: integer, column: integer}[]
---@return string
local function positionsText(positions)
  local parts = {}
  for _, position in ipairs(positions) do
    parts[#parts + 1] = "(" .. position.row .. "," .. position.column .. ")"
  end
  return table.concat(parts, " ")
end

function PuzzleHintHelperTests.testCreateHintHelperWithoutSolution()
  local puzzle = Puzzle({
    puzzleType = "moves",
    stack = "000000000011",
    moves = 1
  })

  local helper = PuzzleHintHelper(puzzle)

  assert(not helper:hasSolution(), "Helper should report no solution when puzzle has no solution")
  assert(helper:getSolutionSwapCount() == 0, "Should have 0 swaps when no solution")
  assert(helper:getSolutionInputString() == nil, "Should return nil for solution input string when no solution")
end

function PuzzleHintHelperTests.testCreateHintHelperWithSolution()
  local solutionInputs = tapInputs(KeyDataEncoding.right, KeyDataEncoding.swap)
  local helper = PuzzleHintHelper(movesPuzzleWithSolution(solutionInputs, {row = 1, column = 1}))

  assert(helper:hasSolution(), "Helper should report having solution")
  assert(helper:getSolutionSwapCount() == 1, "Should have 1 swap in solution")
  assert(helper:getSolutionInputString() == solutionInputs, "Should return original input string")
end

function PuzzleHintHelperTests.testExtractSwapPositions()
  local solutionInputs = tapInputs(KeyDataEncoding.right, KeyDataEncoding.right, KeyDataEncoding.swap,
                                   KeyDataEncoding.left, KeyDataEncoding.swap)
  local helper = PuzzleHintHelper(movesPuzzleWithSolution(solutionInputs, {row = 1, column = 1}))

  assert(helper:getSolutionSwapCount() == 2, "Should extract 2 swaps from solution")

  local swapPositions = helper.solutionSwapPositions
  assert(swapPositions[1].row == 1 and swapPositions[1].column == 3, "First swap should be at (1,3)")
  assert(swapPositions[2].row == 1 and swapPositions[2].column == 2, "Second swap should be at (1,2)")
end

function PuzzleHintHelperTests.testHeldDirectionRepeatsCursorMovement()
  local solutionInputs = string.rep(KeyDataEncoding.right, 15) .. tapInputs(KeyDataEncoding.swap)
  local helper = PuzzleHintHelper(movesPuzzleWithSolution(solutionInputs, {row = 1, column = 1}))

  local swapPosition = helper.solutionSwapPositions[1]
  assert(swapPosition and swapPosition.column == 5, "Holding right should repeat the movement up to column 5, got "
    .. positionsText(helper.solutionSwapPositions))
end

function PuzzleHintHelperTests.testDirectionChangeWithoutIdleFrameMovesCursor()
  local solutionInputs = KeyDataEncoding.right .. KeyDataEncoding.up .. tapInputs(KeyDataEncoding.swap)
  local puzzle = Puzzle({
    puzzleType = "moves",
    startTiming = Puzzle.START_TIMINGS.immediately,
    stack = "123412341234",
    moves = 1,
    cursorStartLeft = {row = 1, column = 1},
    solution = InputCompression.compressInputString(solutionInputs)
  })
  local helper = PuzzleHintHelper(puzzle)

  local swapPosition = helper.solutionSwapPositions[1]
  assert(swapPosition and swapPosition.row == 2 and swapPosition.column == 2,
         "Right then up with no idle frame between should move the cursor to (2,2), got " .. positionsText(helper.solutionSwapPositions))
end

function PuzzleHintHelperTests.testIsPlayerInSync()
  local solutionInputs = tapInputs(KeyDataEncoding.right, KeyDataEncoding.right, KeyDataEncoding.swap,
                                   KeyDataEncoding.left, KeyDataEncoding.swap)
  local helper = PuzzleHintHelper(movesPuzzleWithSolution(solutionInputs, {row = 1, column = 1}))

  assert(helper:isPlayerInSync({}), "Empty player swaps should be in sync")
  assert(helper:isPlayerInSync({{row = 1, column = 3}}), "Correct first swap should be in sync")
  assert(not helper:isPlayerInSync({{row = 1, column = 2}}), "Incorrect first swap should not be in sync")
  assert(not helper:isPlayerInSync({{row = 1, column = 3}, {row = 1, column = 2}, {row = 1, column = 1}}),
         "Too many swaps should not be in sync")
end

function PuzzleHintHelperTests.testGetNextHint()
  local solutionInputs = tapInputs(KeyDataEncoding.right, KeyDataEncoding.right, KeyDataEncoding.swap,
                                   KeyDataEncoding.left, KeyDataEncoding.swap)
  local helper = PuzzleHintHelper(movesPuzzleWithSolution(solutionInputs, {row = 1, column = 1}))

  local hint1 = helper:getNextHint(0)
  assert(hint1 ~= nil, "Should get first hint")
  assert(hint1.row == 1 and hint1.column == 3, "First hint should be (1,3)")

  local hint2 = helper:getNextHint(1)
  assert(hint2 ~= nil, "Should get second hint")
  assert(hint2.row == 1 and hint2.column == 2, "Second hint should be (1,2)")

  assert(helper:getNextHint(2) == nil, "Should get nil when no more swaps")
end

function PuzzleHintHelperTests.testIsMovePuzzle()
  local movesPuzzle = Puzzle({
    puzzleType = "moves",
    stack = "000000000011",
    moves = 1
  })

  local chainPuzzle = Puzzle({
    puzzleType = "chain",
    stack = "000000000011"
  })

  local clearPuzzle = Puzzle({
    puzzleType = "clear",
    stack = "000000000011"
  })

  assert(PuzzleHintHelper(movesPuzzle):isMovePuzzle(), "Moves puzzle should be identified as move puzzle")
  assert(not PuzzleHintHelper(chainPuzzle):isMovePuzzle(), "Chain puzzle should not be identified as move puzzle")
  assert(not PuzzleHintHelper(clearPuzzle):isMovePuzzle(), "Clear puzzle should not be identified as move puzzle")
end

function PuzzleHintHelperTests.testParseEmptySolution()
  local puzzle = Puzzle({
    puzzleType = "moves",
    stack = "000000000011",
    moves = 1,
    solution = ""
  })

  local helper = PuzzleHintHelper(puzzle)

  assert(helper:hasSolution(), "Should have solution even if empty")
  assert(helper:getSolutionSwapCount() == 0, "Empty solution should have 0 swaps")
  assert(helper:getSolutionInputString() == "", "Empty solution should return empty string")
end

function PuzzleHintHelperTests.testDefaultCursorPosition()
  -- the stack refuses a swap on its first frames
  local solutionInputs = tapInputs(KeyDataEncoding.idle, KeyDataEncoding.swap)
  local puzzle = Puzzle({
    puzzleType = "moves",
    startTiming = Puzzle.START_TIMINGS.immediately,
    stack = string.rep("123412341234", 4),
    moves = 1,
    solution = InputCompression.compressInputString(solutionInputs)
  })

  local helper = PuzzleHintHelper(puzzle)

  assert(helper:getSolutionSwapCount() == 1, "Should have 1 swap")
  local swapPos = helper.solutionSwapPositions[1]
  assert(swapPos.row == 7 and swapPos.column == 3,
         "Swap should be at default position (7,3), got " .. positionsText(helper.solutionSwapPositions))
end

function PuzzleHintHelperTests.testClassicSet2Puzzle2FirstHintIsOnTheBottomRow()
  local puzzle = findBundledPuzzle("puzzle_set_name_classic_set_2", 2)
  assert(puzzle, "Classic Set 2 #2 should be bundled")

  local hint = PuzzleHintHelper(puzzle):getNextHint(0)

  assert(hint and hint.row == 1 and hint.column == 1, "The solution swaps at (1,1), the hint went to " .. positionsText({hint}))
end

-- solutions are recorded at level 10 and at level 5 this solution's second swap would queue at (2,4) instead
function PuzzleHintHelperTests.testHintsReplayTheSolutionAtTheLevelItWasRecordedAt()
  local puzzle = findBundledPuzzle("puzzle_set_name_advanced_shoguns", 6)
  assert(puzzle, "Advanced Shoguns #6 should be bundled")

  local hint = PuzzleHintHelper(puzzle):getNextHint(1)

  assert(hint and hint.row == 2 and hint.column == 3, "At level 10 the second swap is at (2,3), the hint went to " .. positionsText({hint}))
end

function PuzzleHintHelperTests.testEveryBundledMovesPuzzleSolutionWinsAtTheSolutionLevel()
  local puzzles = bundledMovesPuzzlesWithSolutions()
  assert(#puzzles >= 60, "expected the bundled moves puzzles with solutions, found " .. #puzzles)

  local losses = {}
  for _, entry in ipairs(puzzles) do
    assert(PuzzleHintHelper(entry.puzzle):getSolutionSwapCount() > 0, entry.name .. " should swap at least once in its solution")
    if not solutionWins(entry.puzzle) then
      losses[#losses + 1] = entry.name
    end
  end

  assert(#losses == 0, #losses .. " solution(s) don't win at the solution level: " .. table.concat(losses, ", "))
end

function PuzzleHintHelperTests.testRefusedSwapIsNotTrackedAsAPlayerSwap()
  local puzzle = Puzzle({
    puzzleType = "moves",
    startTiming = Puzzle.START_TIMINGS.immediately,
    stack = "000011",
    moves = 2,
    cursorStartLeft = {row = 1, column = 1}
  })
  local match = StackReplayTestingUtils.createSinglePlayerMatch(puzzle:toGameMode(), puzzle:toPanelSource())
  local stack = match.stacks[1]
  ---@cast stack Stack
  local helper = PuzzleHintHelper(puzzle)
  helper:followPlayerStack(stack)
  -- the first swap is on two empty cells, which the stack refuses
  local inputs = tapInputs(KeyDataEncoding.idle, KeyDataEncoding.swap, KeyDataEncoding.right, KeyDataEncoding.right,
                           KeyDataEncoding.right, KeyDataEncoding.swap)
  stack:receiveConfirmedInput(inputs)

  while stack.clock < #inputs and not match:hasEnded() do
    match:run()
  end

  assert(positionsText(helper.playerSwapPositions) == "(1,4)",
         "Only the swap the stack queued should be tracked, got " .. positionsText(helper.playerSwapPositions))
end

function PuzzleHintHelperTests.testNonMovesPuzzleHasNoSwapHints()
  local puzzle = Puzzle({
    puzzleType = "chain",
    startTiming = Puzzle.START_TIMINGS.immediately,
    stack = "123412341234",
    cursorStartLeft = {row = 1, column = 1},
    solution = InputCompression.compressInputString(tapInputs(KeyDataEncoding.idle, KeyDataEncoding.swap))
  })

  assert(PuzzleHintHelper(puzzle):getSolutionSwapCount() == 0, "Only moves puzzles get swap hints, so others skip the replay")
end

PuzzleHintHelperTests.testCreateHintHelperWithoutSolution()
PuzzleHintHelperTests.testCreateHintHelperWithSolution()
PuzzleHintHelperTests.testExtractSwapPositions()
PuzzleHintHelperTests.testHeldDirectionRepeatsCursorMovement()
PuzzleHintHelperTests.testDirectionChangeWithoutIdleFrameMovesCursor()
PuzzleHintHelperTests.testIsPlayerInSync()
PuzzleHintHelperTests.testGetNextHint()
PuzzleHintHelperTests.testIsMovePuzzle()
PuzzleHintHelperTests.testParseEmptySolution()
PuzzleHintHelperTests.testDefaultCursorPosition()
PuzzleHintHelperTests.testClassicSet2Puzzle2FirstHintIsOnTheBottomRow()
PuzzleHintHelperTests.testHintsReplayTheSolutionAtTheLevelItWasRecordedAt()
PuzzleHintHelperTests.testEveryBundledMovesPuzzleSolutionWinsAtTheSolutionLevel()
PuzzleHintHelperTests.testRefusedSwapIsNotTrackedAsAPlayerSwap()
PuzzleHintHelperTests.testNonMovesPuzzleHasNoSwapHints()

return PuzzleHintHelperTests
