local class = require("common.lib.class")
local UiElement = require("client.src.ui.UIElement")
local GraphicsUtil = require("client.src.graphics.graphics_util")

local ChallengeModeTimeSplitsUIElement = class(function(self, options, challengeMode)
  self.challengeMode = challengeMode
  self.stageTimeQuads = {}
end, UiElement)

function ChallengeModeTimeSplitsUIElement:drawSelf()
  self:drawTimeSplits()
end

function ChallengeModeTimeSplitsUIElement:drawTimeSplits()
  local totalTime = 0

  local yOffset = 36
  local row = 0
  for i = 1, self.challengeMode.stageIndex do
    if self.stageTimeQuads[i] == nil then
      self.stageTimeQuads[i] = {}
    end
    local time = self.challengeMode.stages[i].expendedTime
    local currentStageTime = time
    local isCurrentStage = i == self.challengeMode.stageIndex
    if isCurrentStage and self.challengeMode.match and not self.challengeMode.match.ended then
      currentStageTime = currentStageTime + (self.challengeMode.match.stacks[1].game_stopwatch or 0)
    end
    totalTime = totalTime + currentStageTime

    if isCurrentStage then
      GraphicsUtil.setColor(0.8, 0.8, 1, 1)
    end
    GraphicsUtil.draw_time(frames_to_time_string(currentStageTime, true), self.x, self.y + yOffset * row,
                           themes[config.theme].time_Scale)
    if isCurrentStage then
      GraphicsUtil.setColor(1, 1, 1, 1)
    end

    row = row + 1
  end

  GraphicsUtil.setColor(1, 1, 0.8, 1)
  GraphicsUtil.draw_time(frames_to_time_string(totalTime, true), self.x, self.y + yOffset * row,
                         themes[config.theme].time_Scale)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

return ChallengeModeTimeSplitsUIElement
