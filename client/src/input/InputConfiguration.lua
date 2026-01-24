local class = require("common.lib.class")
local consts = require("common.engine.consts")
local util = require("common.lib.util")
local joystickManager = require("common.lib.joystickManager")
require("client.src.input.JoystickProvider")

---@alias InputDeviceType ("keyboard" | "controller" | "touch" | nil)

-- Represents a single input configuration slot with key bindings
---@class InputConfiguration
---@field index number Configuration slot number (1-8)
---@field claimed boolean Whether this config is assigned to a player
---@field player Player? Reference to assigned player (if claimed)
---@field isDown table<string, boolean> Input state tracking
---@field isPressed table<string, number> Input press duration tracking
---@field isUp table<string, boolean> Input release state tracking
---@field isPressedWithRepeat function
---@field joystickProvider JoystickProvider
---@field id string Unique identifier (e.g., "config_1")
---@field deviceType InputDeviceType Device type ("keyboard", "controller", "touch", or nil if empty)
---@field deviceName string? Human-readable device name
---@field controllerImageVariant string? Controller icon variant
---@field deviceNumber number? Device count of this type (e.g., 2nd keyboard)
local InputConfiguration = class(
  function(self, index, isPressedWithRepeatFn, joystickProvider)
    self.index = index
    self.claimed = false
    self.player = nil
    self.isDown = {}
    self.isPressed = {}
    self.isUp = {}
    self.isPressedWithRepeat = isPressedWithRepeatFn
    assert(joystickProvider)
    self.joystickProvider = joystickProvider

    -- Cached properties (calculated on init and when bindings change)
    self.id = string.format("config_%d", index)
    self.deviceType = nil
    self.deviceName = nil
    self.controllerImageVariant = nil
    self.deviceNumber = nil

    -- Calculate initial cached properties
    self:updateCachedProperties()
  end
)

-- Recalculates cached properties for this configuration (does not update deviceNumber - use updateAllDeviceNumbers for that)
function InputConfiguration:updateCachedProperties()
  self.deviceType = self:getDeviceType()
  self.deviceName = self:getDeviceName()
  self.controllerImageVariant = self:getControllerImageVariant()
end

-- Updates this configuration's cached properties when bindings change
-- Note: This does NOT update deviceNumber - caller must update all configs' deviceNumbers
function InputConfiguration:update()
  self:updateCachedProperties()
end

-- Check if this configuration has any key bindings
---@return boolean isEmpty True if no keys are bound
function InputConfiguration:isEmpty()
  for _, keyName in ipairs(consts.KEY_NAMES) do
    if self[keyName] then
      return false
    end
  end
  return true
end

-- Check if this configuration has all required key bindings
---@return boolean isFullyConfigured True if all required keys are bound
function InputConfiguration:isFullyConfigured()
  for _, keyName in ipairs(consts.KEY_NAMES) do
    if not self[keyName] then
      return false
    end
  end
  return true
end

-- Parse a binding string to extract GUID, slot, and button ID (static helper)
---@param binding string? Binding string (e.g., "guid:slot:button")
---@return string? guid Controller GUID or nil if not a controller binding
---@return number? slot Controller slot number or nil if not a controller binding
---@return string? buttonId Button identifier or nil if not a controller binding
function InputConfiguration.parseBindingString(binding)
  if not binding or not binding:match(":") then
    return nil, nil, nil
  end

  local guid, slot, buttonId = binding:match("([^:]+):([^:]+):(.+)")
  if guid and slot and buttonId then
    return guid, tonumber(slot), buttonId
  end

  return nil, nil, nil
end

-- Parse controller binding string to extract GUID and slot
---@param keyName string Key name to parse (e.g., "up", "down", "left")
---@return string? guid Controller GUID or nil if not a controller binding
---@return number? slot Controller slot number or nil if not a controller binding
function InputConfiguration:parseControllerBinding(keyName)
  local binding = self[keyName]
  local guid, slot, _ = InputConfiguration.parseBindingString(binding)
  return guid, slot
end

-- Determine device type based on the first available binding
---@return InputDeviceType deviceType Type of device or nil if no bindings
function InputConfiguration:getDeviceType()
  if self:isEmpty() then
    return nil
  end

  local firstBinding
  for _, keyName in ipairs(consts.KEY_NAMES) do
    local binding = self[keyName]
    if binding then
      firstBinding = binding
      break
    end
  end

  if not firstBinding then
    return nil
  end

  if firstBinding:find(":", 1, true) then
    return "controller"
  end

  if firstBinding:match("^mouse") then
    return "touch"
  end

  return "keyboard"
end

