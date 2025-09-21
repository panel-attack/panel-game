local joystickManager = require("common.lib.joystickManager")
local consts = require("common.engine.consts")
local logger = require("common.lib.logger")

local InputDeviceUtils = {}

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

local function resolveControllerName(guid, slot)
  if not guid then
    return nil
  end

  local fallbackName = joystickManager.guidToName and joystickManager.guidToName[guid]

  for _, joystick in ipairs(love.joystick.getJoysticks()) do
    if joystick:getGUID() == guid then
      if not slot then
        local name = joystick:getName()
        logger.debug("InputDeviceUtils:resolveControllerName guid=%s slot=nil name=%s", guid, name)
        return name
      end

      local guidMap = joystickManager.guidsToJoysticks and joystickManager.guidsToJoysticks[guid]
      if guidMap and guidMap[joystick:getID()] == slot then
        local name = joystick:getName()
        logger.debug("InputDeviceUtils:resolveControllerName guid=%s slot=%s name=%s", guid, tostring(slot), name)
        return name
      end
    end
  end

  return fallbackName
end

local function classifyConfiguration(config, index)
  logger.debug("InputDeviceUtils:classifyConfiguration index=%s", tostring(index))
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
    logger.debug("InputDeviceUtils:classifyConfiguration detected touch binding")
    return "touch", "Touch"
  end

  logger.debug("InputDeviceUtils:classifyConfiguration default keyboard")
  return "keyboard", "Keyboard"
end

local function buildConfigDescriptor(config, index)
  local deviceType, label = classifyConfiguration(config, index)

  return {
    id = string.format("config_%d", index),
    config = config,
    type = deviceType,
    label = label,
    index = index,
    assignedPlayer = config.player,
    bindings = {
      Swap1 = config["Swap1"],
      Start = config["Start"],
      Swap2 = config["Swap2"],
      MenuSelect = config["MenuSelect"],
    }
  }
end

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

function InputDeviceUtils.getAssignableDevices()
  local devices = {}
  for i, config in ipairs(GAME.input.inputConfigurations) do
    if config["Swap1"] or config["Start"] then
      logger.debug("InputDeviceUtils:getAssignableDevices adding config index=%d", i)
      devices[#devices + 1] = buildConfigDescriptor(config, i)
    end
  end

  devices[#devices + 1] = buildTouchDescriptor()
  logger.debug("InputDeviceUtils:getAssignableDevices total=%d", #devices)

  return devices
end

local function describePlayerAssignment(player)
  if not player then
    return ""
  end

  if player.inputConfiguration == GAME.input.mouse then
    return "Touch"
  end

  if player.inputConfiguration then
    local index
    for i, config in ipairs(GAME.input.inputConfigurations) do
      if config == player.inputConfiguration then
        index = i
        break
      end
    end

    if index then
      local descriptor = buildConfigDescriptor(player.inputConfiguration, index)
      return descriptor.label
    end
  end

  if player.settings.inputMethod == "touch" then
    return "Touch"
  end

  return "Unassigned"
end

function InputDeviceUtils.formatAssignmentSummary(players)
  local lines = {}
  for i, player in ipairs(players) do
    local indexLabel = player.playerNumber or i
    lines[#lines + 1] = string.format("Player %s: %s", indexLabel, describePlayerAssignment(player))
  end
  logger.debug("InputDeviceUtils:formatAssignmentSummary lines=%d", #lines)
  return table.concat(lines, "\n")
end

function InputDeviceUtils.describePlayerAssignment(player)
  return describePlayerAssignment(player)
end

return InputDeviceUtils
