local logger = require("common.lib.logger")
local GameModes = require("common.engine.GameModes")
local consts = require("common.engine.consts")
local class = require("common.lib.class")
require("common.lib.timezones")
local tableUtils = require("common.lib.tableUtils")
local ReplayPlayer = require("common.engine.ReplayPlayer")

local REPLAY_VERSION = 2

-- A replay is a particular recording of a play of the game. Temporarily this is just helper methods.
Replay = class(function(self, engineVersion, seed, gameMode, puzzle)
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

function Replay.load(jsonData)
  local replay
  if not jsonData then
    -- there was a problem reading the file
    return false, nil
  else
    if not jsonData.engineVersion then
      -- really really bold assumption; serverside replays haven't been tracking engineVersion until very late into v047
      jsonData.engineVersion = "046"
    end
    if not jsonData.replayVersion then
      replay = require("common.engine.replayV1").transform(jsonData)
    else
      replay = require("common.engine.replayV2").transform(jsonData)
    end
    replay.loadedFromFile = true
  end

  return true, replay
end

function Replay.addAnalyticsDataToReplay(match, replay)
  replay.duration = match.clock

  for i = 1, #match.players do
    if match.players[i].human then
      local stack = match.players[i].stack
      local playerTable = replay.players[i]
      playerTable.analytics = stack.analytic.data
      playerTable.analytics.score = stack.score
      if match.room_ratings and match.room_ratings[i] then
        playerTable.analytics.rating = match.room_ratings[i]
      end
    end
  end

  return replay
end

function Replay.finalizeReplay(match, replay)
  if not replay.loadedFromFile then
    replay = Replay.addAnalyticsDataToReplay(match, replay)
    replay.stageId = match.stageId
    for i = 1, #match.players do
      if match.players[i].stack.confirmedInput then
        replay.players[i].settings.inputs = ReplayPlayer.compressInputString(table.concat(match.players[i].stack.confirmedInput))
      end
    end
    replay.incomplete = match.aborted

    if #match.winners == 1 then
      -- ideally this would be public player id
      replay.winnerIndex = tableUtils.indexOf(match.players, match.winners[1])
    end
  end
end

return Replay