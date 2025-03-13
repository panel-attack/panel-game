-- defines the data representation of a player in replays
-- this is the interop format both server and client have to adhere to for using Replays
-- even if the client happens to match many or even all fields, please don't get rid of this and convert

local class = require("common.lib.class")

---@class ReplayV2Player
---@field name string The name of the player
---@field publicId number The publicId of the player; negative numbers indicate unknown or anonymous
---@field human boolean Whether the player is/was human
---@field wins number How many wins the player had in the set prior to the game
---@field settings ReplayV2PlayerSettings
---@field analytics table?

---@class ReplayV2PlayerSettings Specifies settings of the player that change between replays
---@field characterId string?
---@field panelId string?
---@field levelData LevelData?
---@field inputMethod string?
---@field inputs string?
---@field allowAdjacentColors boolean?
---@field level (number | nil)
---@field difficulty (number | nil)
---@field attackEngineSettings table?
---@field healthSettings table?
---@field stackBehaviours StackBehaviours?

---@class ReplayV2Player
---@overload fun(name: string, publicId: number, human: boolean?): ReplayV2Player
local ReplayV2Player = class(
function(self, name, publicId, human)
  self.name = name
  self.publicId = publicId
  self.human = human
  self.settings = {}
end)

ReplayV2Player.TYPE = "ReplayPlayer"

function ReplayV2Player:setWins(wins)
  self.wins = wins
end

function ReplayV2Player:setCharacterId(characterId)
  self.settings.characterId = characterId
end

function ReplayV2Player:setPanelId(panelId)
  self.settings.panelId = panelId
end

---@param levelData LevelData
function ReplayV2Player:setLevelData(levelData)
  if levelData and levelData.TYPE == "LevelData" then
    ---@type LevelData
    self.settings.levelData = levelData
  end
end

-- sets the inputMethod
-- valid inputMethods are "controller" and "touch"
function ReplayV2Player:setInputMethod(inputMethod)
  self.settings.inputMethod = inputMethod
end

-- modifies whether panels of the same color may spawn next to each other
-- this should be determined externally based on some rules
function ReplayV2Player:setAllowAdjacentColors(allowAdjacentColors)
  self.settings.stackBehaviours.allowAdjacentColors = allowAdjacentColors
end

---@param behaviours StackBehaviours
function ReplayV2Player:setBehaviours(behaviours)
  self.settings.stackBehaviours = behaviours
end

function ReplayV2Player:setAttackEngineSettings(attackEngineSettings)
  self.settings.attackEngineSettings = attackEngineSettings
end

function ReplayV2Player:setHealthSettings(healthSettings)
  self.settings.healthSettings = healthSettings
end

-- sets the level for display, level = icon number
function ReplayV2Player:setLevel(level)
  self.settings.level = level
end

-- sets the difficulty for display
-- 1 Easy, 2 Normal, 3 Hard, 4 Ex
function ReplayV2Player:setDifficulty(difficulty)
  self.settings.difficulty = difficulty
end

function ReplayV2Player:setInputs(inputs)
  if type(inputs) == "table" then
    self.settings.inputs = table.concat(inputs)
  else
    self.settings.inputs = inputs
  end
end

function ReplayV2Player:validate()
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

return ReplayV2Player