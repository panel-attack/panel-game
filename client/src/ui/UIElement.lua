local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local DebugSettings = require("client.src.debug.DebugSettings")
local logger = require("common.lib.logger")

---@class UiElement
---@field x number relative x offset to the parent element (canvas if no parent)
---@field y number relative y offset to the parent element (canvas if no parent)
---@field width number width of the element for the sake of resizing children and touch hitboxes
---@field height number height of the element for the sake of resizing children and touch hitboxes
---@field hAlign ("left" | "center" | "right") determines the horizontal alignment relative to the parent
---@field vAlign ("top" | "center" | "bottom") determines the vertical alignment relative to the parent
---@field hFill boolean if the element's width should fill out the entire parent's width
---@field vFill boolean if the element's height should fill out the entire parent's height
---@field isVisible boolean if the element is currently visible for rendering (also disables touch interaction)
---@field isEnabled boolean if the element is currently eligible for touch interaction
---@field parent UiElement the element's parent it is getting position relative to via its properties
---@field children UiElement[] the element's children that get positioned relative to it
---@field id integer unique identifier of the element
---@field onTouch function? touch callback for when the element is being touched
---@field onDrag function? touch callback for when the mouse touching the element is dragged across the screen
---@field onRelease function? touch callback for when the mouse touching the element is released
---@field onHold function? touch callback for when a touch is held on the element for a longer duration
---@field [any] any

---@class UiElementOptions
---@field x number? relative x offset to the parent element (canvas if no parent)
---@field y number? relative y offset to the parent element (canvas if no parent)
---@field width number? width of the element for the sake of resizing children and touch hitboxes
---@field height number? height of the element for the sake of resizing children and touch hitboxes
---@field hAlign ("left" | "center" | "right")? determines the horizontal alignment relative to the parent
---@field vAlign ("top" | "center" | "bottom")? determines the vertical alignment relative to the parent
---@field hFill boolean? if the element's width should fill out the entire parent's width
---@field vFill boolean? if the element's height should fill out the entire parent's height
---@field isVisible boolean? if the element is currently visible for rendering (also disables touch interaction)
---@field isEnabled boolean? if the element is currently eligible for touch interaction

local uniqueId = 0

-- base class for all UI elements
-- takes in a options table for setting default values
-- all valid base options are defined in the constructor
---@class UiElement
---@overload fun(options: UiElementOptions): UiElement
local UIElement = class(
  ---@param self UiElement
  function(self, options)
    -- local position relative to parent (or global pos if parent is nil)
    self.x = options.x or 0
    self.y = options.y or 0

    -- ui dimensions
    self.width = options.width or 0
    self.height = options.height or 0

    -- how to align the element inside the parent element
    self.hAlign = options.hAlign or "left"
    self.vAlign = options.vAlign or "top"

    -- how the size is determined relative to the parent element
    -- hFill true sets the width to the size of the parent
    self.hFill = options.hFill or false
    -- vFill true sets the height to the size of the parent
    self.vFill = options.vFill or false

    -- whether the ui element is visible
    self.isVisible = options.isVisible or options.isVisible == nil and true
    -- whether the ui element recieves events
    self.isEnabled = options.isEnabled or options.isEnabled == nil and true

    -- the parent element, position is relative to it
    self.parent = options.parent
    -- list of children elements
    self.children = options.children or {}

    self.id = uniqueId
    uniqueId = uniqueId + 1
  end
)

UIElement.TYPE = "UIElement"

function UIElement:addChild(uiElement)
  if uiElement.parent ~= self then
    self.children[#self.children + 1] = uiElement
    uiElement.parent = self
    uiElement:resize()
  end
end

function UIElement:resize()
  if self.hFill and self.parent then
    self.width = self.parent.width
  end

  if self.vFill and self.parent then
    self.height = self.parent.height
  end

  self:onResize()

  if self.hFill or self.vFill then
    for _, child in ipairs(self.children) do
      child:resize()
    end
  end
end

-- overridable function to define extra behaviour to the element itself on resize
function UIElement:onResize()
end

function UIElement:detach()
  if self.parent then
    for i, child in ipairs(self.parent.children) do
      if child.id == self.id then
        table.remove(self.parent.children, i)
        self:onDetach()
        self.parent = nil
        break
      end
    end
    return self
  end
end

function UIElement:onDetach()
end

function UIElement:getScreenPos()
  local x, y = 0, 0
  local xOffset, yOffset = 0, 0
  if self.parent then
    x, y = self.parent:getScreenPos()
    xOffset, yOffset = GraphicsUtil.getAlignmentOffset(self.parent, self)
  end

  return x + self.x + xOffset, y + self.y + yOffset
end

-- passes a retranslation request through the tree to reach all Labels
function UIElement:refreshLocalization()
  for _, uiElement in ipairs(self.children) do
    uiElement:refreshLocalization()
  end
end

function UIElement:update(dt)
  self:updateSelf(dt)
  self:updateChildren(dt)
end

-- UiElements can override this method to do custom update logic
-- implementation is optional
function UIElement:updateSelf(dt)
end

function UIElement:updateChildren(dt)
  for _, uiElement in ipairs(self.children) do
    uiElement:update(dt)
  end
end

function UIElement:draw()
  if self.isVisible then
    if DebugSettings.showUIElementBorders() then
      GraphicsUtil.setColor(0, 0, 1, 1)
      GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height)
      GraphicsUtil.setColor(1, 1, 1, 1)
    end
    self:drawSelf()
    -- if DEBUG_ENABLED then
    --   GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height, 1, 1, 1, 0.5)
    -- end
    love.graphics.push("transform")
    love.graphics.translate(self.x, self.y)
    self:drawChildren()
    love.graphics.pop()
  end
