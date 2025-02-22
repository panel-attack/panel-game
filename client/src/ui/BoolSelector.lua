local PATH = (...):gsub('%.[^%.]+$', '')

local UiElement = require(PATH .. ".UIElement")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")

---@class BoolSelectorOptions : UiElementOptions
---@field startValue boolean?

--- A BoolSelector is a UIElement that shows if a setting is on or off and lets you toggle it.
---@class BoolSelector : UiElement
---@field value boolean
---@field vertical boolean
local BoolSelector = class(function(boolSelector, options)
  boolSelector.value = options.startValue or false
  boolSelector.vertical = false
end,
UiElement)

BoolSelector.TYPE = "BoolSelector"

function BoolSelector:onTouch(x, y)
end

function BoolSelector:onRelease(x, y)
  self:setValue(not self.value)
end


function BoolSelector:onSelect(boolSelector, selector)
  self:setValue(not self.value)
end

function BoolSelector:receiveInputs(input)
  if self.isFocusable then
    if (input:isPressedWithRepeat("Right") and self.vertical == false) or
        (input:isPressedWithRepeat("Up") and self.vertical) then
        self:setValue(true)
    elseif (input:isPressedWithRepeat("Left") and self.vertical == false) or
    (input:isPressedWithRepeat("Down") and self.vertical) then
      self:setValue(false)
    elseif input.isDown["Swap1"] then
      GAME.theme:playValidationSfx()
      self:yieldFocus()
    elseif input.isDown["Swap2"] then
      GAME.theme:playCancelSfx()
      self:yieldFocus()
    end
  else 
    if input.isDown["Swap1"] then
      GAME.theme:playValidationSfx()
      self:setValue(not self.value)
    end
  end
end

function BoolSelector:setValue(value)
  local old = self.value
  self.value = value
  if old ~= value and self.onValueChange then
    self:onValueChange(self.value)
  end
end

-- other code may implement a callback here
-- function BoolSelector.onValueChange() end

local circleRadius = 10
local extraDistance = 16
local lengthPadding = 2
local widthPadding = 2
local totalWidth = 0
local totalLength = 0
local fakeCenteredChild = {hAlign = "center", vAlign = "center", width = totalWidth, height = totalLength}

function BoolSelector:drawSelf()
  if DEBUG_ENABLED then
    GraphicsUtil.setColor(0, 0, 1, 1)
    GraphicsUtil.drawRectangle("line", self.x + 1, self.y + 1, self.width - 2, self.height - 2)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end

  local circleX = circleRadius + widthPadding
  local circleY = circleRadius + lengthPadding
  totalWidth = circleRadius * 2 + 2 * widthPadding
  totalLength = circleRadius * 2 + 2 * lengthPadding
  if self.vertical then
    totalLength = totalLength + extraDistance
    if self.value == false then
      circleY = circleY + extraDistance
    end
  else
    totalWidth = totalWidth + extraDistance
    if self.value then
      circleX = circleX + extraDistance
    end
  end
  fakeCenteredChild.width = totalWidth
  fakeCenteredChild.height = totalLength

  -- we want these to be centered but creating a Rectangle / Circle ui element is maybe a bit too much?
  -- so just apply the translation via a fake element with all necessary props
  GraphicsUtil.applyAlignment(self, fakeCenteredChild)
  love.graphics.translate(self.x, self.y)

  if self.value then
    GraphicsUtil.setColor(30/255, 190/255, 67/255, 1)
    GraphicsUtil.drawRectangle("fill", 0, 0, totalWidth, totalLength, nil, nil, nil, nil, circleRadius, circleRadius)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end

  GraphicsUtil.drawRectangle("line", 0, 0, totalWidth, totalLength, nil, nil, nil, nil, circleRadius, circleRadius)
  love.graphics.circle("fill", circleX, circleY, circleRadius)

  GraphicsUtil.resetAlignment()
end

function BoolSelector:getTouchedElement(x, y)
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

return BoolSelector