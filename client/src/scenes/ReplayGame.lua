local GameBase = require("client.src.scenes.GameBase")
local input = require("client.src.inputManager)
local consts = require("common.engine.consts")
local util = require("common.lib.util")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local prof = require("common.lib.jprof.jprof")

local ReplayGame = class(
  function (self, sceneParams)
    self.frameAdvance = false
    self.playbackSpeeds = {-1, 0, 0.5, 1, 2, 3, 4, 8, 16}
    self.playbackSpeedIndex = 4
    self.saveReplay = false
  end,
  GameBase
)

ReplayGame.name = "ReplayGame"

function ReplayGame:togglePause()
  self.match:togglePause()
  if self.musicSource then
    if self.match.isPaused then
      SoundController:pauseMusic()
    else
      SoundController:playMusic(self.musicSource.stageTrack)
    end
  end
end

function ReplayGame:update(dt)
  if self.match.ended then
    self:runGameOver()
  else
    self:runGame()
  end
end

local tick = 0
function ReplayGame:runGame()
  tick = tick + 1
  local playbackSpeed = self.playbackSpeeds[self.playbackSpeedIndex]

  if self.match.ended and playbackSpeed < 0 then
    -- we can rewind from death this way
    self.match.ended = false
  end

  if not self.match.isPaused then
    if playbackSpeed >= 1 then
      for i = 1, playbackSpeed do
        self.match:run()
      end
    elseif playbackSpeed < 0 then
      self.match:rewindToFrame(self.match.clock + playbackSpeed)
    elseif playbackSpeed < 1 then
      local inverse = math.round(1 / playbackSpeed, 0)
      if tick % inverse == 0 then
        self.match:run()
      end
    end
  else
    if self.frameAdvance then
      self.match:togglePause()
      if playbackSpeed > 0 then
        self.match:run()
      elseif playbackSpeed < 0 then
        self.match:rewindToFrame(self.match.clock - 1)
      end
      self.frameAdvance = false
      self.match.isPaused = true
    end
  end

  -- Advance one frame
  if input:isPressedWithRepeat("Swap1", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    self.frameAdvance = true
  elseif input.isDown["Swap1"] then
    if self.match.isPaused then
      self.frameAdvance = true
    else
      self.match:togglePause()
      if self.match.isPaused then
        SoundController:pauseMusic()
      else
        SoundController:playMusic(self.musicSource.stageTrack)
      end
    end
  elseif input:isPressedWithRepeat("MenuRight") then
    self.playbackSpeedIndex = util.bound(1, self.playbackSpeedIndex + 1, #self.playbackSpeeds)
    playbackSpeed = self.playbackSpeeds[self.playbackSpeedIndex]
  elseif input:isPressedWithRepeat("MenuLeft") then
    self.playbackSpeedIndex = util.bound(1, self.playbackSpeedIndex - 1, #self.playbackSpeeds)
    playbackSpeed = self.playbackSpeeds[self.playbackSpeedIndex]
  elseif input.isDown["Swap2"] or input.allKeys.isDown["escape"] then
    if self.match.isPaused then
      self.match:abort()
      GAME.navigationStack:pop()
    else
      self:togglePause()
    end
  elseif input.isDown["Start"] then
    self:togglePause()
  end
end

-- maybe we can rewind from death this way
ReplayGame.runGameOver = ReplayGame.runGame

function ReplayGame:customDraw()
  local textPos = themes[config.theme].gameover_text_Pos
  local playbackText = self.playbackSpeeds[self.playbackSpeedIndex] .. "x"
  GraphicsUtil.printf(playbackText, textPos[0], textPos[1], consts.CANVAS_WIDTH, "center", nil, 1, 10)
end

function ReplayGame:drawHUD()
  for i, stack in ipairs(self.match.stacks) do
    if config.show_ingame_infos then
      stack:drawScore()
      stack:drawSpeed()
      prof.push("Stack:drawMultibar")
      stack:drawMultibar()
      prof.pop("Stack:drawMultibar")
    end

    -- Draw VS HUD
    if stack.player then
      stack:drawPlayerName()
      stack:drawWinCount()
      stack:drawRating()
    end

    stack:drawLevel()
    if stack.analytic then
      prof.push("Stack:drawAnalyticData")
      stack:drawAnalyticData()
      prof.pop("Stack:drawAnalyticData")
    end
  end
end

return ReplayGame