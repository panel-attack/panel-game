local InputConfiguration = require("client.src.input.InputConfiguration")
local logger = require("common.lib.logger")

local function createMockIsPressedWithRepeat(key)
  return key == "test"
end

local function createJoystickProvider(joysticks)
  local storedJoysticks = joysticks or {}
  local provider = {}

  function provider:getJoysticks()
    return storedJoysticks
  end

  return provider
end

local function testBasicConstruction()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())

  assert(config ~= nil, "InputConfiguration should be created")
  assert(config.index == 1, "Index should be set to 1")
  assert(config.claimed == false, "Should start unclaimed")
  assert(config.player == nil, "Should have no player")
  assert(type(config.isDown) == "table", "isDown should be a table")
  assert(type(config.isPressed) == "table", "isPressed should be a table")
  assert(type(config.isUp) == "table", "isUp should be a table")
  assert(type(config.isPressedWithRepeat) == "function", "isPressedWithRepeat should be a function")

  logger.trace("passed test testBasicConstruction")
end

local function testConstructionWithDifferentIndex()
  local config1 = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())
  local config2 = InputConfiguration(5, createMockIsPressedWithRepeat, createJoystickProvider())
  local config3 = InputConfiguration(8, createMockIsPressedWithRepeat, createJoystickProvider())

  assert(config1.index == 1, "Config1 should have index 1")
  assert(config2.index == 5, "Config2 should have index 5")
  assert(config3.index == 8, "Config3 should have index 8")

  logger.trace("passed test testConstructionWithDifferentIndex")
end

local function testIsPressedWithRepeatFunction()
  local testFunction = function(key)
    return key == "testkey"
  end

  local config = InputConfiguration(1, testFunction, createJoystickProvider())

  assert(config.isPressedWithRepeat("testkey") == true, "isPressedWithRepeat should return true for testkey")
  assert(config.isPressedWithRepeat("otherkey") == false, "isPressedWithRepeat should return false for otherkey")

  logger.trace("passed test testIsPressedWithRepeatFunction")
end

local function testKeyBindingStorage()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())

  config.Up = "w"
  config.Down = "s"
  config.Left = "a"
  config.Right = "d"

  assert(config.Up == "w", "Up key should be stored")
  assert(config.Down == "s", "Down key should be stored")
  assert(config.Left == "a", "Left key should be stored")
  assert(config.Right == "d", "Right key should be stored")

  logger.trace("passed test testKeyBindingStorage")
end

local function testControllerBindingStorage()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())

  config.Up = "03000000de280000ff11000001000000:1:dpup"
  config.Down = "03000000de280000ff11000001000000:1:dpdown"
  config.SwapL = "03000000de280000ff11000001000000:1:a"

  assert(config.Up == "03000000de280000ff11000001000000:1:dpup", "Controller binding should be stored")
  assert(config.Down == "03000000de280000ff11000001000000:1:dpdown", "Controller binding should be stored")
  assert(config.SwapL == "03000000de280000ff11000001000000:1:a", "Controller binding should be stored")

  logger.trace("passed test testControllerBindingStorage")
end

local function testMixedInputBindings()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())

  config.Up = "w"
  config.Down = "03000000de280000ff11000001000000:1:dpdown"
  config.SwapL = "space"

  assert(config.Up == "w", "Keyboard binding should work")
  assert(config.Down == "03000000de280000ff11000001000000:1:dpdown", "Controller binding should work")
  assert(config.SwapL == "space", "Keyboard binding should work")

  logger.trace("passed test testMixedInputBindings")
end

local function testClaimedProperty()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())

  assert(config.claimed == false, "Should start unclaimed")

  config.claimed = true
  assert(config.claimed == true, "Should be claimable")

  config.claimed = false
  assert(config.claimed == false, "Should be unclaimable")

  logger.trace("passed test testClaimedProperty")
end

local function testPlayerProperty()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())
  local mockPlayer = {playerNumber = 1}

  assert(config.player == nil, "Should start with no player")

  config.player = mockPlayer
  assert(config.player == mockPlayer, "Should store player reference")

  config.player = nil
  assert(config.player == nil, "Should allow clearing player")

  logger.trace("passed test testPlayerProperty")
end

