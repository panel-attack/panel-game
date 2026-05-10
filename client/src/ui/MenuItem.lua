local PATH = (...):gsub('%.[^%.]+$', '')
local UiElement = require(PATH .. ".UIElement")
local Label = require(PATH .. ".Label")
local TextButton = require(PATH .. ".TextButton")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local system = require("client.src.system")
local DebugSettings = require("client.src.debug.DebugSettings")

---@class MenuItem : UiElement
---@field selected boolean whether this menu item is currently selected
---@field TYPE string type identifier for this class
---@field textButton TextButton? optional reference to a text button if this item contains one
---@field onSelectedFunction function? callback function to execute when the item is selected

---@class MenuItemOptions : UiElementOptions

---@class MenuItem
---@overload fun(options: MenuItemOptions): MenuItem
local MenuItem = class(
  function(self, options)
  self.selected = false
  self.TYPE = "MenuItem"
end,
UiElement)

MenuItem.PADDING = 8
MenuItem.GROUP_PADDING = 15

---Takes a label and an optional extra element and makes and combines them into a menu item which is suitable for inserting into a menu
---@param label UiElement the label or left element to display
---@param item UiElement? optional right element to display
---@return MenuItem
function MenuItem.createMenuItem(label, item)
  assert(label ~= nil)

  label.vAlign = "center"
  label.x = MenuItem.PADDING

  local menuItem = MenuItem({x = 0, y = 0})

  menuItem.width = label.width + (2 * MenuItem.PADDING)

  if system.isMobileOS() or DebugSettings.simulateMobileOS() then
    label.height = math.max(30, label.height + (2 * MenuItem.PADDING))
    menuItem.height = math.max(30, label.height, item and item.height or 0)
  else
    menuItem.height = math.max(menuItem.height, math.max(label.height, item and item.height or 0) + (2 * MenuItem.PADDING))
  end

  if item ~= nil then
    local spaceBetween = 24
    item.x = label.width + spaceBetween
    item.vAlign = "center"
    if system.isMobileOS() or DebugSettings.simulateMobileOS() then
      item.height = math.max(30, item.height)
    end
    menuItem.width = item.x + item.width + MenuItem.PADDING
    menuItem:addChild(item)
  end

  -- Support section headers / team separators.
  if label.isSectionHeader then
    menuItem.height = menuItem.height + (2 * MenuItem.GROUP_PADDING)
    label.y = MenuItem.GROUP_PADDING
  end

  menuItem:addChild(label)
  return menuItem
end

function MenuItem.createSectionHeader(text)
  local label = Label({
    text = text,
    translate = false,
    hAlign = "center",
    vAlign = "center"
  })
  label.isSectionHeader = true

  local section = MenuItem.createMenuItem(label)
  section.height = section.height + (2 * MenuItem.GROUP_PADDING)
  return section
end

---Creates a menu item with just a button, using a pre-created Label
---@param label Label the label to use for the button
---@param onClick function callback function when the button is clicked
---@param width number? optional width for the button (defaults to 140)
---@return MenuItem
function MenuItem.createButtonMenuItemWithLabel(label, onClick, width)
  assert(label ~= nil)
  local BUTTON_WIDTH = width or 140
  label.hAlign = "center"
  label.vAlign = "center"

  local textButton = TextButton({
    label = label,
    onClick = onClick,
    width = BUTTON_WIDTH
  })

  local menuItem = MenuItem.createMenuItem(textButton)
  menuItem.textButton = textButton

  return menuItem
end

---Creates a menu item with just a button
---@param text string the text to display on the button
---@param replacements table<string, string>? optional text replacements for localization
---@param translate boolean? whether to translate the text (defaults to true)
---@param onClick function callback function when the button is clicked
---@param width number? optional width for the button (defaults to 140)
---@return MenuItem
function MenuItem.createButtonMenuItem(text, replacements, translate, onClick, width)
  assert(text ~= nil)
  if translate == nil then
    translate = true
  end

  local label = Label({
    text = text,
    replacements = replacements,
    translate = translate
  })

  return MenuItem.createButtonMenuItemWithLabel(label, onClick, width)
end

---Creates a menu item with a label followed by a button
---@param labelText string the text for the left label
---@param labelTextReplacements table<string, string>? optional text replacements for label localization
---@param labelTextTranslate boolean? whether to translate the label text (defaults to true)
---@param buttonText string the text for the button
---@param buttonTextReplacements table<string, string>? optional text replacements for button localization
---@param buttonTextTranslate boolean? whether to translate the button text (defaults to true)
---@param buttonOnClick function callback function when the button is clicked
---@param width number? optional width for the button (defaults to 140)
---@return MenuItem
function MenuItem.createLabeledButtonMenuItem(labelText, labelTextReplacements, labelTextTranslate, buttonText, buttonTextReplacements, buttonTextTranslate, buttonOnClick, width)
  assert(labelText ~= nil)
  assert(buttonText ~= nil)
  assert(buttonOnClick ~= nil)
  local BUTTON_WIDTH = width or 140
  if labelTextTranslate == nil then
    labelTextTranslate = true
  end
  if buttonTextTranslate == nil then
    buttonTextTranslate = true
  end

  local label = Label({text = labelText, replacements = labelTextReplacements, translate = labelTextTranslate, vAlign = "center"})
  local textButton = TextButton({label = Label({text = buttonText, replacements = buttonTextReplacements, translate = buttonTextTranslate, hAlign = "center", vAlign = "center"}), onClick = buttonOnClick, width = BUTTON_WIDTH})

  local menuItem = MenuItem.createMenuItem(label, textButton)
  menuItem.textButton = textButton

  return menuItem
