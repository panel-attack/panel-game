local class = require("common.lib.class")
local Scene = require("client.src.scenes.Scene")
local ui = require("client.src.ui")
local ModLoader = require("client.src.mods.ModLoader")
local inputs = require("client.src.inputManager")

local SCROLL_STEP = 14

local ModValidationScene = class(
function(self, sceneParams)
  self.scrollContainer = ui.ScrollContainer({hFill = true, vFill = true, scrollOrientation = "vertical"})
  local text = "\n"
  for mod, reason in pairs(ModLoader.invalidMods) do
    text = text .. "Failed to validate mod " .. mod.id .. " at path " .. mod.path .. " for the following reason:\n" .. reason .. "\n"
  end

  text = text .. "\n\nThe mentioned mods have been disabled\nPress Escape to continue"

  local modWarningLabel = ui.Label({text = text, translate = false, x = 10})
  self.scrollContainer:addChild(modWarningLabel)
  self.uiRoot:addChild(self.scrollContainer)

  self.offset = 0
end,
Scene)

ModValidationScene.name = "ModValidationScene"

function ModValidationScene:update(dt)
  if inputs:isPressedWithRepeat("MenuUp", .25, 0.03) then
    GAME.theme:playMoveSfx()
    self.offset = self.offset + SCROLL_STEP
  end
  if inputs:isPressedWithRepeat("MenuDown", .25, 0.03) then
    GAME.theme:playMoveSfx()
    self.offset = self.offset - SCROLL_STEP
  end
  if inputs.isDown.MenuLeft then
    GAME.theme:playMoveSfx()
    self.offset = self.offset + self.scrollContainer.height - SCROLL_STEP
  end
  if inputs.isDown.MenuRight then
    GAME.theme:playMoveSfx()
    self.offset = self.offset - self.scrollContainer.height + SCROLL_STEP
  end
  if inputs.isDown["MenuEsc"] then
    GAME.theme:playValidationSfx()
    GAME.navigationStack:pop()
  end

  self.scrollContainer:setScrollOffset(self.offset)
  self.offset = self.scrollContainer.scrollOffset
end

function ModValidationScene:draw()
  self.uiRoot:draw()
end

return ModValidationScene