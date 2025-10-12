local PATH = (...):gsub('%.[^%.]+$', '')
local UiElement = require(PATH .. ".UIElement")
local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local GraphicsUtil = require("client.src.graphics.graphics_util")

-- StackElement is an element that draws a player stack
-- Useful for previewing stacks or other effects on the player board
---@class StackElement : UiElement
---@field stack PlayerStack?
---@field scale number
local StackElement = class(
function(self, options)
  self.stack = options.stack
  self.scale = options.scale or 3
end,
UiElement)

---@param stack PlayerStack?
function StackElement:setStack(stack)
  if self.stack then
    self.stack:deinit()
  end
  
  self.stack = stack
  if self.stack then
    self.stack.gfxScale = self.scale
    self.width = self.stack.baseWidth * self.scale
    self.height = self.stack.baseHeight * self.scale
    self:refreshPosition()
  end
end

function StackElement:refreshPosition()
  if self.stack then
    self.stack:moveToPosition(0, 0)
  end
end

function StackElement:setScale(scale)
  self.scale = scale
  if self.stack then
    self.stack.gfxScale = self.scale
    self:refreshPosition()
  end
end

function StackElement:draw()
  if self.stack then
    local x, y = self:getScreenPos()
    love.graphics.push("transform")
    love.graphics.translate(self.x, self.y)
    self.stack:render(false, x, y)
    love.graphics.pop()
  end
end

return StackElement