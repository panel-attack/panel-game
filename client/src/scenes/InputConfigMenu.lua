local Scene = require("client.src.scenes.Scene")
local tableUtils = require("common.lib.tableUtils")
local ui = require("client.src.ui")
local consts = require("common.engine.consts")
local inputManager = require("client.src.inputManager")
local class = require("common.lib.class")
local InputConfigSlider = require("client.src.ui.InputConfigSlider")
local KeyBindingMenuItem = require("client.src.ui.KeyBindingMenuItem")

-- Sometimes controllers register buttons as "pressed" even though they aren't. If they have been pressed longer than this they don't count.
local MAX_PRESS_DURATION = 0.5
local pendingInputText = "__"

-- Represents the state of the InputConfigMenu
-- NOT_SETTING: when we are not polling for a new key
-- SETTING_KEY_TRANSITION: skip a frame so we don't use the button activation key as the configured key
-- SETTING_KEY: currently polling for a single key
-- SETTING_ALL_KEYS: currently polling for all keys
local KEY_SETTING_STATE = { NOT_SETTING = nil, SETTING_KEY_TRANSITION = 1, SETTING_KEY = 2, SETTING_ALL_KEYS_TRANSITION = 3, SETTING_ALL_KEYS = 4 }

-- Scene for configuring input
local InputConfigMenu = class(
  function (self, sceneParams)
    self.music = "main"
    self.settingKey = false
    self.menu = nil
    self.backgroundImg = nil
    self.newInputsConfigured = inputManager.hasUnsavedChanges
    self.configIndex = 1

    self:loadUI()

    self:autoConfigureJoysticks()

    self:setSettingKeyState(KEY_SETTING_STATE.NOT_SETTING)

    -- Listen for unconfigured joysticks being added
    inputManager:connectSignal("unconfiguredJoystickAdded", self, self.onUnconfiguredJoystickAdded)
  end,
  Scene
)

InputConfigMenu.name = "InputConfigMenu"

function InputConfigMenu:setSettingKeyState(keySettingState)
  self.settingKey = keySettingState ~= KEY_SETTING_STATE.NOT_SETTING
  self.settingKeyState = keySettingState
  self.menu:setEnabled(not self.settingKey)

  -- Update back button color based on configuration completeness
  if self.backMenuItem and self.backMenuItem.textButton then
    if self:allInputConfigurationsValid() then
      self.backMenuItem.textButton.backgroundColor = GAME.theme.colors.configCorrectBackgroundColor
    else
      self.backMenuItem.textButton.backgroundColor = GAME.theme.colors.incompleteConfigBackgroundColor
    end
  end
end

function InputConfigMenu:allInputConfigurationsValid()
  local result = true

  for _, config in ipairs(inputManager.inputConfigurations) do
    
    local isIncomplete = not config:isEmpty() and not config:isFullyConfigured()
    if isIncomplete then
      result = false
      break
    end
  end

  return result
end

function InputConfigMenu:getKeyDisplayName(key)
  local config = inputManager.inputConfigurations[self.configIndex]
  return config:getButtonDisplayName(key)
end

function InputConfigMenu:updateInputConfigMenuLabels()
  for i, key in ipairs(consts.KEY_NAMES) do
    local keyDisplayName = self:getKeyDisplayName(inputManager.inputConfigurations[self.configIndex][key])
    self:currentKeyLabelForIndex(i + 1):setText(keyDisplayName, nil, false)
  end
end

function InputConfigMenu:currentKeyLabelForIndex(index)
  -- Index is 1-based for key bindings (1 = first key)
  -- Menu item index = index + 1 (account for slider at index 1)
  local menuItem = self.menu.menuItems[index]
  if menuItem.bindingButton and menuItem.bindingButton.label then
    return menuItem.bindingButton.label
  else
    return menuItem.textButton.children[1]
  end
end

function InputConfigMenu:updateKey(key, pressedKey, index)
  GAME.theme:playValidationSfx()
  local config = inputManager.inputConfigurations[self.configIndex]
  inputManager:changeKeyBindingOnInputConfiguration(config, key, pressedKey)
  local keyDisplayName = self:getKeyDisplayName(pressedKey)

  -- Update the menu item (index + 1 to account for slider at position 1)
  local menuItemIndex = index + 1
  local menuItem = self.menu.menuItems[menuItemIndex]
  if menuItem.setBinding then
    menuItem:setBinding(keyDisplayName)
  end
  if menuItem.setSettingKey then
    menuItem:setSettingKey(false)
  end

  self:refreshUI()
end

