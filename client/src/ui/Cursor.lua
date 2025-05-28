local class = require("common.lib.class")
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local input = require("client.src.inputManager")

---@class CursorOptions
---@field target UiElement
---@field keyInput KeyConfiguration?

---@class Cursor
---@operator call(CursorOptions): Cursor
---@overload fun(target: CursorNavigable | UiElement, keyInput: KeyConfiguration?): Cursor
---@field keyInput KeyConfiguration
---@field focusStack CursorNavigable[] A stack of focused UiElement, new elements go on top, as focus is released it goes back down
---@field focusToHover table<CursorNavigable, UiElement | CursorInteractable> Persists the last hovered element for each navigable UiElement so that the last position can be reconstructed when focus is released
---@field focused CursorNavigable The navigable UiElement that is currently consuming the cursor's inputs
local Cursor = class(
function(self, target, keyInput)
  self.keyInput = keyInput or input
  self:setFocus(target)
end)

---@param currentFocus UiElement | CursorNavigable
---@param newFocus UiElement | CursorNavigable
function Cursor:moveFocus(currentFocus, newFocus)
  self:releaseFocus(currentFocus)
  self:deepenFocus(newFocus)
end

---@param uiElement UiElement | CursorNavigable
function Cursor:setFocus(uiElement)
  self.focusStack = {}
  self.focusToHover = {}
  self.focused = uiElement
  self.focusStack = { uiElement }
  uiElement:receiveFocus(self)
end

---@param uiElement UiElement | CursorNavigable
function Cursor:deepenFocus(uiElement)
  self.focusToHover[self.focused]:setHover(self, false)

  self.focusStack[#self.focusStack+1] = uiElement
  self.focused = uiElement
  uiElement:receiveFocus(self)
end

---@param uiElement UiElement | CursorNavigable
function Cursor:releaseFocus(uiElement)
  if #self.focusStack >= 1 then
    for i = #self.focusStack, 2, -1 do
      local focused = self.focusStack[i]
      local hovered = self.focusToHover[focused]
      self.focusStack[i] = nil
      self.focusToHover[focused] = nil
      hovered:setHover(self, false)
      if focused == uiElement then
        break
      end
    end
    if uiElement.onYield then
      uiElement:onYield()
    end

    self.focused = self.focusStack[#self.focusStack]
    self.focusToHover[self.focused]:setHover(self, true)
  end
end

function Cursor:updateHover(focused, newHovered)
  local currentHovered = self.focusToHover[focused]
  self.focusToHover[focused] = newHovered
  if focused == self.focused then
    if currentHovered then
      currentHovered:setHover(self, false)
    end
    newHovered:setHover(self, true)
  end
end

function Cursor:receiveInputs(dt)
  self.focused:receiveInputs(self, dt)
end

function Cursor:draw()
  -- GraphicsUtil.setColor(0, 0, 0, 0.2)
  -- love.graphics.rectangle("fill", self.target.x, self.target.y, self.target.width, self.target.height)
  if self.focused then
    local uiElement = self.focusToHover[self.focused]
    GraphicsUtil.setColor(1, 1, 1, 0.2)
    local x, y = uiElement:getScreenPos()
    love.graphics.rectangle("fill", x, y, uiElement.width, uiElement.height)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
end

return Cursor