local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local UiElement = require("client.src.ui.UIElement")
local Label = require("client.src.ui.Label")
local TextButton = require("client.src.ui.TextButton")
local StackPanel = require("client.src.ui.StackPanel")
local PlayerInputDeviceSlot = require("client.src.scenes.components.PlayerInputDeviceSlot")
local inputManager = require("client.src.inputManager")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local consts = require("common.engine.consts")
local logger = require("common.lib.logger")
local Scene = require("client.src.scenes.Scene")
local directsFocus = require("client.src.ui.FocusDirector")

local HOLD_THRESHOLD = 0.25
local AUTO_CLOSE_DELAY = 0.25
local PLAYER_SLOT_SIZE = 150

-- Modal overlay that blocks game start until all local players have assigned input devices using hold-to-confirm interaction
---@class InputDeviceOverlay : UiElement
---@field battleRoom BattleRoom Reference to battle room for player/device management
---@field holdThreshold number Duration in seconds required to confirm assignment (default 0.25)
---@field active boolean True when overlay is open and processing input
---@field hasFocus boolean True when overlay has keyboard/input focus (managed by FocusDirector)
---@field playerSlots PlayerInputDeviceSlot[] Array of player slot UI elements
---@field deviceState table<string, {confirmTriggered:boolean, holdTime:number}> Tracks hold state per device
---@field touchTargetSlot PlayerInputDeviceSlot? Slot where touch started (locked for duration of touch)
---@field autoCloseTimer number Timer for auto-closing after all assignments complete
---@field escapeHoldTime number Duration escape key has been held
---@field onClose fun()? Callback invoked when overlay closes
---@field onCancel fun()? Callback invoked when user cancels overlay
---@field titleLabel Label Title text element
---@field subtitleLabel Label Subtitle text element
---@field slotsContainer StackPanel Container for player slots
---@field backButton TextButton Button to exit input configuration
---@field cancelHintLabel Label Hint text for escape key to cancel

---@class InputDeviceOverlayOptions
---@field battleRoom BattleRoom
---@field holdThreshold number?
---@field onClose fun()?
---@field onCancel fun()? Callback when user presses back/cancel

---@param options InputDeviceOverlayOptions
local InputDeviceOverlay = class(function(self, options)
  options = options or {}
  self.battleRoom = options.battleRoom
  self.holdThreshold = options.holdThreshold or HOLD_THRESHOLD
  self.onClose = options.onClose
  self.onCancel = options.onCancel

  self.active = false
  self.playerSlots = {}
  self.deviceState = {}
  self.touchTargetSlot = nil
  self.autoCloseTimer = 0
  self.escapeHoldTime = 0
  self.width = consts.CANVAS_WIDTH
  self.height = consts.CANVAS_HEIGHT
  self:setVisibility(false)

  directsFocus(self)
  self:buildUi()
end, UiElement, "InputDeviceOverlay")

---@param config InputConfiguration Input configuration object
---@return number? Maximum hold duration across all checked keys
local function getHoldDurationForInputConfiguration(config)
  local maxDuration = 0

  for _, alias in ipairs(consts.KEY_NAMES) do
    local duration = config.isPressed[alias]
    if duration and duration > maxDuration then
      maxDuration = duration
    end
  end

  return maxDuration
end


-- Builds the main UI elements for the overlay
function InputDeviceOverlay:buildUi()
  -- Title
  self.titleLabel = Label({
    text = "press_button_device",
    hAlign = "center",
    vAlign = "top",
    y = 60,
    fontSize = GraphicsUtil.fontSize + 4
  })
  self:addChild(self.titleLabel)

  -- Subtitle
  self.subtitleLabel = Label({
    text = "or_touch_player_slot",
    hAlign = "center",
    vAlign = "top",
    y = 100,
    fontSize = GraphicsUtil.fontSize
  })
  self:addChild(self.subtitleLabel)

  -- Player slots container
  self.slotsContainer = StackPanel({
    alignment = "left",
    hAlign = "center",
    vAlign = "center",
    height = PLAYER_SLOT_SIZE
  })
  self:addChild(self.slotsContainer)

  self.backButton = TextButton({
    label = Label({
      text = "back"
    }),
    hAlign = "center",
    vAlign = "bottom",
    y = -10,
    onClick = function()
      self:onBackPressed()
    end
  })
  self:addChild(self.backButton)
