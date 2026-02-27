local tableUtils = require("common.lib.tableUtils")
local class = require("common.lib.class")
local GameModes = require("common.data.GameModes")
local PuzzleSource = require("common.engine.PuzzleSource")
local MatchRules = require("common.data.MatchRules")
local Panel = require("common.engine.Panel")
local system = require("client.src.system")

---@class GridCoordinate
---@field row integer
---@field column integer

---@class PuzzleArgs
---@field puzzleType PuzzleType
---@field stack string representation of the panel colors, the last character is the bottom right panel
---@field startTiming PuzzleStartTiming?
---@field cursorStartLeft GridCoordinate?
---@field moves integer? in how many swaps the puzzle has to be solved
---@field solution string? compressed input string for puzzle solution
---@field helpDescription string? optional help text explaining the puzzle pattern

---@class GarbagePuzzleArgs : PuzzleArgs
---@field stopTime integer?
---@field shakeTime integer?
---@field panelBuffer string?
---@field garbagePanelBuffer string?

-- A puzzle is a particular instance of the game, where there is a specific goal for clearing the panels
---@class Puzzle
---@field puzzleType PuzzleType
---@field startTiming PuzzleStartTiming
---@field stack string string representation of the panel colors
---@field cursorStartLeft GridCoordinate?
---@field moves integer
---@field stopTime integer?
---@field shakeTime integer?
---@field panelBuffer string
---@field garbageBuffer string
---@field randomizeColors boolean
---@field UUID string
---@field solution string? compressed input string for puzzle solution
---@field helpDescription string? optional help text explaining the puzzle pattern
---@field puzzleEverBeaten boolean? dynamically added field indicating if this puzzle was ever completed
---@field trainingDate number? dynamically added field for spaced repetition training scheduling
---@overload fun(puzzleArgs: GarbagePuzzleArgs): Puzzle
Puzzle = class(
---@param self Puzzle
---@param puzzleArgs GarbagePuzzleArgs
  function(self, puzzleArgs)
    self.puzzleType = puzzleArgs.puzzleType or Puzzle.PUZZLE_TYPES.moves
    self.cursorStartLeft = puzzleArgs.cursorStartLeft
    if puzzleArgs.startTiming then
      self.startTiming = puzzleArgs.startTiming
    else
      if self.puzzleType == Puzzle.PUZZLE_TYPES.clear or self.puzzleType == Puzzle.PUZZLE_TYPES.chain then
        if self.cursorStartLeft then
          self.startTiming = Puzzle.START_TIMINGS.firstInput
        else
          self.startTiming = Puzzle.START_TIMINGS.firstSwap
        end
      else
        self.startTiming = Puzzle.START_TIMINGS.immediately
      end
    end
    self.stack = string.gsub(puzzleArgs.stack, "%s+", "") -- Remove whitespace so files can be easier to read
    self.moves = puzzleArgs.moves or 0

    self.panelBuffer = puzzleArgs.panelBuffer
    self.garbageBuffer = puzzleArgs.garbagePanelBuffer
    self.stopTime = puzzleArgs.stopTime
    self.shakeTime = puzzleArgs.shakeTime
    self.solution = puzzleArgs.solution
    self.helpDescription = puzzleArgs.helpDescription

    self.UUID = Puzzle.getV2UUID(self)
    self.randomizeColors = false
  end
)

-- Helper function to handle Love2D version compatibility for hashing
---@param hashString string
---@return string
local function hashAndEncode(hashString)
  -- We specify string so its okay to disable diagnostic
  if system.meetsLoveVersionRequirement(12, 0) then
    ---@diagnostic disable-next-line: redundant-parameter, param-type-mismatch
    local digest = love.data.hash("string", "sha256", hashString)
    ---@diagnostic disable-next-line: return-type-mismatch
    return love.data.encode("string", "hex", digest)
  else
    -- Love 11 compatibility
    ---@diagnostic disable-next-line: return-type-mismatch, missing-parameter, param-type-mismatch
    return love.data.encode("string", "hex", love.data.hash("sha256", hashString))
  end
end

