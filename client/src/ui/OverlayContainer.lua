local class = require("common.lib.class")
local UiElement = require("client.src.ui.UIElement")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local consts = require("common.engine.consts")

-- Full-screen semi-transparent overlay that holds a centered UI element
-- Closes on click outside content area
---@class OverlayContainer : UiElement
---@field content UiElement? The centered content element
---@field onClose fun()? Callback invoked when overlay closes
---@field active boolean True when overlay is open and processing input
local OverlayContainer = class(
  function(self, options)
    options = options or {}
    self.content = options.content
    self.onClose = options.onClose
    self.active = false

    self.width = consts.CANVAS_WIDTH
    self.height = consts.CANVAS_HEIGHT
    self:setVisibility(false)

    if self.content then
      self:addChild(self.content)
      self.content.hAlign = "center"
      self.content.vAlign = "center"
    end
  end,
  UiElement, "OverlayContainer"
)

-- Opens the overlay
function OverlayContainer:open()
  self.active = true
  self:setVisibility(true)
end

-- Closes the overlay
function OverlayContainer:close()
  if not self.active then
    return
  end

  self.active = false
  self:setVisibility(false)

  if self.onClose then
    self.onClose()
  end
end

-- Checks if the overlay is currently active
---@return boolean
function OverlayContainer:isActive()
  return self.active
end

-- Sets the content element for the overlay
---@param content UiElement The content to display in the center
function OverlayContainer:setContent(content)
  if self.content then
    self.content:detach()
  end

  self.content = content
  if self.content then
    self:addChild(self.content)
    self.content.hAlign = "center"
    self.content.vAlign = "center"
  end
end

-- Draws the semi-transparent background
function OverlayContainer:drawSelf()
  if not self.active then
    return
  end

  GraphicsUtil.setColor(0, 0, 0, 0.75)
  GraphicsUtil.drawRectangle("fill", 0, 0, self.width, self.height)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

-- Touch handler - closes overlay if clicking outside content
---@return boolean? True to block touch event propagation
function OverlayContainer:onTouch(x, y)
  if not self.active then
    return false
  end

  if self.content then
    local contentX, contentY = self.content:getScreenPos()
    local inContentBounds = x >= contentX and x < contentX + self.content.width and
                           y >= contentY and y < contentY + self.content.height

    if not inContentBounds then
      self:close()
      return true
    end
  end

  return true
end

-- Release handler - blocks event propagation
---@return boolean? True to block release event propagation
function OverlayContainer:onRelease()
  if self.active then
    return true
  end
end

-- Input handler - closes overlay on ESC key
function OverlayContainer:receiveInputs(inputs, dt)
  if not self.active then
    return
  end

  if inputs.isDown["MenuEsc"] then
    self:close()
  end
end

return OverlayContainer
