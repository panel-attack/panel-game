local Match = require("common.engine.Match")
local class = require("common.lib.class")
local logger = require("common.lib.logger")
local StageLoader = require("client.src.mods.StageLoader")
local ModController = require("client.src.mods.ModController")
local consts = require("common.engine.consts")
local tableUtils = require("common.lib.tableUtils")
local GameModes = require("common.data.GameModes")
local ChallengeModePlayer = require("client.src.ChallengeModePlayer")
local Player = require("client.src.Player")
local Signal = require("common.lib.signal")
local CharacterLoader = require("client.src.mods.CharacterLoader")
local ReplayV3 = require("common.data.ReplayV3")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local Telegraph = require("client.src.graphics.Telegraph")
local MatchParticipant = require("client.src.MatchParticipant")
local ChallengeModePlayerStack = require("client.src.ChallengeModePlayerStack")
local NetworkProtocol = require("common.network.NetworkProtocol")
local DebugSettings = require("client.src.debug.DebugSettings")
---@module "client.src.ChallengeModePlayerStack"

---@class ClientMatch
---@field players (Player|ChallengeModePlayer)[]
---@field stacks (PlayerStack|ChallengeModePlayerStack)[]
---@field engine Match
---@field matchRules MatchRules
---@field replay ReplayV3
---@field doCountdown boolean 
---@field stackInteraction StackInteractions how the stacks in the match interact with each other
---@field supportsPause boolean if the game can be paused
---@field isPaused boolean if the game is currently paused
---@field renderDuringPause boolean if the game should be rendered while paused
---@field currentMusicIsDanger boolean
---@field ranked boolean? if the match counts towards an online ranking
---@field online boolean? if the players in the match are remote
---@field spectators string[] list of spectators in an online game
---@field spectatorString string newLine concatenated version of spectators for display
---@field winners MatchParticipant[]
---@field panelSource PanelSource
---@field gameMode GameMode

