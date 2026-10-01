local class = require("common.lib.class")
local FileUtils = require("client.src.FileUtils")
local Puzzle = require("common.engine.Puzzle")
local logger = require("common.lib.logger")

-- A puzzle set is a set of puzzles, typically they have a common difficulty or theme.
---@class PuzzleSet
---@field setName string
---@field description string
---@field localizedSetName string
---@field localizedDescription string
---@field puzzles Puzzle[]
---@field puzzleSets PuzzleSet[]
---@field fileSource string?
local PuzzleSet = class(
function(self, setName, description, puzzles, puzzleSets)
  self.setName = setName
  self.description = description or ""
  self.puzzles = puzzles or {}
  self.puzzleSets = puzzleSets or {}
  self.localizedSetName = loc(setName)
  self.localizedDescription = self.description ~= "" and loc(self.description) or ""
end)

-- Puzzle set properties
PuzzleSet.PUZZLE_SET_PROPERTY = {
  NAME = "Set Name",
  DESCRIPTION = "Description",
  PUZZLES = "Puzzles",
  PUZZLE_SETS = "Puzzle Sets"
}

PuzzleSet.ROOT_PROPERTY = {
  VERSION = "Version",
  PUZZLE_SETS = "Puzzle Sets"
}

PuzzleSet.CURRENT_VERSION = 3

local validPuzzleSetProperties = {}
for _, property in pairs(PuzzleSet.PUZZLE_SET_PROPERTY) do
  validPuzzleSetProperties[property] = true
end

function PuzzleSet.isValidPuzzleSetProperty(property)
  return validPuzzleSetProperties[property] == true
end