local function testIsDownTable()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())

  config.isDown["w"] = true
  config.isDown["s"] = false

  assert(config.isDown["w"] == true, "isDown should track key state")
  assert(config.isDown["s"] == false, "isDown should track key state")

  logger.trace("passed test testIsDownTable")
end

local function testIsPressedTable()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())

  config.isPressed["w"] = 5
  config.isPressed["s"] = 10

  assert(config.isPressed["w"] == 5, "isPressed should track press duration")
  assert(config.isPressed["s"] == 10, "isPressed should track press duration")

  logger.trace("passed test testIsPressedTable")
end

local function testIsUpTable()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())

  config.isUp["w"] = true
  config.isUp["s"] = false

  assert(config.isUp["w"] == true, "isUp should track release state")
  assert(config.isUp["s"] == false, "isUp should track release state")

  logger.trace("passed test testIsUpTable")
end

local function testEmptyConfiguration()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())

  assert(config.Up == nil, "Empty config should have no Up binding")
  assert(config.Down == nil, "Empty config should have no Down binding")
  assert(config.Left == nil, "Empty config should have no Left binding")
  assert(config.Right == nil, "Empty config should have no Right binding")
  assert(config.SwapL == nil, "Empty config should have no SwapL binding")
  assert(config.SwapR == nil, "Empty config should have no SwapR binding")

  logger.trace("passed test testEmptyConfiguration")
end

local function testMultipleConfigurationsAreIndependent()
  local config1 = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())
  local config2 = InputConfiguration(2, createMockIsPressedWithRepeat, createJoystickProvider())

  config1.Up = "w"
  config1.claimed = true

  config2.Up = "i"
  config2.claimed = false

  assert(config1.Up == "w", "Config1 should have its own bindings")
  assert(config2.Up == "i", "Config2 should have its own bindings")
  assert(config1.claimed == true, "Config1 should have its own claimed state")
  assert(config2.claimed == false, "Config2 should have its own claimed state")

  logger.trace("passed test testMultipleConfigurationsAreIndependent")
end

local function testConfigurationIndex()
  local configs = {}
  for i = 1, 8 do
    configs[i] = InputConfiguration(i, createMockIsPressedWithRepeat, createJoystickProvider())
  end

  for i = 1, 8 do
    assert(configs[i].index == i, "Config " .. i .. " should have index " .. i)
  end

  logger.trace("passed test testConfigurationIndex")
end

local function testBindingOverwrite()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())

  config.Up = "w"
  assert(config.Up == "w", "Should set initial binding")

  config.Up = "i"
  assert(config.Up == "i", "Should overwrite binding")

  config.Up = "03000000de280000ff11000001000000:1:dpup"
  assert(config.Up == "03000000de280000ff11000001000000:1:dpup", "Should overwrite with controller binding")

  logger.trace("passed test testBindingOverwrite")
end

local function testNilBindings()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())

  config.Up = "w"
  assert(config.Up == "w", "Should set binding")

  config.Up = nil
  assert(config.Up == nil, "Should allow clearing binding")

  logger.trace("passed test testNilBindings")
end

local function testAllKeyNames()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())

  config.Up = "w"
  config.Down = "s"
  config.Left = "a"
  config.Right = "d"
  config.SwapL = "space"
  config.SwapR = "lshift"
  config.TauntUp = "1"
  config.TauntDown = "2"
  config.Raise = "r"
  config.Pause = "escape"

  assert(config.Up == "w", "Up should be set")
  assert(config.Down == "s", "Down should be set")
  assert(config.Left == "a", "Left should be set")
  assert(config.Right == "d", "Right should be set")
  assert(config.SwapL == "space", "SwapL should be set")
  assert(config.SwapR == "lshift", "SwapR should be set")
  assert(config.TauntUp == "1", "TauntUp should be set")
  assert(config.TauntDown == "2", "TauntDown should be set")
  assert(config.Raise == "r", "Raise should be set")
  assert(config.Pause == "escape", "Pause should be set")

  logger.trace("passed test testAllKeyNames")
end

local function testIsEmptyWithNoBindings()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())

  assert(config:isEmpty() == true, "Empty config should return true for isEmpty()")

  logger.trace("passed test testIsEmptyWithNoBindings")
end

local function testIsEmptyWithOneBinding()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())
  config.Up = "w"

  assert(config:isEmpty() == false, "Config with one binding should return false for isEmpty()")

  logger.trace("passed test testIsEmptyWithOneBinding")
