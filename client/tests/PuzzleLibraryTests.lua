local PuzzleLibrary = require("client.src.PuzzleLibrary")
local PuzzleSet = require("client.src.PuzzleSet")
local Puzzle = require("common.engine.Puzzle")
local PuzzleSetIterator = require("client.src.PuzzleSetIterator")
local Scores = require("client.src.scores")
local class = require("common.lib.class")
local consts = require("common.engine.consts")
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
---@diagnostic disable-next-line: duplicate-set-field
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

-- a puzzle whose UUID changed still counts as beaten by a win saved under its old one
function PuzzleLibraryTests.testAWinUnderAnOldUUIDStillCounts()
  local scores = Scores()
  scores.puzzleRecords["old-uuid"] = {{inputs = "A", timestamp = to_UTC(os.time()), success = true}}
  local puzzle = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 1, stack = "1111111111111111",
                         oldUUIDs = {"old-uuid"}})

  local moved = PuzzleLibrary(scores):addStatisticsToPuzzleSet(PuzzleSet("Set", "", {puzzle}))

  assert(moved, "the record moved, so the scores need saving")
  assert(puzzle.puzzleEverBeaten, "the win under the old UUID counts")
end

-- the shipped chain puzzles that became goal lists
---@return Puzzle[]
local function shippedGoalListPuzzles()
  local puzzleLibrary = PuzzleLibrary(Scores())
  local shippedSet = puzzleLibrary:puzzleSetFromPath(consts.PUZZLES_LOAD_DIRECTORY)
  local goalListPuzzles = {}
  for _, puzzle in ipairs(puzzleLibrary:flattenedPuzzleSetForPuzzleSet(shippedSet).puzzles) do
    if puzzle.puzzleType == Puzzle.GOALS_TYPE then
      goalListPuzzles[#goalListPuzzles + 1] = puzzle
    end
  end
  return goalListPuzzles
end

-- becoming goal lists changed the shipped chain puzzles' UUIDs, so each lists the UUID it had as a one-word chain
-- puzzle last to carry its records over
function PuzzleLibraryTests.testEveryShippedGoalListPuzzleCarriesItsChainPuzzleRecords()
  local goalListPuzzles = shippedGoalListPuzzles()
  assert(#goalListPuzzles == 84, "84 chain puzzles became goal lists, found " .. #goalListPuzzles)
  for _, puzzle in ipairs(goalListPuzzles) do
    local asChainPuzzle = Puzzle({puzzleType = Puzzle.PUZZLE_TYPES.chain, stack = puzzle.stack, startTiming = puzzle.startTiming,
                                  moves = puzzle.moves, stopTime = puzzle.stopTime, shakeTime = puzzle.shakeTime,
                                  cursorStartLeft = puzzle.cursorStartLeft, panelBuffer = puzzle.panelBuffer,
                                  garbagePanelBuffer = puzzle.garbageBuffer})
    local oldUUIDs = puzzle.oldUUIDs or {}
    assert(oldUUIDs[#oldUUIDs] == asChainPuzzle.UUID, "a goal list puzzle does not carry its chain puzzle's records: " .. puzzle.stack)
  end
end

-- the Old UUIDs beta already listed for these chain puzzles, followed by the UUID each had on beta, so records from
-- every version of them carry over and the hash is pinned to what beta saved
local OLD_UUIDS_BY_STACK = {
  ["100999199993339999949999149999949999999"] = {
    "c685b5be277cf47975bc6d135a4007c7ffe9b991c106e343a9a21479e06afa06",
    "1fa51150a17493feb029e69d6630c19422efe800c903953db1d84259f1a88b3d",
    "6e1ab9d35cef047a70252cdad778903722561b6ab17202642ccb74e8ff2a5c2c"
  },
  ["200999299999199999419999149999949999299"] = {
    "d62c1f694df13a01ea0dc07405d5de2e74bce1788aec8ee532c89089c712371e",
    "b51e554914f7caf4cba3869f5cc9b3204a680cb3167510b260aad9c256a97f07",
    "8b19f05ddccce80525c849eac120371cd13a8f496f06c2e499af2bc1761eb272"
  },
  ["300001290106399303199506592303299536393"] = {
    "82e6e481fdf687849105fcd4adbb494d4ece8955bdb0f0c5b0f6c5ec27c3d3d2",
    "ed0351c2c2418b576515777e70d228485850f0c85b83f00f49ad0631806b056b",
    "82dc42215a9c81f9bb5b81c3da0b0862e7ddbb3a71e5c5b2128d32e69ca746c2"
  },
  ["200420400199105499402599241959425299"] = {
    "bcc92b7b59083994f7487db1c54fe5a7cf90b1de24be67a933aa56534c3bf17f",
    "5998c2e92b1bd46ce0e2faa591d045416d8cfcaba7b537520be6eb8556169143",
    "a9b3ca24229e575ae958093397dfc7fe035932147e03eb7f54a331240c52cda1"
  },
  ["100040530099590095290099590931929424139"] = {
    "dc03c465ec023c9fff73cb796aac900169933b440be90dd853b4dce3b1f98ca9",
    "5c42f7346a05495825e4ae02dd21e96ae787235fec9e2cc11273a4c558149eb5",
    "575dc15db016098f6293fe124af4fcc9d4f1d731683020b5223e95b34e8b11cc"
  }
}

function PuzzleLibraryTests.testShippedGoalListPuzzlesKeepBetasOldUUIDsAheadOfTheirChainUUID()
  local found = 0
  for _, puzzle in ipairs(shippedGoalListPuzzles()) do
    local expected = OLD_UUIDS_BY_STACK[puzzle.stack]
    if expected then
      found = found + 1
      local oldUUIDs = puzzle.oldUUIDs or {}
      assert(#oldUUIDs == #expected, "wrong number of Old UUIDs for " .. puzzle.stack)
      for index, uuid in ipairs(expected) do
        assert(oldUUIDs[index] == uuid, "Old UUID " .. index .. " of " .. puzzle.stack .. " is " .. tostring(oldUUIDs[index]))
      end
    end
  end
  assert(found == 5, "found " .. found .. " of the 5 puzzles beta gave Old UUIDs")
end

-- Run the tests
PuzzleLibraryTests.testCurrentTrainingPuzzleIndicesFilteringAndHistogram()
PuzzleLibraryTests.testAWinUnderAnOldUUIDStillCounts()
PuzzleLibraryTests.testEveryShippedGoalListPuzzleCarriesItsChainPuzzleRecords()
PuzzleLibraryTests.testShippedGoalListPuzzlesKeepBetasOldUUIDsAheadOfTheirChainUUID()

return PuzzleLibraryTests