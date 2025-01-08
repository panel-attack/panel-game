local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")

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

function UIElement:draw()
  if self.isVisible then
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

-- UiElements containing children draw the children-independent part in this function
-- implementation is optional so layout elements don't have to
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

function UIElement:getTouchedElement(x, y)
  if self.isVisible and self.isEnabled and self:inBounds(x, y) then
    local touchedElement
    for i = 1, #self.children do
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

return UIElement