end

local function testIsEmptyWithAllBindings()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())

  config.Up = "w"
  config.Down = "s"
  config.Left = "a"
  config.Right = "d"
  config.Swap1 = "space"
  config.Swap2 = "lshift"
  config.TauntUp = "1"
  config.TauntDown = "2"
  config.Raise1 = "r"
  config.Raise2 = "t"
  config.Start = "escape"

  assert(config:isEmpty() == false, "Config with all bindings should return false for isEmpty()")

  logger.trace("passed test testIsEmptyWithAllBindings")
end

local function testIsEmptyAfterClearing()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())

  config.Up = "w"
  config.Down = "s"
  config.Left = "a"

  assert(config:isEmpty() == false, "Config with bindings should return false")

  config.Up = nil
  config.Down = nil
  config.Left = nil

  assert(config:isEmpty() == true, "Config after clearing all bindings should return true for isEmpty()")

  logger.trace("passed test testIsEmptyAfterClearing")
end

local function testGetDeviceTypeWithKeyboardBinding()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())
  config.Up = "w"

  assert(config:getDeviceType() == "keyboard", "Keyboard binding should return keyboard device type")

  logger.trace("passed test testGetDeviceTypeWithKeyboardBinding")
end

local function testGetDeviceTypeWithControllerBinding()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())
  config.Up = "03000000de280000ff11000001000000:1:dpup"

  assert(config:getDeviceType() == "controller", "Controller binding should return controller device type")

  logger.trace("passed test testGetDeviceTypeWithControllerBinding")
end

local function testGetDeviceTypeWithTouchBinding()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())
  config.Up = "mouse1"

  assert(config:getDeviceType() == "touch", "Mouse binding should return touch device type")

  logger.trace("passed test testGetDeviceTypeWithTouchBinding")
end

local function testGetDeviceTypeWithEmptyConfig()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())

  assert(config:getDeviceType() == nil, "Empty configuration should return nil device type")

  logger.trace("passed test testGetDeviceTypeWithEmptyConfig")
end

local function testParseControllerBindingWithValidBinding()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())
  config.Up = "03000000de280000ff11000001000000:1:dpup"

  local guid, slot = config:parseControllerBinding("Up")

  assert(guid == "03000000de280000ff11000001000000", "Should extract GUID correctly")
  assert(slot == 1, "Should extract slot correctly")

  logger.trace("passed test testParseControllerBindingWithValidBinding")
end

local function testParseControllerBindingWithKeyboardBinding()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())
  config.Up = "w"

  local guid, slot = config:parseControllerBinding("Up")

  assert(guid == nil, "Should return nil GUID for keyboard binding")
  assert(slot == nil, "Should return nil slot for keyboard binding")

  logger.trace("passed test testParseControllerBindingWithKeyboardBinding")
end

local function testParseControllerBindingWithNilBinding()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())

  local guid, slot = config:parseControllerBinding("Up")

  assert(guid == nil, "Should return nil GUID for nil binding")
  assert(slot == nil, "Should return nil slot for nil binding")

  logger.trace("passed test testParseControllerBindingWithNilBinding")
end

local function testParseControllerBindingWithMalformedBinding()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())
  config.Up = "malformed:binding"

  local guid, slot = config:parseControllerBinding("Up")

  assert(guid == nil, "Should return nil GUID for malformed binding")
  assert(slot == nil, "Should return nil slot for malformed binding")

  logger.trace("passed test testParseControllerBindingWithMalformedBinding")
end

local function testParseControllerBindingWithDifferentSlots()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())

  config.Up = "03000000de280000ff11000001000000:1:dpup"
  config.Down = "03000000de280000ff11000001000000:2:dpdown"
  config.Left = "03000000de280000ff11000001000000:3:dpleft"

  local guid1, slot1 = config:parseControllerBinding("Up")
  local guid2, slot2 = config:parseControllerBinding("Down")
  local guid3, slot3 = config:parseControllerBinding("Left")

  assert(slot1 == 1, "Should parse slot 1 correctly")
  assert(slot2 == 2, "Should parse slot 2 correctly")
  assert(slot3 == 3, "Should parse slot 3 correctly")

  logger.trace("passed test testParseControllerBindingWithDifferentSlots")
end

