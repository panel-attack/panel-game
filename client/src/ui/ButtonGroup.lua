local PATH = (...):gsub('%.[^%.]+$', '')
local UIElement = require(PATH .. ".UIElement")
local class = require("common.lib.class")
local util = require("common.lib.util")
local tableUtils = require("common.lib.tableUtils")

local BUTTON_PADDING = 5

-- UIElement representing a set of buttons which share state (think radio buttons)

-- forced override for each of the button's onClick function
-- this allows buttons to have individual custom behaviour while also triggering the global state change
local function genButtonGroupFn(self, button)
  local onClick = button.onClick
  return function(b, inputSource, holdTime)
    self:buttonClicked(b)
    onClick(b, inputSource, holdTime)
    self:onChange(self.value)
  end
end

-- setup the buttons for use within the button group
local function setButtons(self, buttons, values, selectedIndex)
  if self.buttons then
    for i, button in ipairs(self.buttons) do
      button:detach()
    end
  end

  self.selectedIndex = selectedIndex
  self.values = values
  self.buttons = buttons

  for _, button in ipairs(buttons) do
    button.onClick = genButtonGroupFn(self, button)
    self:addChild(button)
  end
  self:refreshSelection()
end

local function setActiveButton(self, selectedIndex)
  local newIndex = util.bound(1, selectedIndex, #self.buttons)
  if self.selectedIndex ~= newIndex then
    self.buttons[newIndex]:onClick(nil, 0)
  end
end

---@class ButtonGroup : UiElement
---@field selectedIndex integer
---@field buttons Button[]
---@field value any
---@field values any[]
---@field onChange fun(self: ButtonGroup)
local ButtonGroup = class(
  function(self, options)
    self.selectedIndex = options.selectedIndex or 1
    self:setLayoutRule("childGap", BUTTON_PADDING)

    self.onChange = options.onChange or function() end

    setButtons(self, options.buttons, options.values, self.selectedIndex)
  end,
  UIElement
)
ButtonGroup.TYPE = "ButtonGroup"

-- changes state for the button group
-- updates the color of the selected button
-- updates the value to the selected button's value
function ButtonGroup:buttonClicked(button)
  self.buttons[self.selectedIndex].backgroundColor = {.3, .3, .3, .7}
  local i = tableUtils.indexOf(self.buttons, button)
  self.buttons[i].backgroundColor = {.5, .5, 1, .7}
  self.value = self.values[i]
  self.selectedIndex = i
end

function ButtonGroup:receiveInputsSelf(inputSource, dt)
  local input = inputSource:getInputs()
  if input:isPressedWithRepeat("Left") then
    self:setActiveButton(self.selectedIndex - 1)
  elseif input:isPressedWithRepeat("Right") then
    self:setActiveButton(self.selectedIndex + 1)
  end
end

-- Marks the selected button and takes its value
function ButtonGroup:refreshSelection()
  self.buttons[self.selectedIndex].backgroundColor = {.5, .5, 1, .7}
  self.value = self.values[self.selectedIndex]
end

function ButtonGroup:removeButton(button)
  local index = tableUtils.indexOf(self.buttons, button)
  table.remove(self.buttons, index)
  table.remove(self.values, index)
  button:detach()
  if #self.buttons > 0 then
    self.selectedIndex = util.bound(1, self.selectedIndex, #self.buttons)
    self:refreshSelection()
  end
end

function ButtonGroup:removeButtonByValue(value)
  local index = tableUtils.indexOf(self.values, value)
  self:removeButton(self.buttons[index])
end

ButtonGroup.setButtons = setButtons
ButtonGroup.setActiveButton = setActiveButton

return ButtonGroup