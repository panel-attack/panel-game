local PATH = (...):gsub('%.[^%.]+$', '')
local UiElement = require(PATH .. ".UIElement")
local Layout = require(PATH .. ".Layout")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local DebugSettings = require("client.src.debug.DebugSettings")

---@class StackPanelOptions : UiElementOptions
---@field alignment "left"|"top"

-- StackPanel is a layouting element that stacks up all its children in one direction based on an alignment setting
-- Useful for auto-aligning multiple ui elements that only know one of their dimensions
---@class StackPanel : UiElement
---@operator call(StackPanelOptions): StackPanel
---@field alignment "left"|"top" left stacks the children in a row, top in a column; the panel fits them along it
---@field TYPE string Class type identifier
local StackPanel = class(
---@param stackPanel StackPanel
---@param options StackPanelOptions
function(stackPanel, options)
  stackPanel.alignment = options.alignment
  local sizing = stackPanel.layoutRules.sizing or {}
  if options.alignment == "left" then
    stackPanel:setLayoutRule("layoutDirection", "leftToRight")
    stackPanel:setLayoutRule("sizing", {horizontal = Layout.FIT, vertical = sizing.vertical})
  else
    stackPanel:setLayoutRule("layoutDirection", "topToBottom")
    stackPanel:setLayoutRule("sizing", {horizontal = sizing.horizontal, vertical = Layout.FIT})
  end
end,
UiElement, "StackPanel")

---Adds a UI element after the panel's other children
---@param uiElement UiElement The element to add
function StackPanel:addElement(uiElement)
  self:addChild(uiElement)
end

---Inserts a UI element at a specific index in the StackPanel
---@param uiElement UiElement The element to insert
---@param index number The position to insert at (1-based)
function StackPanel:insertElementAtIndex(uiElement, index)
  self:addChild(uiElement)
  self:moveChild(uiElement, index)
end

---Removes an element from the StackPanel, closing the gap it leaves
---@param uiElement UiElement The element to remove
function StackPanel:remove(uiElement)
  uiElement:detach()
end

---@return UiElement? # the first child that interprets inputs
function StackPanel:getInputChild()
  for _, child in ipairs(self.children) do
    if child:handlesInputs() then
      return child
    end
  end
end

---Hands the inputs to the first child that interprets inputs
---@param inputSource InputSource
---@param dt number Delta time since last frame
function StackPanel:receiveInputsSelf(inputSource, dt)
  local child = self:getInputChild()
  if child then
    child:receiveInputs(inputSource, dt)
  end
end

---Passes focus on to the first child that interprets inputs
---@param inputSource InputSource
function StackPanel:onFocus(inputSource)
  local child = self:getInputChild()
  if child then
    self:forwardFocus(child, inputSource)
  end
end

---Draws the StackPanel's debug borders if enabled in debug settings
function StackPanel:drawSelf()
  if DebugSettings.showUIElementBorders() then
    GraphicsUtil.setColor(1, 0, 0, 0.7)
    GraphicsUtil.drawRectangle("line", 0, 0, self.layoutRect.width, self.layoutRect.height)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
end

return StackPanel