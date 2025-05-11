local class = require("common.lib.class")
local consts = require("common.engine.consts")
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
  function(self, puzzleResults)
    self.puzzleResults = puzzleResults
  end
)

-- Menu for puzzle set -> go into subset
-- Play a puzzle set -> extract all puzzles in order
-- Train a puzzle set -> same as play but in train order / filter


-- Returns all puzzles from the given path as a puzzle set
function PuzzleLibrary:puzzleSetFromPath(fullPath, subDirectory)
  local puzzleSet = PuzzleSet(subDirectory or "Puzzles", {}, {})

  for _, currentFilename in ipairs(FileUtils.getFilteredDirectoryItems(fullPath, "file")) do
    if currentFilename ~= "README.txt" then
      local currentPuzzleSets = self:puzzleSetsFromFile(fullPath .. "/" .. currentFilename)
      for _, currentPuzzleSet in ipairs(currentPuzzleSets) do
        puzzleSet.puzzleSets[#puzzleSet.puzzleSets+1] = currentPuzzleSet
      end
    end
  end
  for _, subDirectory in ipairs(FileUtils.getFilteredDirectoryItems(fullPath, "directory")) do
    local currentPuzzleSet = self:puzzleSetFromPath(fullPath .. "/" .. subDirectory, subDirectory)
    puzzleSet.puzzleSets[#puzzleSet.puzzleSets+1] = currentPuzzleSet
  end

  return puzzleSet
end

function PuzzleLibrary:puzzleSetsFromFile(path)
  local puzzleSets = PuzzleSet.loadFromFile(path)

  return puzzleSets
end

function PuzzleLibrary:flattenedPuzzleSetForPuzzleSet(puzzleSet, filter, sort)
  local result = PuzzleSet("Puzzles", {}, {})

  for _, currentPuzzleSet in ipairs(puzzleSet.puzzleSets) do
    local flattenedPuzzleSet = self:flattenedPuzzleSetForPuzzleSet(currentPuzzleSet, filter, sort)
    for _, puzzle in ipairs(flattenedPuzzleSet.puzzles) do
      result.puzzles[#result.puzzles+1] = puzzle
    end
  end

  logger.trace("added flattened " .. puzzleSet.setName .. " " .. #puzzleSet.puzzles)
  for _, currentPuzzle in ipairs(puzzleSet.puzzles) do
    local trainingDate = self:getNextTrainingDateForPuzzleUUID(currentPuzzle.UUID)
    currentPuzzle.trainingDate = trainingDate
    currentPuzzle.puzzleEverBeaten = self.puzzleResults:puzzleEverBeaten(currentPuzzle.UUID)
    result.puzzles[#result.puzzles+1] = currentPuzzle
  end

  if filter then
    filter(result)
  end

  if sort then
    table.sort(result.puzzles, sort)
  end

  return result
end


function PuzzleLibrary:getPuzzlesForPuzzleSet(directory, filter, sort)

  local puzzleSet = self:puzzleSetFromPath(directory)
  if filter then
    puzzleSet.puzzles = tableUtils.filter(puzzleSet.puzzles, filter)
  end

  if sort then
    table.sort(puzzleSet.puzzles, sort)
  end

  return puzzleSet
end

-- writes the stock puzzles
function PuzzleLibrary.writeDefaultPuzzles(defaultPuzzleDirectory, readmePath, savePuzzleDirectory)
  pcall(
    function()
      -- Until we have a way to disable the default puzzles, we shouldn't keep writing them if the user has their own puzzles.
      -- We will also need a way to handle new puzzles and updates to puzzles.
      -- local puzzleFiles = FileUtils.getFilteredDirectoryItems(savePuzzleDirectory) or {}
      -- if #puzzleFiles == 0 then
        love.filesystem.createDirectory(savePuzzleDirectory)
        FileUtils.recursiveCopy(defaultPuzzleDirectory, savePuzzleDirectory)
        FileUtils.copyFile(readmePath, savePuzzleDirectory .. "/README.txt")
      -- end
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

function PuzzleLibrary:trainIntervalForResults(streakCount, winRate)
  local interval = self:trainIntervalForStreak(streakCount)
  local result = interval * winRate
  return result
end

function PuzzleLibrary:getNextTrainingDateForPuzzleUUID(UUID)

  local winStreak = self.puzzleResults:puzzleUUIDWinStreak(UUID)
  if winStreak == 0 then
    return 0
  end

  local successRecord = self.puzzleResults:getLatestSuccessForPuzzleUUID(UUID)
  if successRecord == nil then
    return 0
  end
  assert(successRecord.success == true)
  assert(successRecord.timestamp > 0)

  local winRate = self.puzzleResults:puzzleSuccessRateForUUID(UUID)
  local trainInterval = self:trainIntervalForResults(winStreak, winRate)
  local nextTrainingDate = successRecord.timestamp + trainInterval
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
function PuzzleLibrary.filterPuzzleSetForTraining(puzzleSet)
  if tableUtils.contains(invalidSetsForTraining, puzzleSet.setName) then
    puzzleSet.puzzles = {}
    puzzleSet.puzzleSets = {}
  end
end

function PuzzleLibrary:currentTrainingPuzzleSetForPuzzleSet(puzzleSet)
  local flattenedPuzzleSet = self:flattenedPuzzleSetForPuzzleSet(puzzleSet, self.filterPuzzleSetForTraining)
  local timedResults = {}
  local results = {}
  local currentTime = to_UTC(os.time())
  for _, puzzle in ipairs(flattenedPuzzleSet.puzzles) do
    local bucketDifference = math.ceil((puzzle.trainingDate - currentTime) / DAY)
    if puzzle.trainingDate < currentTime then
      bucketDifference = 0
    end
    if timedResults[bucketDifference] == nil then
      timedResults[bucketDifference] = 0
    end
    timedResults[bucketDifference] = timedResults[bucketDifference] + 1
    if currentTime > puzzle.trainingDate then
      results[#results+1] = puzzle
    end
  end

  logger.debug("Training Puzzles Histogram")
  local total = 0
  for k, v in pairsSortedByKeys(timedResults) do
    logger.debug(k .. " day has " .. v .. " puzzles")
    total = total + v
  end
  logger.debug(total .. " total puzzles")

  local sortFunction = function(a,b) 
      if a.trainingDate == b.trainingDate then
        return a.UUID < b.UUID
      end
      return a.trainingDate < b.trainingDate
    end

  table.sort(results, sortFunction)

  local puzzleSet = PuzzleSet("Training " .. #results, results)
  return puzzleSet
end

return PuzzleLibrary