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
local directsFocus = require("client.src.ui.FocusDirector")

local HOLD_THRESHOLD = 0.25
local AUTO_CLOSE_DELAY = 0.25
local PLAYER_SLOT_SIZE = 150

-- Modal overlay that blocks game start until all local players have assigned input devices using hold-to-confirm interaction
---@class InputDeviceOverlay : UiElement
---@field players Player[] Reference to players that can reassign their input device with this overlay
---@field holdThreshold number Duration in seconds required to confirm assignment (default 0.25)
---@field active boolean True when overlay is open and processing input
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
---@field players Player[] Reference to players that may be eligible for reassigning their input device with this overlay
---@field holdThreshold number?
---@field onClose fun()?
---@field onCancel fun()? Callback when user presses back/cancel

---@class InputDeviceOverlay
---@operator call(InputDeviceOverlayOptions): InputDeviceOverlay
local InputDeviceOverlay = class(
---@param self InputDeviceOverlay
---@param options InputDeviceOverlayOptions
function(self, options)
  options = options or {}
  self.players = {}

  for _, player in ipairs(options.players) do
    if player.isLocal and player.human then
      self.players[#self.players+1] = player
    end
  end

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
---@return number? maxDuration Maximum hold duration across all checked keys
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
    text = "hold_button_device",
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
      text = "leave"
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

---@return Player[] localHumanPlayers Array of local human players
function InputDeviceOverlay:getLocalPlayers()
  return self.players
end

-- Gets the next player that needs device assignment
---@return Player? player Next unassigned player or nil if all assigned
function InputDeviceOverlay:getNextUnassignedPlayer()
  for _, player in ipairs(self:getLocalPlayers()) do
    if not player:hasInputConfiguration() then
      return player
    end
  end
  return nil
end

---@return PlayerInputDeviceSlot? slot Player slot under mouse cursor or nil
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
    local assignedInputConfig = player.inputConfiguration
    if assignedInputConfig then
      slot:setAssignedDevice(assignedInputConfig)
    end
  end
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
          local assignedInputConfig = player.inputConfiguration
          slot:setAssignedDevice(assignedInputConfig)
        end
      end
    end
  end
end




-- Assigns a device to a player and plays feedback
---@param inputConfig InputConfiguration Input configuration to assign
---@param targetPlayer Player? Player to assign to, or nil to assign to next unassigned player
function InputDeviceOverlay:assignDevice(inputConfig, targetPlayer)
  assert(inputConfig, "config is required")

  if not targetPlayer then
    targetPlayer = self:getNextUnassignedPlayer()
  end

  if not targetPlayer then
    return
  end

  if targetPlayer.inputConfiguration ~= inputConfig then
    targetPlayer:unrestrictInputs()
    targetPlayer:restrictInputs(inputConfig)
  end

  GAME.theme:playValidationSfx()
  self:updatePlayerSlots()

  -- Trigger pop animation on the slot that was just assigned
  for i, player in ipairs(self.players) do
    if player == targetPlayer and self.playerSlots[i] then
      self.playerSlots[i]:triggerPopAnimation()
      break
    end
  end

  if self:allPlayersAssigned() then
    self.autoCloseTimer = AUTO_CLOSE_DELAY
  end
end

---@return boolean # true if all players are assigned, false otherwise
function InputDeviceOverlay:allPlayersAssigned()
  for _, player in ipairs(self.players) do
    if not player:hasInputConfiguration() then
      return false
    end
  end

  return true
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
---@return boolean # True if mouse button 1 is held
function InputDeviceOverlay:isMouseHolding()
  local mousePressed = inputManager.mouse.isPressed[1]
  local mouseDown = inputManager.mouse.isDown[1]
  return (type(mousePressed) == "number" and mousePressed > 0) or type(mouseDown) == "number"
end

-- Checks if touch device is already assigned to any player
---@param touchConfig InputConfiguration Touch input configuration
---@return boolean # True if touch is already assigned
function InputDeviceOverlay:isTouchAlreadyAssigned(touchConfig)
  assert(touchConfig.deviceType == "touch", "Checked device is not a touch device")

  if touchConfig.claimed then
    for _, player in ipairs(self.players) do
      if touchConfig.player == player and player.inputConfiguration == touchConfig then
        return true
      end
    end
  end

  return false
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

  local state = self.deviceState[touchConfig.id]
  if not state then
    state = {confirmTriggered = false, holdTime = 0}
    self.deviceState[touchConfig.id] = state
  end

  state.holdTime = state.holdTime + dt
  self.escapeHoldTime = 0

  local progress = math.min(state.holdTime / self.holdThreshold, 1)
  self.touchTargetSlot:setHoldProgress(progress, "touch")

  if state.holdTime >= self.holdThreshold and not state.confirmTriggered then
    self:assignTouchToSlot(touchConfig, self.touchTargetSlot)
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

---@return InputConfiguration? touchInputConfig Touch input configuration or nil if not found
function InputDeviceOverlay:getTouchDescriptor()
  for _, config in ipairs(inputManager:getAssignableDevices()) do
    if config.deviceType == "touch" then
      return config
    end
  end
  return nil
end

-- Checks if any button is currently being pressed on any device
---@return boolean # True if any device has active input
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

  if #self.players == 0 then
    -- no local players
    return
  end

  if not self:allPlayersAssigned() then
    self:open()
  end
end

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

---@return boolean # True if overlay is currently active
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

---@return boolean? # True to block touch event propagation
function InputDeviceOverlay:onTouch()
  if self.active then
    return true
  end
end

---@return boolean? # True to block release event propagation
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
