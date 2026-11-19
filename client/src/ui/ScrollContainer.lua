local PATH = (...):gsub('%.[^%.]+$', '')
local UiElement = require(PATH .. ".UIElement")
local LayoutSolver = require(PATH .. ".LayoutSolver")
local class = require("common.lib.class")
local util = require("common.lib.util")
local GraphicsUtil = require("client.src.graphics.graphics_util")

local VERTICAL_CLIP = {vertical = true}
local HORIZONTAL_CLIP = {horizontal = true}

---@class ScrollContainerOptions : UiElementOptions
---@field scrollOrientation ("vertical" | "horizontal" | nil)

---@class ScrollContainer : UiElement
---@field scrollOrientation string "vertical" or "horizontal"
---@field scrollOffset number by how many pixels the children are translated in the orientation, 0 or less
---@field maxScrollOffset number how far the children in the flow reached past the end of the container in the last layout,
--- unbounded from a child being added until the next layout works it out
---@field keepOffset number? the offset of the area the next layout scrolls into view, as keepVisible takes it
---@field keepSize number? the size of the area the next layout scrolls into view
---@field keepChild UiElement? the child the next layout scrolls fully into view

---@class ScrollContainer
---@overload fun(options: ScrollContainerOptions): ScrollContainer
local ScrollContainer = class(
---@param self ScrollContainer
function(self, options)
  self.scrollOrientation = options.scrollOrientation or "vertical"
  self.scrollOffset = 0
  self.maxScrollOffset = 0
  local vertical = self.scrollOrientation == "vertical"
  self:setLayoutRule("layoutDirection", vertical and "topToBottom" or "leftToRight")
  self:setLayoutRule("clip", vertical and VERTICAL_CLIP or HORIZONTAL_CLIP)
end,
UiElement)
ScrollContainer.TYPE = "ScrollContainer"
-- pixels one notch of the mouse wheel scrolls
ScrollContainer.SCROLL_STEP = 40

-- bounds the scrollOffset of the container to the desired value between 0 and -maxScrollOffset
---@param value number desired scrollOffset value
function ScrollContainer:setScrollOffset(value)
  self.scrollOffset = util.bound(-self.maxScrollOffset, value, 0)
  self.keepOffset, self.keepSize, self.keepChild = nil, nil, nil
  self:markLayoutDirty()
end

-- update the scroll offset so the element with passed scroll offset + size remains visible
-- usually we want a cursor type of object to call this on move to automatically advance the scrollContainer
-- The next layout scrolls, once the container's size is known.
---@param offset number the offset of the element to be kept visible
---@param size number the size of the element to be kept visible
function ScrollContainer:keepVisible(offset, size)
  self.keepOffset, self.keepSize, self.keepChild = offset, size, nil
  self:markLayoutDirty()
end

-- Has the next layout scroll so the child in the flow is fully visible
---@param child UiElement
function ScrollContainer:keepChildVisible(child)
  self.keepOffset, self.keepSize, self.keepChild = nil, nil, child
  self:markLayoutDirty()
end

-- Scrolls just far enough that the area at the offset with the size is visible
---@param offset number the area's offset, negative, as keepVisible takes it
---@param size number the area's size
---@param refSize number the container's size along the orientation
function ScrollContainer:scrollToShow(offset, size, refSize)
  -- with increasing negative value we scroll further down/right
  if self.scrollOffset - refSize > offset - size then
    self.scrollOffset = offset - size + refSize
  elseif offset > self.scrollOffset then
    self.scrollOffset = offset
  end
end

-- Works out the scroll along the orientation from the children in the flow placed unscrolled: far enough to show what
-- keepVisible or keepChildVisible asked for, and no further than the content reaches
---@param axis table LayoutSolver.X_AXIS or LayoutSolver.Y_AXIS
---@return number
function ScrollContainer:getChildOffset(axis)
  local vertical = self.scrollOrientation == "vertical"
  if (axis == LayoutSolver.Y_AXIS) ~= vertical then
    return 0
  end
  local position, size = "x", "width"
  if vertical then
    position, size = "y", "height"
  end
  local reach = 0
  for _, child in ipairs(self.children) do
    if child.layoutRules.floating == nil then
      local rect = child.layoutRect
      reach = math.max(reach, rect[position] + rect[size])
    end
  end
  local refSize = self.layoutRect[size]
  self.maxScrollOffset = math.max(0, reach - refSize)
  if self.keepOffset then
    self:scrollToShow(self.keepOffset, self.keepSize, refSize)
  elseif self.keepChild and self.keepChild.parent == self then
    local rect = self.keepChild.layoutRect
    self:scrollToShow(-rect[position], rect[size], refSize)
  end
  self.keepOffset, self.keepSize, self.keepChild = nil, nil, nil
  self.scrollOffset = util.bound(-self.maxScrollOffset, self.scrollOffset, 0)
  return self.scrollOffset
