local class = require("common.lib.class")
local FileUtils = require("client.src.FileUtils")
local logger = require("common.lib.logger")
local Puzzle = require("common.engine.Puzzle")
local PuzzleSet = require("client.src.PuzzleSet")
local Scores = require("client.src.scores")
local tableUtils = require("common.lib.tableUtils")

-- A puzzle collection is the set of all puzzles that can be queried and filtered for a subset.
---@class PuzzleLibrary
---@field puzzleSets table<integer, table> all the puzzle sets
---@field puzzleResults Scores
local PuzzleLibrary =
  class(
  function(self, path, puzzleResults)
    self.puzzleSets = {}
    self:loadPuzzlesFromDirectory(path)
    self.puzzleResults = puzzleResults
  end
)

-- Loads all puzzles from the given directory
function PuzzleLibrary:loadPuzzlesFromDirectory(path)
  local puzzleFiles = FileUtils.getFilteredDirectoryItems(path) or {}
  local count = 0
  logger.debug("loading custom puzzles...")
  for _, filename in pairs(puzzleFiles) do
    logger.trace(filename)
    if love.filesystem.getInfo(path .. "/" .. filename) and filename ~= "README.txt" then
      local puzzleSets = PuzzleSet.loadFromFile(path .. "/" .. filename)
      for _, puzzleSet in ipairs(puzzleSets) do
        self.puzzleSets[#self.puzzleSets+1] = puzzleSet
        count = count + 1
      end
    end
  end
  logger.debug("loaded " .. count .. " puzzle sets")
end


-- writes the stock puzzles
function PuzzleLibrary.writeDefaultPuzzles(defaultPuzzleDirectory, readmePath, savePuzzleDirectory)
  pcall(
    function()
      -- Until we have a way to disable the default puzzles, we shouldn't keep writing them if the user has their own puzzles.
      -- We will also need a way to handle new puzzles and updates to puzzles.
      local puzzleFiles = FileUtils.getFilteredDirectoryItems(savePuzzleDirectory) or {}
      if #puzzleFiles == 0 then
        love.filesystem.createDirectory(savePuzzleDirectory)
        FileUtils.recursiveCopy(defaultPuzzleDirectory, savePuzzleDirectory)
        FileUtils.copyFile(readmePath, savePuzzleDirectory .. "/README.txt")
      end
    end
  )
end

function PuzzleLibrary:puzzleSetGetWinRate(puzzleSet)
  local result = 0
  for index, puzzle in ipairs(puzzleSet.puzzles) do
    local winRate = self.puzzleResults:puzzleSuccessRateForUUID(puzzle.UUID)
    result = result + winRate
  end
  return result / #puzzleSet.puzzles
end

local ONE_HOUR = 60 * 60
local ALMOST_A_DAY = ONE_HOUR * 23
local DAY = ONE_HOUR * 24
function PuzzleLibrary:trainIntervalForStreak(streakCount)

  if streakCount >= 10 then
    return ALMOST_A_DAY + 30 * DAY
  elseif streakCount >= 5 then
    return ALMOST_A_DAY + 14 * DAY
  elseif streakCount >= 4 then
    return ALMOST_A_DAY + 5 * DAY
  elseif streakCount >= 3 then
    return ALMOST_A_DAY + DAY
  elseif streakCount >= 2 then
    return ALMOST_A_DAY
  elseif streakCount >= 1 then
    return ONE_HOUR
  end

  return 0
end

function PuzzleLibrary:getNextTrainingDateForPuzzleUUID(UUID)

  local winStreak = self.puzzleResults:puzzleUUIDWinStreak(UUID)
  if winStreak == 0 then
    return 0
  end

  local records = self.puzzleResults:getRecordsForPuzzleUUID(UUID)

  assert(#records > 0)
  local latestRecord = records[#records]
  assert(latestRecord.success)
  assert(latestRecord.timestamp)

  local trainInterval = self:trainIntervalForStreak(winStreak)
  local nextTrainingDate = latestRecord.timestamp + trainInterval
  return nextTrainingDate
end

local invalidSetsForTraining = {"Classic set 1",
    "Classic set 2",
    "Classic set 3",
    "Classic set 4",
    "Classic set 5",
    "Classic set 6",
    "Bagagle Mode",
    "Go Hard",
    "Ridiculous Mode"}
function PuzzleLibrary.puzzleSetAllowedForTraining(puzzleSet)
  if tableUtils.contains(invalidSetsForTraining, puzzleSet.setName) then
    return false
  end

  return true
end

function PuzzleLibrary:currentTrainingPuzzleSet()

  local results = {}
  local currentTime = to_UTC(os.time())
  for _, puzzleSet in ipairs(self.puzzleSets) do
    if PuzzleLibrary.puzzleSetAllowedForTraining(puzzleSet) then
      for _, puzzle in ipairs(puzzleSet.puzzles) do
        local trainingDate = self:getNextTrainingDateForPuzzleUUID(puzzle.UUID)
        if currentTime > trainingDate then
          results[#results+1] = puzzle
        end
      end
    end
  end

  local sortFunction = function(a,b) 
      local aTrainDate = self:getNextTrainingDateForPuzzleUUID(a.UUID)
      local bTrainDate = self:getNextTrainingDateForPuzzleUUID(b.UUID)
      if aTrainDate == bTrainDate then
        return a.UUID < b.UUID
      end
      return aTrainDate < bTrainDate
    end

  table.sort(results, sortFunction)

  local puzzleSet = PuzzleSet("Training " .. #results, results)
  return puzzleSet
end

function PuzzleLibrary:getPuzzlesForPuzzleMenu()
  local filteredPuzzleSets = tableUtils.filter(self.puzzleSets, function(puzzleSet) 
    -- might want to filter this for now, but at least make a copy
    return true
  end)

  table.sort(filteredPuzzleSets, function(a,b) return a.setName < b.setName end)

  return filteredPuzzleSets
end

return PuzzleLibrary