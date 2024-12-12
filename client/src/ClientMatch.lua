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
local Signal = require("common.lib.signal")
local CharacterLoader = require("client.src.mods.CharacterLoader")

---@class ClientMatch
---@field players table[]
---@field clientStacks PlayerStack[]
---@field match Match
---@field replay Replay?
---@field doCountdown boolean if a countdown is performed at the start of the match
---@field stackInteraction integer how the stacks in the match interact with each other
---@field winConditions integer[] enumerated conditions to determine a winner between multiple stacks
---@field gameOverConditions integer[] enumerated conditions for Stacks to go game over
---@field timeLimit integer? if the game automatically ends after a certain time
---@field supportsPause boolean if the game can be paused
---@field isPaused boolean if the game is currently paused
---@field renderDuringPause boolean if the game should be rendered while paused
---@field currentMusicIsDanger boolean
---@field ranked boolean? if the match counts towards an online ranking
---@field online boolean? if the players in the match are remote
---@field spectators string[] list of spectators in an online game
---@field spectatorString string newLine concatenated version of spectators for display

---@class ClientMatch : Signal
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
  self.isPaused = false

  if optionalArgs then
    -- debatable if these couldn't be player settings instead
    self.puzzle = optionalArgs.puzzle
    self.ranked = optionalArgs.ranked
  end

  -- match needs its own table so it can sort players with impunity
  self.players = shallowcpy(players)

  self.renderDuringPause = false
  self.currentMusicIsDanger = false

  self.spectators = {}
  self.spectatorString = ""

  Signal.turnIntoEmitter(self)
  self:createSignal("countdownEnded")
  self:createSignal("dangerMusicChanged")
  self:createSignal("pauseChanged")
  self:createSignal("matchEnded")
end)

local countdownEnd = consts.COUNTDOWN_START + consts.COUNTDOWN_LENGTH

function ClientMatch:run()
  if self.isPaused or self.match:hasEnded() then
    self.match:runGameOver()
    return
  end


  for i, stack in ipairs(self.clientStacks) do
    -- if stack.cpu then
    --   stack.cpu:run(stack)
    -- end
    if stack and stack.is_local and stack.send_controls and not stack:game_ended() --[[and not stack.cpu]] then
      stack:send_controls()
    end
  end

  self.match:run()

  if self.panicTickStartTime and self.panicTickStartTime == self.clock then
    self:updateDangerMusic()
  end

  if self.doCountdown and self.clock == countdownEnd then
    self:emitSignal("countdownEnded")
  elseif not self.doCountdown and self.clock == consts.COUNTDOWN_START then
    self:emitSignal("countdownEnded")
  end

  self:playCountdownSfx()
  self:playTimeLimitDepletingSfx()

  if self.match:hasEnded() then
    self.match:handleMatchEnd()
    -- execute callbacks
    self:emitSignal("matchEnded", self)
  end
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
    stack:connectSignal("dangerMusicChanged", self, self.updateDangerMusic)
    self.clientStacks[i] = stack
    self.engineStacks[#self.engineStacks+1] = stack.engine

    if self.stackInteraction == GameModes.StackInteractions.ATTACK_ENGINE then
      local attackEngineHost = SimulatedStack({which = #self.stacks + 1, is_local = true, character = CharacterLoader.fullyResolveCharacterSelection()})
      attackEngineHost:addAttackEngine(stack.settings.attackEngineSettings)
      attackEngineHost:setGarbageTarget(stack)
      self.engineStacks[#self.engineStacks+1] = attackEngineHost
    end

    if self.replay then
      if self.replay.completed then
        -- watching a finished replay
        if stack.human then
          stack:receiveConfirmedInput(self.replay.players[i].settings.inputs)
        end
        stack:setMaxRunsPerFrame(1)
      elseif not self:hasLocalPlayer() and self.replay.players[i].settings.inputs then
        -- catching up to a match in progress
        stack:receiveConfirmedInput(self.replay.players[i].settings.inputs)
        stack:enableCatchup(true)
      end
    end
  end

  self.match = Match(self.engineStacks, self.doCountdown, self.stackInteraction, self.winConditions, self.gameOverConditions,
                     {timeLimit = self.timeLimit, puzzle = self.puzzle})
  self.match:start()

  if self.match.timeLimit then
    self.panicTicksPlayed = {}
    for i = 1, 15 do
      self.panicTicksPlayed[i] = false
    end

    self.panicTickStartTime = (self.match.timeLimit - 15) * 60
    if self.match.doCountdown then
      self.panicTickStartTime = self.panicTickStartTime + consts.COUNTDOWN_START + consts.COUNTDOWN_LENGTH
    end
  end
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
  self.isPaused = not self.isPaused
  self:emitSignal("pauseChanged", self)
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
  replay:setStage(self.stageId)
  replay:setRanked(self.ranked)

  for i, replayPlayer in ipairs(replay.players) do
    local player = self.players[i]

    replayPlayer.name = player.name
    replayPlayer.publicId = player.publicId
    replayPlayer.human = player.human

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

  --local match = Match.createFromReplay(replay)

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

function ClientMatch:playCountdownSfx()
  if self.match.doCountdown then
    if self.match.clock < 200 then
      if (self.match.clock - consts.COUNTDOWN_START) % 60 == 0 then
        if self.match.clock == countdownEnd then
          SoundController:playSfx(themes[config.theme].sounds.go)
        else
          SoundController:playSfx(themes[config.theme].sounds.countdown)
        end
      end
    end
  end
end

function ClientMatch:playTimeLimitDepletingSfx()
  if self.match.timeLimit then
    -- have to account for countdown
    if self.match.clock >= self.panicTickStartTime then
      local tickIndex = math.ceil((self.match.clock - self.panicTickStartTime) / 60)
      if self.panicTicksPlayed[tickIndex] == false then
        SoundController:playSfx(themes[config.theme].sounds.countdown)
        self.panicTicksPlayed[tickIndex] = true
      end
    end
  end
end

function ClientMatch:updateDangerMusic()
  local dangerMusic
  if self.panicTickStartTime == nil or self.match.clock < self.panicTickStartTime then
    dangerMusic = tableUtils.trueForAny(self.clientStacks, function(s) return s.danger_music end)
  else
    dangerMusic = true
  end

  if dangerMusic ~= self.currentMusicIsDanger then
    self:emitSignal("dangerMusicChanged", dangerMusic)
    self.currentMusicIsDanger = dangerMusic
  end
end

function ClientMatch:generateSeed()
  local seed = 17
  seed = seed * 37 + self.players[1].rating.new
  seed = seed * 37 + self.players[2].rating.new
  seed = seed * 37 + self.players[1].wins
  seed = seed * 37 + self.players[2].wins

  return seed
end

function ClientMatch:setSeed(seed)
  if seed then
    self.match:setSeed(seed)
  elseif self.online and #self.players > 1 then
    self.match:setSeed(self:generateSeed())
  else
    -- Use the default random seed set up on match creation
  end
end

return ClientMatch