local FileUtils = require("client.src.FileUtils")
local tableUtils = require("common.lib.tableUtils")
local joystickManager = require("common.lib.joystickManager")
local consts = require("common.engine.consts")
local logger = require("common.lib.logger")
local InputConfiguration = require("client.src.input.InputConfiguration")
local Signal = require("common.lib.signal")
require("client.src.input.JoystickProvider")

-- table containing the set of keys in various states 
-- base structure: 
--   isDown: table of {key: true} pairs if the key was pressed in the current frame 
--   isUp: table of {key: true} pairs if the key was released in the current frame 
--   isPressed: table of {key: time} pairs if the key is currently being held down where total duration held down is stored as time
--   Caveats:
--     isUp/isDown is set to one of the KEY_CHANGE enum values, see that definition for details
-- Key groups: 
--   allKeys: every key read in by LOVE (includes keyboard, controller, and joystick) 
--   inputConfigurations: raw key inputs mapped to internal aliases for that configuration
--   base (top level): the union of all inputConfigurations not already claimed by a player
--   mouse: all mouse buttons and the position of the mouse
---@class InputManager
local inputManager = {
  isDown = {},
  isPressed = {},
  isUp = {},
  allKeys = {isDown = {}, isPressed = {}, isUp = {}},
  mouse = {isDown = {}, isPressed = {}, isUp = {}, x = 0, y = 0},
  ---@type InputConfiguration[]
  inputConfigurations = {},
  maxConfigurations = 8,
  hasUnsavedChanges = false,
  unconfiguredJoysticksCache = nil
}

-- Represents the state of love.run while the key in isDown/isUp is active
-- DETECTED: set when the key state is first changed within the event handler
-- APPLIED: set in update immediately after the key state was just DETECTED 
-- This is only used within this file, external users should simply treat isDown/isUp as a boolean
local KEY_CHANGE = {NONE = nil, DETECTED = 1, APPLIED = 2}

local currentDt

-- map of menu key names (used in inputManager.isDown/Up/Pressed & isPressedWithRepeat)
-- and a tuple of {list of reserved keys, configured game key}
local menuReservedKeysMap = {
  MenuUp = {{"up"}, {"Up"}},
  MenuDown = {{"down"}, {"Down"}},
  MenuLeft = {{"left"}, {"Left"}},
  MenuRight = {{"right"}, {"Right"}},
  MenuEsc = {{"escape", "x"}, {"Swap2"}},
  MenuNextPage = {{"pageup"}, {"Raise1"}},
  MenuPrevPage = {{"pagedown"}, {"Raise2"}},
  MenuBack = {{"backspace"}, {}},
  MenuSelect = {{"return", "kpenter", "z"}, {"Swap1", "Start"}},
  FrameAdvance = {{"\\"}, {"TauntUp"}}
}

-- useful alternate representations of the above information
local menuKeyNames = {}
local menuReservedKeys = {}
local keyNameToMenuKeys = {}