function InputConfigMenu:setKey(key, index)
  local pressedKey = next(inputManager.allKeys.isDown)
  if pressedKey then
    self:updateKey(key, pressedKey, index)
    self:setSettingKeyState(KEY_SETTING_STATE.NOT_SETTING)
  end
end

function InputConfigMenu:setAllKeys()
  local pressedKey = next(inputManager.allKeys.isDown)
  if pressedKey then
    self:updateKey(consts.KEY_NAMES[self.index], pressedKey, self.index)
    if self.index < #consts.KEY_NAMES then
      self.index = self.index + 1
      local menuItemIndex = self.index + 1 
      local menuItem = self.menu.menuItems[menuItemIndex]
      if menuItem.setBinding then
        menuItem:setBinding(pendingInputText)
      end
      if menuItem.setSettingKey then
        menuItem:setSettingKey(true)
      end
      self.menu:setSelectedIndex(menuItemIndex)
      self:setSettingKeyState(KEY_SETTING_STATE.SETTING_ALL_KEYS_TRANSITION)
    else
      self:setSettingKeyState(KEY_SETTING_STATE.NOT_SETTING)
    end
  end
end

function InputConfigMenu:setKeyStart(key)
  GAME.theme:playValidationSfx()
  self.key = key
  self.index = nil
  for i, k in ipairs(consts.KEY_NAMES) do
    if k == key then
      self.index = i
      break
    end
  end
  local menuItemIndex = self.index + 1 
  local menuItem = self.menu.menuItems[menuItemIndex]
  if menuItem.setBinding then
    menuItem:setBinding(pendingInputText)
  end
  if menuItem.setSettingKey then
    menuItem:setSettingKey(true)
  end
  self.menu:setSelectedIndex(menuItemIndex)
  self:setSettingKeyState(KEY_SETTING_STATE.SETTING_KEY_TRANSITION)
end

function InputConfigMenu:setAllKeysStart()
  GAME.theme:playValidationSfx()
  self.index = 1
  local menuItemIndex = self.index + 1 
  local menuItem = self.menu.menuItems[menuItemIndex]
  if menuItem.setBinding then
    menuItem:setBinding(pendingInputText)
  end
  if menuItem.setSettingKey then
    menuItem:setSettingKey(true)
  end
  self.menu:setSelectedIndex(menuItemIndex)
  self:setSettingKeyState(KEY_SETTING_STATE.SETTING_ALL_KEYS_TRANSITION)
end

function InputConfigMenu:clearAllInputs()
  GAME.theme:playValidationSfx()
  local config = inputManager.inputConfigurations[self.configIndex]
  inputManager:clearKeyBindingsOnInputConfiguration(config)
  self:refreshUI()
  self:setSettingKeyState(KEY_SETTING_STATE.NOT_SETTING)
end

function InputConfigMenu:resetToDefault(menuOptions)
  GAME.theme:playValidationSfx()
  inputManager:setupDefaultKeyConfigurations()
  GAME.theme:playMoveSfx()
  self.slider:setValue(1)
  self.configIndex = 1
  self:refreshUI()
  self:setSettingKeyState(KEY_SETTING_STATE.NOT_SETTING)
end

function InputConfigMenu:autoConfigureJoysticks()

  -- Auto-configure any newly connected joysticks
  for _, joystick in ipairs(inputManager:getUnconfiguredJoysticks()) do
    -- Use inputManager to perform the actual configuration
    local configIndex = inputManager:autoConfigureJoystick(joystick, true)

    if configIndex then
      -- Flag that a new controller was just configured
      self.newInputsConfigured = true

      self.configIndex = configIndex
      self.slider:setValue(configIndex)
      self:refreshUI()
    end
  end
end

-- Signal handler called when an unconfigured joystick is added
function InputConfigMenu:onUnconfiguredJoystickAdded(joystick)
  -- Auto-configure the joystick
  local configIndex = inputManager:autoConfigureJoystick(joystick, true)

  if configIndex then
    -- Flag that a new controller was just configured
    self.newInputsConfigured = true

    -- Switch to the newly configured input
    self.configIndex = configIndex
    self.slider:setValue(configIndex)
    self:refreshUI()
  end
end

function InputConfigMenu:createExitMenuFunction()
  return function ()
    local currentConfig = inputManager.inputConfigurations[self.configIndex]

    -- Check if current configuration is half-configured
    if not currentConfig:isEmpty() and not currentConfig:isFullyConfigured() then
      return
    end

    GAME.theme:playValidationSfx()
    if inputManager.hasUnsavedChanges then
      inputManager:saveInputConfigurationMappings()
    end

    GAME.navigationStack:pop()
  end
