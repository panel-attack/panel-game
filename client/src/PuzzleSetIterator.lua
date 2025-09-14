local class = require("common.lib.class")
local PuzzleSet = require("client.src.PuzzleSet")

-- Provides iteration through puzzles in a puzzle set, supporting both sequential and training order traversal
---@class PuzzleSetIterator
---@field puzzleSet PuzzleSet
---@field currentIndex integer
---@field puzzleList Puzzle[]
---@field puzzleIndicesList integer[][]
local PuzzleSetIterator = class(function(self, puzzleSet)
  self.puzzleSet = puzzleSet
  self.currentIndex = 0
  -- Build puzzle indices list for basic iterator
  if puzzleSet then
    self.puzzleIndicesList = {}
    for i = 1, #puzzleSet.puzzles do
      self.puzzleIndicesList[i] = {i}
    end
  end
end)

---@return integer[]?
function PuzzleSetIterator:currentPuzzle()
  if self.puzzleIndicesList and self.currentIndex <= #self.puzzleIndicesList then
    local indices = self.puzzleIndicesList[self.currentIndex]
    return indices
  end
  return nil
end

-- Advances to and returns the next puzzle's indices, or nil if at end
---@return integer[]?
function PuzzleSetIterator:nextPuzzle()
  if self.puzzleIndicesList and self.currentIndex <= #self.puzzleIndicesList then
    self.currentIndex = self.currentIndex + 1
    local indices = self.puzzleIndicesList[self.currentIndex]
    return indices
  end
  return nil
end

-- Returns the total number of puzzles available in this iterator
function PuzzleSetIterator:totalPuzzleCount()
  return #self.puzzleIndicesList
end

---Factory method to create iterator for specific puzzle set with breadth-first ordering
---@param puzzleSet PuzzleSet
---@param puzzleSetIndices integer[]
---@param startIndex integer?
---@return PuzzleSetIterator
function PuzzleSetIterator.makePuzzleSetIterator(puzzleSet, puzzleSetIndices, startIndex)
  local iterator = PuzzleSetIterator()
  startIndex = startIndex or 1
  
  -- Navigate to the target puzzle set using the indices
  local targetSet = puzzleSet
  local targetIndices = {}
  for _, index in ipairs(puzzleSetIndices) do
    if targetSet.puzzleSets and targetSet.puzzleSets[index] then
      targetIndices[#targetIndices + 1] = index
      targetSet = targetSet.puzzleSets[index]
    else
      assert(false)
      -- Invalid index path, return empty iterator
      iterator.puzzleIndicesList = {}
      iterator.currentIndex = 0
      return iterator
    end
  end
  
  -- Collect all puzzle indices in breadth-first order from the target set
  local puzzleIndicesList = {}
  
  -- Helper function to recursively collect puzzle indices in breadth-first order
  local function collectPuzzlesRecursive(currentSet, currentIndices, depth)
    -- Add puzzles from current set at this depth level
    for i = 1, #currentSet.puzzles do
      local indices = {}
      for _, idx in ipairs(currentIndices) do
        indices[#indices + 1] = idx
      end
      indices[#indices + 1] = i
      puzzleIndicesList[#puzzleIndicesList + 1] = indices
    end
    
    -- Then recursively process child sets
    if currentSet.puzzleSets then
      for childIndex, childSet in ipairs(currentSet.puzzleSets) do
        local childIndices = {}
        for _, idx in ipairs(currentIndices) do
          childIndices[#childIndices + 1] = idx
        end
        childIndices[#childIndices + 1] = childIndex
        collectPuzzlesRecursive(childSet, childIndices, depth + 1)
      end
    end
  end
  
  -- Start recursive collection from target set
  collectPuzzlesRecursive(targetSet, targetIndices, 0)
  
  iterator.puzzleIndicesList = puzzleIndicesList
  iterator.currentIndex = startIndex - 1
  
  return iterator
end

---Factory method to create iterator for training order (uses PuzzleLibrary logic)
---@param puzzleSet PuzzleSet
---@param puzzleLibrary PuzzleLibrary
---@return PuzzleSetIterator
function PuzzleSetIterator.makeTrainingOrderIterator(puzzleSet, puzzleSetIndices, puzzleLibrary)
  local iterator = PuzzleSetIterator()
  
  local trainingIndices = puzzleLibrary:currentTrainingPuzzleIndicesForPuzzleSet(puzzleSet, puzzleSetIndices)
  
  iterator.puzzleIndicesList = trainingIndices
  iterator.currentIndex = 0
  
  return iterator
end

---Static method to get puzzle from puzzle set using puzzleSetIndices
---@param puzzleSet PuzzleSet
---@param puzzleSetIndices integer[]
---@return Puzzle?
function PuzzleSetIterator.getPuzzleFromIndices(puzzleSet, puzzleSetIndices)
  if puzzleSetIndices == nil then
    return nil
  end
  
  local indexCopy = deepcpy(puzzleSetIndices)
  local index = indexCopy[#indexCopy]
  indexCopy[#indexCopy] = nil
  
  return puzzleSet:getPuzzleFromIndices(indexCopy, index)
end

return PuzzleSetIterator