local function testParseControllerBindingWithDifferentGUIDs()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())

  config.Up = "03000000de280000ff11000001000000:1:dpup"
  config.Down = "030000005e040000120b000005050000:1:dpdown"

  local guid1, slot1 = config:parseControllerBinding("Up")
  local guid2, slot2 = config:parseControllerBinding("Down")

  assert(guid1 == "03000000de280000ff11000001000000", "Should parse first GUID correctly")
  assert(guid2 == "030000005e040000120b000005050000", "Should parse second GUID correctly")

  logger.trace("passed test testParseControllerBindingWithDifferentGUIDs")
end

local function testGetDeviceNameWithKeyboardBinding()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())
  config.Up = "w"

  assert(config:getDeviceName() == "Keyboard", "Keyboard binding should return 'Keyboard'")

  logger.trace("passed test testGetDeviceNameWithKeyboardBinding")
end

local function testGetDeviceNameWithTouchBinding()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())
  config.Up = "mouse1"

  assert(config:getDeviceName() == "Touch", "Mouse binding should return 'Touch'")

  logger.trace("passed test testGetDeviceNameWithTouchBinding")
end

local function testGetDeviceNameWithConnectedController()
  local guid = "03000000de280000ff11000001000000"
  local joystick = {
    getGUID = function()
      return guid
    end,
    getName = function()
      return "Test Controller"
    end,
    getID = function()
      return 1
    end
  }

  local provider = createJoystickProvider({joystick})
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, provider)
  config.Up = guid .. ":1:dpup"

  local deviceName = config:getDeviceName()
  assert(deviceName == "Test Controller", "Connected controller should use joystick name")

  logger.trace("passed test testGetDeviceNameWithConnectedController")
end

local function testGetDeviceNameWithDisconnectedController()
  local guid = "00000000deadbeef0000000000000000"

  local provider = createJoystickProvider()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, provider)
  config.Up = guid .. ":1:dpup"

  local deviceName = config:getDeviceName()
  assert(deviceName == "Controller", "Disconnected controller should fall back to generic name")

  logger.trace("passed test testGetDeviceNameWithDisconnectedController")
end

local function testGetDeviceNameWithUnknownController()
  local guid = "unknown-guid-0000"

  local provider = createJoystickProvider()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, provider)
  config.Up = guid .. ":1:dpup"

  local deviceName = config:getDeviceName()
  assert(deviceName == "Controller", "Unknown controller should return 'Controller'")

  logger.trace("passed test testGetDeviceNameWithUnknownController")
end

local function testGetDeviceNameWithEmptyConfig()
  local config = InputConfiguration(1, createMockIsPressedWithRepeat, createJoystickProvider())

  assert(config:getDeviceName() == nil, "Empty configuration should return nil device name")

  logger.trace("passed test testGetDeviceNameWithEmptyConfig")
end

testBasicConstruction()
testConstructionWithDifferentIndex()
testIsPressedWithRepeatFunction()
testKeyBindingStorage()
testControllerBindingStorage()
testMixedInputBindings()
testClaimedProperty()
testPlayerProperty()
testIsDownTable()
testIsPressedTable()
testIsUpTable()
testEmptyConfiguration()
testMultipleConfigurationsAreIndependent()
testConfigurationIndex()
testBindingOverwrite()
testNilBindings()
testAllKeyNames()
testIsEmptyWithNoBindings()
testIsEmptyWithOneBinding()
testIsEmptyWithAllBindings()
testIsEmptyAfterClearing()
testGetDeviceTypeWithKeyboardBinding()
testGetDeviceTypeWithControllerBinding()
testGetDeviceTypeWithTouchBinding()
testGetDeviceTypeWithEmptyConfig()
testParseControllerBindingWithValidBinding()
testParseControllerBindingWithKeyboardBinding()
testParseControllerBindingWithNilBinding()
testParseControllerBindingWithMalformedBinding()
testParseControllerBindingWithDifferentSlots()
testParseControllerBindingWithDifferentGUIDs()
testGetDeviceNameWithKeyboardBinding()
testGetDeviceNameWithTouchBinding()
testGetDeviceNameWithConnectedController()
testGetDeviceNameWithDisconnectedController()
testGetDeviceNameWithUnknownController()
testGetDeviceNameWithEmptyConfig()

