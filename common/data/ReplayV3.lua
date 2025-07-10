local class = require("common.lib.class")
local LevelData = require("common.data.LevelData")
local StackBehaviours = require("common.data.StackBehaviours")
local logger = require("common.lib.logger")
local MatchRules = require("common.data.MatchRules")
local GameModes = require("common.data.GameModes")
local consts = require("common.engine.consts")
require("common.lib.timezones")
local tableUtils = require("common.lib.tableUtils")
local InputCompression = require("common.data.InputCompression")
local ReplayV2 = require("common.compatibility.ReplayV2")

local REPLAY_VERSION = 3

---@class ReplayPanelSource
---@field sourceType ReplayPanelSourceType
---@field [string] any

---@class ReplayBaseStack
---@field stackType StackType

---@class ReplayStack : ReplayBaseStack
---@field levelData LevelData
---@field stackBehaviours StackBehaviours
---@field inputMethod InputMethod
---@field inputs string

---@class ReplaySimulatedStack : ReplayBaseStack
---@field attackSettings table
---@field healthSettings HealthSettings

---@class GarbageFlow
---@field source integer index of the stack whose outgoing garbage queue is used as the source
---@field recipients integer[] stacks that consume the outgoing garbage

---@class BaseStackMetadata
---@field stackIndex integer
---@field renderIndex integer?
---@field panelId string?
---@field characterId string?
---@field wins integer?

---@class StackMetadata : BaseStackMetadata
---@field publicId integer?
---@field name string?
---@field level integer?
---@field difficulty integer?
---@field analytics AnalyticsData?

---@class SimulatedStackMetadata : BaseStackMetadata
---@field challengeModeDifficulty integer?
---@field stageIndex integer?

---@class ReplayMetadata
---@field timestamp integer The time the replay got created as a system dependent timestamp; this denotes the start time
---@field stacks BaseStackMetadata[]
---@field stageId string? The stage that was picked for the match on the machine saving the replay
---@field winnerIndex integer? index of players that won the match; nil if incomplete or the match concluded with a tie
---@field winnerId integer? publicId of the player that won the match; negative if unknown; nil if incomplete or the match concluded with a tie
---@field ranked boolean? If the match counted towards a ladder
---@field incomplete boolean? If the match was finished by an abort
---@field completed boolean? If the match that is represented by the replay has already finished
---@field gameId integer? The identifier for the game on the server it was played on
---@field duration integer? How long the game took in frames
---@field gameModeName ("timeattack" | "endless" | "vsSelf" | "training" | "challenge" | "VS" | "puzzle")?

---@class ReplayV3
---@field engineVersion string The engine version the replay was generated with
---@field replayVersion integer Indicates the version of the replay's data format
---@field panelSource ReplayPanelSource
---@field rules MatchRules
---@field stacks ReplayBaseStack[]
---@field garbageFlows GarbageFlow[]
---@field metadata ReplayMetadata
---@overload fun(engineVersion: string, rules: MatchRules, panelSource: ReplayPanelSource): ReplayV3
local ReplayV3 = class(
---@param self ReplayV3
---@param engineVersion string
---@param rules MatchRules
---@param panelSource { [ReplayPanelSourceType]: any }
function(self, engineVersion, rules, panelSource)
  self.engineVersion = engineVersion
  self.replayVersion = REPLAY_VERSION
  self.rules = rules
  self.panelSource = panelSource
  self.stacks = {}
  self.garbageFlows = {}
  self.metadata = { stacks = {}, timestamp = to_UTC(os.time()) }
end)

-- so that json.encode always has the same basic structure
ReplayV3.keyOrder = {keyorder = {"engineVersion", "replayVersion", "panelSource", "rules", "stacks", "garbageFlows", "metadata"}}

---@enum ReplayPanelSourceType
ReplayV3.panelSourceTypes = { seedV1 = 1, puzzle = 2, seedV2 = 3 }
---@enum StackType
ReplayV3.stackTypes = { Stack = 1, SimulatedStack = 2 }

---@param ranked boolean
function ReplayV3:setRanked(ranked)
  self.metadata.ranked = ranked
end

---@param stageId string
function ReplayV3:setStage(stageId)
  self.metadata.stageId = stageId
end

-- set the duration in frames
---@param duration integer
function ReplayV3:setDuration(duration)
  self.metadata.duration = duration
end

---@param timestamp integer
function ReplayV3:setTimestamp(timestamp)
  self.metadata.timestamp = timestamp
end

