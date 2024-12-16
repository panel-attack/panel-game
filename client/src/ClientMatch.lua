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
local Replay = require("common.data.Replay")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local Telegraph = require("client.src.graphics.Telegraph")
local MatchParticipant = require("client.src.MatchParticipant")
local ChallengeModePlayerStack = require("client.src.ChallengeModePlayerStack")

---@class ClientMatch
---@field players table[]
---@field stacks PlayerStack[]
---@field match Match
---@field replay Replay
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
---@field winners MatchParticipant[]

---@class ClientMatch : Signal
---@overload fun(players: MatchParticipant[], doCountdown: boolean, stackInteraction: integer, winConditions: integer[], gameOverConditions: integer[], supportsPause: boolean, optionalArgs: table?): ClientMatch
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
  self.renderDuringPause = false

  if optionalArgs then
    -- debatable if these couldn't be player settings instead
    self.puzzle = optionalArgs.puzzle
    self.ranked = optionalArgs.ranked
  end

  -- match needs its own table so it can sort players with impunity
  self.players = shallowcpy(players)

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
    self:runGameOver()
    return
  end

  for i, stack in ipairs(self.stacks) do
    -- if stack.cpu then
    --   stack.cpu:run(stack)
    -- end
    if stack and stack.is_local and stack.send_controls and not stack:game_ended() --[[and not stack.cpu]] then
      stack:send_controls()
    end
  end

  self.match:run()

  if self.panicTickStartTime and self.panicTickStartTime == self.match.clock then
    self:updateDangerMusic()
  end

  if self.doCountdown and self.match.clock == countdownEnd then
    self:emitSignal("countdownEnded")
  elseif not self.doCountdown and self.match.clock == consts.COUNTDOWN_START then
    self:emitSignal("countdownEnded")
  end

  self:playCountdownSfx()
  self:playTimeLimitDepletingSfx()

  if self.match:hasEnded() then
    self.match:handleMatchEnd()
    -- this prepares everything about the replay except the save location
    self:finalizeReplay()
    self.ended = true
    -- execute callbacks
    self:emitSignal("matchEnded", self)
  end
end

