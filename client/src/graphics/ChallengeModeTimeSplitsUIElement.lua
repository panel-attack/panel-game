local class = require("common.lib.class")
local UiElement = require("client.src.ui.UIElement")
local GraphicsUtil = require("client.src.graphics.graphics_util")

local ChallengeModeTimeSplitsUIElement = class(function(self, options, challengeMode, currentStateIndex)
  self.challengeMode = challengeMode
  self.stageTimeQuads = {}
  self.currentStageIndex = currentStateIndex
end, UiElement)

function ChallengeModeTimeSplitsUIElement:drawSelf()
  self:drawTimeSplits()
end

function ChallengeModeTimeSplitsUIElement:drawTimeSplits()
  local totalTime = 0

  local yOffset = 32
  local row = 0
  for i = 1, self.challengeMode.stageIndex do
    if self.stageTimeQuads[i] == nil then
      self.stageTimeQuads[i] = {}
    end
    local time = self.challengeMode.stages[i].expendedTime
    local currentStageTime = time
    local isCurrentStage = (self.currentStageIndex and i == self.currentStageIndex)
    if isCurrentStage and self.challengeMode.match and not self.challengeMode.match.ended then
      currentStageTime = currentStageTime + (self.challengeMode.match.stacks[1].engine.game_stopwatch or 0)
    end
    totalTime = totalTime + currentStageTime

    if isCurrentStage then
      GraphicsUtil.setColor(0.8, 0.8, 1, 1)
    end
    GraphicsUtil.draw_time(frames_to_time_string(currentStageTime, true), self.x, self.y + yOffset * row,
                           themes[config.theme].time_Scale)

    row = row + 1

    if isCurrentStage then
      GraphicsUtil.setColor(1, 1, 1, 1)
      break
    end
  end

  GraphicsUtil.setColor(1, 1, 0.8, 1)
  GraphicsUtil.draw_time(frames_to_time_string(totalTime, true), self.x, self.y + yOffset * row,
                         themes[config.theme].time_Scale)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

return ChallengeModeTimeSplitsUIElement