function ReplayV3:generateFileName()
  local time = os.date("*t", self.metadata.timestamp)
  local filename = "v" .. self.engineVersion .. "-"
  filename = filename .. string.format("%04d-%02d-%02d-%02d-%02d-%02d", time.year, time.month, time.day, time.hour, time.min, time.sec)

  for i, player in ipairs(self.metadata.stacks) do
    local stack = self.stacks[player.stackIndex]
    if stack.stackType == ReplayV3.stackTypes.Stack then
      ---@cast stack ReplayStack
      ---@cast player StackMetadata
      filename = filename .. "-" .. player.name
      if player.level then
        filename = filename .. "-L" .. player.level
      elseif player.difficulty then
        filename = filename .. "-Spd" .. stack.levelData.startingSpeed
        filename = filename .. "-Dif" .. player.difficulty
      end
    else
      ---@cast stack ReplaySimulatedStack
      ---@cast player SimulatedStackMetadata
      if player.challengeModeDifficulty then
        filename = filename .. "-stage-" .. player.challengeModeDifficulty .. "-" .. (player.stageIndex or 0)
      end
    end
  end

  filename = filename .. "-" .. self.metadata.gameModeName

  if self.metadata.gameModeName == "VS" then
    if tableUtils.trueForAll(self.stacks, function(p) return p.stackType == ReplayV3.stackTypes.Stack end) then
      filename = filename .. (self.metadata.ranked and "ranked" or "casual")
    end

    if not self.metadata.incomplete then
      if self.metadata.winnerIndex then
        filename = filename .. "-P" .. self.metadata.winnerIndex .. "wins"
      else
        filename = filename .. "-draw"
      end
    end
  end

  if self.metadata.incomplete then
    filename = filename .. "-INCOMPLETE"
  end

  return filename
end

---@param outcome (0 | 1 | 2 | nil)
function ReplayV3:setOutcome(outcome)
  if outcome == nil then
    self.metadata.incomplete = true
    self.metadata.winnerIndex = nil
    self.metadata.winnerId = nil
  else
    self.metadata.incomplete = nil
    if outcome == 0 then
      -- it's a tie!
      self.metadata.winnerIndex = nil
      self.metadata.winnerId = nil
    else
      self.metadata.winnerIndex = outcome
      for i, player in ipairs(self.metadata.stacks) do
        if player.stackIndex == i and self.stacks[i].stackType == ReplayV3.stackTypes.Stack then
          ---@cast player StackMetadata
          self.metadata.winnerId = player.publicId
        end
      end
    end
  end
  self.metadata.completed = true
end

---@param pathSeparator ("/" | "\\")
function ReplayV3:generatePath(pathSeparator)
  local now = os.date("*t", self.metadata.timestamp)
  local sep = pathSeparator
  local path = "replays" .. sep .. "v" .. self.engineVersion .. sep .. string.format("%04d" .. sep .. "%02d" .. sep .. "%02d", now.year, now.month, now.day)

  if self.metadata.gameModeName == "timeattack" then
    path = path .. sep .. "Time Attack"
  elseif self.metadata.gameModeName == "endless" then
    path = path .. sep .. "Endless"
  elseif self.metadata.gameModeName == "puzzle" then
    path = path .. sep .. "Puzzle"
  elseif self.metadata.gameModeName == "vsSelf" then
    path = path .. sep .. "Vs Self"
  elseif self.metadata.gameModeName == "training" then
    path = path .. sep .. "Training"
  elseif self.metadata.gameModeName == "challenge" then
    path = path .. sep .. "Challenge Mode"
  elseif self.metadata.gameModeName == "VS" then
    local names = {}
    for i, player in ipairs(self.metadata.stacks) do
      ---@cast player StackMetadata
      names[i] = player.name
    end
    -- sort player names alphabetically for folder name so we don't have a folder "a-vs-b" and also "b-vs-a"
    table.sort(names)
    path = path .. sep .. table.concat(names, "-vs-")
  else
    path = path .. sep .. "Unknown"
  end

  return path
end

---@param match Match
---@param replay ReplayV3
function ReplayV3.finalizeReplay(match, replay)
  if not replay.metadata.completed then
    for i, stack in ipairs(match.stacks) do
      if stack.TYPE == "Stack" then
        ---@cast stack Stack
        replay.stacks[i].inputs = InputCompression.compressInputTable(stack.confirmedInput)
      end
    end

    -- abort is functionally equivalent to #match.winners == 0
    if match.aborted then
      replay:setOutcome()
    else
      local winners = match:getWinners()
      if #winners == 1 then
        replay:setOutcome(tableUtils.indexOf(match.stacks, match.winners[1]))
      elseif #winners > 1 then
        replay:setOutcome(0)
      end
    end
  end
end

