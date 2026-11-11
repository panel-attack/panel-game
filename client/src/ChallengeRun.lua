local class = require("common.lib.class")

---@alias ChallengeRunResult ("win" | "loss" | "tie" | "abandoned" | "inProgress")

---@class ChallengeRunAttempt
---@field seed integer the seed the stage's panels were generated from
---@field result ChallengeRunResult
---@field frames integer? how long the attempt lasted, absent if it never ended
---@field replay string? path of the attempt's replay in the save directory

---@class ChallengeRunStage
---@field attempts ChallengeRunAttempt[]

-- The progress of one play through a Challenge Mode difficulty, from its first stage until it is beaten.
-- Its continues and time are counted from the attempts, which are all it keeps of each stage.
-- A run saved while a stage is in progress was left by quitting the game, so loading it counts that stage as abandoned.
---@class ChallengeRun
---@field difficulty integer
---@field stageIndex integer the stage being played or about to be played
---@field complete boolean true once the last stage was won
---@field stages ChallengeRunStage[]
---@overload fun(difficulty: integer, stageCount: integer): ChallengeRun
local ChallengeRun = class(
  function(self, difficulty, stageCount)
    self.difficulty = difficulty
    self.stageIndex = 1
    self.complete = false
    self.stages = {}
    for i = 1, stageCount do
      self.stages[i] = {attempts = {}}
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

  if result == ChallengeRun.results.WIN then
    if self.stageIndex < #self.stages then
      self.stageIndex = self.stageIndex + 1
    else
      self.complete = true
    end
  end
end

-- Returns how many attempts ended in a loss or were abandoned
---@return integer
function ChallengeRun:getContinues()
  local continues = 0
  for _, stage in ipairs(self.stages) do
    for _, attempt in ipairs(stage.attempts) do
      if attempt.result == ChallengeRun.results.LOSS or attempt.result == ChallengeRun.results.ABANDONED then
        continues = continues + 1
      end
    end
  end
  return continues
end

-- Returns the frames the finished attempts on the stage lasted
---@param stageIndex integer
---@return integer
function ChallengeRun:getStageTime(stageIndex)
  local frames = 0
  for _, attempt in ipairs(self.stages[stageIndex].attempts) do
    frames = frames + (attempt.frames or 0)
  end
  return frames
end

-- Returns the frames the finished attempts on all stages lasted
---@return integer
function ChallengeRun:getTime()
  local frames = 0
  for stageIndex = 1, #self.stages do
    frames = frames + self:getStageTime(stageIndex)
  end
  return frames
end

-- Returns the run as plain data for saving
---@return table
function ChallengeRun:toSaveData()
  return {
    difficulty = self.difficulty,
    stageIndex = self.stageIndex,
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
