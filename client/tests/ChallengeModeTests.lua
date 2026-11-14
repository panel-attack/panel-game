local ChallengeMode = require("client.src.ChallengeMode")
local ChallengeModeSave = require("client.src.ChallengeModeSave")
local ChallengeRun = require("client.src.ChallengeRun")

local SAVE_NAME = "challengeModeTests"
local DIFFICULTY = 1
local STAGE_COUNT = 10

local function removeSaveFiles()
  love.filesystem.remove(ChallengeModeSave.path(SAVE_NAME))
end

-- runs the test against a challenge of the easiest difficulty saving to files nobody else uses,
-- shutting the challenge down and removing the files afterwards even if the test fails
---@param run ChallengeRun?
---@param test fun(challengeMode: ChallengeMode, save: ChallengeModeSave)
local function withChallenge(run, test)
  removeSaveFiles()
  local save = ChallengeModeSave.load(SAVE_NAME)
  local challengeMode = ChallengeMode.create(DIFFICULTY, save, run)
  local ok, err = pcall(test, challengeMode, save)
  challengeMode:shutdown()
  removeSaveFiles()
  assert(ok, err)
end

-- the parts of a match that a challenge reads when the match starts and ends
local function fakeMatch(winners, frames, seed)
  return {
    getWinners = function() return winners end,
    stacks = {{engine = {stopWatch = frames}}},
    engine = {aborted = #winners == 0},
    panelSource = {seed = seed},
  }
end

local function savedRun()
  return ChallengeModeSave.load(SAVE_NAME):getRun(DIFFICULTY)
end

-- a run that has won its stages up to the given one
local function runOnStage(stageIndex)
  local run = ChallengeRun(DIFFICULTY, STAGE_COUNT)
  for i = 1, stageIndex - 1 do
    run:startStage(i)
    run:finishStage(ChallengeRun.results.WIN, 60)
  end
  return run
end

local function aStartedStageIsOnDiskAsALoss()
  withChallenge(nil, function(challengeMode)
    challengeMode:recordStageStart(fakeMatch({}, 0, 77))

    assert(challengeMode.run:getContinues() == 0, "the stage is not lost while it is played")
    local run = savedRun()
    assert(run ~= nil, "the run was saved when the stage started")
    assert(run:getContinues() == 1, "quitting the game now would count as a loss")
    assert(run.stages[1].attempts[1].seed == 77)
  end)
end

local function aWonStageIsSavedOnTheNextStage()
  withChallenge(nil, function(challengeMode)
    local match = fakeMatch({GAME.localPlayer}, 600, 77)
    challengeMode:recordStageStart(match)

    challengeMode:onMatchEnded(match)

    local run = savedRun()
    assert(run.stageIndex == 2 and run:getContinues() == 0)
    assert(run.stages[1].attempts[1].frames == 600)
    assert(challengeMode.player.settings.level == 2, "the challenge moved on to the next opponent too")
  end)
end

local function aLostStageKeepsItsContinue()
  withChallenge(nil, function(challengeMode)
    local match = fakeMatch({challengeMode.player}, 600, 77)
    challengeMode:recordStageStart(match)

    challengeMode:onMatchEnded(match)

    local run = savedRun()
    assert(run.stageIndex == 1 and run:getContinues() == 1)
    assert(run.stages[1].attempts[1].result == ChallengeRun.results.LOSS)
  end)
end

local function leavingAStageKeepsItsContinue()
  withChallenge(nil, function(challengeMode)
    local match = fakeMatch({}, 300, 77)
    challengeMode:recordStageStart(match)

    challengeMode:onMatchEnded(match)

    local run = savedRun()
    assert(run.stageIndex == 1 and run:getContinues() == 1)
    assert(run.stages[1].attempts[1].result == ChallengeRun.results.ABANDONED)
    assert(run.stages[1].attempts[1].frames == 300)
  end)
end

local function aContinuedRunStartsOnItsSavedStage()
  withChallenge(runOnStage(3), function(challengeMode)
    assert(challengeMode.run.stageIndex == 3)
    assert(challengeMode.player.settings.level == 3, "the opponent is the one of the saved stage")
  end)
end

local function beatingTheLastStageRecordsTheRun()
  withChallenge(runOnStage(STAGE_COUNT), function(challengeMode)
    local match = fakeMatch({GAME.localPlayer}, 600, 77)
    challengeMode:recordStageStart(match)

    challengeMode:onMatchEnded(match)

    assert(challengeMode.run.complete)
    local save = ChallengeModeSave.load(SAVE_NAME)
    assert(save:getRun(DIFFICULTY) == nil, "the run is no longer unfinished")
    assert(save:getBestContinues(DIFFICULTY) == 0)
  end)
end

-- whichever game scene the platform uses, leaving it during a stage warns that it counts as a loss
local function itsGamesWarnBeforeLeaving()
  withChallenge(nil, function(challengeMode)
    assert(challengeMode.sceneParameters.leaveWarning == "challenge_leave_warning")
  end)
end

aStartedStageIsOnDiskAsALoss()
aWonStageIsSavedOnTheNextStage()
aLostStageKeepsItsContinue()
leavingAStageKeepsItsContinue()
aContinuedRunStartsOnItsSavedStage()
beatingTheLastStageRecordsTheRun()
itsGamesWarnBeforeLeaving()