end

---@return Player[] Array of local human players
function InputDeviceOverlay:getLocalPlayers()
  assert(self.battleRoom, "InputDeviceOverlay requires a battleRoom reference")
  return self.battleRoom:getLocalHumanPlayers()
end

-- Gets the next player that needs device assignment
---@return Player? Next unassigned player or nil if all assigned
function InputDeviceOverlay:getNextUnassignedPlayer()
  for _, player in ipairs(self:getLocalPlayers()) do
    if not self.battleRoom:isPlayerAssigned(player) then
      return player
    end
  end
  return nil
end

---@return PlayerInputDeviceSlot? Player slot under mouse cursor or nil
function InputDeviceOverlay:getPlayerSlotForTouch()
  for _, slot in ipairs(self.playerSlots) do
    if slot:isMouseOver() then
      return slot
    end
  end
  return nil
end

function InputDeviceOverlay:buildPlayerSlots()
  self.playerSlots = {}
  while #self.slotsContainer.children > 0 do
    self.slotsContainer:remove(self.slotsContainer.children[1])
  end

  local players = self:getLocalPlayers()
  for i, player in ipairs(players) do
    local slot = PlayerInputDeviceSlot({playerNumber = i, parentOverlay = self})
    self.playerSlots[i] = slot
    self.slotsContainer:addElement(slot)

    -- Add spacing after each slot except the last
    if i < #players then
      local spacer = UiElement({
        width = 20,
        height = PLAYER_SLOT_SIZE
      })
      self.slotsContainer:addElement(spacer)
    end

    -- Check if player is already assigned
    local assignedDevice = self:getAssignedDeviceForPlayer(player)
    if assignedDevice then
      slot:setAssignedDevice(assignedDevice)
    end
  end
end

---@param player Player
---@return InputConfiguration? Input configuration if player is assigned, nil otherwise
function InputDeviceOverlay:getAssignedDeviceForPlayer(player)
  if not self.battleRoom or not player then
    return nil
  end

  for _, config in ipairs(inputManager:getAssignableDevices()) do
    if config then
      local assignedPlayer = self.battleRoom:getPlayerAssignedToDevice(config)
      if assignedPlayer == player then
        return config
      end
    end
  end
  return nil
end

function InputDeviceOverlay:updatePlayerSlots()
  if not self.playerSlots then
    return
  end

  for i, slot in ipairs(self.playerSlots) do
    if slot and slot.setAssignedDevice then
      local players = self:getLocalPlayers()
      if players then
        local player = players[i]
        if player then
          local assignedDevice = self:getAssignedDeviceForPlayer(player)
          slot:setAssignedDevice(assignedDevice)
        end
      end
    end
  end
end




-- Assigns a device to a player and plays feedback
---@param config InputConfiguration Input configuration to assign
---@param targetPlayer Player? Player to assign to, or nil to assign to next unassigned player
function InputDeviceOverlay:assignDevice(config, targetPlayer)
  assert(config, "config is required")
  assert(self.battleRoom, "InputDeviceOverlay requires a battleRoom reference")

  if not targetPlayer then
    targetPlayer = self:getNextUnassignedPlayer()
  end

  if not targetPlayer then
    return
  end

  local success = self.battleRoom:claimDeviceForPlayer(targetPlayer, config)
  if success then
    if GAME.theme and GAME.theme.playValidationSfx then
      GAME.theme:playValidationSfx()
    end
    self:updatePlayerSlots()

    -- Trigger pop animation on the slot that was just assigned
    local players = self:getLocalPlayers()
    for i, player in ipairs(players) do
      if player == targetPlayer and self.playerSlots[i] then
        self.playerSlots[i]:triggerPopAnimation()
        break
      end
    end

    if self.battleRoom:areLocalPlayersAssigned() then
      self.autoCloseTimer = AUTO_CLOSE_DELAY
    end
  end
end

