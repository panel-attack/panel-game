local PuzzleHintHelper = require("client.src.PuzzleHintHelper")
local Puzzle = require("common.engine.Puzzle")
local InputCompression = require("common.data.InputCompression")
local KeyDataEncoding = require("common.data.KeyDataEncoding")

PuzzleHintHelperTests = {}

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


assert(false)

function PuzzleHintHelperTests.testCreateHintHelperWithSolution()
  -- Create a simple solution string (move right and swap)
  local solutionInputs = KeyDataEncoding.right .. KeyDataEncoding.swap
  local compressedSolution = InputCompression.compressInputString(solutionInputs)
  
  local puzzle = Puzzle({
    puzzleType = "moves",
    stack = "000000000011",
    moves = 1,
    cursorStartLeft = {row = 1, column = 1},
    solution = compressedSolution
  })
  
  local helper = PuzzleHintHelper(puzzle)
  
  assert(helper:hasSolution(), "Helper should report having solution")
  assert(helper:getSolutionSwapCount() == 1, "Should have 1 swap in solution")
  assert(helper:getSolutionInputString() == solutionInputs, "Should return original input string")
end

function PuzzleHintHelperTests.testIsSwapInput()
  local puzzle = Puzzle({
    puzzleType = "moves",
    stack = "000000000011",
    moves = 1
  })
  
  local helper = PuzzleHintHelper(puzzle)
  
  assert(helper:isSwapInput(KeyDataEncoding.swap), "swap character should be recognized as swap input")
  assert(not helper:isSwapInput(KeyDataEncoding.left), "left character should not be recognized as swap input")
  assert(not helper:isSwapInput(KeyDataEncoding.up), "up character should not be recognized as swap input")
  assert(not helper:isSwapInput(KeyDataEncoding.down), "down character should not be recognized as swap input")
  assert(not helper:isSwapInput(KeyDataEncoding.right), "right character should not be recognized as swap input")
end

function PuzzleHintHelperTests.testProcessInputForCursorPosition()
  local puzzle = Puzzle({
    puzzleType = "moves",
    stack = "000000000011",
    moves = 1
  })
  
  local helper = PuzzleHintHelper(puzzle)
  
  -- Test cursor movement from position (5, 3)
  local row, column = helper:processInputForCursorPosition(KeyDataEncoding.left, 5, 3)
  assert(row == 5 and column == 2, "Left movement should decrease column")
  
  row, column = helper:processInputForCursorPosition(KeyDataEncoding.right, 5, 3)
  assert(row == 5 and column == 4, "Right movement should increase column")
  
  row, column = helper:processInputForCursorPosition(KeyDataEncoding.up, 5, 3)
  assert(row == 6 and column == 3, "Up movement should increase row")
  
  row, column = helper:processInputForCursorPosition(KeyDataEncoding.down, 5, 3)
  assert(row == 4 and column == 3, "Down movement should decrease row")
  
  row, column = helper:processInputForCursorPosition(KeyDataEncoding.swap, 5, 3) -- swap (no movement)
  assert(row == 5 and column == 3, "Swap should not change position")
end

function PuzzleHintHelperTests.testProcessInputForCursorPositionBoundaries()
  local puzzle = Puzzle({
    puzzleType = "moves",
    stack = "000000000011",
    moves = 1
  })
  
  local helper = PuzzleHintHelper(puzzle)
  
  -- Test left boundary (column 1)
  local row, column = helper:processInputForCursorPosition(KeyDataEncoding.left, 5, 1)
  assert(row == 5 and column == 1, "Should not go below column 1")
  
  -- Test right boundary (column 5)
  row, column = helper:processInputForCursorPosition(KeyDataEncoding.right, 5, 5)
  assert(row == 5 and column == 5, "Should not go above column 5")
  
  -- Test bottom boundary (row 1)
  row, column = helper:processInputForCursorPosition(KeyDataEncoding.down, 1, 3)
  assert(row == 1 and column == 3, "Should not go below row 1")
  
  -- Test top boundary (row 12)
  row, column = helper:processInputForCursorPosition(KeyDataEncoding.up, 12, 3)
  assert(row == 12 and column == 3, "Should not go above row 12")
end

function PuzzleHintHelperTests.testExtractSwapPositions()
  -- Create solution with multiple moves and swaps
  local solutionInputs = KeyDataEncoding.right .. KeyDataEncoding.right .. KeyDataEncoding.swap .. KeyDataEncoding.left .. KeyDataEncoding.up .. KeyDataEncoding.up .. KeyDataEncoding.swap
  local compressedSolution = InputCompression.compressInputString(solutionInputs)
  
  local puzzle = Puzzle({
    puzzleType = "moves",
    stack = "000000000011",
    moves = 2,
    cursorStartLeft = {row = 1, column = 1},
    solution = compressedSolution
  })
  
  local helper = PuzzleHintHelper(puzzle)
  
  assert(helper:getSolutionSwapCount() == 2, "Should extract 2 swaps from solution")
  
  local swapPositions = helper.solutionSwapPositions
  assert(swapPositions[1].row == 1 and swapPositions[1].column == 3, "First swap should be at (1,3)")
  assert(swapPositions[2].row == 3 and swapPositions[2].column == 2, "Second swap should be at (3,2)")
