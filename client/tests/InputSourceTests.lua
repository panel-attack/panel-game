local InputSource = require("client.src.input.InputSource")
local Player = require("client.src.Player")
local inputManager = require("client.src.inputManager")
local logger = require("common.lib.logger")

local function createFakeInputs()
  return {isDown = {}, isPressed = {}, isUp = {}, isPressedWithRepeat = function() return false end}
end

local function testPlayerSourceReadsClaimedDevice()
  local player = Player("p1", -1, true)
  local device = createFakeInputs()
  player.inputConfiguration = device

  assert(player.inputSource:getInputs() == device, "a player's source should read the player's claimed device")
  logger.trace("passed test testPlayerSourceReadsClaimedDevice")
end

local function testPlayerSourceKeepsIdentityAcrossDeviceSwap()
  local player = Player("p1", -1, true)
  local source = player.inputSource
  player.inputConfiguration = createFakeInputs()
  local secondDevice = createFakeInputs()
  player.inputConfiguration = secondDevice

  assert(player.inputSource == source, "swapping devices should not replace the player's source")
  assert(source:getInputs() == secondDevice, "the source should read the newly claimed device")
  logger.trace("passed test testPlayerSourceKeepsIdentityAcrossDeviceSwap")
end

local function testPlayerSourceWithoutDeviceAsserts()
  local player = Player("p1", -1, true)

  assert(not pcall(player.inputSource.getInputs, player.inputSource), "a player's source without a claimed device should assert")
  logger.trace("passed test testPlayerSourceWithoutDeviceAsserts")
end

local function testAnyPlayerReadsInputManager()
  assert(InputSource.anyPlayer.player == nil, "the any-player source belongs to no player")
  assert(InputSource.anyPlayer:getInputs() == inputManager, "the any-player source should read the merged global input")
  logger.trace("passed test testAnyPlayerReadsInputManager")
end

testPlayerSourceReadsClaimedDevice()
testPlayerSourceKeepsIdentityAcrossDeviceSwap()
testPlayerSourceWithoutDeviceAsserts()
testAnyPlayerReadsInputManager()
