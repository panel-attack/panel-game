local GameBase = require("client.src.scenes.GameBase")
local class = require("common.lib.class")
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local ChallengeModeTimeSplitsUIElement = require("client.src.graphics.ChallengeModeTimeSplitsUIElement")
local ChallengeModeRecapScene = require("client.src.scenes.ChallengeModeRecapScene")

-- Scene for one battle in a challenge mode game
local Game1pChallenge = class(function(self, sceneParams)
  self.match:connectSignal("matchEnded", self, self.onMatchEnded)
  self.match:connectSignal("pauseChanged", self, self.pauseChanged)
  self.totalTimeQuads = {}
  self.stageIndex = GAME.battleRoom.stageIndex
  self.timeSplitElement = ChallengeModeTimeSplitsUIElement({x = consts.CANVAS_WIDTH / 2, y = 280}, GAME.battleRoom, GAME.battleRoom.stageIndex)
  self.uiRoot:addChild(self.timeSplitElement)

end, GameBase)

Game1pChallenge.name = "Game1pChallenge"

function Game1pChallenge:startNextScene()
  if GAME.battleRoom.challengeComplete then
    -- We passed the last level, go to the recap.
    GAME.navigationStack:replace(ChallengeModeRecapScene({challengeMode = GAME.battleRoom}))
  else
    -- Level is done, go back to ready screen.
    GAME.navigationStack:pop()
  end
end

function Game1pChallenge:pauseChanged(match)
  if match.isPaused then
    self.timeSplitElement.isVisible = false
  else
    self.timeSplitElement.isVisible = true
  end
end

function Game1pChallenge:drawHUD()
  if GAME.battleRoom then
    local drawX = consts.CANVAS_WIDTH / 2
    local drawY = 110
    local width = 200
    local height = consts.CANVAS_HEIGHT - drawY

    -- Background
    GraphicsUtil.drawRectangle("fill", drawX - width / 2, drawY, width, height, 0, 0, 0, 0.5)

    drawY = 110
    self:drawDifficultyName(drawX, drawY)

    drawY = drawY + 60
    self:drawStageInfo(drawX, drawY)

    drawY = drawY + 60
    self:drawContinueInfo(drawX, drawY)

    self.uiRoot:draw()

    if not self.match.isPaused then
      for i, stack in ipairs(self.match.stacks) do
        if stack.player and stack.player.human then
          if config.show_ingame_infos then
            stack:drawMultibar()
            stack:drawAnalyticData()
          end
        else
          stack:drawMultibar()
        end
      end
    end
  end
end

function Game1pChallenge:drawDifficultyName(drawX, drawY)
  local limit = 400
  GraphicsUtil.printf(loc("difficulty"), drawX - limit / 2, drawY, limit, "center", nil, nil, 10)
  GraphicsUtil.printf(GAME.battleRoom.difficultyName, drawX - limit / 2, drawY + 26, limit, "center", nil, nil, 10)
end

function Game1pChallenge:drawStageInfo(drawX, drawY)
  local limit = 400
  GraphicsUtil.printf("Stage", drawX - limit / 2, drawY, limit, "center", nil, nil, 10)
  GraphicsUtil.drawPixelFont(self.stageIndex, themes[config.theme].fontMaps.numbers[2], drawX, drawY + 26,
                           themes[config.theme].win_Scale, themes[config.theme].win_Scale, "center", 0)
end

function Game1pChallenge:drawContinueInfo(drawX, drawY)
  local limit = 400
  GraphicsUtil.printf("Continues", drawX - limit / 2, drawY, limit, "center", nil, nil, 4)
  GraphicsUtil.printf(GAME.battleRoom.continues, drawX - limit / 2, drawY + 20, limit, "center", nil, nil, 4)
end

return Game1pChallenge
