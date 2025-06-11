local import = require("common.lib.import")
local ScrollContainer = import("./ScrollContainer")
local class = require("common.lib.class")
local util = require("common.lib.util")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local VerticalFlexLayout = import("./Layouts.VerticalFlexLayout")
local VerticalScrollLayout = import("./Layouts.VerticalScrollLayout")
local tableUtils = require("common.lib.tableUtils")
local addCursorNavigationInterface = import("./CursorNavigable")

---@class VerticalMenu : ScrollContainer, Focusable
---@operator call(ScrollContainerOptions): VerticalMenu
---@overload fun(options: ScrollContainerOptions): VerticalMenu
---@type VerticalMenu
local VerticalMenu = class(
function(self, options)
  self.selectedIndex = nil
  self.scrollOrientation = "vertical"
  self.layout = VerticalScrollLayout
  addCursorNavigationInterface(self, self.receiveInputs)

  self.onYield = options.onYield
  self.onFocus = options.onFocus
end,
ScrollContainer)

VerticalMenu.TYPE = "VerticalMenu"

---@param cursor Cursor
function VerticalMenu:selectPrevious(cursor)
  local hoveredIndex = tableUtils.indexOf(self.children, cursor.focusToHover[self])
  for i = hoveredIndex - 1, hoveredIndex - #self.children, -1 do
    local index = wrap(1, i, #self.children)
    local child = self.children[index]
    if child.receiveInputs and child.isEnabled and child.isVisible then
      cursor:updateHover(self, self.children[index])
      break
    end
  end
  self:keepVisible(cursor)
  GAME.theme:playMoveSfx()
end

---@param cursor Cursor
function VerticalMenu:selectNext(cursor)
  local hoveredIndex = tableUtils.indexOf(self.children, cursor.focusToHover[self])
  for i = hoveredIndex + 1, hoveredIndex + #self.children do
    local index = wrap(1, i, #self.children)
    local child = self.children[index]
    if child.receiveInputs and child.isEnabled and child.isVisible then
      cursor:updateHover(self, self.children[index])
      break
    end
  end
  self:keepVisible(cursor)
  GAME.theme:playMoveSfx()
end

---@param cursor Cursor
function VerticalMenu:selectLast(cursor)
  cursor:updateHover(self, self:getLast())
  self:keepVisible(cursor)
end

---@return CursorInteractable | UiElement
function VerticalMenu:getLast()
  for i = #self.children, 1, -1 do
    local child = self.children[i]
    if child.receiveInputs and child.isEnabled and child.isVisible then
      return child
    end
  end

  return self.children[1]
end

---@param cursor Cursor
---@param dt number?
function VerticalMenu:receiveInputs(cursor, dt)
  if not self.isEnabled then
    return
  end

  local inputs = cursor.keyInput
  local selectedElement = cursor.focusToHover[self]

  if inputs.isDown["MenuEsc"] then
    if self:getLast() ~= selectedElement then
      self:selectLast(cursor)
      GAME.theme:playCancelSfx()
    else
      selectedElement:receiveInputs(cursor, dt)
    end
  elseif inputs:isPressedWithRepeat("MenuUp") then
    self:selectPrevious(cursor)
  elseif inputs:isPressedWithRepeat("MenuDown") then
    self:selectNext(cursor)
  else
    if inputs.isDown["MenuSelect"] and selectedElement.isNavigable then
      self:deepenFocus(selectedElement)
    else
      selectedElement:receiveInputs(cursor, dt)
    end
  end
end

function VerticalMenu:setSelectedIndex(index)
  self.selectedIndex = util.bound(1, index, #self.children)
end

function VerticalMenu:drawChildren()
  for i, uiElement in ipairs(self.children) do
    if uiElement.isVisible then
      if i == self.selectedIndex then
        GraphicsUtil.setColor(0.6, 0.6, 1, 0.5)
        love.graphics.rectangle("fill", uiElement.x, uiElement.y, uiElement.width, uiElement.height)
        love.graphics.rectangle("line", uiElement.x, uiElement.y, uiElement.width, uiElement.height)
      end
      uiElement:draw()
    end
  end
end

function VerticalMenu:onResized()
  ScrollContainer.onResized(self)
  for _, child in ipairs(self.children) do
    for cursor, _ in pairs(child.hoveringCursors) do
      self:keepVisible(cursor)
    end
  end
end

return VerticalMenu