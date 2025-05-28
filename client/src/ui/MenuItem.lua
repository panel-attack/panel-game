local import = require("common.lib.import")
local UiElement = import("./UIElement")
local Label = import("./Label")
local Button = import("./Button")
local TextButton = import("./TextButton")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local HorizontalFlexLayout = import("./Layouts.HorizontalFlexLayout")

-- MenuItem is a specific UIElement that all children of Menu should be
---@class MenuItem
local MenuItem = class(function(self, options)
  self.selected = false
  self.TYPE = "MenuItem"
end,
UiElement)

MenuItem.PADDING = 2

-- Takes a label and an optional extra element and makes and combines them into a menu item
-- which is suitable for inserting into a menu
function MenuItem.createMenuItem(label, item)
  assert(label ~= nil)

  local menuItem = UiElement({
    hAlign = "center",
    vAlign = "center",
    layout = HorizontalFlexLayout,
    childGap = 16,
    hFill = true,
    backgroundColor = {math.random(), math.random(), math.random(), 0.4}
  })

  menuItem.width = label.width + (2 * MenuItem.PADDING)

  label.vAlign = "center"
  label.hAlign = "right"
  label.hFill = true
  menuItem:addChild(label)
  if item ~= nil then
    item.vAlign = "center"
    item.hAlign = "left"
    item.hFill = true
    menuItem:addChild(item)
    menuItem.receiveInputs = function(i, inputs)
      item:receiveInputs(inputs)
    end
  end

  return menuItem
end

-- Creates a menu item with just a button
function MenuItem.createButtonMenuItem(text, replacements, translate, onClick)
  assert(text ~= nil)
  local id
  if translate == nil or translate then
    id = text
    text = nil
  end

  local label = Label({
    id = id,
    text = text,
    replacements = replacements,
    hAlign = "center",
    vAlign = "center",
    wrap = false
  })
  local button = Button({
    width = 140,
    maxWidth = 300,
    padding = 8,
    onClick = onClick,
    hAlign = "center",
    vAlign = "center",
  })
  button:addChild(label)

  return button
end

-- Creates a menu item with a label followed by a button
function MenuItem.createLabeledButtonMenuItem(labelText, labelTextReplacements, labelTextTranslate, buttonText, buttonTextReplacements, buttonTextTranslate, buttonOnClick)
  assert(labelText ~= nil)
  assert(buttonText ~= nil)
  assert(buttonOnClick ~= nil)
  local BUTTON_WIDTH = 140
  if labelTextTranslate == nil then
    labelTextTranslate = true
  end
  if buttonTextTranslate == nil then
    buttonTextTranslate = true
  end
  local id
  if labelTextTranslate == nil or labelTextTranslate then
    id = text
    text = nil
  end
  local label = Label({
    id = id,
    text = text,
    replacements = labelTextReplacements,
    vAlign = "center"
  })
  local textButton = TextButton({label = Label({text = buttonText, replacements = buttonTextReplacements, translate = buttonTextTranslate, hAlign = "center", vAlign = "center"}), onClick = buttonOnClick, width = BUTTON_WIDTH})

  local menuItem = MenuItem.createMenuItem(label, textButton)
  menuItem.textButton = textButton

  return menuItem
end

function MenuItem.createStepperMenuItem(text, replacements, translate, stepper)
  assert(text ~= nil)
  local id
  if translate == nil or translate then
    id = text
    text = nil
  end
  local label = Label({
    id = id,
    text = text,
    replacements = replacements,
    vAlign = "center"
  })

  return MenuItem.createMenuItem(label, stepper)
end

function MenuItem.createToggleButtonGroupMenuItem(text, replacements, translate, toggleButtonGroup)
  assert(text ~= nil)
  local id
  if translate == nil or translate then
    id = text
    text = nil
  end
  local label = Label({
    id = id,
    text = text,
    replacements = replacements,
    vAlign = "center"
  })
  return MenuItem.createMenuItem(label, toggleButtonGroup)
end

function MenuItem.createSliderMenuItem(text, replacements, translate, slider)
  assert(text ~= nil)
  local id
  if translate == nil or translate then
    id = text
    text = nil
  end
  local label = Label({
    id = id,
    text = text,
    replacements = replacements,
    vAlign = "center"
  })
  return MenuItem.createMenuItem(label, slider)
end

function MenuItem:setSelected(selected)
  self.selected = selected
  if selected and self.onSelectedFunction then
    self.onSelectedFunction()
  end
end


local DEFAULT_BACKGROUND_COLOR = {1, 1, 1}
local SELECTED_BACKGROUND_COLOR = {0.6, 0.6, 1}
local DEFAULT_BORDER_COLOR = {1, 1, 1}
local SELECTED_BORDER_COLOR = {0.6, 0.6, 1}

function MenuItem:drawSelf()
  local baseOpacity = 0.15
  if self.selected then
    local selectedAdditionalOpacity = 0.5
    local fillOpacity = (math.cos(6 * love.timer.getTime()) + 1) / 16 + baseOpacity + selectedAdditionalOpacity
    local borderOpacity = (math.cos(6 * love.timer.getTime()) + 1) / 4 + baseOpacity + selectedAdditionalOpacity
    GraphicsUtil.drawRectangle("fill", self.x, self.y, self.width, self.height, SELECTED_BACKGROUND_COLOR[1], SELECTED_BACKGROUND_COLOR[2], SELECTED_BACKGROUND_COLOR[3], fillOpacity)
    GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height, SELECTED_BORDER_COLOR[1], SELECTED_BORDER_COLOR[2], SELECTED_BORDER_COLOR[3], borderOpacity)
  else
    GraphicsUtil.drawRectangle("fill", self.x, self.y, self.width, self.height, DEFAULT_BACKGROUND_COLOR[1], DEFAULT_BACKGROUND_COLOR[2], DEFAULT_BACKGROUND_COLOR[3], baseOpacity)
    GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height, DEFAULT_BORDER_COLOR[1], DEFAULT_BORDER_COLOR[2], DEFAULT_BORDER_COLOR[3], baseOpacity)
  end
end

-- inputs as a passthrough in case we ever implement player specific menus
function MenuItem:receiveInputs(inputs)
  for _, child in ipairs(self.children) do
    if child.receiveInputs then
      child:receiveInputs(inputs)
      return
    end
  end
end

return MenuItem
