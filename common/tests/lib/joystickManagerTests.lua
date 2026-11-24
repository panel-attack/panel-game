local joystickManager = require("common.lib.joystickManager")
local logger = require("common.lib.logger")

-- a joystick whose hat reads hatDirection, registered with joystickManager under a GUID no real controller has
local function createRegisteredFakeJoystick(id, hatDirection)
  local joystick = {}
  function joystick:getGUID()
    return "joystickManagerTestsGUID"
  end
  function joystick:getID()
    return id
  end
  function joystick:getName()
    return "Fake Pro Controller"
  end
  function joystick:isGamepad()
    return false
  end
  function joystick:getDeviceInfo()
    return 0, 0, 0
  end
  function joystick:getAxisCount()
    return 0
  end
  function joystick:getHat()
    return hatDirection
  end
  joystickManager:registerJoystick(joystick)
  return joystick
end

-- counts logger.warn calls made while running fn
local function countWarnings(fn)
  local warn = logger.warn
  local warningCount = 0
  logger.warn = function()
    warningCount = warningCount + 1
  end
  local success, err = pcall(fn)
  logger.warn = warn
  assert(success, err)
  return warningCount
end

local function testUnknownHatDirectionReadsAsCentered()
  -- SDL's HIDAPI Switch driver reports up and down together, which LOVE's getHat returns as ""
  local joystick = createRegisteredFakeJoystick(9001, "")

  local warningCount = countWarnings(function()
    for _ = 1, 3 do
      local dpadState = joystickManager:getDPadState(joystick, 1)
      for key, isPressed in pairs(dpadState) do
        assert(not isPressed, key .. " should read as released for an unknown hat direction")
      end
    end
  end)
  assert(warningCount == 1, "an unknown hat direction should be logged once per controller, got " .. warningCount)

  joystickManager:unregisterJoystick(joystick)
end

local function testUnknownHatDirectionIsLoggedForEachController()
  local firstJoystick = createRegisteredFakeJoystick(9002, "")
  local secondJoystick = createRegisteredFakeJoystick(9003, "")

  local warningCount = countWarnings(function()
    joystickManager:getDPadState(firstJoystick, 1)
    joystickManager:getDPadState(secondJoystick, 1)
    joystickManager:getDPadState(firstJoystick, 1)
  end)
  assert(warningCount == 2, "each controller should log its unknown hat direction once, got " .. warningCount)

  joystickManager:unregisterJoystick(firstJoystick)
  joystickManager:unregisterJoystick(secondJoystick)
end

local function testKnownHatDirectionPressesItsButtons()
  local joystick = createRegisteredFakeJoystick(9004, "lu")

  local dpadState = joystickManager:getDPadState(joystick, 1)
  assert(dpadState[joystickManager:getJoystickButtonName(joystick, "left1")])
  assert(dpadState[joystickManager:getJoystickButtonName(joystick, "up1")])
  assert(not dpadState[joystickManager:getJoystickButtonName(joystick, "right1")])
  assert(not dpadState[joystickManager:getJoystickButtonName(joystick, "down1")])

  joystickManager:unregisterJoystick(joystick)
end

testUnknownHatDirectionReadsAsCentered()
testUnknownHatDirectionIsLoggedForEachController()
testKnownHatDirectionPressesItsButtons()