function ClientMatch:runGameOver()
  for _, stack in ipairs(self.stacks) do
    stack:runGameOver()
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

  self.stacks = {}
  local engineStacks = {}
  for i, player in ipairs(self.players) do
    local stack = player:createStackFromSettings(self, i)
    stack:connectSignal("dangerMusicChanged", self, self.updateDangerMusic)
    self.stacks[i] = stack
    engineStacks[#engineStacks+1] = stack.engine

    if self.stackInteraction == GameModes.StackInteractions.ATTACK_ENGINE then
      local attackEngineHost = ChallengeModePlayerStack({which = #engineStacks + 1, is_local = true, character = CharacterLoader.fullyResolveCharacterSelection()})
      attackEngineHost:addAttackEngine(stack.settings.attackEngineSettings)
      attackEngineHost:setGarbageTarget(stack)
      engineStacks[#engineStacks+1] = attackEngineHost
    end

    if self.replay then
      if self.replay.completed then
        -- watching a finished replay
        if player.human then
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

  self.match = Match(engineStacks, self.doCountdown, self.stackInteraction, self.winConditions, self.gameOverConditions,
                     {timeLimit = self.timeLimit, puzzle = self.puzzle})
  self.match:setSeed(self.seed)
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

  if not self.replay then
    self.replay = self.match:createNewReplay()
  else
    self.match:setAlwaysSaveRollbacks(self.replay.completed)
    self.match:setEngineVersion(self.replay.engineVersion)
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
  for i = 1, #self.stacks do
    self.stacks[i]:deinit()
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
  self:emitSignal("matchEnded", self)
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

---@return Replay?
function ClientMatch:finalizeReplay()
  local replay
  if not self.replay.completed then
    replay = self.replay
    replay:setDuration(self.match.clock)
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

      if player.stack.analytic then
        replayPlayer.analytics = player.stack.analytic.data
        replayPlayer.analytics.score = player.stack.score
        replayPlayer.analytics.rating = player.rating
      end
    end

    Replay.finalizeReplay(self.match, self.replay)
  end

  return replay
end

---@param replay Replay
---@param supportsPause boolean
---@return ClientMatch
function ClientMatch.createFromReplay(replay, supportsPause)
  local optionalArgs = {
    timeLimit = replay.gameMode.timeLimit,
    puzzle = replay.gameMode.puzzle,
  }

  local players = {}

  for i = 1, #replay.players do
    if replay.players[i].human then
      players[i] = Player.createFromReplayPlayer(replay.players[i], i)
    else
      players[i] = ChallengeModePlayer.createFromReplayPlayer(replay.players[i], i)
    end
  end

  local clientMatch = ClientMatch(
    players,
    replay.gameMode.doCountdown,
    replay.gameMode.stackInteraction,
    replay.gameMode.winConditions,
    replay.gameMode.gameOverConditions,
    supportsPause,
    optionalArgs
  )

  clientMatch:setSeed(replay.seed)
  clientMatch:setStage(replay.stageId)
  clientMatch.replay = replay

  return clientMatch
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
    dangerMusic = tableUtils.trueForAny(self.stacks, function(s) return s.danger_music end)
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
    self.seed = seed
  elseif self.online and #self.players > 1 then
    self.seed = self:generateSeed()
  else
    -- Use the default random seed set up on match creation
  end
end


----------------
--- Graphics ---
----------------

function ClientMatch:matchelementOriginX()
  local x = 375 + (464) / 2
  if themes[config.theme]:offsetsAreFixed() then
    x = 0
  end
  return x
end

function ClientMatch:matchelementOriginY()
  local y = 118
  if themes[config.theme]:offsetsAreFixed() then
    y = 0
  end
  return y
end

function ClientMatch:drawMatchLabel(drawable, themePositionOffset, scale)
  local x = self:matchelementOriginX() + themePositionOffset[1]
  local y = self:matchelementOriginY() + themePositionOffset[2]

  if themes[config.theme]:offsetsAreFixed() then
    -- align in center
    x = x - math.floor(drawable:getWidth() * 0.5 * scale)
  else 
    -- align left, no adjustment
  end
  GraphicsUtil.draw(drawable, x, y, 0, scale, scale)
end

function ClientMatch:drawMatchTime(timeString, themePositionOffset, scale)
  local x = self:matchelementOriginX() + themePositionOffset[1]
  local y = self:matchelementOriginY() + themePositionOffset[2]
  GraphicsUtil.draw_time(timeString, x, y, scale)
end

function ClientMatch:drawTimer()
  -- Draw the timer for time attack
  if self.puzzle then
    -- puzzles don't have a timer...yet?
  else
    local frames = 0
    local stack = self.stacks[1]
    if stack ~= nil and stack.game_stopwatch ~= nil and tonumber(stack.game_stopwatch) ~= nil then
      frames = stack.game_stopwatch
    end

    if self.timeLimit then
      frames = (self.timeLimit * 60) - frames
      if frames < 0 then
        frames = 0
      end
    end

    local timeString = frames_to_time_string(frames, self.match.ended)

    self:drawMatchLabel(themes[config.theme].images.IMG_time, themes[config.theme].timeLabel_Pos, themes[config.theme].timeLabel_Scale)
    self:drawMatchTime(timeString, themes[config.theme].time_Pos, themes[config.theme].time_Scale)
  end
end

function ClientMatch:drawMatchType()
  local matchImage = nil
  if self.ranked then
    matchImage = themes[config.theme].images.IMG_ranked
  else
    matchImage = themes[config.theme].images.IMG_casual
  end

  self:drawMatchLabel(matchImage, themes[config.theme].matchtypeLabel_Pos, themes[config.theme].matchtypeLabel_Scale)
end

function ClientMatch:drawCommunityMessage()
  -- Draw the community message
  if not config.debug_mode then
    GraphicsUtil.printf(join_community_msg or "", 0, 668, consts.CANVAS_WIDTH, "center")
  end
end

local function isRollbackActive(stack)
  return stack.engine.framesBehind > GARBAGE_DELAY_LAND_TIME
end

function ClientMatch:render()
  if config.show_fps then
    GraphicsUtil.print("Dropped Frames: " .. GAME.droppedFrames, 1, 12)
  end

  if config.show_fps and #self.stacks > 1 then
    local drawY = 23
    for i = 1, #self.stacks do
      local stack = self.stacks[i]
      GraphicsUtil.print("P" .. stack.which .." Average Latency: " .. stack.engine.framesBehind, 1, drawY)
      drawY = drawY + 11
    end

    if self:hasLocalPlayer() then
      if tableUtils.trueForAny(self.stacks, isRollbackActive) then
        -- let the player know that rollback is active
        local iconSize = 60
        local icon_width, icon_height = themes[config.theme].images.IMG_bug:getDimensions()
        local x = 5
        local y = 30
        GraphicsUtil.draw(themes[config.theme].images.IMG_bug, x, y, 0, iconSize / icon_width, iconSize / icon_height)
      end
    else
      if tableUtils.trueForAny(self.stacks, function(stack) return stack.engine.framesBehind > MAX_LAG * 0.75 end) then
        -- let the spectator know the game is about to die
        local iconSize = 60
        local icon_width, icon_height = themes[config.theme].images.IMG_bug:getDimensions()
        local x = (consts.CANVAS_WIDTH / 2) - (iconSize / 2)
        local y = (consts.CANVAS_HEIGHT / 2) - (iconSize / 2)
        GraphicsUtil.draw(themes[config.theme].images.IMG_bug, x, y, 0, iconSize / icon_width, iconSize / icon_height)
      end
    end
  end

  if config.debug_mode then
    local padding = 14
    local drawX = 500
    local drawY = -4

    -- drawY = drawY + padding
    -- GraphicsUtil.printf("Time Spent Running " .. self.timeSpentRunning * 1000, drawX, drawY)

    -- drawY = drawY + padding
    -- local totalTime = love.timer.getTime() - self.createTime
    -- GraphicsUtil.printf("Total Time " .. totalTime * 1000, drawX, drawY)

    drawY = drawY + padding
    local totalTime = love.timer.getTime() - self.match.createTime
    local timePercent = math.round(self.match.timeSpentRunning / totalTime, 5)
    GraphicsUtil.printf("Time Percent Running Match: " .. timePercent, drawX, drawY)

    drawY = drawY + padding
    local maxTime = math.round(self.match.maxTimeSpentRunning, 5)
    GraphicsUtil.printf("Max Stack Update: " .. maxTime, drawX, drawY)

    drawY = drawY + padding
    GraphicsUtil.printf("Seed " .. self.match.seed, drawX, drawY)

    if self.match.gameOverClock and self.match.gameOverClock > 0 then
      drawY = drawY + padding
      GraphicsUtil.printf("gameOverClock " .. self.match.gameOverClock, drawX, drawY)
    end
  end

  if not self.isPaused or self.renderDuringPause then
    for _, stack in ipairs(self.stacks) do
      -- don't render stacks that only have an attack engine
      if stack.player or stack.healthEngine then
        stack:render()
      end

      if stack.garbageTarget then
        Telegraph:render(stack, stack.garbageTarget)
      end
    end

    -- Draw VS HUD
    if self.stackInteraction == GameModes.StackInteractions.VERSUS then
      if tableUtils.trueForAll(self.players, MatchParticipant.isHuman) or self.ranked then
        self:drawMatchType()
      end
    end

    self:drawTimer()
  end
end

-- a helper function for tests
-- prevents running graphics related processes, e.g. cards, popFX
function ClientMatch:removeCanvases()
  for i = 1, #self.players do
    self.players[i].stack.canvas = nil
  end
end

  -- Draw the pause menu
function ClientMatch:draw_pause()
  if not self.renderDuringPause then
    local image = themes[config.theme].images.pause
    local scale = consts.CANVAS_WIDTH / math.max(image:getWidth(), image:getHeight()) -- keep image ratio
    -- adjust coordinates to be centered
    local x = consts.CANVAS_WIDTH / 2
    local y = consts.CANVAS_HEIGHT / 2
    local xOffset = math.floor(image:getWidth() * 0.5)
    local yOffset = math.floor(image:getHeight() * 0.5)

    GraphicsUtil.draw(image, x, y, 0, scale, scale, xOffset, yOffset)
  end
  local y = 260
  GraphicsUtil.printf(loc("pause"), 0, y, consts.CANVAS_WIDTH, "center", nil, 1, 10)
  GraphicsUtil.printf(loc("pl_pause_help"), 0, y + 30, consts.CANVAS_WIDTH, "center", nil, 1)
end

function ClientMatch:getWinners()
  if not self.winners and self.match:hasEnded() then
    local winningStacks = self.match:getWinners()
    local winners = {}
    for i, stack in ipairs(winningStacks) do
      for j, player in ipairs(self.players) do
        if player.stack.engine == stack then
          winners[#winners+1] = player
          break
        end
      end
    end
    self.winners = winners
    return self.winners
  else
    return self.winners
  end
end

return ClientMatch