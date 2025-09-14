local PuzzleSetIterator = require("client.src.PuzzleSetIterator")
local PuzzleSet = require("client.src.PuzzleSet")
local Puzzle = require("common.engine.Puzzle")
local PuzzleLibrary = require("client.src.PuzzleLibrary")
local class = require("common.lib.class")

local PuzzleSetIteratorTests = class(function() end)

function PuzzleSetIteratorTests.testClassExists()
  -- Test that PuzzleSetIterator class exists and can be instantiated
  assert(PuzzleSetIterator ~= nil, "PuzzleSetIterator class should exist")
  
  -- Test that we can instantiate the class
  local iterator = PuzzleSetIterator()
  assert(iterator ~= nil, "PuzzleSetIterator should be instantiable")
end

function PuzzleSetIteratorTests.testNextPuzzleMethod()
  -- Test that nextPuzzle method returns puzzleSetIndices correctly
  local puzzle1 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 5, stack = "1254216999999952"})
  local puzzle2 = Puzzle({puzzleType = "chain", startTiming = "countdown", moves = 3, stack = "2134567890123456"})
  local puzzleSet = PuzzleSet("Test Set", "Test description", {puzzle1, puzzle2})
  
  local iterator = PuzzleSetIterator(puzzleSet)
  
  -- Test first puzzle indices
  local firstIndices = iterator:nextPuzzle()
  assert(type(firstIndices) == "table", "nextPuzzle should return table of indices")
  assert(#firstIndices == 1 and firstIndices[1] == 1, "First call should return {1} for first puzzle in root set")
  
  -- Test second puzzle indices  
  local secondIndices = iterator:nextPuzzle()
  assert(type(secondIndices) == "table", "nextPuzzle should return table of indices")
  assert(#secondIndices == 1 and secondIndices[1] == 2, "Second call should return {2} for second puzzle in root set")
  
  -- Test nil when no more puzzles
  local noIndices = iterator:nextPuzzle()
  assert(noIndices == nil, "nextPuzzle should return nil when no more puzzles")
end

function PuzzleSetIteratorTests.testMakePuzzleSetIterator()
  -- Test makePuzzleSetIterator factory method with breadth-first ordering on root
  local puzzle1 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 1, stack = "1111111111111111"})
  local puzzle2 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 2, stack = "2222222222222222"})
  local puzzle3 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 3, stack = "3333333333333333"})
  local puzzle4 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 4, stack = "4444444444444444"})
  
  -- Create nested puzzle sets
  local childSet1 = PuzzleSet("Child 1", "Child description 1", {puzzle3})
  local childSet2 = PuzzleSet("Child 2", "Child description 2", {puzzle4})
  local parentSet = PuzzleSet("Parent", "Parent description", {puzzle1, puzzle2}, {childSet1, childSet2})
  
  -- Test with empty indices to iterate through root set (breadth-first)
  local iterator = PuzzleSetIterator.makePuzzleSetIterator(parentSet, {})
  
  -- Should iterate through parent puzzles first (breadth-first), then child puzzles
  local first = iterator:nextPuzzle()
  assert(type(first) == "table" and #first == 1 and first[1] == 1, "Should get indices {1} for first parent puzzle")
  
  local second = iterator:nextPuzzle()
  assert(type(second) == "table" and #second == 1 and second[1] == 2, "Should get indices {2} for second parent puzzle")
  
  local third = iterator:nextPuzzle()
  assert(type(third) == "table" and #third == 2 and third[1] == 1 and third[2] == 1, "Should get indices {1,1} for first child puzzle (breadth-first)")
  
  local fourth = iterator:nextPuzzle()
  assert(type(fourth) == "table" and #fourth == 2 and fourth[1] == 2 and fourth[2] == 1, "Should get indices {2,1} for second child puzzle (breadth-first)")
  
  local none = iterator:nextPuzzle()
  assert(none == nil, "Should return nil when no more puzzles")
end

function PuzzleSetIteratorTests.testMakePuzzleSetIteratorWithStartIndex()
  -- Test makePuzzleSetIterator with starting index
  local puzzle1 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 1, stack = "1111111111111111"})
  local puzzle2 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 2, stack = "2222222222222222"})
  local puzzle3 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 3, stack = "3333333333333333"})
  
  local puzzleSet = PuzzleSet("Test Set", "Test description", {puzzle1, puzzle2, puzzle3})
  
  -- Start at index 2
  local iterator = PuzzleSetIterator.makePuzzleSetIterator(puzzleSet, {}, 2)
  
  local first = iterator:nextPuzzle()
  assert(type(first) == "table" and #first == 1 and first[1] == 2, "Should start at indices {2}")
  
  local second = iterator:nextPuzzle()
  assert(type(second) == "table" and #second == 1 and second[1] == 3, "Should get indices {3}")
  
  local none = iterator:nextPuzzle()
  assert(none == nil, "Should return nil when no more puzzles")
end

function PuzzleSetIteratorTests.testMakePuzzleSetIteratorWithSpecificChildSet()
  -- Test that puzzleSetIndices navigates to specific child set and only traverses its children
  local puzzle1 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 1, stack = "1111111111111111"})
  local puzzle2 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 2, stack = "2222222222222222"})
  local puzzle3 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 3, stack = "3333333333333333"})
  local puzzle4 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 4, stack = "4444444444444444"})
  local puzzle5 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 5, stack = "5555555555555555"})
  
  -- Create nested structure: root -> child1, child2 where child1 has its own children
  local grandchild1 = PuzzleSet("Grandchild 1", "Grandchild description 1", {puzzle4})
  local grandchild2 = PuzzleSet("Grandchild 2", "Grandchild description 2", {puzzle5})
  local child1 = PuzzleSet("Child 1", "Child description 1", {puzzle2}, {grandchild1, grandchild2})
  local child2 = PuzzleSet("Child 2", "Child description 2", {puzzle3})
  local root = PuzzleSet("Root", "Root description", {puzzle1}, {child1, child2})
  
  -- Navigate to first child set (index 1) - should only get child1 puzzles and its children
  local iterator = PuzzleSetIterator.makePuzzleSetIterator(root, {1})
  
  -- Should get indices for puzzle2 (from child1), then puzzle4 (from grandchild1), then puzzle5 (from grandchild2)
  -- Should NOT get puzzle1 (from root) or puzzle3 (from child2)
  local first = iterator:nextPuzzle()
  assert(type(first) == "table" and #first == 2 and first[1] == 1 and first[2] == 1, "Should get indices {1,1} for puzzle from child1")
  
  local second = iterator:nextPuzzle()
  assert(type(second) == "table" and #second == 3 and second[1] == 1 and second[2] == 1 and second[3] == 1, "Should get indices {1,1,1} for puzzle from grandchild1")
  
  local third = iterator:nextPuzzle()
  assert(type(third) == "table" and #third == 3 and third[1] == 1 and third[2] == 2 and third[3] == 1, "Should get indices {1,2,1} for puzzle from grandchild2")
  
  local none = iterator:nextPuzzle()
  assert(none == nil, "Should return nil when no more puzzles")
end

function PuzzleSetIteratorTests.testMakePuzzleSetIteratorWithDeepNesting()
  -- Test deep hierarchy navigation with multiple levels
  local puzzle1 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 1, stack = "1111111111111111"})
  local puzzle2 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 2, stack = "2222222222222222"})
  local puzzle3 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 3, stack = "3333333333333333"})
  
  -- Create deep nesting: root -> child -> grandchild
  local grandchild = PuzzleSet("Grandchild", "Grandchild description", {puzzle3})
  local child = PuzzleSet("Child", "Child description", {puzzle2}, {grandchild})
  local root = PuzzleSet("Root", "Root description", {puzzle1}, {child})
  
  -- Iterate everything
  local deepIterator = PuzzleSetIterator.makePuzzleSetIterator(root, {})
  
  assert(puzzle1 == PuzzleSetIterator.getPuzzleFromIndices(root, deepIterator:nextPuzzle()))
  assert(puzzle2 == PuzzleSetIterator.getPuzzleFromIndices(root, deepIterator:nextPuzzle()))
  assert(puzzle3 == PuzzleSetIterator.getPuzzleFromIndices(root, deepIterator:nextPuzzle()))
  assert(nil == PuzzleSetIterator.getPuzzleFromIndices(root, deepIterator:nextPuzzle()))
  
  local none = deepIterator:nextPuzzle()
  assert(none == nil, "Should return nil when no more puzzles")

  -- Navigate to grandchild set (indices {1, 1} = first child of first child)
  local iterator = PuzzleSetIterator.makePuzzleSetIterator(root, {1, 1})
  
  -- Should only get indices for puzzle3 from grandchild
  local first = iterator:nextPuzzle()
  assert(type(first) == "table" and #first == 3 and first[1] == 1 and first[2] == 1 and first[3] == 1, "Should get indices {1,1,1} for puzzle from grandchild")
  
  local none = iterator:nextPuzzle()
  assert(none == nil, "Should return nil when no more puzzles")
end

function PuzzleSetIteratorTests.testMakeTrainingOrderIterator()
  -- Test training order iterator factory method
  local currentTime = to_UTC(os.time())
  
  -- Create puzzles with different training dates
  local puzzle1 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 1, stack = "1111111111111111"})
  puzzle1.trainingDate = currentTime - 100  -- needs training (oldest)
  puzzle1.UUID = "puzzle1-uuid"
  
  local puzzle2 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 2, stack = "2222222222222222"})
  puzzle2.trainingDate = currentTime + 100  -- doesn't need training (future)
  puzzle2.UUID = "puzzle2-uuid"
  
  local puzzle3 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 3, stack = "3333333333333333"})
  puzzle3.trainingDate = currentTime - 50   -- needs training (newer)
  puzzle3.UUID = "puzzle3-uuid"
  
  local puzzle4 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 4, stack = "4444444444444444"})
  puzzle4.trainingDate = currentTime - 100  -- needs training (same as puzzle1, sort by UUID)
  puzzle4.UUID = "puzzle4-uuid"
  
  local puzzleSet = PuzzleSet("Training Set", "Training description", {puzzle1, puzzle2, puzzle3, puzzle4})
  
  -- Create a mock puzzle library to handle the training logic
  local puzzleLibrary = PuzzleLibrary()
  
  -- Create training order iterator
  local iterator = PuzzleSetIterator.makeTrainingOrderIterator(puzzleSet, {}, puzzleLibrary)
  
  -- Should get puzzleSetIndices in training order (oldest first, then by UUID for ties)
  local first = iterator:nextPuzzle()
  assert(type(first) == "table", "Should return puzzleSetIndices table")
  local firstPuzzle = PuzzleSetIterator.getPuzzleFromIndices(puzzleSet, first)
  assert(firstPuzzle == puzzle1 or firstPuzzle == puzzle4, "Should get puzzle with oldest training date first")
  
  local second = iterator:nextPuzzle()
  assert(type(second) == "table", "Should return puzzleSetIndices table")
  local secondPuzzle = PuzzleSetIterator.getPuzzleFromIndices(puzzleSet, second)
  assert(secondPuzzle == puzzle1 or secondPuzzle == puzzle4, "Should get other puzzle with oldest training date")
  assert(secondPuzzle ~= firstPuzzle, "Should be different from first puzzle")
  
  local third = iterator:nextPuzzle()
  assert(type(third) == "table", "Should return puzzleSetIndices table")
  local thirdPuzzle = PuzzleSetIterator.getPuzzleFromIndices(puzzleSet, third)
  assert(thirdPuzzle == puzzle3, "Should get puzzle3 (newer training date)")
  
  -- puzzle2 should not appear because it doesn't need training
  local none = iterator:nextPuzzle()
  assert(none == nil, "Should return nil when no more training puzzles")
