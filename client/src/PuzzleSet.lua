local class = require("common.lib.class")
local FileUtils = require("client.src.FileUtils")
local Puzzle = require("common.engine.Puzzle")
local logger = require("common.lib.logger")

-- A puzzle set is a set of puzzles, typically they have a common difficulty or theme.
---@class PuzzleSet
---@field setName string
---@field description string
---@field puzzles Puzzle[]
---@field fileSource string?
local PuzzleSet = class(
function(self, setName, description, puzzles, puzzleSets)
  self.setName = setName
  self.description = description or ""
  self.puzzles = puzzles or {}
  self.puzzleSets = puzzleSets or {}
end)

---@param filePath string
---@return PuzzleSet[]
function PuzzleSet.loadFromFile(filePath)
  local data = FileUtils.readJsonFile(filePath)
  local puzzleSets = {}

  if data then
    if data["Version"] == 3 then
      for _, puzzleSetData in pairs(data["Puzzle Sets"]) do
        puzzleSets[#puzzleSets + 1] = PuzzleSet.loadV3(puzzleSetData)
      end
    elseif data["Version"] == 2 then
      for _, puzzleSetData in pairs(data["Puzzle Sets"]) do
        puzzleSets[#puzzleSets + 1] = PuzzleSet.loadV2(puzzleSetData)
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
              puzzleSets[#puzzleSets + 1] = v1Set
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
      local args = {
        puzzleType = "moves",
        startTiming = "countdown",
        moves = puzzleData[2],
        stack = puzzleData[1]
      }
      local puzzle = Puzzle(args)
      if puzzle:validate() then
        puzzles[#puzzles + 1] = puzzle
      end
    end
  end

  if #puzzles > 0 then
    return PuzzleSet(setName, nil, puzzles)
  end
end

---@return PuzzleSet
function PuzzleSet.loadV2(puzzleSetData)
  local puzzleSetName = loc(puzzleSetData["Set Name"])
  local puzzles = {}
  for _, puzzleData in pairs(puzzleSetData["Puzzles"]) do
    local args = {
      puzzleType = puzzleData["Puzzle Type"],
      startTiming = puzzleData["Do Countdown"] and "countdown" or "immediately",
      moves = puzzleData["Moves"],
      stack = puzzleData["Stack"],
      stopTime = puzzleData["Stop"],
      shakeTime = puzzleData["Shake"],
    }
    local puzzle = Puzzle(args)
    puzzles[#puzzles + 1] = puzzle
  end

  return PuzzleSet(puzzleSetName, nil, puzzles)
end

---@return PuzzleSet
function PuzzleSet.loadV3(puzzleSetData)
  local puzzleSetName = loc(puzzleSetData["Set Name"])
  local puzzleSetDescription = puzzleSetData["Description"]
  puzzleSetDescription = puzzleSetDescription and loc(puzzleSetDescription) or nil
  local puzzleSet = PuzzleSet(puzzleSetName, puzzleSetDescription, {}, {})

  for _, puzzleData in pairs(puzzleSetData["Puzzles"] or {}) do
    local args = {
      puzzleType = puzzleData["Puzzle Type"],
      startTiming = puzzleData["StartTiming"],
      moves = puzzleData["Moves"],
      stack = puzzleData["Stack"],
      stopTime = puzzleData["Stop"],
      shakeTime = puzzleData["Shake"],
      panelBuffer = puzzleData["PanelBuffer"],
      garbagePanelBuffer = puzzleData["GarbagePanelBuffer"]
    }
    if puzzleData["CursorStartLeft"] then
      args.cursorStartLeft = {row = puzzleData["CursorStartLeft"].Row, column = puzzleData["CursorStartLeft"].Column}
    end

    local puzzle = Puzzle(args)
    puzzleSet.puzzles[#puzzleSet.puzzles + 1] = puzzle
  end
  for _, currentPuzzleSet in pairs(puzzleSetData["Puzzle Sets"] or {}) do
    puzzleSet.puzzleSets[#puzzleSet.puzzleSets + 1] = PuzzleSet.loadV3(currentPuzzleSet)
  end

  return puzzleSet
end

return PuzzleSet