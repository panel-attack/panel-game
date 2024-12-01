local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local Scene = require("client.src.scenes.Scene")
local Label = require("client.src.ui.Label")
local class = require("common.lib.class")
local logger = require("common.lib.logger")
local input = require("common.lib.inputManager")
local tableUtils = require("common.lib.tableUtils")
local util = require("common.lib.util")
local ChallengeModeTimeSplitsUIElement = require("client.src.graphics.ChallengeModeTimeSplitsUIElement")

-- @module ChallengeModeRecapScene
-- Gives a summary of the recently completed challenge mode game
local ChallengeModeRecapScene = class(function(self, sceneParams)
  self.backgroundImg = themes[config.theme].images.bg_main
  self.challengeMode = sceneParams.challengeMode
  self.timeSplitElement = ChallengeModeTimeSplitsUIElement({x = consts.CANVAS_WIDTH / 2, y = 200}, GAME.battleRoom)
  self.uiRoot:addChild(self.timeSplitElement)
  self.recapStartTime = love.timer.getTime()
  self.minDisplayTime = 2 -- the minimum amount of seconds the scene will be displayed for
  self.maxDisplayTime = -1
end, Scene)

ChallengeModeRecapScene.name = "ChallengeModeRecapScene"

------------------------------
-- scene core functionality --
------------------------------

function ChallengeModeRecapScene:update(dt)
  self.backgroundImg:update(dt)
  local displayTime = love.timer.getTime() - self.recapStartTime

  -- if conditions are met, leave the scene
  local keyPressed = (tableUtils.length(input.isDown) > 0) or (tableUtils.length(input.mouse.isDown) > 0)

  if ((displayTime >= self.maxDisplayTime and self.maxDisplayTime ~= -1) or (displayTime >= self.minDisplayTime and keyPressed)) then
    GAME.theme:playValidationSfx()
    GAME.navigationStack:popToTop()
  end
end

function ChallengeModeRecapScene:draw()
  self.backgroundImg:draw()

  local drawX = consts.CANVAS_WIDTH / 2
  local drawY = 20

  local limit = consts.CANVAS_WIDTH
  local message = "Congratulations!\n You beat " .. self.challengeMode.difficultyName .. "!"
  GraphicsUtil.printf(message, 0, drawY, limit, "center", nil, nil, 30)
  self.uiRoot:draw()

  local limit = 400
  drawY = drawY + 120
  GraphicsUtil.printf("Continues", drawX - limit / 2, drawY, limit, "center", nil, nil, 4)
  drawY = drawY + 20
  GraphicsUtil.printf(GAME.battleRoom.continues, drawX - limit / 2, drawY, limit, "center", nil, nil, 4)

  local font = GraphicsUtil.getGlobalFont()
  GraphicsUtil.print(loc("continue_button"), (consts.CANVAS_WIDTH - font:getWidth(loc("continue_button"))) / 2, consts.CANVAS_HEIGHT - 60)
end

return ChallengeModeRecapScene
