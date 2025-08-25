local PATH = (...):gsub('%.[^%.]+$', '')
local UIElement = require(PATH .. ".UIElement")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local consts = require("common.engine.consts")

---@class MultibarElementOptions : UiElementOptions
---@field stack ClientStack The client stack to get multibar data from
---@field framePos {[1]: number, [2]: number} Frame position offset relative to element
---@field barPos {[1]: number, [2]: number} Bar position offset relative to element
---@field overtimePos {[1]: number, [2]: number} Overtime text position offset relative to element
---@field frameScale number Scale for the frame
---@field barScale number Scale for the bars
---@field overtimeDecimals number Decimals for overtime display

---@class MultibarElement : UiElement
---@field stack ClientStack
---@field framePos {[1]: number, [2]: number}
---@field barPos {[1]: number, [2]: number}
---@field overtimePos {[1]: number, [2]: number}
---@field frameScale number
---@field barScale number
---@field overtimeDecimals number
---@field frameAsset love.Drawable
---@field healthAsset love.Drawable
---@field shakeAsset love.Drawable
---@field stopAsset love.Drawable
---@field preStopAsset love.Drawable
---@field healthQuad love.Quad
---@field shakeQuad love.Quad
---@field stopQuad love.Quad
---@field preStopQuad love.Quad
---@field multiBarFrameCount number
---@field multiBarMaxHeight number
---@overload fun(options: MultibarElementOptions): MultibarElement
local MultibarElement = class(
  function(self, options)
    self.stack = options.stack
    
    -- Store position offsets
    self.framePos = options.framePos
    self.barPos = options.barPos
    self.overtimePos = options.overtimePos
    
    -- Store scale values
    self.frameScale = options.frameScale
    self.barScale = options.barScale
    self.overtimeDecimals = options.overtimeDecimals
    
    -- Get assets from stack
    self.frameAsset = self.stack.assets.multibar.frameAbsolute
    self.healthAsset = self.stack.assets.multibar.health
    self.shakeAsset = self.stack.assets.multibar.shake
    self.stopAsset = self.stack.assets.multibar.stop
    self.preStopAsset = self.stack.assets.multibar.preStop
    
    local width, height = self.healthAsset:getDimensions()
    self.healthQuad = GraphicsUtil:newRecycledQuad(0, 0, width, height, width, height)
    width, height = self.preStopAsset:getDimensions()
    self.preStopQuad = GraphicsUtil:newRecycledQuad(0, 0, width, height, width, height)
    width, height = self.stopAsset:getDimensions()
    self.stopQuad = GraphicsUtil:newRecycledQuad(0, 0, width, height, width, height)
    width, height = self.shakeAsset:getDimensions()
    self.shakeQuad = GraphicsUtil:newRecycledQuad(0, 0, width, height, width, height)
    self.multiBarFrameCount = self.stack.multiBarFrameCount
    self.multiBarMaxHeight = 589 * (self.stack.gfxScale / 3) * self.barScale
    self.leftoverTimeDecimals = self.overtimeDecimals
    
    -- Might need to autosize the width and height better later
    if not options.width then
      options.width = 100
    end
    if not options.height then
      options.height = self.multiBarMaxHeight + 50
    end
  end,
  UIElement
)
MultibarElement.TYPE = "MultibarElement"

---Draws a bar at the specified relative position within the element
---@param image love.Drawable The bar image
---@param quad love.Quad The quad for the bar
---@param relativeBarPos {[1]: number, [2]: number} Position relative to the element
---@param height number Height of the bar
---@param yOffset number Y offset from the bottom
---@param rotate number Rotation (unused)
---@param scale number Scale factor
function MultibarElement:drawBar(image, quad, relativeBarPos, height, yOffset, rotate, scale)
  local imageWidth, imageHeight = image:getDimensions()
  local barYScale = height / imageHeight
  local quadY = 0
  if barYScale < 1 then
    barYScale = 1
    quadY = imageHeight - height
  end
  
  local elementX = self.x or 0
  local elementY = self.y or 0
  local x = elementX + relativeBarPos[1]
  local y = elementY + relativeBarPos[2]
  
  quad:setViewport(0, quadY, imageWidth, imageHeight - quadY)
  
  GraphicsUtil.drawQuad(image, quad, x, y - height - yOffset, rotate, scale, scale * barYScale, 0, 0, self.stack.mirror_x)
end

