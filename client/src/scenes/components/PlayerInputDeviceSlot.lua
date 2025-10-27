local class = require("common.lib.class")
local UiElement = require("client.src.ui.UIElement")
local ImageContainer = require("client.src.ui.ImageContainer")
local inputManager = require("client.src.inputManager")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local InputPromptRenderer = require("client.src.graphics.InputPromptRenderer")

local PLAYER_SLOT_SIZE = 150
local DEVICE_ICON_SIZE = 64

-- Visual UI element representing one player's input device assignment status
---@class PlayerInputDeviceSlot : UiElement
---@field playerNumber number Visual player index (1, 2, etc.)
---@field assignedDevice InputConfiguration? Input configuration if assigned, nil otherwise
---@field holdProgress number Current hold progress from 0-1
---@field pendingDeviceType string? Device type being held during assignment (keyboard/controller/touch)
---@field playerImage ImageContainer? Player number icon from theme
---@field deviceIcon UiElement? Device icon showing keyboard/controller/touch type
---@field isTargetedForTouch boolean True when mouse is hovering over this slot for touch assignment
---@field parentOverlay InputDeviceOverlay? Reference to parent overlay for accessing device configs
---@field popScale number Current scale for pop animation (1.0 = normal, >1.0 = enlarged)
---@field popAnimationSpeed number Speed of pop animation decay per second

---@param options {playerNumber: number, parentOverlay: InputDeviceOverlay}
local PlayerInputDeviceSlot = class(function(self, options)
  local playerNumber = options.playerNumber or options
  self.playerNumber = playerNumber
  self.assignedDevice = nil
  self.holdProgress = 0
  self.pendingDeviceType = nil
  self.isTargetedForTouch = false
  self.parentOverlay = options.parentOverlay
  self.popScale = 1.0
  self.maxPopScale = 1.12
  self.popAnimationSpeed = 1

  -- Set size after parent initialization
  self.width = PLAYER_SLOT_SIZE
  self.height = PLAYER_SLOT_SIZE

  self:createPlayerNumberImage()
end, UiElement)

function PlayerInputDeviceSlot:drawSelf()
  love.graphics.push()

  -- Apply scale animation from center of slot
  if self.popScale ~= 1.0 then
    local centerX = self.x + self.width / 2
    local centerY = self.y + self.height / 2
    love.graphics.translate(centerX, centerY)
    love.graphics.scale(self.popScale, self.popScale)
    love.graphics.translate(-centerX, -centerY)
  end

  self:drawSlotBackground(self)
  self:drawSlotBorder(self)

  love.graphics.pop()
end

-- Draws slot background with progress-based color transitions
---@param slot PlayerInputDeviceSlot
function PlayerInputDeviceSlot:drawSlotBackground(slot)
  local progress = self.holdProgress or 0
  local bgColor = self:getBackgroundColor(progress)
  GraphicsUtil.setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
  GraphicsUtil.drawRectangle("fill", self.x, self.y, slot.width, slot.height)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

-- Draws slot border with progress-based color transitions
---@param slot PlayerInputDeviceSlot
function PlayerInputDeviceSlot:drawSlotBorder(slot)
  local progress = self.holdProgress or 0
  local borderColor = self:getBorderColor(progress)
  GraphicsUtil.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
  GraphicsUtil.drawRectangle("line", self.x, self.y, slot.width, slot.height)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

-- Gets background color based on assignment and progress
---@param progress number Hold progress from 0-1
---@return table Color array {r, g, b, a}
function PlayerInputDeviceSlot:getBackgroundColor(progress)
  if self.assignedDevice then
    return GAME.theme.colors.activeBackgroundColor
  else
    -- Interpolate from inputSlotDefaultBackgroundColor to inputSlotSelectedBackgroundColor
    local defaultColor = GAME.theme.colors.inputSlotDefaultBackgroundColor
    local selectedColor = GAME.theme.colors.inputSlotSelectedBackgroundColor
    return {
      defaultColor[1] + (selectedColor[1] - defaultColor[1]) * progress,
      defaultColor[2] + (selectedColor[2] - defaultColor[2]) * progress,
      defaultColor[3] + (selectedColor[3] - defaultColor[3]) * progress,
      defaultColor[4] + (selectedColor[4] - defaultColor[4]) * progress,
    }
  end
