local class = require("common.lib.class")
local FileUtils = require("client.src.FileUtils")
local Puzzle = require("common.engine.Puzzle")

-- A puzzle set is a set of puzzles, typically they have a common difficulty or theme.
---@class PuzzleSet
---@field setName string
---@field puzzles Puzzle[]
---@field fileSource string?
local PuzzleSet =
  class(
  function(self, setName, puzzles)
    self.setName = setName
    self.puzzles = puzzles
  end
)

---@param filePath string
---@return PuzzleSet[]
function PuzzleSet.loadFromFile(filePath)
  local data = FileUtils.readJsonFile(filePath)
  local puzzleSets = {}

  if data then
    if data["Version"] == 2 then
      for _, puzzleSetData in pairs(data["Puzzle Sets"]) do
        puzzleSets[#puzzleSets+1] = PuzzleSet.loadV2(puzzleSetData)
      end
    elseif data["Version"] ~= 2 and data["Version"] then
      error("Puzzle " .. filePath .. " specifies invalid version " .. data["Version"])
    else -- old file format compatibility
      for setName, puzzleSet in pairs(data) do
        puzzleSets[#puzzleSets+1] = PuzzleSet.loadV1(setName, puzzleSet)
      end
    end
  end

  for _, puzzleSet in ipairs(puzzleSets) do
    puzzleSet.fileSource = filePath
  end

  return puzzleSets
end

---@return PuzzleSet
function PuzzleSet.loadV1(setName, puzzleSetData)
  local puzzles = {}
  for _, puzzleData in pairs(puzzleSetData) do
    local puzzle = Puzzle("moves", true, puzzleData[2], puzzleData[1])
    puzzles[#puzzles + 1] = puzzle
  end

  return PuzzleSet(setName, puzzles)
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

return PuzzleSet