---Draws a label at the specified relative position within the element
---@param drawable love.Drawable The drawable to render
---@param relativePos {[1]: number, [2]: number} Position relative to the element
---@param scale number Scale factor
function MultibarElement:drawLabel(drawable, relativePos, scale)
  local elementX = self.x or 0
  local elementY = self.y or 0
  local x = elementX + relativePos[1]
  local y = elementY + relativePos[2]
  GraphicsUtil.draw(drawable, x, y, 0, scale, scale)
end

---Draws a string at the specified relative position within the element
---@param text string The text to draw
---@param relativePos {[1]: number, [2]: number} Position relative to the element
---@param fontSize number Font size
function MultibarElement:drawString(text, relativePos, fontSize)
  local elementX = self.x or 0
  local elementY = self.y or 0
  local x = elementX + relativePos[1]
  local y = elementY + relativePos[2]
  
  if fontSize == nil then
    fontSize = GraphicsUtil.fontSize
  end
  local fontDelta = fontSize - GraphicsUtil.fontSize
  local limit = consts.CANVAS_WIDTH - x
  local alignment = "left"
  
  GraphicsUtil.printf(text, x, y, limit, alignment, nil, nil, fontDelta)
end

---Draws the multibar with all its components
---@param stop_time number Stop time in frames
---@param shake_time number Shake time in frames
---@param pre_stop_time number Pre-stop time in frames
function MultibarElement:drawMultibar(stop_time, shake_time, pre_stop_time)
  local relativeFramePos = self.framePos
  local relativeBarPos = self.barPos
  local relativeOvertimePos = self.overtimePos
  
  -- Draw frame
  self:drawLabel(self.frameAsset, relativeFramePos, self.frameScale * (self.stack.gfxScale / 3))

  local bottomOffset = 0

  -- Draw health bar
  local healthHeight = (self.stack.engine.health / self.multiBarFrameCount) * self.multiBarMaxHeight
  healthHeight = math.min(healthHeight, self.multiBarMaxHeight)
  self:drawBar(self.healthAsset, self.healthQuad, relativeBarPos, healthHeight, 0, 0, self.barScale)

  bottomOffset = healthHeight

  local stopHeight = 0
  local preStopHeight = 0

  if shake_time > 0 and shake_time > (stop_time + pre_stop_time) then
    -- shake is only drawn if it is greater than prestop + stop
    -- shake is always guaranteed to fit
    local shakeHeight = (shake_time / self.multiBarFrameCount) * self.multiBarMaxHeight
    self:drawBar(self.shakeAsset, self.shakeQuad, relativeBarPos, shakeHeight, bottomOffset, 0, self.barScale)
  else
    -- stop/prestop are only drawn if greater than shake
    if stop_time > 0 then
      stopHeight = math.min(stop_time, self.multiBarFrameCount - self.stack.engine.health) / self.multiBarFrameCount * self.multiBarMaxHeight
      self:drawBar(self.stopAsset, self.stopQuad, relativeBarPos, stopHeight, bottomOffset, 0, self.barScale)

      bottomOffset = bottomOffset + stopHeight
    end

    local totalInvincibility = self.stack.engine.health + stop_time + pre_stop_time
    local remainingSeconds = 0
    if totalInvincibility > self.multiBarFrameCount then
      -- total invincibility exceeds what the multibar can display -> fill only the remaining space with prestop
      preStopHeight = (1 - (self.stack.engine.health + stop_time) / self.multiBarFrameCount) * self.multiBarMaxHeight
      remainingSeconds = (totalInvincibility - self.multiBarFrameCount) / 60
    else
      preStopHeight = pre_stop_time / self.multiBarFrameCount * self.multiBarMaxHeight
    end

    if pre_stop_time and pre_stop_time > 0 then
      self:drawBar(self.preStopAsset, self.preStopQuad, relativeBarPos, preStopHeight, bottomOffset, 0, self.barScale)
    end

    if remainingSeconds > 0 then
      self:drawString(string.format("%." .. self.leftoverTimeDecimals .. "f", remainingSeconds), relativeOvertimePos, 20)
    end
  end
end

function MultibarElement:drawSelf()
  local stop_time = self.stack.engine.stop_time or 0
  local shake_time = self.stack.engine.shake_time or 0
  local pre_stop_time = self.stack.engine.pre_stop_time or 0
  self:drawMultibar(stop_time, shake_time, pre_stop_time)
end

return MultibarElement