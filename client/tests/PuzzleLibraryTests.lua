local PuzzleLibrary = require("client.src.PuzzleLibrary")
local PuzzleSet = require("client.src.PuzzleSet")
local Puzzle = require("common.engine.Puzzle")
local PuzzleSetIterator = require("client.src.PuzzleSetIterator")
local class = require("common.lib.class")
local logger = require("common.lib.logger")
local util = require("common.lib.util")

local PuzzleLibraryTests = class(function() end)

function PuzzleLibraryTests.testCurrentTrainingPuzzleIndicesFilteringAndHistogram()
  -- Test that currentTrainingPuzzleIndicesForPuzzleSet applies filtering
  -- and that the Training Puzzles Histogram is logged
  
  local currentTime = to_UTC(os.time())
  
  -- Create a simple test with just one puzzle that needs training
  local puzzle1 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 1, stack = "1111111111111111"})
  puzzle1.trainingDate = currentTime - 100  -- needs training
  puzzle1.UUID = "puzzle1-uuid"
  
  local normalSet = PuzzleSet("Normal Training Set", "Training description", {puzzle1})
  
  -- Create mock scores that return expected training data
  local mockScores = {
    puzzleUUIDWinStreak = function(self, uuid) return 1 end,
    getLatestSuccessForPuzzleUUID = function(self, uuid) 
      return {success = true, timestamp = currentTime - 200, UUID = nil}
    end,
    puzzleSuccessRateForUUID = function(self, uuid) return 0.8 end,
    puzzleEverBeaten = function(self, uuid) return true end
  }
  
  local puzzleLibrary = PuzzleLibrary(mockScores)
  
  -- Mock logger to capture debug output for first method only
  local loggedMessages = {}
  local originalDebug = logger.debug
  logger.debug = function(message)
    loggedMessages[#loggedMessages + 1] = message
  end
  
  -- Now call the second method without logging
  local trainingIndices = puzzleLibrary:currentTrainingPuzzleIndicesForPuzzleSet(normalSet, {})
  
  -- Restore original logger
  logger.debug = originalDebug

  -- Check histogram logging 
  local foundHistogramTitle = false
  local foundTotalPuzzles = false
  for _, message in ipairs(loggedMessages) do
    if message == "Training Puzzles Histogram" then
      foundHistogramTitle = true
    elseif message:match("total puzzles") then
      foundTotalPuzzles = true
    end
  end
  
  assert(#trainingIndices == 1, "Training indices should have 1 entry")
  assert(foundHistogramTitle, "Should log 'Training Puzzles Histogram' title")
  assert(foundTotalPuzzles, "Should log total puzzles count")
end

-- Run the tests
PuzzleLibraryTests.testCurrentTrainingPuzzleIndicesFilteringAndHistogram()

return PuzzleLibraryTests