end

---Creates a menu item with a label and a stepper control
---@param text string the text for the label
---@param replacements table<string, string>? optional text replacements for localization
---@param translate boolean? whether to translate the text (defaults to true)
---@param stepper UiElement the stepper control element
---@return MenuItem
function MenuItem.createStepperMenuItem(text, replacements, translate, stepper)
  assert(text ~= nil)
  assert(stepper ~= nil)
  if translate == nil then
    translate = true
  end
  local label = Label({text = text, replacements = replacements, translate = translate, vAlign = "center"})
  local menuItem = MenuItem.createMenuItem(label, stepper)
  
  return menuItem
end

---Creates a menu item with a label and a toggle button group
---@param text string the text for the label
---@param replacements table<string, string>? optional text replacements for localization
---@param translate boolean? whether to translate the text (defaults to true)
---@param toggleButtonGroup UiElement the toggle button group element
---@return MenuItem
function MenuItem.createToggleButtonGroupMenuItem(text, replacements, translate, toggleButtonGroup)
  assert(text ~= nil)
  assert(toggleButtonGroup ~= nil)
  if translate == nil then
    translate = true
  end
  local label = Label({text = text, replacements = replacements, translate = translate, vAlign = "center"})
  local menuItem = MenuItem.createMenuItem(label, toggleButtonGroup)
  
  return menuItem
end

---Creates a menu item with a label and a slider control
---@param text string the text for the label
---@param replacements table<string, string>? optional text replacements for localization
---@param translate boolean? whether to translate the text (defaults to true)
---@param slider UiElement the slider control element
---@return MenuItem
function MenuItem.createSliderMenuItem(text, replacements, translate, slider)
  assert(text ~= nil)
  assert(slider ~= nil)
  if translate == nil then
    translate = true
  end
  local label = Label({text = text, replacements = replacements, translate = translate, vAlign = "center"})
  local menuItem = MenuItem.createMenuItem(label, slider)

  return menuItem
end

function MenuItem.createBoolSelectorMenuItem(text, replacements, translate, boolSelector)
  assert(text ~= nil)
  assert(boolSelector ~= nil)
  if translate == nil then
    translate = true
  end
  local label = Label({text = text, replacements = replacements, translate = translate, vAlign = "center"})
  local menuItem = MenuItem.createMenuItem(label, boolSelector)

  return menuItem
end

---Sets the selected state of this menu item
---@param selected boolean whether the item should be selected
function MenuItem:setSelected(selected)
  self.selected = selected
  if selected and self.onSelectedFunction then
    self.onSelectedFunction()
  end
end


---Draws the menu item background and selection highlight
function MenuItem:drawSelf()
  local cornerRadius = 32
  local borderWidth = 4

  if self.selected then
    local bgColor = GAME.theme.colors.menuSelectedBackgroundColor
    local borderColor = GAME.theme.colors.menuSelectedBorderColor

    GraphicsUtil.drawRectangle("fill", self.x, self.y, self.width, self.height, bgColor[1], bgColor[2], bgColor[3], 1.0, cornerRadius, cornerRadius)

    for w = 1, borderWidth do
      GraphicsUtil.drawRectangle("line", self.x - w, self.y - w, self.width + 2*w, self.height + 2*w,
        borderColor[1], borderColor[2], borderColor[3], 1.0, cornerRadius, cornerRadius)
    end
  else
    local bgColor = GAME.theme.colors.menuDefaultBackgroundColor
    local borderColor = GAME.theme.colors.menuDefaultBorderColor

    GraphicsUtil.drawRectangle("fill", self.x, self.y, self.width, self.height, bgColor[1], bgColor[2], bgColor[3], bgColor[4], cornerRadius, cornerRadius)

    for w = 1, 1 do
      GraphicsUtil.drawRectangle("line", self.x - w, self.y - w, self.width + 2*w, self.height + 2*w,
        borderColor[1], borderColor[2], borderColor[3], borderColor[4], cornerRadius, cornerRadius)
    end
  end
end

---Passes inputs to child elements that can receive them
---@param inputs table input state table
function MenuItem:receiveInputs(inputs)
  for _, child in ipairs(self.children) do
    if child.receiveInputs then
      child:receiveInputs(inputs)
      return
    end
  end
end

return MenuItem
