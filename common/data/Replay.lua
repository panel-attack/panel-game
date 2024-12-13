local logger = require("common.lib.logger")
local GameModes = require("common.engine.GameModes")
local consts = require("common.engine.consts")
local class = require("common.lib.class")
require("common.lib.timezones")
local tableUtils = require("common.lib.tableUtils")
local ReplayPlayer = require("common.data.ReplayPlayer")
local LevelPresets = require("common.data.LevelPresets")
local LevelData = require("common.data.LevelData")

local REPLAY_VERSION = 2

---@class Replay
---@field timestamp number The time the replay got created as a system dependent timestamp
---@field engineVersion string The engine version the replay was generated with
---@field replayVersion number Indicates the version of the replay's data format
---@field seed number The seed to be used to for random functions
---@field gameMode table Contains flags and fields determining the overall Match settings
---@field players ReplayPlayer[] The players that are/were part of the Match
---@field ranked boolean? If the match counted towards the ladder
---@field stageId string? The stage that was picked for the match on the machine saving the replay
---@field duration number? How long the game took in frames
---@field incomplete boolean? If the match was finished by an abort
---@field completed boolean? If the match that is represented by the replay has already finished
---@field winnerIndex number? index of players that won the match; nil if incomplete or the match concluded with a tie
---@field winnerId number? publicId of the player that won the match; negative if unknown; nil if incomplete or the match concluded with a tie
---@field gameId number? The identifier for the game on the server it was played on

-- A replay is a data recording of a Match
---@class Replay
---@overload fun(engineVersion: string, seed: number, gameMode: table, puzzle: table?): Replay
local Replay = class(
function(self, engineVersion, seed, gameMode, puzzle)
    self.timestamp = to_UTC(os.time())
    self.engineVersion = engineVersion
    self.replayVersion = REPLAY_VERSION
    self.seed = seed
    -- the gameMode argument in the constructor expects the format specified in GameModes.lua
    self.gameMode = {
      stackInteraction = gameMode.stackInteraction,
      winConditions = gameMode.winConditions or {},
      gameOverConditions = gameMode.gameOverConditions,
      timeLimit = gameMode.timeLimit,
      doCountdown = gameMode.doCountdown or true,
      puzzle = puzzle,
    }
    self.players = {}
  end
)

Replay.TYPE = "Replay"

function Replay:setRanked(ranked)
  self.ranked = ranked
end

function Replay:setStage(stageId)
  self.stageId = stageId
end

-- set the duration in frames
function Replay:setDuration(duration)
  self.duration = duration
end

function Replay:setOutcome(outcome)
  if outcome == nil then
    self.incomplete = true
    self.winnerIndex = nil
    self.winnerId = nil
  else
    self.incomplete = nil
    if outcome == 0 then
      -- it's a tie!
      self.winnerIndex = nil
      self.winnerId = nil
    else
      self.winnerIndex = outcome
      self.winnerId = self.players[outcome].publicId
    end
  end
  self.completed = true
end

function Replay:setTimestamp(timestamp)
  self.timestamp = timestamp
end

-- adds or updates a replay player at the specified index
-- replayPlayer is a table as defined by the ReplayPlayer class
function Replay:updatePlayer(i, replayPlayer)
  self.players[i] = replayPlayer
end

function Replay:generatePath(pathSeparator)
  local now = os.date("*t", self.timestamp)
  local sep = pathSeparator
  local path = "replays" .. sep .. "v" .. self.engineVersion .. sep .. string.format("%04d" .. sep .. "%02d" .. sep .. "%02d", now.year, now.month, now.day)

  if self.gameMode.stackInteraction == GameModes.StackInteractions.NONE then
    if self.gameMode.timeLimit then
      path = path .. sep .. "Time Attack"
    else
      path = path .. sep .. "Endless"
    end
  elseif self.gameMode.stackInteraction == GameModes.StackInteractions.SELF then
    path = path .. sep .. "Vs Self"
  elseif self.gameMode.stackInteraction == GameModes.StackInteractions.ATTACK_ENGINE then
    path = path .. sep .. "Training"
  elseif self.gameMode.stackInteraction == GameModes.StackInteractions.VERSUS then
    if tableUtils.trueForAny(self.players, function(p) return not p.human end) then
      path = path .. sep .. "Challenge Mode"
    else
      local names = {}
      for i, player in ipairs(self.players) do
        names[i] = player.name
      end
      -- sort player names alphabetically for folder name so we don't have a folder "a-vs-b" and also "b-vs-a"
      table.sort(names)
      path = path .. sep .. table.concat(names, "-vs-")
    end
  end

  return path
end

