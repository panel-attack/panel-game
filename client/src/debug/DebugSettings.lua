local logger = require("common.lib.logger")

-- Singleton class for managing runtime debug settings
-- Settings are persisted to the config file under config.debug
---@class DebugSettings
local DebugSettings = {}

---@class DebugConfig
---@field showStackDebugInfo boolean
---@field showUIElementBorders boolean
---@field simulateMobileOS boolean
---@field forceFPS boolean
---@field drawGraphicsStats boolean
---@field showRuntimeGraph boolean
---@field vsFramesBehind number
---@field showDebugServers boolean
---@field showDesignHelper boolean
---@field profileFrameTimes boolean
---@field profileThreshold number

---@class DebugSettingDefinition
---@field key string The key used in config.debug table
---@field type "boolean"|"number" The type of the setting
---@field default boolean|number The default value
---@field label string The display label for the UI
---@field min number? Minimum value for number types
---@field max number? Maximum value for number types
---@field debugBuildOnly boolean? Forces the setting off and hides it in non-debug builds

-- All debug settings defined in one place with their metadata
local settingDefinitions = {
  {
    key = "showStackDebugInfo",
    type = "boolean",
    default = false,
    label = "Show Stack Debug Info",
    debugBuildOnly = false
  },
  {
    key = "showUIElementBorders",
    type = "boolean",
    default = false,
    label = "Show UI Element Borders",
    debugBuildOnly = true
  },
  {
    key = "simulateMobileOS",
    type = "boolean",
    default = false,
    label = "Simulate Mobile OS",
    debugBuildOnly = true
  },
  {
    key = "forceFPS",
    type = "boolean",
    default = false,
    label = "Force FPS Display",
    debugBuildOnly = true
  },
  {
    key = "drawGraphicsStats",
    type = "boolean",
    default = false,
    label = "Draw Graphics Stats",
    debugBuildOnly = true
  },
  {
    key = "showRuntimeGraph",
    type = "boolean",
    default = false,
    label = "Show Runtime Graph",
    debugBuildOnly = true
  },
  {
    key = "vsFramesBehind",
    type = "number",
    default = 0,
    label = "VS Frames Behind",
    min = 0,
    max = 200,
    debugBuildOnly = true
  },
  {
    key = "showDebugServers",
    type = "boolean",
    default = false,
    label = "Show Debug Servers",
    debugBuildOnly = false
  },
  {
    key = "showDesignHelper",
    type = "boolean",
    default = false,
    label = "Show Design Helper",
    debugBuildOnly = true
  },
  {
    key = "profileFrameTimes",
    type = "boolean",
    default = false,
    label = "Profile frame times",
    debugBuildOnly = false
  },
  {
    key = "profileThreshold",
    type = "number",
    default = 50,
    label = "Discard frames below duration (ms)",
    min = 0,
    max = 100,
    debugBuildOnly = false
  }
}

local function isNonDebugBuild()
  return not DEBUG_ENABLED
end

local function shouldLockToDefault(def)
  return isNonDebugBuild() and def.debugBuildOnly
end

---Creates a DebugConfig table populated with default values.
---@return DebugConfig
local function createDefaultConfig()
  local defaults = {}
  for _, def in ipairs(settingDefinitions) do
    local value = def.default
    defaults[def.key] = value
  end
  ---@type DebugConfig
  return defaults
end

--- Current settings values (loaded from config.debug)
---@type DebugConfig
local settings = createDefaultConfig()

local function clampNumber(value, minValue, maxValue)
  if minValue then
    value = math.max(minValue, value)
  end
  if maxValue then
    value = math.min(maxValue, value)
  end
  return value
end

local function findDefinition(key)
  for _, def in ipairs(settingDefinitions) do
    if def.key == key then
      return def
    end
  end
end

---Returns default debug configuration values keyed by setting.
---@return DebugConfig
function DebugSettings.getDefaultConfigValues()
  return createDefaultConfig()
end

---Normalizes persisted debug configuration values using definitions.
---@param persisted table<string, any>|nil
---@return DebugConfig
function DebugSettings.normalizeConfigValues(persisted)
  local normalized = createDefaultConfig()
  local source = persisted or {}

  for _, def in ipairs(settingDefinitions) do
    local value = source[def.key]
    if def.type == "boolean" then
      if type(value) == "boolean" then
        normalized[def.key] = value
      end
    elseif def.type == "number" then
      if type(value) ~= "number" then
        value = def.default
      end
      normalized[def.key] = clampNumber(value, def.min, def.max)
    end
  end

  return normalized
end

-- Initializes debug settings from config
function DebugSettings.init()
  config.debug = config.debug or {}

  config.debug = DebugSettings.normalizeConfigValues(config.debug)

  for _, def in ipairs(settingDefinitions) do
    local value = config.debug[def.key]
    if shouldLockToDefault(def) then
      settings[def.key] = def.default
    else
      settings[def.key] = value
    end
  end
end

-- Saves current settings to config
local function saveSettings()
  config.debug = config.debug or {}

  for _, def in ipairs(settingDefinitions) do
    config.debug[def.key] = settings[def.key]
  end

  write_conf_file()
end