end

function InputConfigMenu:loadUI()

  self.backgroundImg = themes[config.theme].images.bg_main

  -- Create a centered vertical stack panel for all content
  local contentStack = ui.StackPanel({
    alignment = "top",
    width = consts.CANVAS_WIDTH,
    hAlign = "center",
    vAlign = "center"
  })

  -- Header text
  local headerText = ui.Label({
    text = "config_input_welcome",
    hAlign = "center",
    vAlign = "center",
    fontSize = 16
  })
  contentStack:addElement(headerText)

  contentStack:addElement(ui.UiElement({
    width = 1,
    height = 10
  }))

  -- New controller message (conditionally visible)
  self.newControllerLabel = ui.Label({
    text = "input_config_new_controller",
    hAlign = "center",
    vAlign = "center",
    textColor = GAME.theme.colors.highlightTextColor,
    fontSize = 14
  })
  self.newControllerLabel.isVisible = false
  contentStack:addElement(self.newControllerLabel)

  contentStack:addElement(ui.UiElement({
    width = 1,
    height = 10
  }))

  -- Create menu options
  local menuOptions = {}

  -- 1. Slider
  self.slider = InputConfigSlider({
    value = self.configIndex,
    onValueChange = function(slider)
      self.configIndex = slider.value
      self:refreshUI()
    end
  })
  menuOptions[1] = ui.SliderMenuItem.create({
    labelText = "configuration",
    slider = self.slider
  })

  -- 2. Key binding items
  for i, key in ipairs(consts.KEY_NAMES) do
    local keyDisplayName = self:getKeyDisplayName(inputManager.inputConfigurations[self.configIndex][key])
    local keyBindingItem = KeyBindingMenuItem.create({
      keyName = key,
      bindingText = keyDisplayName,
      onActivate = function()
        if not self.settingKey then
          self:setKeyStart(key)
        end
      end
    })
    menuOptions[#menuOptions + 1] = keyBindingItem
  end

  -- 3. Action buttons
  menuOptions[#menuOptions + 1] = ui.MenuItem.createButtonMenuItem("op_all_keys", nil, nil, function() self:setAllKeysStart() end)
  menuOptions[#menuOptions + 1] = ui.MenuItem.createButtonMenuItem("Clear All Inputs", nil, false, function() self:clearAllInputs() end)
  menuOptions[#menuOptions + 1] = ui.MenuItem.createButtonMenuItem("Reset Keys To Default", nil, false, function() self:resetToDefault() end)

  -- Back button with warning for incomplete configurations
  self.backMenuItem = ui.MenuItem.createButtonMenuItem("back", nil, nil, self:createExitMenuFunction())
  menuOptions[#menuOptions + 1] = self.backMenuItem

  self.menu = ui.Menu.createCenteredMenu(menuOptions, 0)
  contentStack:addElement(self.menu)

  self.uiRoot:addChild(contentStack)
end

function InputConfigMenu:update(dt)

  if self.backgroundImg then
    self.backgroundImg:update(dt)
  end

  -- Only allow menu navigation when not setting a key
  if self.menu and not self.settingKey then
    self.menu:receiveInputs()
  end

  local noKeysHeld = (tableUtils.first(inputManager.allKeys.isPressed, function (value)
    return value < MAX_PRESS_DURATION
  end)) == nil

  if self.settingKeyState == KEY_SETTING_STATE.SETTING_KEY_TRANSITION then
    if noKeysHeld then
      self:setSettingKeyState(KEY_SETTING_STATE.SETTING_KEY)
    end
  elseif self.settingKeyState == KEY_SETTING_STATE.SETTING_ALL_KEYS_TRANSITION then
    if noKeysHeld then
      self:setSettingKeyState(KEY_SETTING_STATE.SETTING_ALL_KEYS)
    end
  elseif self.settingKeyState == KEY_SETTING_STATE.SETTING_KEY then
    self:setKey(self.key, self.index)
  elseif self.settingKeyState == KEY_SETTING_STATE.SETTING_ALL_KEYS then
    self:setAllKeys()
  end

  self:refreshUI()
end

function InputConfigMenu:refreshUI()
  self.slider:refresh()
  self.newControllerLabel.isVisible = self.newInputsConfigured
  self:updateInputConfigMenuLabels()
end

function InputConfigMenu:draw()
  themes[config.theme].images.bg_main:draw()
  self.uiRoot:draw()
end

return InputConfigMenu
