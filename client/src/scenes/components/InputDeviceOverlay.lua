local class = require("common.lib.class")
local UiElement = require("client.src.ui.UIElement")
local Label = require("client.src.ui.Label")
local Grid = require("client.src.ui.Grid")
local TextButton = require("client.src.ui.TextButton")
local InputDeviceUtils = require("client.src.input.InputDeviceUtils")
local inputManager = require("client.src.inputManager")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local consts = require("common.engine.consts")
local logger = require("common.lib.logger")

local HOLD_THRESHOLD = 0.5
local CONFIRM_KEYS = {"Swap1", "Start"}
local CANCEL_KEYS = {"Swap2", "MenuEsc"}
local KEY_ACTIVE_VALUES = {
  [true] = true,
  [false] = false,
}

---@class InputDeviceOverlay : UiElement
---@field battleRoom BattleRoom
---@field holdThreshold number
---@field active boolean
---@field deviceGrid Grid?
---@field deviceButtons table<string, TextButton>
---@field deviceDescriptors table
---@field deviceState table<string, {confirmTriggered:boolean, cancelTriggered:boolean}>
---@field touchHoldTriggered boolean
---@field onClose fun()? optional close callback
local InputDeviceOverlay = class(function(self, options)
  options = options or {}
  self.battleRoom = options.battleRoom
  self.holdThreshold = options.holdThreshold or HOLD_THRESHOLD
  self.onClose = options.onClose

  self.active = false
  self.deviceGrid = nil
  self.deviceButtons = {}
  self.deviceDescriptors = {}
  self.deviceState = {}
  self.touchHoldTriggered = false
  self.touchHoldTime = 0

  self.hFill = true
  self.vFill = true
  self.width = consts.CANVAS_WIDTH
  self.height = consts.CANVAS_HEIGHT
  self:setVisibility(false)

  self:buildUi()
  logger.debug("InputDeviceOverlay initialized")
end, UiElement)

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

  if descriptor.bindings then
    for _, alias in ipairs(keyAliases) do
      local binding = descriptor.bindings[alias]
      if binding then
        local duration = inputManager.allKeys.isPressed[binding]
        if type(duration) == "number" and duration > (maxDuration or 0) then
          maxDuration = duration
        end
      end
    end
  end

  return maxDuration
end

local function isKeyHeldForDescriptor(descriptor, keyAliases)
  local device = descriptor.config

  if device then
    for _, alias in ipairs(keyAliases) do
      local downValue = device.isDown and device.isDown[alias]
      if type(downValue) == "number" then
        return true
      elseif KEY_ACTIVE_VALUES[downValue] then
        return true
      end
    end
  end

  if descriptor.bindings then
    for _, alias in ipairs(keyAliases) do
      local binding = descriptor.bindings[alias]
      if binding then
        local downValue = inputManager.allKeys.isDown[binding]
        if type(downValue) == "number" then
          return true
        elseif KEY_ACTIVE_VALUES[downValue] then
          return true
        end
      end
    end
  end

  return false
end

function InputDeviceOverlay:buildUi()
  self.titleLabel = Label({
    text = "Select Input Device(s)",
    translate = false,
    hAlign = "center",
    hFill = true,
    wrapWidth = consts.CANVAS_WIDTH
  })
  self.titleLabel.y = 60
  self:addChild(self.titleLabel)

  local instructionWidth = math.floor(consts.CANVAS_WIDTH * 0.7)
  self.instructionsLabel = Label({
    text = "",
    translate = false,
    hAlign = "center",
    hFill = false,
    width = instructionWidth,
    wrapWidth = instructionWidth,
    fontSize = GraphicsUtil.fontSize + 2
  })
  self.instructionsLabel.x = math.floor((consts.CANVAS_WIDTH - instructionWidth) / 2)
  self.instructionsLabel.y = 120
  self:addChild(self.instructionsLabel)

  self.playerSlotContainer = UiElement({
    x = math.floor((consts.CANVAS_WIDTH - math.floor(consts.CANVAS_WIDTH * 0.7)) / 2),
    y = 240,
    width = math.floor(consts.CANVAS_WIDTH * 0.7),
    height = 0,
    hFill = false,
    vFill = false
  })
  self.playerSlotContainer.drawSelf = function(container)
    if container.height <= 0 then
      return
    end
    GraphicsUtil.setColor(0, 0, 0, 0.5)
    GraphicsUtil.drawRectangle("fill", 0, 0, container.width, container.height)
    GraphicsUtil.setColor(1, 1, 1, 0.2)
    GraphicsUtil.drawRectangle("line", 0, 0, container.width, container.height)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
  self:addChild(self.playerSlotContainer)
  self.playerSlotLabels = {}
