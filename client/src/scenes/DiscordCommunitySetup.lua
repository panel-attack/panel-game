local Scene = require("client.src.scenes.Scene")
local ui = require("client.src.ui")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local consts = require("common.engine.consts")
local save = require("client.src.save")
local InputConfigMenu = require("client.src.scenes.InputConfigMenu")
local logger = require("common.lib.logger")

local DiscordCommunitySetup = class(function(self, sceneParams)
  assert(sceneParams, "DiscordCommunitySetup requires sceneParams")
  assert(sceneParams.triggerNextScene, "DiscordCommunitySetup requires triggerNextScene callback")

  self.music = "main"

  local titleFontSize = 28
  local bodyFontSize = 14

  -- Create a centered vertical stack panel for all content
  local contentStack = ui.StackPanel({
    alignment = "top",
    width = consts.CANVAS_WIDTH,
    hAlign = "center",
    vAlign = "center"
  })
  
  -- Title
  local titleLabel = ui.Label({
    fontSize = titleFontSize,
    text = "discord_welcome_title",
    hAlign = "center",
    vAlign = "center"
  })
  contentStack:addElement(titleLabel)
  
  contentStack:addElement(ui.UiElement({
    width = 1,
    height = 10
  }))
  
  -- Discord logo
  local discordLogo = ui.ImageContainer({
    image = love.graphics.newImage("client/assets/themes/Panel Attack Modern/discord_logo.png"),
    width = 160,
    height = 160,
    hAlign = "center"
  })
  contentStack:addElement(discordLogo)
  
  contentStack:addElement(ui.UiElement({
    width = 1,
    height = 10
  }))
  
  -- Message lines
  local messageLine1 = ui.Label({
    fontSize = bodyFontSize,
    text = "discord_message_line1",
    hAlign = "center",
    vAlign = "center"
  })
  contentStack:addElement(messageLine1)

  contentStack:addElement(ui.UiElement({
    width = 1,
    height = 10
  }))

  local messageLine2 = ui.Label({
    fontSize = bodyFontSize,
    text = "discord_message_line2",
    hAlign = "center",
    vAlign = "center"
  })
  contentStack:addElement(messageLine2)
  
  contentStack:addElement(ui.UiElement({
    width = 1,
    height = 10
  }))

  local messageLine3 = ui.Label({
    fontSize = bodyFontSize,
    text = "discord_message_line3",
    hAlign = "center",
    vAlign = "center"
  })
  contentStack:addElement(messageLine3)

  local discordLinkButton = ui.MenuItem.createButtonMenuItem("discord_join_link", nil, nil, function()
    GAME.theme:playValidationSfx()
    love.system.openURL("https://discord.panelattack.com")
  end)
  
  local continueButton = ui.MenuItem.createButtonMenuItem("next_button", nil, nil, function()
    GAME.theme:playValidationSfx()
    config.discordCommunityShown = true
    write_conf_file()
    self.triggerNextScene()
  end)
  
  contentStack:addElement(ui.UiElement({
    width = 1,
    height = 20
  }))
  
  -- Menu buttons
  local menu = ui.Menu.createCenteredMenu({discordLinkButton, continueButton}, 0)
  contentStack:addElement(menu)
  self.menu = menu

  self.uiRoot:addChild(contentStack)
end, Scene)

DiscordCommunitySetup.name = "DiscordCommunitySetup"

function DiscordCommunitySetup:update(dt)
  GAME.theme.images.bg_main:update(dt)
  self.menu:receiveInputs()
end

function DiscordCommunitySetup:draw()
  GAME.theme.images.bg_main:draw()
  self.uiRoot:draw()
end

return DiscordCommunitySetup