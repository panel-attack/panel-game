local class = require("common.lib.class")
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")

---@class CursorOptions
---@field target UiElement
---@field keyInput KeyConfiguration
---@field hoveredIndex integer?

---@class Cursor : FocusDirector, UiElement
---@operator call(CursorOptions): Cursor
---@field keyInput KeyConfiguration
---@field focusStack (UiElement | CursorNavigable)[]
---@field hovered UiElement
---@field focused UiElement | CursorNavigable
---@field hoveredIndex integer
---@field escapeCallback fun(self: Cursor)
local Cursor = class(
function(self, options)
  self.keyInput = options.keyInput
  self.focusStack = {}

  if options.escapeCallback then
    self.escapeCallback = options.escapeCallback
  end
  self:setFocus(options.target)
end)


function Cursor:moveFocus(currentFocus, newFocus)
  self:releaseFocus(currentFocus)
  self:deepenFocus(newFocus)
end

---@param uiElement UiElement | CursorNavigable
function Cursor:setFocus(uiElement, callback)
  if self.focused then
    self.focused.cursor = nil
  end
  uiElement:receiveFocus(self)
  self.focused = uiElement
  self.focusStack = {}
end

---@param uiElement UiElement | CursorNavigable
function Cursor:deepenFocus(uiElement)
  self.focusStack[#self.focusStack+1] = self.focused
  self.focused.cursor = nil
  self.focused = uiElement
  self.focused.cursor = self
end

---@param uiElement UiElement
function Cursor:releaseFocus(uiElement)
  for i = #self.focusStack, 2, -1 do
    local focused = self.focusStack[i]
    self.focusStack[i] = nil
    if focused.cursor then
      focused.cursor = nil
      focused.hoveredElement = nil
    end
    if focused == uiElement then
      break
    end
  end

  self.focused = table.remove(self.focusStack, #self.focusStack)
end


function Cursor:getLastIndex()
  for i = #self.focused.children, 1, -1 do
    local child = self.focused.children[i]
    if child.receiveInputs and child.isEnabled and child.isVisible then
      return i
    end
  end
end

function Cursor:moveToLast()
  self.hoveredIndex = self:getLastIndex()
  self.hovered = self.focused.children[self.hoveredIndex]
end


function Cursor:receiveInputs(dt)
  local focused = self.focused
  local hoveredElement = self.focused.hoveredElement
  self.focused:processCursorInput(dt)
  if self.focused.hoveredElement ~= hoveredElement then
    hoveredElement.cursorFocus = false
    if focused == self.focused then
      --self.focused.hoveredElement.
    end
  end
end

---@param uiElement UiElement
---@param hoveredIndex integer?
function Cursor:setTarget(uiElement, hoveredIndex)
  if self.focused ~= uiElement then
    self.hovered = nil
  end
  self.focused = uiElement
  if uiElement.isFocusable then
    self:setFocus(self.focused)
    if hoveredIndex then
      self.hoveredIndex = hoveredIndex
      self.hovered = self.focused.children[self.hoveredIndex]
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