end

-- scrolls by the mouse wheel's movement, a positive y moving the content down to reveal what is above
---@param dx number
---@param dy number
function ScrollContainer:onScroll(dx, dy)
  if self.scrollOrientation == "vertical" then
    self:setScrollOffset(self.scrollOffset + dy * ScrollContainer.SCROLL_STEP)
  else
    self:setScrollOffset(self.scrollOffset + dx * ScrollContainer.SCROLL_STEP)
  end
end

function ScrollContainer:onTouch(x, y)
  local realTouchedElement = self:getTouchedChildElement(x, y)
  if realTouchedElement then
    self.touchedChild = realTouchedElement
    if self.touchedChild.onTouch then
      self.touchedChild:onTouch(x, y)
    end
  else
    self.scrolling = true
    self.initialTouchX = x
    self.initialTouchY = y
    self.originalOffset = self.scrollOffset
  end
end

function ScrollContainer:onDrag(x, y)
  if not self.touchedChild then
    if self.scrollOrientation == "vertical" then
      self:setScrollOffset(self.originalOffset + (y - self.initialTouchY))
    elseif self.scrollOrientation == "horizontal" then
      self:setScrollOffset(self.originalOffset + (x - self.initialTouchX))
    end
  elseif self.touchedChild.onDrag then
    self.touchedChild:onDrag(x, y)
  end
end

function ScrollContainer:onRelease(x, y, duration)
  if not self.touchedChild then
    self:onDrag(x, y)
    self.scrolling = false
  else
    if self.touchedChild.onRelease then
      self.touchedChild:onRelease(x, y)
    end
    self.touchedChild = nil
  end
end

-- Draws an arrow on each side the content continues past; the children are drawn clipped to the container
function ScrollContainer:drawSelf()
  if self.maxScrollOffset > 0 then
    local fontSize = GraphicsUtil.fontSize
    local width, height = self.layoutRect.width, self.layoutRect.height
    if self.scrollOrientation == "vertical" then
      if self.scrollOffset < 0 then
        GraphicsUtil.print("^", width / 2 - fontSize / 2, -20)
      end
      if math.abs(self.scrollOffset) < self.maxScrollOffset then
        GraphicsUtil.print("v", width / 2 - fontSize  / 2, height + 8)
      end
    else
      if self.scrollOffset < 0 then
        GraphicsUtil.print("<", -20, height / 2 - fontSize / 2)
      end
      if math.abs(self.scrollOffset) < self.maxScrollOffset then
        GraphicsUtil.print(">", width + 8, height / 2 - fontSize / 2)
      end
    end
  end
end

-- overwrite the default callback to always return itself so the class can act as an intermediator
-- because any children that are offscreen at scrollOffset 0 cannot get hit by the default touchhandler without translating touch coordinates
function ScrollContainer:getTouchedElement(x, y)
  if self.isVisible and self.isEnabled and UiElement.inBounds(self, x, y) then
    return self
  end
end

-- the child under the touch; the children's layout rects already include the scroll offset
function ScrollContainer:getTouchedChildElement(x, y)
  local touchedElement
  for i = 1, #self.children do
    touchedElement = self.children[i]:getTouchedElement(x, y)
    if touchedElement then
      return touchedElement
    end
  end
end

-- Replaces the children with the element; the next layout keeps the scroll offset within the new content
---@param uiElement UiElement
function ScrollContainer:setContent(uiElement)
  while #self.children > 0 do
    self.children[1]:detach()
  end
  self:addChild(uiElement)
end

-- adds the uiElement; how far the content reaches is unknown until the next layout works it out
function ScrollContainer:addChild(uiElement)
  UiElement.addChild(self, uiElement)
  self.maxScrollOffset = math.huge
end

return ScrollContainer
