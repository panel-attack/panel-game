local PATH = (...):gsub('%.[^%.]+$', '')
local UiElement = require(PATH .. ".UIElement")
local class = require("common.lib.class")
local FocusDirector = require(PATH .. ".FocusDirector")
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")

---@class CursorOptions
---@field target UiElement
---@field hoveredIndex integer?

---@class Cursor : FocusDirector, UiElement
---@operator call(CursorOptions): Cursor
---@field hovered UiElement
---@field target UiElement
---@field hoveredIndex integer
---@field escapeCallback fun(self: Cursor)
local Cursor = class(
function(self, options)
  if options.escapeCallback then
    self.escapeCallback = options.escapeCallback
  end
  self:setTarget(options.target)
  if options.hoveredIndex then
    self.hoveredIndex = options.hoveredIndex
    self.hovered = self.target.children[self.hoveredIndex]
  else
    self.hoveredIndex = 0
    self:moveToNext()
  end
end,
UiElement)

FocusDirector(Cursor)

function Cursor:moveToNext()
  if self.target then
    for i = self.hoveredIndex + 1, self.hoveredIndex + #self.target.children do
      local index = wrap(1, i, #self.target.children)
      local child = self.target.children[index]
      if child.receiveInputs and child.isEnabled and child.isVisible then
        self.hoveredIndex = index
        self.hovered = self.target.children[self.hoveredIndex]
        break
      end
    end
  end
end

function Cursor:moveToPrevious()
  if self.target then
    for i = self.hoveredIndex - 1, self.hoveredIndex - #self.target.children, -1 do
      local index = wrap(1, i, #self.target.children)
      local child = self.target.children[index]
      if child.receiveInputs and child.isEnabled and child.isVisible then
        self.hoveredIndex = index
        self.hovered = self.target.children[self.hoveredIndex]
        break
      end
    end
  end
end

function Cursor:getLastIndex()
  for i = #self.target.children, 1, -1 do
    local child = self.target.children[i]
    if child.receiveInputs and child.isEnabled and child.isVisible then
      return i
    end
  end
end

function Cursor:moveToLast()
  self.hoveredIndex = self:getLastIndex()
  self.hovered = self.target.children[self.hoveredIndex]
end

function Cursor:receiveInputs(inputs, dt)
  if self.target then
    if self.focused then
      self.focused:receiveInputs(inputs, dt, self.player)
    elseif inputs.isDown.Swap2 then
      GAME.theme:playCancelSfx()
      self:escapeCallback()
    elseif inputs:isPressedWithRepeat("Left", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
      if self.target.layout.characteristic == "horizontal" then
        GAME.theme:playMoveSfx()
        self:moveToPrevious()
      elseif self.hovered.receiveInputs then
        self.hovered:receiveInputs(inputs, dt)
      else
        GAME.theme:playCancelSfx()
      end
    elseif inputs:isPressedWithRepeat("Right", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
      if self.target.layout.characteristic == "horizontal" then
        GAME.theme:playMoveSfx()
        self:moveToNext()
      elseif self.hovered.receiveInputs then
        self.hovered:receiveInputs(inputs, dt)
      else
        GAME.theme:playCancelSfx()
      end
    elseif inputs:isPressedWithRepeat("Up", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
      if self.target.layout.characteristic == "vertical" then
        GAME.theme:playMoveSfx()
        self:moveToPrevious()
      elseif self.hovered.receiveInputs then
        self.hovered:receiveInputs(inputs, dt)
      else
        GAME.theme:playCancelSfx()
      end
    elseif inputs:isPressedWithRepeat("Down", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
      if self.target.layout.characteristic == "vertical" then
        GAME.theme:playMoveSfx()
        self:moveToNext()
      elseif self.hovered.receiveInputs then
        self.hovered:receiveInputs(inputs, dt)
      else
        GAME.theme:playCancelSfx()
      end
    elseif inputs.isDown.Swap1 or inputs.isDown.Start then
      if self.hovered.isFocusable then
        GAME.theme:playValidationSfx()
        self:setFocus(self.hovered)
      elseif self.hovered.receiveInputs then
        self.hovered:receiveInputs(inputs, dt)
      else
        GAME.theme:playCancelSfx()
      end
    end
  end
end

---@param uiElement UiElement
---@param hoveredIndex integer?
function Cursor:setTarget(uiElement, hoveredIndex)
  if self.target ~= uiElement then
    self.hovered = nil
  end
  self.target = uiElement
  if uiElement.isFocusable then
    self:setFocus(self.target)
    if hoveredIndex then
      self.hoveredIndex = hoveredIndex
      self.hovered = self.target.children[self.hoveredIndex]
    else
      self.hoveredIndex = 0
      self:moveToNext()
    end
  end
end

function Cursor:drawSelf()
  -- GraphicsUtil.setColor(0, 0, 0, 0.2)
  -- love.graphics.rectangle("fill", self.target.x, self.target.y, self.target.width, self.target.height)
  if self.hovered then
    GraphicsUtil.setColor(1, 1, 1, 0.2)
    local x, y = self.hovered:getScreenPos()
    love.graphics.rectangle("fill", x, y, self.hovered.width, self.hovered.height)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
end

function Cursor:escapeCallback()
  if self.hoveredIndex == self:getLastIndex() then
    if self.focused then
      self.focused:yieldFocus()
    else
      GAME.navigationStack:pop()
    end
  else
    self:moveToLast()
  end
end

return Cursor