-- Processes hold input for a configuration device
---@param config InputConfiguration Input configuration for controller/keyboard
---@param dt number Delta time in seconds
function InputDeviceOverlay:processConfigHold(config, dt)
  assert(config, "Config is required")
  assert(type(dt) == "number", "dt must be numeric")

  if config.claimed == true then
    return
  end

  local state = self.deviceState[config.id]
  if not state then
    state = {confirmTriggered = false, holdTime = 0}
    self.deviceState[config.id] = state
  end

  local confirmDuration = getHoldDurationForInputConfiguration(config)
  if confirmDuration and confirmDuration > 0 then
    state.holdTime = confirmDuration
  else
    state.holdTime = 0
  end

  -- Update visual feedback on all slots
  local progress = math.min(state.holdTime / self.holdThreshold, 1)
  for i, slot in ipairs(self.playerSlots) do
    if not slot.assignedDevice and progress > 0 then
      self.escapeHoldTime = 0
      slot:setHoldProgress(progress, config.deviceType)
      break
    end
  end

  if state.holdTime >= self.holdThreshold and not state.confirmTriggered then
    self:assignDevice(config)
    state.confirmTriggered = true
  elseif state.holdTime < self.holdThreshold then
    state.confirmTriggered = false
  end
end


-- Updates touch hold state and visual feedback
---@param dt number Delta time in seconds
function InputDeviceOverlay:updateTouchHold(dt)
  local touchDescriptor = self:getTouchDescriptor()
  if not touchDescriptor then
    return
  end

  local holding = self:isMouseHolding()
  if holding then
    self:processTouchHold(dt, touchDescriptor)
  else
    self:clearTouchTarget()
  end
end

-- Checks if mouse is currently being held down
---@return boolean True if mouse button 1 is held
function InputDeviceOverlay:isMouseHolding()
  local mousePressed = inputManager.mouse.isPressed[1]
  local mouseDown = inputManager.mouse.isDown[1]
  return (type(mousePressed) == "number" and mousePressed > 0) or type(mouseDown) == "number"
end

-- Checks if touch device is already assigned to any player
---@param touchConfig InputConfiguration Touch input configuration
---@return boolean True if touch is already assigned
function InputDeviceOverlay:isTouchAlreadyAssigned(touchConfig)
  if not self.battleRoom then
    return false
  end

  local assignedPlayer = self.battleRoom:getPlayerAssignedToDevice(touchConfig)
  return assignedPlayer ~= nil
end

-- Processes touch hold logic when mouse is held down
---@param dt number Delta time in seconds
---@param touchConfig InputConfiguration Touch input configuration
function InputDeviceOverlay:processTouchHold(dt, touchConfig)
  -- Don't allow claiming another slot if touch is already assigned
  if self:isTouchAlreadyAssigned(touchConfig) then
    self:clearTouchTarget()
    return
  end

  -- Lock to initial slot where touch started
  if not self.touchTargetSlot then
    local slotUnderMouse = self:getPlayerSlotForTouch()
    if not slotUnderMouse then
      self:clearTouchTarget()
      return
    end
    self.touchTargetSlot = slotUnderMouse
    self.touchTargetSlot:setTouchTarget(true)
  end

  local targetSlot = self.touchTargetSlot

  local state = self.deviceState[touchConfig.id]
  if not state then
    state = {confirmTriggered = false, holdTime = 0}
    self.deviceState[touchConfig.id] = state
  end

  state.holdTime = state.holdTime + dt
  self.escapeHoldTime = 0

  local progress = math.min(state.holdTime / self.holdThreshold, 1)
  targetSlot:setHoldProgress(progress, "touch")

  if state.holdTime >= self.holdThreshold and not state.confirmTriggered then
    self:assignTouchToSlot(touchConfig, targetSlot)
    state.confirmTriggered = true
  elseif state.holdTime < self.holdThreshold then
    state.confirmTriggered = false
  end
end



-- Assigns touch device to specific slot
---@param touchConfig InputConfiguration Touch input configuration
---@param targetSlot PlayerInputDeviceSlot Slot to assign touch to
function InputDeviceOverlay:assignTouchToSlot(touchConfig, targetSlot)
  local players = self:getLocalPlayers()
  for i, slot in ipairs(self.playerSlots) do
    if slot == targetSlot then
      local targetPlayer = players[i]
      if targetPlayer then
        self:assignDevice(touchConfig, targetPlayer)
      end
      break
    end
  end
end

function InputDeviceOverlay:clearTouchTarget()
  if self.touchTargetSlot then
    self.touchTargetSlot:setTouchTarget(false)
    self.touchTargetSlot:setHoldProgress(0, nil)
    self.touchTargetSlot = nil
  end
  -- Clear touch device state
  local touchConfig = self:getTouchDescriptor()
  if touchConfig then
    local state = self.deviceState[touchConfig.id]
    if state then
      state.holdTime = 0
      state.confirmTriggered = false
    end
  end