end

-- Gets border color based on assignment and progress
---@param progress number Hold progress from 0-1
---@return table Color array {r, g, b, a}
function PlayerInputDeviceSlot:getBorderColor(progress)
  if self.assignedDevice then
    return GAME.theme.colors.inputSlotSelectedBorderColor
  else
    -- Interpolate from inputSlotDefaultBorderColor to inputSlotSelectedBorderColor
    local defaultColor = GAME.theme.colors.inputSlotDefaultBorderColor
    local selectedColor = GAME.theme.colors.inputSlotSelectedBorderColor
    return {
      defaultColor[1] + (selectedColor[1] - defaultColor[1]) * progress,
      defaultColor[2] + (selectedColor[2] - defaultColor[2]) * progress,
      defaultColor[3] + (selectedColor[3] - defaultColor[3]) * progress,
      defaultColor[4] + (selectedColor[4] - defaultColor[4]) * progress,
    }
  end
end

-- Creates the player number image from theme
function PlayerInputDeviceSlot:createPlayerNumberImage()
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
---@param config InputConfiguration? Input configuration or nil
function PlayerInputDeviceSlot:setAssignedDevice(config)
  self.assignedDevice = config
end

-- Updates the device icon based on current assignment or hold progress
function PlayerInputDeviceSlot:updateDeviceIcon()
  if self.deviceIcon then
    self.deviceIcon:detach()
    self.deviceIcon = nil
  end

  -- Show icon for assigned device OR pending device during hold
  local deviceType = nil
  if self.assignedDevice and self.assignedDevice.deviceType then
    deviceType = self.assignedDevice.deviceType
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

      -- Get pre-calculated controller image variant and device number from config
      local controllerImageVariant = nil
      local deviceNumber = nil

      if self.assignedDevice then
        -- Use pre-calculated values from assigned device config
        controllerImageVariant = self.assignedDevice.controllerImageVariant
        deviceNumber = self.assignedDevice.deviceNumber
      elseif self.pendingDeviceType and self.parentOverlay then
        -- For pending devices, find the config being held to show specific controller icon
        for _, config in ipairs(inputManager:getAssignableDevices()) do
          if config.deviceType == self.pendingDeviceType then
            local state = self.parentOverlay.deviceState[config.id]
            if state and state.holdTime > 0 then
              controllerImageVariant = config.controllerImageVariant
              deviceNumber = config.deviceNumber
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
function PlayerInputDeviceSlot:setHoldProgress(progress, pendingDeviceType)
  self.holdProgress = math.max(0, math.min(1, progress))
  self.pendingDeviceType = pendingDeviceType
end

---@param isTarget boolean True when mouse is hovering over this slot
function PlayerInputDeviceSlot:setTouchTarget(isTarget)
  self.isTargetedForTouch = isTarget
end

---@param dt number Delta time in seconds
function PlayerInputDeviceSlot:updateSelf(dt)
  -- Update device icon if needed during each frame
  self:updateDeviceIcon()

  -- Animate pop scale back to 1.0
  if self.popScale > 1.0 then
    self.popScale = self.popScale - (self.popAnimationSpeed * dt)
    if self.popScale < 1.0 then
      self.popScale = 1.0
    end
  end
end

-- Triggers pop animation when assignment completes
function PlayerInputDeviceSlot:triggerPopAnimation()
  self.popScale = self.maxPopScale
end

-- Checks if mouse cursor is over this player slot
---@return boolean True if mouse is over this slot
function PlayerInputDeviceSlot:isMouseOver()
  local mx, my = inputManager.mouse.x, inputManager.mouse.y
  local x, y = self:getScreenPos()
  return mx >= x and mx <= x + self.width and my >= y and my <= y + self.height
end

return PlayerInputDeviceSlot
