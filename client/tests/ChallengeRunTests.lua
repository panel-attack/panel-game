local ChallengeRun = require("client.src.ChallengeRun")

local function startingAStageRecordsTheAttemptInProgress()
  local run = ChallengeRun(2, 3)

  run:startStage(123)

  assert(run.continues == 0 and run.stages[1].continues == 0, "the stage has not been lost yet")
  local attempt = run.stages[1].attempts[1]
  assert(attempt.seed == 123, "the attempt keeps its seed")
  assert(attempt.result == ChallengeRun.results.IN_PROGRESS)
end

-- a run saved with a stage in progress was left by quitting the game, which cannot avoid the continue
local function anAttemptInProgressIsAbandonedWhenTheRunIsLoaded()
  local run = ChallengeRun(2, 3)
  run:startStage(123)

  local loaded = ChallengeRun.fromSaveData(run:toSaveData())

  assert(loaded.continues == 1 and loaded.stages[1].continues == 1)
  assert(loaded.stages[1].attempts[1].result == ChallengeRun.results.ABANDONED)
  assert(loaded.stageIndex == 1)
end

local function abandoningAStageCostsAContinue()
  local run = ChallengeRun(2, 3)
  run:startStage(123)

  run:finishStage(ChallengeRun.results.ABANDONED, 300)

  assert(run.continues == 1 and run.stages[1].continues == 1)
  assert(run.stageIndex == 1)
end

local function winningAStageCostsNoContinue()
  local run = ChallengeRun(2, 3)
  run:startStage(123)

  run:finishStage(ChallengeRun.results.WIN, 600)

  assert(run.continues == 0 and run.stages[1].continues == 0)
  assert(run.stages[1].attempts[1].result == ChallengeRun.results.WIN)
end

local function winningAStageMovesToTheNextStage()
  local run = ChallengeRun(2, 3)
  run:startStage(123)

  run:finishStage(ChallengeRun.results.WIN, 600)

  assert(run.stageIndex == 2)
  assert(not run.complete)
end

local function aTieCostsNoContinueAndStaysOnTheStage()
  local run = ChallengeRun(2, 3)
  run:startStage(123)

  run:finishStage(ChallengeRun.results.TIE, 600)

  assert(run.continues == 0 and run.stages[1].continues == 0)
  assert(run.stageIndex == 1)
end

local function aLossKeepsTheContinueAndStaysOnTheStage()
  local run = ChallengeRun(2, 3)
  run:startStage(123)

  run:finishStage(ChallengeRun.results.LOSS, 600)

  assert(run.continues == 1 and run.stages[1].continues == 1)
  assert(run.stageIndex == 1)
  assert(run.stages[1].attempts[1].result == ChallengeRun.results.LOSS)
end

local function finishingAStageAddsItsTime()
  local run = ChallengeRun(2, 3)
  run:startStage(1)
  run:finishStage(ChallengeRun.results.LOSS, 600)
  run:startStage(2)

  run:finishStage(ChallengeRun.results.WIN, 400, "replays/stage1.json")

  assert(run.stages[1].expendedTime == 1000, "both attempts count towards the stage's time")
  assert(run.expendedTime == 1000)
  local attempts = run.stages[1].attempts
  assert(attempts[1].frames == 600 and attempts[2].frames == 400, "each attempt keeps its own time")
  assert(attempts[2].replay == "replays/stage1.json", "the attempt links its replay")
end

local function winningTheLastStageCompletesTheRun()
  local run = ChallengeRun(2, 1)
  run:startStage(123)

  run:finishStage(ChallengeRun.results.WIN, 600)

  assert(run.complete)
  assert(run.stageIndex == 1, "the run stays on its last stage")
end

local function aRunComesBackFromItsSaveData()
  local run = ChallengeRun(4, 3)
  run:startStage(11)
  run:finishStage(ChallengeRun.results.LOSS, 600)
  run:startStage(12)
  run:finishStage(ChallengeRun.results.WIN, 300)
  run:startStage(13)
  run:finishStage(ChallengeRun.results.LOSS, 100)

  local loaded = ChallengeRun.fromSaveData(run:toSaveData())

  assert(loaded.difficulty == 4 and loaded.stageIndex == 2 and loaded.continues == 2 and loaded.expendedTime == 1000)
  assert(#loaded.stages == 3)
  assert(loaded.stages[1].continues == 1 and loaded.stages[1].expendedTime == 900)
  assert(loaded.stages[2].attempts[1].seed == 13)
end

startingAStageRecordsTheAttemptInProgress()
anAttemptInProgressIsAbandonedWhenTheRunIsLoaded()
abandoningAStageCostsAContinue()
winningAStageCostsNoContinue()
winningAStageMovesToTheNextStage()
aTieCostsNoContinueAndStaysOnTheStage()
aLossKeepsTheContinueAndStaysOnTheStage()
finishingAStageAddsItsTime()
winningTheLastStageCompletesTheRun()
aRunComesBackFromItsSaveData()
