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
  pcall(
    function()
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
  )
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

function PuzzleLibrary:getPuzzlesForPuzzleMenu()
  local filteredPuzzleSets = tableUtils.filter(self.puzzleSets, function(puzzleSet) 
    -- return GAME.scores:puzzleUUIDHasBeenBeaten(puzzleSet.puzzles[#puzzleSet.puzzles].UUID) == false
    return true
  end)

  table.sort(filteredPuzzleSets, function(a,b) return self:puzzleSetGetWinRate(a) < self:puzzleSetGetWinRate(b) end)

  return filteredPuzzleSets
end

return PuzzleLibrary