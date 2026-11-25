local input = require("client.src.inputManager")
local joystickManager = require("common.lib.joystickManager")

-- A stand-in for a love.Joystick that LÖVE opened without sending joystickadded, as it does for controllers connected at launch
---@param id integer
---@param hat love.JoystickHat
local function createUnregisteredJoystick(id, hat)
  return {
    getID = function() return id end,
    getGUID = function() return "joystickInputTestsGuid" end,
    getName = function() return "Joystick Input Tests Stick" end,
    isGamepad = function() return false end,
    getDeviceInfo = function() return 0, 0, 0 end,
    getAxisCount = function() return 2 end,
    getAxis = function() return 0 end,
    getHatCount = function() return 1 end,
    getHat = function() return hat end,
  }
end

-- Runs test with fresh key tables, unregistering the joystick and putting the key tables back afterwards
---@param joystick table
---@param test fun()
local function withJoystick(joystick, test)
  local isDown, isPressed, isUp = input.allKeys.isDown, input.allKeys.isPressed, input.allKeys.isUp
  input.allKeys.isDown, input.allKeys.isPressed, input.allKeys.isUp = {}, {}, {}

  local ok, err = pcall(test)

  if joystickManager:isRegistered(joystick) then
    joystickManager:unregisterJoystick(joystick)
  end
  input.allKeys.isDown, input.allKeys.isPressed, input.allKeys.isUp = isDown, isPressed, isUp
  assert(ok, err)
end

local function testAxisInputFromAnUnregisteredJoystickPressesItsDirection()
  local joystick = createUnregisteredJoystick(9001, "c")
  withJoystick(joystick, function()
    input:joystickaxis(joystick, 1, 1)

    assert(joystickManager:isRegistered(joystick), "axis input should register a joystick that was never added")
    local key = joystickManager:getJoystickButtonName(joystick, "+x1")
    assert(input.allKeys.isDown[key], "pushing axis 1 to 1 should press " .. key)
  end)
end

testAxisInputFromAnUnregisteredJoystickPressesItsDirection()

local function testDPadOfAnUnregisteredJoystickPressesItsDirection()
  local joystick = createUnregisteredJoystick(9002, "u")
  local getJoysticks = love.joystick.getJoysticks
  local joystickModule = love.joystick
  joystickModule["getJoysticks"] = function() return {joystick} end
  local ok, err = pcall(withJoystick, joystick, function()
    input:dPadToButtons()

    assert(joystickManager:isRegistered(joystick), "reading the dpad should register a joystick that was never added")
    local key = joystickManager:getJoystickButtonName(joystick, "up1")
    assert(input.allKeys.isDown[key], "a hat held up should press " .. key)
  end)
  joystickModule["getJoysticks"] = getJoysticks
  assert(ok, err)
end

testDPadOfAnUnregisteredJoystickPressesItsDirection()