end

function InputDeviceOverlay:getLocalPlayers()
  assert(self.battleRoom, "InputDeviceOverlay requires a battleRoom reference")
  return self.battleRoom:getLocalHumanPlayers()
end

function InputDeviceOverlay:getNextUnassignedPlayer()
  logger.debug("InputDeviceOverlay:getNextUnassignedPlayer")
  for _, player in ipairs(self:getLocalPlayers()) do
    if not self.battleRoom:isPlayerAssigned(player) then
      return player
    end
  end

  return nil
end

function InputDeviceOverlay:updateInstructions()
  logger.debug("InputDeviceOverlay:updateInstructions")
  local targetPlayer = self:getNextUnassignedPlayer()
  local playerLabel
  if targetPlayer then
    playerLabel = targetPlayer.playerNumber or "?"
  else
    local players = self:getLocalPlayers()
    playerLabel = players[1] and (players[1].playerNumber or "?") or "?"
  end

  local text = string.format(
    "Hold confirm for about 0.5 seconds on the device you want for Player %s, or click and hold on the touch tile.\nHold cancel to unassign a device",
    playerLabel
  )
  self.instructionsLabel:setText(text, nil, false)
  self.instructionsLabel:setWrap(self.instructionsLabel.width, "center")
  self.instructionsLabel:setWrap(math.floor(consts.CANVAS_WIDTH * 0.7), "center")
end

