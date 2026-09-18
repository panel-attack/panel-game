local Stack = require("common.engine.Stack")
require("common.engine.checkMatches")

local function assertLines(comboSize, expectedLines)
  local lines = Stack.getEstimatedGarbageLinesForCombo(comboSize)
  assert(lines == expectedLines, "combo " .. comboSize .. " should send " .. expectedLines .. " lines but sent " .. lines)
end

local function comboTooSmallSendsNothing()
  assertLines(3, 0)
end

local function widthThreePieceCountsAsHalfLine()
  assertLines(4, 0.5)
end

local function widthFourPieceCountsAsFullLine()
  assertLines(5, 1)
end

local function mixedPiecesAddUp()
  assertLines(8, 1.5)
end

local function fullWidthPiecesCountOneLineEach()
  assertLines(13, 3)
end

local function combosBetweenListedSizesUseTheSmallerSize()
  assertLines(19, 4)
  assertLines(26, 6)
end

local function largestComboSendsEightLines()
  assertLines(72, 8)
end

comboTooSmallSendsNothing()
widthThreePieceCountsAsHalfLine()
widthFourPieceCountsAsFullLine()
mixedPiecesAddUp()
fullWidthPiecesCountOneLineEach()
combosBetweenListedSizesUseTheSmallerSize()
largestComboSendsEightLines()