end

-- UiElements can override this method to do custom drawing
-- implementation is optional
function UIElement:drawSelf()
end

function UIElement:drawChildren()
  for _, uiElement in ipairs(self.children) do
    if uiElement.isVisible then
      GraphicsUtil.applyAlignment(self, uiElement)
      uiElement:draw()
      GraphicsUtil.resetAlignment()
    end
  end
end

-- setVisibility is to used on children that are temporarily "offscreen", e.g. as part of a scrolling UiElement
-- if you want to stop drawing an element, e.g. due to changing a subscreen, 
--  the more opportune method is to simply remove it from the ui tree via detach()
function UIElement:setVisibility(isVisible)
  self.isVisible = isVisible
  self:onVisibilityChanged()
end

function UIElement:onVisibilityChanged()
end

function UIElement:setEnabled(isEnabled)
  self.isEnabled = isEnabled
  for _, uiElement in ipairs(self.children) do
    uiElement:setEnabled(isEnabled)
  end
end

function UIElement:inBounds(x, y)
  local screenX, screenY = self:getScreenPos()
  return x > screenX and x < screenX + self.width and y > screenY and y < screenY + self.height
end

function UIElement:isTouchable()
  return self.onTouch
  or self.onHold
  or self.onDrag
  or self.onRelease
end

---Returns the foremost visible, enabled element containing the given screen-space coordinates.
---@param x number screen x coordinate of the touch
---@param y number screen y coordinate of the touch
---@return UiElement? element the coordinates intersect, or nil when none match
function UIElement:getTouchedElement(x, y)
  if self.isVisible and self.isEnabled and self:inBounds(x, y) then
    local touchedElement
    -- Check children in reverse order (last drawn = first touched)
    for i = #self.children, 1, -1 do
      touchedElement = self.children[i]:getTouchedElement(x, y)
      if touchedElement then
        return touchedElement
      end
    end

    if self:isTouchable() then
      return self
    end
  end
end

-- Traverses the UI tree and calls receiveInputs on any focused elements
function UIElement:handleFocusedInput(inputs, dt)
  -- If this element has focus and can receive inputs, handle it
  if self.hasFocus and self.receiveInputs then
    self:receiveInputs(inputs, dt)
    return true -- Input was handled, don't continue traversing
  end
  
  -- If this element is a focus director with a focused child, handle that
  if self.focused and self.focused.receiveInputs then
    self.focused:receiveInputs(inputs, dt)
    return true -- Input was handled
  end
  
  -- Otherwise, traverse children to find focused elements
  for _, child in ipairs(self.children) do
    if child:handleFocusedInput(inputs, dt) then
      return true -- Input was handled by a child
    end
  end
  
  return false -- No focused element found
end

---Returns a formatted tree of this element and all children with class name, TYPE, and root position
---@return string
function UIElement:toStringWithDepth()
  local function getElementInfo(element, depth)
    local indent = string.rep("  ", depth)
    local typeStr = element.TYPE and (" [" .. element.TYPE .. "]") or ""
    local x, y = element:getScreenPos()
    local info = string.format("%s%s @ (%.1f, %.1f)", indent, typeStr, x, y)

    local lines = {info}
    for _, child in ipairs(element.children) do
      local childInfo = getElementInfo(child, depth + 1)
      table.insert(lines, childInfo)
    end

    return table.concat(lines, "\n")
  end

  return getElementInfo(self, 0)
end

---Returns a formatted list of this element and its direct children only (non-recursive)
---@return string
function UIElement:toString()
  local typeStr = self.TYPE and (" [" .. self.TYPE .. "]") or ""
  local x, y = self:getScreenPos()
  local lines = {string.format("%s @ (%.1f, %.1f)", typeStr, x, y)}

  for _, child in ipairs(self.children) do
    local childTypeStr = child.TYPE and (" [" .. child.TYPE .. "]") or ""
    local childX, childY = child:getScreenPos()
    table.insert(lines, string.format("  %s @ (%.1f, %.1f)", childTypeStr, childX, childY))
  end

  return table.concat(lines, "\n")
end

return UIElement