-- Controller Image Variant Tests (using static helper)
local function testPlayStation5Controllers()
  assert(InputConfiguration.getControllerImageVariantFromName("PS5 Controller") == "playstation5")
  assert(InputConfiguration.getControllerImageVariantFromName("DualSense Wireless Controller") == "playstation5")
  assert(InputConfiguration.getControllerImageVariantFromName("Sony DualSense") == "playstation5")
  logger.trace("passed test testPlayStation5Controllers")
end

local function testPlayStation4Controllers()
  assert(InputConfiguration.getControllerImageVariantFromName("PS4 Controller") == "playstation4")
  assert(InputConfiguration.getControllerImageVariantFromName("DUALSHOCK 4 Wireless Controller") == "playstation4")
  assert(InputConfiguration.getControllerImageVariantFromName("Sony DualShock 4") == "playstation4")
  logger.trace("passed test testPlayStation4Controllers")
end

local function testPlayStation3Controllers()
  assert(InputConfiguration.getControllerImageVariantFromName("PS3 Controller") == "playstation3")
  assert(InputConfiguration.getControllerImageVariantFromName("Sony PLAYSTATION(R)3 Controller") == "playstation3")
  logger.trace("passed test testPlayStation3Controllers")
end

local function testPlayStation2Controllers()
  assert(InputConfiguration.getControllerImageVariantFromName("PS2 Controller") == "playstation2")
  logger.trace("passed test testPlayStation2Controllers")
end

local function testPlayStation1Controllers()
  assert(InputConfiguration.getControllerImageVariantFromName("PS1 Controller") == "playstation1")
  assert(InputConfiguration.getControllerImageVariantFromName("PlayStation 1 Controller") == "playstation1")
  logger.trace("passed test testPlayStation1Controllers")
end

local function testXboxSeriesControllers()
  assert(InputConfiguration.getControllerImageVariantFromName("Xbox Series X Controller") == "xboxseries")
  assert(InputConfiguration.getControllerImageVariantFromName("Xbox Series S Controller") == "xboxseries")
  logger.trace("passed test testXboxSeriesControllers")
end

local function testXboxOneControllers()
  assert(InputConfiguration.getControllerImageVariantFromName("Xbox One Controller") == "xboxone")
  assert(InputConfiguration.getControllerImageVariantFromName("Microsoft Xbox One Controller") == "xboxone")
  assert(InputConfiguration.getControllerImageVariantFromName("Xbox Wireless Controller") == "xboxone")
  logger.trace("passed test testXboxOneControllers")
end

local function testXbox360Controllers()
  assert(InputConfiguration.getControllerImageVariantFromName("Xbox 360 Controller") == "xbox360")
  assert(InputConfiguration.getControllerImageVariantFromName("Microsoft Xbox 360 Controller") == "xbox360")
  logger.trace("passed test testXbox360Controllers")
end

local function testSwitchProControllers()
  assert(InputConfiguration.getControllerImageVariantFromName("Pro Controller") == "switch_pro")
  assert(InputConfiguration.getControllerImageVariantFromName("Nintendo Switch Pro Controller") == "switch_pro")
  assert(InputConfiguration.getControllerImageVariantFromName("Switch Pro Controller") == "switch_pro")
  logger.trace("passed test testSwitchProControllers")
end

local function testSNESControllers()
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo SN30") == "snes")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo SN30 Pro") == "snes")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo SF30") == "snes")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo SF30 Pro") == "snes")
  assert(InputConfiguration.getControllerImageVariantFromName("SNES Controller") == "snes")
  assert(InputConfiguration.getControllerImageVariantFromName("Super Nintendo Controller") == "snes")
  assert(InputConfiguration.getControllerImageVariantFromName("Super Famicom Controller") == "snes")
  assert(InputConfiguration.getControllerImageVariantFromName("Hyperkin Scout") == "snes")
  assert(InputConfiguration.getControllerImageVariantFromName("Hyperkin Scout Premium SNES Controller") == "snes")
  assert(InputConfiguration.getControllerImageVariantFromName("iBuffalo BSGP1204 Series") == "snes")
  assert(InputConfiguration.getControllerImageVariantFromName("2-axis 8-button gamepad") == "snes")
  logger.trace("passed test testSNESControllers")
end