function InputDeviceOverlay:updatePlayerSlots()
  logger.debug("InputDeviceOverlay:updatePlayerSlots")
  self:updateTitle()
  for _, label in ipairs(self.playerSlotLabels) do
    label.element:detach()
  end
  self.playerSlotLabels = {}

  local players = self:getLocalPlayers()
  local lineHeight = 28
  if #players == 0 then
    self.playerSlotContainer.height = 0
  else
  self.playerSlotContainer.height = #players * lineHeight + 24
  end

  for index, player in ipairs(players) do
    local assignment = InputDeviceUtils.describePlayerAssignment(player)
    local labelText = string.format("Player %s — %s", player.playerNumber or index, assignment)
    local label = Label({
      text = labelText,
      translate = false,
      hAlign = "left",
      wrapWidth = self.playerSlotContainer.width,
      fontSize = GraphicsUtil.fontSize + 1
    })
    label.x = 8
    label.y = 12 + (index - 1) * lineHeight
    self.playerSlotContainer:addChild(label)
    self.playerSlotLabels[#self.playerSlotLabels + 1] = {player = player, element = label}
  end

  if self.deviceGridContainer then
    self.deviceGridContainer.y = self.playerSlotContainer.y + self.playerSlotContainer.height + 40
  end
end

function InputDeviceOverlay:updateTitle()
  local players = self:getLocalPlayers()
  local needed = 0
  for _, player in ipairs(players) do
    if not self.battleRoom:isPlayerAssigned(player) then
      needed = needed + 1
    end
  end
  local plural = needed > 1 and "Devices" or "Device"
  self.titleLabel:setText("Select Input " .. plural, nil, false)
end

function InputDeviceOverlay:rebuildDeviceGrid()
  logger.debug("InputDeviceOverlay:rebuildDeviceGrid")
  if self.deviceGrid then
    self.deviceGrid:detach()
    self.deviceGrid = nil
  end
  if self.deviceGridContainer then
    self.deviceGridContainer:detach()
    self.deviceGridContainer = nil
  end

  local devices = self.deviceDescriptors
  if #devices == 0 then
    return
  end

  local columns = math.min(#devices, 3)
  local rows = math.ceil(#devices / columns)
  local unitSize = 180

  local grid = Grid({
    unitSize = unitSize,
    gridWidth = columns,
    gridHeight = rows,
    unitMargin = 8
  })
  grid.x = 0
  grid.y = 0

  local gridContainer = UiElement({
    x = math.floor((consts.CANVAS_WIDTH - grid.width) / 2),
    y = self.playerSlotContainer.y + self.playerSlotContainer.height + 40,
    width = grid.width,
    height = grid.height
  })
  gridContainer.drawSelf = function(container)
    GraphicsUtil.setColor(0, 0, 0, 0.55)
    GraphicsUtil.drawRectangle("fill", 0, 0, container.width, container.height)
    GraphicsUtil.setColor(1, 1, 1, 0.25)
    GraphicsUtil.drawRectangle("line", 0, 0, container.width, container.height)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
  gridContainer:addChild(grid)
  self:addChild(gridContainer)
  self.deviceGridContainer = gridContainer
  self.deviceGrid = grid
  self.deviceButtons = {}
  self.touchDescriptor = nil
  self.touchButton = nil

  for index, descriptor in ipairs(devices) do
    logger.debug("InputDeviceOverlay: building descriptor %s bindings Swap1=%s Start=%s", descriptor.id,
      tostring(descriptor.bindings and descriptor.bindings.Swap1), tostring(descriptor.bindings and descriptor.bindings.Start))
    local button = TextButton({
      label = Label({text = "", translate = false}),
      hFill = true,
      vFill = true,
      backgroundColor = {0.15, 0.15, 0.15, 0.85},
      outlineColor = {1, 1, 1, 1}
    })
    button.isEnabled = descriptor.type == "touch"
    button.deviceId = descriptor.id
    if button.label then
      button.label:setVisibility(false)
    end

    local progressFill = UiElement({x = 0, y = 0, width = 0, height = button.height})
    progressFill.drawSelf = function(fill)
      GraphicsUtil.setColor(1, 1, 1, 0.2)
      GraphicsUtil.drawRectangle("fill", 0, 0, fill.width, fill.height)
      GraphicsUtil.setColor(1, 1, 1, 1)
    end
    button.progressFill = progressFill
    button:addChild(progressFill)

    local nameLabel = Label({
      text = descriptor.label,
      translate = false,
      hAlign = "center",
      wrapWidth = unitSize - 32,
      fontSize = GraphicsUtil.fontSize + 2
    })
    nameLabel.hFill = true
    button.nameLabel = nameLabel
    button:addChild(nameLabel)

    local baseInstruction = descriptor.type == "touch" and "Click and hold" or "Hold confirm"
    local instructionLabel = Label({
      text = baseInstruction,
      translate = false,
      hAlign = "center",
      wrapWidth = unitSize - 32,
      fontSize = GraphicsUtil.fontSize - 2
    })
    instructionLabel.hFill = true
    button.instructionLabel = instructionLabel
    button:addChild(instructionLabel)

    button.onResize = function(selfButton)
      if selfButton.progressFill then
        selfButton.progressFill.height = selfButton.height
      end
      if selfButton.nameLabel then
        selfButton.nameLabel.width = selfButton.width - 16
        selfButton.nameLabel.x = 8
        selfButton.nameLabel.y = 14
      end
      if selfButton.instructionLabel then
        selfButton.instructionLabel.width = selfButton.width - 16
        selfButton.instructionLabel.x = 8
        selfButton.instructionLabel.y = selfButton.height - selfButton.instructionLabel.height - 14
      end
    end
    button:onResize()

    if descriptor.type == "touch" then
      self.touchDescriptor = descriptor
      self.touchButton = button
      button.onClick = function() end
      button.onSelect = nil
    else
      button.onClick = function() end
    end
    descriptor.button = button

    local col = ((index - 1) % columns) + 1
    local row = math.floor((index - 1) / columns) + 1
    grid:createElementAt(col, row, 1, 1, descriptor.id, button, true, true)
    self.deviceButtons[descriptor.id] = button
  end

  self:updateDeviceButtons()
end

function InputDeviceOverlay:updateDeviceButtons()
  logger.debug("InputDeviceOverlay:updateDeviceButtons")
  for _, descriptor in ipairs(self.deviceDescriptors) do
    local button = self.deviceButtons[descriptor.id]
    if button then
      local state = self.deviceState[descriptor.id]
      self:updateHoldFeedback(descriptor, state)
    end
  end
end

function InputDeviceOverlay:syncDevices()
  logger.debug("InputDeviceOverlay:syncDevices")
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
    self:rebuildDeviceGrid()
  else
    self:updateDeviceButtons()
  end
end

function InputDeviceOverlay:updateHoldFeedback(descriptor, state)
  local button = descriptor.button or self.deviceButtons[descriptor.id]
  if not button then
    return
  end

  local assignedPlayer = self.battleRoom and self.battleRoom:getPlayerAssignedToDevice(descriptor.config) or nil
  local ratio = 0
  if state and state.confirmHoldTime then
    ratio = math.min(state.confirmHoldTime / self.holdThreshold, 1)
  end
  if descriptor == self.touchDescriptor then
    ratio = math.min((self.touchHoldTime or 0) / self.holdThreshold, 1)
  end
  if button.progressFill then
    button.progressFill.width = button.width * ratio
  end

  if assignedPlayer then
    button.backgroundColor = {0.25, 0.5, 0.25, 0.9}
    local statusText = string.format("Assigned to Player %s\nHold cancel to unassign", assignedPlayer.playerNumber or "?")
    button.nameLabel:setText(descriptor.label, nil, false)
    button.instructionLabel:setText(statusText, nil, false)
    if button.progressFill then
      button.progressFill.width = button.width
    end
  else
    button.backgroundColor = {0.15, 0.15, 0.15, 0.85}
    button.nameLabel:setText(descriptor.label, nil, false)
    local baseInstruction
    if descriptor.type == "touch" then
      if ratio > 0 then
        baseInstruction = string.format("Click %.0f%%", ratio * 100)
      else
        baseInstruction = "Click and hold"
      end
    else
      if ratio > 0 then
        baseInstruction = string.format("Hold %.0f%%", ratio * 100)
      else
        baseInstruction = "Hold confirm"
      end
    end
    button.instructionLabel:setText(baseInstruction, nil, false)
  end

  if button.onResize then
    button:onResize()
  end
end

function InputDeviceOverlay:assignDevice(descriptor)
  assert(descriptor, "descriptor is required")
  assert(self.battleRoom, "InputDeviceOverlay requires a battleRoom reference")
  local targetPlayer = self:getNextUnassignedPlayer()
  if not targetPlayer then
    logger.debug("InputDeviceOverlay:assignDevice called with no target player")
    return
  end

  logger.debug("InputDeviceOverlay:assignDevice assigning device %s to player %s", descriptor.id, targetPlayer.playerNumber)
  if descriptor.bindings then
    logger.debug("InputDeviceOverlay:assignDevice bindings Swap1=%s Start=%s", tostring(descriptor.bindings.Swap1), tostring(descriptor.bindings.Start))
  end
  local success = self.battleRoom:claimDeviceForPlayer(targetPlayer, descriptor.config)
  if success then
    GAME.theme:playValidationSfx()
    self:updatePlayerSlots()
    self:updateInstructions()
    self:updateDeviceButtons()
    if self.battleRoom:areLocalPlayersAssigned() then
      self:close()
    end
  end
end

function InputDeviceOverlay:handleCancel(descriptor)
  assert(descriptor, "descriptor is required")
  assert(self.battleRoom, "InputDeviceOverlay requires a battleRoom reference")
  logger.debug("InputDeviceOverlay:handleCancel for device %s", descriptor.id)
  local player = self.battleRoom:getPlayerAssignedToDevice(descriptor.config)
  if player then
    self.battleRoom:clearPlayerAssignment(player)
    GAME.theme:playCancelSfx()
    self:updatePlayerSlots()
    self:updateInstructions()
    self:updateDeviceButtons()
  end
end

function InputDeviceOverlay:processConfigHold(descriptor, dt)
  assert(descriptor and descriptor.config, "Descriptor with config is required")
  assert(type(dt) == "number", "dt must be numeric")
  logger.debug("InputDeviceOverlay:processConfigHold device=%s dt=%.3f", descriptor.id, dt)
  local device = descriptor.config
  local state = self.deviceState[descriptor.id]
  if not state then
    state = {confirmTriggered = false, cancelTriggered = false, confirmHoldTime = 0, cancelHoldTime = 0}
    self.deviceState[descriptor.id] = state
  end

  local swap1Binding = descriptor.bindings and descriptor.bindings.Swap1
  local startBinding = descriptor.bindings and descriptor.bindings.Start
  if swap1Binding or startBinding then
    logger.debug("InputDeviceOverlay:processConfigHold %s raw isPressed Swap1=%s Start=%s", descriptor.id,
      tostring(swap1Binding and device.isPressed and device.isPressed.Swap1 or "nil"),
      tostring(startBinding and device.isPressed and device.isPressed.Start or "nil"))
    logger.debug("InputDeviceOverlay:processConfigHold %s raw isDown Swap1=%s Start=%s", descriptor.id,
      tostring(swap1Binding and device.isDown and device.isDown.Swap1 or "nil"),
      tostring(startBinding and device.isDown and device.isDown.Start or "nil"))
    logger.debug("InputDeviceOverlay:processConfigHold %s allKeys isPressed swap1Binding=%s startBinding=%s", descriptor.id,
      tostring(swap1Binding and inputManager.allKeys.isPressed[swap1Binding] or "nil"),
      tostring(startBinding and inputManager.allKeys.isPressed[startBinding] or "nil"))
    logger.debug("InputDeviceOverlay:processConfigHold %s allKeys isDown swap1Binding=%s startBinding=%s", descriptor.id,
      tostring(swap1Binding and inputManager.allKeys.isDown[swap1Binding] or "nil"),
      tostring(startBinding and inputManager.allKeys.isDown[startBinding] or "nil"))
  end

  local confirmDuration = getHoldDurationForDescriptor(descriptor, CONFIRM_KEYS)
  if confirmDuration then
    state.confirmHoldTime = confirmDuration
    if confirmDuration > 0 then
      logger.debug("InputDeviceOverlay:processConfigHold %s confirmDuration=%.3f", descriptor.id, confirmDuration)
    end
  elseif isKeyHeldForDescriptor(descriptor, CONFIRM_KEYS) then
    state.confirmHoldTime = (state.confirmHoldTime or 0) + dt
    confirmDuration = state.confirmHoldTime
    logger.debug("InputDeviceOverlay:processConfigHold %s accumulating confirmHold=%.3f", descriptor.id, state.confirmHoldTime)
  else
    state.confirmHoldTime = 0
  end

  if confirmDuration and confirmDuration >= self.holdThreshold then
    if not state.confirmTriggered then
      logger.debug("InputDeviceOverlay:processConfigHold confirm threshold reached for %s", descriptor.id)
      self:assignDevice(descriptor)
    end
    state.confirmTriggered = true
  else
    state.confirmTriggered = false
  end

  if self.battleRoom:getPlayerAssignedToDevice(device) then
    local cancelDuration = getHoldDurationForDescriptor(descriptor, CANCEL_KEYS)
    if cancelDuration then
      state.cancelHoldTime = cancelDuration
      if cancelDuration > 0 then
        logger.debug("InputDeviceOverlay:processConfigHold %s cancelDuration=%.3f", descriptor.id, cancelDuration)
      end
    elseif isKeyHeldForDescriptor(descriptor, CANCEL_KEYS) then
      state.cancelHoldTime = (state.cancelHoldTime or 0) + dt
      cancelDuration = state.cancelHoldTime
      logger.debug("InputDeviceOverlay:processConfigHold %s accumulating cancelHold=%.3f", descriptor.id, state.cancelHoldTime)
    else
      state.cancelHoldTime = 0
    end

    if cancelDuration and cancelDuration >= self.holdThreshold then
      if not state.cancelTriggered then
        logger.debug("InputDeviceOverlay:processConfigHold cancel threshold reached for %s", descriptor.id)
        self:handleCancel(descriptor)
      end
      state.cancelTriggered = true
    else
      state.cancelTriggered = false
    end
  else
    state.cancelTriggered = false
    state.cancelHoldTime = 0
  end

  self:updateHoldFeedback(descriptor, state)
end

function InputDeviceOverlay:isMouseOverButton(button)
  if not button then
    return false
  end
  local bx, by = button:getScreenPos()
  return inputManager.mouse.x >= bx and inputManager.mouse.x <= bx + button.width and
    inputManager.mouse.y >= by and inputManager.mouse.y <= by + button.height
end

function InputDeviceOverlay:updateTouchHold(dt)
  if not self.touchDescriptor or not self.touchButton then
    return
  end

  local mousePressed = inputManager.mouse.isPressed[1]
  local mouseDown = inputManager.mouse.isDown[1]
  local inBounds = self:isMouseOverButton(self.touchButton)
  local holding = (type(mousePressed) == "number" and mousePressed > 0) or type(mouseDown) == "number"

  if holding and inBounds then
    if type(mousePressed) == "number" then
      self.touchHoldTime = mousePressed
    else
      self.touchHoldTime = self.touchHoldTime + dt
    end

    logger.debug("InputDeviceOverlay:updateTouchHold holdTime=%.3f", self.touchHoldTime)
    if self.touchHoldTime >= self.holdThreshold and not self.touchHoldTriggered then
      self.touchHoldTriggered = true
      self:assignDevice(self.touchDescriptor)
    end
  else
    if not holding or not inBounds then
      self.touchHoldTriggered = false
    end
    self.touchHoldTime = 0
  end

  self.deviceState[self.touchDescriptor.id] = self.deviceState[self.touchDescriptor.id] or {}
  local touchState = self.deviceState[self.touchDescriptor.id]
  touchState.confirmHoldTime = self.touchHoldTime
  self:updateHoldFeedback(self.touchDescriptor, touchState)
end

function InputDeviceOverlay:updateSelf(dt)
  if not self.active then
    return
  end
  logger.debug("InputDeviceOverlay:updateSelf dt=%.3f", dt)

  self:syncDevices()

  for _, descriptor in ipairs(self.deviceDescriptors) do
    if descriptor.type ~= "touch" then
      self:processConfigHold(descriptor, dt)
    end
  end

  self:updateTouchHold(dt)

  if self.battleRoom and self.battleRoom:areLocalPlayersAssigned() then
    self:close()
  end
end

function InputDeviceOverlay:drawSelf()
  if not self.active then
    return
  end

  logger.debug("InputDeviceOverlay:drawSelf")
  GraphicsUtil.setColor(0, 0, 0, 0.75)
  GraphicsUtil.drawRectangle("fill", 0, 0, self.width, self.height)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

function InputDeviceOverlay:open()
  assert(self.battleRoom, "InputDeviceOverlay requires a battleRoom reference")
  logger.debug("InputDeviceOverlay:open")
  self:updatePlayerSlots()

  self:updateInstructions()
  self.deviceState = {}
  self.touchHoldTriggered = false
  self.active = true
  self:setVisibility(true)
  self:syncDevices()
end

function InputDeviceOverlay:close()
  if not self.active then
    return
  end

  logger.debug("InputDeviceOverlay:close")
  self.active = false
  self:setVisibility(false)
  if self.onClose then
    self.onClose()
  end
  self.touchHoldTriggered = false
  self.touchHoldTime = 0
end

function InputDeviceOverlay:isActive()
  return self.active
end

function InputDeviceOverlay:onTouch()
  if self.active then
    logger.debug("InputDeviceOverlay:onTouch consumed")
    return true
  end
end

function InputDeviceOverlay:onRelease()
  if self.active then
    logger.debug("InputDeviceOverlay:onRelease consumed")
    return true
  end
end

function InputDeviceOverlay:receiveInputs()
  -- swallow focus-based input while overlay is displayed
  logger.debug("InputDeviceOverlay:receiveInputs consumed")
end

return InputDeviceOverlay
