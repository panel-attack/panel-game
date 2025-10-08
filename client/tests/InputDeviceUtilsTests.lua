local InputDeviceUtils = require("client.src.input.InputDeviceUtils")

-- PlayStation Controllers
local function testPlayStation5Controllers()
  local result = InputDeviceUtils.getControllerImageVariant("PS5 Controller")
  assert(result == "playstation5", "PS5 Controller expected 'playstation5' but got '" .. tostring(result) .. "'")

  result = InputDeviceUtils.getControllerImageVariant("DualSense Wireless Controller")
  assert(result == "playstation5", "DualSense expected 'playstation5' but got '" .. tostring(result) .. "'")

  result = InputDeviceUtils.getControllerImageVariant("Sony DualSense")
  assert(result == "playstation5", "Sony DualSense expected 'playstation5' but got '" .. tostring(result) .. "'")
end

local function testPlayStation4Controllers()
  assert(InputDeviceUtils.getControllerImageVariant("PS4 Controller") == "playstation4")
  assert(InputDeviceUtils.getControllerImageVariant("DUALSHOCK 4 Wireless Controller") == "playstation4")
  assert(InputDeviceUtils.getControllerImageVariant("Sony DualShock 4") == "playstation4")
end

local function testPlayStation3Controllers()
  assert(InputDeviceUtils.getControllerImageVariant("PS3 Controller") == "playstation3")
  assert(InputDeviceUtils.getControllerImageVariant("Sony PLAYSTATION(R)3 Controller") == "playstation3")
end

local function testPlayStation2Controllers()
  assert(InputDeviceUtils.getControllerImageVariant("PS2 Controller") == "playstation2")
end

local function testPlayStation1Controllers()
  assert(InputDeviceUtils.getControllerImageVariant("PS1 Controller") == "playstation1")
  assert(InputDeviceUtils.getControllerImageVariant("PlayStation 1 Controller") == "playstation1")
end

-- Xbox Controllers
local function testXboxSeriesControllers()
  assert(InputDeviceUtils.getControllerImageVariant("Xbox Series X Controller") == "xboxseries")
  assert(InputDeviceUtils.getControllerImageVariant("Xbox Series S Controller") == "xboxseries")
end

local function testXboxOneControllers()
  assert(InputDeviceUtils.getControllerImageVariant("Xbox One Controller") == "xboxone")
  assert(InputDeviceUtils.getControllerImageVariant("Microsoft Xbox One Controller") == "xboxone")
  assert(InputDeviceUtils.getControllerImageVariant("Xbox Wireless Controller") == "xboxone")
end

local function testXbox360Controllers()
  assert(InputDeviceUtils.getControllerImageVariant("Xbox 360 Controller") == "xbox360")
  assert(InputDeviceUtils.getControllerImageVariant("Microsoft Xbox 360 Controller") == "xbox360")
end

-- Nintendo Switch Controllers
local function testSwitchProControllers()
  assert(InputDeviceUtils.getControllerImageVariant("Pro Controller") == "switch_pro")
  assert(InputDeviceUtils.getControllerImageVariant("Nintendo Switch Pro Controller") == "switch_pro")
  assert(InputDeviceUtils.getControllerImageVariant("Switch Pro Controller") == "switch_pro")
end

-- SNES Controllers
local function testSNESControllers()
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo SN30") == "snes")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo SN30 Pro") == "snes")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo SF30") == "snes")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo SF30 Pro") == "snes")
  assert(InputDeviceUtils.getControllerImageVariant("SNES Controller") == "snes")
  assert(InputDeviceUtils.getControllerImageVariant("Super Nintendo Controller") == "snes")
  assert(InputDeviceUtils.getControllerImageVariant("Super Famicom Controller") == "snes")
  assert(InputDeviceUtils.getControllerImageVariant("Hyperkin Scout") == "snes")
  assert(InputDeviceUtils.getControllerImageVariant("Hyperkin Scout Premium SNES Controller") == "snes")
  assert(InputDeviceUtils.getControllerImageVariant("iBuffalo BSGP1204 Series") == "snes")
  assert(InputDeviceUtils.getControllerImageVariant("2-axis 8-button gamepad") == "snes")
end