local function testN64Controllers()
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo 64") == "n64")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo N64") == "n64")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo 64 Controller") == "n64")
  assert(InputConfiguration.getControllerImageVariantFromName("N64 Controller") == "n64")
  assert(InputConfiguration.getControllerImageVariantFromName("Nintendo 64 Controller") == "n64")
  assert(InputConfiguration.getControllerImageVariantFromName("Hyperkin Admiral N64 Controller") == "n64")
  assert(InputConfiguration.getControllerImageVariantFromName("Admiral Controller") == "n64")
  logger.trace("passed test testN64Controllers")
end

local function testGameCubeControllers()
  assert(InputConfiguration.getControllerImageVariantFromName("GameCube Controller") == "gamecube")
  assert(InputConfiguration.getControllerImageVariantFromName("Game Cube Controller") == "gamecube")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo GameCube") == "gamecube")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo GBros") == "gamecube")
  assert(InputConfiguration.getControllerImageVariantFromName("GBros Adapter") == "gamecube")
  assert(InputConfiguration.getControllerImageVariantFromName("Hori Battle Pad") == "gamecube")
  assert(InputConfiguration.getControllerImageVariantFromName("Hori Horipad") == "gamecube")
  assert(InputConfiguration.getControllerImageVariantFromName("HORIPAD") == "gamecube")
  logger.trace("passed test testGameCubeControllers")
end

local function test8BitDoProSeries()
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo Pro 2") == "playstation4")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo Pro2") == "playstation4")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo Pro 3") == "playstation4")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo Pro3") == "playstation4")
  logger.trace("passed test test8BitDoProSeries")
end

local function test8BitDoUltimateSeries()
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo Ultimate") == "xboxone")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo Ultimate 2") == "xboxone")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo Ultimate 2C") == "xboxone")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo Ultimate 3-mode Controller") == "xboxone")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo Ultimate Wired Controller") == "xboxone")
  logger.trace("passed test test8BitDoUltimateSeries")
end

local function testGameSirTarantula()
  assert(InputConfiguration.getControllerImageVariantFromName("GameSir Tarantula") == "playstation4")
  assert(InputConfiguration.getControllerImageVariantFromName("GameSir Tarantula Pro") == "playstation4")
  logger.trace("passed test testGameSirTarantula")
end

local function testHoriControllers()
  assert(InputConfiguration.getControllerImageVariantFromName("Horipad Pro for Xbox") == "xboxone")
  assert(InputConfiguration.getControllerImageVariantFromName("HORI Xbox Controller") == "xboxone")
  assert(InputConfiguration.getControllerImageVariantFromName("Horipad for Nintendo Switch") == "switch_pro")
  assert(InputConfiguration.getControllerImageVariantFromName("HORI Nintendo Switch Controller") == "switch_pro")
  logger.trace("passed test testHoriControllers")
end

local function testGenericControllers()
  assert(InputConfiguration.getControllerImageVariantFromName("Unknown Controller") == "generic")
  assert(InputConfiguration.getControllerImageVariantFromName("Random Gamepad") == "generic")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo Lite") == "generic")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo Lite 2") == "generic")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo Zero") == "generic")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo Zero 2") == "generic")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo Micro") == "generic")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo F40") == "generic")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo Arcade Stick") == "generic")
  assert(InputConfiguration.getControllerImageVariantFromName("8BitDo M30") == "generic")
  assert(InputConfiguration.getControllerImageVariantFromName("GameSir T4") == "generic")
  assert(InputConfiguration.getControllerImageVariantFromName("GameSir G7") == "generic")
  assert(InputConfiguration.getControllerImageVariantFromName("Hori Fighting Edge") == "generic")
  assert(InputConfiguration.getControllerImageVariantFromName(nil) == "generic")
  logger.trace("passed test testGenericControllers")
end

testPlayStation5Controllers()
testPlayStation4Controllers()
testPlayStation3Controllers()
testPlayStation2Controllers()
testPlayStation1Controllers()
testXboxSeriesControllers()
testXboxOneControllers()
testXbox360Controllers()
testSwitchProControllers()
testSNESControllers()
testN64Controllers()
testGameCubeControllers()
test8BitDoProSeries()
test8BitDoUltimateSeries()
testGameSirTarantula()
testHoriControllers()
testGenericControllers()

logger.trace("All InputConfiguration tests passed!")
