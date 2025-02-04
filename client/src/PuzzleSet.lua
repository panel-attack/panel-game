local class = require("common.lib.class")
local FileUtils = require("client.src.FileUtils")
local Puzzle = require("common.engine.Puzzle")

-- A puzzle set is a set of puzzles, typically they have a common difficulty or theme.
local PuzzleSet =
  class(
  function(self, setName, puzzles)
    self.setName = setName
    self.puzzles = puzzles
  end
)

function PuzzleSet.loadFromFile(filename)
  local data = FileUtils.readJsonFile(filename)

  if data then
    if data["Version"] == 2 then
      for _, puzzleSet in pairs(data["Puzzle Sets"]) do
        local puzzleSetName = puzzleSet["Set Name"]
        local puzzles = {}
        for _, puzzle in pairs(puzzleSet["Puzzles"]) do
          local puzzle = Puzzle(puzzle["Puzzle Type"], puzzle["Do Countdown"], puzzle["Moves"], puzzle["Stack"], puzzle["Stop"], puzzle["Shake"])
          puzzles[#puzzles + 1] = puzzle
        end

        return PuzzleSet(puzzleSetName, puzzles)
      end
    elseif data["Version"] ~= 2 and data["Version"] then
      error("Puzzle " .. filename .. " specifies invalid version " .. data["Version"])
    else -- old file format compatibility
      for set_name, puzzle_set in pairs(data) do
        local puzzles = {}
        for _, puzzleData in pairs(puzzle_set) do
          local puzzle = Puzzle("moves", true, puzzleData[2], puzzleData[1])
          puzzles[#puzzles + 1] = puzzle
        end

        return PuzzleSet(set_name, puzzles)
      end
    end
  end
end

return PuzzleSet