end

---@return InputConfiguration? Touch input configuration or nil if not found
function InputDeviceOverlay:getTouchDescriptor()
  for _, config in ipairs(inputManager:getAssignableDevices()) do
    if config.deviceType == "touch" then
      return config
    end
  end
  return nil
end

-- Checks if any button is currently being pressed on any device
---@return boolean True if any device has active input
function InputDeviceOverlay:isAnyButtonCurrentlyPressed()
  -- Check if mouse is being held (for touch)
  if self:isMouseHolding() then
    return true
  end

  if tableUtils.length(inputManager.allKeys.isPressed) > 0 then
    return true
  end

  return false
end

---@param dt number Delta time in seconds
function InputDeviceOverlay:updateSelf(dt)
  if not self.active then
    if not self.battleRoom.spectating and GAME.input:checkForUnassignedConfigurationInputs(self.battleRoom:getLocalHumanPlayers()) then
      self.battleRoom:releaseAllLocalAssignments()
    end

    self:openInputDeviceOverlayIfNeeded()

    return
  end

  for _, slot in ipairs(self.playerSlots) do
    if not slot.assignedDevice then
      slot:setHoldProgress(0, nil)
    end
  end

  for _, config in ipairs(inputManager:getAssignableDevices()) do
    if config.deviceType ~= "touch" then
      self:processConfigHold(config, dt)
    end
  end

  self:updateTouchHold(dt)

  self:receiveInputs(GAME.input, dt)

  -- Handle auto-close timer
  if self.autoCloseTimer > 0 and not self:isAnyButtonCurrentlyPressed() then
    self.autoCloseTimer = self.autoCloseTimer - dt
    if self.autoCloseTimer <= 0 then
      self:close()
    end
  end
end

function InputDeviceOverlay:openInputDeviceOverlayIfNeeded()
  if self.active then
    return
  end

  local hasLocalPlayers = #self.battleRoom:getLocalHumanPlayers() > 0
  if not hasLocalPlayers then
    return
  end

  if not self.battleRoom.hasShutdown and not self.battleRoom:areLocalPlayersAssigned() then
    self:open()
  end
end

-- Intentional override
---@diagnostic disable-next-line: duplicate-set-field
function InputDeviceOverlay:drawSelf()
  if not self.active then
    return
  end

  local bgColor = GAME.theme.colors.darkTransparentBackgroundColor
  GraphicsUtil.setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
  GraphicsUtil.drawRectangle("fill", 0, 0, self.width, self.height)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

function InputDeviceOverlay:open()
  assert(self.battleRoom, "InputDeviceOverlay requires a battleRoom reference")

  self.deviceState = {}
  self.touchTargetSlot = nil
  self.autoCloseTimer = 0
  self.active = true
  self:setVisibility(true)

  self:buildPlayerSlots()
end

function InputDeviceOverlay:close()
  if not self.active then
    return
  end

  self.active = false
  self:setVisibility(false)
  self:clearTouchTarget()
  self.autoCloseTimer = 0
  self:setFocus(nil)

  if self.onClose then
    self.onClose()
  end
end

---@return boolean True if overlay is currently active
function InputDeviceOverlay:isActive()
  return self.active
end

-- Handles back button press - closes overlay and invokes cancel callback
function InputDeviceOverlay:onBackPressed()
  GAME.theme:playCancelSfx()
  self:close()
  if self.onCancel then
    self.onCancel()
  end
end

---@return boolean? True to block touch event propagation
function InputDeviceOverlay:onTouch()
  if self.active then
    return true
  end
end

---@return boolean? True to block release event propagation
function InputDeviceOverlay:onRelease()
  if self.active then
    return true
  end
end

function InputDeviceOverlay:receiveInputs(input, dt)

  if input.isDown["MenuEsc"] then
    self.escapeHoldTime = self.escapeHoldTime + dt
  elseif input.isPressed["MenuEsc"] and self.escapeHoldTime > 0 then
    self.escapeHoldTime = self.escapeHoldTime + dt
    if self.escapeHoldTime >= self.holdThreshold then
      self:onBackPressed()
      self.escapeHoldTime = 0
    end
  else
    self.escapeHoldTime = 0
  end
end

return InputDeviceOverlay
