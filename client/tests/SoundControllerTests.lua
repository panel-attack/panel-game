local SoundController = require("client.src.music.SoundController")
local system = require("client.src.system")

---@param test fun(state: {os: string, currentDevice: string})
local function withMockPlaybackDevices(test)
  local originalGetOS = love.system.getOS
  local originalGetPlaybackDevices = love.audio.getPlaybackDevices
  local originalGetPlaybackDevice = love.audio.getPlaybackDevice
  local originalSetPlaybackDevice = love.audio.setPlaybackDevice
  local originalMeetsLoveVersionRequirement = system.meetsLoveVersionRequirement
  local originalNextCheck = SoundController.nextPlaybackDeviceCheck

  local state = {os = "Windows", currentDevice = "Speakers"}

  love.system.getOS = function()
    return state.os
  end
  system.meetsLoveVersionRequirement = function()
    return true
  end
  love.audio.getPlaybackDevices = function()
    return {"Headphones", "Speakers"}
  end
  love.audio.getPlaybackDevice = function()
    return state.currentDevice
  end
  love.audio.setPlaybackDevice = function(device)
    state.currentDevice = device
    return true
  end
  SoundController.nextPlaybackDeviceCheck = nil

  local success, message = pcall(test, state)

  love.system.getOS = originalGetOS
  love.audio.getPlaybackDevices = originalGetPlaybackDevices
  love.audio.getPlaybackDevice = originalGetPlaybackDevice
  love.audio.setPlaybackDevice = originalSetPlaybackDevice
  system.meetsLoveVersionRequirement = originalMeetsLoveVersionRequirement
  SoundController.nextPlaybackDeviceCheck = originalNextCheck

  if not success then
    error(message, 0)
  end
end

local function testChangesToDefaultDevice()
  withMockPlaybackDevices(function(state)
    SoundController:updatePlaybackDevice()
    assert(state.currentDevice == "Headphones", "Audio should switch from speakers to the default headphones")
  end)
end

local function testOnlyChangesDeviceOnSupportedPlatforms()
  withMockPlaybackDevices(function(state)
    for osName, shouldSwitch in pairs({Windows = true, ["OS X"] = true, Linux = false, Android = false, iOS = false}) do
      state.os = osName
      state.currentDevice = "Speakers"
      SoundController.nextPlaybackDeviceCheck = nil
      SoundController:updatePlaybackDevice()
      local expectedDevice = shouldSwitch and "Headphones" or "Speakers"
      assert(state.currentDevice == expectedDevice, "Unexpected audio-device behavior on " .. osName)
    end
  end)
end

testChangesToDefaultDevice()
testOnlyChangesDeviceOnSupportedPlatforms()
