local UiElement = require("client.src.ui.UIElement")
local class = require("common.lib.class")
local util = require("common.lib.util")

local ScrollContainer = class(function(self, options)
  self.scrollOrientation = "vertical" or options.scrollOrientation
  self.scrollStepSize = options.scrollStepSize
  self.scrollOffset = 0
  self.maxScrollOffset = 0
  self.TYPE = "ScrollContainer"
end,
UiElement)

-- 
function ScrollContainer:setScrollOffset(value)
  self.scrollOffset = util.bound(-self.maxScrollOffset, value, 0)
end

-- update the scroll offset so the element with passed scroll offset + size remains visible
function ScrollContainer:keepVisible(offset, size)
  -- with increasing negative value we scroll further down/right
  local refSize
  if self.scrollOrientation == "vertical" then
    refSize = self.height
  else
    refSize = self.width
  end
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
  local realTouchedElement = self:getTouchedChildElement(x, y)
  if realTouchedElement then
    self.touchedChild = realTouchedElement
    if self.touchedChild.onTouch then
      x, y = getTranslatedOffset(self, x, y)
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
    x, y = getTranslatedOffset(self, x, y)
    self.touchedChild:onDrag(x, y)
  end
end

function ScrollContainer:onRelease(x, y, duration)
  if not self.touchedChild then
    self:onDrag(x, y)
    self.scrolling = false
  else
    if self.touchedChild.onRelease then
      x, y = getTranslatedOffset(self, x, y)
      self.touchedChild:onRelease(x, y)
    end
    self.touchedChild = nil
  end
end

function ScrollContainer:draw()
  if self.isVisible then
    -- make a stencil according to width/height
    love.graphics.setStencilMode("draw", 1)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.setStencilMode("test", 1)

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
    love.graphics.setStencilMode()
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
  x, y = getTranslatedOffset(self, x, y)
  local touchedElement
  for i = 1, #self.children do
    touchedElement = self.children[i]:getTouchedElement(x, y)
    if touchedElement then
      return touchedElement
    end
  end
end

function ScrollContainer:addChild(uiElement)
  UiElement.addChild(self, uiElement)
  if self.scrollOrientation == "vertical" then
    self.maxScrollOffset = math.max(self.maxScrollOffset, (uiElement.y + uiElement.height) - self.height)
  else
    self.maxScrollOffset = math.max(self.maxScrollOffset, (uiElement.x + uiElement.width) - self.width)
  end
end

return ScrollContainer