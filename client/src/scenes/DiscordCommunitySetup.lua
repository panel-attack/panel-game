local Scene = require("client.src.scenes.Scene")
local ui = require("client.src.ui")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local consts = require("common.engine.consts")
local save = require("client.src.save")
local InputConfigMenu = require("client.src.scenes.InputConfigMenu")
local logger = require("common.lib.logger")

local DiscordCommunitySetup = class(function(self, sceneParams)
  self.music = "main"

  local titleFontSize = 28
  local bodyFontSize = 16

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
    text = "Unofficial Beta Build",
    translate = false,
    hAlign = "center",
    vAlign = "center"
  })
  contentStack:addElement(titleLabel)
  
  contentStack:addElement(ui.UiElement({
    width = 1,
    height = 10
  }))

  if GAME.theme.images.unofficial_brand_square then
    local brandImage = ui.ImageContainer({
      image = GAME.theme.images.unofficial_brand_square,
      width = 220,
      height = 220,
      hAlign = "center"
    })
    contentStack:addElement(brandImage)
    contentStack:addElement(ui.UiElement({
      width = 1,
      height = 12
    }))
  end
  
  -- Message lines
  local messageLine1 = ui.Label({
    fontSize = bodyFontSize,
    text = "This is an unofficial version of Panel Attack.",
    translate = false,
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
    text = "Please do NOT report bugs to the official Panel Attack team.",
    translate = false,
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
    text = "This build is beta. If you have questions or bugs, contact bramp.",
    translate = false,
    hAlign = "center",
    vAlign = "center"
  })
  contentStack:addElement(messageLine3)

  local continueButton = ui.MenuItem.createButtonMenuItem("Continue", nil, false, function()
    GAME.theme:playValidationSfx()
    config.discordCommunityShown = true
    write_conf_file()
    GAME.navigationStack:pop()
  end)
  
  contentStack:addElement(ui.UiElement({
    width = 1,
    height = 20
  }))
  
  -- Menu buttons
  local menu = ui.Menu.createCenteredMenu({continueButton}, 0)
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
  GraphicsUtil.drawRectangle("fill", 0, 0, consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT, 0, 0, 0, 0.55)
  self.uiRoot:draw()
end

return DiscordCommunitySetup