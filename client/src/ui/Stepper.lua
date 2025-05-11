local PATH = (...):gsub('%.[^%.]+$', '')
local UIElement = require(PATH .. ".UIElement")
local TextButton = require(PATH .. ".TextButton")
local Label = require(PATH .. ".Label")
local class = require("common.lib.class")
local util = require("common.lib.util")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local HorizontalFlexLayout = require(PATH .. ".Layouts.HorizontalFlexLayout")

local NAV_BUTTON_WIDTH = 25

-- UIElement representing a scrolling list of options
local Stepper = class(
  function(self, options)
    self.onChange = options.onChange or function() end
    self.selectedIndex = options.selectedIndex or 1
    self.childGap = options.childGap or 8

    local navButtonWidth = 25
    self.leftButton = TextButton({
      width = navButtonWidth,
      vAlign = "center",
      hAlign = "center",
      label = Label({text = "<"}),
      onClick = function(selfElement, inputSource, holdTime)
        self:setState(self.selectedIndex - 1)
      end
    })
    self.labelContainer = UIElement({
      vAlign = "center",
      hAlign = "center",
    })
    self.rightButton = TextButton({
      width = navButtonWidth,
      vAlign = "center",
      hAlign = "center",
      label = Label({text = ">"}),
      onClick = function(selfElement, inputSource, holdTime)
        self:setState(self.selectedIndex + 1)
      end
    })
    self:addChild(self.leftButton)
    self:addChild(self.labelContainer)
    self:addChild(self.rightButton)

    self:setLabels(options.labels, options.values, self.selectedIndex)
    self.color = {.5, .5, 1, .7}
    self.borderColor = {.7, .7, 1, .7}
  end,
  UIElement
)

Stepper.TYPE = "Stepper"
Stepper.layout = HorizontalFlexLayout
function Stepper:setLabels(labels, values, selectedIndex)
  self.selectedIndex = selectedIndex
  self.values = values
  self.labels = labels

  for i = #self.labelContainer.children, 1, -1 do
    self.labelContainer.children[i]:detach()
  end

  local minWidth = 0
  for _, label in ipairs(labels) do
      label.hAlign = "center"
      label.vAlign = "center"
      label:setVisibility(false)
      minWidth = math.max(minWidth, label:getPreferredWidth())

      self.labelContainer:addChild(label)
  end
  self.labelContainer.minWidth = minWidth
  self.labelContainer.width = minWidth
  self.labelContainer.maxWidth = minWidth

  self.labels[self.selectedIndex]:setVisibility(true)
  self.value = self.values[self.selectedIndex]
end

function Stepper.setState(self, i)
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

function Stepper:receiveInputs(input)
  if input:isPressedWithRepeat("Left") then
    self:setState(self.selectedIndex - 1)
  elseif input:isPressedWithRepeat("Right") then
    self:setState(self.selectedIndex + 1)
  elseif input.isDown["Swap2"] and self.isFocusable then
    self:yieldFocus()
  end
end

function Stepper:refreshLocalization()
  for i, label in ipairs(self.labels) do
    label:refreshLocalization()
  end
  UIElement.refreshLocalization(self)
end

function Stepper:drawSelf()
  if config.debug_mode then
    GraphicsUtil.setColor(self.color)
    GraphicsUtil.drawRectangle("fill", self.x, self.y, self.width, self.height)
    GraphicsUtil.setColor(self.borderColor)
    GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
end

return Stepper