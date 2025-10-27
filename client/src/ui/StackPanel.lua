local PATH = (...):gsub('%.[^%.]+$', '')
local UiElement = require(PATH .. ".UIElement")
local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local DebugSettings = require("client.src.debug.DebugSettings")

---@class StackPanel : UiElement
---StackPanel is a layouting element that stacks up all its children in one direction based on an alignment setting.
---Useful for auto-aligning multiple ui elements that only know one of their dimensions.
---@field alignment "left"|"right"|"top"|"bottom" Direction in which children are stacked
---@field pixelsTaken number Tracks how many pixels are already taken in the stacking direction
---@field TYPE string Class type identifier
local StackPanel = class(function(stackPanel, options)
  ---@type "left"|"right"|"top"|"bottom"
  stackPanel.alignment = options.alignment
  ---@type number
  stackPanel.pixelsTaken = 0
end,
UiElement)

StackPanel.TYPE = "StackPanel"

---Applies positioning and sizing settings to a UI element based on the StackPanel's alignment
---@param uiElement UiElement The element to apply settings to
function StackPanel:applyStackPanelSettings(uiElement)
  if self.alignment == "left" then
    uiElement.hFill = false
    uiElement.hAlign = "left"
    uiElement.x = self.width
    self.pixelsTaken = self.pixelsTaken + uiElement.width
    self.width = self.pixelsTaken
  elseif self.alignment == "right" then
    uiElement.hFill = false
    uiElement.hAlign = "right"
    uiElement.x = - self.pixelsTaken
    self.pixelsTaken = self.pixelsTaken + uiElement.width
    self.width = self.pixelsTaken
  elseif self.alignment == "top" then
    uiElement.vFill = false
    uiElement.vAlign = "top"
    uiElement.y = self.pixelsTaken
    self.pixelsTaken = self.pixelsTaken + uiElement.height
    self.height = self.pixelsTaken
  elseif self.alignment == "bottom" then
    uiElement.vFill = false
    uiElement.vAlign = "bottom"
    uiElement.y = - self.pixelsTaken
    self.pixelsTaken = self.pixelsTaken + uiElement.height
    self.height = self.pixelsTaken
  end
end

---Adds a UI element to the StackPanel, applying proper positioning and resizing
---@param uiElement UiElement The element to add
function StackPanel:addElement(uiElement)
  self:applyStackPanelSettings(uiElement)
  self:addChild(uiElement)
  self:resize()
  uiElement.yieldFocus = function()
    self.yieldFocus()
  end
end

---Inserts a UI element at a specific index in the StackPanel
---@param uiElement UiElement The element to insert
---@param index number The position to insert at (1-based)
function StackPanel:insertElementAtIndex(uiElement, index)
  -- add it at the end
  StackPanel.addElement(self, uiElement)
  StackPanel.shiftTo(self, uiElement, index)
end

---Shifts an element to a specific index by swapping positions with preceding elements
---@param uiElement UiElement The element to shift
---@param index number The target position (1-based)
function StackPanel:shiftTo(uiElement, index)
  -- swap the previous element with it while updating values until it reached the desired index
  for i = #self.children - 1, index, -1 do
    local otherElement = table.remove(self.children, i)
    if self.alignment == "left" then
      uiElement.x = otherElement.x
      otherElement.x = otherElement.x + uiElement.width
    elseif self.alignment == "right" then
      uiElement.x = otherElement.x
      otherElement.x = otherElement.x - uiElement.width
    elseif self.alignment == "top" then
      uiElement.y = otherElement.y
      otherElement.y = otherElement.y + uiElement.height
    elseif self.alignment == "bottom" then
      uiElement.y = otherElement.y
      otherElement.y = otherElement.y - uiElement.height
    end
    table.insert(self.children, i + 1, otherElement)
  end
end

---Removes an element from the StackPanel, updating positions and pixel tracking
---IMPORTANT: Use this method instead of element:detach() to maintain proper layout state
---@param uiElement UiElement The element to remove
function StackPanel:remove(uiElement)
  local index = tableUtils.indexOf(self.children, uiElement)

  -- swap the next element with it while updating values until it reached the end, then remove it
  for i = index + 1, #self.children do
    local otherElement = table.remove(self.children, i)
    if self.alignment == "left" then
      otherElement.x = uiElement.x
      uiElement.x = uiElement.x + otherElement.width
    elseif self.alignment == "right" then
      otherElement.x = uiElement.x
      uiElement.x = uiElement.x - otherElement.width
    elseif self.alignment == "top" then
      otherElement.y = uiElement.y
      uiElement.y = uiElement.y + otherElement.height
    elseif self.alignment == "bottom" then
      otherElement.y = uiElement.y
      uiElement.y = uiElement.y + otherElement.height
    end
    table.insert(self.children, i - 1, otherElement)
  end

  if self.alignment == "left" or self.alignment == "right" then
    self.width = self.width - uiElement.width
    self.pixelsTaken = self.width
  else
    self.height = self.height - uiElement.height
    self.pixelsTaken = self.height
  end
  uiElement:detach()
end

---Processes user input and forwards it to child elements
---@param input table Input state
---@param dt number Delta time since last frame
function StackPanel:receiveInputs(input, dt)
  for _, child in ipairs(self.children) do
    if child.receiveInputs then
      child:receiveInputs(input, dt)
      return
    end
  end
end

---Draws the StackPanel's debug borders if enabled in debug settings
function StackPanel:drawSelf()
  if DebugSettings.showUIElementBorders() then
    GraphicsUtil.setColor(1, 0, 0, 0.7)
    GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
end

return StackPanel