--- The ClientMatch is a way to create a match that will run with graphics and sounds on a client.
---@class ClientMatch : Signal
---@overload fun(players: MatchParticipant[], ranked: boolean): ClientMatch
local ClientMatch = class(
function(self, players, ranked)
  assert(players)
  self.players = players
  self.ranked = ranked

  self.supportsPause = false
  self.isPaused = false
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

---@param battleRoom BattleRoom
function ClientMatch.createFromBattleRoom(battleRoom)
  local clientMatch = ClientMatch.createFromGameMode(battleRoom.players, battleRoom.mode, battleRoom:createPanelSource(), battleRoom.ranked, battleRoom.preferredStageId)

  clientMatch.supportsPause = not battleRoom.online or (#battleRoom.players == 1 and battleRoom.players[1].isLocal)

  return clientMatch
end

---@param gameMode GameMode
---@return ClientMatch
function ClientMatch.createFromGameMode(players, gameMode, panelSource, ranked, stageId)
  local clientMatch = ClientMatch(players, ranked)
  clientMatch:setStage(stageId)
  clientMatch.gameMode = gameMode
  clientMatch.stackInteraction = gameMode.stackInteraction
  clientMatch.matchRules = gameMode.matchRules
  clientMatch.panelSource = panelSource
  clientMatch.supportsPause = #players == 1 and players[1].isLocal

  clientMatch:setupFromGameMode()

  return clientMatch
end

---@param replay ReplayV3
---@param players MatchParticipant[]?
---@return ClientMatch
function ClientMatch.createFromReplay(replay, players)
  local engine = Match.createFromReplay(replay)

  -- we only need to reconstruct the players from the metadata
  -- unless we already got them passed in
  players = players or {}

  for _, stackMetadata in ipairs(replay.metadata.stacks) do
    local stackData = replay.stacks[stackMetadata.stackIndex]

    if not players[stackMetadata.stackIndex] then
      if stackData.stackType == 1 then
        ---@cast stackMetadata StackMetadata
        players[stackMetadata.stackIndex] = Player.createFromReplayMetadata(stackMetadata)
      elseif stackData.stackType == 2 then
        ---@cast stackMetadata SimulatedStackMetadata
        players[stackMetadata.stackIndex] = ChallengeModePlayer.createFromReplayMetadata(stackMetadata)
      end
    end
  end

  ---@type ClientMatch
  ---@diagnostic disable-next-line: param-type-mismatch
  local clientMatch = ClientMatch(players, replay.metadata.ranked)
  clientMatch.replay = replay
  clientMatch.engine = engine
  clientMatch.supportsPause = #players == 1 and players[1].isLocal
  clientMatch.stacks = {}
  clientMatch.spectators = {}
  clientMatch.spectatorString = ""

  clientMatch:setStage(replay.metadata.stageId)

  clientMatch.players = players

  -- and assign their stacks from the engine
  for i, player in ipairs(clientMatch.players) do
    local clientStack = player:createClientStack(clientMatch.engine.stacks[i])
    if replay.metadata.completed then
      -- watching a finished replay
      clientStack:setMaxRunsPerFrame(1)
    elseif not clientMatch:hasLocalPlayer() and player.human then
      ---@cast clientStack PlayerStack
      clientStack:enableCatchup(true)
    end
    clientMatch.stacks[i] = clientStack
  end

  clientMatch:sharedSetup()

  return clientMatch
end

function ClientMatch:setupFromGameMode()
  self.engine = Match(self.panelSource, self.matchRules)

  self.stacks = {}

  for i, player in ipairs(self.players) do
    local engineStack
    local clientStack
    if player.human then
      engineStack = self.engine:createStackWithSettings(player.settings.levelData, player.isLocal, player.settings.inputMethod)
    else
      ---@cast player ChallengeModePlayer
      engineStack = self.engine:createSimulatedStackWithSettings(player.settings.attackEngineSettings, player.settings.healthSettings)
    end

    clientStack = player:createClientStack(engineStack)
    self.stacks[i] = clientStack
  end

  if self.stackInteraction == GameModes.StackInteractions.ATTACK_ENGINE then
    for _, player in ipairs(self.players) do
      local engineStack = self.engine:createSimulatedStackWithSettings(player.settings.attackEngineSettings)
      local attackEngineHost = ChallengeModePlayerStack({
        engine = engineStack,
        is_local = not (self.replay and self.replay.metadata.completed),
        characterId = CharacterLoader.fullyResolveCharacterSelection(),
        attackSettings = player.settings.attackEngineSettings,
        match = self,
      })
      self.engine:addTarget(engineStack, player.stack.engine)
      self.stacks[#self.stacks+1] = attackEngineHost
    end
  elseif self.stackInteraction == GameModes.StackInteractions.SELF then
    for _, stack in ipairs(self.stacks) do
      self.engine:addTarget(stack.engine, stack.engine)
    end
  elseif self.stackInteraction == GameModes.StackInteractions.VERSUS then
    for i, stack1 in ipairs(self.stacks) do
      for j, stack2 in ipairs(self.stacks) do
        if i ~= j then
          self.engine:addTarget(stack1.engine, stack2.engine)
        end
      end
    end
  end

  self:sharedSetup()

  self.replay = self.engine:createNewReplay()
end


function ClientMatch:sharedSetup()
  self.engine.debug.vsFramesBehind = DebugSettings.getVSFramesBehind()
end

function ClientMatch:run()
  if self.isPaused or self.engine:hasEnded() then
    self:runGameOver()
    return
  end

  for _, stack in ipairs(self.stacks) do
    -- if stack.cpu then
    --   stack.cpu:run(stack)
    -- end
    if stack.is_local and stack.send_controls and not stack:game_ended() --[[and not stack.cpu]] then
      ---@cast stack PlayerStack
      stack:send_controls()
    end
  end

  local runs = math.max(unpack(self.engine:run()))

  if self.panicTickStartTime and self.panicTickStartTime == self.engine.clock then
    self:updateDangerMusic()
  end

  if self.engine.doCountdown and self.engine.clock - runs < countdownEnd and self.engine.clock >= countdownEnd then
    self:emitSignal("countdownEnded")
  elseif not self.engine.doCountdown and self.engine.clock - runs < consts.COUNTDOWN_START and self.engine.clock >= consts.COUNTDOWN_START then
    self:emitSignal("countdownEnded")
  end

  self:playCountdownSfx()
  self:playTimeLimitDepletingSfx()

  if self.engine:hasEnded() then
    self.engine:handleMatchEnd()
    self:handleMatchEnd()
  end
end

function ClientMatch:handleMatchEnd()
  self.ended = true
  -- this prepares everything about the replay except the save location
  self:finalizeReplay()
  -- execute callbacks
  self:emitSignal("matchEnded", self)
end

function ClientMatch:runGameOver()
  for _, stack in ipairs(self.stacks) do
    stack:runGameOver()
  end
end

function ClientMatch:start()
  self:initializeTelegraphRelationships()

  self.engine:start()

  -- outgoing garbage is already correctly directed by Match
  -- but the relationship is indirect between engine stacks to reduce coupling
  -- for rendering telegraph, it helps to explicitly know where garbage is being sent
  -- match already tracks garbage directions as n to n to theoretically support more than 2 players
  -- (there are some other pieces missing still to actually support that)
  -- here on client side we can simply acknowledge that only up to 2 players per match are supported

  self:moveStacks()
  for _, stack in ipairs(self.stacks) do
    stack:connectSignal("dangerMusicChanged", self, self.updateDangerMusic)
  end

  if self.engine.timeLimit then
    self.panicTicksPlayed = {}
    for i = 1, 15 do
      self.panicTicksPlayed[i] = false
    end

    self.panicTickStartTime = (self.engine.timeLimit - 15) * 60
    if self.engine.doCountdown then
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
  for i = 1, #self.stacks do
    self.stacks[i]:deinit()
  end
end

function ClientMatch:moveStacks()
  if self.replay and self.replay.metadata.completed then
    if tableUtils.trueForAll(self.replay.metadata.stacks, function(s) return s.renderIndex end) then
      for _, stackMetadata in ipairs(self.replay.metadata.stacks) do
        self.stacks[stackMetadata.stackIndex]:moveForRenderIndex(stackMetadata.renderIndex)
      end
      return
    end
  end

  -- we want to render the stacks in a particular order so that the local player ends up as P1 (left side)
  -- BUT: we want to keep player indexing consistent over boundaries (client <-> replay <- server) to not mess with replay saving
  -- so we solve the rendering requirement via a shallowcpy and assigning positions directly to the stacks rather than starting reordering shenanigans all across the code base
  local stacks = shallowcpy(self.stacks)
  table.sort(stacks, function(a, b)
    if a.is_local == b.is_local then
      return a.player_number < b.player_number
    else
      return a.is_local
    end
  end)

  for i, stack in ipairs(stacks) do
    stack:moveForRenderIndex(i)
  end
end

function ClientMatch:setStage(stageId)
  logger.debug("Setting match stage id to " .. (stageId or ""))
  if stageId then
    -- we got one from the server
    self.stageId = StageLoader.fullyResolveStageSelection(stageId)
  else
    local player = self.players[math.random(#self.players)]
    self.stageId = StageLoader.resolveBundle(player.settings.selectedStageId)
  end
  ModController:loadModFor(stages[self.stageId], self)
end

function ClientMatch:abort()
  self.engine:abort()
  self:handleMatchEnd()
end

function ClientMatch:getWinningPlayerCharacter()
  local character = characters[consts.RANDOM_CHARACTER_SPECIAL_VALUE]
  local maxWins = -1
  for i = 1, #self.players do
    if self.players[i].wins > maxWins then
      character = self.players[i].stack.character
      maxWins = self.players[i].wins
    end
  end

  return character
end

function ClientMatch:togglePause()
  self.isPaused = not self.isPaused
  self:emitSignal("pauseChanged", self)
end

---@param doCountdown boolean if the match should have a countdown before physics start
function ClientMatch:setCountdown(doCountdown)
  self.engine:setCountdown(doCountdown)
end

function ClientMatch:rewindToFrame(frame)
  self.engine:rewindToFrame(frame)
end

---@return ReplayV3?
function ClientMatch:finalizeReplay()
  local replay
  if not self.replay.metadata.completed then
    replay = self.replay
    replay:setDuration(self.engine.clock)
    replay:setStage(self.stageId)
    replay:setRanked(self.ranked)
    if self.gameMode then
      replay.metadata.gameModeName = self.gameMode.name
    end

    for i, stack in ipairs(self.stacks) do
      local stackIndex = tableUtils.indexOf(self.engine.stacks, stack.engine)
      ---@type BaseStackMetadata
      local metadata = {
        stackIndex = stackIndex,
        renderIndex = stack.renderIndex,
        characterId = stack.character.id,
        panelId = stack.panels_dir,
      }

      local player = stack.player
      if player then
        metadata.wins = player.wins
        if player.human then
          ---@cast metadata StackMetadata
          ---@cast player Player
          metadata.name = player.name
          metadata.publicId = player.publicId
          if stack.level then
            metadata.level = stack.level
          elseif stack.difficulty then
            metadata.difficulty = stack.difficulty
          end
          metadata.analytics = player.stack.analytic.data
          ---@diagnostic disable-next-line: inject-field
          metadata.analytics.score = player.stack.engine.score
          ---@diagnostic disable-next-line: inject-field
          metadata.analytics.rating = player.rating
        else
          ---@cast metadata SimulatedStackMetadata
          ---@cast player ChallengeModePlayer
          metadata.challengeModeDifficulty = player.settings.difficulty
          metadata.stageIndex = player.settings.level
        end
      end
      replay.metadata.stacks[i] = metadata
    end

    ReplayV3.finalizeReplay(self.engine, self.replay)
  end

  return replay
end

function ClientMatch:initializeTelegraphRelationships()
  for i, garbageTargets in ipairs(self.engine.garbageTargets) do
    for _, engineStack in ipairs(garbageTargets) do
      local index = tableUtils.indexOf(self.engine.stacks, engineStack)
      self.stacks[i]:setGarbageTarget(self.stacks[index])
    end
  end

  for recipientStack, garbageSources in pairs(self.engine.garbageSources) do
    local recipientIndex = tableUtils.indexOf(self.engine.stacks, recipientStack)
    for _, engineStack in ipairs(garbageSources) do
      local index = tableUtils.indexOf(self.engine.stacks, engineStack)
      self.stacks[recipientIndex]:setGarbageSource(self.stacks[index])
    end
  end
end

function ClientMatch:playCountdownSfx()
  if self.engine.doCountdown then
    if self.engine.clock < 200 then
      if (self.engine.clock - consts.COUNTDOWN_START) % 60 == 0 then
        if self.engine.clock == countdownEnd then
          SoundController:playSfx(themes[config.theme].sounds.go)
        else
          SoundController:playSfx(themes[config.theme].sounds.countdown)
        end
      end
    end
  end
end

function ClientMatch:playTimeLimitDepletingSfx()
  if self.engine.timeLimit then
    -- have to account for countdown
    if self.engine.clock >= self.panicTickStartTime then
      local tickIndex = math.ceil((self.engine.clock - self.panicTickStartTime) / 60)
      if self.panicTicksPlayed[tickIndex] == false then
        SoundController:playSfx(themes[config.theme].sounds.countdown)
        self.panicTicksPlayed[tickIndex] = true
      end
    end
  end
end

local function inDanger(stack)
  return stack.danger_music
end
function ClientMatch:updateDangerMusic()
  local dangerMusic
  if self.panicTickStartTime == nil then
    dangerMusic = tableUtils.trueForAny(self.stacks, inDanger)
  else
    if self.engine.clock < self.panicTickStartTime then
      dangerMusic = false
    else
      dangerMusic = true
    end
  end

  if dangerMusic ~= self.currentMusicIsDanger then
    self:emitSignal("dangerMusicChanged", dangerMusic)
    self.currentMusicIsDanger = dangerMusic
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
  local frames = 0
  local stack = self.stacks[1]
  if stack ~= nil and stack.engine.game_stopwatch ~= nil and tonumber(stack.engine.game_stopwatch) ~= nil then
    frames = stack.engine.game_stopwatch
  end

  if self.engine.timeLimit then
    frames = (self.engine.timeLimit) - frames
    if frames < 0 then
      frames = 0
    end
  end

  local timeString = frames_to_time_string(frames, self.engine.ended)

  self:drawMatchLabel(themes[config.theme].images.IMG_time, themes[config.theme].timeLabel_Pos, themes[config.theme].timeLabel_Scale)
  self:drawMatchTime(timeString, themes[config.theme].time_Pos, themes[config.theme].time_Scale)
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
  if not DebugSettings.showStackDebugInfo() then
    GraphicsUtil.printf(join_community_msg or "", 0, 668, consts.CANVAS_WIDTH, "center")
  end
end

local function isRollbackActive(stack)
  return stack.engine.framesBehind > GARBAGE_DELAY_LAND_TIME
end

function ClientMatch:render()
  if config.show_fps and #self.stacks > 1 then
    local drawY = 23
    for i = 1, #self.stacks do
      local stack = self.stacks[i]
      GraphicsUtil.print("P" .. stack.renderIndex .." Average Latency: " .. stack.engine.framesBehind, 1, drawY)
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

  if DebugSettings.showStackDebugInfo() then
    local padding = 14
    local drawX = 500
    local drawY = -4

    -- drawY = drawY + padding
    -- GraphicsUtil.printf("Time Spent Running " .. self.timeSpentRunning * 1000, drawX, drawY)

    -- drawY = drawY + padding
    -- local totalTime = love.timer.getTime() - self.createTime
    -- GraphicsUtil.printf("Total Time " .. totalTime * 1000, drawX, drawY)

    drawY = drawY + padding
    local totalTime = love.timer.getTime() - self.engine.createTime
    local timePercent = math.round(self.engine.timeSpentRunning / totalTime, 5)
    GraphicsUtil.printf("Time Percent Running Match: " .. timePercent, drawX, drawY)

    drawY = drawY + padding
    local maxTime = math.round(self.engine.maxTimeSpentRunning, 5)
    GraphicsUtil.printf("Max Stack Update: " .. maxTime, drawX, drawY)

    if self.engine.gameOverClock and self.engine.gameOverClock > 0 then
      drawY = drawY + padding
      GraphicsUtil.printf("gameOverClock " .. self.engine.gameOverClock, drawX, drawY)
    end
  end

  if not self.isPaused or self.renderDuringPause then
    for _, stack in ipairs(self.stacks) do
      -- don't render stacks that only have an attack engine
      if stack.player or stack.engine.healthEngine then
        stack:render(self.engine.ended)
      end

      if stack.garbageTarget then
        Telegraph:render(stack, stack.garbageTarget)
      end
    end

    -- Draw VS HUD
    if self.stackInteraction == GameModes.StackInteractions.VERSUS or self.replay.metadata.gameModeName == "VS" then
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
  if not self.winners and self.engine:hasEnded() then
    local winningStacks = self.engine:getWinners()
    local winners = {}
    for _, stack in ipairs(winningStacks) do
      for _, player in ipairs(self.players) do
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

---@param prefix "I" | "U"
---@param input string
function ClientMatch:receiveInput(prefix, input)
  if self:hasLocalPlayer() then
    if self.players[1].human and self.players[1].isLocal then
      ---@diagnostic disable-next-line: param-type-mismatch
      self.stacks[2]:receiveConfirmedInput(input)
    elseif self.players[2].human and self.players[2].isLocal then
      ---@diagnostic disable-next-line: param-type-mismatch
      self.stacks[1]:receiveConfirmedInput(input)
    end
  else
    if prefix == NetworkProtocol.serverMessageTypes.opponentInput.prefix then
      ---@diagnostic disable-next-line: param-type-mismatch
      self.stacks[2]:receiveConfirmedInput(input)
    else
      ---@diagnostic disable-next-line: param-type-mismatch
      self.stacks[1]:receiveConfirmedInput(input)
    end
  end
end

return ClientMatch