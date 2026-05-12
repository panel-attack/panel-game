local import = require("common.lib.import")
local ScrollContainer = import("./ScrollContainer")
local class = require("common.lib.class")
local util = require("common.lib.util")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local tableUtils = require("common.lib.tableUtils")
local FocusDirector = import("./FocusDirector")

---@class ScrollMenu : ScrollContainer
local ScrollMenu = class(
  ---@param self ScrollMenu
  ---@param options ScrollContainerOptions
function(self, options)
  self.selectedIndex = nil
  self.scrollOrientation = "vertical"
  self.childGap = options.childGap or 8
  self.padding = options.padding or 32
end,
ScrollContainer)

ScrollMenu.TYPE = "ScrollMenu"

FocusDirector(ScrollMenu)

function ScrollMenu:onRelease(x, y, duration)
  if self.touchedChild and self.focused and self.focused ~= self.touchedChild then
    self.focused:yieldFocus()
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

  if self.children[self.selectedIndex] and self.children[self.selectedIndex].setSelected then
    self.children[self.selectedIndex]:setSelected(false)
  end

  local child
  for i = self.selectedIndex - 1, self.selectedIndex - #self.children, -1 do
    local index = wrap(1, i, #self.children)
    child = self.children[index]
    if child.receiveInputs and child.isEnabled and child.isVisible then
      self.selectedIndex = index
      break
    end
  end
  if child and child.setSelected then child:setSelected(true) end
  self:keepVisible(-child.y, child.height)
  GAME.theme:playMoveSfx()
end

function ScrollMenu:selectNext()
  if not self.selectedIndex then
    return
  end

  if self.children[self.selectedIndex] and self.children[self.selectedIndex].setSelected then
    self.children[self.selectedIndex]:setSelected(false)
  end

  local child
  for i = self.selectedIndex + 1, self.selectedIndex + #self.children do
    local index = wrap(1, i, #self.children)
    child = self.children[index]
    if child.receiveInputs and child.isEnabled and child.isVisible then
      self.selectedIndex = index
      break
    end
  end
  if child and child.setSelected then child:setSelected(true) end
  self:keepVisible(-child.y, child.height)
  GAME.theme:playMoveSfx()
end

function ScrollMenu:selectLast()
  self.selectedIndex = self:getLastIndex()
  local child = self.children[self.selectedIndex]
  self:keepVisible(-child.y, child.height)
end

function ScrollMenu:getLastIndex()
  for i = #self.children, 1, -1 do
    local child = self.children[i]
    if child.receiveInputs and child.isEnabled and child.isVisible then
      return i
    end
  end
end

---@param uiElement UiElement
---@return boolean # if the selection was successful
function ScrollMenu:select(uiElement)
  for i, child in ipairs(self.children) do
    if child == uiElement and child.receiveInputs and child.isEnabled and child.isVisible then
      if self.selectedIndex and self.children[self.selectedIndex] and self.children[self.selectedIndex].setSelected then
        self.children[self.selectedIndex]:setSelected(false)
      end
      self.selectedIndex = i
      if child.setSelected then child:setSelected(true) end
      self:keepVisible(-child.y, child.height)
      return true
    end
  end
  return false
end

-- MenuEsc contract: pressing escape jumps the selection to the last child.
-- If already on the last child, escape is forwarded to that child's
-- receiveInputs — and Button.receiveInputs treats MenuEsc identically to
-- MenuSelect (it fires onClick). The net effect: the last child IS the back
-- action. So any menu passed to setFocus (i.e. any nested submenu) MUST end
-- with a back button whose onClick calls `menu:yieldFocus()`. Without one,
-- escaping on the last item fires whatever action that item has — e.g. a
-- "Relaxed" button would start a game instead of cancelling out.
---@param inputs InputConfiguration
---@param dt number?
function ScrollMenu:receiveInputs(inputs, dt)
  if not self.isEnabled or not self.selectedIndex then
    return
  end

  if self.focused then
    self.focused:receiveInputs(inputs, dt)
  else
    local selectedElement = self.children[self.selectedIndex]

    if inputs.isDown["MenuEsc"] then
      if self:getLastIndex() ~= self.selectedIndex then
        self:selectLast()
        GAME.theme:playCancelSfx()
      else
        selectedElement:receiveInputs(inputs, dt)
      end
    elseif inputs:isPressedWithRepeat("MenuUp") then
      self:selectPrevious()
    elseif inputs:isPressedWithRepeat("MenuDown") then
      self:selectNext()
    else
      if inputs.isDown["MenuSelect"] and selectedElement.isFocusable then
        self:setFocus(selectedElement)
      else
        selectedElement:receiveInputs(inputs, dt)
      end
    end
  end
end

---@param uiElement UiElement
function ScrollMenu:addChild(uiElement)
  local lastChild = self.children[#self.children]
  local y
  if lastChild then
    y = lastChild.y + lastChild.height + self.childGap
  else
    y = self.padding
  end
  uiElement.y = y
  ScrollContainer.addChild(self, uiElement)
end

function ScrollMenu:drawChildren()
  for i, uiElement in ipairs(self.children) do
    if uiElement.isVisible then
      uiElement:draw()
    end
  end
end

return ScrollMenu