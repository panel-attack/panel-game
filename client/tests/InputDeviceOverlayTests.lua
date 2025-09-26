local InputDeviceOverlay = require("client.src.scenes.components.InputDeviceOverlay")
local inputManager = require("client.src.inputManager")

local function noop() end

local function setUpThemeStubs()
  local original = GAME.theme
  if not original then
    GAME.theme = {playValidationSfx = noop, playCancelSfx = noop}
    return function() end
  end

  local prevValidation = original.playValidationSfx
  local prevCancel = original.playCancelSfx
  original.playValidationSfx = noop
  original.playCancelSfx = noop

  return function()
    original.playValidationSfx = prevValidation
    original.playCancelSfx = prevCancel
  end
end

local function createTestBattleRoom(player, keyboardConfig, touchConfig)
  local battleRoom = {
    players = {player},
    lastClaim = nil,
  }

  function battleRoom:getLocalHumanPlayers()
    return {player}
  end

  function battleRoom:isPlayerAssigned(target)
    return target.inputConfiguration ~= nil
  end

  function battleRoom:areLocalPlayersAssigned()
    return player.inputConfiguration ~= nil
  end

  function battleRoom:claimDeviceForPlayer(target, device)
    device.player = target
    target.inputConfiguration = device
    target.settings.inputMethod = (device == touchConfig) and "touch" or "controller"
    self.lastClaim = {player = target, device = device}
    return true
  end

  function battleRoom:getPlayerAssignedToDevice(device)
    if player.inputConfiguration == device then
      return player
    end
    return nil
  end

  function battleRoom:clearPlayerAssignment(target)
    if target.inputConfiguration then
      target.inputConfiguration.player = nil
    end
    target.inputConfiguration = nil
    target.settings.inputMethod = "controller"
  end

  return battleRoom
end

local function createOverlayUnderTest()
  local player = {
    playerNumber = 1,
    settings = {inputMethod = "controller"},
    inputConfiguration = nil,
  }

  local keyboardConfig = {
    isPressed = {},
    isDown = {},
    isUp = {},
    claimed = false,
    player = nil,
  }

  local touchConfig = {
    isPressed = {},
    isDown = {},
    isUp = {},
    claimed = false,
    player = nil,
  }

  local battleRoom = createTestBattleRoom(player, keyboardConfig, touchConfig)
  local overlay = InputDeviceOverlay({battleRoom = battleRoom})

  overlay.deviceDescriptors = {
    {id = "config_1", type = "keyboard", label = "Keyboard", config = keyboardConfig},
    {id = "touch", type = "touch", label = "Touch", config = touchConfig},
  }

  overlay.deviceButtons = {}
  overlay.touchDescriptor = overlay.deviceDescriptors[2]
  overlay.touchButton = {
    width = 100,
    height = 100,
    getScreenPos = function()
      return 0, 0
    end
  }

  overlay.updatePlayerSlots = noop
  overlay.updateDeviceButtons = noop

  return overlay, battleRoom, player, keyboardConfig, touchConfig
end

local function testAssignDeviceFromPressedDuration()
  local restoreTheme = setUpThemeStubs()
  local overlay, battleRoom, player, keyboardConfig = createOverlayUnderTest()

  keyboardConfig.isPressed["Swap1"] = 1.25
  overlay:processConfigHold(overlay.deviceDescriptors[1], 0)

  assert(battleRoom.lastClaim ~= nil, "Expected device claim to be recorded")
  assert(battleRoom.lastClaim.device == keyboardConfig, "Expected keyboard configuration to be claimed")
  assert(player.inputConfiguration == keyboardConfig, "Player should reference assigned configuration")
  restoreTheme()
end

local function testAssignDeviceByAccumulatedHold()
  local restoreTheme = setUpThemeStubs()
  local overlay, battleRoom, player, keyboardConfig = createOverlayUnderTest()

  keyboardConfig.isPressed["Swap1"] = 2 -- simulate key held
  overlay:processConfigHold(overlay.deviceDescriptors[1], 0.6)
  overlay:processConfigHold(overlay.deviceDescriptors[1], 0.5)

  assert(battleRoom.lastClaim and battleRoom.lastClaim.device == keyboardConfig, "Hold accumulation should trigger claim")
  assert(player.inputConfiguration == keyboardConfig, "Player should be assigned after accumulated hold")
  restoreTheme()
end

local function testCancelReleasesAssignment()
  local restoreTheme = setUpThemeStubs()
  local overlay, battleRoom, player, keyboardConfig = createOverlayUnderTest()

  keyboardConfig.isPressed["Swap1"] = 1.2
  overlay:processConfigHold(overlay.deviceDescriptors[1], 0)
  assert(player.inputConfiguration == keyboardConfig, "Setup failed to assign config before cancel test")

  keyboardConfig.isPressed["Swap2"] = 1.1
  overlay:processConfigHold(overlay.deviceDescriptors[1], 0)

  assert(player.inputConfiguration == nil, "Cancel hold should clear player assignment")
  restoreTheme()
end

local function testTouchHoldAssigns()
  local restoreTheme = setUpThemeStubs()
  local overlay, battleRoom, player, _, touchConfig = createOverlayUnderTest()

  inputManager.mouse.x = 10
  inputManager.mouse.y = 10
  inputManager.mouse.isPressed[1] = overlay.holdThreshold

  overlay:updateTouchHold(0)

  assert(battleRoom.lastClaim and battleRoom.lastClaim.device == touchConfig, "Touch hold should assign touch config")
  assert(player.inputConfiguration == touchConfig, "Player should receive touch configuration")
  inputManager.mouse.isPressed[1] = nil
  restoreTheme()
end

local function testIconRenderingSystem()
  local restoreTheme = setUpThemeStubs()
  local overlay, battleRoom, player, keyboardConfig = createOverlayUnderTest()

  -- Mock GAME.theme with input prompt icons
  if not GAME.theme then
    GAME.theme = {}
  end
  GAME.theme.getInputPromptIcon = function(self, deviceType)
    -- Return a mock texture-like object
    return {
      getWidth = function() return 32 end,
      getHeight = function() return 32 end
    }
  end

  overlay:open()
  keyboardConfig.isPressed["Swap1"] = 1.25
  overlay:processConfigHold(overlay.deviceDescriptors[1], 0)

  -- Verify device icons are created and properly configured
  local playerSlot = overlay.playerSlots[1]
  assert(playerSlot.deviceIcon ~= nil, "Device icon should be created")
  assert(playerSlot.pendingDeviceType == "keyboard", "Pending device type should be keyboard")

  restoreTheme()
end

local function testOverlayConsumesTouches()
  local overlay = select(1, createOverlayUnderTest())
  overlay.active = true
  assert(overlay:onTouch(), "Overlay should consume touches while active")
  assert(overlay:onRelease(), "Overlay should consume releases while active")
end

local function test(func)
  func()
end

test(testAssignDeviceFromPressedDuration)
test(testAssignDeviceByAccumulatedHold)
test(testCancelReleasesAssignment)
test(testTouchHoldAssigns)
test(testIconRenderingSystem)
test(testOverlayConsumesTouches)
