local import = require("common.lib.import")
local UiElement = import("./UIElement")
local Label = import("./Label")
local Button = import("./Button")
local TextButton = import("./TextButton")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local HorizontalFlexLayout = import("./Layouts.HorizontalFlexLayout")
local addCursorInteractionInterface = import("./CursorInteractable")

-- MenuItem is a wrapper UIElement that bundles a label element with another interactable UIElement and passes through inputs to that second element
---@class MenuItem : UiElement, CursorInteractable
local MenuItem = class(function(self, options)
  addCursorInteractionInterface(self, self.receiveInputs)
end,
UiElement)

MenuItem.TYPE = "MenuItem"
MenuItem.PADDING = 2
MenuItem.layout = HorizontalFlexLayout

-- Takes a label and an optional extra element and makes and combines them into a menu item
-- which is suitable for inserting into a menu
---@param label Label
---@param item UiElement
---@return UiElement | CursorInteractable
function MenuItem.createMenuItem(label, item)
  assert(label ~= nil)

  local menuItem = MenuItem({
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
    item.hFill = true
    item.vAlign = "center"
    menuItem:addChild(item)
    menuItem.item = item
  end

  return menuItem
end

-- Creates just a button as buttons already have their own hover draw
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

  return MenuItem.createMenuItem(label, textButton)
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

local DEFAULT_BACKGROUND_COLOR = {1, 1, 1}
local SELECTED_BACKGROUND_COLOR = {0.6, 0.6, 1}
local DEFAULT_BORDER_COLOR = {1, 1, 1}
local SELECTED_BORDER_COLOR = {0.6, 0.6, 1}

function MenuItem:drawSelf()
  local baseOpacity = 0.15
  if next(self.hoveringCursors) then
    local selectedAdditionalOpacity = 0.5
    local fillOpacity = (math.cos(6 * love.timer.getTime()) + 1) / 16 + baseOpacity + selectedAdditionalOpacity
    local borderOpacity = (math.cos(6 * love.timer.getTime()) + 1) / 4 + baseOpacity + selectedAdditionalOpacity
    GraphicsUtil.drawRectangle("fill", 0, 0, self.width, self.height, SELECTED_BACKGROUND_COLOR[1], SELECTED_BACKGROUND_COLOR[2], SELECTED_BACKGROUND_COLOR[3], fillOpacity)
    GraphicsUtil.drawRectangle("line", 0, 0, self.width, self.height, SELECTED_BORDER_COLOR[1], SELECTED_BORDER_COLOR[2], SELECTED_BORDER_COLOR[3], borderOpacity)
  else
    GraphicsUtil.drawRectangle("fill", 0, 0, self.width, self.height, DEFAULT_BACKGROUND_COLOR[1], DEFAULT_BACKGROUND_COLOR[2], DEFAULT_BACKGROUND_COLOR[3], baseOpacity)
    GraphicsUtil.drawRectangle("line", 0, 0, self.width, self.height, DEFAULT_BORDER_COLOR[1], DEFAULT_BORDER_COLOR[2], DEFAULT_BORDER_COLOR[3], baseOpacity)
  end
end

function MenuItem:receiveInputs(cursor, dt)
  if self.item then
    self.item:receiveInputs(cursor, dt)
  end
end

return MenuItem
