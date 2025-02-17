local PATH = (...):gsub('%.[^%.]+$', '')
local UIElement = require(PATH .. ".UIElement")
local class = require("common.lib.class")
local util = require("common.lib.util")
local GraphicsUtil = require("client.src.graphics.graphics_util")

local handleRadius = 7.5
local xPadding = 8
local yPadding = 2
local valueBackgroundPaddingX = 2
local valueBackgroundPaddingY = -1 -- textHeight isn't a tight bounds
local sliderBarThickness = 6

local Slider = class(
  function(self, options)
    self.min = options.min or 1
    self.max = options.max or 99
    -- pixels per value change
    self.tickLength = options.tickLength or 1
    self.tickAmount = options.tickAmount or 1
    self.onValueChange = options.onValueChange or function() end
    local value = options.value or math.floor((self.max - self.min) / 2)
    self.value = self:getBoundedValue(value) -- don't use set value as not everything is setup yet
    self.onlyChangeOnRelease = options.onlyChangeOnRelease or false
    
    self.minText = GraphicsUtil.newText(love.graphics.getFont(), self.min)
    self.maxText = GraphicsUtil.newText(love.graphics.getFont(), self.max)
    self.valueText = GraphicsUtil.newText(love.graphics.getFont(), self.value)

    local valueTextWidth, valueTextHeight = self.valueText:getDimensions()
    local textWidth, textHeight = self.maxText:getDimensions()
    self.width = self.tickLength * self:tickCount() + xPadding + math.max(xPadding, textWidth / 2)
    self.height = yPadding * 2 + handleRadius * 2 + valueTextHeight + textHeight
    
    self.TYPE = "Slider"
  end,
  UIElement
)

function Slider:onTouch(x, y)
  self:setValueFromPos(x, false)
end

function Slider:onDrag(x, y)
  self:setValueFromPos(x, false)
end

function Slider:onRelease(x, y)
  self:setValueFromPos(x, true)
end

function Slider:receiveInputs(input)
  if input:isPressedWithRepeat("Left") then
    self:setValue(self.value - self.tickAmount, true)
  elseif input:isPressedWithRepeat("Right") then
    self:setValue(self.value + self.tickAmount, true)
  elseif self.isFocusable and (input.isDown["Swap2"] or input.isDown["Swap1"]) then
    self:yieldFocus()
  end
end

function Slider:getBoundedValue(value)
  local v = math.round((value - self.min) / self.tickAmount) * self.tickAmount + self.min
  v = util.bound(self.min, v, self.max)
  return v
end

function Slider:getValueForPos(x)
  local screenX, screenY = self:getScreenPos()
  local v = self:getBoundedValue((x - (screenX + xPadding)) / self.tickLength * self.tickAmount + self.min)
  return v
end

function Slider:getCurrentXForValue()
  local v = self.x + xPadding + (self.value - self.min) * self.tickLength / self.tickAmount
  return v
end

function Slider:setValueFromPos(x, committed)
  self:setValue(self:getValueForPos(x), committed)
end

function Slider:setValue(value, committed)
  self.value = util.bound(self.min, value, self.max)
  self.valueText:set(self.value)
  if committed or self.onlyChangeOnRelease == false then
    self:onValueChange()
  end
end

-- Ticks are 0 indexed
function Slider:tickCount()
  return (self.max - self.min) / self.tickAmount
end

function Slider:currentTickForValue()
  local currentTick = math.round(self.value - self.min) * self.tickAmount
  return currentTick
end

local SLIDER_CIRCLE_COLOR = {0.5, 0.5, 1, 0.8}
function Slider:drawSelf()
  local valueTextWidth, valueTextHeight = self.valueText:getDimensions()

  local gray = .5
  local lightGray = .65
  local alpha = .7
  local barWidth = self:tickCount() * self.tickLength
  local currentX = self:getCurrentXForValue()

  -- Slider bar
  GraphicsUtil.setColor(gray, gray, gray, alpha)
  GraphicsUtil.drawRectangle("fill", self.x + xPadding, self.y + yPadding + valueTextHeight, barWidth, sliderBarThickness)

  -- Slider circle
  GraphicsUtil.setColor(unpack(SLIDER_CIRCLE_COLOR))
  love.graphics.circle("fill", currentX, self.y + yPadding + valueTextHeight + sliderBarThickness / 2, handleRadius, 32)
  
  -- Value background
  GraphicsUtil.setColor(gray, gray, gray, alpha)
  GraphicsUtil.drawRectangle("fill", currentX - valueTextWidth / 2 - valueBackgroundPaddingX, self.y + yPadding - valueBackgroundPaddingY, valueTextWidth + valueBackgroundPaddingX*2, valueTextHeight + valueBackgroundPaddingY*2)
  
  -- Value centered at top
  GraphicsUtil.setColor(1, 1, 1, 1)
  GraphicsUtil.draw(self.valueText, currentX - valueTextWidth / 2, self.y + yPadding, 0, 1, 1, 0, 0)

  GraphicsUtil.setColor(lightGray, lightGray, lightGray, 1)

  local textWidth, textHeight = self.minText:getDimensions()
  GraphicsUtil.draw(self.minText, self.x + xPadding - textWidth / 2, self.y + yPadding + sliderBarThickness + textHeight, 0, 1, 1, 0, 0)

  textWidth, textHeight = self.maxText:getDimensions()
  GraphicsUtil.draw(self.maxText, self.x + xPadding + barWidth - textWidth / 2, self.y + yPadding + sliderBarThickness + textHeight, 0, 1, 1, 0, 0)

  GraphicsUtil.setColor(1, 1, 1, 1)

end

return Slider