---@param replay ReplayV3
function ReplayV3.replayCanBeViewed(replay)
  if DEBUG_ENABLED then
    return true
  end
  if replay.engineVersion > consts.ENGINE_VERSION then
    -- replay is from a newer game version, we can't watch
    -- or maybe we can but there is no way to verify we can
    return false
  elseif replay.engineVersion < consts.VERSION_MIN_VIEW then
    -- there were breaking changes since the version the replay was recorded on
    -- definitely can not watch
    return false
  else
    if replay.engineVersion == consts.ENGINE_VERSIONS.LEVELDATA then
      local stack = replay.stacks[2]
      ---@cast stack ReplaySimulatedStack
      if stack and stack.stackType == 2 and not stack.healthSettings then
        -- in v048 garbage matching was broken for blocks higher than 1 row that were touching horizontally, so deny viewing those
        local hasBrokenGarbage = false
        for i, attackPattern in ipairs(stack.attackSettings.attackPatterns) do
          if attackPattern.height > 1 and attackPattern.width <= 3 then
            hasBrokenGarbage = true
            break
          end
        end
        return not hasBrokenGarbage
      end
    end

    -- can view this one
    return true
  end
end

---@param replayData table
---@return ReplayV3
function ReplayV3.createFromV3Data(replayData)
  ---@diagnostic disable-next-line: param-type-mismatch
  replayData = setmetatable(replayData, ReplayV3)

  ---@cast replayData ReplayV3

  for i, stack in ipairs(replayData.stacks) do
    if stack.stackType == 1 then
      ---@cast stack ReplayStack
      if LevelData.validate(stack.levelData) then
        stack.levelData = setmetatable(stack.levelData, LevelData)
      end
      -- the startTimersWithSwapCount got retired in favor of delaySimulationUntil
      -- as there were no use cases in which it was set to a different value than 1, there should be no problems with a straight up replacement
---@diagnostic disable-next-line: undefined-field
      if stack.stackBehaviours.startTimersWithSwapCount > 0 then
        stack.stackBehaviours.delaySimulationUntil = "firstSwap"
      end
    end
  end
  return replayData
end

-- creates a Replay from the table t which contains the deserialized data representation of a replay from network or file
-- use the completed flag to indicate whether the replay is done (functionally equivalent to being loaded from file at this time)
--   or whether it is in progress (functionally equivalent to getting the replay sent on joining a match as a spectator)
function ReplayV3.createFromTable(t, completed)
  local replay
  if not t then
    -- there was a problem reading the file
    return replay
  else
    if t.replayVersion == 3 then
      replay = ReplayV3.createFromV3Data(t)
      t.metadata.completed = completed
    else
      if not t.replayVersion then
        replay = ReplayV2.createFromLegacyReplay(t)
      elseif tonumber(t.replayVersion) == 2 then
        replay = ReplayV2.createFromV2Data(t)
      end

      if completed ~= nil then
        replay.completed = completed
      end
      replay = ReplayV3.loadFromV2Replay(replay)
    end
  end

  return replay
end

