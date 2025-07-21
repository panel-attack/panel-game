local class = require("common.lib.class")
local consts = require("common.engine.consts")
local FileUtils = require("client.src.FileUtils")
local logger = require("common.lib.logger")
local PuzzleSet = require("client.src.PuzzleSet")
local tableUtils = require("common.lib.tableUtils")

-- A puzzle collection is a set of all puzzles that can be queried and filtered for a subset.
---@class PuzzleLibrary
---@field puzzleResults Scores?
local PuzzleLibrary =
    class(
      function(self, puzzleResults)
        self.puzzleResults = puzzleResults
      end
    )

---@return table<integer, table> all the puzzle sets
function PuzzleLibrary:getDefaultPuzzleSet()
  local directory = consts.PUZZLES_SAVE_DIRECTORY
  local puzzleSet = self:puzzleSetFromPath(directory)

  self:addStatisticsToPuzzleSet(puzzleSet)

  return puzzleSet
end

function PuzzleLibrary:addStatisticsToPuzzleSet(puzzleSet)
  for _, currentPuzzleSet in ipairs(puzzleSet.puzzleSets) do
    self:addStatisticsToPuzzleSet(currentPuzzleSet)
  end

  for _, currentPuzzle in ipairs(puzzleSet.puzzles) do
    local trainingDate = self:getNextTrainingDateForPuzzleUUID(currentPuzzle.UUID)
    currentPuzzle.trainingDate = trainingDate
    currentPuzzle.puzzleEverBeaten = self.puzzleResults:puzzleEverBeaten(currentPuzzle.UUID)
  end
end

