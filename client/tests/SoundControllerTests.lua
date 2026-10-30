local SoundController = require("client.src.music.SoundController")
local system = require("client.src.system")

---@param test fun(state: {os: string, devices: string[], brokenDevice: string?, currentDevice: string, inMatch: boolean})
local function withMockPlaybackDevices(test)
  local originalGetOS = love.system.getOS
  local originalGetPlaybackDevices = love.audio.getPlaybackDevices
  local originalGetPlaybackDevice = love.audio.getPlaybackDevice
  local originalSetPlaybackDevice = love.audio.setPlaybackDevice
  local originalMeetsLoveVersionRequirement = system.meetsLoveVersionRequirement
  local originalNextCheck = SoundController.nextPlaybackDeviceCheck
  local ownHasOngoingMatch = rawget(GAME, "hasOngoingMatch")

  local state = {os = "Windows", devices = {"Headphones", "Speakers"}, currentDevice = "Speakers", inMatch = false}

  love.system.getOS = function()
    return state.os
  end
  system.meetsLoveVersionRequirement = function()
    return true
  end
  love.audio.getPlaybackDevices = function()
    return state.devices
  end
  love.audio.getPlaybackDevice = function()
    return state.currentDevice
  end
  love.audio.setPlaybackDevice = function(device)
    if device == state.brokenDevice then
      return false, "cannot open"
    end
    state.currentDevice = device
    return true
  end
  SoundController.nextPlaybackDeviceCheck = nil
  GAME.hasOngoingMatch = function()
    return state.inMatch
  end

  local success, message = pcall(test, state)

  love.system.getOS = originalGetOS
  love.audio.getPlaybackDevices = originalGetPlaybackDevices
  love.audio.getPlaybackDevice = originalGetPlaybackDevice
  love.audio.setPlaybackDevice = originalSetPlaybackDevice
  system.meetsLoveVersionRequirement = originalMeetsLoveVersionRequirement
  SoundController.nextPlaybackDeviceCheck = originalNextCheck
  GAME.hasOngoingMatch = ownHasOngoingMatch

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

local function testSkipsADefaultDeviceThatFailsToOpen()
  withMockPlaybackDevices(function(state)
    state.devices = {"Headphones", "Monitor", "Speakers"}
    state.brokenDevice = "Headphones"
    SoundController:followDefaultPlaybackDevice()
    assert(state.currentDevice == "Monitor", "Audio should switch to the first listed device that opens")
  end)
end

local function testDoesNotCheckDuringAMatch()
  withMockPlaybackDevices(function(state)
    state.inMatch = true
    SoundController:updatePlaybackDevice()
    assert(state.currentDevice == "Speakers", "Enumerating devices costs frame time, so a match should not check")
  end)
end

local function testFollowingTheDefaultWorksDuringAMatch()
  withMockPlaybackDevices(function(state)
    state.inMatch = true
    SoundController:followDefaultPlaybackDevice()
    assert(state.currentDevice == "Headphones", "Regaining focus mid-match should still switch to the default")
  end)
end

local function testLinuxKeepsNativeAudioRouting()
  withMockPlaybackDevices(function(state)
    state.os = "Linux"
    love.audio.getPlaybackDevice = function()
      error("Linux should not query the playback device")
    end
    love.audio.getPlaybackDevices = function()
      error("Linux should not enumerate playback devices")
    end
    SoundController:updatePlaybackDevice()
    SoundController:followDefaultPlaybackDevice()
    assert(state.currentDevice == "Speakers", "Periodic and focus checks should leave Linux audio routing unchanged")
  end)
end

testChangesToDefaultDevice()
testSkipsADefaultDeviceThatFailsToOpen()
testDoesNotCheckDuringAMatch()
testFollowingTheDefaultWorksDuringAMatch()
testLinuxKeepsNativeAudioRouting()
