local class = require("common.lib.class")
local InputCompression = require("common.data.InputCompression")
local KeyDataEncoding = require("common.data.KeyDataEncoding")

---@class PuzzleHintHelper
---@field puzzle Puzzle
---@field solutionInputs string[]? decompressed solution input array
---@field currentSwapCount integer number of swaps player has made
---@field solutionSwapPositions table[] array of {row=number, column=number} positions for each swap in solution
PuzzleHintHelper = class(
  function(self, puzzle)
    self.puzzle = puzzle
    self.solutionInputs = nil
    self.currentSwapCount = 0
    self.solutionSwapPositions = {}
    
    if puzzle.solution then
      self:parseSolution()
    end
  end
)

---Parse the compressed solution into input array and extract swap positions
function PuzzleHintHelper:parseSolution()
  if not self.puzzle.solution then
    return
  end
  
  local decompressedInputs = InputCompression.decompressInputString2(self.puzzle.solution)
  self.solutionInputs = {}
  
  -- Convert input string to array of individual characters
  for i = 1, #decompressedInputs do
    self.solutionInputs[i] = string.sub(decompressedInputs, i, i)
  end
  
  -- Extract swap positions from solution
  self:extractSwapPositions()
end

---Extract the cursor positions where swaps occur in the solution
function PuzzleHintHelper:extractSwapPositions()
  if not self.solutionInputs then
    return
  end
  
  self.solutionSwapPositions = {}
  local cursorRow = self.puzzle.cursorStartLeft and self.puzzle.cursorStartLeft.row or 7
  local cursorColumn = self.puzzle.cursorStartLeft and self.puzzle.cursorStartLeft.column or 3
  local lastInputIdle = false
  for i, input in ipairs(self.solutionInputs) do
    if input == KeyDataEncoding.idle then
      lastInputIdle = true
    else
      if self:isSwapInput(input) then
        table.insert(self.solutionSwapPositions, {row = cursorRow, column = cursorColumn})
      elseif lastInputIdle then
        cursorRow, cursorColumn = self:processInputForCursorPosition(input, cursorRow, cursorColumn)
      end
      lastInputIdle = false
    end
  end
end

---Check if an input character represents a swap action
---@param input string single character input
---@return boolean
function PuzzleHintHelper:isSwapInput(input)
  local raise, swap, up, down, left, right = unpack(KeyDataEncoding.base64decode[input])
  return swap
end

---Process input to determine new cursor position
---@param input string single character input
---@param currentRow integer current cursor row
---@param currentColumn integer current cursor column
---@return integer newRow, integer newColumn
function PuzzleHintHelper:processInputForCursorPosition(input, currentRow, currentColumn)
  local newRow = currentRow
  local newColumn = currentColumn
  
  if input == KeyDataEncoding.left then
    newColumn = math.max(1, currentColumn - 1)
  elseif input == KeyDataEncoding.right then
    newColumn = math.min(5, currentColumn + 1) -- max column is 5 (6 columns, 0-indexed becomes 1-5)
  elseif input == KeyDataEncoding.up then
    newRow = math.min(12, currentRow + 1)
  elseif input == KeyDataEncoding.down then
    newRow = math.max(1, currentRow - 1)
  end
  
  return newRow, newColumn
end

---Check if player is in sync with solution at current swap count
---@param playerSwapPositions table[] array of {row=number, column=number} where player made swaps
---@return boolean isInSync
function PuzzleHintHelper:isPlayerInSync(playerSwapPositions)
  if not self.solutionSwapPositions or #playerSwapPositions == #self.solutionSwapPositions then
    return false
  end
  
  -- Check if all player swaps match solution swaps up to current position
  for i = 1, #playerSwapPositions do
    if i > #self.solutionSwapPositions then
      return false -- player has made more swaps than solution
    end
    
    local playerPos = playerSwapPositions[i]
    local solutionPos = self.solutionSwapPositions[i]
    
    if playerPos.row ~= solutionPos.row or playerPos.column ~= solutionPos.column then
      return false
    end
  end
  
  return true
end

---Get the next hint (cursor position for next swap)
---@param currentSwapCount integer number of swaps player has made so far
---@return table? nextSwapPosition {row=number, column=number} or nil if no more swaps
function PuzzleHintHelper:getNextHint(currentSwapCount)
  if not self.solutionSwapPositions then
    return nil
  end
  
  local nextSwapIndex = currentSwapCount + 1
  if nextSwapIndex > #self.solutionSwapPositions then
    return nil -- no more swaps in solution
  end
  
  return self.solutionSwapPositions[nextSwapIndex]
end

---Get the full solution input string
---@return string? solutionInputString or nil if no solution
function PuzzleHintHelper:getSolutionInputString()
  if not self.solutionInputs then
    return nil
  end
  
  return table.concat(self.solutionInputs)
end

---Check if puzzle has a solution
---@return boolean
function PuzzleHintHelper:hasSolution()
  return self.puzzle.solution ~= nil
end

---Check if puzzle is a move puzzle
---@return boolean
function PuzzleHintHelper:isMovePuzzle()
  return self.puzzle.puzzleType == "moves"
end

---Get total number of swaps in solution
---@return integer
function PuzzleHintHelper:getSolutionSwapCount()
  return self.solutionSwapPositions and #self.solutionSwapPositions or 0
end

return PuzzleHintHelper