local joystickManager = require("common.lib.joystickManager")
local consts = require("common.engine.consts")
local logger = require("common.lib.logger")

-- Utility module for detecting, classifying, and labeling input devices
local InputDeviceUtils = {}

-- Parses controller binding string to extract GUID and slot
---@param binding string? Controller binding string (format: "guid:slot:...")
---@return string? guid Controller GUID
---@return number? slot Controller slot number
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
---@param guid string Controller GUID
---@param slot number? Controller slot number
---@return string? Controller name or nil
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
---@param config table Input configuration object
---@param index number Configuration index
---@return string deviceType "keyboard", "controller", or "touch"
---@return string label Human-readable device name
local function classifyConfiguration(config, index)
  local firstBinding
  for _, keyName in ipairs(consts.KEY_NAMES) do
    local binding = config[keyName]
    if binding then
      firstBinding = firstBinding or binding
      if binding:find(":", 1, true) then
        local guid, slot = parseControllerBinding(binding)
        if guid then
          local name = resolveControllerName(guid, slot)
          return "controller", name or "Controller"
        end
        return "controller", "Controller"
      end
    end
  end

  if firstBinding and firstBinding:match("^mouse") then
    return "touch", "Touch"
  end

  return "keyboard", "Keyboard"
end

-- Maps controller names to specific image variants for theme selection
---@param controllerName string? Controller name from Love2D
---@return string Image variant key (e.g., "playstation4", "xboxone", "generic")
function InputDeviceUtils.getControllerImageVariant(controllerName)
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

-- Builds device descriptor for input configuration
---@param config table Input configuration object
---@param index number Configuration index in GAME.input.inputConfigurations
---@return table Device descriptor with type, label, config, etc.
local function buildConfigDescriptor(config, index)
  local deviceType, label = classifyConfiguration(config, index)

  -- For controllers, determine the specific image variant to use
  local controllerImageVariant = nil
  if deviceType == "controller" then
    controllerImageVariant = InputDeviceUtils.getControllerImageVariant(label)
  end

  return {
    id = string.format("config_%d", index),
    config = config,
    type = deviceType,
    label = label,
    controllerImageVariant = controllerImageVariant, -- Specific controller image to use
    index = index,
    assignedPlayer = config.player
  }
end

-- Builds device descriptor for touch/mouse input
---@return table Touch device descriptor
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
---@return table[] Array of device descriptors with metadata
function InputDeviceUtils.getAssignableDevices()
  local devices = {}
  local deviceTypeCounters = {} -- Track device configuration numbers per type

  for i, config in ipairs(GAME.input.inputConfigurations) do
    if config["Swap1"] or config["Start"] then
      local descriptor = buildConfigDescriptor(config, i)

      -- Calculate device configuration number for this type
      deviceTypeCounters[descriptor.type] = (deviceTypeCounters[descriptor.type] or 0) + 1
      descriptor.deviceNumber = deviceTypeCounters[descriptor.type]

      devices[#devices + 1] = descriptor
    end
  end

  local touchDescriptor = buildTouchDescriptor()
  touchDescriptor.deviceNumber = 1 -- Touch is always device number 1
  devices[#devices + 1] = touchDescriptor

  return devices
end

-- Gets label for a specific input configuration
---@param inputConfiguration table Input configuration object
---@return string Human-readable label
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
---@param player Player?
---@return string Description of player's device assignment
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
---@param players Player[] Array of players
---@return string Multi-line summary text
function InputDeviceUtils.formatAssignmentSummary(players)
  local lines = {}
  for i, player in ipairs(players) do
    local indexLabel = player.playerNumber or i
    lines[#lines + 1] = string.format("Player %s: %s", indexLabel, describePlayerAssignment(player))
  end
  return table.concat(lines, "\n")
end

-- Public wrapper for describePlayerAssignment
---@param player Player
---@return string Description of player's device assignment
function InputDeviceUtils.describePlayerAssignment(player)
  return describePlayerAssignment(player)
end

-- Detects which input configuration is currently providing input
---@return table? Input configuration with active input, or nil
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

---@param battleRoom BattleRoom?
---@return boolean True if an unassigned configuration has active input
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
