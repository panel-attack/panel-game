local PATH = (...):gsub('%.[^%.]+$', '')

local UiElement = require(PATH .. ".UIElement")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local DebugSettings = require("client.src.debug.DebugSettings")

---@class BoolSelectorOptions : UiElementOptions
---@field startValue boolean?

--- A BoolSelector is a UIElement that shows if a setting is on or off and lets you toggle it.
---@class BoolSelector : UiElement
---@field value boolean
---@field vertical boolean
---@field circleRadius number
---@field extraDistance number
---@field lengthPadding number
---@field widthPadding number
local BoolSelector = class(function(self, options)
  self.value = options.startValue or false
  self.vertical = false
  self.circleRadius = 10
  self.extraDistance = 16
  self.lengthPadding = 2
  self.widthPadding = 2
  self.onValueChange = options.onValueChange or function() end

  -- Calculate initial dimensions
  self.width = self:calculateWidth()
  self.height = self:calculateHeight()
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

---@return number
function BoolSelector:calculateWidth()
  local width = self.circleRadius * 2 + 2 * self.widthPadding
  if not self.vertical then
    width = width + self.extraDistance
  end
  return width
end

---@return number
function BoolSelector:calculateHeight()
  local height = self.circleRadius * 2 + 2 * self.lengthPadding
  if self.vertical then
    height = height + self.extraDistance
  end
  return height
end

-- other code may implement a callback here
-- function BoolSelector.onValueChange() end

function BoolSelector:drawSelf()
  if DebugSettings.showUIElementBorders() then
    GraphicsUtil.setColor(0, 0, 1, 1)
    GraphicsUtil.drawRectangle("line", self.x + 1, self.y + 1, self.width - 2, self.height - 2)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end

  local drawX = self.x + self.widthPadding
  local drawY = self.y + self.lengthPadding
  local drawWidth = self.width - 2 * self.widthPadding
  local drawHeight = self.height - 2 * self.lengthPadding

  local circleX = self.circleRadius
  local circleY = self.circleRadius

  if self.vertical then
    if self.value == false then
      circleY = circleY + self.extraDistance
    end
  else
    if self.value then
      circleX = circleX + self.extraDistance
    end
  end

  if self.value then
    GraphicsUtil.setColor(30/255, 190/255, 67/255, 1)
    GraphicsUtil.drawRectangle("fill", drawX, drawY, drawWidth, drawHeight, nil, nil, nil, nil, self.circleRadius, self.circleRadius)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end

  GraphicsUtil.drawRectangle("line", drawX, drawY, drawWidth, drawHeight, nil, nil, nil, nil, self.circleRadius, self.circleRadius)
  love.graphics.circle("fill", drawX + circleX, drawY + circleY, self.circleRadius)
end

return BoolSelector