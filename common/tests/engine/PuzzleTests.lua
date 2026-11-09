local Puzzle = require("common.engine.Puzzle")
local class = require("common.lib.class")

local PuzzleTests = class(function() end)

function PuzzleTests.validationCountdown()
-- Purposeful wrong type
---@diagnostic disable-next-line: assign-type-mismatch
  local puzzle = Puzzle({puzzleType = "moves", startTiming = "idc", moves = 5, stack = "1254216999999952"})
  local isValid, validationMessage = puzzle:validate()

  assert(not isValid)
  assert(string.match(validationMessage, "startTiming"))
end

function PuzzleTests.validationPuzzleType()
-- Purposeful wrong type
---@diagnostic disable-next-line: assign-type-mismatch
  local puzzle = Puzzle({puzzleType = "garbageGoal", startTiming = "immediately", moves = 5, stack = "1254216999999952"})
  local isValid, validationMessage = puzzle:validate()

  assert(not isValid)
  assert(string.match(validationMessage, "puzzle type"))

  -- Make sure the warning names the valid puzzle types
  for _, puzzleType in pairs(Puzzle.PUZZLE_TYPES) do
    assert(string.find(validationMessage, puzzleType, 1, true),
           "the warning message should talk about puzzle type " .. puzzleType .. ", but got: " .. validationMessage)
  end
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
  local puzzle = Puzzle({puzzleType = "clear", moves = 3,
                         stack = "[==================================]000060500014600011300024502542203135466243",
                         garbagePanelBuffer = "999999"})
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

function PuzzleTests.clearGameModeWaitsForTheGarbageBuffer()
  local puzzle = Puzzle({puzzleType = "clear", stack = "[====]112122", garbagePanelBuffer = "334344556566112122445455661611223233"})
  assert(puzzle:validate())
  local mode = puzzle:toGameMode()
  assert(mode.matchRules.stackWinConditions["GARBAGE_BUFFER_EXCEEDED"] == 0)
  local conditions = 0
  for _ in pairs(mode.matchRules.stackWinConditions) do
    conditions = conditions + 1
  end
  assert(conditions == 1, "revealing the buffer is the whole goal")
  assert(mode.matchRules.stackOverConditions["HEALTH"] == 0)

  local partialRow = Puzzle({puzzleType = "clear", stack = "[====]112122", garbagePanelBuffer = "3343"})
  assert(partialRow:toGameMode().matchRules.stackWinConditions["GARBAGE_BUFFER_EXCEEDED"] == 0)
end

-- the buffer holds whole rows, so a partial last row is filled with grey rather than counting as running out
function PuzzleTests.aPartialLastGarbageRowIsFilledWithGrey()
  local source = Puzzle({puzzleType = "clear", stack = "[====]112122", garbagePanelBuffer = "3343"}):toPanelSource()
  assert(source.garbagePanelBuffer == "334399", "got " .. source.garbagePanelBuffer)
end

-- a clear puzzle without a buffer has no rows for the player to see, so its first revealed row runs past it
function PuzzleTests.aClearPuzzleWithoutABufferRunsPastItOnTheFirstRevealedRow()
  local noBuffer = Puzzle({puzzleType = "clear", stack = "[====]112122"})

  assert(noBuffer:validate())
  local winConditions = noBuffer:toGameMode().matchRules.stackWinConditions
  assert(winConditions["GARBAGE_BUFFER_EXCEEDED"] == 0, "every clear puzzle is won by running past its buffer")
  assert(winConditions["MATCHABLE_GARBAGE_PANELS"] == nil, "hitting every block is no longer a puzzle goal")
end

function PuzzleTests.validationGarbageBufferColors()
  local empty = Puzzle({puzzleType = "clear", stack = "[====]112122", garbagePanelBuffer = "000000334344"})
  local isValid, validationMessage = empty:validate()
  assert(not isValid)
  assert(string.match(validationMessage, "GarbagePanelBuffer"))

  local letters = Puzzle({puzzleType = "clear", stack = "[====]112122", garbagePanelBuffer = "33434a"})
  assert(not letters:validate())

  local colors = Puzzle({puzzleType = "clear", stack = "[====]112122", garbagePanelBuffer = "334344999599"})
  assert(colors:validate())
end

