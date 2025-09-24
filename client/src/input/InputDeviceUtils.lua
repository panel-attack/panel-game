local joystickManager = require("common.lib.joystickManager")
local consts = require("common.engine.consts")
local logger = require("common.lib.logger")

local InputDeviceUtils = {}

-- Parses controller binding string to extract GUID and slot
local function parseControllerBinding(binding)
  if not binding then
    return nil
  end

  local guid, slot = binding:match("([^:]+):([^:]+):")
  if guid and slot then
    return guid, tonumber(slot)
  end

  return nil
end

-- Resolves controller name from GUID and slot using Love2D joystick API
local function resolveControllerName(guid, slot)
  if not guid then
    return nil
  end

  local fallbackName = joystickManager.guidToName and joystickManager.guidToName[guid]

  for _, joystick in ipairs(love.joystick.getJoysticks()) do
    if joystick:getGUID() ~= guid then
      goto continue
    end

    if not slot then
      local name = joystick:getName()
      return name
    end

    local guidMap = joystickManager.guidsToJoysticks and joystickManager.guidsToJoysticks[guid]
    if guidMap and guidMap[joystick:getID()] == slot then
      local name = joystick:getName()
      return name
    end

    ::continue::
  end

  return fallbackName
end

-- Classifies input configuration as keyboard, controller, or touch based on bindings
local function classifyConfiguration(config, index)
  local firstBinding
  for _, keyName in ipairs(consts.KEY_NAMES) do
    local binding = config[keyName]
    if binding then
      firstBinding = firstBinding or binding
      if binding:find(":", 1, true) then
        local guid, slot = parseControllerBinding(binding)
        local name = resolveControllerName(guid, slot)
        if slot then
          return "controller", name or "Controller"
        end
        return "controller", name or "Controller"
      end
    end
  end

  if firstBinding and firstBinding:match("^mouse") then
    return "touch", "Touch"
  end

  return "keyboard", "Keyboard"
end

-- Builds device descriptor for input configuration
local function buildConfigDescriptor(config, index)
  local deviceType, label = classifyConfiguration(config, index)

  return {
    id = string.format("config_%d", index),
    config = config,
    type = deviceType,
    label = label,
    index = index,
    assignedPlayer = config.player
  }
end

-- Builds device descriptor for touch/mouse input
local function buildTouchDescriptor()
  local mouse = GAME.input.mouse
  return {
    id = "touch",
    config = mouse,
    type = "touch",
    label = "Touch",
    index = nil,
    assignedPlayer = mouse.player
  }
end

-- Gets list of all assignable input devices (controllers, keyboard, touch)
function InputDeviceUtils.getAssignableDevices()
  local devices = {}
  for i, config in ipairs(GAME.input.inputConfigurations) do
    if config["Swap1"] or config["Start"] then
      devices[#devices + 1] = buildConfigDescriptor(config, i)
    end
  end

  devices[#devices + 1] = buildTouchDescriptor()

  return devices
end

-- Gets label for a specific input configuration
local function getConfigurationLabel(inputConfiguration)
  for i, config in ipairs(GAME.input.inputConfigurations) do
    if config == inputConfiguration then
      local descriptor = buildConfigDescriptor(config, i)
      return descriptor.label
    end
  end
  return "Unknown"
end

-- Describes current input device assignment for a player
local function describePlayerAssignment(player)
  if not player then
    return ""
  end

  if player.inputConfiguration == GAME.input.mouse then
    return "Touch"
  end

  if player.inputConfiguration then
    return getConfigurationLabel(player.inputConfiguration)
  end

  return "Unassigned"
end

-- Formats assignment summary text showing all player device assignments
function InputDeviceUtils.formatAssignmentSummary(players)
  local lines = {}
  for i, player in ipairs(players) do
    local indexLabel = player.playerNumber or i
    lines[#lines + 1] = string.format("Player %s: %s", indexLabel, describePlayerAssignment(player))
  end
  return table.concat(lines, "\n")
end

-- Public wrapper for describePlayerAssignment
function InputDeviceUtils.describePlayerAssignment(player)
  return describePlayerAssignment(player)
end

-- Detects which input configuration is currently providing input
function InputDeviceUtils.detectActiveInputConfiguration()
  for i = 1, #GAME.input.inputConfigurations do
    local config = GAME.input.inputConfigurations[i]
    for _, keyName in ipairs(consts.KEY_NAMES) do
      if config.isDown and config.isDown[keyName] then
        return config
      end
    end
  end

  return nil
end

function InputDeviceUtils.checkForUnassignedConfigurationInputs(battleRoom)
  if not battleRoom then
    return false
  end

  local activeConfig = InputDeviceUtils.detectActiveInputConfiguration()
  if not activeConfig then
    return false
  end

  local assignedConfigs = {}
  for _, player in ipairs(battleRoom:getLocalHumanPlayers()) do
    if player.inputConfiguration then
      assignedConfigs[player.inputConfiguration] = true
    end
  end

  return not assignedConfigs[activeConfig]
end

return InputDeviceUtils