---@param puzzle Puzzle
---@return string
function Puzzle.getV1UUID(puzzle)
  local nilString = tostring(nil) -- (puzzle.startTiming == Puzzle.START_TIMINGS.countdown) and tostring(true) or tostring(false)
  local hashString = puzzle.stack .. puzzle.puzzleType .. tostring(false) .. tostring(puzzle.moves) .. nilString .. nilString
  return hashAndEncode(hashString)
end

---@param puzzle Puzzle
---@return string
function Puzzle.getV2UUIDOld(puzzle)
  local hashString = puzzle.stack .. puzzle.puzzleType .. tostring(puzzle.startTiming) .. tostring(puzzle.moves) .. tostring(puzzle.stopTime) .. tostring(puzzle.shakeTime)
  return hashAndEncode(hashString)
end

---@param puzzle Puzzle
---@return string
function Puzzle.getV2UUID(puzzle)
  local cursorString = ""
  if puzzle.cursorStartLeft then
    cursorString = tostring(puzzle.cursorStartLeft.row) .. "," .. tostring(puzzle.cursorStartLeft.column)
  end
  local hashString = puzzle.stack .. puzzle.puzzleType .. tostring(puzzle.startTiming) .. tostring(puzzle.moves) .. tostring(puzzle.stopTime) .. tostring(puzzle.shakeTime) .. cursorString .. tostring(puzzle.panelBuffer) .. tostring(puzzle.garbageBuffer)
  return hashAndEncode(hashString)
end

---@alias PuzzleStartTiming "countdown" | "immediately" | "firstInput" | "firstSwap"

Puzzle.START_TIMINGS = { countdown = "countdown", immediately = "immediately", firstInput = "firstInput", firstSwap = "firstSwap" }
---@enum PuzzleType
Puzzle.PUZZLE_TYPES = { moves = "moves", chain = "chain", clear = "clear" }
Puzzle.LEGAL_CHARACTERS = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "[", "]", "{", "}", "=" }

Puzzle.PUZZLE_PROPERTY = {
  TYPE = "Puzzle Type",
  START_TIMING = "StartTiming",
  MOVES = "Moves",
  STOP = "Stop",
  SHAKE = "Shake",
  STACK = "Stack",
  PANEL_BUFFER = "PanelBuffer",
  GARBAGE_PANEL_BUFFER = "GarbagePanelBuffer",
  CURSOR_START_LEFT = "CursorStartLeft",
  SOLUTION = "Solution",
  HELP_DESCRIPTION = "Help Description"
}


Puzzle.CURSOR_PROPERTY = {
  COLUMN = "Column",
  ROW = "Row"
}


local validPuzzleProperties = {}
for _, property in pairs(Puzzle.PUZZLE_PROPERTY) do
  validPuzzleProperties[property] = true
end

local validCursorProperties = {}
for _, property in pairs(Puzzle.CURSOR_PROPERTY) do
  validCursorProperties[property] = true
end


function Puzzle.isValidPuzzleProperty(property)
  return validPuzzleProperties[property] == true
end

function Puzzle.isValidCursorProperty(property)
  return validCursorProperties[property] == true
end

-- Helper functions for consistent key ordering
---@return string[]
function Puzzle.getPuzzleKeyOrder()
  return {
    Puzzle.PUZZLE_PROPERTY.TYPE,
    Puzzle.PUZZLE_PROPERTY.START_TIMING,
    Puzzle.PUZZLE_PROPERTY.MOVES,
    Puzzle.PUZZLE_PROPERTY.STOP,
    Puzzle.PUZZLE_PROPERTY.SHAKE,
    Puzzle.PUZZLE_PROPERTY.STACK,
    Puzzle.PUZZLE_PROPERTY.PANEL_BUFFER,
    Puzzle.PUZZLE_PROPERTY.GARBAGE_PANEL_BUFFER,
    Puzzle.PUZZLE_PROPERTY.CURSOR_START_LEFT,
    Puzzle.PUZZLE_PROPERTY.SOLUTION,
    Puzzle.PUZZLE_PROPERTY.HELP_DESCRIPTION
  }
end


---@return string[]
function Puzzle.getCursorKeyOrder()
  return {
    Puzzle.CURSOR_PROPERTY.COLUMN,
    Puzzle.CURSOR_PROPERTY.ROW
  }