-- Walk down the hierarchy to find the first puzzle set with a fileSource
-- Returns the puzzle set with fileSource and the adjusted path
---@param rootPuzzleSet PuzzleSet The root puzzle set to start from
---@param indices integer[] Array of indices representing the path down the hierarchy
---@return PuzzleSet? puzzleSetWithFileSource The first puzzle set found with a fileSource
---@return integer[] adjustedPath The remaining path after the fileSource puzzle set
function PuzzleSet.findPuzzleSetWithFileSource(rootPuzzleSet, indices)
  local currentPuzzleSet = rootPuzzleSet
  local adjustedPath = {}
  
  for i, pathIndex in ipairs(indices) do
    if currentPuzzleSet.puzzleSets and currentPuzzleSet.puzzleSets[pathIndex] and currentPuzzleSet.puzzleSets[pathIndex].fileSource then
      -- Found a puzzle set with fileSource
      currentPuzzleSet = currentPuzzleSet.puzzleSets[pathIndex]
      -- Copy the remaining path after this point
      for j = i + 1, #indices do
        adjustedPath[#adjustedPath + 1] = indices[j]
      end
      return currentPuzzleSet, adjustedPath
    elseif currentPuzzleSet.puzzleSets and currentPuzzleSet.puzzleSets[pathIndex] then
      -- Continue walking down the hierarchy
      currentPuzzleSet = currentPuzzleSet.puzzleSets[pathIndex]
    else
      -- Path is invalid
      break
    end
  end
  
  -- If we get here, no fileSource was found in the path, return the root
  return rootPuzzleSet, indices
end

-- Helper functions for consistent key ordering
---@return string[]
function PuzzleSet.getPuzzleSetKeyOrder()
  return {
    PuzzleSet.PUZZLE_SET_PROPERTY.NAME,
    PuzzleSet.PUZZLE_SET_PROPERTY.DESCRIPTION,
    PuzzleSet.PUZZLE_SET_PROPERTY.PUZZLES,
    PuzzleSet.PUZZLE_SET_PROPERTY.PUZZLE_SETS
  }
end

---@return string[]
function PuzzleSet.getRootKeyOrder()
  return {
    PuzzleSet.ROOT_PROPERTY.VERSION,
    PuzzleSet.ROOT_PROPERTY.PUZZLE_SETS
  }
end

PuzzleSet.keyOrder = {
  PuzzleSet.ROOT_PROPERTY.VERSION,
  
  PuzzleSet.PUZZLE_SET_PROPERTY.NAME,
  PuzzleSet.PUZZLE_SET_PROPERTY.DESCRIPTION,
  PuzzleSet.PUZZLE_SET_PROPERTY.PUZZLES,
  PuzzleSet.PUZZLE_SET_PROPERTY.PUZZLE_SETS,
  
  Puzzle.PUZZLE_PROPERTY.TYPE,
  Puzzle.PUZZLE_PROPERTY.START_TIMING,
  Puzzle.PUZZLE_PROPERTY.MOVES,
  Puzzle.PUZZLE_PROPERTY.STOP,
  Puzzle.PUZZLE_PROPERTY.SHAKE,
  Puzzle.PUZZLE_PROPERTY.STACK,
  Puzzle.PUZZLE_PROPERTY.PANEL_BUFFER,
  Puzzle.PUZZLE_PROPERTY.GARBAGE_PANEL_BUFFER,
  Puzzle.PUZZLE_PROPERTY.CURSOR_START_LEFT,
  
  Puzzle.CURSOR_PROPERTY.COLUMN,
  Puzzle.CURSOR_PROPERTY.ROW
}

---@param filePath string
---@return PuzzleSet[]
function PuzzleSet.loadFromFile(filePath)
  local data = FileUtils.readJsonFile(filePath)
  local puzzleSets = {}

  if data then
    if data[PuzzleSet.ROOT_PROPERTY.VERSION] == PuzzleSet.CURRENT_VERSION then
      for _, puzzleSetData in pairs(data[PuzzleSet.ROOT_PROPERTY.PUZZLE_SETS]) do
        local loadedSet = PuzzleSet.loadV3(puzzleSetData)
        if loadedSet then
          puzzleSets[#puzzleSets + 1] = loadedSet
        end
      end
    elseif data[PuzzleSet.ROOT_PROPERTY.VERSION] == 2 then
      for _, puzzleSetData in pairs(data[PuzzleSet.ROOT_PROPERTY.PUZZLE_SETS]) do
        puzzleSets[#puzzleSets + 1] = PuzzleSet.loadV2(puzzleSetData)
      end
    elseif data[PuzzleSet.ROOT_PROPERTY.VERSION] and type(data[PuzzleSet.ROOT_PROPERTY.VERSION]) == "number" then
      logger.warn("Puzzle " .. filePath .. " specifies invalid version " .. data[PuzzleSet.ROOT_PROPERTY.VERSION])
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
        puzzleType = Puzzle.PUZZLE_TYPES.moves,
        startTiming = Puzzle.START_TIMINGS.countdown,
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
  local puzzleSetName = puzzleSetData[PuzzleSet.PUZZLE_SET_PROPERTY.NAME]
  local puzzles = {}
  for fileIndex, puzzleData in ipairs(puzzleSetData[PuzzleSet.PUZZLE_SET_PROPERTY.PUZZLES]) do
    local args = {
      puzzleType = puzzleData[Puzzle.PUZZLE_PROPERTY.TYPE],
      startTiming = puzzleData["Do Countdown"] and Puzzle.START_TIMINGS.countdown or Puzzle.START_TIMINGS.immediately,
      moves = puzzleData[Puzzle.PUZZLE_PROPERTY.MOVES],
      stack = puzzleData[Puzzle.PUZZLE_PROPERTY.STACK],
      stopTime = puzzleData[Puzzle.PUZZLE_PROPERTY.STOP],
      shakeTime = puzzleData[Puzzle.PUZZLE_PROPERTY.SHAKE]
    }
    local puzzle = Puzzle(args)
    puzzle.fileIndex = fileIndex
    if PuzzleSet.validatePuzzleForSet(puzzle, puzzleSetName, fileIndex) then
      puzzles[#puzzles + 1] = puzzle
    end
  end

  return PuzzleSet(puzzleSetName, nil, puzzles)
end

-- Says why a puzzle in a file is not being loaded, naming the entry to go and fix
---@param puzzleSetName string
---@param fileIndex integer where the puzzle sits in the file
---@param reason string
local function warnPuzzleHidden(puzzleSetName, fileIndex, reason)
  logger.warn("Hiding puzzle " .. fileIndex .. " of set " .. tostring(puzzleSetName) .. " because " .. reason)
end

-- the properties a puzzle cannot be built without; the loader works on their text right away, so an
-- entry missing one has to be hidden before it is read rather than after
local requiredPuzzleProperties = {Puzzle.PUZZLE_PROPERTY.TYPE, Puzzle.PUZZLE_PROPERTY.STACK}

-- Checks that an entry says enough to build a puzzle from, warning about and hiding one that does not
---@param puzzleData table
---@param puzzleSetName string
---@param fileIndex integer where the puzzle sits in the file
---@return boolean readable
local function puzzleEntryIsReadable(puzzleData, puzzleSetName, fileIndex)
  for _, property in ipairs(requiredPuzzleProperties) do
    if type(puzzleData[property]) ~= "string" then
      warnPuzzleHidden(puzzleSetName, fileIndex, "it has no " .. property)
      return false
    end
  end

  return true
end

-- Validates a puzzle read from a file, warning about and hiding one that fails so the rest of the set still loads
---@param puzzle Puzzle
---@param puzzleSetName string
---@param fileIndex integer where the puzzle sits in the file, so the warning names the entry to go and fix
---@return boolean valid
function PuzzleSet.validatePuzzleForSet(puzzle, puzzleSetName, fileIndex)
  local valid, problems = puzzle:validate()
  if not valid then
    warnPuzzleHidden(puzzleSetName, fileIndex, "it is invalid:" .. problems)
  end
  return valid
end

---@param puzzleSetData table
---@return boolean
function PuzzleSet.validateV3Properties(puzzleSetData)
  -- Validate puzzle set properties
  for key, _ in pairs(puzzleSetData) do
    if not PuzzleSet.isValidPuzzleSetProperty(key) then
      logger.warn("Unsupported puzzle set property found: " .. tostring(key))
      return false
    end
  end
  
  -- Validate puzzle properties
  for _, puzzleData in pairs(puzzleSetData[PuzzleSet.PUZZLE_SET_PROPERTY.PUZZLES] or {}) do
    for key, _ in pairs(puzzleData) do
      if not Puzzle.isValidPuzzleProperty(key) then
        logger.warn("Unsupported puzzle property found: " .. tostring(key))
        return false
      end
    end
    
    -- Validate cursor properties if present
    if puzzleData[Puzzle.PUZZLE_PROPERTY.CURSOR_START_LEFT] then
      for key, _ in pairs(puzzleData[Puzzle.PUZZLE_PROPERTY.CURSOR_START_LEFT]) do
        if not Puzzle.isValidCursorProperty(key) then
          logger.warn("Unsupported cursor property found: " .. tostring(key))
          return false
        end
      end
    end
  end
  
  -- Recursively validate nested puzzle sets
  for _, nestedPuzzleSetData in pairs(puzzleSetData[PuzzleSet.PUZZLE_SET_PROPERTY.PUZZLE_SETS] or {}) do
    if not PuzzleSet.validateV3Properties(nestedPuzzleSetData) then
      return false
    end
  end
  
  return true
end

-- Reads one puzzle entry of a version 3 file, warning about and skipping one the game cannot load so
-- that the rest of the set still comes in
---@param puzzleData table
---@param puzzleSetName string
---@param fileIndex integer which entry of the set in the file this is, so a warning names the one to go and fix
---@return Puzzle? puzzle nil for an entry that was hidden
function PuzzleSet.readV3Puzzle(puzzleData, puzzleSetName, fileIndex)
  if not puzzleEntryIsReadable(puzzleData, puzzleSetName, fileIndex) then
    return nil
  end

  ---@type string
  local puzzleTypeValue = puzzleData[Puzzle.PUZZLE_PROPERTY.TYPE]
  local args = {
    puzzleType = string.lower(puzzleTypeValue),
    moves = puzzleData[Puzzle.PUZZLE_PROPERTY.MOVES],
    stack = puzzleData[Puzzle.PUZZLE_PROPERTY.STACK],
    stopTime = puzzleData[Puzzle.PUZZLE_PROPERTY.STOP],
    shakeTime = puzzleData[Puzzle.PUZZLE_PROPERTY.SHAKE],
    panelBuffer = puzzleData[Puzzle.PUZZLE_PROPERTY.PANEL_BUFFER],
    garbagePanelBuffer = puzzleData[Puzzle.PUZZLE_PROPERTY.GARBAGE_PANEL_BUFFER],
    solution = puzzleData[Puzzle.PUZZLE_PROPERTY.SOLUTION],
    helpDescription = puzzleData[Puzzle.PUZZLE_PROPERTY.HELP_DESCRIPTION]
  }
  if puzzleData[Puzzle.PUZZLE_PROPERTY.CURSOR_START_LEFT] then
    args.cursorStartLeft = {row = puzzleData[Puzzle.PUZZLE_PROPERTY.CURSOR_START_LEFT].Row, column = puzzleData[Puzzle.PUZZLE_PROPERTY.CURSOR_START_LEFT].Column}
  end

  -- an absent timing is nil, which leaves the puzzle to its default; one that is there but unreadable is
  -- the file asking for something the game does not have, and defaulting it would play the wrong puzzle
  local fileStartTiming = puzzleData[Puzzle.PUZZLE_PROPERTY.START_TIMING]
  args.startTiming = Puzzle.startTimingFromFile(fileStartTiming)
  if fileStartTiming ~= nil and args.startTiming == nil then
    warnPuzzleHidden(puzzleSetName, fileIndex,
      "StartTiming '" .. tostring(fileStartTiming) .. "' is not one of " .. Puzzle.startTimingSpellings())
    return nil
  end

  local puzzle = Puzzle(args)
  puzzle.fileIndex = fileIndex
  if not PuzzleSet.validatePuzzleForSet(puzzle, puzzleSetName, fileIndex) then
    return nil
  end

  return puzzle
end

-- Reads a version 3 set
---@param puzzleSetData table
---@return PuzzleSet?
function PuzzleSet.loadV3(puzzleSetData)
  if not PuzzleSet.validateV3Properties(puzzleSetData) then
    return nil
  end

  local puzzleSetName = puzzleSetData[PuzzleSet.PUZZLE_SET_PROPERTY.NAME]
  local puzzleSetDescription = puzzleSetData[PuzzleSet.PUZZLE_SET_PROPERTY.DESCRIPTION] or nil
  local puzzleSet = PuzzleSet(puzzleSetName, puzzleSetDescription, {}, {})

  for fileIndex, puzzleData in ipairs(puzzleSetData[PuzzleSet.PUZZLE_SET_PROPERTY.PUZZLES] or {}) do
    local puzzle = PuzzleSet.readV3Puzzle(puzzleData, puzzleSetName, fileIndex)
    if puzzle then
      puzzleSet.puzzles[#puzzleSet.puzzles + 1] = puzzle
    end
  end
  for _, currentPuzzleSet in pairs(puzzleSetData[PuzzleSet.PUZZLE_SET_PROPERTY.PUZZLE_SETS] or {}) do
    local loadedSet = PuzzleSet.loadV3(currentPuzzleSet)
    if loadedSet then
      puzzleSet.puzzleSets[#puzzleSet.puzzleSets + 1] = loadedSet
    end
  end

  return puzzleSet
end

-- Get a puzzle by index
---@param index integer
---@return Puzzle
-- Returns the puzzle at the given index with bounds checking
function PuzzleSet:getPuzzle(index)
  if not index or type(index) ~= "number" or index < 1 or index > #self.puzzles then
    error("Invalid puzzle index: " .. tostring(index) .. ". Must be between 1 and " .. #self.puzzles)
  end
  return self.puzzles[index]
end

-- Navigates down the hierarchy to find a nested puzzle set using an array of indices
function PuzzleSet:getPuzzleSetFromIndices(puzzleSetIndices)  
  local puzzleSet = self

  -- Navigate through puzzle set hierarchy
  for i = 1, #puzzleSetIndices do
    local index = puzzleSetIndices[i]
    if puzzleSet.puzzleSets and puzzleSet.puzzleSets[index] then
      puzzleSet = puzzleSet.puzzleSets[index]
    else
      return nil -- Invalid path
    end
  end
  
  return puzzleSet
end

-- Gets a specific puzzle by navigating to a nested puzzle set and then selecting the puzzle index
function PuzzleSet:getPuzzleFromIndices(puzzleSetIndices, puzzleIndex)
  local puzzleSet = self:getPuzzleSetFromIndices(puzzleSetIndices)
  
  -- Get the final puzzle
  if puzzleSet and puzzleSet.puzzles and puzzleSet.puzzles[puzzleIndex] then
    return puzzleSet.puzzles[puzzleIndex]
  end
  
  return nil
end

-- Check if all puzzles in this set have been completed
-- This includes both direct puzzles and all puzzles in nested puzzle sets
---@return boolean
function PuzzleSet:isCompleted()
  -- A puzzle set is considered completed if it has content and all content is completed
  local hasContent = false
  
  -- Check all direct puzzles in this set
  if self.puzzles and #self.puzzles > 0 then
    hasContent = true
    for _, puzzle in ipairs(self.puzzles) do
      if not puzzle.puzzleEverBeaten then
        return false
      end
    end
  end
  
  -- Check all nested puzzle sets recursively
  if self.puzzleSets and #self.puzzleSets > 0 then
    hasContent = true
    for _, nestedPuzzleSet in ipairs(self.puzzleSets) do
      if not nestedPuzzleSet:isCompleted() then
        return false
      end
    end
  end
  
  -- Return true only if the set has content and all of it is completed
  return hasContent
end

-- Check if this puzzle set has some but not all puzzles completed
-- This includes both direct puzzles and all puzzles in nested puzzle sets
---@return boolean
function PuzzleSet:isPartiallyCompleted()
  -- If fully completed, it's not partially completed
  if self:isCompleted() then
    return false
  end
  
  local hasContent = false
  local hasCompletedContent = false
  
  -- Check all direct puzzles in this set
  if self.puzzles and #self.puzzles > 0 then
    hasContent = true
    for _, puzzle in ipairs(self.puzzles) do
      if puzzle.puzzleEverBeaten then
        hasCompletedContent = true
        break
      end
    end
  end
  
  -- Check all nested puzzle sets recursively
  if self.puzzleSets and #self.puzzleSets > 0 then
    hasContent = true
    for _, nestedPuzzleSet in ipairs(self.puzzleSets) do
      if nestedPuzzleSet:isCompleted() or nestedPuzzleSet:isPartiallyCompleted() then
        hasCompletedContent = true
        break
      end
    end
  end
  
  -- Return true if the set has content and some (but not all) of it is completed
  return hasContent and hasCompletedContent
end

-- Update a puzzle at the specified index
---@param index integer
---@param newPuzzle Puzzle
function PuzzleSet:updatePuzzle(index, newPuzzle)
  if not index or type(index) ~= "number" or index < 1 or index > #self.puzzles then
    error("Invalid puzzle index: " .. tostring(index) .. ". Must be between 1 and " .. #self.puzzles)
  end
  if not newPuzzle then
    error("Cannot update puzzle: newPuzzle cannot be nil")
  end
  self.puzzles[index] = newPuzzle
end

local function puzzleSetToSaveData(puzzleSet)
  local puzzleSetData = {
    [PuzzleSet.PUZZLE_SET_PROPERTY.NAME] = puzzleSet.setName,
    [PuzzleSet.PUZZLE_SET_PROPERTY.DESCRIPTION] = puzzleSet.description,
    [PuzzleSet.PUZZLE_SET_PROPERTY.PUZZLES] = {}
  }
  
  -- Convert puzzles to save format
  for i, puzzle in ipairs(puzzleSet.puzzles) do
    puzzleSetData[PuzzleSet.PUZZLE_SET_PROPERTY.PUZZLES][i] = puzzle:getSaveData()
  end
  
  -- Recursively handle nested puzzle sets
  if puzzleSet.puzzleSets and #puzzleSet.puzzleSets > 0 then
    puzzleSetData[PuzzleSet.PUZZLE_SET_PROPERTY.PUZZLE_SETS] = {}
    for i, nestedPuzzleSet in ipairs(puzzleSet.puzzleSets) do
      puzzleSetData[PuzzleSet.PUZZLE_SET_PROPERTY.PUZZLE_SETS][i] = puzzleSetToSaveData(nestedPuzzleSet)
    end
  end
  
  return puzzleSetData
end

-- Generate JSON data structure
---@return table
function PuzzleSet:generateSaveData()
  if not self.setName or self.setName == "" then
    error("Cannot generate save data: setName is required")
  end
  
  local data = {
    [PuzzleSet.ROOT_PROPERTY.VERSION] = PuzzleSet.CURRENT_VERSION,
    [PuzzleSet.ROOT_PROPERTY.PUZZLE_SETS] = {
      puzzleSetToSaveData(self)
    }
  }
  
  return data
end

-- Save only this specific puzzle within its source file, preserving other puzzles and puzzle sets in the same file
---@param targetPuzzleSet PuzzleSet The puzzle set containing the target puzzle
---@param puzzleIndex integer The index of the puzzle to update within the target puzzle set
---@param updatedPuzzle Puzzle The updated puzzle to save
function PuzzleSet:saveTargetPuzzleToFile(targetPuzzleSet, puzzleIndex, updatedPuzzle)
  if not self.fileSource then
    error("Cannot save puzzle set: no file source specified")
  end
  if not targetPuzzleSet then
    error("Cannot save puzzle: targetPuzzleSet cannot be nil")
  end
  if not puzzleIndex or type(puzzleIndex) ~= "number" or puzzleIndex < 1 then
    error("Cannot save puzzle: puzzleIndex must be a positive number")
  end
  if not updatedPuzzle then
    error("Cannot save puzzle: updatedPuzzle cannot be nil")
  end
  
  -- Load the original JSON file data
  local originalData = FileUtils.readJsonFile(self.fileSource)
  if not originalData then
    error("Cannot load original file data from: " .. self.fileSource)
  end
  
  -- Find and update the specific puzzle within the JSON data structure
  local updated = self:updatePuzzleInFileData(originalData, targetPuzzleSet, puzzleIndex, updatedPuzzle)
  if not updated then
    logger.warn("Cannot save solution to old puzzle format, please upgrade your puzzles to the latest file format")
    return -- Early return, this is likely an old puzzle format.
  end

  -- Extract directory and filename from fileSource path
  local directory, filename = self.fileSource:match("^(.+)/([^/]+)$")
  if not directory or not filename then
    -- Handle case where fileSource is just a filename
    directory = ""
    filename = self.fileSource
  end

  -- Write the modified data back to file
  local encodeArgs = {
    indent = true,
    pretty = true,
    keyorder = PuzzleSet.keyOrder
  }
  FileUtils.writeJson(directory, filename, originalData, encodeArgs)
end


-- Helper method to find and update a specific puzzle within the JSON file data
---@param fileData table The JSON data structure from the file
---@param targetPuzzleSet PuzzleSet The puzzle set containing the target puzzle
---@param puzzleIndex integer The index of the puzzle to update within the target puzzle set
---@param updatedPuzzle Puzzle The updated puzzle data
---@return boolean success Whether the puzzle set was found and puzzle was updated
function PuzzleSet:updatePuzzleInFileData(fileData, targetPuzzleSet, puzzleIndex, updatedPuzzle)
  if not fileData[PuzzleSet.ROOT_PROPERTY.PUZZLE_SETS] then
    return false
  end
  
  -- Convert target puzzle to save data format
  local puzzleData = updatedPuzzle:getSaveData()

  -- a puzzle the loader hid is still in the file, so the entry to write is the one the puzzle was
  -- read from rather than its position in the set
  local fileIndex = updatedPuzzle.fileIndex or puzzleIndex

  -- Recursively search and update in the file data
  return self:updatePuzzleInDataArray(fileData[PuzzleSet.ROOT_PROPERTY.PUZZLE_SETS], targetPuzzleSet, fileIndex, puzzleData)
end

-- Helper to recursively search for a puzzle set and update a specific puzzle within it
---@param puzzleSetsArray table Array of puzzle set data
---@param targetPuzzleSet PuzzleSet The puzzle set containing the target puzzle
---@param puzzleIndex integer The index of the puzzle to update within the target puzzle set
---@param puzzleData table The puzzle data to replace
---@return boolean success Whether the puzzle set was found and puzzle was updated
function PuzzleSet:updatePuzzleInDataArray(puzzleSetsArray, targetPuzzleSet, puzzleIndex, puzzleData)
  for i, puzzleSetData in ipairs(puzzleSetsArray) do
    if puzzleSetData[PuzzleSet.PUZZLE_SET_PROPERTY.NAME] == targetPuzzleSet.setName then
      -- Found the target puzzle set - update the specific puzzle
      if puzzleSetData[PuzzleSet.PUZZLE_SET_PROPERTY.PUZZLES] and puzzleSetData[PuzzleSet.PUZZLE_SET_PROPERTY.PUZZLES][puzzleIndex] then
        puzzleSetData[PuzzleSet.PUZZLE_SET_PROPERTY.PUZZLES][puzzleIndex] = puzzleData
        return true
      else
        -- Puzzle index out of range
        return false
      end
    end
    
    -- Check nested puzzle sets
    if puzzleSetData[PuzzleSet.PUZZLE_SET_PROPERTY.PUZZLE_SETS] then
      if self:updatePuzzleInDataArray(puzzleSetData[PuzzleSet.PUZZLE_SET_PROPERTY.PUZZLE_SETS], targetPuzzleSet, puzzleIndex, puzzleData) then
        return true
      end
    end
  end
  
  return false
end

return PuzzleSet