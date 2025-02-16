local PATH = (...):gsub('%.[^%.]+$', '')
local UIElement = require(PATH .. ".UIElement")
local class = require("common.lib.class")
local util = require("common.lib.util")
local GraphicsUtil = require("client.src.graphics.graphics_util")

local handleRadius = 7.5

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

    self.width = self.tickLength * self:tickCount() + 2
    self.height = handleRadius * 2 + 12 -- magic
    
    self.TYPE = "Slider"
  end,
  UIElement
)

local sliderYOffset = 15
local textYOffset = 0
local sliderBarThickness = 5

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
  local v = self:getBoundedValue((x - screenX) / self.tickLength * self.tickAmount + self.min)
  return v
end

function Slider:getCurrentXForValue()
  local v = self.x + (self.value - self.min) * self.tickLength / self.tickAmount
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
  local light_gray = .5
  local alpha = .7
  local barWidth = self:tickCount() * self.tickLength
  GraphicsUtil.setColor(light_gray, light_gray, light_gray, alpha)
  GraphicsUtil.drawRectangle("fill", self.x, self.y + sliderYOffset, barWidth, sliderBarThickness)

  GraphicsUtil.setColor(unpack(SLIDER_CIRCLE_COLOR))
  local x = self:getCurrentXForValue()
  love.graphics.circle("fill", x, self.y + sliderYOffset + sliderBarThickness / 2, handleRadius, 32)
  GraphicsUtil.setColor(1, 1, 1, 1)

  local textWidth, textHeight = self.minText:getDimensions()
  GraphicsUtil.draw(self.minText, self.x - textWidth * .3, self.y + textYOffset, 0, 1, 1, 0, 0)

  textWidth, textHeight = self.maxText:getDimensions()
  GraphicsUtil.draw(self.maxText, self.x + barWidth - textWidth, self.y + textYOffset, 0, 1, 1, 0, 0)

  textWidth, textHeight = self.valueText:getDimensions()
  GraphicsUtil.draw(self.valueText, self.x + (barWidth / 2.0) - textWidth / 2, self.y + textYOffset, 0, 1, 1, 0, 0)
end

return Slider
