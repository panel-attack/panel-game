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
---@return PuzzleSet?
function PuzzleSet.loadFromFile(filePath)
  local data = FileUtils.readJsonFile(filePath)

  if data then
    local set

    if data["Version"] == 2 then
      for _, puzzleSet in pairs(data["Puzzle Sets"]) do
        local puzzleSetName = puzzleSet["Set Name"]
        local puzzles = {}
        for _, puzzle in pairs(puzzleSet["Puzzles"]) do
          local puzzle = Puzzle(puzzle["Puzzle Type"], puzzle["Do Countdown"], puzzle["Moves"], puzzle["Stack"], puzzle["Stop"], puzzle["Shake"])
          puzzles[#puzzles + 1] = puzzle
        end

        set = PuzzleSet(puzzleSetName, puzzles)
      end
    elseif data["Version"] ~= 2 and data["Version"] then
      error("Puzzle " .. filePath .. " specifies invalid version " .. data["Version"])
    else -- old file format compatibility
      for setName, puzzleSet in pairs(data) do
        local puzzles = {}
        for _, puzzleData in pairs(puzzleSet) do
          local puzzle = Puzzle("moves", true, puzzleData[2], puzzleData[1])
          puzzles[#puzzles + 1] = puzzle
        end

        set = PuzzleSet(setName, puzzles)
      end
    end

    set.fileSource = filePath
    return set
  end
end

return PuzzleSet