-- Get a human-readable device name for this configuration
---@return string|nil deviceName Human-readable device name or nil if unknown
function InputConfiguration:getDeviceName()
  local deviceType = self:getDeviceType()

  if deviceType == "keyboard" then
    return "Keyboard"
  elseif deviceType == "touch" then
    return "Touch"
  elseif deviceType == "controller" then
    local guid
    local keyNames = consts.KEY_NAMES or {}

    for _, keyName in ipairs(keyNames) do
      guid, _ = self:parseControllerBinding(keyName)
      if guid then
        break
      end
    end

    if not guid then
      return "Controller"
    end

    local joysticks = self.joystickProvider:getJoysticks()
    for _, joystick in ipairs(joysticks) do
      if joystick:getGUID() == guid then
        local name = joystick:getName()
        if name and #name > 0 then
          return name
        end
      end
    end

    return "Controller"
  end

  return nil
end

-- Maps controller names to specific image variants for theme selection (static helper)
---@param controllerName string? Controller name from Love2D
---@return string controllerImageVariant Image variant key (e.g., "playstation4", "xboxone", "generic")
function InputConfiguration.getControllerImageVariantFromName(controllerName)
  if not controllerName then
    return "generic"
  end

  local name = controllerName:lower()

  -- PlayStation controllers
  if name:find("playstation") or name:find("dualshock") or name:find("dualsense") or name:find("ps%d") then
    if name:find("5") or name:find("dualsense") then
      return "playstation5"
    elseif name:find("4") or name:find("dualshock 4") then
      return "playstation4"
    elseif name:find("3") then
      return "playstation3"
    elseif name:find("2") then
      return "playstation2"
    elseif name:find("1") then
      return "playstation1"
    else
      return "playstation4" -- Default to PS4 for generic PlayStation
    end
  end

  -- Xbox controllers
  if name:find("xbox") or name:find("microsoft") then
    if name:find("series") or name:find("xbox series") then
      return "xboxseries"
    elseif name:find("one") or name:find("xbox one") then
      return "xboxone"
    elseif name:find("360") then
      return "xbox360"
    else
      return "xboxone" -- Default to Xbox One for generic Xbox
    end
  end

  -- SNES controllers (8BitDo and others) - Check before Switch to avoid "Super Nintendo" matching "Nintendo"
  if name:find("snes") or name:find("sn30") or name:find("sf30") or name:find("super nintendo") or name:find("super famicom") then
    return "snes"
  end

  -- N64 controllers (8BitDo and others) - Check before Switch to avoid "Nintendo 64" matching "Nintendo"
  if name:find("n64") or name:find("nintendo 64") or name:find("64 controller") or (name:find("8bitdo") and name:find("64")) then
    return "n64"
  end

  -- Hyperkin Admiral N64 Controller
  if name:find("admiral") then
    return "n64"
  end

  -- Nintendo Switch controllers
  if name:find("switch") or name:find("nintendo") or (name:find("pro controller") and not name:find("sn30") and not name:find("sf30")) then
    return "switch_pro"
  end

  -- Hyperkin Scout (SNES-style controller)
  if name:find("scout") and name:find("hyperkin") then
    return "snes"
  end

  -- iBuffalo SNES controllers
  if name:find("ibuffalo") or name:find("2%-axis 8%-button") then
    return "snes"
  end

  -- SEGA Genesis/Mega Drive controllers (M30 style)
  if name:find("m30") or name:find("genesis") or name:find("mega drive") or name:find("neogeo") then
    -- Check it's not a Nintendo M30 variant
    if not name:find("nintendo") then
      return "generic" -- No SEGA controller image, use generic
    end
  end

  -- GameCube controllers
  if name:find("gamecube") or name:find("game cube") then
    return "gamecube"
  end

  -- 8BitDo GameCube adapter
  if name:find("gbros") then
    return "gamecube"
  end

  -- Hori Xbox-style controllers (Horipad for Xbox) - Check first
  if name:find("hori") and name:find("xbox") then
    return "xboxone"
  end

  -- Hori Nintendo Switch controllers - Check for explicit Switch mention
  if name:find("hori") and name:find("switch") then
    return "switch_pro"
  end

  -- Hori GameCube-style controllers (Battle Pad and generic Horipad default to GameCube)
  -- Generic "Horipad" without Xbox/Switch specifier defaults to GameCube style
  if name:find("hori") and (name:find("battle pad") or name:find("horipad")) then
    return "gamecube"
  end

  -- 8BitDo Pro 2 and Pro 3 - PlayStation style (symmetrical sticks)
  if name:find("8bitdo") and (name:find("pro 2") or name:find("pro 3") or name:find("pro2") or name:find("pro3")) then
    return "playstation4" -- Use PS4 as the generic PlayStation style
  end

  -- 8BitDo Ultimate series - Xbox style (asymmetrical sticks)
  if name:find("8bitdo") and name:find("ultimate") then
    return "xboxone" -- Use Xbox One as the generic Xbox style
  end

  -- GameSir Tarantula - PlayStation style (symmetrical sticks)
  if name:find("gamesir") and name:find("tarantula") then
    return "playstation4"
  end

  -- Default to generic controller for other modern controllers
  -- This includes: 8BitDo Lite/Zero/F40/Micro/Arcade, GameSir G7/T4/X2, Hori Fighting Edge, etc.
  return "generic"
