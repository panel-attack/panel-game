local class = require("common.lib.class")

---@alias ChallengeRunResult ("win" | "loss" | "tie" | "abandoned" | "inProgress")

---@class ChallengeRunAttempt
---@field seed integer the seed the stage's panels were generated from
---@field result ChallengeRunResult
---@field frames integer? how long the attempt lasted, absent if it never ended
---@field replay string? path of the attempt's replay in the save directory

---@class ChallengeRunStage
---@field expendedTime integer frames spent on the stage over all attempts
---@field continues integer attempts on the stage that ended in a loss or were abandoned
---@field attempts ChallengeRunAttempt[]

-- The progress of one play through a Challenge Mode difficulty, from its first stage until it is beaten.
-- A run saved while a stage is in progress was left by quitting the game, so loading it counts that stage as abandoned.
---@class ChallengeRun
---@field difficulty integer
---@field stageIndex integer the stage being played or about to be played
---@field continues integer
---@field expendedTime integer frames spent on all stages
---@field complete boolean true once the last stage was won
---@field stages ChallengeRunStage[]
---@overload fun(difficulty: integer, stageCount: integer): ChallengeRun
local ChallengeRun = class(
  function(self, difficulty, stageCount)
    self.difficulty = difficulty
    self.stageIndex = 1
    self.continues = 0
    self.expendedTime = 0
    self.complete = false
    self.stages = {}
    for i = 1, stageCount do
      self.stages[i] = {expendedTime = 0, continues = 0, attempts = {}}
    end
  end
)

ChallengeRun.results = {WIN = "win", LOSS = "loss", TIE = "tie", ABANDONED = "abandoned", IN_PROGRESS = "inProgress"}

-- Records the start of an attempt on the current stage
---@param seed integer
function ChallengeRun:startStage(seed)
  local stage = self.stages[self.stageIndex]
  stage.attempts[#stage.attempts + 1] = {seed = seed, result = ChallengeRun.results.IN_PROGRESS}
end

-- Records how the current stage's latest attempt ended and moves on to the next stage after a win
---@param result ChallengeRunResult
---@param frames integer
---@param replayPath string?
function ChallengeRun:finishStage(result, frames, replayPath)
  local stage = self.stages[self.stageIndex]
  local attempt = stage.attempts[#stage.attempts]
  attempt.result = result
  attempt.frames = frames
  attempt.replay = replayPath
  stage.expendedTime = stage.expendedTime + frames
  self.expendedTime = self.expendedTime + frames

  if result == ChallengeRun.results.LOSS or result == ChallengeRun.results.ABANDONED then
    stage.continues = stage.continues + 1
    self.continues = self.continues + 1
  end

  if result == ChallengeRun.results.WIN then
    if self.stageIndex < #self.stages then
      self.stageIndex = self.stageIndex + 1
    else
      self.complete = true
    end
  end
end

-- Returns the run as plain data for saving
---@return table
function ChallengeRun:toSaveData()
  return {
    difficulty = self.difficulty,
    stageIndex = self.stageIndex,
    continues = self.continues,
    expendedTime = self.expendedTime,
    complete = self.complete,
    stages = self.stages,
  }
end

-- Recreates a run from the data toSaveData returned, abandoning the attempt that was in progress when it was saved
---@param data table
---@return ChallengeRun
function ChallengeRun.fromSaveData(data)
  local run = ChallengeRun(data.difficulty, 0)
  run.stageIndex = data.stageIndex
  run.continues = data.continues
  run.expendedTime = data.expendedTime
  run.complete = data.complete
  run.stages = data.stages
  local attempts = run.stages[run.stageIndex].attempts
  local lastAttempt = attempts[#attempts]
  if lastAttempt and lastAttempt.result == ChallengeRun.results.IN_PROGRESS then
    run:finishStage(ChallengeRun.results.ABANDONED, 0)
  end
  return run
end

return ChallengeRun