-- Returns all puzzles from the given path as a puzzle set.
-- Puzzle sets are embedded recursively
-- @return PuzzleSet 
function PuzzleLibrary:puzzleSetFromPath(fullPath, subDirectory)
  local puzzleSet = PuzzleSet(subDirectory or "pz_puzzles", nil, {}, {})

  local puzzleFiles = FileUtils.getFilteredDirectoryItems(fullPath, "file")

  table.sort(puzzleFiles, function(a, b)
    if a == "Puzzles.json" then
      return true
    elseif b == "Puzzles.json" then
      return false
    else
      return a < b
    end
  end)

  for _, currentFilename in ipairs(puzzleFiles) do
    if currentFilename ~= "README.txt" then
      local currentPuzzleSets = self:puzzleSetsFromFile(fullPath .. "/" .. currentFilename)
      for _, currentPuzzleSet in ipairs(currentPuzzleSets) do
        puzzleSet.puzzleSets[#puzzleSet.puzzleSets + 1] = currentPuzzleSet
      end
    end
  end
  for _, subDirectory in ipairs(FileUtils.getFilteredDirectoryItems(fullPath, "directory")) do
    local currentPuzzleSet = self:puzzleSetFromPath(fullPath .. "/" .. subDirectory, subDirectory)
    puzzleSet.puzzleSets[#puzzleSet.puzzleSets + 1] = currentPuzzleSet
  end

  return puzzleSet
end

-- Helper function to load from a puzzle file
function PuzzleLibrary:puzzleSetsFromFile(path)
  local puzzleSets = PuzzleSet.loadFromFile(path)

  return puzzleSets
end

-- Creates a new puzzle set from a given puzzle set by recursively putting all the puzzles at the root level.
function PuzzleLibrary:flattenedPuzzleSetForPuzzleSet(puzzleSet, filter, sort)
  local result = PuzzleSet("pz_puzzles", nil, {}, {})

  for _, currentPuzzleSet in ipairs(puzzleSet.puzzleSets) do
    local flattenedPuzzleSet = self:flattenedPuzzleSetForPuzzleSet(currentPuzzleSet, filter, sort)
    for _, puzzle in ipairs(flattenedPuzzleSet.puzzles) do
      result.puzzles[#result.puzzles + 1] = puzzle
    end
  end

  for _, currentPuzzle in ipairs(puzzleSet.puzzles) do
    result.puzzles[#result.puzzles + 1] = currentPuzzle
  end

  if filter then
    filter(result)
  end

  if sort then
    table.sort(result.puzzles, sort)
  end

  return result
end

-- writes the stock puzzles to the user's puzzle directory
function PuzzleLibrary.writeDefaultPuzzles(defaultPuzzleDirectory, readmePath, savePuzzleDirectory)
  pcall(
    function()
      love.filesystem.createDirectory(savePuzzleDirectory)
      FileUtils.recursiveCopy(defaultPuzzleDirectory, savePuzzleDirectory)
      FileUtils.copyFile(readmePath, savePuzzleDirectory .. "/README.txt")
    end
  )
  pcall(
    function()
      local oldPuzzleFile = savePuzzleDirectory .. "/stock (example).json"
      if love.filesystem.exists(oldPuzzleFile) then
        love.filesystem.remove(oldPuzzleFile)
      end
    end
  )
end

local ONE_HOUR = 60 * 60
local ALMOST_A_DAY = ONE_HOUR * 23
local DAY = ONE_HOUR * 24
-- Returns how long until the next training given a win streak
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

-- Returns a train inverval taking into account the win rate and streak count
function PuzzleLibrary:trainIntervalForResults(streakCount, winRate)
  local interval = self:trainIntervalForStreak(streakCount)
  local result = interval * winRate
  return result
end

-- Returns the next timestamp this puzzle UUID should be trained
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
  assert(successRecord.UUID == nil)

  local winRate = self.puzzleResults:puzzleSuccessRateForUUID(UUID)
  local trainInterval = self:trainIntervalForResults(winStreak, winRate)
  local nextTrainingDate = successRecord.timestamp + trainInterval
  return nextTrainingDate
end

local invalidSetsForTraining = { "puzzle_name_classic_set_1",
  "puzzle_name_classic_set_2",
  "puzzle_name_classic_set_3",
  "puzzle_name_classic_set_4",
  "puzzle_name_classic_set_5",
  "puzzle_name_classic_set_6"}
function PuzzleLibrary.filterPuzzleSetForTraining(puzzleSet)
  if tableUtils.contains(invalidSetsForTraining, puzzleSet.setName) then
    puzzleSet.puzzles = {}
    puzzleSet.puzzleSets = {}
  end
end

-- Returns training puzzles with their indices in the original puzzle set hierarchy
-- @param puzzleSet PuzzleSet
-- @param puzzleSetIndices integer[]
function PuzzleLibrary:currentTrainingPuzzleIndicesForPuzzleSet(puzzleSet, puzzleSetIndices)
  assert(puzzleSet)
  assert(puzzleSetIndices)

  -- Collect all puzzles with their indices while preserving hierarchy and applying filtering
  local puzzleWithIndices = {}
  local function collectPuzzlesRecursively(set, currentIndices)
    -- Apply same filtering logic as filterPuzzleSetForTraining
    if tableUtils.contains(invalidSetsForTraining, set.setName) then
      return -- Skip this entire set and its children
    end
    
    -- Add puzzles from current set
    for i, puzzle in ipairs(set.puzzles) do
      local indices = {}
      for _, idx in ipairs(currentIndices) do
        indices[#indices + 1] = idx
      end
      indices[#indices + 1] = i
      puzzleWithIndices[#puzzleWithIndices + 1] = {puzzle = puzzle, indices = indices}
    end
    
    -- Recursively process child sets
    for i, childSet in ipairs(set.puzzleSets) do
      local childIndices = {}
      for _, idx in ipairs(currentIndices) do
        childIndices[#childIndices + 1] = idx
      end
      childIndices[#childIndices + 1] = i
      collectPuzzlesRecursively(childSet, childIndices)
    end
  end
  local currentPuzzleSet = puzzleSet:getPuzzleSetFromIndices(puzzleSetIndices)

  collectPuzzlesRecursively(currentPuzzleSet, puzzleSetIndices)
  
  -- Apply training date filtering and histogram calculation
  local timedResults = {}
  local trainingPuzzles = {}
  local currentTime = to_UTC(os.time())
  
  for _, puzzleData in ipairs(puzzleWithIndices) do
    local puzzle = puzzleData.puzzle
    local bucketDifference = math.ceil((puzzle.trainingDate - currentTime) / DAY)
    if puzzle.trainingDate < currentTime then
      bucketDifference = 0
    end
    if timedResults[bucketDifference] == nil then
      timedResults[bucketDifference] = 0
    end
    timedResults[bucketDifference] = timedResults[bucketDifference] + 1
    if currentTime > puzzle.trainingDate then
      trainingPuzzles[#trainingPuzzles + 1] = puzzleData
    end
  end
  
  -- Log histogram
  logger.debug("Training Puzzles Histogram")
  local total = 0
  for k, v in pairsSortedByKeys(timedResults) do
    logger.debug(k .. " day has " .. v .. " puzzles")
    total = total + v
  end
  logger.debug(total .. " total puzzles")
  
  -- Sort by training date, then by UUID (same logic as original method)
  local sortFunction = function(a, b)
    if a.puzzle.trainingDate == b.puzzle.trainingDate then
      return a.puzzle.UUID < b.puzzle.UUID
    end
    return a.puzzle.trainingDate < b.puzzle.trainingDate
  end
  
  table.sort(trainingPuzzles, sortFunction)
  
  -- Return just the indices arrays
  local result = {}
  for _, puzzleData in ipairs(trainingPuzzles) do
    result[#result + 1] = puzzleData.indices
  end
  
  return result
end

return PuzzleLibrary