local releaseDefinitionCache
-- Returns all setting definitions for UI generation
---@return DebugSettingDefinition[]
function DebugSettings.getDefinitions()
  if not isNonDebugBuild() then
    return settingDefinitions
  end

  if not releaseDefinitionCache then
    releaseDefinitionCache = {}
    for _, def in ipairs(settingDefinitions) do
      if not def.debugBuildOnly then
        releaseDefinitionCache[#releaseDefinitionCache + 1] = def
      end
    end
  end

  return releaseDefinitionCache
end

-- Gets the value of a setting by key
---@param key string
---@return boolean|number
function DebugSettings.get(key)
  local def = findDefinition(key)

  if isNonDebugBuild() then
    if def then
      if shouldLockToDefault(def) then
        return def.default
      end

      if def.type == "boolean" then
        return settings[key] or false
      elseif def.type == "number" then
        return settings[key] or 0
      end
    end
    return false
  end

  if not def then
    return false
  end

  return settings[key]
end

-- Sets the value of a setting by key
---@param key string
---@param value boolean|number
function DebugSettings.set(key, value)
  local def = findDefinition(key)
  if not def then
    logger.warn("Attempted to set unknown debug setting: " .. key)
    return
  end

  if def.type == "boolean" then
    settings[key] = value and true or false
  else
    local numericValue = type(value) == "number" and value or def.default
    settings[key] = clampNumber(numericValue, def.min, def.max)
  end
  saveSettings()
end

-- Returns whether to show stack debug information
---@return boolean
function DebugSettings.showStackDebugInfo()
  return DebugSettings.get("showStackDebugInfo") --[[@as boolean]]
end

-- Returns whether to show UI element borders
---@return boolean
function DebugSettings.showUIElementBorders()
  return DebugSettings.get("showUIElementBorders") --[[@as boolean]]
end

-- Returns whether to simulate mobile OS on desktop
---@return boolean
function DebugSettings.simulateMobileOS()
  return DebugSettings.get("simulateMobileOS") --[[@as boolean]]
end

-- Returns whether to force FPS display in debug builds
---@return boolean
function DebugSettings.forceFPS()
  return DebugSettings.get("forceFPS") --[[@as boolean]]
end

-- Returns whether to draw graphics stats (draw calls, texture memory, etc.)
---@return boolean
function DebugSettings.drawGraphicsStats()
  return DebugSettings.get("drawGraphicsStats") --[[@as boolean]]
end

-- Returns whether to show the runtime graph
---@return boolean
function DebugSettings.showRuntimeGraph()
  return DebugSettings.get("showRuntimeGraph") --[[@as boolean]]
end

-- Returns the VS frames behind value (only applicable when showStackDebugInfo is true)
---@return number
function DebugSettings.getVSFramesBehind()
  return DebugSettings.get("vsFramesBehind") --[[@as number]]
end

-- Sets whether to show stack debug information
---@param value boolean
function DebugSettings.setShowStackDebugInfo(value)
  DebugSettings.set("showStackDebugInfo", value)
end

-- Sets whether to show UI element borders
---@param value boolean
function DebugSettings.setShowUIElementBorders(value)
  DebugSettings.set("showUIElementBorders", value)
end

-- Sets whether to simulate mobile OS on desktop
---@param value boolean
function DebugSettings.setSimulateMobileOS(value)
  DebugSettings.set("simulateMobileOS", value)
end

-- Sets whether to force FPS display in debug builds
---@param value boolean
function DebugSettings.setForceFPS(value)
  DebugSettings.set("forceFPS", value)
end

-- Sets whether to draw graphics stats
---@param value boolean
function DebugSettings.setDrawGraphicsStats(value)
  DebugSettings.set("drawGraphicsStats", value)
end

-- Sets whether to show the runtime graph
---@param value boolean
function DebugSettings.setShowRuntimeGraph(value)
  DebugSettings.set("showRuntimeGraph", value)
end

-- Sets the VS frames behind value
---@param value number
function DebugSettings.setVSFramesBehind(value)
  DebugSettings.set("vsFramesBehind", value)
end

-- Returns whether to show debug servers in main menu
---@return boolean
function DebugSettings.showDebugServers()
  return DebugSettings.get("showDebugServers") --[[@as boolean]]
end

-- Sets whether to show debug servers in main menu
---@param value boolean
function DebugSettings.setShowDebugServers(value)
  DebugSettings.set("showDebugServers", value)
end

-- Returns whether to show design helper in main menu
---@return boolean
function DebugSettings.showDesignHelper()
  return DebugSettings.get("showDesignHelper") --[[@as boolean]]
end

-- Sets whether to show design helper in main menu
---@param value boolean
function DebugSettings.setShowDesignHelper(value)
  DebugSettings.set("showDesignHelper", value)
end

-- Returns whether to profile frame times
---@return boolean
function DebugSettings.getProfileFrameTimes()
  return DebugSettings.get("profileFrameTimes") --[[@as boolean]]
end

-- Sets whether to profile frame times
---@param value boolean
function DebugSettings.setProfileFrameTimes(value)
  DebugSettings.set("profileFrameTimes", value)
  local prof = require("common.lib.zoneProfiler")
  prof.enable(value)
  prof.setDurationFilter(DebugSettings.getProfileThreshold() / 1000)
end

-- Returns the profile threshold in milliseconds
---@return number
function DebugSettings.getProfileThreshold()
  return DebugSettings.get("profileThreshold") --[[@as number]]
end

-- Sets the profile threshold in milliseconds
---@param value number
function DebugSettings.setProfileThreshold(value)
  DebugSettings.set("profileThreshold", value)
  local prof = require("common.lib.zoneProfiler")
  prof.setDurationFilter(value / 1000)
end

return DebugSettings
