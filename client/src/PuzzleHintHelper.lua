local class = require("common.lib.class")
local InputCompression = require("common.data.InputCompression")
local Match = require("common.engine.Match")
local LevelPresets = require("common.data.LevelPresets")
local Puzzle = require("common.engine.Puzzle")

-- Analyzes puzzle solutions to provide hints and next move suggestions to players
---@class PuzzleHintHelper
---@field puzzle Puzzle
---@field solutionInputs string[]? decompressed solution input array
---@field currentSwapCount integer number of swaps player has made
---@field solutionSwapPositions table[] array of {row=number, column=number} positions for each swap in solution
---@field playerStack Stack? the stack whose queued swaps are recorded in playerSwapPositions
---@field playerSwapPositions table[] array of {row=number, column=number} positions for each swap the player's stack queued
---@overload fun(puzzle: Puzzle): PuzzleHintHelper
local PuzzleHintHelper = class(
  function(self, puzzle)
    self.puzzle = puzzle
    self.solutionInputs = nil
    self.currentSwapCount = 0
    self.solutionSwapPositions = {}
    self.playerSwapPositions = {}
    
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

---Append the swap the stack queued on the frame it just ran, so refused swap presses are never counted
---@param positions table[] the swaps recorded from this stack so far
---@param stack Stack
local function recordQueuedSwap(positions, stack)
  if stack.swapCount > #positions then
    positions[#positions + 1] = {row = stack.queuedSwapRow, column = stack.queuedSwapColumn}
  end
end

---Replay the solution through an engine stack at the level it was recorded at and record each swap it queues
---so held directions, direction changes and refused swaps play out exactly as they do in the game
function PuzzleHintHelper:extractSwapPositions()
  if not self.solutionInputs or not self:isMovePuzzle() then
    return
  end

  self.solutionSwapPositions = {}
  local match = Match(self.puzzle:toPanelSource(), self.puzzle:toGameMode().matchRules)
  local stack = match:createStackWithSettings(LevelPresets.getModern(Puzzle.SOLUTION_LEVEL), false, "controller")
  ---@cast stack Stack
  match:start()
  stack:setMaxRunsPerFrame(1)
  stack:receiveConfirmedInput(table.concat(self.solutionInputs))

  while stack.clock < #self.solutionInputs and not match:hasEnded() do
    match:run()
    recordQueuedSwap(self.solutionSwapPositions, stack)
  end
end

---Record every swap the player's stack queues from now on in playerSwapPositions, the same way the solution's are
---@param stack Stack
function PuzzleHintHelper:followPlayerStack(stack)
  self.playerStack = stack
  self.playerSwapPositions = {}
  stack:connectSignal("finishedRun", self, self.recordPlayerSwap)
end

---Record the swap the player's stack queued on the frame it just ran
function PuzzleHintHelper:recordPlayerSwap()
  recordQueuedSwap(self.playerSwapPositions, self.playerStack)
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