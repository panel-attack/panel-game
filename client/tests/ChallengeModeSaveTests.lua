local ChallengeModeSave = require("client.src.ChallengeModeSave")
local ChallengeRun = require("client.src.ChallengeRun")

local SAVE_NAME = "challengeModeSaveTests"

local function removeSaveFiles()
  love.filesystem.remove(ChallengeModeSave.path(SAVE_NAME))
end

-- runs the test against save files nobody else uses, removing them afterwards even if the test fails
local function withEmptySave(test)
  removeSaveFiles()
  local ok, err = pcall(test)
  removeSaveFiles()
  assert(ok, err)
end

local function runOnStageTwo(difficulty)
  local run = ChallengeRun(difficulty, 3)
  run:startStage(5)
  run:finishStage(ChallengeRun.results.WIN, 600)
  return run
end

local function completedRun(difficulty, losses)
  local run = ChallengeRun(difficulty, 1)
  for i = 1, losses do
    run:startStage(i)
    run:finishStage(ChallengeRun.results.LOSS, 100)
  end
  run:startStage(losses + 1)
  run:finishStage(ChallengeRun.results.WIN, 100)
  return run
end

local function withoutASaveThereIsNoRun()
  withEmptySave(function()
    local save = ChallengeModeSave.load(SAVE_NAME)

    assert(save:getRun(1) == nil)
    assert(save:getBestContinues(1) == nil)
    assert(save:getBestTime(1) == nil)
    assert(save:getLastDifficulty() == nil)
  end)
end

local function aSavedRunLoadsBack()
  withEmptySave(function()
    ChallengeModeSave.load(SAVE_NAME):saveRun(runOnStageTwo(3))

    local run = ChallengeModeSave.load(SAVE_NAME):getRun(3)

    assert(run ~= nil, "the run was saved")
    assert(run.difficulty == 3 and run.stageIndex == 2 and run.expendedTime == 600)
  end)
end

local function eachDifficultyKeepsItsOwnRun()
  withEmptySave(function()
    local save = ChallengeModeSave.load(SAVE_NAME)
    save:saveRun(runOnStageTwo(3))
    save:saveRun(ChallengeRun(5, 3))

    local loaded = ChallengeModeSave.load(SAVE_NAME)

    assert(loaded:getRun(3).stageIndex == 2)
    assert(loaded:getRun(5).stageIndex == 1)
    assert(loaded:getRun(4) == nil)
  end)
end

local function aDiscardedRunIsGone()
  withEmptySave(function()
    local save = ChallengeModeSave.load(SAVE_NAME)
    save:saveRun(runOnStageTwo(3))

    save:discardRun(3)

    assert(ChallengeModeSave.load(SAVE_NAME):getRun(3) == nil)
  end)
end

local function aCompletedRunBecomesARecord()
  withEmptySave(function()
    ChallengeModeSave.load(SAVE_NAME):saveRun(completedRun(2, 3))

    local save = ChallengeModeSave.load(SAVE_NAME)

    assert(save:getRun(2) == nil, "a completed run is no longer unfinished")
    assert(save:getBestContinues(2) == 3)
    local records = save:getCompletedRuns(2)
    assert(#records == 1 and records[1].stages[1].attempts[4].result == ChallengeRun.results.WIN)
  end)
end

local function theBestContinuesIsTheFewestOfAnyCompletedRun()
  withEmptySave(function()
    local save = ChallengeModeSave.load(SAVE_NAME)
    save:saveRun(completedRun(2, 3))
    save:saveRun(completedRun(2, 1))
    save:saveRun(completedRun(2, 2))

    local loaded = ChallengeModeSave.load(SAVE_NAME)

    assert(loaded:getBestContinues(2) == 1)
    assert(#loaded:getCompletedRuns(2) == 3)
  end)
end

local function aCompletedRunsTimeIsTheBestTime()
  withEmptySave(function()
    ChallengeModeSave.load(SAVE_NAME):saveRun(completedRun(2, 3))

    assert(ChallengeModeSave.load(SAVE_NAME):getBestTime(2) == 400)
  end)
end

local function theBestTimeIsTheFastestOfAnyCompletedRun()
  withEmptySave(function()
    local save = ChallengeModeSave.load(SAVE_NAME)
    save:saveRun(completedRun(2, 3))
    save:saveRun(completedRun(2, 1))
    save:saveRun(completedRun(2, 2))

    assert(ChallengeModeSave.load(SAVE_NAME):getBestTime(2) == 200)
  end)
end

local function anUnfinishedRunSetsNoBestTime()
  withEmptySave(function()
    ChallengeModeSave.load(SAVE_NAME):saveRun(runOnStageTwo(3))

    assert(ChallengeModeSave.load(SAVE_NAME):getBestTime(3) == nil)
  end)
end

local function theLastPlayedDifficultyLoadsBack()
  withEmptySave(function()
    local save = ChallengeModeSave.load(SAVE_NAME)
    save:saveRun(runOnStageTwo(3))
    save:saveRun(ChallengeRun(5, 3))

    assert(ChallengeModeSave.load(SAVE_NAME):getLastDifficulty() == 5)
  end)
end

local function theSaveFileIsNotPlainText()
  withEmptySave(function()
    ChallengeModeSave.load(SAVE_NAME):saveRun(runOnStageTwo(3))

    local contents = love.filesystem.read(ChallengeModeSave.path(SAVE_NAME))

    assert(contents, "the save was written")
    assert(not contents:find("difficulty", 1, true), "the save is compressed rather than readable JSON")
  end)
end

withoutASaveThereIsNoRun()
aSavedRunLoadsBack()
eachDifficultyKeepsItsOwnRun()
aDiscardedRunIsGone()
aCompletedRunBecomesARecord()
theBestContinuesIsTheFewestOfAnyCompletedRun()
aCompletedRunsTimeIsTheBestTime()
theBestTimeIsTheFastestOfAnyCompletedRun()
anUnfinishedRunSetsNoBestTime()
theLastPlayedDifficultyLoadsBack()
theSaveFileIsNotPlainText()
