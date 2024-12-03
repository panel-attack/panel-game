-- defines the data representation of a player in replays
-- this is the interop format both server and client have to adhere to for using Replays
-- even if the client happens to match many or even all fields, please don't get rid of this and convert

local class = require("common.lib.class")
local utf8 = require("common.lib.utf8Additions")

local ReplayPlayer = class(function(self, name, publicId, human)
  self.name = name
  self.publicId = publicId
  self.human = human
  self.settings = {}
end)

ReplayPlayer.TYPE = "ReplayPlayer"

function ReplayPlayer:setWins(wins)
  self.wins = wins
end

function ReplayPlayer:setCharacterId(characterId)
  self.settings.characterId = characterId
end

function ReplayPlayer:setPanelId(panelId)
  self.settings.panelId = panelId
end

-- sets the levelData which is a LevelData object
function ReplayPlayer:setLevelData(levelData)
  if levelData.TYPE == "LevelData" then
    self.settings.levelData = levelData
  end
end

-- sets the inputMethod
-- valid inputMethods are "controller" and "touch"
function ReplayPlayer:setInputMethod(inputMethod)
  self.settings.inputMethod = inputMethod
end

-- modifies whether panels of the same color may spawn next to each other
-- this should be determined externally based on some rules
function ReplayPlayer:setAllowAdjacentColors(allowAdjacentColors)
  self.settings.allowAdjacentColors = allowAdjacentColors
end

function ReplayPlayer:setAttackEngineSettings(attackEngineSettings)
  self.settings.attackEngineSettings = attackEngineSettings
end

function ReplayPlayer:setHealthSettings(healthSettings)
  self.settings.healthSettings = healthSettings
end

-- sets the level for display, level = icon number
function ReplayPlayer:setLevel(level)
  self.settings.level = level
end

-- sets the difficulty for display
-- 1 Easy, 2 Normal, 3 Hard, 4 Ex
function ReplayPlayer:setDifficulty(difficulty)
  self.settings.difficulty = difficulty
end

function ReplayPlayer:setInputs(inputs)
  if type(inputs) == "table" then
    self.settings.inputs = table.concat(inputs)
  else
    self.settings.inputs = inputs
  end
end

function ReplayPlayer:validate()
  -- check for gameplay relevant settings
  if self.human == nil then
    return false
  end

  if self.human == true then
    if not self.settings.levelData then
      return false
    end

    if not self.settings.inputMethod or not (self.settings.inputMethod == "controller" or self.settings.inputMethod == "touch") then
      return false
    end

    if self.settings.allowAdjacentColors == nil then
      return false
    end
  else
    if not self.settings.attackEngineSettings or not self.settings.healthSettings then
      return false
    end
  end

  -- not super critical but the most defining of the optional settings that cannot be substituted by a client
  if not self.publicId then
    return false
  end

  -- everything else will "only" produce graphics crashes and could reasonably be substituted by a client
  return true
end

-- Returns if the unicode codepoint (representative number) is either the left or right parenthesis
local function codePointIsParenthesis(codePoint)
  if codePoint >= 40 and codePoint <= 41 then
    return true
  end
  return false
end

-- Returns if the unicode codepoint (representative number) is a digit from 0-9
local function codePointIsDigit(codePoint)
  if codePoint >= 48 and codePoint <= 57 then
    return true
  end
  return false
end

function ReplayPlayer.compressInputString(inputs)
  assert(inputs ~= nil, "string must be provided for compression")
  assert(type(inputs) == "string", "input to be compressed must be a string")
  if string.len(inputs) == 0 then
    return inputs
  end

  local compressedTable = {}
  local function addToTable(codePoint, repeatCount)
    local currentInput = utf8.char(codePoint)
    -- write the input
    if tonumber(currentInput) == nil then
      compressedTable[#compressedTable+1] = currentInput .. repeatCount
    else
      local completeInput = "(" .. currentInput
      for j = 2, repeatCount do
        completeInput = completeInput .. currentInput
      end
      compressedTable[#compressedTable+1] = completeInput .. ")"
    end
  end

  local previousCodePoint = nil
  local repeatCount = 1
  for p, codePoint in utf8.codes(inputs) do
    if codePointIsDigit(codePoint) and codePointIsParenthesis(previousCodePoint) == true then
      -- Detected a digit enclosed in parentheses in the inputs, the inputs are already compressed.
      return inputs
    end
    if p > 1 then
      if previousCodePoint ~= codePoint then
        addToTable(previousCodePoint, repeatCount)
        repeatCount = 1
      else
        repeatCount = repeatCount + 1
      end
    end
    previousCodePoint = codePoint
  end
  -- add the final entry without having to check for table length in every iteration
  addToTable(previousCodePoint, repeatCount)

  return table.concat(compressedTable)
end

function ReplayPlayer.decompressInputString(inputs)
  local previousCodePoint = nil
  local inputChunks = {}
  local numberString = nil
  local characterCodePoint = nil
  -- Go through the characters one by one, saving character and then the number sequence and after passing it writing out that many characters
  for p, codePoint in utf8.codes(inputs) do
    if p > 1 then
      if codePointIsDigit(codePoint) then
        local number = utf8.char(codePoint)
        if numberString == nil then
          characterCodePoint = previousCodePoint
          numberString = ""
        end
        numberString = numberString .. number
      else
        if numberString ~= nil then
          if codePointIsParenthesis(characterCodePoint) then
            inputChunks[#inputChunks+1] = numberString
          else
            local character = utf8.char(characterCodePoint)
            local repeatCount = tonumber(numberString)
            inputChunks[#inputChunks+1] = string.rep(character, repeatCount)
          end
          numberString = nil
        end
        if previousCodePoint == codePoint then
          -- Detected two consecutive letters or symbols in the inputs, the inputs are not compressed.
          return inputs
        else
          -- Nothing to do yet
        end
      end
    end
    previousCodePoint = codePoint
  end

  local result
  if numberString ~= nil then
    local character = utf8.char(characterCodePoint)
    local repeatCount = tonumber(numberString)
    inputChunks[#inputChunks+1] = string.rep(character, repeatCount)
    result = table.concat(inputChunks)
  else
    -- We never encountered a single number, this string wasn't compressed
    result = inputs
  end
  return result
end

return ReplayPlayer