end

function PuzzleSetIteratorTests.testGetPuzzleFromIndices()
  -- Test getting puzzle from puzzle set using puzzleSetIndices
  local puzzle1 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 1, stack = "1111111111111111"})
  local puzzle2 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 2, stack = "2222222222222222"})
  local puzzle3 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 3, stack = "3333333333333333"})
  
  -- Create nested puzzle sets
  local childSet = PuzzleSet("Child", "Child description", {puzzle3})
  local parentSet = PuzzleSet("Parent", "Parent description", {puzzle1, puzzle2}, {childSet})
  
  -- Test getting puzzle from root set
  local rootPuzzle1 = PuzzleSetIterator.getPuzzleFromIndices(parentSet, {1})
  assert(rootPuzzle1 == puzzle1, "Should get first puzzle from root set with indices {1}")
  
  local rootPuzzle2 = PuzzleSetIterator.getPuzzleFromIndices(parentSet, {2})
  assert(rootPuzzle2 == puzzle2, "Should get second puzzle from root set with indices {2}")
  
  -- Test getting puzzle from child set
  local childPuzzle = PuzzleSetIterator.getPuzzleFromIndices(parentSet, {1, 1})
  assert(childPuzzle == puzzle3, "Should get puzzle from child set with indices {1,1}")
  
  -- Test invalid indices
  local invalidPuzzle = PuzzleSetIterator.getPuzzleFromIndices(parentSet, {99})
  assert(invalidPuzzle == nil, "Should return nil for invalid indices")
  
  local invalidDeepPuzzle = PuzzleSetIterator.getPuzzleFromIndices(parentSet, {1, 99})
  assert(invalidDeepPuzzle == nil, "Should return nil for invalid deep indices")
end

-- Run the tests
PuzzleSetIteratorTests.testClassExists()
PuzzleSetIteratorTests.testNextPuzzleMethod()
PuzzleSetIteratorTests.testMakePuzzleSetIterator()
PuzzleSetIteratorTests.testMakePuzzleSetIteratorWithStartIndex()
PuzzleSetIteratorTests.testMakePuzzleSetIteratorWithSpecificChildSet()
PuzzleSetIteratorTests.testMakePuzzleSetIteratorWithDeepNesting()
PuzzleSetIteratorTests.testMakeTrainingOrderIterator()
PuzzleSetIteratorTests.testGetPuzzleFromIndices()

return PuzzleSetIteratorTests