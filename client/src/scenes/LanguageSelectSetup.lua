local Scene = require("client.src.scenes.Scene")
local ui = require("client.src.ui")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local consts = require("common.engine.consts")
local save = require("client.src.save")
local logger = require("common.lib.logger")

local LanguageSelectSetup = class(function(self, sceneParams)
  self.music = "main"
  self:load(sceneParams)
end, Scene)

function LanguageSelectSetup:load(sceneParams)
  -- Create a centered vertical stack panel for all content
  local contentStack = ui.StackPanel({
    alignment = "top",
    width = consts.CANVAS_WIDTH,
    hAlign = "center",
    vAlign = "center"
  })
  self.uiRoot:addChild(contentStack)

  -- Title
  local titleLabel = ui.Label({
    text = "Select your language",
    translate = false,
    hAlign = "center",
    vAlign = "center"
  })
  contentStack:addElement(titleLabel)

  -- Spacer for gap between title and menu
  local spacer = ui.UiElement({
    width = 1,
    height = 30
  })
  contentStack:addElement(spacer)

  -- Language selection menu
  self.menu = self:createLanguageMenu()
  contentStack:addElement(self.menu)

  contentStack:addElement(ui.UiElement({
    width = 1,
    height = 60
  }))

  self.disclaimerLabel = ui.Label({
    text = "translation_disclaimer",
    hAlign = "center"
  })

  contentStack:addElement(self.disclaimerLabel)
end

LanguageSelectSetup.name = "LanguageSelectSetup"

function LanguageSelectSetup:createLanguageMenu()
  local languageMenuItems = {}
  local languageData, languageLabels = Localization:getLanguageLabelsWithFonts()

  for i, language in ipairs(languageData) do
    table.insert(languageMenuItems, ui.MenuItem.createButtonMenuItemWithLabel(languageLabels[i], function()
      GAME.theme:playValidationSfx()
      config.language_code = language.code
      GAME:setLanguage(language.code)
      write_conf_file()
      GAME.navigationStack:pop()
    end))
  end

  local menu = ui.Menu.createCenteredMenu(languageMenuItems, 0, {supportsBackButton = false})
  return menu
end

function LanguageSelectSetup:update(dt)
  GAME.theme.images.bg_main:update(dt)
  self.menu:receiveInputs()

  for i, menuItem in ipairs(self.menu.menuItems) do
    if menuItem.selected then
      local code = Localization:getLanguageCode(menuItem.textButton.label.text)
      if Localization:get_language() ~= code then
        GAME:setLanguage(code)
        self.disclaimerLabel.fontSize = Localization.languageCodeToFontData[code].fontSize
      end

      self.disclaimerLabel:refreshLocalization()
    end
  end

end

function LanguageSelectSetup:draw()
  GAME.theme.images.bg_main:draw()
  self.uiRoot:draw()
end

return LanguageSelectSetup