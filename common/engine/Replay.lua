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

function Replay.createNewReplay(match)
  local replay = Replay(match.engineVersion, match.seed, match.gameMode, match.puzzle)
  replay:setStage(match.stage)
  replay:setRanked(match.ranked)

  for i, player in ipairs(match.players) do
    local replayPlayer = ReplayPlayer(player.name, player.publicId, player.human)
    replayPlayer:setWins(player.wins)
    replayPlayer:setCharacterId(player.settings.characterId)
    replayPlayer:setPanelId(player.settings.panelId)
    replayPlayer:setLevelData(player.settings.levelData)
    replayPlayer:setInputMethod(player.settings.inputMethod)
    replayPlayer:setAllowAdjacentColors(player.stack.allowAdjacentColors)
    replayPlayer:setAttackEngineSettings(player.settings.attackEngineSettings)
    replayPlayer:setHealthSettings(player.settings.healthSettings)
    -- these are display-only props, the true info is stored in levelData for either of them
    if player.settings.style == GameModes.Styles.MODERN then
      replayPlayer:setLevel(player.settings.level)
    else
      replayPlayer:setDifficulty(player.settings.difficulty)
    end

    replay:updatePlayer(i, replayPlayer)
  end

  match.replay = replay

  return replay
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
      -- really really bold assumption; serverside replays haven't been tracking engineVersion ever
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

function Replay.finalizeAndWriteReplay(extraPath, extraFilename, replay)
  if replay.incomplete then
    extraFilename = extraFilename .. "-INCOMPLETE"
  end
  local path, filename = Replay.finalReplayFilename(extraPath, extraFilename)
  local replayJSON = json.encode(replay)
  Replay.writeReplayFile(path, filename, replayJSON)
end

function Replay.finalReplayFilename(extraPath, extraFilename)
  local now = os.date("*t", to_UTC(os.time()))
  local sep = "/"
  local path = "replays" .. sep .. "v" .. consts.ENGINE_VERSION .. sep .. string.format("%04d" .. sep .. "%02d" .. sep .. "%02d", now.year, now.month, now.day)
  if extraPath then
    path = path .. sep .. extraPath
  end
  local filename = "v" .. consts.ENGINE_VERSION .. "-" .. string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec)
  if extraFilename then
    filename = filename .. "-" .. extraFilename
  end
  filename = filename .. ".json"
  logger.debug("saving replay as " .. path .. sep .. filename)
  return path, filename
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

-- writes a replay file of the given path and filename
function Replay.writeReplayFile(path, filename, replayJSON)
  assert(path ~= nil)
  assert(filename ~= nil)
  assert(replayJSON ~= nil)
  Replay.lastPath = path
  pcall(
    function()
      love.filesystem.createDirectory(path)
      love.filesystem.write(path .. "/" .. filename, replayJSON)
    end
  )
end

return Replay