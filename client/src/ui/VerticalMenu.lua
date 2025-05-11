local PATH = (...):gsub('%.[^%.]+$', '')
local ScrollContainer = require(PATH .. ".ScrollContainer")
local class = require("common.lib.class")
local util = require("common.lib.util")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local Focusable = require(PATH .. ".Focusable")
local FocusDirector = require(PATH .. ".FocusDirector")
local input = require("client.src.inputManager")
local VerticalScrollLayout = require(PATH .. ".Layouts.VerticalScrollLayout")

---@class VerticalMenu : ScrollContainer, Focusable
local VerticalMenu = class(
function(self, options)
  self.selectedIndex = nil
  self.scrollOrientation = "vertical"
  self.layout = VerticalScrollLayout
end,
ScrollContainer)

Focusable(VerticalMenu)
FocusDirector(VerticalMenu)

function VerticalMenu:setInitialFocus()
  for i, child in ipairs(self.children) do
    if child.receiveInputs and child.isEnabled and child.isVisible then
      self.selectedIndex = i
      break
    end
  end
end

function VerticalMenu:selectPrevious()
  for i = self.selectedIndex - 1, self.selectedIndex - #self.children, -1 do
    local index = wrap(1, i, #self.children)
    local child = self.children[index]
    if child.receiveInputs and child.isEnabled and child.isVisible then
      self.selectedIndex = index
      break
    end
  end
  self:keepVisible(self.children[self.selectedIndex].y, self.children[self.selectedIndex].height)
  GAME.theme:playMoveSfx()
end

function VerticalMenu:selectNext()
  for i = self.selectedIndex + 1, self.selectedIndex + #self.children do
    local index = wrap(1, i, #self.children)
    local child = self.children[index]
    if child.receiveInputs and child.isEnabled and child.isVisible then
      self.selectedIndex = index
      break
    end
  end
  self:keepVisible(self.children[self.selectedIndex].y, self.children[self.selectedIndex].height)
  GAME.theme:playMoveSfx()
end

function VerticalMenu:selectLast()
  for i = #self.children, 1, -1 do
    local child = self.children[i]
    if child.receiveInputs and child.isEnabled and child.isVisible then
      self.selectedIndex = i
      break
    end
  end
end

function VerticalMenu:receiveInputs(inputs, dt)
  if not self.selectedIndex then
    self:setInitialFocus()
  end

  if not self.isEnabled then
    return
  end

  if not inputs then
    -- if we don't get inputs passed, use the global input table
    inputs = input
  end

  local selectedElement = self.children[self.selectedIndex]

  if self.focused then
    self.focused:receiveInputs(inputs, dt)
  elseif inputs.isDown["MenuEsc"] then
    if self.selectedIndex ~= #self.children then
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

function VerticalMenu:setSelectedIndex(index)
  self.selectedIndex = util.bound(1, index, #self.children)
end

function VerticalMenu:draw()
  ScrollContainer.draw(self)
  if self.selectedIndex then
    local selected = self.children[self.selectedIndex]
    love.graphics.print(">", self.x + selected.x - 10, self.y + self.scrollOffset + selected.y)
  end
end

return VerticalMenu