end

-- Instance method to get controller image variant for this configuration
---@return string? controllerImageVariant Controller image variant or nil if not a controller
function InputConfiguration:getControllerImageVariant()
  if self:getDeviceType() ~= "controller" then
    return nil
  end

  local controllerName = self:getDeviceName()
  return InputConfiguration.getControllerImageVariantFromName(controllerName)
end

-- Maps gamepad button IDs to display names (static helper)
---@param joystick PanelAttackJoystick? Joystick object
---@param buttonId string Button identifier (e.g., "0", "dpup11", "+y3")
---@return string displayName Display name for the button
function InputConfiguration.getButtonNameFromMapping(joystick, buttonId)
  if not joystick or not joystick:isGamepad() then
    return buttonId
  end

  local gamepadButtonNames = {
    dpup = "Up",
    dpdown = "Down",
    dpleft = "Left",
    dpright = "Right",
    a = "A",
    b = "B",
    x = "X",
    y = "Y",
    leftshoulder = "LB",
    rightshoulder = "RB",
    leftstick = "LS",
    rightstick = "RS",
    start = "Start",
    back = "Back",
    guide = "Guide",
    triggerleft = "LT",
    triggerright = "RT"
  }

  for gamepadButton, displayName in pairs(gamepadButtonNames) do
    local inputtype, inputindex, hatdir = joystick:getGamepadMapping(gamepadButton)
    if inputtype == "button" then
      if tostring(inputindex) == tostring(buttonId) then
        return displayName
      end
      if buttonId == (gamepadButton .. inputindex) then
        return displayName
      end
    elseif inputtype == "hat" then
      if buttonId == (gamepadButton .. inputindex) then
        return displayName
      end
    elseif inputtype == "axis" then
      local stickIndex = math.floor((1 + inputindex) / 2)
      local direction = (inputindex % 2 == 0) and "y" or "x"
      local axisString = direction .. stickIndex

      if buttonId == ("+" .. axisString) or buttonId == ("-" .. axisString) then
        return displayName
      end
    end
  end

  return buttonId
end

-- Find a joystick by GUID and slot
---@param guid string Controller GUID
---@param slot number Controller slot number
---@return PanelAttackJoystick? joystick Joystick object or nil if not found
function InputConfiguration:findJoystick(guid, slot)
  for _, stick in ipairs(self.joystickProvider:getJoysticks()) do
    if stick:getGUID() == guid then
      local guidMap = joystickManager.guidsToJoysticks and joystickManager.guidsToJoysticks[guid]
      if guidMap and guidMap[stick:getID()] == slot then
        return stick
      end
    end
  end
  return nil
end

-- Get human-readable display name for a key binding
---@param keyBinding string? Key binding string (e.g., "space", "guid:slot:button", nil)
---@return string displayName Display name for the key binding
function InputConfiguration:getButtonDisplayName(keyBinding)
  if not keyBinding then
    return loc("op_none")
  end

  local guid, slot, buttonId = InputConfiguration.parseBindingString(keyBinding)

  if not guid or not slot or not buttonId then
    -- Not a controller binding, return as-is
    return keyBinding
  end

  local joystick = self:findJoystick(guid, slot)
  if joystick then
    return InputConfiguration.getButtonNameFromMapping(joystick, buttonId)
  else
    return buttonId
  end
end

-- Singleton touch configuration instance
local touchConfiguration = nil

-- Gets or creates the special Touch InputConfiguration that wraps the mouse
---@return InputConfiguration touchConfig Touch configuration
function InputConfiguration.getTouchConfiguration()
  if not touchConfiguration then
    -- Create a special InputConfiguration for touch
    -- We pass dummy values since touch doesn't use the normal config system
    local dummyFn = function() return false end
    touchConfiguration = InputConfiguration(0, dummyFn, love.joystick)

    -- Set touch-specific properties
    touchConfiguration.id = "touch"
    touchConfiguration.deviceType = "touch"
    touchConfiguration.deviceName = "Touch"
    touchConfiguration.controllerImageVariant = nil
    touchConfiguration.deviceNumber = 1
    touchConfiguration.index = nil

    -- Override isEmpty to return false (touch is always "available")
    touchConfiguration.isEmpty = function() return false end

    -- Link to the actual mouse input state
    touchConfiguration.isDown = GAME.input.mouse.isDown
    touchConfiguration.isPressed = GAME.input.mouse.isPressed
    touchConfiguration.isUp = GAME.input.mouse.isUp
  end

  return touchConfiguration
end

return InputConfiguration
