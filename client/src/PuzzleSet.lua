local class = require("common.lib.class")
local FileUtils = require("client.src.FileUtils")
local Puzzle = require("common.engine.Puzzle")
local logger = require("common.lib.logger")

-- A puzzle set is a set of puzzles, typically they have a common difficulty or theme.
---@class PuzzleSet
---@field setName string
---@field puzzles Puzzle[]
---@field fileSource string?
local PuzzleSet =
  class(
  function(self, setName, puzzles, puzzleSets)
    self.setName = setName
    self.puzzles = puzzles or {}
    self.puzzleSets = puzzleSets or {}
  end
)

---@param filePath string
---@return PuzzleSet[]
function PuzzleSet.loadFromFile(filePath)
  local data = FileUtils.readJsonFile(filePath)
  local puzzleSets = {}

  if data then
    if data["Version"] == 3 then
      for _, puzzleSetData in pairs(data["Puzzle Sets"]) do
        puzzleSets[#puzzleSets+1] = PuzzleSet.loadV3(puzzleSetData)
      end
    elseif data["Version"] == 2 then
      for _, puzzleSetData in pairs(data["Puzzle Sets"]) do
        puzzleSets[#puzzleSets+1] = PuzzleSet.loadV2(puzzleSetData)
      end
    elseif data["Version"] and type(data["Version"]) == "number" then
      logger.warn("Puzzle " .. filePath .. " specifies invalid version " .. data["Version"])
    else
      -- old file format compatibility
      -- the old file format actually has NO markers to identify it as a puzzle which means that we just have to try and import
      local successCounter = 0
      local result, error = pcall(function()
        for setName, puzzleSet in pairs(data) do
          if type(setName) == "string" and type(puzzleSet) == "table" then
            local v1Set = PuzzleSet.loadV1(setName, puzzleSet)
            if v1Set then
              puzzleSets[#puzzleSets+1] = v1Set
              successCounter = successCounter + 1
            end
          end
        end
      end)

      if successCounter == 0 then
        logger.warn("Failed to import invalid file " .. filePath .. " as a puzzle")
      elseif result == false then
        logger.warn("Encountered an error when trying to import puzzle file:\n" .. error)
      end
    end
  end

  for _, puzzleSet in ipairs(puzzleSets) do
    puzzleSet.fileSource = filePath
  end

  return puzzleSets
end

---@return PuzzleSet?
function PuzzleSet.loadV1(setName, puzzleSetData)
  local puzzles = {}
  for _, puzzleData in pairs(puzzleSetData) do
    if type(puzzleData) == "table" and #puzzleData >= 2 and type(puzzleData[1]) == "string" and type(puzzleData[2]) == "number" then
      local puzzle = Puzzle("moves", true, puzzleData[2], puzzleData[1])
      if puzzle:validate() then
        puzzles[#puzzles + 1] = puzzle
      end
    end
  end

  if #puzzles > 0 then
    return PuzzleSet(setName, puzzles)
  end
end

---@return PuzzleSet
function PuzzleSet.loadV2(puzzleSetData)
  local puzzleSetName = puzzleSetData["Set Name"]
  local puzzles = {}
  for _, puzzleData in pairs(puzzleSetData["Puzzles"]) do
    local puzzle = Puzzle(puzzleData["Puzzle Type"], puzzleData["Do Countdown"], puzzleData["Moves"], puzzleData["Stack"], puzzleData["Stop"], puzzleData["Shake"])
    puzzles[#puzzles + 1] = puzzle
  end

  return PuzzleSet(puzzleSetName, puzzles)
end

---@return PuzzleSet
function PuzzleSet.loadV3(puzzleSetData)
  local puzzleSetName = puzzleSetData["Set Name"]
  local puzzleSet = PuzzleSet(puzzleSetName, {}, {})

  for _, puzzleData in pairs(puzzleSetData["Puzzles"] or {}) do
    local puzzle = Puzzle(puzzleData["Puzzle Type"], puzzleData["Do Countdown"], puzzleData["Moves"], puzzleData["Stack"], puzzleData["Stop"], puzzleData["Shake"])
    puzzleSet.puzzles[#puzzleSet.puzzles + 1] = puzzle
  end
  for _, currentPuzzleSet in pairs(puzzleSetData["Puzzle Sets"] or {}) do
    puzzleSet.puzzleSets[#puzzleSet.puzzleSets + 1] = PuzzleSet.loadV3(currentPuzzleSet)
  end

  return puzzleSet
end

return PuzzleSet