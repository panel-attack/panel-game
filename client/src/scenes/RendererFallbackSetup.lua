local Scene = require("client.src.scenes.Scene")
local ui = require("client.src.ui")
local Layout = require("client.src.ui.Layout")
local class = require("common.lib.class")
local consts = require("common.engine.consts")
local InputSource = require("client.src.input.InputSource")
local RendererSetting = require("client.src.graphics.RendererSetting")

-- Shown at startup after the game restarted itself without Vulkan because Vulkan stopped working.
-- Asks whether to keep starting on OpenGL; otherwise the next launch lets LÖVE pick again.
---@class RendererFallbackSetup : Scene
local RendererFallbackSetup = class(function(self, sceneParams)
  self.music = "main"

  local contentStack = ui.StackPanel({
    alignment = "top",
    layoutRules = {
      sizing = {horizontal = Layout.fixed(consts.CANVAS_WIDTH)},
      childAlignment = {x = "center"},
      floating = Layout.floatAt("centerCenter")
    }
  })

  contentStack:addElement(ui.Label({
    fontSize = 28,
    text = "renderer_fallback_title"
  }))
  contentStack:addElement(ui.UiElement({layoutRules = {sizing = Layout.fixedSize(1, 10)}}))
  contentStack:addElement(ui.Label({
    fontSize = 14,
    text = "renderer_fallback_message",
    replacements = {sceneParams.rendererName}
  }))
  contentStack:addElement(ui.UiElement({layoutRules = {sizing = Layout.fixedSize(1, 20)}}))

  local keepButton = ui.MenuItem.createButtonMenuItem("renderer_fallback_keep", nil, nil, function()
    self:playValidationSfx()
    self:keepFallbackRenderer()
  end)
  local tryAgainButton = ui.MenuItem.createButtonMenuItem("renderer_fallback_try_again", nil, nil, function()
    self:playValidationSfx()
    self:tryDefaultRendererAgain()
  end)
  self.menu = ui.Menu.createCenteredMenu({keepButton, tryAgainButton}, 0)
  -- the menu takes its place in the stack rather than centering itself on the screen
  self.menu:setLayoutRule("floating", nil)
  contentStack:addElement(self.menu)

  self.uiRoot:addChild(contentStack)
end, Scene)

RendererFallbackSetup.name = "RendererFallbackSetup"

-- Saves OpenGL as the renderer so every launch avoids Vulkan, and leaves the prompt
function RendererFallbackSetup:keepFallbackRenderer()
  config.renderer = RendererSetting.OPENGL
  write_conf_file()
  GAME.navigationStack:pop()
end

-- Leaves the prompt with the setting unchanged, so the next launch lets LÖVE pick Vulkan again
function RendererFallbackSetup:tryDefaultRendererAgain()
  GAME.navigationStack:pop()
end

function RendererFallbackSetup:update(dt)
  GAME.theme.images.bg_main:update(dt)
  self.menu:receiveInputs(InputSource.anyPlayer, dt)
end

function RendererFallbackSetup:draw()
  GAME.theme.images.bg_main:draw()
  self.uiRoot:draw()
end

return RendererFallbackSetup