for menuKeyName, keys in pairs(menuReservedKeysMap) do
  menuKeyNames[#menuKeyNames + 1] = menuKeyName
  for _, key in ipairs(keys[1]) do
    menuReservedKeys[key] = true
  end
end

for menuKeyName, keyNames in pairs(menuReservedKeysMap) do
  for i, keyName in ipairs(keyNames[2]) do
    keyNameToMenuKeys[keyName] = menuKeyName
  end
end

function inputManager:keyPressed(key, scancode, isrepeat)
  self.allKeys.isDown[key] = KEY_CHANGE.DETECTED
end

function inputManager:keyReleased(key, scancode)
  self.allKeys.isUp[key] = KEY_CHANGE.DETECTED
end

---@param joystick love.Joystick
---@return boolean? isNotConfigured
function inputManager:onJoystickAdded(joystick)
  joystickManager:registerJoystick(joystick)
  self:updateUnconfiguredJoysticksCache()
  local unconfiguredJoysticks = self:getUnconfiguredJoysticks()

  -- Check if the newly added joystick is unconfigured
  for _, unconfiguredJoystick in ipairs(unconfiguredJoysticks) do
    if unconfiguredJoystick == joystick then
      self:emitSignal("unconfiguredJoystickAdded", joystick)
      return true
    end
  end
end

function inputManager:onJoystickRemoved(joystick)
  joystickManager:unregisterJoystick(joystick)
  self:updateUnconfiguredJoysticksCache()
end

function inputManager:joystickPressed(joystick, button)
  if not joystickManager:isRegistered(joystick) then
    -- always check and register to be sure, in rare cases joystickadded is not called or not called early enough
    joystickManager:registerJoystick(joystick)
  end

  local key = joystickManager:getJoystickButtonName(joystick, button)
  self.allKeys.isDown[key] = KEY_CHANGE.DETECTED
end

function inputManager:joystickReleased(joystick, button)
  if not joystickManager:isRegistered(joystick) then
    -- always check and register to be sure, in rare cases joystickadded is not called or not called early enough
    joystickManager:registerJoystick(joystick)
  end

  local key = joystickManager:getJoystickButtonName(joystick, button)
  self.allKeys.isUp[key] = KEY_CHANGE.DETECTED
end

function inputManager:joystickaxis(joystick, axisIndex, value)
  local device = joystickManager.devices[joystick:getID()]
  if not device.defaultAxisPositions[axisIndex] then
    logger.info("Detected input from previously unrecorded axis " .. axisIndex .. " for stick with guid " .. joystick:getGUID())
    return
  end

  local stickIndex = math.floor((1 + axisIndex) / 2)
  local direction

  if axisIndex % 2 == 0 then
    direction = "y"
  else
    direction = "x"
  end

  direction = direction .. stickIndex

  local positiveKeybind = joystickManager:getJoystickButtonName(joystick, "+" .. direction)
  local negativeKeybind = joystickManager:getJoystickButtonName(joystick, "-" .. direction)

  local correctedValue = value - device.defaultAxisPositions[axisIndex]

  if correctedValue > 0.5 then
    if not self.allKeys.isDown[positiveKeybind] and not self.allKeys.isPressed[positiveKeybind] then
      self.allKeys.isDown[positiveKeybind] = KEY_CHANGE.DETECTED
    end
  else
    if self.allKeys.isDown[positiveKeybind] or self.allKeys.isPressed[positiveKeybind] then
      self.allKeys.isUp[positiveKeybind] = KEY_CHANGE.DETECTED
    end
  end

  if correctedValue < -0.5 then
    if not self.allKeys.isDown[negativeKeybind] and not self.allKeys.isPressed[negativeKeybind] then
      self.allKeys.isDown[negativeKeybind] = KEY_CHANGE.DETECTED
    end
  else
    if self.allKeys.isDown[negativeKeybind] or self.allKeys.isPressed[negativeKeybind] then
      self.allKeys.isUp[negativeKeybind] = KEY_CHANGE.DETECTED
    end
  end
end

-- maps joysticks' analog sticks state to the appropriate input maps
-- function inputManager:joystickToButtons()
--   for _, joystick in ipairs(love.joystick.getJoysticks()) do
--     for axisIndex = 1, joystick:getAxisCount() / 2 do
--       local dpadState = joystickManager:joystickToDPad(joystick, axisIndex * 2 - 1, axisIndex * 2)
--       for key, isPressed in pairs(dpadState) do
--         if isPressed then
--           if not self.allKeys.isDown[key] and not self.allKeys.isPressed[key] then
--             self.allKeys.isDown[key] = KEY_CHANGE.DETECTED
--           end
--         else
--           if self.allKeys.isDown[key] or self.allKeys.isPressed[key] then
--             self.allKeys.isUp[key] = KEY_CHANGE.DETECTED
--           end
--         end
--       end
--     end
--   end
-- end

-- maps joysticks' dpad to the appropriate input maps
function inputManager:dPadToButtons()
  for _, joystick in ipairs(love.joystick.getJoysticks()) do
    for hatIndex = 1, joystick:getHatCount() do
      local dpadState = joystickManager:getDPadState(joystick, hatIndex)
      for key, isPressed in pairs(dpadState) do
        if isPressed then
          if not self.allKeys.isDown[key] and not self.allKeys.isPressed[key] then
            self.allKeys.isDown[key] = KEY_CHANGE.DETECTED
          end
        else
          if self.allKeys.isDown[key] or self.allKeys.isPressed[key] then
            self.allKeys.isUp[key] = KEY_CHANGE.DETECTED
          end
        end
      end
    end
  end
end

function inputManager:updateKeyStates(dt, keys)
  currentDt = dt
  for key, _ in pairs(keys.isDown) do
    if keys.isDown[key] == KEY_CHANGE.DETECTED then
      keys.isDown[key] = KEY_CHANGE.APPLIED
    else
      keys.isDown[key] = KEY_CHANGE.NONE
      -- if the key got released on the same frame, don't mark as pressed
      if not keys.isUp[key] then
        keys.isPressed[key] = dt
      end
    end
  end

  for key, _ in pairs(keys.isPressed) do
    keys.isPressed[key] = keys.isPressed[key] + dt
  end

  for key, _ in pairs(keys.isUp) do
    if keys.isUp[key] == KEY_CHANGE.DETECTED then
      -- only eliminate pressed - we want to detect inputs that were released on the same frame already
      -- so isDown is not cleared for that reason and it self clears on the next frame
      keys.isPressed[key] = KEY_CHANGE.NONE
      keys.isUp[key] = KEY_CHANGE.APPLIED
    else
      keys.isUp[key] = KEY_CHANGE.NONE
    end
  end
end

function inputManager:aliasKey(key, keyAlias)
  self.isDown[keyAlias] = self.isDown[keyAlias] or self.allKeys.isDown[key]
  self.isUp[keyAlias] = self.isUp[keyAlias] or self.allKeys.isUp[key]
  if self.allKeys.isPressed[key] and (not self.isPressed[keyAlias] or self.allKeys.isPressed[key] > self.isPressed[keyAlias]) then
    self.isPressed[keyAlias] = self.allKeys.isPressed[key]
  end
end

function inputManager:mergePressedKeys(key1, key2)
  local maxPressedTime = math.max(self.allKeys.isPressed[key1] or 0, self.allKeys.isPressed[key2] or 0)
  if maxPressedTime == 0 then
    return nil
  else
    return maxPressedTime
  end
end

function inputManager:updateSystemKeys()
  -- alt
  self.isDown["Alt"] = self.allKeys.isDown["lalt"] or self.allKeys.isDown["ralt"]
  self.isUp["Alt"] = self.allKeys.isUp["lalt"] and self.allKeys.isUp["ralt"]
  self.isPressed["Alt"] = self:mergePressedKeys("lalt", "ralt")

  -- ctrl
  self.isDown["Ctrl"] = self.allKeys.isDown["lctrl"] or self.allKeys.isDown["rctrl"]
  self.isUp["Ctrl"] = self.allKeys.isUp["lctrl"] and self.allKeys.isUp["rctrl"]
  self.isPressed["Ctrl"] = self:mergePressedKeys("lctrl", "rctrl")

  -- shift
  self.isDown["Shift"] = self.allKeys.isDown["lshift"] or self.allKeys.isDown["rshift"]
  self.isUp["Shift"] = self.allKeys.isUp["lshift"] and self.allKeys.isUp["rshift"]
  self.isPressed["Shift"] = self:mergePressedKeys("lshift", "rshift")

  -- systemKey
  self.isDown["SystemKey"] = self.isDown["Alt"] and self.isDown["Ctrl"] and self.isDown["Shift"]
  self.isUp["SystemKey"] = self.isUp["Alt"] and self.isUp["Ctrl"] and self.isUp["Shift"]
  self.isPressed["SystemKey"] = (self.isPressed["Alt"] and self.isPressed["Ctrl"] and self.isPressed["Shift"]) and
                                    math.min(self.isPressed["Alt"], self.isPressed["Ctrl"], self.isPressed["Shift"])
end

-- copy over specific raw key states into the custom input structures defined in the header
function inputManager:updateKeyMaps()
  -- set the reserved key aliases
  for keyAlias, keys in pairs(menuReservedKeysMap) do
    self.isDown[keyAlias] = KEY_CHANGE.NONE
    self.isUp[keyAlias] = KEY_CHANGE.NONE
    self.isPressed[keyAlias] = KEY_CHANGE.NONE
    for _, key in ipairs(keys[1]) do
      self:aliasKey(key, keyAlias)
    end
  end

  for _, keyAlias in ipairs(consts.KEY_NAMES) do
    self.isDown[keyAlias] = KEY_CHANGE.NONE
    self.isUp[keyAlias] = KEY_CHANGE.NONE
    self.isPressed[keyAlias] = KEY_CHANGE.NONE
    for i = 1, #self.inputConfigurations do
      local key = self.inputConfigurations[i][keyAlias]
      self.inputConfigurations[i].isDown[keyAlias] = self.allKeys.isDown[key]
      self.inputConfigurations[i].isUp[keyAlias] = self.allKeys.isUp[key]
      self.inputConfigurations[i].isPressed[keyAlias] = self.allKeys.isPressed[key]

      if not self.inputConfigurations[i].claimed then
        -- the top level inputs only contain unclaimed inputs
        self:aliasKey(key, keyAlias)
      end

      -- copy over configured keys into the menu reserved key aliases
      -- (even if they are not menu reserved keys themselves?) could lead to funky results when binding arrow keys to other stuff
      -- but the alternative is not being able to bind arrow keys to other stuff whatsoever
      if keyNameToMenuKeys[keyAlias] --[[and not menuReservedKeys[key]] then
        local menuKeyAlias = keyNameToMenuKeys[keyAlias]
        -- but they may contain the generic Menu input representation as these are meant to be used only in non-exclusive ways
        self:aliasKey(key, menuKeyAlias)
      end
    end
  end
end

function inputManager:update(dt)
  --self:joystickToButtons()
  self:dPadToButtons()
  self:updateKeyStates(dt, self.allKeys)
  self:updateKeyStates(dt, self.mouse)
  self:updateKeyMaps()
  self:updateSystemKeys()
end

function inputManager:mousePressed(x, y, button)
  if not self.mouse.isDown[button] and not self.mouse.isPressed[button] then
    self.mouse.isDown[button] = KEY_CHANGE.DETECTED
  end
  self.mouse.x = x
  self.mouse.y = y
end

function inputManager:mouseReleased(x, y, button)
  self.mouse.isDown[button] = KEY_CHANGE.NONE
  self.mouse.isPressed[button] = KEY_CHANGE.NONE
  self.mouse.isUp[button] = KEY_CHANGE.DETECTED
  self.mouse.x = x
  self.mouse.y = y
end

function inputManager:mouseMoved(x, y)
  self.mouse.x = x
  self.mouse.y = y
end

local function quantize(x, period)
  return math.floor(x / period) * period
end

local function isPressedWithRepeat(inputs, key, delay, repeatPeriod)
  if delay == nil then
    delay = consts.KEY_DELAY
  end
  if repeatPeriod == nil then
    repeatPeriod = consts.KEY_REPEAT_PERIOD
  end
  if tableUtils.trueForAny(menuKeyNames, function(k)
    return k == key
  end) then
    -- menu inputs always need to work, override the given (even though it might be the same)
    inputs = inputManager
  end

  if inputs.isPressed[key] then
    local prevDuration = quantize(inputs.isPressed[key] - currentDt, repeatPeriod)
    local currDuration = quantize(inputs.isPressed[key], repeatPeriod)
    return inputs.isPressed[key] > delay and prevDuration ~= currDuration
  else
    return inputs.isDown[key]
  end
end

function inputManager:isPressedWithRepeat(key, delay, repeatPeriod, inputs)
  if not inputs then
    inputs = self
  end

  return isPressedWithRepeat(inputs, key, delay, repeatPeriod)
end

-- input migration utils
local function convertButton(rawButton)
  local letterToDir = {u = "up", d = "down", l = "left", r = "right"}
  local button = {rawButton:match("hat(%d+)-(%l+)")}
  if #button ~= 0 then
    return string.format("%s%d", letterToDir[button[2]], button[1])
  end

  button = {rawButton:match("axis(%d+)([%+|%-])")}
  if #button ~= 0 then
    return string.format("%s%s%d", button[2] == "+" and "-" or "+", button[1] % 2 == 0 and "y" or "x", math.ceil(button[1] / 2.0))
  end

  return rawButton
end

local function convertKey(key)
  if not key then
    return nil
  end

  local joystickNameParts = {key:match("(.*)#([^-]*)-(.*)")}
  if #joystickNameParts ~= 0 then
    return string.format("%s:%s:%s", joystickNameParts[1], joystickNameParts[2], convertButton(joystickNameParts[3]))
  end

  joystickNameParts = {key:match("([^-]*)-(.*)")}
  if #joystickNameParts ~= 0 then
    return string.format("%s:0:%s", joystickNameParts[1], convertButton(joystickNameParts[2]))
  end

  return key
end

function inputManager:migrateInputConfigs(inputConfigs)
  local oldToNewKeyMap = self:getOldToNewKeyMap()
  if tableUtils.trueForAll(inputConfigs, function(inputConfig)
    return not inputConfig["Start"]
  end) then
    for i, inputConfig in ipairs(inputConfigs) do
      for oldKey, newKey in pairs(oldToNewKeyMap) do
        inputConfigs[i][newKey] = convertKey(inputConfig[oldKey])
      end
    end
  end
  return inputConfigs
end

function inputManager:getOldToNewKeyMap()
  local oldToNewKeyMap = {
    up = "Up",
    down = "Down",
    left = "Left",
    right = "Right",
    swap1 = "Swap1",
    swap2 = "Swap2",
    taunt_up = "TauntUp",
    taunt_down = "TauntDown",
    raise1 = "Raise1",
    raise2 = "Raise2",
    pause = "Start"
  }

  return oldToNewKeyMap
end

-- Gets only the saved keymaps from each input config
function inputManager:getSaveKeyMap()
  local result = {}
  for i, inputConfig in ipairs(inputManager.inputConfigurations) do
    result[i] = {}
    for _, keyName in ipairs(consts.KEY_NAMES) do
      result[i][keyName] = inputConfig[keyName]
    end
  end
  return result
end

function inputManager:writeKeyConfigurationToFile()
  FileUtils.writeJson("", "keysV3.json", self:getSaveKeyMap())
  self.hasUnsavedChanges = false
end

-- Saves input configuration mappings to disk
function inputManager:saveInputConfigurationMappings()
  self:writeKeyConfigurationToFile()
end


local currentVersionFilename = "keysV3.json"
local previousVersionFilename = "keysV2.json"

function inputManager:hasKeyFile()
  local filename = nil
  local migrateInputs = false
  if FileUtils.exists(currentVersionFilename) then
    filename = currentVersionFilename
  elseif FileUtils.exists(previousVersionFilename) then
    filename = previousVersionFilename
    migrateInputs = true
  end

  return filename, migrateInputs
end

-- Loads input file and setups defaults
function inputManager:load()
  local filename, migrateInputs = self:hasKeyFile()

  if filename == nil then
    -- No key file exists - set up default keys
    inputManager:setupDefaultKeyConfigurations()
    return inputManager.inputConfigurations
  end

  local inputConfigs = FileUtils.readJsonFile(filename)

  if migrateInputs then
    -- migrate old input configs
    inputConfigs = inputManager:migrateInputConfigs(inputConfigs)
  end
  self:importConfigurations(inputConfigs)
  
  return inputConfigs
end

for i = 1, inputManager.maxConfigurations do
  inputManager.inputConfigurations[i] = InputConfiguration(i, isPressedWithRepeat, love.joystick)
end

inputManager.allKeys.isPressedWithRepeat = isPressedWithRepeat

-- Turn inputManager into a Signal emitter
Signal.turnIntoEmitter(inputManager)
inputManager:createSignal("unconfiguredJoystickAdded")

function inputManager:importConfigurations(configurations)
  for i = 1, #configurations do
    for key, value in pairs(configurations[i]) do
      self.inputConfigurations[i][key] = value
    end
  end
  -- Update all cached properties after importing
  for _, inputConfig in ipairs(self.inputConfigurations) do
    inputConfig:updateCachedProperties()
  end
  self:updateAllDeviceNumbers()
end

---@param player Player
---@param inputConfiguration InputConfiguration
function inputManager:claimConfiguration(player, inputConfiguration)
  if inputConfiguration.claimed and inputConfiguration.player ~= player then
    error("Trying to assign input configuration to player " .. player.playerNumber ..
      " that is already in use by player " .. inputConfiguration.player.playerNumber)
  end

  inputConfiguration.claimed = true
  inputConfiguration.player = player

  self:updateKeyMaps()

  return inputConfiguration
end

---@param player Player
---@param inputConfiguration InputConfiguration
function inputManager:releaseConfiguration(player, inputConfiguration)
  if not inputConfiguration.claimed then
    error("Trying to release an unclaimed inputConfiguration")
  elseif inputConfiguration.player ~= player then
    error("Trying to release input configuration of player " .. inputConfiguration.player.playerNumber ..
    " through player " .. player.playerNumber)
  end

  inputConfiguration.claimed = false
  inputConfiguration.player = nil

  self:updateKeyMaps()
end

-- Updates deviceNumber for all InputConfigurations based on device type counts
function inputManager:updateAllDeviceNumbers()
  local deviceTypeCounters = {}

  for _, inputConfig in ipairs(self.inputConfigurations) do
    -- Only count non-empty configurations with bindings
    if not inputConfig:isEmpty() and inputConfig.deviceType then
      deviceTypeCounters[inputConfig.deviceType] = (deviceTypeCounters[inputConfig.deviceType] or 0) + 1
      inputConfig.deviceNumber = deviceTypeCounters[inputConfig.deviceType]
    else
      inputConfig.deviceNumber = nil
    end
  end
end

-- Updates a specific InputConfiguration when its bindings change
---@param inputConfig InputConfiguration Configuration to update
function inputManager:updateInputConfiguration(inputConfig)
  inputConfig:update()
  self:updateAllDeviceNumbers()
end

-- Clears a button binding from all other input configurations
---@param buttonBinding string The button binding to clear (e.g., "space", "guid:slot:button")
function inputManager:clearButtonFromAllConfigs(buttonBinding)
  if not buttonBinding then
    return
  end

  for _, inputConfig in ipairs(self.inputConfigurations) do
    for _, keyName in ipairs(consts.KEY_NAMES) do
      if inputConfig[keyName] == buttonBinding then
        inputConfig[keyName] = nil
      end
    end
  end
end

-- Changes a key binding on an input configuration
---@param inputConfiguration InputConfiguration Configuration to modify
---@param keyName string Key name to change (e.g., "Up", "Down", "Swap1")
---@param keyToUse string? New key binding (nil to clear)
---@param skipSave boolean? If true, skip writing to file (for batch operations)
function inputManager:changeKeyBindingOnInputConfiguration(inputConfiguration, keyName, keyToUse, skipSave)

  -- Clear the new binding from all other configurations
  if keyToUse then
    self:clearButtonFromAllConfigs(keyToUse)
  end

  inputConfiguration[keyName] = keyToUse

  self.hasUnsavedChanges = true
  self:updateInputConfiguration(inputConfiguration)
  self:updateUnconfiguredJoysticksCache()
  if not skipSave then
    self:writeKeyConfigurationToFile()
  end
end

-- Clears all key bindings on an input configuration
---@param inputConfiguration InputConfiguration Configuration to clear
function inputManager:clearKeyBindingsOnInputConfiguration(inputConfiguration)
  for _, keyName in ipairs(consts.KEY_NAMES) do
    inputConfiguration[keyName] = nil
  end
  self.hasUnsavedChanges = true
  self:updateInputConfiguration(inputConfiguration)
  self:updateUnconfiguredJoysticksCache()
  self:writeKeyConfigurationToFile()
end

function inputManager:setupDefaultKeyConfigurations()
  local defaultKeys = {}
  defaultKeys[#defaultKeys+1] = {
    Up = "up",
    Down = "down",
    Left = "left",
    Right = "right",
    Swap1 = "z",
    Swap2 = "x",
    TauntUp = "y",
    TauntDown = "u",
    Raise1 = "c",
    Raise2 = "v",
    Start = "return"
  }
  defaultKeys[#defaultKeys+1] = {
    Up = "w",
    Down = "s",
    Left = "a",
    Right = "d",
    Swap1 = "j",
    Swap2 = "k",
    TauntUp = "i",
    TauntDown = "l",
    Raise1 = "o",
    Raise2 = "u",
    Start = "space"
  }
  for i = 1, inputManager.maxConfigurations do
    if i <= #defaultKeys then
      for keyName, key in pairs(defaultKeys[i]) do
        self.inputConfigurations[i][keyName] = key
      end
    else
      for _, keyName in ipairs(consts.KEY_NAMES) do
        self.inputConfigurations[i][keyName] = nil
      end
    end
  end

  -- Auto-configure all connected gamepads
  local connectedJoysticks = love.joystick.getJoysticks()
  for _, joystick in ipairs(connectedJoysticks) do
    self:autoConfigureJoystick(joystick, false)
  end

  -- Update all cached properties after setting defaults
  for _, inputConfig in ipairs(self.inputConfigurations) do
    inputConfig:updateCachedProperties()
  end
  self:updateAllDeviceNumbers()
end

---@return InputConfiguration? Input configuration with active input, or nil
function inputManager:detectActiveInputConfiguration()
  for i = 1, #self.inputConfigurations do
    local inputConfig = self.inputConfigurations[i]
    for _, keyName in ipairs(consts.KEY_NAMES) do
      if inputConfig.isDown and inputConfig.isDown[keyName] then
        return inputConfig
      end
    end
  end

  return nil
end

---@param localHumanPlayers Player[]
---@return boolean True if an unassigned configuration has active input
function inputManager:checkForUnassignedConfigurationInputs(localHumanPlayers)
  if #localHumanPlayers == 0 then
    return false
  end

  local activeConfig = self:detectActiveInputConfiguration()
  if not activeConfig then
    return false
  end

  local assignedConfigs = {}
  for _, player in ipairs(localHumanPlayers) do
    if player.inputConfiguration then
      assignedConfigs[player.inputConfiguration] = true
    end
  end

  return not assignedConfigs[activeConfig]
end

-- Gets all configured joystick GUIDs from input configurations
---@return table<string, boolean> Map of configured GUIDs
function inputManager:getConfiguredJoystickGuids()
  local configuredGuids = {}
  for i = 1, self.maxConfigurations do
    local inputConfig = self.inputConfigurations[i]
    if inputConfig then
      for _, keyName in ipairs(consts.KEY_NAMES) do
        local keyMapping = inputConfig[keyName]
        if keyMapping and type(keyMapping) == "string" then
          -- Extract GUID from mapping format like "guid:id:button"
          local guid = keyMapping:match("^([^:]+):")
          if guid then
            configuredGuids[guid] = true
          end
        end
      end
    end
  end
  return configuredGuids
end

-- Updates the unconfigured joysticks cache immediately
function inputManager:updateUnconfiguredJoysticksCache()
  -- Build the list
  local unconfiguredJoysticks = {}
  local connectedJoysticks = love.joystick.getJoysticks()
  local configuredGuids = self:getConfiguredJoystickGuids()

  for _, joystick in ipairs(connectedJoysticks) do
    local guid = joystick:getGUID()
    -- Check if this joystick could be auto-configured (has gamepad mapping)
    local customId = joystickManager.guidsToJoysticks[guid] and joystickManager.guidsToJoysticks[guid][joystick:getID()]

    if customId and not configuredGuids[guid] then
      unconfiguredJoysticks[#unconfiguredJoysticks + 1] = joystick
    end
  end

  -- Update the cache
  self.unconfiguredJoysticksCache = unconfiguredJoysticks
end

-- Gets a list of joysticks that don't have input configurations
---@return love.Joystick[] Array of unconfigured joysticks
function inputManager:getUnconfiguredJoysticks()
  -- Return cached value (always fresh since we update immediately)
  return self.unconfiguredJoysticksCache or {}
end

-- Check if there are any connected joysticks that aren't configured
function inputManager:hasUnconfiguredJoysticks()
  local unconfigured = self:getUnconfiguredJoysticks()
  return #unconfigured > 0
end

-- Finds the next available (empty) input configuration slot
---@return number? Index of empty configuration, or nil if all slots are full
function inputManager:findNextAvailableConfig()
  for i = 1, self.maxConfigurations do
    local isEmpty = self.inputConfigurations[i]:isEmpty()
    if isEmpty then
      return i
    end
  end
  -- If all slots are full, return nil to indicate no available slot
  return nil
end

-- Automatically configures a joystick by mapping gamepad buttons to Panel Attack actions
---@param joystick love.Joystick The joystick to configure
---@param shouldSave boolean if the configuration should be saved to disk
---@return number? configIndex The index of the configuration that was set up, or nil if configuration failed
function inputManager:autoConfigureJoystick(joystick, shouldSave)
  local configIndex = self:findNextAvailableConfig()

  -- If no available slot, skip configuration
  if not configIndex then
    return nil
  end

  -- Only auto-configure gamepads (devices with known button mappings)
  if not joystick:isGamepad() then
    return nil
  end

  logger.debug("Autoconfiguring joystick at index " .. configIndex)

  local guid = joystick:getGUID()
  local customId = joystickManager.guidsToJoysticks[guid] and joystickManager.guidsToJoysticks[guid][joystick:getID()]

  if customId ~= nil then
    -- Map Panel Attack actions to Love2D gamepad button names
    local gamepadButtonMappings = {
      Up = "dpup",
      Down = "dpdown",
      Left = "dpleft",
      Right = "dpright",
      Swap1 = "a",
      Swap2 = "b",
      TauntUp = "y",
      TauntDown = "x",
      Raise1 = "leftshoulder",
      Raise2 = "rightshoulder",
      Start = "start"
    }

    local basicMapping = {}

    -- Query the actual button mappings from Love2D
    for panelAttackAction, gamepadButton in pairs(gamepadButtonMappings) do
      local inputtype, inputindex, _ = joystick:getGamepadMapping(gamepadButton)
      if inputtype == "button" then
        basicMapping[panelAttackAction] = guid .. ":" .. customId .. ":" .. inputindex
      elseif inputtype == "hat" then
        -- Some controllers use hat for D-pad instead of individual buttons
        basicMapping[panelAttackAction] = guid .. ":" .. customId .. ":" .. gamepadButton .. inputindex
      end
    end

    -- Only proceed if we got at least some mappings
    if next(basicMapping) then
      -- Ensure the configuration slot has all the keys we need
      local inputConfig = self.inputConfigurations[configIndex]
      for keyName, keyMapping in pairs(basicMapping) do
        self:changeKeyBindingOnInputConfiguration(inputConfig, keyName, keyMapping, true)
      end

      -- Make sure all required keys are set (fill any missing ones with nil to be explicit)
      for _, keyName in ipairs(consts.KEY_NAMES) do
        if inputConfig[keyName] == nil and not basicMapping[keyName] then
          self:changeKeyBindingOnInputConfiguration(inputConfig, keyName, nil, true)
        end
      end

      self:updateUnconfiguredJoysticksCache()
      if shouldSave then
        self:writeKeyConfigurationToFile()
      end
      return configIndex
    end
  end
  return nil
end

-- Gets list of all assignable input devices (controllers, keyboard, touch)
-- Returns InputConfiguration objects directly with all metadata already calculated
---@return InputConfiguration[] inputConfigurations Array of InputConfiguration objects
function inputManager:getAssignableDevices()
  local devices = {}

  -- Add all non-empty InputConfigurations
  for _, inputConfig in ipairs(self.inputConfigurations) do
    if not inputConfig:isEmpty() then
      devices[#devices + 1] = inputConfig
    end
  end

  -- Add touch configuration
  local touchConfig = InputConfiguration.getTouchConfiguration()
  devices[#devices + 1] = touchConfig

  return devices
end

return inputManager
