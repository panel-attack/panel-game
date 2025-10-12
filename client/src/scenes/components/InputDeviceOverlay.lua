local class = require("common.lib.class")
local UiElement = require("client.src.ui.UIElement")
local Label = require("client.src.ui.Label")
local StackPanel = require("client.src.ui.StackPanel")
local ImageContainer = require("client.src.ui.ImageContainer")
local InputDeviceUtils = require("client.src.input.InputDeviceUtils")
local inputManager = require("client.src.inputManager")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local InputPromptRenderer = require("client.src.graphics.InputPromptRenderer")
local consts = require("common.engine.consts")
local logger = require("common.lib.logger")

local HOLD_THRESHOLD = 0.25
local ALL_INPUT_KEYS = consts.KEY_NAMES
local AUTO_CLOSE_DELAY = 0.25
local PLAYER_SLOT_SIZE = 150
local DEVICE_ICON_SIZE = 64


-- Visual UI element representing one player's input device assignment status
---@class PlayerSlot : UiElement
---@field playerNumber number Visual player index (1, 2, etc.)
---@field assignedDevice table? Device descriptor if assigned, nil otherwise
---@field holdProgress number Current hold progress from 0-1
---@field pendingDeviceType string? Device type being held during assignment (keyboard/controller/touch)
---@field playerImage ImageContainer? Player number icon from theme
---@field deviceIcon UiElement? Device icon showing keyboard/controller/touch type
---@field isTargetedForTouch boolean True when mouse is hovering over this slot for touch assignment
---@field parentOverlay InputDeviceOverlay? Reference to parent overlay for accessing device descriptors

---@param options {playerNumber: number, parentOverlay: InputDeviceOverlay}
local PlayerSlot = class(function(self, options)
  local playerNumber = options.playerNumber or options
  self.playerNumber = playerNumber
  self.assignedDevice = nil
  self.holdProgress = 0
  self.pendingDeviceType = nil
  self.isTargetedForTouch = false
  self.parentOverlay = options.parentOverlay

  -- Set size after parent initialization
  self.width = PLAYER_SLOT_SIZE
  self.height = PLAYER_SLOT_SIZE

  self:createPlayerNumberImage()
end, UiElement)

function PlayerSlot:drawSelf()
    self:drawSlotBackground(self)
    self:drawSlotBorder(self)
end

-- Draws slot background with progress-based color transitions
---@param slot PlayerSlot
function PlayerSlot:drawSlotBackground(slot)
  local progress = self.holdProgress or 0
  local bgColor = self:getBackgroundColor(progress)
  GraphicsUtil.setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
  GraphicsUtil.drawRectangle("fill", self.x, self.y, slot.width, slot.height)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

-- Draws slot border with progress-based color transitions
---@param slot PlayerSlot
function PlayerSlot:drawSlotBorder(slot)
  local progress = self.holdProgress or 0
  local borderColor = self:getBorderColor(progress)
  GraphicsUtil.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
  GraphicsUtil.drawRectangle("line", self.x, self.y, slot.width, slot.height)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

-- Gets background color based on assignment and progress
---@param progress number Hold progress from 0-1
---@return table Color array {r, g, b, a}
function PlayerSlot:getBackgroundColor(progress)
  if self.assignedDevice then
    return {0.2, 0.3, 0.4, 0.9}  -- Assigned: grey-blue background
  else
    local greyToBlue = progress * 0.3  -- How much blue to add
    return {0.2, 0.2 + greyToBlue, 0.2 + greyToBlue * 2, 0.8}
  end
end

-- Gets border color based on assignment and progress
---@param progress number Hold progress from 0-1
---@return table Color array {r, g, b, a}
function PlayerSlot:getBorderColor(progress)
  if self.assignedDevice then
    return {0.3, 0.4, 0.5, 1}  -- Assigned: grey-blue border
  else
    local greyToBlue = progress * 0.5  -- How much blue to add to border
    return {0.4, 0.4 + greyToBlue, 0.4 + greyToBlue * 1.5, 1}
  end
end

-- Creates the player number image from theme
function PlayerSlot:createPlayerNumberImage()
  local playerIcon = GAME.theme:getPlayerNumberIcon(self.playerNumber)
  assert(playerIcon, string.format("Missing player %d icon in current theme", self.playerNumber))

  self.playerImage = ImageContainer({
    image = playerIcon,
    hAlign = "center",
    vAlign = "top",
    y = 14,
    scale = 2
  })
  self:addChild(self.playerImage)
end

-- Sets the assigned device for this player slot
---@param device table? Device descriptor or nil
function PlayerSlot:setAssignedDevice(device)
  self.assignedDevice = device
end