-- a buffer is what tells a clear puzzle apart from one about its board, so a buffer of nothing has to
-- read as no buffer rather than as a goal that is already met
function PuzzleTests.anEmptyGarbageBufferIsTheSameAsNone()
  local none = Puzzle({puzzleType = "moves", stack = "[====]112122", moves = 1})
  local empty = Puzzle({puzzleType = "moves", stack = "[====]112122", moves = 1, garbagePanelBuffer = ""})

  assert(empty.garbageBuffer == nil, "an empty buffer is no buffer, got " .. tostring(empty.garbageBuffer))
  assert(empty:getSaveData()[Puzzle.PUZZLE_PROPERTY.GARBAGE_PANEL_BUFFER] == nil, "an empty buffer is not written to the file")
  assert(Puzzle.getV2UUID(empty) == Puzzle.getV2UUID(none), "an empty buffer does not change the puzzle's identity")
end

PuzzleTests.anEmptyGarbageBufferIsTheSameAsNone()
PuzzleTests.validationGarbageBufferColors()
PuzzleTests.clearGameModeWaitsForTheGarbageBuffer()
PuzzleTests.aPartialLastGarbageRowIsFilledWithGrey()
PuzzleTests.aClearPuzzleWithoutABufferRunsPastItOnTheFirstRevealedRow()
PuzzleTests.validationCountdown()
PuzzleTests.validationPuzzleType()
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