end

---@param width integer
---@param height integer
---@return string puzzleString
function Puzzle:fillMissingPanelsInPuzzleString(width, height)
  local puzzleString = self.stack
  local boardSizeInPanels = width * height
  if self.puzzleType == Puzzle.PUZZLE_TYPES.clear then
    -- first fill up the currently started row
    local fillUpLength = (puzzleString:len() % width)
    if fillUpLength > 0 then
      puzzleString = string.rep("0", width - fillUpLength) .. puzzleString
    end
  else
    puzzleString = string.rep("0", boardSizeInPanels - string.len(puzzleString)) .. puzzleString
  end

  return puzzleString
end

---@param puzzleString string
---@return string puzzleString, string panelBuffer, string garbageBuffer
function Puzzle.randomizeColorsInPuzzleString(puzzleString, panelBuffer, garbageBuffer)
  local colorArray = Panel.regularColorsArray()
  if puzzleString:find("7") then
    colorArray = Panel.extendedRegularColorsArray()
  end
  local newColorOrder = {}

  for _ = 1, #colorArray, 1 do
    newColorOrder[tostring(tableUtils.length(newColorOrder)+1)] = tostring(table.remove(colorArray, love.math.random(1, #colorArray)))
  end

  puzzleString = puzzleString:gsub("%d", newColorOrder)
  panelBuffer = panelBuffer and panelBuffer:gsub("%d", newColorOrder) or ""
  garbageBuffer = garbageBuffer and garbageBuffer:gsub("%d", newColorOrder) or ""

  return puzzleString, panelBuffer, garbageBuffer
end

---@return boolean isValid
---@return string problems
function Puzzle:validate()
  local errMessage = ""

  if type(self.startTiming) ~= "string" or Puzzle.START_TIMINGS[self.startTiming] == nil then
    errMessage = "\nInvalid value for property 'startTiming'"
  end

  local stackLength = string.len(self.stack)
  if stackLength > 6*12 then
    -- any encoded panels extending beyond the height of the playfield need to be garbage or empty
    local overflowStack = self.stack:sub(1, stackLength - 72)
    local matches = {}
    for match in string.gmatch(overflowStack, "[1-9]") do
      matches[#matches+1] = match
    end
    if #matches > 0 then
      errMessage = errMessage ..
     "\nThere cannot be any panels on above the top of the stack, only garbage and whitespace." ..
     "\nPanels above the top identified: " .. table.concat(matches)
    end
  end

  local illegalCharacters = {}
  local pendingGarbageStart = nil
  local pendingGarbageStartIndex = 0
  for i = 1, #self.stack do
    local char = string.sub(self.stack, i, i)
    if not tableUtils.contains(Puzzle.LEGAL_CHARACTERS, char)
      and not tableUtils.contains(illegalCharacters, char) then
      table.insert(illegalCharacters, char)
    end
    if char == "[" or char == "{" then
      if not pendingGarbageStart then
        pendingGarbageStart = char
        pendingGarbageStartIndex = i
      else
        errMessage = errMessage ..
        "\nPuzzlestring contains invalid garbage notation, make sure you close garbage before you open another."
      end
    elseif char == "]" and pendingGarbageStart ~= "[" and pendingGarbageStart
      or char == "}" and pendingGarbageStart ~= "{" and pendingGarbageStart then
        errMessage = errMessage ..
        "\nPuzzlestring contains invalid garbage notation, make sure to not mix the symbols for opening/closing regular and shock garbage in your puzzle."
    elseif char == "]" and pendingGarbageStart == "["
      or char == "}" and pendingGarbageStart == "{" then
        if (i + 1 - pendingGarbageStartIndex) - 6 > 0 then-- more than 6 panels in the garbage -> chain garbage
          if ((i + 1 - pendingGarbageStartIndex) % 6 > 0 -- length of the garbage is not valid (needs to be divisable by 6)
            or (i % 6 > 0)) then -- end position of the garbage is not valid (needs to be at the end of a row)
            errMessage = errMessage ..
            "\nPuzzlestring contains invalid garbage notation, make sure to enter a valid length for chain type garbage, creating garbage that is  possible to encounter in the game."
          end
        else -- combo garbage
          if math.floor((i - 1) / 6) ~= math.floor(pendingGarbageStartIndex / 6) then
            errMessage = errMessage ..
            "\nPuzzlestring contains invalid garbage notation, make sure that your combo garbage does not extend over the scope of a single row."
          end
        end
        -- garbage has been properly closed - most likely
        pendingGarbageStart = nil
    end
  end

  if #illegalCharacters > 0 then
    errMessage = errMessage .. "\nPuzzlestring contains invalid characters: " .. table.concat(illegalCharacters, ", ")
  end

  if not Puzzle.PUZZLE_TYPES[self.puzzleType] then
    errMessage = errMessage ..
    "\nInvalid puzzle type detected, available puzzle types are: " .. table.concat(Puzzle.PUZZLE_TYPES, ", ")
  end

  if self.puzzleType == Puzzle.PUZZLE_TYPES.moves and (not tonumber(self.moves) or tonumber(self.moves) < 1 ) then
    errMessage = errMessage ..
    "\nInvalid number of moves detected, expecting a number greater than zero but instead got " .. self.moves
  end

  if self.cursorStartLeft then
    if not (self.cursorStartLeft.row >= 1 and self.cursorStartLeft.row <= 12) or not (self.cursorStartLeft.column >= 1 and self.cursorStartLeft.column <= 5) then
      errMessage = errMessage ..
      "\nInvalid cursor start position, expected row to be between 1 and 12 and column to be between 1 and 5"
    end
  end

  return errMessage == "", errMessage
end

-- Helper function to convert a single puzzle to save data format
---@return table
function Puzzle:getSaveData()
  ---@type table<string, any>
  local puzzleData = {
    [Puzzle.PUZZLE_PROPERTY.TYPE] = self.puzzleType,
    [Puzzle.PUZZLE_PROPERTY.START_TIMING] = self.startTiming,
    [Puzzle.PUZZLE_PROPERTY.MOVES] = self.moves,
    [Puzzle.PUZZLE_PROPERTY.STOP] = self.stopTime,
    [Puzzle.PUZZLE_PROPERTY.SHAKE] = self.shakeTime,
    [Puzzle.PUZZLE_PROPERTY.STACK] = self.stack,
    [Puzzle.PUZZLE_PROPERTY.PANEL_BUFFER] = self.panelBuffer,
    [Puzzle.PUZZLE_PROPERTY.GARBAGE_PANEL_BUFFER] = self.garbageBuffer,
    [Puzzle.PUZZLE_PROPERTY.SOLUTION] = self.solution,
    [Puzzle.PUZZLE_PROPERTY.HELP_DESCRIPTION] = self.helpDescription
  }

  if self.cursorStartLeft then
    puzzleData[Puzzle.PUZZLE_PROPERTY.CURSOR_START_LEFT] = {
      [Puzzle.CURSOR_PROPERTY.COLUMN] = self.cursorStartLeft.column,
      [Puzzle.CURSOR_PROPERTY.ROW] = self.cursorStartLeft.row
    }
  end

  return puzzleData
end

---@param panels Panel[][]
---@return string puzzleString
function Puzzle.toPuzzleString(panels)
  local function getPanelColor(panel)
    if panel.isGarbage then
      local effectiveHeight = panel.height
      if panel.state == "matched" then
        -- this is making the assumption that garbage that is currently clearing into panels is still to be included for the garbage block
        effectiveHeight = panel.height + 1
      end
      -- offsets are being calculated from the bottom left corner of garbage
      -- but we need to go in our order of traversal, therefore...
      -- top left anchor point
      if panel.x_offset == 0 and panel.y_offset == panel.height - 1 then
        -- garbage start
        if panel.metal then
          return "{"
        else
          return "["
        end
      -- bottom right anchor point
      elseif panel.x_offset == panel.width - 1 and panel.y_offset == panel.height - effectiveHeight then
        -- garbage end
        if panel.metal then
          return "}"
        else
          return "]"
        end
      else
        -- garbage body
        return "="
      end
    else
      return tostring(panel.color)
    end
  end
  local puzzleMatrix = {}

  for row = #panels, 1, -1 do
    for column = 1, #panels[row] do
      puzzleMatrix[#puzzleMatrix+1] = getPanelColor(panels[row][column])
    end
  end

  return table.concat(puzzleMatrix)
end

---@return GameMode
function Puzzle:toGameMode()
  local mode = GameModes.getPreset(GameModes.IDs.ONE_PLAYER_PUZZLE)
  if not mode.matchRules.stackSetupModifications then
    mode.matchRules.stackSetupModifications = { behaviours = {}}
  elseif not mode.matchRules.stackSetupModifications.behaviours then
    mode.matchRules.stackSetupModifications.behaviours = {}
  end

  if self.moves > 0 then
    mode.matchRules.stackOverConditions[MatchRules.StackOverConditions.SWAPS] = self.moves
  end

  if self.puzzleType == Puzzle.PUZZLE_TYPES.clear then
    mode.matchRules.stackOverConditions[MatchRules.StackOverConditions.HEALTH] = 0
    mode.matchRules.stackWinConditions[MatchRules.StackWinConditions.MATCHABLE_GARBAGE_PANELS] = 0
    mode.matchRules.stackSetupModifications.stopTime = self.stopTime
    mode.matchRules.stackSetupModifications.shakeTime = self.shakeTime
  else
    mode.matchRules.stackSetupModifications.behaviours = {
      allowManualRaise = false,
      passiveRaise = false,
    }
    if self.puzzleType == Puzzle.PUZZLE_TYPES.chain then
      mode.matchRules.stackOverConditions[MatchRules.StackOverConditions.CHAIN] = false
      mode.matchRules.stackWinConditions[MatchRules.StackWinConditions.MATCHABLE_PANELS] = 0
    elseif self.puzzleType == Puzzle.PUZZLE_TYPES.moves then
      mode.matchRules.stackWinConditions[MatchRules.StackWinConditions.MATCHABLE_PANELS] = 0
    end
  end

  mode.matchRules.stackSetupModifications.behaviours.swapStallingMode = 0
  if self.startTiming == Puzzle.START_TIMINGS.countdown then
    mode.matchRules.doCountdown = true
    mode.matchRules.stackSetupModifications.behaviours.delaySimulationUntil = "countdownEnded"
  elseif self.startTiming == Puzzle.START_TIMINGS.firstInput then
    mode.matchRules.stackSetupModifications.behaviours.delaySimulationUntil = "firstInput"
  elseif self.startTiming == Puzzle.START_TIMINGS.firstSwap then
    mode.matchRules.stackSetupModifications.behaviours.delaySimulationUntil = "firstSwap"
  end

  if self.cursorStartLeft then
    mode.matchRules.stackSetupModifications.startingRow = self.cursorStartLeft.row
    mode.matchRules.stackSetupModifications.startingCol = self.cursorStartLeft.column
  end

  return mode
end

---@param randomize boolean?
---@return PuzzleSource
function Puzzle:toPanelSource(randomize)
  local puzzleString = self:fillMissingPanelsInPuzzleString(6, 12)
  local panelBuffer = self.panelBuffer
  local garbageBuffer = self.garbageBuffer

  if randomize then
    puzzleString, panelBuffer, garbageBuffer = Puzzle.randomizeColorsInPuzzleString(puzzleString, panelBuffer, garbageBuffer)
  end

  return PuzzleSource(puzzleString, panelBuffer, garbageBuffer)
end

---@param puzzleString string
---@param originalPuzzle Puzzle
---@return Puzzle
function Puzzle.newPuzzleWithPuzzleString(puzzleString, originalPuzzle)
  return Puzzle({
    puzzleType = originalPuzzle.puzzleType,
    stack = puzzleString,
    moves = originalPuzzle.moves,
    startTiming = originalPuzzle.startTiming,
    cursorStartLeft = originalPuzzle.cursorStartLeft,
    stopTime = originalPuzzle.stopTime,
    shakeTime = originalPuzzle.shakeTime,
    panelBuffer = originalPuzzle.panelBuffer,
    garbagePanelBuffer = originalPuzzle.garbageBuffer,
    solution = originalPuzzle.solution,
    helpDescription = originalPuzzle.helpDescription
  })
end

return Puzzle