-- Updates the device icon based on current assignment or hold progress
function PlayerSlot:updateDeviceIcon()
  if self.deviceIcon then
    self.deviceIcon:detach()
    self.deviceIcon = nil
  end

  -- Show icon for assigned device OR pending device during hold
  local deviceType = nil
  if self.assignedDevice and self.assignedDevice.type then
    deviceType = self.assignedDevice.type
  elseif self.pendingDeviceType and self.holdProgress > 0 then
    deviceType = self.pendingDeviceType
  end

  if deviceType then
    local iconElement = UiElement({
      width = DEVICE_ICON_SIZE,
      height = DEVICE_ICON_SIZE,
      hAlign = "center",
      vAlign = "center"
    })

    -- Intentional override
    ---@diagnostic disable-next-line: duplicate-set-field
    iconElement.drawSelf = function(icon)
      -- Device icon transitions from grey to blue based on progress
      local progress = self.holdProgress or 0
      local alpha
      if self.assignedDevice then
        -- Assigned device: full opacity
        alpha = 1
      else
        -- Pending device: grey to blue transition (fade in)
        alpha = 0.4 + progress * 0.6
      end

      local centerX = icon.width / 2
      local centerY = icon.height / 2

      -- Get pre-calculated controller image variant and device number from descriptor
      local controllerImageVariant = nil
      local deviceNumber = nil

      if self.assignedDevice then
        -- Use pre-calculated values from assigned device descriptor
        controllerImageVariant = self.assignedDevice.controllerImageVariant
        deviceNumber = self.assignedDevice.deviceNumber
      elseif self.pendingDeviceType and self.parentOverlay then
        -- For pending devices, find the descriptor being held to show specific controller icon
        for _, descriptor in ipairs(self.parentOverlay.deviceDescriptors) do
          if descriptor.type == self.pendingDeviceType then
            local state = self.parentOverlay.deviceState[descriptor.id]
            if state and state.holdTime > 0 then
              controllerImageVariant = descriptor.controllerImageVariant
              deviceNumber = descriptor.deviceNumber
              break
            end
          end
        end
      end

      -- Render the device icon with number if applicable
      InputPromptRenderer.renderIconWithNumber(deviceType, centerX, centerY, DEVICE_ICON_SIZE, alpha, controllerImageVariant, deviceNumber)
    end

    self.deviceIcon = iconElement
    self:addChild(iconElement)
  end
end

-- Sets hold progress and pending device type for visual feedback
---@param progress number Hold progress from 0-1
---@param pendingDeviceType string? Device type being held (keyboard/controller/touch)
function PlayerSlot:setHoldProgress(progress, pendingDeviceType)
  self.holdProgress = math.max(0, math.min(1, progress))
  self.pendingDeviceType = pendingDeviceType
end

---@param isTarget boolean True when mouse is hovering over this slot
function PlayerSlot:setTouchTarget(isTarget)
  self.isTargetedForTouch = isTarget
end

---@param dt number Delta time in seconds
function PlayerSlot:updateSelf(dt)
  -- Update device icon if needed during each frame
  self:updateDeviceIcon()
end

-- Checks if mouse cursor is over this player slot
---@return boolean True if mouse is over this slot
function PlayerSlot:isMouseOver()
  local mx, my = inputManager.mouse.x, inputManager.mouse.y
  local x, y = self:getScreenPos()
  return mx >= x and mx <= x + self.width and my >= y and my <= y + self.height
end

-- Modal overlay that blocks game start until all local players have assigned input devices using hold-to-confirm interaction
---@class InputDeviceOverlay : UiElement
---@field battleRoom BattleRoom Reference to battle room for player/device management
---@field holdThreshold number Duration in seconds required to confirm assignment (default 0.25)
---@field active boolean True when overlay is open and processing input
---@field playerSlots PlayerSlot[] Array of player slot UI elements
---@field deviceDescriptors table[] Array of device metadata from InputDeviceUtils
---@field deviceState table<string, {confirmTriggered:boolean, holdTime:number}> Tracks hold state per device
---@field touchTargetSlot PlayerSlot? Current slot being targeted for touch assignment
---@field autoCloseTimer number Timer for auto-closing after all assignments complete
---@field onClose fun()? Callback invoked when overlay closes
---@field titleLabel Label Title text element
---@field subtitleLabel Label Subtitle text element
---@field slotsContainer StackPanel Container for player slots

---@class InputDeviceOverlayOptions
---@field battleRoom BattleRoom
---@field holdThreshold number?
---@field onClose fun()?

---@param options InputDeviceOverlayOptions
local InputDeviceOverlay = class(function(self, options)
  options = options or {}
  self.battleRoom = options.battleRoom
  self.holdThreshold = options.holdThreshold or HOLD_THRESHOLD
  self.onClose = options.onClose

  self.active = false
  self.playerSlots = {}
  self.deviceDescriptors = {}
  self.deviceState = {}
  self.touchTargetSlot = nil
  self.autoCloseTimer = 0
  self.width = consts.CANVAS_WIDTH
  self.height = consts.CANVAS_HEIGHT
  self:setVisibility(false)

  self:buildUi()
end, UiElement)