local function countKeys(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end

function PuzzleTests.goalsAreReadFromTheirFileSpelling()
  local chain = Puzzle.parseGoal("x4")
  assert(chain and chain.kind == "chain" and chain.size == 4)
  local combo = Puzzle.parseGoal("+6")
  assert(combo and combo.kind == "combo" and combo.size == 6)
  local emptyBoard = Puzzle.parseGoal("empty board")
  assert(emptyBoard and emptyBoard.kind == "emptyBoard")
  local clear = Puzzle.parseGoal("CLEAR")
  assert(clear and clear.kind == "clear")
  assert(Puzzle.parseGoal("x") == nil)
  assert(Puzzle.parseGoal("chain") == nil, "the old chain rule cannot be asked for by a goal list")
  assert(Puzzle.parseGoal(4) == nil)
end

function PuzzleTests.goalsAreWrittenInTheirFileSpelling()
  local puzzle = Puzzle({goals = {"empty board", "X4", "+6", "+6"}, stack = "011010"})
  local written = puzzle:getSaveData()["Puzzle Type"]
  assert(table.concat(written, ",") == "Empty Board,x4,+6,+6")
end

function PuzzleTests.aLegacyTypeBecomesItsGoals()
  local moves = Puzzle({puzzleType = "moves", moves = 1, stack = "011010"})
  assert(#moves.goals == 1 and moves.goals[1].kind == "emptyBoard")
  local clear = Puzzle({puzzleType = "clear", stack = "[====]112122", garbagePanelBuffer = "334344"})
  assert(#clear.goals == 1 and clear.goals[1].kind == "clear")
  local chain = Puzzle({puzzleType = "chain", stack = "011010"})
  assert(#chain.goals == 1 and chain.goals[1].kind == "legacyChain")
  assert(chain:getSaveData(true)["Puzzle Type"] == "chain", "a version 3 file keeps the one word type")
end

function PuzzleTests.theLegacyShapesKeepTheirUuid()
  assert(Puzzle({puzzleType = "moves", moves = 1, stack = "011010"}).UUID
    == "d17b0e3f0747c4a18b0398a7bcc86e556c068d873f350b85880a6f8efeaa0aba")
  assert(Puzzle({goals = {"Empty Board"}, moves = 1, stack = "011010"}).UUID
    == "d17b0e3f0747c4a18b0398a7bcc86e556c068d873f350b85880a6f8efeaa0aba")
  assert(Puzzle({puzzleType = "chain", stack = "011010"}).UUID == "a4d352439dabe32af28f38653c47d50eee76a67ee30eef27929820430e394b22")
  assert(Puzzle({puzzleType = "clear", stack = "[====]112122", garbagePanelBuffer = "334344"}).UUID
    == "72f404eb985581584ecbbc0ebf3e915a134f1e9569d25f474ee60083f907e235")
  assert(Puzzle({goals = {"Empty Board", "x2"}, moves = 1, stack = "011010"}).UUID
    ~= Puzzle({goals = {"Empty Board"}, moves = 1, stack = "011010"}).UUID, "another goal makes another puzzle")
end

function PuzzleTests.chainAndComboGoalsBecomeCountedWinConditions()
  local puzzle = Puzzle({goals = {"x2", "x2", "x4", "+6"}, moves = 3, stack = "011010"})
  assert(puzzle:validate())
  local rules = puzzle:toGameMode().matchRules
  assert(rules.stackWinConditions["CHAINS"][2] == 2)
  assert(rules.stackWinConditions["CHAINS"][4] == 1)
  assert(rules.stackWinConditions["COMBOS"][6] == 1)
  assert(countKeys(rules.stackWinConditions) == 2, "the board does not have to be emptied unless that is asked for")
  assert(rules.stackOverConditions["GOALS_UNREACHABLE"] == true)
  assert(rules.stackOverConditions["SWAPS"] == 3)
  assert(rules.stackSetupModifications.behaviours.passiveRaise == false)
end

function PuzzleTests.emptyBoardAndClearCanBeAskedForTogether()
  local puzzle = Puzzle({goals = {"Empty Board", "Clear"}, stack = "[====]112122", garbagePanelBuffer = "334344"})
  assert(puzzle:validate())
  local rules = puzzle:toGameMode().matchRules
  assert(rules.stackWinConditions["MATCHABLE_PANELS"] == 0)
  assert(rules.stackWinConditions["GARBAGE_BUFFER_EXCEEDED"] == 0)
  assert(rules.stackOverConditions["HEALTH"] == 0)
  assert(rules.stackSetupModifications.behaviours.passiveRaise == nil, "a puzzle with a clear goal rises like a clear puzzle")
end

function PuzzleTests.validationGoals()
  local none = Puzzle({goals = {}, stack = "011010"})
  local isValid, message = none:validate()
  assert(not isValid and string.match(message, "at least one goal"))

  local unknown = Puzzle({goals = {"x4", "big chain"}, stack = "011010"})
  isValid, message = unknown:validate()
  assert(not isValid and string.match(message, "big chain"))

  isValid = Puzzle({goals = {"x1"}, stack = "011010"}):validate()
  assert(not isValid, "a chain starts at x2")
  isValid = Puzzle({goals = {"+3"}, stack = "011010"}):validate()
  assert(not isValid, "a match of three is not a combo")
end

function PuzzleTests.anEmptyBoardPuzzleNeedsNoSwapLimit()
  assert(Puzzle({goals = {"Empty Board"}, moves = 0, stack = "011010"}):validate())
end

function PuzzleTests.anEmptyBoardPuzzleWithoutASwapLimitCanStillBeLost()
  local rules = Puzzle({goals = {"Empty Board"}, moves = 0, stack = "011010"}):toGameMode().matchRules
  assert(rules.stackOverConditions["GOALS_UNREACHABLE"] == true, "stranding a color has to end the puzzle, nothing else would")
end

function PuzzleTests.aSwapLimitThatIsNotANumberIsInvalid()
  ---@diagnostic disable-next-line: assign-type-mismatch
  local isValid, validationMessage = Puzzle({goals = {"Empty Board"}, moves = "abc", stack = "011010"}):validate()
  assert(not isValid, "the swap limit is compared with the swap count once the puzzle starts")
  assert(string.match(validationMessage, "Moves"))
end

function PuzzleTests.aNegativeSwapLimitIsInvalid()
  local isValid = Puzzle({goals = {"Empty Board"}, moves = -1, stack = "011010"}):validate()
  assert(not isValid, "a negative limit is neither a limit nor the absence of one")
end

function PuzzleTests.aMovesPuzzleWithoutASwapLimitIsValid()
  assert(Puzzle({puzzleType = "moves", moves = 0, stack = "011010"}):validate())
end

function PuzzleTests.goalsSurviveAnEditedBoard()
  local original = Puzzle({goals = {"x2", "+4"}, moves = 2, stack = "011010"})
  local edited = Puzzle.newPuzzleWithPuzzleString("022020", original)
  assert(table.concat(edited:getSaveData()["Puzzle Type"], ",") == "x2,+4")
end

PuzzleTests.goalsAreReadFromTheirFileSpelling()
PuzzleTests.goalsAreWrittenInTheirFileSpelling()
PuzzleTests.aLegacyTypeBecomesItsGoals()
PuzzleTests.theLegacyShapesKeepTheirUuid()
PuzzleTests.chainAndComboGoalsBecomeCountedWinConditions()
PuzzleTests.emptyBoardAndClearCanBeAskedForTogether()
PuzzleTests.validationGoals()
PuzzleTests.anEmptyBoardPuzzleNeedsNoSwapLimit()
PuzzleTests.anEmptyBoardPuzzleWithoutASwapLimitCanStillBeLost()
PuzzleTests.goalsSurviveAnEditedBoard()
PuzzleTests.aSwapLimitThatIsNotANumberIsInvalid()
PuzzleTests.aNegativeSwapLimitIsInvalid()
PuzzleTests.aMovesPuzzleWithoutASwapLimitIsValid()