function Replay:generateFileName()
  local time = os.date("*t", self.timestamp)
  local filename = "v" .. self.engineVersion .. "-"
  filename = filename .. string.format("%04d-%02d-%02d-%02d-%02d-%02d", time.year, time.month, time.day, time.hour, time.min, time.sec)

  for _, player in ipairs(self.players) do
    if player.human then
      filename = filename .. "-" .. player.name
      if player.settings.level then
        filename = filename .. "-L" .. player.settings.level
      elseif player.settings.difficulty then
        filename = filename .. "-Spd" .. player.settings.levelData.startingSpeed
        filename = filename .. "-Dif" .. player.settings.difficulty
      end
    else
      filename = filename .. "-stage-" .. player.settings.difficulty .. "-" .. (player.settings.level or 0)
    end
  end

  if self.gameMode.stackInteraction == GameModes.StackInteractions.NONE then
    if self.gameMode.timeLimit then
      filename = filename .. "-timeattack"
    else
      filename = filename .. "-endless"
    end
  elseif self.gameMode.stackInteraction == GameModes.StackInteractions.SELF then
    filename = filename .. "-vsSelf"
  elseif self.gameMode.stackInteraction == GameModes.StackInteractions.ATTACK_ENGINE then
    filename = filename .. "-training"
  elseif self.gameMode.stackInteraction == GameModes.StackInteractions.VERSUS then
    if tableUtils.trueForAny(self.players, function(p) return not p.human end) then
      filename = filename .. "-challenge"
    else
      filename = filename .. "-VS-" .. (self.ranked and "ranked" or "casual")
    end

    if not self.incomplete then
      if self.winnerIndex then
        filename = filename .. "-P" .. self.winnerIndex .. "wins"
      else
        filename = filename .. "-draw"
      end
    end
  end

  if self.incomplete then
    filename = filename .. "-INCOMPLETE"
  end

  return filename
end

function Replay.replayCanBeViewed(replay)
  if replay.engineVersion > consts.ENGINE_VERSION then
    -- replay is from a newer game version, we can't watch
    -- or maybe we can but there is no way to verify we can
    return false
  elseif replay.engineVersion < consts.VERSION_MIN_VIEW then
    -- there were breaking changes since the version the replay was recorded on
    -- definitely can not watch
    return false
  else
    -- can view this one
    return true
  end
end

function Replay.finalizeReplay(match, replay)
  if not replay.completed then
    for i = 1, #match.stacks do
      if match.stacks[i].confirmedInput then
        replay.players[i].settings.inputs = ReplayPlayer.compressInputString(table.concat(match.stacks[i].confirmedInput))
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

-- creates a Replay from the table t which contains the deserialized data representation of a replay from network or file
-- use the completed flag to indicate whether the replay is done (functionally equivalent to being loaded from file at this time)
--   or whether it is in progress (functionally equivalent to getting the replay sent on joining a match as a spectator)
function Replay.createFromTable(t, completed)
  local replay
  if not t then
    -- there was a problem reading the file
    return replay
  else
    if not t.replayVersion then
      replay = Replay.createFromLegacyReplay(t)
    elseif tonumber(t.replayVersion) == 2 then
      replay = Replay.createFromV2Data(t)
    end
    if completed ~= nil then
      replay.completed = completed
    end
  end

  return replay
end

function Replay.createFromV2Data(replayData)
  local replay = Replay(replayData.engineVersion, replayData.seed, replayData.gameMode)
  replay:setStage(replayData.stageId)
  replay:setRanked(replayData.ranked)
  replay:setDuration(replayData.duration)

  for i, player in ipairs(replayData.players) do
    local replayPlayer = ReplayPlayer(player.name, player.publicId, player.human)
    replayPlayer:setWins(player.wins)
    replayPlayer:setCharacterId(player.settings.characterId)
    replayPlayer:setPanelId(player.settings.panelId)
    if player.human then
      if LevelData.validate(player.settings.levelData) then
        setmetatable(player.settings.levelData, LevelData)
        replayPlayer:setLevelData(player.settings.levelData)
      end
      replayPlayer:setInputMethod(player.settings.inputMethod)
      replayPlayer:setInputs(ReplayPlayer.decompressInputString(player.settings.inputs))
    else
      replayPlayer:setHealthSettings(player.settings.healthSettings)
    end
    replayPlayer:setAllowAdjacentColors(player.settings.allowAdjacentColors)
    replayPlayer:setAttackEngineSettings(player.settings.attackEngineSettings)
    replayPlayer:setLevel(player.settings.level)
    replayPlayer:setDifficulty(player.settings.difficulty)

    replay:updatePlayer(i, replayPlayer)
  end

  -- setOutcome accesses ReplayPlayer tables for the publicId so can only happen after they have been set
  if replayData.incomplete then
    replay:setOutcome()
  else
    replay:setOutcome(replayData.winnerIndex or 0)
  end

  return replay
