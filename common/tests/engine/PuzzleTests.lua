local Puzzle = require("common.engine.Puzzle")
local class = require("common.lib.class")

local PuzzleTests = class(function() end)

function PuzzleTests.validationCountdown()
  local puzzle = Puzzle({puzzleType = "moves", startTiming = "idc", moves = 5, stack = "1254216999999952"})
  local isValid, validationMessage = puzzle:validate()

  assert(not isValid)
  assert(string.match(validationMessage, "startTiming"))
end

function PuzzleTests.validationPuzzleType()
  local puzzle = Puzzle({puzzleType = "garbageGoal", startTiming = "immediately", moves = 5, stack = "1254216999999952"})
  local isValid, validationMessage = puzzle:validate()

  assert(not isValid)
  assert(string.match(validationMessage, "puzzle type"))
end

function PuzzleTests.validationMoves()
  local puzzle = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 0, stack = "1254216999999952"})
  local isValid, validationMessage = puzzle:validate()

  assert(not isValid)
  assert(string.match(validationMessage, "expecting a number greater than zero"))
end

function PuzzleTests.validationStackCharacters()
  local puzzle = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 3, stack = "12542169999f9952"})
  local isValid, validationMessage = puzzle:validate()

  assert(not isValid)
  assert(string.match(validationMessage, "invalid characters: f"))
end

function PuzzleTests.validationStackLength()
  local puzzle = Puzzle({puzzleType = "moves", moves = 2, stack= "1254216999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999952"})
  local isValid, validationMessage = puzzle:validate()

  assert(not isValid)
  assert(string.match(validationMessage, "Panels above the top"))
end

function PuzzleTests.validationStackLength2()
  local puzzle = Puzzle({puzzleType = "clear", moves = 3, stack = "[==================================]000060500014600011300024502542203135466243"})
  local isValid = puzzle:validate()

  assert(isValid)
end

function PuzzleTests.validationGarbageCoherence1()
  local puzzle = Puzzle({puzzleType = "moves", moves = 2, stack = "929999[==========}040000224999949999"})
  local isValid, validationMessage = puzzle:validate()

  assert(not isValid)
  assert(string.match(validationMessage, "invalid garbage notation"))
end

function PuzzleTests.validationGarbageCoherence2()
  local puzzle = Puzzle({puzzleType = "moves", moves = 2, stack= "929999[====[====]]040000224999949999"})
  local isValid, validationMessage = puzzle:validate()

  assert(not isValid)
  assert(string.match(validationMessage, "invalid garbage notation"))
end

function PuzzleTests.validationGarbageCoherence3()
  local puzzle = Puzzle({puzzleType = "moves", moves = 2, stack = "{====}929999[======]040000224999949999"})
  local isValid, validationMessage = puzzle:validate()

  assert(not isValid)
  assert(string.match(validationMessage, "length"))
end

function PuzzleTests.validationGarbageCoherence4()
  local puzzle = Puzzle({puzzleType = "moves", moves = 2, stack = "9299[===]99040000224999949999"})
  local isValid, validationMessage = puzzle:validate()

  assert(not isValid)
  assert(string.match(validationMessage, "extend"))
end

function PuzzleTests.validationValid()
  local puzzle = Puzzle({puzzleType = "moves", moves = 2, stack = "{====}929999[====]040000224999949999"})
  local isValid, validationMessage = puzzle:validate()

  assert(isValid)
  assert(validationMessage == "")
end

PuzzleTests.validationCountdown()
PuzzleTests.validationPuzzleType()
PuzzleTests.validationMoves()
PuzzleTests.validationStackLength()
PuzzleTests.validationStackLength2()
PuzzleTests.validationStackCharacters()
PuzzleTests.validationGarbageCoherence1()
PuzzleTests.validationGarbageCoherence2()
PuzzleTests.validationGarbageCoherence3()
PuzzleTests.validationGarbageCoherence4()
PuzzleTests.validationValid()

function PuzzleTests.testFilledPuzzleString()
  local puzzle = Puzzle({puzzleType = "moves", moves = 5, stack = "123"})
  local filledString = puzzle:fillMissingPanelsInPuzzleString(6, 12)
  assert(filledString ~= puzzle.stack)
  assert(filledString:len() == 72)
  assert(filledString == "000000000000000000000000000000000000000000000000000000000000000000000123")
end

PuzzleTests.testFilledPuzzleString()

function PuzzleTests.testRandomizeColors()
  local puzzleString = "{====}929999[====]040000224999949999"
  -- Technically its correct that sometimes we will get the same colors.
  -- Pick a constant seed that we found gives a different color set then the original
  love.math.setRandomSeed(1)
  local randomizedString = Puzzle.randomizeColorsInPuzzleString(puzzleString)
  assert(randomizedString:len() == puzzleString:len())
  assert(randomizedString ~= puzzleString)
end

PuzzleTests.testRandomizeColors()

function PuzzleTests.testRandomizeColorsSometimesSameColors()
  local puzzleString = "{====}929999[====]040000224999949999"
  -- Technically its correct that sometimes we will get the same colors.
  -- Pick a constant seed that we found gives the same colors
  love.math.setRandomSeed(9)
  local randomizedString = Puzzle.randomizeColorsInPuzzleString(puzzleString)
  assert(randomizedString:len() == puzzleString:len())
  assert(randomizedString == puzzleString)
end

PuzzleTests.testRandomizeColorsSometimesSameColors()

function PuzzleTests.testNewPuzzleWithPuzzleString()
  local originalPuzzle = Puzzle({
    puzzleType = "moves", 
    startTiming = "countdown", 
    moves = 5, 
    stack = "1254216999999952",
    stopTime = 10,
    shakeTime = 5,
    panelBuffer = "000111222",
    garbagePanelBuffer = "333444555",
    cursorStartLeft = {row = 3, column = 2}
  })
  
  local newPuzzleString = "9876543210987654"
  local newPuzzle = Puzzle.newPuzzleWithPuzzleString(newPuzzleString, originalPuzzle)
  
  assert(newPuzzle.puzzleType == originalPuzzle.puzzleType)
  assert(newPuzzle.startTiming == originalPuzzle.startTiming)
  assert(newPuzzle.moves == originalPuzzle.moves)
  assert(newPuzzle.stack == newPuzzleString)
  assert(newPuzzle.stopTime == originalPuzzle.stopTime)
  assert(newPuzzle.shakeTime == originalPuzzle.shakeTime)
  assert(newPuzzle.panelBuffer == originalPuzzle.panelBuffer)
  assert(newPuzzle.garbageBuffer == originalPuzzle.garbageBuffer)
  assert(newPuzzle.cursorStartLeft.row == originalPuzzle.cursorStartLeft.row)
  assert(newPuzzle.cursorStartLeft.column == originalPuzzle.cursorStartLeft.column)
end

function PuzzleTests.testNewPuzzleWithPuzzleStringMinimal()
  local originalPuzzle = Puzzle({
    puzzleType = "chain", 
    stack = "1111111111111111"
  })
  
  local newPuzzleString = "2222222222222222"
  local newPuzzle = Puzzle.newPuzzleWithPuzzleString(newPuzzleString, originalPuzzle)
  
  assert(newPuzzle.puzzleType == "chain")
  assert(newPuzzle.stack == newPuzzleString)
  assert(newPuzzle.moves == 0)
  assert(newPuzzle.cursorStartLeft == nil)
end

PuzzleTests.testNewPuzzleWithPuzzleString()
PuzzleTests.testNewPuzzleWithPuzzleStringMinimal()