local import = require("common.lib.import")
local ScrollContainer = import("./ScrollContainer")
local class = require("common.lib.class")
local util = require("common.lib.util")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local tableUtils = require("common.lib.tableUtils")
local InputSource = require("client.src.input.InputSource")

---@class ScrollMenu : ScrollContainer
local ScrollMenu = class(
  ---@param self ScrollMenu
  ---@param options ScrollContainerOptions
function(self, options)
  self.selectedIndex = nil
  self.scrollOrientation = "vertical"
  self:setLayoutRule("childGap", options.childGap or 8)
  self:setLayoutRule("padding", {top = options.padding or 32})
end,
ScrollContainer)

ScrollMenu.TYPE = "ScrollMenu"

function ScrollMenu:onRelease(x, y, duration)
  local focused = self.focusedChild[InputSource.anyPlayer]
  if self.touchedChild and focused and focused ~= self.touchedChild then
    self:unfocusChild(InputSource.anyPlayer)
  end
  if not self.scrolling then
    self:select(self.touchedChild)
  end
  ScrollContainer.onRelease(self, x, y, duration)
end

function ScrollMenu:selectPrevious()
  if not self.selectedIndex then
    return
  end

  local child
  for i = self.selectedIndex - 1, self.selectedIndex - #self.children, -1 do
    local index = wrap(1, i, #self.children)
    child = self.children[index]
    if child:handlesInputs() and child.isEnabled and child.isVisible then
      self.selectedIndex = index
      break
    end
  end
  self:keepChildVisible(child)
  GAME.theme:playMoveSfx()
end

function ScrollMenu:selectNext()
  if not self.selectedIndex then
    return
  end

  local child
  for i = self.selectedIndex + 1, self.selectedIndex + #self.children do
    local index = wrap(1, i, #self.children)
    child = self.children[index]
    if child:handlesInputs() and child.isEnabled and child.isVisible then
      self.selectedIndex = index
      break
    end
  end
  self:keepChildVisible(child)
  GAME.theme:playMoveSfx()
end

function ScrollMenu:selectLast()
  self.selectedIndex = self:getLastIndex()
  local child = self.children[self.selectedIndex]
  self:keepChildVisible(child)
end

function ScrollMenu:getLastIndex()
  for i = #self.children, 1, -1 do
    local child = self.children[i]
    if child:handlesInputs() and child.isEnabled and child.isVisible then
      return i
    end
  end
end

---@param uiElement UiElement
---@return boolean # if the selection was successful
function ScrollMenu:select(uiElement)
  for i, child in ipairs(self.children) do
    if child == uiElement and child:handlesInputs() and child.isEnabled and child.isVisible then
      self.selectedIndex = i
      self:keepChildVisible(child)
      return true
    end
  end
  return false
end

---@param inputSource InputSource
---@param dt number?
function ScrollMenu:receiveInputs(inputSource, dt)
  if not self.isEnabled or not self.selectedIndex then
    return
  end
  ScrollContainer.receiveInputs(self, inputSource, dt)
end

---@param inputSource InputSource
---@param dt number?
function ScrollMenu:receiveInputsSelf(inputSource, dt)
  local inputs = inputSource:getInputs()
  local selectedElement = self.children[self.selectedIndex]

  if inputs.isDown["MenuEsc"] then
    if self:getLastIndex() ~= self.selectedIndex then
      self:selectLast()
      GAME.theme:playCancelSfx()
    else
      selectedElement:receiveInputs(inputSource, dt)
    end
  elseif inputs:isPressedWithRepeat("MenuUp") then
    self:selectPrevious()
  elseif inputs:isPressedWithRepeat("MenuDown") then
    self:selectNext()
  else
    if inputs.isDown["MenuSelect"] and selectedElement.isFocusable then
      self:focusChild(selectedElement, inputSource)
    else
      selectedElement:receiveInputs(inputSource, dt)
    end
  end
end

-- Draws a highlight behind the selected child, clipped to the menu like the children
function ScrollMenu:drawChildren()
  local selected = self.selectedIndex and self.children[self.selectedIndex]
  if selected and selected.isVisible then
    local rect = selected.layoutRect
    GraphicsUtil.clipStack:pushRectangle(0, 0, self.layoutRect.width, self.layoutRect.height)
    GraphicsUtil.setColor(0.6, 0.6, 1, 0.5)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height)
    love.graphics.rectangle("line", rect.x, rect.y, rect.width, rect.height)
    GraphicsUtil.clipStack:pop()
  end
  ScrollContainer.drawChildren(self)
end

return ScrollMenu