end

function PuzzleHintHelperTests.testIsPlayerInSync()
  local solutionInputs = KeyDataEncoding.right .. KeyDataEncoding.right .. KeyDataEncoding.swap .. KeyDataEncoding.left .. KeyDataEncoding.up .. KeyDataEncoding.up .. KeyDataEncoding.swap
  local compressedSolution = InputCompression.compressInputString(solutionInputs)
  
  local puzzle = Puzzle({
    puzzleType = "moves",
    stack = "000000000011",
    moves = 2,
    cursorStartLeft = {row = 1, column = 1},
    solution = compressedSolution
  })
  
  local helper = PuzzleHintHelper(puzzle)
  
  -- Test empty player swaps (in sync)
  assert(helper:isPlayerInSync({}), "Empty player swaps should be in sync")
  
  -- Test correct first swap
  local playerSwaps1 = {{row = 1, column = 3}}
  assert(helper:isPlayerInSync(playerSwaps1), "Correct first swap should be in sync")
  
  -- Test incorrect first swap
  local playerSwaps2 = {{row = 1, column = 2}}
  assert(not helper:isPlayerInSync(playerSwaps2), "Incorrect first swap should not be in sync")
  
  -- Test correct two swaps
  local playerSwaps3 = {{row = 1, column = 3}, {row = 3, column = 2}}
  assert(helper:isPlayerInSync(playerSwaps3), "Correct two swaps should be in sync")
  
  -- Test too many swaps
  local playerSwaps4 = {{row = 1, column = 3}, {row = 3, column = 2}, {row = 1, column = 1}}
  assert(not helper:isPlayerInSync(playerSwaps4), "Too many swaps should not be in sync")
end

function PuzzleHintHelperTests.testGetNextHint()
  local solutionInputs = KeyDataEncoding.right .. KeyDataEncoding.right .. KeyDataEncoding.swap .. KeyDataEncoding.left .. KeyDataEncoding.up .. KeyDataEncoding.up .. KeyDataEncoding.swap
  local compressedSolution = InputCompression.compressInputString(solutionInputs)
  
  local puzzle = Puzzle({
    puzzleType = "moves",
    stack = "000000000011",
    moves = 2,
    cursorStartLeft = {row = 1, column = 1},
    solution = compressedSolution
  })
  
  local helper = PuzzleHintHelper(puzzle)
  
  -- Test getting first hint
  local hint1 = helper:getNextHint(0)
  assert(hint1 ~= nil, "Should get first hint")
  assert(hint1.row == 1 and hint1.column == 3, "First hint should be (1,3)")
  
  -- Test getting second hint
  local hint2 = helper:getNextHint(1)
  assert(hint2 ~= nil, "Should get second hint")
  assert(hint2.row == 3 and hint2.column == 2, "Second hint should be (3,2)")
  
  -- Test getting hint when no more swaps
  local hint3 = helper:getNextHint(2)
  assert(hint3 == nil, "Should get nil when no more swaps")
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
  
  local helper1 = PuzzleHintHelper(movesPuzzle)
  local helper2 = PuzzleHintHelper(chainPuzzle)
  local helper3 = PuzzleHintHelper(clearPuzzle)
  
  assert(helper1:isMovePuzzle(), "Moves puzzle should be identified as move puzzle")
  assert(not helper2:isMovePuzzle(), "Chain puzzle should not be identified as move puzzle")
  assert(not helper3:isMovePuzzle(), "Clear puzzle should not be identified as move puzzle")
end

function PuzzleHintHelperTests.testParseEmptySolution()
  local puzzle = Puzzle({
    puzzleType = "moves",
    stack = "000000000011",
    moves = 1,
    solution = "" -- empty solution
  })
  
  local helper = PuzzleHintHelper(puzzle)
  
  assert(helper:hasSolution(), "Should have solution even if empty")
  assert(helper:getSolutionSwapCount() == 0, "Empty solution should have 0 swaps")
  assert(helper:getSolutionInputString() == "", "Empty solution should return empty string")
end

function PuzzleHintHelperTests.testDefaultCursorPosition()
  local solutionInputs = KeyDataEncoding.swap -- just swap at starting position
  local compressedSolution = InputCompression.compressInputString(solutionInputs)
  
  local puzzle = Puzzle({
    puzzleType = "moves",
    stack = "000000000011",
    moves = 1,
    -- no cursorStartLeft specified, should default to (1,1)
    solution = compressedSolution
  })
  
  local helper = PuzzleHintHelper(puzzle)
  
  assert(helper:getSolutionSwapCount() == 1, "Should have 1 swap")
  local swapPos = helper.solutionSwapPositions[1]
  assert(swapPos.row == 7 and swapPos.column == 3, "Swap should be at default position (7,3)")
end

return PuzzleHintHelperTests