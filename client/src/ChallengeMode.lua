local logger = require("common.lib.logger")
local class = require("common.lib.class")
local ChallengeModePlayer = require("client.src.ChallengeModePlayer")
local ChallengeRun = require("client.src.ChallengeRun")
local GameModes = require("common.data.GameModes")
local levelPresets = require("common.data.LevelPresets")
local Game1pChallenge = require("client.src.scenes.Game1pChallenge")
require("client.src.BattleRoom")
local save = require("client.src.save")
local fileUtils = require("client.src.FileUtils")


-- Challenge Mode is a particular play through of the challenge mode in the game, it contains all the settings for the mode.
---@class ChallengeMode : BattleRoom
---@field stages table
---@field difficulty integer
---@field difficultyName string
---@field run ChallengeRun the progress through the stages, saved whenever a stage starts or ends
---@field save ChallengeModeSave
---@field player ChallengeModePlayer
local ChallengeMode = class(
  function(self, mode, gameScene, difficulty, save, run)
    self.stages = self:createStages(difficulty)
    self.difficulty = difficulty
    self.difficultyName = loc("challenge_difficulty_" .. difficulty)
    self.run = run or ChallengeRun(difficulty, #self.stages)
    self.save = save
    self.sceneParameters = {leaveWarning = "challenge_leave_warning"}

    self:addPlayer(GAME.localPlayer)
    GAME.localPlayer:setStyle(GameModes.Styles.MODERN)

    self.player = ChallengeModePlayer(#self.players + 1)
    self.player.settings.difficulty = difficulty
    self:addPlayer(self.player)
    self:restoreInputConfigurations()
    self:setStage(self.run.stageIndex)
  end,
  BattleRoom
)

-- Creates a challenge of the difficulty that continues run, or starts a new run if there is none
---@param difficulty integer
---@param save ChallengeModeSave
---@param run ChallengeRun?
---@return ChallengeMode
function ChallengeMode.create(difficulty, save, run)
  return ChallengeMode(GameModes.getPreset(GameModes.IDs.ONE_PLAYER_CHALLENGE), Game1pChallenge, difficulty, save, run)
end

ChallengeMode.numDifficulties = 8

function ChallengeMode:createStages(difficulty)
  local stages = {}

  local stageCount
  local framesToppedOutToLoseBase
  local framesToppedOutToLoseIncrement
  local lineClearGPMBase
  local lineClearGPMIncrement
  local lineHeightToKill
  local panelLevel

  if difficulty == 1 then
    stageCount = 10
    framesToppedOutToLoseBase = 60
    framesToppedOutToLoseIncrement = 3
    lineClearGPMBase = 3.3
    lineClearGPMIncrement = 0.45
    panelLevel = 2
    lineHeightToKill = 6
  elseif difficulty == 2 then
    stageCount = 11
    framesToppedOutToLoseBase = 66
    framesToppedOutToLoseIncrement = 6
    lineClearGPMBase = 5
    lineClearGPMIncrement = 0.7
    panelLevel = 4
    lineHeightToKill = 6
  elseif difficulty == 3 then
    stageCount = 12
    framesToppedOutToLoseBase = 72
    framesToppedOutToLoseIncrement = 12
    lineClearGPMBase = 15.5
    lineClearGPMIncrement = 0.7
    panelLevel = 6
    lineHeightToKill = 6
  elseif difficulty == 4 then
    stageCount = 12
    framesToppedOutToLoseBase = 72
    framesToppedOutToLoseIncrement = 30
    lineClearGPMBase = 15.5
    lineClearGPMIncrement = 1.5
    panelLevel = 6
    lineHeightToKill = 6
  elseif difficulty == 5 then
    stageCount = 12
    framesToppedOutToLoseBase = 72
    framesToppedOutToLoseIncrement = 240
    lineClearGPMBase = 30
    lineClearGPMIncrement = 1.5
    panelLevel = 8
    lineHeightToKill = 6
  elseif difficulty == 6 then
    stageCount = 12
    framesToppedOutToLoseBase = 72
    framesToppedOutToLoseIncrement = 240
    lineClearGPMBase = 35
    lineClearGPMIncrement = 1.5
    panelLevel = 10
    lineHeightToKill = 6
  elseif difficulty == 7 then
    stageCount = 12
    framesToppedOutToLoseBase = 360
    framesToppedOutToLoseIncrement = 240
    lineClearGPMBase = 37
    lineClearGPMIncrement = 1.5
    panelLevel = 10
    lineHeightToKill = 6
  elseif difficulty == 8 then
    stageCount = 12
    framesToppedOutToLoseBase = 720
    framesToppedOutToLoseIncrement = 240
    lineClearGPMBase = 39
    lineClearGPMIncrement = 1.5
    panelLevel = 10
    lineHeightToKill = 6
  else
    error("Invalid challenge mode difficulty level of " .. difficulty)
  end

  for stageIndex = 1, stageCount, 1 do
    local incrementMultiplier = stageIndex - 1
    local stage = {}
    stage.attackSettings = self:getAttackSettings(difficulty, stageIndex)
    stage.healthSettings = {
      framesToppedOutToLose = framesToppedOutToLoseBase + framesToppedOutToLoseIncrement * incrementMultiplier,
      lineClearGPM = lineClearGPMBase + lineClearGPMIncrement * incrementMultiplier,
      lineHeightToKill = lineHeightToKill,
      riseSpeed = levelPresets.getModern(panelLevel).startingSpeed
    }
    stage.playerLevel = panelLevel
    stage.index = stageIndex

    stages[stageIndex] = stage
  end

  return stages
end

function ChallengeMode:attackFilePath(difficulty, stageIndex)
  for i = stageIndex, 1, -1 do
    local path = "client/assets/default_data/training/challenge-" .. difficulty .. "-" .. i .. ".json"
    if fileUtils.exists(path) then
      return path
    end
  end

  return nil
end

function ChallengeMode:getAttackSettings(difficulty, stageIndex)
  local attackFile = save.readAttackFile(self:attackFilePath(difficulty, stageIndex))
  assert(attackFile ~= nil, "could not find attack file for challenge mode")
  return attackFile
end

---@param replay ReplayV3?
---@return ClientMatch match
function ChallengeMode:startMatch(replay)
  local match = BattleRoom.startMatch(self, replay)
  self:recordStageStart(match)
  return match
end

-- Saves the stage as lost before it can be played, so that quitting the game during it cannot avoid the continue
---@param match ClientMatch
function ChallengeMode:recordStageStart(match)
  self.run:startStage(match.panelSource.seed)
  self.save:saveRun(self.run)
end

-- Returns how the stage's match ended for the player taking the challenge
---@param match ClientMatch
---@return ChallengeRunResult
function ChallengeMode:stageResult(match)
  local winners = match:getWinners()
  if #winners == 1 then
    if winners[1] == self.player then
      return ChallengeRun.results.LOSS
    else
      return ChallengeRun.results.WIN
    end
  elseif #winners == 2 then
    return ChallengeRun.results.TIE
  else
    -- only the player can end the game before its conclusion
    return ChallengeRun.results.ABANDONED
  end
end

-- Records how the stage's match ended in the run, saves the run and sets up the stage the run is on next
---@param match ClientMatch
function ChallengeMode:recordStageResult(match)
  local winners = match:getWinners()
  if #winners == 1 then
    winners[1]:incrementWinCount()
  end

  local gameTime = 0
  local stackEngine = match.stacks[1].engine
  if stackEngine ~= nil and stackEngine.stopWatch then
    gameTime = stackEngine.stopWatch
  end

  local replayPath = match.replay and fileUtils.getReplayPath(match.replay)
  self.run:finishStage(self:stageResult(match), gameTime, replayPath)
  self.save:saveRun(self.run)
  if not self.run.complete then
    self:setStage(self.run.stageIndex)
  end
end

function ChallengeMode:onMatchEnded(match)
  self.matchesPlayed = self.matchesPlayed + 1

  -- an abort is always the responsibility of the local player in challenge mode
  -- so always record the result, even if it may have been an abort
  self:recordStageResult(match)

  if self.online and match:hasLocalPlayer() then
    GAME.netClient:reportLocalGameResult(match:getWinners())
  end

  -- nilling the match here doesn't keep the game scene from rendering it as it has its own reference
  self.match = nil
  self.state = BattleRoom.states.Setup
end

function ChallengeMode:setStage(index)
  logger.debug("Setting stage to index " .. index)
  GAME.localPlayer:setLevel(self.stages[index].playerLevel)
  GAME.localPlayer:setLevelData(levelPresets.getModern(GAME.localPlayer.settings.level))

  local stageSettings = self.stages[index]
  self.player:setAttackEngineSettings(stageSettings.attackSettings)
  self.player.settings.healthSettings = stageSettings.healthSettings
  self.player.settings.level = index
  if stageSettings.characterId then
    self.player:setCharacter(stageSettings.characterId)
  else
    self.player:setCharacterForStage(index)
  end
  self.player:setStage("")
end

return ChallengeMode