-- N64 Controllers
local function testN64Controllers()
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo 64") == "n64")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo N64") == "n64")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo 64 Controller") == "n64")
  assert(InputDeviceUtils.getControllerImageVariant("N64 Controller") == "n64")
  assert(InputDeviceUtils.getControllerImageVariant("Nintendo 64 Controller") == "n64")
  assert(InputDeviceUtils.getControllerImageVariant("Hyperkin Admiral N64 Controller") == "n64")
  assert(InputDeviceUtils.getControllerImageVariant("Admiral Controller") == "n64")
end

-- GameCube Controllers
local function testGameCubeControllers()
  assert(InputDeviceUtils.getControllerImageVariant("GameCube Controller") == "gamecube")
  assert(InputDeviceUtils.getControllerImageVariant("Game Cube Controller") == "gamecube")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo GameCube") == "gamecube")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo GBros") == "gamecube")
  assert(InputDeviceUtils.getControllerImageVariant("GBros Adapter") == "gamecube")
  assert(InputDeviceUtils.getControllerImageVariant("Hori Battle Pad") == "gamecube")
  assert(InputDeviceUtils.getControllerImageVariant("Hori Horipad") == "gamecube")
  assert(InputDeviceUtils.getControllerImageVariant("HORIPAD") == "gamecube")
end

-- 8BitDo Pro Series (PlayStation style)
local function test8BitDoProSeries()
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo Pro 2") == "playstation4")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo Pro2") == "playstation4")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo Pro 3") == "playstation4")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo Pro3") == "playstation4")
end

-- 8BitDo Ultimate Series (Xbox style)
local function test8BitDoUltimateSeries()
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo Ultimate") == "xboxone")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo Ultimate 2") == "xboxone")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo Ultimate 2C") == "xboxone")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo Ultimate 3-mode Controller") == "xboxone")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo Ultimate Wired Controller") == "xboxone")
end

-- GameSir Tarantula (PlayStation style)
local function testGameSirTarantula()
  assert(InputDeviceUtils.getControllerImageVariant("GameSir Tarantula") == "playstation4")
  assert(InputDeviceUtils.getControllerImageVariant("GameSir Tarantula Pro") == "playstation4")
end

-- Hori Controllers (various styles)
local function testHoriControllers()
  -- Horipad for Xbox
  assert(InputDeviceUtils.getControllerImageVariant("Horipad Pro for Xbox") == "xboxone")
  assert(InputDeviceUtils.getControllerImageVariant("HORI Xbox Controller") == "xboxone")

  -- Horipad for Switch (explicit Switch mention)
  assert(InputDeviceUtils.getControllerImageVariant("Horipad for Nintendo Switch") == "switch_pro")
  assert(InputDeviceUtils.getControllerImageVariant("HORI Nintendo Switch Controller") == "switch_pro")
end

-- Generic/Unknown Controllers
local function testGenericControllers()
  assert(InputDeviceUtils.getControllerImageVariant("Unknown Controller") == "generic")
  assert(InputDeviceUtils.getControllerImageVariant("Random Gamepad") == "generic")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo Lite") == "generic")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo Lite 2") == "generic")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo Zero") == "generic")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo Zero 2") == "generic")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo Micro") == "generic")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo F40") == "generic")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo Arcade Stick") == "generic")
  assert(InputDeviceUtils.getControllerImageVariant("8BitDo M30") == "generic")
  assert(InputDeviceUtils.getControllerImageVariant("GameSir T4") == "generic")
  assert(InputDeviceUtils.getControllerImageVariant("GameSir G7") == "generic")
  assert(InputDeviceUtils.getControllerImageVariant("Hori Fighting Edge") == "generic")
  assert(InputDeviceUtils.getControllerImageVariant(nil) == "generic")
end

local function test(func)
  func()
end

-- Run all tests
test(testPlayStation5Controllers)
test(testPlayStation4Controllers)
test(testPlayStation3Controllers)
test(testPlayStation2Controllers)
test(testPlayStation1Controllers)
test(testXboxSeriesControllers)
test(testXboxOneControllers)
test(testXbox360Controllers)
test(testSwitchProControllers)
test(testSNESControllers)
test(testN64Controllers)
test(testGameCubeControllers)
test(test8BitDoProSeries)
test(test8BitDoUltimateSeries)
test(testGameSirTarantula)
test(testHoriControllers)
test(testGenericControllers)