end

-- creates a replay from the table created by decoding the legacy json file
-- timestamp and winnerIndex are optional properties that were not saved in the json for the longest time
-- they were however encoded in the filename
-- since this is in common they'd have to be determined elsewhere and passed in as arguments
-- if they are present in the data, the data takes priority over the arguments
function Replay.createFromLegacyReplay(legacyReplay, timestamp, winnerIndex)
  local mode
  local gameMode
  if legacyReplay.vs then
    mode = "vs"
    if legacyReplay.vs.P2_char then
      gameMode = GameModes.getPreset("TWO_PLAYER_VS")
    else
      gameMode = GameModes.getPreset("ONE_PLAYER_VS_SELF")
    end
  elseif legacyReplay.time then
    mode = "time"
    gameMode = GameModes.getPreset("ONE_PLAYER_TIME_ATTACK")
  elseif legacyReplay.endless then
    mode = "endless"
    gameMode = GameModes.getPreset("ONE_PLAYER_ENDLESS")
  end
  local v1r = legacyReplay[mode]
  -- doCountdown used to be configurable client side for time attack / endless
  gameMode.doCountdown = v1r.do_countdown

  if mode == "time" then
    gameMode.timeLimit = 120
  end

  -- really bold assumption; serverside replays haven't been tracking engineVersion until very late into v047
  local engineVersion = legacyReplay.engineVersion or "046"

  local replay = Replay(engineVersion, v1r.seed, gameMode)
  if legacyReplay.timestamp then
    replay:setTimestamp(legacyReplay.timestamp)
  elseif timestamp then
    replay:setTimestamp(timestamp)
  end
  replay:setStage(v1r.stage or consts.RANDOM_STAGE_SPECIAL_VALUE)
  replay:setRanked(v1r.match_type == "Ranked")

  local p1 = ReplayPlayer(v1r.P1_name or "Player 1", -1, true)
  p1:setWins(v1r.P1_win_count or 0)
  p1:setCharacterId(v1r.P1_char)
  -- not saved in v1
  p1:setPanelId(config and config.panels or "pacci")

  if gameMode.playerCount == 2 then
    p1:setInputMethod(v1r.P1_inputMethod or "controller")
  else
    p1:setInputMethod(v1r.inputMethod or "controller")
  end

  p1:setInputs(ReplayPlayer.decompressInputString(v1r.in_buf))

  if v1r.P1_level then
    p1:setLevel(v1r.P1_level)
    -- suffices because modern endless/timeattack never had replays
    p1:setAllowAdjacentColors(v1r.P1_level < 8)
    p1:setLevelData(LevelPresets.getModern(v1r.P1_level))
  else
    p1:setDifficulty(v1r.difficulty)
    p1:setAllowAdjacentColors(true)
    local levelData = LevelPresets.getClassic(v1r.difficulty)
    levelData:setStartingSpeed(v1r.speed)
    if v1r.difficulty == 1 and mode == "endless" then
      -- endless has 5 colors, the preset has 6 like time attack so fix it
      levelData:setColorCount(5)
    end
    p1:setLevelData(levelData)
  end

  replay:updatePlayer(1, p1)

  if v1r.P2_char then
    local p2 = ReplayPlayer(v1r.P2_name, -2, true)
    p2:setWins(v1r.P2_win_count or 0)
    p2:setCharacterId(v1r.P2_char)
    -- not saved in v1
    p2:setPanelId(config and config.panels or "pacci")
    p2:setInputMethod(v1r.P2_inputMethod or "controller")
    p2:setInputs(ReplayPlayer.decompressInputString(v1r.I))

    -- presence of V2 means level and vs
    p2:setLevel(v1r.P2_level)
    p2:setAllowAdjacentColors(v1r.P2_level < 8)
    p2:setLevelData(LevelPresets.getModern(v1r.P2_level))

    replay:updatePlayer(2, p2)
  end

  if v1r.duration then
    replay:setDuration(v1r.duration)
  else
    if #replay.players == 1 then
      replay:setDuration(string.len(replay.players[1].settings.inputs))
    elseif #replay.players == 2 then
      replay:setDuration(math.min(string.len(replay.players[1].settings.inputs), string.len(replay.players[2].settings.inputs)))
    end
  end

  if v1r.winner then
    replay:setOutcome(v1r.winner)
  elseif winnerIndex then
    replay:setOutcome(winnerIndex)
  end

  return replay
end

return Replay