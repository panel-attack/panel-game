local PATH = (...):gsub('%.[^%.]+$', '')
local UIElement = require(PATH .. ".UIElement")
local TextButton = require(PATH .. ".TextButton")
local Label = require(PATH .. ".Label")
local Layout = require(PATH .. ".Layout")
local class = require("common.lib.class")
local util = require("common.lib.util")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local DebugSettings = require("client.src.debug.DebugSettings")

local NAV_BUTTON_WIDTH = 25
local EMPTY_STEPPER_WIDTH = 160

-- The label's size along the axis: the size its rules fix, or its text's measure when they don't fix one
---@param label Label
---@param axis "horizontal"|"vertical"
---@return number
local function labelLength(label, axis)
  return Layout.fixedLength(label.layoutRules, axis) or (axis == "horizontal" and label.contentWidth or label.contentHeight)
end

local function setLabels(self, labels, values, selectedIndex)
  self.selectedIndex = selectedIndex
  self.values = values
  self.labels = labels

  self:removeLabelChildren()

  if (#labels == 0) then
    self.rightButton:setVisibility(false);
    self.leftButton:setVisibility(false);
    self.stepperWidth = EMPTY_STEPPER_WIDTH
    self:setFixedSize(self.stepperWidth, self.stepperHeight)
    return
  end

  for _, label in ipairs(labels) do
      label:setLayoutRule("floating", Layout.floatAt("centerCenter"))
      self.stepperWidth = math.max(labelLength(label, "horizontal") + 10 + NAV_BUTTON_WIDTH * 2, self.stepperWidth)
      self.stepperHeight = math.max(labelLength(label, "vertical") + 4, self.stepperHeight)

      self:addChild(label)
      label:setVisibility(false)
  end

  self.labels[self.selectedIndex]:setVisibility(true)
  self.value = self.values[self.selectedIndex]
  self:setFixedSize(self.stepperWidth, self.stepperHeight)
  self.rightButton:setVisibility(true);
  self.leftButton:setVisibility(true);
end

local function setState(self, i)
  local new_index = util.bound(1, i, #self.labels)
  if i ~= new_index then
    return
  end

  self.labels[self.selectedIndex]:setVisibility(false)
  self.selectedIndex = new_index
  self.value = self.values[new_index]
  self.labels[new_index]:setVisibility(true)
  self.onChange(self.value)
end

-- UIElement representing a scrolling list of options
local Stepper = class(
  function(self, options)
    self.onChange = options.onChange or function() end
    self.selectedIndex = options.selectedIndex or 1
    -- the stepper grows to fit its widest and tallest labels, from the size it was given
    self.stepperWidth = Layout.fixedLength(self.layoutRules, "horizontal") or 0
    self.stepperHeight = Layout.fixedLength(self.layoutRules, "vertical") or 0

    local navButtonWidth = 25
    self.leftButton = TextButton({
      layoutRules = {sizing = {horizontal = Layout.fixed(navButtonWidth)}, floating = Layout.floatAt("leftCenter")},
      label = Label({text = "<", translate = false}),
      onClick = function(selfElement, inputSource, holdTime)
        setState(self, self.selectedIndex - 1)
      end
    })
    self.rightButton = TextButton({
      layoutRules = {sizing = {horizontal = Layout.fixed(navButtonWidth)}, floating = Layout.floatAt("rightCenter")},
      label = Label({text = ">", translate = false}),
      onClick = function(selfElement, inputSource, holdTime)
        setState(self, self.selectedIndex + 1)
      end
    })
    self:addChild(self.leftButton)
    self:addChild(self.rightButton)

    self.color = {.5, .5, 1, .7}
    self.borderColor = {.7, .7, 1, .7}

    setLabels(self, options.labels, options.values, self.selectedIndex)

    self.TYPE = "Stepper"
  end,
  UIElement
)

Stepper.setLabels = setLabels
Stepper.setState = setState

function Stepper:receiveInputsSelf(inputSource, dt)
  local input = inputSource:getInputs()
  if input:isPressedWithRepeat("Left") then
    self:setState(self.selectedIndex - 1)
  elseif input:isPressedWithRepeat("Right") then
    self:setState(self.selectedIndex + 1)
  elseif input.isDown["Swap2"] and self.isFocusable then
    self:yieldFocus(inputSource)
  end
end

function Stepper:refreshLocalization()
  for i, label in ipairs(self.labels) do
    label:refreshLocalization()
  end
  UIElement.refreshLocalization(self)
end

function Stepper:drawSelf()
  if DebugSettings.showUIElementBorders() then
    GraphicsUtil.setColor(self.color)
    GraphicsUtil.drawRectangle("fill", 0, 0, self.layoutRect.width, self.layoutRect.height)
    GraphicsUtil.setColor(self.borderColor)
    GraphicsUtil.drawRectangle("line", 0, 0, self.layoutRect.width, self.layoutRect.height)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
end

-- Remove all attached labels, preserving the navigation buttons
function Stepper:removeLabelChildren()
  for i = #self.children, 3, -1 do
    self.children[i]:detach()
  end
end

return Stepper