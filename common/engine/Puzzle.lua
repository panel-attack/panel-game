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

---@class PuzzleGoal
---@field kind PuzzleGoalKind
---@field size integer? the chain or combo size asked for
---@field text string? what the file said, kept for a goal that could not be read

---@class PuzzleArgs
---@field goals (string | PuzzleGoal)[]? everything the puzzle asks for, in the file spelling or already read
---@field puzzleType PuzzleType? the one word type of a version 3 file, used when there are no goals
---@field stack string representation of the panel colors, the last character is the bottom right panel
---@field startTiming PuzzleStartTiming?
---@field cursorStartLeft GridCoordinate?
---@field moves integer? in how many swaps the puzzle has to be solved
---@field solution string? compressed input string for puzzle solution
---@field helpDescription string? optional help text explaining the puzzle pattern
---@field oldUUIDs string[]? the UUIDs the puzzle had before its data changed, oldest first

---@class GarbagePuzzleArgs : PuzzleArgs
---@field stopTime integer?
---@field shakeTime integer?
---@field panelBuffer string?
---@field garbagePanelBuffer string?

-- A puzzle is a particular instance of the game, where there is a specific goal for clearing the panels
---@class Puzzle
---@field goals PuzzleGoal[] everything that has to be achieved to win, a goal listed twice has to be achieved twice
---@field puzzleType PuzzleType the one word type the goals amount to, "goals" if they are no such type
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
---@field oldUUIDs string[]? the UUIDs the puzzle had before its data changed, so records saved under them can be carried to this one
---@field fileIndex integer? which entry of its set in the file the puzzle was read from, set by the loader; a puzzle the loader hid leaves a gap, so this is not its position in the set
---@field puzzleEverBeaten boolean? dynamically added field indicating if this puzzle was ever completed
---@field trainingDate number? dynamically added field for spaced repetition training scheduling
---@overload fun(puzzleArgs: GarbagePuzzleArgs): Puzzle
Puzzle = class(
---@param self Puzzle
---@param puzzleArgs GarbagePuzzleArgs
  function(self, puzzleArgs)
    if puzzleArgs.goals then
      self.goals = Puzzle.readGoals(puzzleArgs.goals)
    else
      self.goals = Puzzle.goalsOfLegacyType(puzzleArgs.puzzleType or Puzzle.PUZZLE_TYPES.moves)
    end
    self.puzzleType = Puzzle.legacyTypeOfGoals(self.goals)
    self.cursorStartLeft = puzzleArgs.cursorStartLeft
    if puzzleArgs.startTiming then
      self.startTiming = puzzleArgs.startTiming
    else
      if self.puzzleType ~= Puzzle.PUZZLE_TYPES.moves then
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
    -- an empty buffer is stored as none at all so it does not write a junk key or change the puzzle's UUID
    self.garbageBuffer = puzzleArgs.garbagePanelBuffer ~= "" and puzzleArgs.garbagePanelBuffer or nil
    self.stopTime = puzzleArgs.stopTime
    self.shakeTime = puzzleArgs.shakeTime
    self.solution = puzzleArgs.solution
    self.helpDescription = puzzleArgs.helpDescription
    self.oldUUIDs = puzzleArgs.oldUUIDs

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
  -- a puzzle that is one of the old one word types hashes that word, so the goal list did not change any puzzle's UUID
  local typeString = puzzle.puzzleType
  if typeString == Puzzle.GOALS_TYPE then
    typeString = table.concat(puzzle:goalsToFile(), ",")
  end
  local hashString = puzzle.stack .. typeString .. tostring(puzzle.startTiming) .. tostring(puzzle.moves) .. tostring(puzzle.stopTime)
    .. tostring(puzzle.shakeTime) .. cursorString .. tostring(puzzle.panelBuffer) .. tostring(puzzle.garbageBuffer)
  return hashAndEncode(hashString)
end

---@alias PuzzleStartTiming "countdown" | "immediately" | "firstInput" | "firstSwap"

Puzzle.START_TIMINGS = { countdown = "countdown", immediately = "immediately", firstInput = "firstInput", firstSwap = "firstSwap" }
-- how a puzzle file spells each start timing; files written before the saver was fixed used the START_TIMINGS spelling
Puzzle.START_TIMING_IN_FILE = { countdown = "Countdown", immediately = "Immediately", firstInput = "First Input", firstSwap = "First Swap" }

-- Both spellings are read so that a file written before the saver was fixed still says what it means.
---@param value any the StartTiming read from a puzzle file
---@return PuzzleStartTiming? startTiming nil for a value that is not a start timing
function Puzzle.startTimingFromFile(value)
  for startTiming, fileValue in pairs(Puzzle.START_TIMING_IN_FILE) do
    if value == fileValue or value == startTiming then
      return startTiming
    end
  end
end

-- Joins the values of a keyed table for a message, sorted, because pairs order is not stable and a
-- warning that reshuffles between runs is a nuisance to compare
---@param values table<any, string>
---@return string
local function sortedValueList(values)
  local list = {}
  for _, value in pairs(values) do
    list[#list + 1] = value
  end
  table.sort(list)

  return table.concat(list, ", ")
end

-- The StartTiming spellings a file may use, as a readable list, so a warning about a bad one can say
-- what would have been accepted
---@return string
function Puzzle.startTimingSpellings()
  return sortedValueList(Puzzle.START_TIMING_IN_FILE)
end

---@alias PuzzleType "moves" | "chain" | "clear" | "goals"
-- the types a version 3 file could name; a puzzle whose goals are none of them has the type "goals"
Puzzle.PUZZLE_TYPES = { moves = "moves", chain = "chain", clear = "clear" }

-- The puzzle types a version 3 file may name, as a readable list, so a warning about a bad one can say what
-- would have been accepted
---@return string
function Puzzle.puzzleTypeNames()
  return sortedValueList(Puzzle.PUZZLE_TYPES)
end

Puzzle.GOALS_TYPE = "goals"

---@alias PuzzleGoalKind "emptyBoard" | "clear" | "legacyChain" | "chain" | "combo" | "unknown"
-- legacyChain is the chain type of a version 3 file: empty the board without ever letting the chain end.
-- A goal list cannot ask for it, it only exists so those files play as they always did.
Puzzle.GOAL_KINDS = { emptyBoard = "emptyBoard", clear = "clear", legacyChain = "legacyChain", chain = "chain", combo = "combo",
                      unknown = "unknown" }
Puzzle.MIN_CHAIN_GOAL = 2
Puzzle.MIN_COMBO_GOAL = 4

local LEGACY_TYPE_TO_GOAL_KIND = {
  moves = Puzzle.GOAL_KINDS.emptyBoard,
  clear = Puzzle.GOAL_KINDS.clear,
  chain = Puzzle.GOAL_KINDS.legacyChain
}

-- Reads one goal as a puzzle file spells it, ignoring case and spaces: Empty Board, Clear, xN or +N
---@param value any one entry of a file's Puzzle Type list
---@return PuzzleGoal? goal nil for anything that is not a goal
function Puzzle.parseGoal(value)
  if type(value) ~= "string" then
    return nil
  end
  local text = string.lower(string.gsub(value, "%s+", ""))
  if text == "emptyboard" then
    return {kind = Puzzle.GOAL_KINDS.emptyBoard}
  elseif text == "clear" then
    return {kind = Puzzle.GOAL_KINDS.clear}
  end
  local chainSize = string.match(text, "^x(%d+)$")
  if chainSize then
    return {kind = Puzzle.GOAL_KINDS.chain, size = tonumber(chainSize)}
  end
  local comboSize = string.match(text, "^%+(%d+)$")
  if comboSize then
    return {kind = Puzzle.GOAL_KINDS.combo, size = tonumber(comboSize)}
  end
  return nil
end

-- Spells a goal the way a puzzle file writes it
---@param goal PuzzleGoal
---@return string # how a puzzle file spells the goal
function Puzzle.goalToFile(goal)
  if goal.kind == Puzzle.GOAL_KINDS.emptyBoard then
    return "Empty Board"
  elseif goal.kind == Puzzle.GOAL_KINDS.clear then
    return "Clear"
  elseif goal.kind == Puzzle.GOAL_KINDS.chain then
    return "x" .. goal.size
  elseif goal.kind == Puzzle.GOAL_KINDS.combo then
    return "+" .. goal.size
  end
  return tostring(goal.text)
end

-- an entry that is not a goal is kept as an unknown one so validate can name it
---@param goals (string | PuzzleGoal)[]
---@return PuzzleGoal[]
function Puzzle.readGoals(goals)
  local read = {}
  for i, goal in ipairs(goals) do
    if type(goal) == "table" then
      read[i] = {kind = goal.kind, size = goal.size, text = goal.text}
    else
      read[i] = Puzzle.parseGoal(goal) or {kind = Puzzle.GOAL_KINDS.unknown, text = tostring(goal)}
    end
  end
  return read
end

-- The goal a one-word puzzle type of a version 3 file stands for, an unknown goal for a word that is not a type
---@param puzzleType string
---@return PuzzleGoal[]
function Puzzle.goalsOfLegacyType(puzzleType)
  local kind = LEGACY_TYPE_TO_GOAL_KIND[puzzleType]
  if kind then
    return {{kind = kind}}
  end
  return {{kind = Puzzle.GOAL_KINDS.unknown, text = tostring(puzzleType)}}
end

-- The one-word type a goal list is the same as, so it plays and hashes like that type; the goals type for any other list
---@param goals PuzzleGoal[]
---@return PuzzleType
function Puzzle.legacyTypeOfGoals(goals)
  if #goals == 1 then
    for puzzleType, kind in pairs(LEGACY_TYPE_TO_GOAL_KIND) do
      if goals[1].kind == kind then
        return puzzleType
      end
    end
  end
  return Puzzle.GOALS_TYPE
end

-- Whether the puzzle asks for at least one goal of the kind
---@param kind PuzzleGoalKind
---@return boolean
function Puzzle:hasGoal(kind)
  for _, goal in ipairs(self.goals) do
    if goal.kind == kind then
      return true
    end
  end
  return false
end

-- How many times each size of the given kind is asked for
---@param kind PuzzleGoalKind chain or combo
---@return table<integer, integer>? counts nil if the puzzle has no goal of the kind
function Puzzle:goalCountsBySize(kind)
  local counts
  for _, goal in ipairs(self.goals) do
    if goal.kind == kind then
      counts = counts or {}
      counts[goal.size] = (counts[goal.size] or 0) + 1
    end
  end
  return counts
end

-- The goal list as a puzzle file writes it
---@return string[]
function Puzzle:goalsToFile()
  local written = {}
  for i, goal in ipairs(self.goals) do
    written[i] = Puzzle.goalToFile(goal)
  end
  return written
end
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
  HELP_DESCRIPTION = "Help Description",
  OLD_UUIDS = "Old UUIDs"
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
    Puzzle.PUZZLE_PROPERTY.HELP_DESCRIPTION,
    Puzzle.PUZZLE_PROPERTY.OLD_UUIDS
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
  if self:hasGoal(Puzzle.GOAL_KINDS.clear) then
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

-- Checks the goal list for validate
---@return string problems what is wrong with the goals, empty if nothing is
function Puzzle:goalProblems()
  local problems = ""
  if #self.goals == 0 then
    problems = problems .. "\nA puzzle needs at least one goal in its puzzle type"
  end
  for _, goal in ipairs(self.goals) do
    if goal.kind == Puzzle.GOAL_KINDS.unknown then
      problems = problems .. "\nInvalid puzzle type '" .. tostring(goal.text)
        .. "' detected, a goal is one of Empty Board, Clear, a chain like x4 or a combo like +6,"
        .. " and the one word type of a version 3 file is one of " .. Puzzle.puzzleTypeNames()
    elseif goal.kind == Puzzle.GOAL_KINDS.chain and goal.size < Puzzle.MIN_CHAIN_GOAL then
      problems = problems .. "\nThe smallest chain is x" .. Puzzle.MIN_CHAIN_GOAL .. ", got x" .. goal.size
    elseif goal.kind == Puzzle.GOAL_KINDS.combo and goal.size < Puzzle.MIN_COMBO_GOAL then
      problems = problems .. "\nThe smallest combo is +" .. Puzzle.MIN_COMBO_GOAL .. ", got +" .. goal.size
    end
  end
  return problems
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

  -- a revealed garbage row has to be panels; an empty cell there would leave a hole in the stack
  if self.garbageBuffer and self.garbageBuffer:find("[^1-9]") then
    errMessage = errMessage ..
    "\nGarbagePanelBuffer may only contain the colors 1-9, got " .. self.garbageBuffer
  end

  if type(self.moves) ~= "number" or self.moves < 0 then
    errMessage = errMessage ..
    "\nMoves has to be a number of swaps, or 0 for no limit, but got " .. tostring(self.moves)
  end

  errMessage = errMessage .. self:goalProblems()

  if self.cursorStartLeft then
    if not (self.cursorStartLeft.row >= 1 and self.cursorStartLeft.row <= 12) or not (self.cursorStartLeft.column >= 1 and self.cursorStartLeft.column <= 5) then
      errMessage = errMessage ..
      "\nInvalid cursor start position, expected row to be between 1 and 12 and column to be between 1 and 5"
    end
  end

  return errMessage == "", errMessage
end

-- Helper function to convert a single puzzle to save data format
---@param asLegacyType boolean? for a version 3 file, which names one type instead of listing goals
---@return table
function Puzzle:getSaveData(asLegacyType)
  if not asLegacyType and self:hasGoal(Puzzle.GOAL_KINDS.legacyChain) then
    error("Cannot save the puzzle as a list of goals: the chain type of a version 3 file is not a goal")
  end

  ---@type table<string, any>
  local puzzleData = {
    [Puzzle.PUZZLE_PROPERTY.TYPE] = asLegacyType and self.puzzleType or self:goalsToFile(),
    [Puzzle.PUZZLE_PROPERTY.START_TIMING] = Puzzle.START_TIMING_IN_FILE[self.startTiming],
    [Puzzle.PUZZLE_PROPERTY.MOVES] = self.moves,
    [Puzzle.PUZZLE_PROPERTY.STOP] = self.stopTime,
    [Puzzle.PUZZLE_PROPERTY.SHAKE] = self.shakeTime,
    [Puzzle.PUZZLE_PROPERTY.STACK] = self.stack,
    [Puzzle.PUZZLE_PROPERTY.PANEL_BUFFER] = self.panelBuffer,
    [Puzzle.PUZZLE_PROPERTY.GARBAGE_PANEL_BUFFER] = self.garbageBuffer,
    [Puzzle.PUZZLE_PROPERTY.SOLUTION] = self.solution,
    [Puzzle.PUZZLE_PROPERTY.HELP_DESCRIPTION] = self.helpDescription,
    [Puzzle.PUZZLE_PROPERTY.OLD_UUIDS] = self.oldUUIDs
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

  local winConditions = mode.matchRules.stackWinConditions
  local overConditions = mode.matchRules.stackOverConditions

  if self:hasGoal(Puzzle.GOAL_KINDS.clear) then
    overConditions[MatchRules.StackOverConditions.HEALTH] = 0
    winConditions[MatchRules.StackWinConditions.GARBAGE_BUFFER_EXCEEDED] = 0
    mode.matchRules.stackSetupModifications.stopTime = self.stopTime
    mode.matchRules.stackSetupModifications.shakeTime = self.shakeTime
  else
    mode.matchRules.stackSetupModifications.behaviours = {
      allowManualRaise = false,
      passiveRaise = false,
    }
  end

  if self:hasGoal(Puzzle.GOAL_KINDS.emptyBoard) or self:hasGoal(Puzzle.GOAL_KINDS.legacyChain) then
    winConditions[MatchRules.StackWinConditions.MATCHABLE_PANELS] = 0
  end
  if self:hasGoal(Puzzle.GOAL_KINDS.legacyChain) then
    overConditions[MatchRules.StackOverConditions.CHAIN] = false
  end

  winConditions[MatchRules.StackWinConditions.CHAINS] = self:goalCountsBySize(Puzzle.GOAL_KINDS.chain)
  winConditions[MatchRules.StackWinConditions.COMBOS] = self:goalCountsBySize(Puzzle.GOAL_KINDS.combo)
  if winConditions[MatchRules.StackWinConditions.CHAINS] or winConditions[MatchRules.StackWinConditions.COMBOS] then
    overConditions[MatchRules.StackOverConditions.GOALS_UNREACHABLE] = true
  elseif self:hasGoal(Puzzle.GOAL_KINDS.emptyBoard) and self.moves == 0 then
    -- with a swap limit the puzzle ends the way it always has, without one a stranded color is the only thing that can end it
    overConditions[MatchRules.StackOverConditions.GOALS_UNREACHABLE] = true
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
  local puzzle = Puzzle({
    goals = originalPuzzle.goals,
    stack = puzzleString,
    moves = originalPuzzle.moves,
    startTiming = originalPuzzle.startTiming,
    cursorStartLeft = originalPuzzle.cursorStartLeft,
    stopTime = originalPuzzle.stopTime,
    shakeTime = originalPuzzle.shakeTime,
    panelBuffer = originalPuzzle.panelBuffer,
    garbagePanelBuffer = originalPuzzle.garbageBuffer,
    solution = originalPuzzle.solution,
    helpDescription = originalPuzzle.helpDescription,
    oldUUIDs = originalPuzzle.oldUUIDs
  })
  -- the derived puzzle stands in for the original, so it is saved back to the entry that one came from
  puzzle.fileIndex = originalPuzzle.fileIndex

  return puzzle
end

return Puzzle