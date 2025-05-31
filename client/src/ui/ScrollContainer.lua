local import = require("common.lib.import")
local UiElement = import("./UIElement")
local class = require("common.lib.class")
local util = require("common.lib.util")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local logger = require("common.lib.logger")
local VerticalScrollLayout = import("./Layouts.VerticalScrollLayout")
local HorizontalScrollLayout = import("./Layouts.HorizontalScrollLayout")

---@class ScrollContainerOptions : UiElementOptions
---@field scrollOrientation ("vertical" | "horizontal" | nil)

---@class ScrollContainer : UiElement
---@operator call(ScrollContainerOptions): ScrollContainer
---@field scrollOrientation string "vertical" or "horizontal"
---@field scrollOffset number by how many pixels the children are translated in the orientation
---@field maxScrollOffset number maximum allowed value for scrollOffset the object will bound to
---@overload fun(options: ScrollContainerOptions): ScrollContainer
---@type ScrollContainer
local ScrollContainer = class(
---@param self ScrollContainer
function(self, options)
  self.scrollOrientation = options.scrollOrientation or "vertical"
  if self.scrollOrientation == "vertical" then
    self.layout = VerticalScrollLayout
  else
    self.layout = HorizontalScrollLayout
  end
  self.scrollOffset = 0
  self.maxScrollOffset = 0
end,
UiElement)
ScrollContainer.TYPE = "ScrollContainer"

-- bounds the scrollOffset of the container to the desired value between 0 and -maxScrollOffset
---@param value number desired scrollOffset value
function ScrollContainer:setScrollOffset(value)
  logger.debug("Firing ScrollContainer.setScrollOffset " .. tostring(value))
  logger.debug("maxScrollOffset " .. tostring(self.maxScrollOffset))
  self.scrollOffset = util.bound(-self.maxScrollOffset, value, 0)
end

-- update the scroll offset so the element with passed scroll offset + size remains visible
-- usually we want a cursor type of object to call this on move to automatically advance the scrollContainer
---@param cursor Cursor
function ScrollContainer:keepVisible(cursor)
  local hoveredElement = cursor.focusToHover[self]
  local offset -- the offset of the element to be kept visible
  local size -- the size of the element to be kept visible
  local refSize
  if self.scrollOrientation == "horizontal" then
    offset = hoveredElement.x
    size = hoveredElement.width
    refSize = self.width
  else
    offset = hoveredElement.y
    size = hoveredElement.height
    refSize = self.height
  end
  logger.debug("Firing ScrollContiner.keepVisible")
  -- weird implementation detail that with scrolling scrolloffset goes negative
  -- childGap is added to guarantee some whitespace if the container is built around it
  offset = -offset + self.childGap / 2
  size = size + self.childGap
  -- with increasing negative value we scroll further down/right

  if self.scrollOffset - refSize > offset - size then
    self:setScrollOffset(offset - size + refSize)
  elseif offset > self.scrollOffset then
    self:setScrollOffset(offset)
  end
end

-- returns the touch coordinates translated by the current scrollOffset
local function getTranslatedOffset(scrollContainer, x, y)
  local translatedX, translatedY = x, y
  if scrollContainer.scrollOrientation == "vertical" then
    translatedY = translatedY - scrollContainer.scrollOffset
  else
    translatedX = translatedX - scrollContainer.scrollOffset
  end
  return translatedX, translatedY
end

function ScrollContainer:onTouch(x, y)
  logger.debug("Firing ScrollContainer.onTouch")
  self.initialTouchX = x
  self.initialTouchY = y
  logger.debug("initialTouchY: " .. self.initialTouchY)
  self.originalOffset = self.scrollOffset
  logger.debug("originalOffset: " .. self.originalOffset)

  local realTouchedElement = self:getTouchedChildElement(x, y)
  if realTouchedElement then
    self.touchedChild = realTouchedElement
    if self.touchedChild.onTouch then
      self.touchedChild:onTouch(x, y)
    end
  end
end

function ScrollContainer:onDrag(x, y)
  logger.debug("Firing ScrollContainer.onDrag")
  logger.debug("y: " .. y)
  if not self.touchedChild or not self.touchedChild.onDrag then
    if self.scrollOrientation == "vertical" then
      self:setScrollOffset(self.originalOffset + (y - self.initialTouchY))
    elseif self.scrollOrientation == "horizontal" then
      self:setScrollOffset(self.originalOffset + (x - self.initialTouchX))
    end
  else
    self.touchedChild:onDrag(x, y)
  end
