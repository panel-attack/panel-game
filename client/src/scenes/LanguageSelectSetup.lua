local Scene = require("client.src.scenes.Scene")
local ui = require("client.src.ui")
local Layout = require("client.src.ui.Layout")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local consts = require("common.engine.consts")
local save = require("client.src.save")
local logger = require("common.lib.logger")
local InputSource = require("client.src.input.InputSource")

local LanguageSelectSetup = class(function(self, sceneParams)
  self.music = "main"
  self:load(sceneParams)
end, Scene)

function LanguageSelectSetup:load(sceneParams)
  -- Create a centered vertical stack panel for all content
  local contentStack = ui.StackPanel({
    alignment = "top",
    layoutRules = {
      sizing = {horizontal = Layout.fixed(consts.CANVAS_WIDTH)},
      childAlignment = {x = "center"},
      floating = Layout.floatAt("centerCenter")
    }
  })
  self.uiRoot:addChild(contentStack)

  -- Title
  local titleLabel = ui.Label({
    text = "Select your language",
    translate = false
  })
  contentStack:addElement(titleLabel)

  -- Spacer for gap between title and menu
  local spacer = ui.UiElement({
    layoutRules = {sizing = Layout.fixedSize(1, 30)}
  })
  contentStack:addElement(spacer)

  -- Language selection menu
  self.menu = self:createLanguageMenu()
  -- the menu takes its place in the stack rather than centering itself on the screen
  self.menu:setLayoutRule("floating", nil)
  contentStack:addElement(self.menu)

  contentStack:addElement(ui.UiElement({
    layoutRules = {sizing = Layout.fixedSize(1, 60)}
  }))

  self.disclaimerLabel = ui.Label({
    text = "",
    translate = false
  })

  contentStack:addElement(self.disclaimerLabel)
  self:setLanguage(Localization:get_language())
end

-- Switches the game to the language and shows its translation disclaimer, which English doesn't have
---@param languageCode LanguageCode
function LanguageSelectSetup:setLanguage(languageCode)
  GAME:setLanguage(languageCode)
  self.disclaimerLabel.fontSize = Localization.languageCodeToFontData[languageCode].fontSize
  if languageCode == "EN" then
    self.disclaimerLabel:setText("", nil, false)
  else
    self.disclaimerLabel:setText("translation_disclaimer", nil, true)
    self.disclaimerLabel:refreshLocalization()
  end
end

LanguageSelectSetup.name = "LanguageSelectSetup"

function LanguageSelectSetup:createLanguageMenu()
  local languageMenuItems = {}
  local languageData, languageLabels = Localization:getLanguageLabelsWithFonts()

  for i, language in ipairs(languageData) do
    table.insert(languageMenuItems, ui.MenuItem.createButtonMenuItemWithLabel(languageLabels[i], function()
      self:playValidationSfx()
      config.language_code = language.code
      GAME:setLanguage(language.code)
      write_conf_file()
      GAME.navigationStack:pop()
      for _, scene in ipairs(GAME.navigationStack.scenes) do
        scene:refreshLocalization()
      end
    end))
  end

  local menu = ui.Menu.createCenteredMenu(languageMenuItems, 0, {supportsBackButton = false})
  return menu
end

function LanguageSelectSetup:update(dt)
  GAME.theme.images.bg_main:update(dt)
  
  for i, menuItem in ipairs(self.menu.menuItems) do
    if menuItem.selected then
      local code = Localization:getLanguageCode(menuItem.textButton.label.text)
      if Localization:get_language() ~= code then
        self:setLanguage(code)
      end
    end
  end
  
  self.menu:receiveInputs(InputSource.anyPlayer, dt)
end

function LanguageSelectSetup:draw()
  GAME.theme.images.bg_main:draw()
  self.uiRoot:draw()
end

return LanguageSelectSetup