---@param descriptor table Device descriptor
---@param keyAliases string[] Array of key aliases to check
---@return number? Maximum hold duration across all checked keys
local function getHoldDurationForDescriptor(descriptor, keyAliases)
  local device = descriptor.config
  local maxDuration

  if device and device.isPressed then
    for _, alias in ipairs(keyAliases) do
      local duration = device.isPressed[alias]
      if type(duration) == "number" and duration > (maxDuration or 0) then
        maxDuration = duration
      end
    end
  end

  if descriptor.config then
    for _, alias in ipairs(keyAliases) do
      local key = descriptor.config[alias]
      if key then
        local duration = inputManager.allKeys.isPressed[key]
        if type(duration) == "number" and duration > (maxDuration or 0) then
          maxDuration = duration
        end
      end
    end
  end

  return maxDuration
end


-- Builds the main UI elements for the overlay
function InputDeviceOverlay:buildUi()
  -- Title
  self.titleLabel = Label({
    text = "Press a button on the device you want to use",
    hAlign = "center",
    vAlign = "top",
    y = 60,
    fontSize = GraphicsUtil.fontSize + 4
  })
  self:addChild(self.titleLabel)

  -- Subtitle
  self.subtitleLabel = Label({
    text = "or touch the player slot if you want to use touch",
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

---@return PlayerSlot? Player slot under mouse cursor or nil
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
    local slot = PlayerSlot({playerNumber = i, parentOverlay = self})
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
---@return table? Device descriptor if player is assigned, nil otherwise
function InputDeviceOverlay:getAssignedDeviceForPlayer(player)
  if not self.deviceDescriptors or not self.battleRoom or not player then
    return nil
  end

  for _, descriptor in ipairs(self.deviceDescriptors) do
    if descriptor and descriptor.config then
      local assignedPlayer = self.battleRoom:getPlayerAssignedToDevice(descriptor.config)
      if assignedPlayer == player then
        return descriptor
      end
    end
  end
  return nil
end


function InputDeviceOverlay:syncDevices()
  local latest = InputDeviceUtils.getAssignableDevices()
  local rebuild = false

  if #latest ~= #self.deviceDescriptors then
    rebuild = true
  else
    for index, descriptor in ipairs(latest) do
      local current = self.deviceDescriptors[index]
      if not current or current.config ~= descriptor.config then
        rebuild = true
        break
      end
    end
  end

  self.deviceDescriptors = latest

  if rebuild then
    self:updatePlayerSlots()
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
          local assignedDevice = self:getAssignedDeviceForPlayer(player)
          slot:setAssignedDevice(assignedDevice)
        end
      end
    end
  end
end




-- Assigns a device to a player and plays feedback
---@param descriptor table Device descriptor to assign
---@param targetPlayer Player? Player to assign to, or nil to assign to next unassigned player
function InputDeviceOverlay:assignDevice(descriptor, targetPlayer)
  assert(descriptor, "descriptor is required")
  assert(self.battleRoom, "InputDeviceOverlay requires a battleRoom reference")

  if not targetPlayer then
    targetPlayer = self:getNextUnassignedPlayer()
  end

  if not targetPlayer then
    return
  end

  local success = self.battleRoom:claimDeviceForPlayer(targetPlayer, descriptor.config)
  if success then
    if GAME.theme and GAME.theme.playValidationSfx then
      GAME.theme:playValidationSfx()
    end
    self:updatePlayerSlots()

    if self.battleRoom:areLocalPlayersAssigned() then
      self.autoCloseTimer = AUTO_CLOSE_DELAY
    end
  end
end

-- Processes hold input for a configuration device
---@param descriptor table Device descriptor for controller/keyboard
---@param dt number Delta time in seconds
function InputDeviceOverlay:processConfigHold(descriptor, dt)
  assert(descriptor and descriptor.config, "Descriptor with config is required")
  assert(type(dt) == "number", "dt must be numeric")

  if descriptor.config.claimed == true then
    return
  end

  local state = self.deviceState[descriptor.id]
  if not state then
    state = {confirmTriggered = false, holdTime = 0}
    self.deviceState[descriptor.id] = state
  end

  local confirmDuration = getHoldDurationForDescriptor(descriptor, ALL_INPUT_KEYS)
  if confirmDuration and confirmDuration > 0 then
    state.holdTime = confirmDuration
  else
    state.holdTime = 0
  end

  -- Update visual feedback on all slots
  local progress = math.min(state.holdTime / self.holdThreshold, 1)
  for i, slot in ipairs(self.playerSlots) do
    if not slot.assignedDevice and progress > 0 then
      slot:setHoldProgress(progress, descriptor.type)
      break
    end
  end

  if state.holdTime >= self.holdThreshold and not state.confirmTriggered then
    self:assignDevice(descriptor)
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

-- Processes touch hold logic when mouse is held down
---@param dt number Delta time in seconds
---@param touchDescriptor table Touch device descriptor
function InputDeviceOverlay:processTouchHold(dt, touchDescriptor)
  local targetSlot = self:getPlayerSlotForTouch()
  if not targetSlot then
    self:clearTouchTarget()
    return
  end

  local state = self.deviceState[touchDescriptor.id]
  if not state then
    state = {confirmTriggered = false, holdTime = 0}
    self.deviceState[touchDescriptor.id] = state
  end

  self:updateTouchTarget(targetSlot)

  -- Update hold time directly in device state
  local mousePressed = inputManager.mouse.isPressed[1]
  if type(mousePressed) == "number" then
    state.holdTime = mousePressed
  else
    state.holdTime = state.holdTime + dt
  end

  local progress = math.min(state.holdTime / self.holdThreshold, 1)
  targetSlot:setHoldProgress(progress, "touch")

  if state.holdTime >= self.holdThreshold and not state.confirmTriggered then
    self:assignTouchToSlot(touchDescriptor, targetSlot)
    state.confirmTriggered = true
  elseif state.holdTime < self.holdThreshold then
    state.confirmTriggered = false
  end
end

-- Updates touch target slot when changed
---@param targetSlot PlayerSlot New target slot for touch assignment
function InputDeviceOverlay:updateTouchTarget(targetSlot)
  if self.touchTargetSlot ~= targetSlot then
    if self.touchTargetSlot then
      self.touchTargetSlot:setTouchTarget(false)
    end
    self.touchTargetSlot = targetSlot
    self.touchTargetSlot:setTouchTarget(true)
    -- Reset touch device state when switching targets
    local touchDescriptor = self:getTouchDescriptor()
    if touchDescriptor then
      local state = self.deviceState[touchDescriptor.id]
      if state then
        state.holdTime = 0
        state.confirmTriggered = false
      end
    end
  end
end


-- Assigns touch device to specific slot
---@param touchDescriptor table Touch device descriptor
---@param targetSlot PlayerSlot Slot to assign touch to
function InputDeviceOverlay:assignTouchToSlot(touchDescriptor, targetSlot)
  local players = self:getLocalPlayers()
  for i, slot in ipairs(self.playerSlots) do
    if slot == targetSlot then
      local targetPlayer = players[i]
      if targetPlayer then
        self:assignDevice(touchDescriptor, targetPlayer)
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
  local touchDescriptor = self:getTouchDescriptor()
  if touchDescriptor then
    local state = self.deviceState[touchDescriptor.id]
    if state then
      state.holdTime = 0
      state.confirmTriggered = false
    end
  end
end

---@return table? Touch device descriptor or nil if not found
function InputDeviceOverlay:getTouchDescriptor()
  for _, descriptor in ipairs(self.deviceDescriptors) do
    if descriptor.type == "touch" then
      return descriptor
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

  -- Check if any configuration device has buttons pressed
  for _, descriptor in ipairs(self.deviceDescriptors) do
    if descriptor.type ~= "touch" and descriptor.config then
      local holdDuration = getHoldDurationForDescriptor(descriptor, ALL_INPUT_KEYS)
      if holdDuration and holdDuration > 0 then
        return true
      end
    end
  end

  return false
end

---@param dt number Delta time in seconds
function InputDeviceOverlay:updateSelf(dt)
  if not self.active then
    return
  end


  for i, slot in ipairs(self.playerSlots) do
    if not slot.assignedDevice then
      slot:setHoldProgress(0, nil)
    end
  end

  for _, descriptor in ipairs(self.deviceDescriptors) do
    if descriptor.type ~= "touch" then
      self:processConfigHold(descriptor, dt)
    end
  end

  self:updateTouchHold(dt)

  -- Handle auto-close timer
  if self.autoCloseTimer > 0 and not self:isAnyButtonCurrentlyPressed() then
    self.autoCloseTimer = self.autoCloseTimer - dt
    if self.autoCloseTimer <= 0 then
      self:close()
    end
  end
end

-- Intentional override
---@diagnostic disable-next-line: duplicate-set-field
function InputDeviceOverlay:drawSelf()
  if not self.active then
    return
  end

  GraphicsUtil.setColor(0, 0, 0, 0.75)
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

  self:syncDevices()
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

  if self.onClose then
    self.onClose()
  end
end

---@return boolean True if overlay is currently active
function InputDeviceOverlay:isActive()
  return self.active
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

function InputDeviceOverlay:receiveInputs()
  -- swallow focus-based input while overlay is displayed
end

return InputDeviceOverlay
