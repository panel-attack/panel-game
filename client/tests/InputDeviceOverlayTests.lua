local InputDeviceOverlay = require("client.src.scenes.components.InputDeviceOverlay")
local Player = require("client.src.Player")
local consts = require("common.engine.consts")
local input = require("client.src.inputManager")

local ASSIGNED_KEY = "f9"
local UNASSIGNED_KEY = "f10"
-- the only key name each test configuration binds
local BOUND_KEY_NAME = "Swap1"

-- Runs test with input configuration 1 bound to ASSIGNED_KEY and claimed by a local player, configuration 2 bound to UNASSIGNED_KEY
-- and claimed by no one, and an overlay for that player, putting the configurations back afterwards
---@param test fun(overlay: InputDeviceOverlay, player: Player)
local function withOneAssignedPlayer(test)
  local configurations = {input.inputConfigurations[1], input.inputConfigurations[2]}
  local keys = {ASSIGNED_KEY, UNASSIGNED_KEY}
  local bindings = {}
  for i, configuration in ipairs(configurations) do
    bindings[i] = {}
    for _, keyName in ipairs(consts.KEY_NAMES) do
      bindings[i][keyName] = configuration[keyName]
      configuration[keyName] = nil
    end
    configuration[BOUND_KEY_NAME] = keys[i]
  end
  local player = Player("InputDeviceOverlayTests", -1, true)
  player.playerNumber = 1
  player:restrictInputs(configurations[1])
  local overlay = InputDeviceOverlay({players = {player}})

  local ok, err = pcall(test, overlay, player)

  overlay:close()
  player:unrestrictInputs()
  for _, key in ipairs(keys) do
    input:keyReleased(key)
  end
  input:update(consts.FRAME_RATE)
  input:update(consts.FRAME_RATE)
  for i, configuration in ipairs(configurations) do
    for _, keyName in ipairs(consts.KEY_NAMES) do
      configuration[keyName] = bindings[i][keyName]
    end
  end
  input:update(consts.FRAME_RATE)
  assert(ok, err)
end

---@param key string
local function pressKey(key)
  input:keyPressed(key)
  input:update(consts.FRAME_RATE)
end

local function aDeviceNoPlayerHasReopensTheOverlayWithTheAssignmentsReleased()
  withOneAssignedPlayer(function(overlay, player)
    overlay:openInputDeviceOverlayIfNeeded()
    assert(not overlay:isActive(), "every local player has a device, so there is nothing to pick")

    pressKey(UNASSIGNED_KEY)
    overlay:openIfUnassignedDeviceUsed()

    assert(overlay:isActive(), "a device no player has was used, so the devices are picked again")
    assert(not player:hasInputConfiguration(), "the assignments are released so the new device can take any slot")
  end)
end

aDeviceNoPlayerHasReopensTheOverlayWithTheAssignmentsReleased()

local function aPlayersOwnDeviceKeepsTheOverlayClosed()
  withOneAssignedPlayer(function(overlay, player)
    pressKey(ASSIGNED_KEY)
    overlay:openIfUnassignedDeviceUsed()

    assert(not overlay:isActive())
    assert(player.inputConfiguration == input.inputConfigurations[1])
  end)
end

aPlayersOwnDeviceKeepsTheOverlayClosed()

-- the puzzle menu lets any device navigate it, so a device no player has must not take the devices away there
local function aDeviceNoPlayerHasOnlyReopensTheOverlayWhenAsked()
  withOneAssignedPlayer(function(overlay, player)
    pressKey(UNASSIGNED_KEY)
    overlay:openInputDeviceOverlayIfNeeded()

    assert(not overlay:isActive())
    assert(player.inputConfiguration == input.inputConfigurations[1])
  end)
end

aDeviceNoPlayerHasOnlyReopensTheOverlayWhenAsked()
