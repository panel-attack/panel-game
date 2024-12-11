local Match = require("common.engine.Match")
local class = require("common.lib.class")
local logger = require("common.lib.logger")
local StageLoader = require("client.src.mods.StageLoader")
local ModController = require("client.src.mods.ModController")
local consts = require("common.engine.consts")
local tableUtils = require("common.lib.tableUtils")
local GameModes = require("common.engine.GameModes")
local ChallengeModePlayer = require("client.src.ChallengeModePlayer")
local Player = require("client.src.Player")

local ClientMatch = class(
function(self, players, doCountdown, stackInteraction, winConditions, gameOverConditions, supportsPause, optionalArgs)
  assert(doCountdown ~= nil)
  assert(stackInteraction)
  assert(winConditions)
  assert(gameOverConditions)
  assert(supportsPause ~= nil)
  self.doCountdown = doCountdown
  self.stackInteraction = stackInteraction
  self.winConditions = winConditions
  self.gameOverConditions = gameOverConditions
  if tableUtils.contains(gameOverConditions, GameModes.GameOverConditions.TIME_OUT) then
    assert(optionalArgs.timeLimit)
    self.timeLimit = optionalArgs.timeLimit
  end
  self.supportsPause = supportsPause
  if optionalArgs then
    -- debatable if these couldn't be player settings instead
    self.puzzle = optionalArgs.puzzle
    self.ranked = optionalArgs.ranked
  end

  -- match needs its own table so it can sort players with impunity
  self.players = shallowcpy(players)
end)


function ClientMatch:run()
  
  self.match:run()
end

function ClientMatch:start()
  -- battle room may add the players in any order
  -- match has to make sure the local player ends up as P1 (left side)
  -- if both are local or both are not, order by playerNumber
  table.sort(self.players, function(a, b)
    if a.isLocal == b.isLocal then
      return a.playerNumber < b.playerNumber
    else
      return a.isLocal
    end
  end)

  self.clientStacks = {}
  self.engineStacks = {}
  for i, player in ipairs(self.players) do
    local stack = player:createStackFromSettings()
    self.clientStacks[i] = stack
    self.engineStacks[i] = stack.engine
    stack:connectSignal("dangerMusicChanged", self, self.updateDangerMusic)
  end

  self.match = Match(self.engineStacks, self.doCountdown, self.stackInteraction, self.winConditions, self.gameOverConditions, self.supportsPause,
                     {timeLimit = self.timeLimit, puzzle = self.puzzle, ranked = self.ranked})
  self.match:start()
end

-- if there is no local player that means the client is either spectating (or watching a replay)
---@return boolean if the match has a local player
function ClientMatch:hasLocalPlayer()
  for _, player in ipairs(self.players) do
    if player.isLocal then
      return true
    end
  end

  return false
end

-- Should be called prior to clearing the match.
-- Consider recycling any memory that might leave around a lot of garbage.
-- Note: You can just leave the variables to clear / garbage collect on their own if they aren't large.
function ClientMatch:deinit()
  for i = 1, #self.clientStacks do
    self.clientStacks[i]:deinit()
  end
end

function ClientMatch:setStage(stageId)
  logger.debug("Setting match stage id to " .. (stageId or ""))
  if stageId then
    -- we got one from the server
    self.stageId = StageLoader.fullyResolveStageSelection(stageId)
  elseif #self.players == 1 then
    self.stageId = StageLoader.resolveBundle(self.players[1].settings.selectedStageId)
  else
    self.stageId = StageLoader.fullyResolveStageSelection()
  end
  ModController:loadModFor(stages[self.stageId], self)
end

function ClientMatch:connectSignal(signalName, subscriber, callback)
  self.match:connectSignal(signalName, subscriber, callback)
end

function ClientMatch:disconnectSignal(signalName, subscriber)
  self.match:disconnectSignal(signalName, subscriber)
end

function ClientMatch:abort()
  self.match:abort()
end

function ClientMatch:getWinningPlayerCharacter()
  local character = consts.RANDOM_CHARACTER_SPECIAL_VALUE
  local maxWins = -1
  for i = 1, #self.players do
    if self.players[i].wins > maxWins then
      character = self.players[i].stack.character
      maxWins = self.players[i].wins
    end
  end

  return characters[character]
end

function ClientMatch:togglePause()
  self.match:togglePause()
end

---@param doCountdown boolean if the match should have a countdown before physics start
function ClientMatch:setCountdown(doCountdown)
  self.match:setCountdown(doCountdown)
end

function ClientMatch:rewindToFrame(frame)
  self.match:rewindToFrame(frame)
end

function ClientMatch:enrichReplay()
  local replay = self.match.replay
  replay:setStage(self.stage)
  replay:setRanked(self.ranked)

  for i, replayPlayer in ipairs(replay.players) do
    local player = self.players[i]

    replayPlayer.name = player.name
    replayPlayer.publicId = player.publicId

    replayPlayer:setWins(player.wins)
    replayPlayer:setCharacterId(player.characterId)
    replayPlayer:setPanelId(player.panelId)
    -- these are display-only props, the true info is stored in levelData for either of them
    if player.settings.style == GameModes.Styles.MODERN then
      replayPlayer:setLevel(player.settings.level)
    else
      replayPlayer:setDifficulty(player.settings.difficulty)
    end
  end
end

function ClientMatch.createFromReplay(replay, supportsPause)
  local optionalArgs = {
    timeLimit = replay.gameMode.timeLimit,
    puzzle = replay.gameMode.puzzle,
  }

  local match = Match.createFromReplay(replay, supportsPause)

  local players = {}

  for i = 1, #replay.players do
    if replay.players[i].human then
      players[i] = Player.createFromReplayPlayer(replay.players[i], i)
    else
      players[i] = ChallengeModePlayer.createFromReplayPlayer(replay.players[i], i)
    end
  end

  local match = ClientMatch(
    players,
    replay.gameMode.doCountdown,
    replay.gameMode.stackInteraction,
    replay.gameMode.winConditions,
    replay.gameMode.gameOverConditions,
    supportsPause,
    optionalArgs
  )

  match:setSeed(replay.seed)
  match:setStage(replay.stageId)
  match.engineVersion = replay.engineVersion
  match.replay = replay

  return match
end

function ClientMatch:setSeed(seed)
  self.seed = seed
  self.match:setSeed(seed)
end

return ClientMatch