---@param v2Replay ReplayV2
---@return ReplayV3
function ReplayV3.loadFromV2Replay(v2Replay)
  local stacksActive

  if v2Replay.gameMode.stackInteraction == GameModes.StackInteractions.ATTACK_ENGINE then
    stacksActive = 1
  else
    stacksActive = #v2Replay.players - 1
  end

  local timeLimit
  if v2Replay.gameMode.timeLimit then
    timeLimit = v2Replay.gameMode.timeLimit * 60
  end
  ---@type MatchRules
  local rules = {
    doCountdown = v2Replay.gameMode.doCountdown,
    matchEndConditions = { STACKS_ACTIVE = stacksActive, TIME_LIMIT = timeLimit },
    matchWinRuleset = { { GAME_OVER_CLOCK = "HIGHEST" } },
    -- other conditions were not part of replays in v2
    stackOverConditions = { HEALTH = 0 },
    -- StackWinConditions were always empty in v2 replays
    stackWinConditions = {},
    -- new in v3
    stackSetupModifications = {}
  }

  local panelSource = {
    sourceType = ReplayV3.panelSourceTypes.seedV1,
    seed = v2Replay.seed,
    allowAdjacentColorsOnStartingBoard = tableUtils.trueForAll(v2Replay.players, function(p) return (not p.human) or p.settings.allowAdjacentColors end),
    shockEnabled = (v2Replay.gameMode.stackInteraction ~= GameModes.StackInteractions.NONE)
  }

  local replay = ReplayV3(v2Replay.engineVersion, rules, panelSource)

  replay.metadata.stageId = v2Replay.stageId
  replay.metadata.timestamp = v2Replay.timestamp
  replay.metadata.winnerIndex = v2Replay.winnerIndex
  replay.metadata.winnerId = v2Replay.winnerId
  replay.metadata.ranked = v2Replay.ranked
  replay.metadata.completed = v2Replay.completed
  replay.metadata.gameId = v2Replay.gameId
  replay.metadata.duration = v2Replay.duration

  if v2Replay.gameMode.stackInteraction == GameModes.StackInteractions.ATTACK_ENGINE then
    local v2Player = v2Replay.players[1]
    local behaviours = {
      passiveRaise = true,
      allowManualRaise = true,
      swapStallingMode = 0,
      swapStallingPunish = 0,
    }
    replay.stacks[1] = {
      stackType = ReplayV3.stackTypes.Stack,
      levelData = v2Player.settings.levelData,
      stackBehaviours = behaviours,
      inputMethod = v2Player.settings.inputMethod,
      inputs = v2Player.settings.inputs,
    }

    replay.stacks[2] = {
      stackType = ReplayV3.stackTypes.SimulatedStack,
      attackSettings = v2Player.settings.attackEngineSettings
    }

    local metadata = {
      publicId = v2Player.publicId,
      name = v2Player.name,
      stackIndex = 1,
      wins = v2Player.wins,
      characterId = v2Player.settings.characterId,
      panelId = v2Player.settings.panelId,
      level = v2Player.settings.level,
      difficulty = v2Player.settings.difficulty,
      analytics = v2Player.analytics
    }
    replay.metadata.stacks[1] = metadata
    replay.metadata.stacks[2] = {
      panelId = v2Player.settings.panelId,
      stackIndex = 2,
    }

    replay.garbageFlows[#replay.garbageFlows+1] = {
      source = 2,
      recipients = { 1 },
    }
  else
    for i, v2Player in ipairs(v2Replay.players) do
      if v2Player.human then
        ---@type StackBehaviours
        local behaviours = {
          passiveRaise = true,
          allowManualRaise = true,
          swapStallingMode = 0,
          swapStallingPunish = 0,
        }
        ---@type ReplayStack
        local replayStack = {
          stackType = ReplayV3.stackTypes.Stack,
          levelData = v2Player.settings.levelData,
          stackBehaviours = behaviours,
          inputMethod = v2Player.settings.inputMethod,
          inputs = v2Player.settings.inputs,
        }
        replay.stacks[i] = replayStack

        if v2Player.settings.allowAdjacentColors then
          replayStack.levelData.adjacentDenialFrequency = 0
        else
          replayStack.levelData.adjacentDenialFrequency = 1
        end

        ---@type StackMetadata
        local metadata = {
          publicId = v2Player.publicId,
          name = v2Player.name,
          stackIndex = i,
          wins = v2Player.wins,
          characterId = v2Player.settings.characterId,
          panelId = v2Player.settings.panelId,
          level = v2Player.settings.level,
          difficulty = v2Player.settings.difficulty,
          analytics = v2Player.analytics
        }
        replay.metadata.stacks[i] = metadata
      else
        ---@type ReplaySimulatedStack
        local replayStack = {
          stackType = ReplayV3.stackTypes.SimulatedStack,
          attackSettings = v2Player.settings.attackEngineSettings,
          healthSettings = v2Player.settings.healthSettings
        }

        replay.stacks[i] = replayStack

        ---@type SimulatedStackMetadata
        local metadata = {
          stackIndex = i,
          wins = v2Player.wins,
          characterId = v2Player.settings.characterId,
          panelId = v2Player.settings.panelId,
          stageIndex = v2Player.settings.level,
          challengeModeDifficulty = v2Player.settings.difficulty
        }
        replay.metadata.stacks[i] = metadata
      end
    end

    if v2Replay.gameMode.stackInteraction == GameModes.StackInteractions.SELF then
      replay.garbageFlows[#replay.garbageFlows+1] = {
        source = 1,
        recipients = { 1 }
      }
    elseif v2Replay.gameMode.stackInteraction == GameModes.StackInteractions.VERSUS then
      replay.garbageFlows[#replay.garbageFlows+1] = {
        source = 1,
        recipients = { 2 }
      }
      replay.garbageFlows[#replay.garbageFlows+1] = {
        source = 2,
        recipients = { 1 }
      }
    end
  end

  if v2Replay.gameMode.stackInteraction == GameModes.StackInteractions.NONE then
    if v2Replay.gameMode.timeLimit then
      replay.metadata.gameModeName = "timeattack"
    else
      replay.metadata.gameModeName = "endless"
    end
  elseif v2Replay.gameMode.stackInteraction == GameModes.StackInteractions.SELF then
    replay.metadata.gameModeName = "vsSelf"
  elseif v2Replay.gameMode.stackInteraction == GameModes.StackInteractions.ATTACK_ENGINE then
    replay.metadata.gameModeName = "training"
  elseif v2Replay.gameMode.stackInteraction == GameModes.StackInteractions.VERSUS then
    if tableUtils.trueForAny(v2Replay.players, function(p) return not p.human end) then
      replay.metadata.gameModeName = "challenge"
    else
      replay.metadata.gameModeName = "VS"
    end
  end

  return replay
end


return ReplayV3