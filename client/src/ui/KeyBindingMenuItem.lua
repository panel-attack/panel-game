local PATH = (...):gsub('%.[^%.]+$', '')
local MenuItem = require(PATH .. ".MenuItem")
local Label = require(PATH .. ".Label")
local TextButton = require(PATH .. ".TextButton")
local Layout = require(PATH .. ".Layout")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local class = require("common.lib.class")
local logger = require("common.lib.logger")

---@class KeyBindingMenuItem : MenuItem
local KeyBindingMenuItem = class(function(self, options)
  self.selected = false
  self.settingKey = false
  self.TYPE = "KeyBindingMenuItem"
  self.keyName = options and options.keyName or nil
  self.onActivate = options and options.onActivate or nil
end, MenuItem)

--- Creates a KeyBindingMenuItem with key name label and binding button
---@param options table Options table with keyName, bindingText, onActivate
---@return KeyBindingMenuItem
function KeyBindingMenuItem.create(options)
  assert(options.keyName ~= nil)
  assert(options.bindingText ~= nil)

  local BUTTON_WIDTH = 120
  local SPACE_BETWEEN = 16

  local menuItem = KeyBindingMenuItem(options)

  -- Create key name label (left side)
  local keyLabel = Label({
    text = string.lower(options.keyName),
    fontSize = 12,
    layoutRules = {sizing = {horizontal = Layout.fixed(224)}}
  })

  -- Create binding button (right side)
  local bindingButton = TextButton({
    label = Label({
      text = options.bindingText,
      translate = false,
      fontSize = 12
    }),
    onClick = options.onActivate,
    layoutRules = {sizing = {horizontal = Layout.fixed(BUTTON_WIDTH)}}
  })

  -- Store references
  menuItem.keyLabel = keyLabel
  menuItem.bindingButton = bindingButton

  -- the label and the button in a row, centered on each other
  menuItem:setLayoutRule("childGap", SPACE_BETWEEN)
  menuItem:setLayoutRule("childAlignment", {y = "center"})

  -- Add children
  menuItem:addChild(keyLabel)
  menuItem:addChild(bindingButton)

  return menuItem
end

--- Sets the binding text displayed on the button
---@param text string The binding text to display
function KeyBindingMenuItem:setBinding(text)
  if self.bindingButton and self.bindingButton.label then
    self.bindingButton.label:setText(text, nil, false)
  end
end

--- Sets whether this item is currently setting a key
---@param setting boolean True if actively setting a key
function KeyBindingMenuItem:setSettingKey(setting)
  self.settingKey = setting
end

function KeyBindingMenuItem:drawSelf()
  local baseOpacity = 0.15

  -- Draw subtle glow on button area
  local buttonRect = self.bindingButton.layoutRect
  local buttonX = buttonRect.x
  local buttonY = buttonRect.y
  if self.settingKey then
    -- Active key setting: strong glow on button area with pulse (regardless of selection state)
    local selectedAdditionalOpacity = 0.5
    local fillOpacity = (math.cos(6 * love.timer.getTime()) + 1) / 16 + baseOpacity + selectedAdditionalOpacity
    local borderOpacity = (math.cos(6 * love.timer.getTime()) + 1) / 4 + baseOpacity + selectedAdditionalOpacity

    local bgColor = GAME.theme.colors.menuSelectedBackgroundColor
    local borderColor = GAME.theme.colors.menuSelectedBorderColor
    GraphicsUtil.drawRectangle("fill", buttonX, buttonY, buttonRect.width, buttonRect.height,
      bgColor[1], bgColor[2], bgColor[3], fillOpacity)
    GraphicsUtil.drawRectangle("line", buttonX, buttonY, buttonRect.width, buttonRect.height,
      borderColor[1], borderColor[2], borderColor[3], borderOpacity)
  elseif self.selected then
    -- Normal selection: subtle pulse on button area
    local selectedAdditionalOpacity = 0.1
    local fillOpacity = (math.cos(6 * love.timer.getTime()) + 1) / 16 + baseOpacity + selectedAdditionalOpacity
    local borderOpacity = (math.cos(6 * love.timer.getTime()) + 1) / 4 + baseOpacity + selectedAdditionalOpacity

    local bgColor = GAME.theme.colors.menuSelectedBackgroundColor
    local borderColor = GAME.theme.colors.menuSelectedBorderColor
    GraphicsUtil.drawRectangle("fill", buttonX, buttonY, buttonRect.width, buttonRect.height,
      bgColor[1], bgColor[2], bgColor[3], fillOpacity)
    GraphicsUtil.drawRectangle("line", buttonX, buttonY, buttonRect.width, buttonRect.height,
      borderColor[1], borderColor[2], borderColor[3], borderOpacity)
  else
    -- no special drawing for base case for now, just the elements
  end
end

function KeyBindingMenuItem:receiveInputsSelf(inputSource, dt)
  if self.bindingButton then
    self.bindingButton:receiveInputs(inputSource, dt)
  end
end

return KeyBindingMenuItem