end

function ScrollContainer:onRelease(x, y, duration)
  logger.debug("Firing ScrollContainer.onRelease")
  self:onDrag(x, y)

  if self.touchedChild then
    if self.touchedChild.onRelease then
      self.touchedChild:onRelease(x, y)
    end
    self.touchedChild = nil
  end
end

local loveMajor = love.getVersion()

function ScrollContainer:draw()
  if self.isVisible then
    UiElement.drawSelf(self)
    -- make a stencil according to width/height
    if loveMajor >= 12 then
      love.graphics.setStencilMode("draw", 1)
      love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
      love.graphics.setStencilMode("test", 1)
    else
      -- the scrollcontainer props could theoretically change every frame so we need to recreate the closure every time
      local stencilFunction = function()
        love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
      end
      love.graphics.stencil(stencilFunction, "replace", 1)
      love.graphics.setStencilTest("greater", 0)
    end

    love.graphics.push("transform")
    -- do an extra translate to account for the scroll offset
    if self.scrollOrientation == "vertical" then
      love.graphics.translate(self.x, self.y + self.scrollOffset)
    else
      love.graphics.translate(self.x + self.scrollOffset, self.y)
    end
    -- and then just render everything
    -- by combining stencil + translate only the elements positioned within the stencil after the translate get drawn
    self:drawChildren()
    love.graphics.pop()
    -- clean up the stencil
    if loveMajor >= 12 then
      love.graphics.setStencilMode()
    else
      love.graphics.setStencilTest()
    end

    if self.maxScrollOffset > 0 then
      local fontSize = GraphicsUtil.getEffectiveFontSize("normal")
      if self.scrollOrientation == "vertical" then
        if self.scrollOffset < 0 then
          GraphicsUtil.print("^", self.x + self.width / 2 - fontSize / 2, self.y - 20)
        end
        if math.abs(self.scrollOffset) < self.maxScrollOffset then
          GraphicsUtil.print("v", self.x + self.width / 2 - fontSize  / 2, self.y + self.height + 8)
        end
      else
        if self.scrollOffset < 0 then
          GraphicsUtil.print("<", self.x - 20, self.y + self.height / 2 - fontSize / 2)
        end
        if math.abs(self.scrollOffset) < self.maxScrollOffset then
          GraphicsUtil.print(">", self.x + self.width + 8, self.y + self.height / 2 - fontSize / 2)
        end
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

-- in order for the "offscreen" children to pass the inBounds check, the touch coordinates get corrected by the scroll offset before recursing down the ui
function ScrollContainer:getTouchedChildElement(x, y)
  local touchedElement
  for i = 1, #self.children do
    touchedElement = self.children[i]:getTouchedElement(x, y)
    if touchedElement then
      return touchedElement
    end
  end
end

function ScrollContainer:recalculateMaxScrollOffset()
  local lastChild = self.children[#self.children]
  if lastChild then
    if self.scrollOrientation == "vertical" then
      self.maxScrollOffset = math.max(0, lastChild.y + lastChild.height - self.height + self.padding)
    else
      self.maxScrollOffset = math.max(0, lastChild.x + lastChild.width - self.width + self.padding)
    end
  else
    self.maxScrollOffset = 0
  end
end

function ScrollContainer:onResized()
  self:recalculateMaxScrollOffset()
end

function ScrollContainer:getPreferredWidth()
  return self.minWidth
end

---@param whoIsAsking table?
---@return integer x
---@return integer y
function ScrollContainer:getScreenPos(whoIsAsking)
  local x, y = 0, 0
  if self.parent then
    x, y = self.parent:getScreenPos(self)
  end

  x = x + self.x
  y = y + self.y

  -- for children the scrolloffset needs to be applied, otherwise not;
  -- as whoIsAsking is recursively calling upwards, whoIsAsking will be a direct child even if the call originates from further down in the tree
  if whoIsAsking and whoIsAsking.parent and whoIsAsking.parent == self then
    local xOffset, yOffset = getTranslatedOffset(self, 0, 0)
    x = x - xOffset
    y = y - yOffset
  end

  return x, y
end

return ScrollContainer