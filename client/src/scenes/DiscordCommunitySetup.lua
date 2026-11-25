local Scene = require("client.src.scenes.Scene")
local ui = require("client.src.ui")
local Layout = require("client.src.ui.Layout")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local consts = require("common.engine.consts")
local save = require("client.src.save")
local InputConfigMenu = require("client.src.scenes.InputConfigMenu")
local logger = require("common.lib.logger")
local InputSource = require("client.src.input.InputSource")

local DiscordCommunitySetup = class(function(self, sceneParams)
  self.music = "main"

  local titleFontSize = 28
  local bodyFontSize = 14

  -- Create a centered vertical stack panel for all content
  local contentStack = ui.StackPanel({
    alignment = "top",
    layoutRules = {
      sizing = {horizontal = Layout.fixed(consts.CANVAS_WIDTH)},
      childAlignment = {x = "center"},
      floating = Layout.floatAt("centerCenter")
    }
  })
  
  -- Title
  local titleLabel = ui.Label({
    fontSize = titleFontSize,
    text = "discord_welcome_title"
  })
  contentStack:addElement(titleLabel)
  
  contentStack:addElement(ui.UiElement({
    layoutRules = {sizing = Layout.fixedSize(1, 10)}
  }))
  
  -- Discord logo
  local discordLogo = ui.ImageContainer({
    image = love.graphics.newImage("client/assets/themes/Panel Attack Modern/discord_logo.png"),
    layoutRules = {sizing = Layout.fixedSize(160, 160)}
  })
  contentStack:addElement(discordLogo)
  
  contentStack:addElement(ui.UiElement({
    layoutRules = {sizing = Layout.fixedSize(1, 10)}
  }))
  
  -- Message lines
  local messageLine1 = ui.Label({
    fontSize = bodyFontSize,
    text = "discord_message_line1"
  })
  contentStack:addElement(messageLine1)

  contentStack:addElement(ui.UiElement({
    layoutRules = {sizing = Layout.fixedSize(1, 10)}
  }))

  local messageLine2 = ui.Label({
    fontSize = bodyFontSize,
    text = "discord_message_line2"
  })
  contentStack:addElement(messageLine2)
  
  contentStack:addElement(ui.UiElement({
    layoutRules = {sizing = Layout.fixedSize(1, 10)}
  }))

  local messageLine3 = ui.Label({
    fontSize = bodyFontSize,
    text = "discord_message_line3"
  })
  contentStack:addElement(messageLine3)

  local discordLinkButton = ui.MenuItem.createButtonMenuItem("discord_join_link", nil, nil, function()
    self:playValidationSfx()
    love.system.openURL("https://discord.panelattack.com")
  end)
  
  local continueButton = ui.MenuItem.createButtonMenuItem("next_button", nil, nil, function()
    self:playValidationSfx()
    config.discordCommunityShown = true
    write_conf_file()
    GAME.navigationStack:pop()
  end)
  
  contentStack:addElement(ui.UiElement({
    layoutRules = {sizing = Layout.fixedSize(1, 20)}
  }))
  
  -- Menu buttons
  local menu = ui.Menu.createCenteredMenu({discordLinkButton, continueButton}, 0)
  -- the menu takes its place in the stack rather than centering itself on the screen
  menu:setLayoutRule("floating", nil)
  contentStack:addElement(menu)
  self.menu = menu

  self.uiRoot:addChild(contentStack)
end, Scene)

DiscordCommunitySetup.name = "DiscordCommunitySetup"

function DiscordCommunitySetup:update(dt)
  GAME.theme.images.bg_main:update(dt)
  self.menu:receiveInputs(InputSource.anyPlayer, dt)
end

function DiscordCommunitySetup:draw()
  GAME.theme.images.bg_main:draw()
  self.uiRoot:draw()
end

return DiscordCommunitySetup