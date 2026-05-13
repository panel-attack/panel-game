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

-- Lua 5.1 / LuaJIT has `unpack` as a global; 5.2+ moved it to `table.unpack`.
-- LÖVE 11.x runs on LuaJIT so call sites using `table.unpack` crash here.
local unpack = table.unpack or unpack
local MatchParticipant = require("client.src.MatchParticipant")
local ChallengeModePlayerStack = require("client.src.ChallengeModePlayerStack")
local NetworkProtocol = require("common.network.NetworkProtocol")
local DebugSettings = require("client.src.debug.DebugSettings")
local TeamUtils = require("common.data.TeamUtils")
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
---@param gameMode GameMode? optional — when provided, restores team setup on the engine for online play
---@return ClientMatch
function ClientMatch.createFromReplay(replay, players, gameMode)
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

  -- Resolve gameMode from the replay metadata when the caller didn't pass one
  -- (saved-replay viewing via ReplayBrowser, etc). This way every match constructed
  -- via createFromReplay gets the correct end-condition / team behavior automatically.
  if not gameMode and replay.metadata and replay.metadata.gameModeName then
    local modeId = GameModes.nameToGameModeId[replay.metadata.gameModeName]
    if modeId then
      gameMode = GameModes.getPreset(modeId)
    end
  end

  -- Restore team configuration on the engine. Without this, Match:hasEnded skips
  -- the TEAMS_ACTIVE check (it requires self.teams) and a team match never ends
  -- until literally every stack dies — even the surviving team. Garbage targets
  -- are already populated above from replay.garbageFlows; we just need teams +
  -- garbageMode for hasEnded and shared-mode distribution to work.
  if gameMode then
    clientMatch.gameMode = gameMode
    clientMatch.stackInteraction = gameMode.stackInteraction
    clientMatch.matchRules = gameMode.matchRules
    if gameMode.stackInteraction == GameModes.StackInteractions.TEAM_VERSUS
        and gameMode.teamCount and gameMode.playersPerTeam then
      local teams = TeamUtils.createTeams(#players, gameMode.teamCount, gameMode.playersPerTeam)
      clientMatch.engine:setTeams(teams)
      if gameMode.garbageMode then
        clientMatch.engine:setGarbageMode(gameMode.garbageMode)
      end
      clientMatch.engine:setupTeamGarbageTargets()
    end
  end

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

  -- Loose-sync catch-up: when a spectator / mid-match joiner receives a
  -- partial replay, the inputs cover the historical sim but garbage and
  -- death deliveries were driven by G/D events at runtime — not derivable
  -- from inputs alone. Queue them up here so ClientMatch:run can replay
  -- them at the right sender frames as catch-up progresses.
  --
  -- Skip for completed replays: those play back offline (looseSyncActive
  -- false), so deliverOutgoingGarbage / pushGarbageTo direct-push from the
  -- sim. Applying events on top would double-deliver.
  if not replay.metadata.completed and replay.crossPlayerEvents then
    clientMatch.pendingHistoricalGarbage = {}
    for i, ev in ipairs(replay.crossPlayerEvents.garbage or {}) do
      clientMatch.pendingHistoricalGarbage[i] = ev
    end
    clientMatch.pendingHistoricalDeaths = {}
    for i, ev in ipairs(replay.crossPlayerEvents.deaths or {}) do
      clientMatch.pendingHistoricalDeaths[i] = ev
    end
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
  elseif self.stackInteraction == GameModes.StackInteractions.TEAM_VERSUS then
    local gm = self.gameMode
    local teams = TeamUtils.createTeams(#self.players, gm.teamCount, gm.playersPerTeam)
    self.engine:setTeams(teams)
    self.engine:setGarbageMode(gm.garbageMode)
    self.engine:setupTeamGarbageTargets()
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

  -- Drain any queued historical G/D events that the sim has now caught up
  -- to. Deaths run first so the sender's stack stops at game_over_clock
  -- before this tick advances it further; garbage second so it lands while
  -- the recipient's stack is still healthy enough to receive it.
  self:drainPendingHistoricalEvents()

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

  -- Keep shared-mode telegraph targets aligned with the next living recipient
  -- selected by the engine's round-robin cursor.
  self:refreshSharedModeTelegraphTargets()

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

  -- drain visuals and confirm elimination for stacks that died mid-match
  for _, stack in ipairs(self.stacks) do
    if stack:game_ended() then
      stack:runGameOver(self.engine.clock)
    end
  end

  if self.engine:hasEnded() then
    self.engine:handleMatchEnd()
    self:handleMatchEnd()
  end
end

---Drain historical G/D events whose senderFrame has been reached by the
---corresponding sender stack. Called once per ClientMatch:run tick so events
---land at approximately the same point in the sim as they did live.
---No-op when there is no queue (most matches).
---
---An event is "ready" when the sender stack's stopWatch has reached the
---event's senderFrame, OR the sender's stack is already game-over (any
---remaining events for that sender can't sensibly wait any longer).
function ClientMatch:drainPendingHistoricalEvents()
  local function isReady(ev)
    local senderStack = self.engine and self.engine.stacks[ev.sender]
    if not senderStack then return true end -- nowhere to defer to; just apply
    local frame = ev.senderFrame or 0
    if (senderStack.stopWatch or 0) >= frame then return true end
    if senderStack.game_over_clock and senderStack.game_over_clock > 0 then return true end
    return false
  end

  local deaths = self.pendingHistoricalDeaths
  if deaths and #deaths > 0 then
    local kept = {}
    for _, ev in ipairs(deaths) do
      if isReady(ev) then
        local stack = self.stacks[ev.sender]
        if stack and stack.engine and not stack.is_local then
          self:_applyDeathEventNow(ev, stack)
        end
      else
        kept[#kept + 1] = ev
      end
    end
    self.pendingHistoricalDeaths = kept
  end

  local garbage = self.pendingHistoricalGarbage
  if garbage and #garbage > 0 then
    local kept = {}
    for _, ev in ipairs(garbage) do
      if isReady(ev) then
        self:_applyGarbageEventNow(ev)
      else
        kept[#kept + 1] = ev
      end
    end
    self.pendingHistoricalGarbage = kept
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
    stack:runGameOver(self.engine.clock)
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

  self.spectatorFocus = nil
  self:moveStacks()
  for _, stack in ipairs(self.stacks) do
    stack:connectSignal("dangerMusicChanged", self, self.updateDangerMusic)
  end

  if self.engine.timeLimit then
    self.panicTicksPlayed = {}
    for i = 1, 15 do
      self.panicTicksPlayed[i] = false
    end

    self.panicTickStartTime = self.engine.timeLimit - 15 * 60
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

-- True when the match has at least one local player AND every local player's
-- stack has been eliminated (game_over_clock set). Used by the game scene to
-- offer a "back to waiting room" exit while teammates fight on.
---@return boolean
function ClientMatch:isLocalPlayerEliminated()
  local sawLocal = false
  for _, stack in ipairs(self.stacks) do
    if stack.is_local then
      sawLocal = true
      if not stack.engine or stack.engine.game_over_clock <= 0 then
        return false
      end
    end
  end
  return sawLocal
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
        if #self.stacks == 3 then
          self.stacks[stackMetadata.stackIndex]:moveForRenderIndex3Player(stackMetadata.renderIndex)
        elseif #self.stacks == 4 then
          self.stacks[stackMetadata.stackIndex]:moveForRenderIndex4PlayerHorizontal(stackMetadata.renderIndex)
        elseif #self.stacks == 5 then
          self.stacks[stackMetadata.stackIndex]:moveForRenderIndex5Player(stackMetadata.renderIndex)
        elseif #self.stacks == 6 then
          self.stacks[stackMetadata.stackIndex]:moveForRenderIndex6Player(stackMetadata.renderIndex)
        elseif #self.stacks == 7 then
          self.stacks[stackMetadata.stackIndex]:moveForRenderIndex7Player(stackMetadata.renderIndex)
        else
          self.stacks[stackMetadata.stackIndex]:moveForRenderIndex(stackMetadata.renderIndex)
        end
      end
      return
    end
  end

  -- we want to render the stacks in a particular order so that the local player ends up as P1 (left side)
  -- BUT: we want to keep player indexing consistent over boundaries (client <-> replay <- server) to not mess with replay saving
  -- so we solve the rendering requirement via a shallowcpy and assigning positions directly to the stacks rather than starting reordering shenanigans all across the code base
  --
  -- Spectator-focus override: when the viewer is spectating (pure spectator or a
  -- dead local player using the spectator UI), pressing left/right shouldn't
  -- just outline a different stack — it should rotate the focused stack into
  -- the big-left container so we're actually watching that player. The small
  -- containers stay in place; only which-player-renders-where changes.
  local stacks = shallowcpy(self.stacks)
  local focus = self.spectatorFocus
  table.sort(stacks, function(a, b)
    if focus then
      local aFocused = a.player_number == focus
      local bFocused = b.player_number == focus
      if aFocused ~= bFocused then
        return aFocused
      end
    end
    if a.is_local == b.is_local then
      return a.player_number < b.player_number
    else
      return a.is_local
    end
  end)

  for i, stack in ipairs(stacks) do
    if #self.stacks == 3 then
      stack:moveForRenderIndex3Player(i)
    elseif #self.stacks == 4 then
      stack:moveForRenderIndex4PlayerHorizontal(i)
    elseif #self.stacks == 5 then
      stack:moveForRenderIndex5Player(i)
    elseif #self.stacks == 6 then
      stack:moveForRenderIndex6Player(i)
    elseif #self.stacks == 7 then
      stack:moveForRenderIndex7Player(i)
    else
      stack:moveForRenderIndex(i)
    end
  end
end

-- Cycles spectator focus forward (direction=1) or backward (direction=-1) through live stacks.
-- The focused stack moves into the big-left render position via moveStacks;
-- containers stay where they are, only the players inside them swap.
function ClientMatch:cycleSpectatorFocus(direction)
  local live = {}
  for _, stack in ipairs(self.stacks) do
    if stack.canvas then
      live[#live + 1] = stack.player_number
    end
  end
  table.sort(live)
  if #live == 0 then return end
  if not self.spectatorFocus then
    self.spectatorFocus = live[direction > 0 and 1 or #live]
  else
    local idx = 1
    for i, pn in ipairs(live) do
      if pn == self.spectatorFocus then idx = i break end
    end
    idx = ((idx - 1 + direction) % #live) + 1
    self.spectatorFocus = live[idx]
  end
  -- Restamp positions so the newly focused stack lands in renderIndex 1
  -- (big-left); other stacks shift into the small containers around it.
  self:moveStacks()
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
  if not self.supportsPause then
    error("Tried to pause a non-pausable match")
  end
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
  -- Build a target LIST per stack so N-player FFA/team modes render a Telegraph
  -- to every enemy. The legacy 1v1 code path used setGarbageTarget (singular),
  -- which silently overwrote when called more than once — keeping only the last
  -- enemy. The render loop below iterates stack.garbageTargets so all enemies
  -- get the flying-icon animation.
  --
  -- Shared (round-robin) mode caveat: the engine's garbageTargets list contains
  -- every enemy because the round-robin pick happens at delivery time, not at
  -- setup. If we rendered to all of them we'd visually show every enemy taking
  -- a hit while only one actually receives. For shared mode, restrict the
  -- client list to a single target (the first enemy — matches the round-robin
  -- counter's initial position). For "all" mode and 1v1, take every target.
  local garbageMode = (self.gameMode and self.gameMode.garbageMode)
    or (self.engine and self.engine.garbageMode)
  local sharedMode = garbageMode == "shared"
  for i, engineTargets in ipairs(self.engine.garbageTargets) do
    local clientStack = self.stacks[i]
    if clientStack then
      local clientTargets = {}
      for _, engineStack in ipairs(engineTargets) do
        local index = tableUtils.indexOf(self.engine.stacks, engineStack)
        if self.stacks[index] then
          clientTargets[#clientTargets + 1] = self.stacks[index]
          if sharedMode and #engineTargets > 1 then
            break
          end
        end
      end
      clientStack:setGarbageTargets(clientTargets)
    end
  end

  for recipientStack, garbageSources in pairs(self.engine.garbageSources) do
    local recipientIndex = tableUtils.indexOf(self.engine.stacks, recipientStack)
    for _, engineStack in ipairs(garbageSources) do
      local index = tableUtils.indexOf(self.engine.stacks, engineStack)
      self.stacks[recipientIndex]:setGarbageSource(self.stacks[index])
    end
  end

  self:refreshSharedModeTelegraphTargets()
end

function ClientMatch:refreshSharedModeTelegraphTargets()
  if not self.engine then
    return
  end

  local garbageMode = (self.gameMode and self.gameMode.garbageMode)
    or (self.engine and self.engine.garbageMode)
  if garbageMode ~= "shared" then
    return
  end

  local teamStateBySender = self.engine.teamGarbageState
  if not teamStateBySender then
    return
  end

  for senderIndex, engineTargets in ipairs(self.engine.garbageTargets) do
    if #engineTargets > 1 then
      local teamState = teamStateBySender[senderIndex]
      if teamState and teamState.enemyIndices and #teamState.enemyIndices > 0 then
        local startIndex = teamState.currentTargetIndex or 1
        local chosenRecipientIndex = nil
        local i = startIndex

        for _ = 1, #teamState.enemyIndices do
          local recipientIndex = teamState.enemyIndices[i]
          local recipientStack = self.engine.stacks[recipientIndex]
          if recipientStack and not recipientStack:game_ended() then
            chosenRecipientIndex = recipientIndex
            break
          end
          i = (i % #teamState.enemyIndices) + 1
        end

        local senderClientStack = self.stacks[senderIndex]
        if senderClientStack then
          if chosenRecipientIndex and self.stacks[chosenRecipientIndex] then
            senderClientStack:setGarbageTargets({ self.stacks[chosenRecipientIndex] })
          else
            senderClientStack:setGarbageTargets({})
          end
        end
      end
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
  if stack ~= nil and stack.engine.stopWatch ~= nil and tonumber(stack.engine.stopWatch) ~= nil then
    frames = stack.engine.stopWatch
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

local function getTeamIndexForPlayerPosition(gameMode, playerPosition)
  if not gameMode or not gameMode.playersPerTeam then
    return nil
  end

  local playersPerTeam = gameMode.playersPerTeam
  if type(playersPerTeam) == "number" then
    return math.floor((playerPosition - 1) / playersPerTeam) + 1
  elseif type(playersPerTeam) == "table" then
    local cumulative = 0
    for idx, count in ipairs(playersPerTeam) do
      if playerPosition <= cumulative + count then
        return idx
      end
      cumulative = cumulative + count
    end
  end

  return nil
end

local teamColors = {
  {1,    0.55, 0.75, 1},  -- pink   (team 1)
  {0.65, 0.4,  0.95, 1},  -- purple (team 2)
  {0.45, 1,    0.45, 1},  -- green
  {1,    1,    0.45, 1},  -- yellow
  {1,    0.6,  0.2,  1},  -- orange
  {0.45, 0.7,  1,    1},  -- blue
  {0.45, 1,    1,    1},  -- cyan
  {1,    0.45, 0.45, 1},  -- red
}

---@param text string
---@param maxWidth number
---@param font love.Font
---@return string
local function clampTextToWidth(text, maxWidth, font)
  if font:getWidth(text) <= maxWidth then
    return text
  end

  local ellipsis = "..."
  local result = text
  while #result > 0 and font:getWidth(result .. ellipsis) > maxWidth do
    result = result:sub(1, #result - 1)
  end

  if result == "" then
    return ellipsis
  end

  return result .. ellipsis
end

function ClientMatch:drawTeamScoreboard()
  if self.stackInteraction ~= GameModes.StackInteractions.TEAM_VERSUS then
    return
  end

  local canvasWidth = GAME.globalCanvas:getWidth()
  local teamWins = GAME.battleRoom and GAME.battleRoom.teamWins

  -- Shared 2-team banner header (pink/purple). Returns silently for FFA / non-team modes.
  local TeamBannerHeader = require("client.src.graphics.TeamBannerHeader")
  TeamBannerHeader.draw(self.gameMode, self.players, teamWins, canvasWidth)
  TeamBannerHeader.drawGarbageModeBelowBanner(self.gameMode, canvasWidth, "match")

  -- For >2 teams, fall through to the legacy section-row layout below.
  local teamCount = self.gameMode.teamCount or 2
  if teamCount == 2 then return end

  local teamData = {}
  for i, player in ipairs(self.players) do
    local teamIndex = getTeamIndexForPlayerPosition(self.gameMode, i) or i
    if not teamData[teamIndex] then
      teamData[teamIndex] = {names = {}, wins = 0}
    end
    teamData[teamIndex].names[#teamData[teamIndex].names + 1] = player.name or ("P" .. i)
    if teamWins and teamWins[teamIndex] then
      teamData[teamIndex].wins = teamWins[teamIndex]
    else
      teamData[teamIndex].wins = math.max(teamData[teamIndex].wins, player:getWinCountForDisplay())
    end
  end

  local topY = (#self.stacks >= 4) and 4 or 8
  local font = GraphicsUtil.getGlobalFont()

  do
    local sectionWidth = canvasWidth / teamCount
    for t = 1, teamCount do
      local data = teamData[t]
      if data then
        GraphicsUtil.setColor(unpack(teamColors[t] or teamColors[1]))
        local label = table.concat(data.names, "+") .. "  " .. data.wins
        label = clampTextToWidth(label, sectionWidth - 8, font)
        GraphicsUtil.printf(label, (t - 1) * sectionWidth, topY, sectionWidth, "center")
      end
    end
  end

  GraphicsUtil.setColor(1, 1, 1, 1)
end

function ClientMatch:drawStackSeparators()
  if #self.stacks ~= 4 then
    return
  end

  local byRenderIndex = {}
  for _, stack in ipairs(self.stacks) do
    byRenderIndex[stack.renderIndex] = stack
  end

  local s1 = byRenderIndex[1]
  local s2 = byRenderIndex[2]
  local s3 = byRenderIndex[3]
  local s4 = byRenderIndex[4]
  if not (s1 and s2 and s3 and s4) then
    return
  end

  local function leftX(stack) return stack.frameOriginX * stack.gfxScale end
  local function rightX(stack) return leftX(stack) + stack:canvasWidth() end
  local function topY(stack) return stack.frameOriginY * stack.gfxScale end
  local function bottomY(stack) return topY(stack) + stack:canvasHeight() end

  local separatorX = (math.max(rightX(s1), rightX(s3)) + math.min(leftX(s2), leftX(s4))) / 2
  local separatorY = (math.max(bottomY(s1), bottomY(s2)) + math.min(topY(s3), topY(s4))) / 2

  GraphicsUtil.setColor(1, 1, 1, 0.2)
  GraphicsUtil.drawRectangle("fill", separatorX - 1, 0, 2, GAME.globalCanvas:getHeight())
  GraphicsUtil.drawRectangle("fill", 0, separatorY - 1, GAME.globalCanvas:getWidth(), 2)
  GraphicsUtil.setColor(1, 1, 1, 1)
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

      if stack.canvas and not stack:game_ended() then
        if stack.garbageTargets and #stack.garbageTargets > 0 then
          for _, target in ipairs(stack.garbageTargets) do
            Telegraph:render(stack, target)
          end
        elseif stack.garbageTarget then
          Telegraph:render(stack, stack.garbageTarget)
        end
      end
    end

    -- Draw VS HUD
    if self.stackInteraction == GameModes.StackInteractions.VERSUS or self.replay.metadata.gameModeName == "VS" then
      if tableUtils.trueForAll(self.players, MatchParticipant.isHuman) or self.ranked then
        self:drawMatchType()
      end
    end

    self:drawTimer()
    self:drawTeamScoreboard()
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

---@param playerNumber integer 1-based slot number of the sender
---@param input string encoded input string
function ClientMatch:receiveInput(playerNumber, input)
  if playerNumber and self.stacks[playerNumber] then
    ---@diagnostic disable-next-line: param-type-mismatch
    self.stacks[playerNumber]:receiveConfirmedInput(input)
  end
end

---Loose-sync: handle an incoming GarbageEvent from the server.
---
---The server is the single source of truth: it relays G to every player
---including the sender, so the visual on the sender's view of the recipient
---only fires after the server confirms (and possibly redirects) the
---delivery. This function applies the garbage to whichever stack the server
---said is the recipient — local-authoritative for gameplay on the actual
---player's machine, view-stack for visual on everyone else's screens. No
---is_local filter; the server already redirected if needed and the
---sender's machine no longer does a local visual push in
---deliverOutgoingGarbage.
---@param body table parsed event payload: {sender, senderFrame, serverWallClockMs, recipients, garbage}
function ClientMatch:applyGarbageEvent(body)
  if not body or type(body.recipients) ~= "table" or type(body.garbage) ~= "table" then
    logger.warn("applyGarbageEvent: malformed body, dropping")
    return
  end

  -- Defer only when the sender's sim is FAR behind senderFrame (catch-up
  -- for spectators / rejoiners). For an in-sync client the sender's view-
  -- stack lags by network latency only — a handful of frames at most — and
  -- we keep the existing "apply immediately" path so garbage drops feel
  -- responsive. The 60-frame threshold (~1s at 60fps) easily covers normal
  -- network jitter while catching the catch-up case where we're seconds or
  -- minutes behind. See drainPendingHistoricalEvents.
  local senderStack = body.sender and self.engine and self.engine.stacks[body.sender]
  local catchupDeferFrames = 60
  if senderStack and body.senderFrame
      and (senderStack.stopWatch or 0) + catchupDeferFrames < body.senderFrame then
    self.pendingHistoricalGarbage = self.pendingHistoricalGarbage or {}
    self.pendingHistoricalGarbage[#self.pendingHistoricalGarbage + 1] = body
    return
  end

  self:_applyGarbageEventNow(body)
end

---Internal: apply a GarbageEvent without the catch-up defer check.
---Called by applyGarbageEvent (in-sync path) and by drainPendingHistoricalEvents.
---@param body table parsed event payload
function ClientMatch:_applyGarbageEventNow(body)
  for _, recipientIndex in ipairs(body.recipients) do
    local stack = self.stacks[recipientIndex]
    if stack and stack.engine then
      logger.info(string.format(
        "G apply: sender=%s senderFrame=%s -> stack[%d] (is_local=%s) garbageCount=%d",
        tostring(body.sender), tostring(body.senderFrame), recipientIndex,
        tostring(stack.is_local),
        (type(body.garbage) == "table") and #body.garbage or 0))
      -- self.stacks[i] is a ClientStack wrapper; the actual engine stack
      -- (and the receiveGarbage method) lives on stack.engine.
      -- Copy the garbage table per recipient so chain-flag mutations in
      -- correctChainingFlag don't leak between recipients sharing one event.
      local garbageCopy = {}
      for j, g in ipairs(body.garbage) do
        garbageCopy[j] = shallowcpy(g)
      end
      stack.engine:receiveGarbage(garbageCopy)
    end
  end

  -- Self-heal the round-robin cursor: G is the canonical "who got hit"
  -- per delivery (the server even redirects when the original recipient is
  -- dead). distributeGarbageToTargets advances each client's cursor based
  -- on local liveness view, which can briefly diverge at death boundaries
  -- — fine for the bookkeeping, but refreshSharedModeTelegraphTargets uses
  -- the cursor to draw next-target arrows, so the divergence is player-
  -- visible. Re-anchor the cursor to the just-hit recipient's position +
  -- next-living, so every client's telegraph points the same place.
  -- Shared mode only: G in "all" mode carries every recipient at once.
  if body.sender and type(body.recipients) == "table" and #body.recipients == 1 then
    local engine = self.engine
    local teamState = engine and engine.teamGarbageState and engine.teamGarbageState[body.sender]
    if teamState and teamState.enemyIndices then
      local hitRecipient = body.recipients[1]
      local stacks = engine.stacks
      -- Find the hit recipient's position in the enemy list, then advance
      -- the cursor to the next-living after that position. Same predicate
      -- as Match.lua's engine cursor and Room.lua's _redirectIfDead — one
      -- rule, three call sites via TeamUtils.findNextLiving.
      local hitIndex
      for i, slot in ipairs(teamState.enemyIndices) do
        if slot == hitRecipient then
          hitIndex = i
          break
        end
      end
      if hitIndex then
        local _, _, nextLivingIndex = TeamUtils.findNextLiving(
          teamState.enemyIndices, hitIndex,
          function(slot)
            local s = stacks[slot]
            return s and not s:game_ended()
          end
        )
        if nextLivingIndex then
          teamState.currentTargetIndex = nextLivingIndex
        end
      end
    end
  end
end

---Loose-sync: handle an incoming DeathEvent from the server.
---Marks the (remote) sender's stack as game-ended at body.senderFrame.
---Skips local-authoritative stacks — those set their own game_over_clock via
---the engine's natural top-out detection, no override needed.
---@param body table parsed event payload: {sender, senderFrame, serverWallClockMs, reason}
function ClientMatch:applyDeathEvent(body)
  if not body or type(body.sender) ~= "number" or type(body.senderFrame) ~= "number" then
    logger.warn("applyDeathEvent: malformed body, dropping")
    return
  end

  local stack = self.stacks[body.sender]
  if not stack or not stack.engine then
    logger.warn("applyDeathEvent: no stack/engine at slot " .. tostring(body.sender))
    return
  end

  if stack.is_local then
    -- Our own death — we already set game_over_clock when the local sim hit it.
    return
  end

  -- Always set game_over_clock immediately. The previous design deferred
  -- to pendingHistoricalDeaths if the view-stack was >60 frames behind
  -- the sender's death frame ("catch-up defer"). That created a deadlock:
  -- once a sender dies, server/Room.lua:716 stops relaying their inputs,
  -- so the view-stack on every other client is permanently pinned at the
  -- last frame before the death. stopWatch never advances past senderFrame,
  -- drainPendingHistoricalEvents never applies the death, game_over_clock
  -- stays -1, Match.isDone's loose-sync bypass (Match.lua:760, which is
  -- there specifically to cover this case) never fires, the match never
  -- ends. The Amber/Bev/Koozie hung-match was this bug.
  --
  -- For spectator/rejoiner catch-up (the other case the defer existed
  -- to handle), pendingHistoricalDeaths is preloaded at match-create
  -- time from replay.crossPlayerEvents.deaths (ClientMatch:createFromReplay
  -- around line 194-197). That path is untouched; this change only
  -- affects D events arriving live during a running match.
  --
  -- _applyDeathEventNow is idempotent — it no-ops if game_over_clock is
  -- already > 0 — so a deferred death later re-applied via the drain
  -- doesn't double-set.
  self:_applyDeathEventNow(body, stack)
end

---Internal: apply a DeathEvent without the catch-up defer check.
---@param body table parsed event payload
---@param stack ClientStack the recipient client stack (must be non-nil, non-local)
function ClientMatch:_applyDeathEventNow(body, stack)
  -- ClientStack wraps the engine stack; game_over_clock lives on engine.
  local engine = stack.engine
  if engine.game_over_clock <= 0 then
    engine.game_over_clock = body.senderFrame
    logger.info(string.format("DeathEvent applied: stack[%d] game_over_clock=%d (reason=%s)",
      body.sender, body.senderFrame, tostring(body and body.reason)))
  end
end

---Loose-sync: handle a server-authored KOArbitration result.
---Stores the authoritative outcome on the match so the end-of-match UI can
---show "Draw" or the right winner regardless of what the local sim derived.
---Does not force-end the match — if the server's natural outcomeReport path
---is also in flight, it will land on the same result.
---@param body table parsed payload: {winnerSlot, tie, deaths}
function ClientMatch:applyKOArbitration(body)
  if not body then
    logger.warn("applyKOArbitration: nil body, dropping")
    return
  end

  self.koArbitration = {
    winnerSlot = body.winnerSlot,
    tie = body.tie == true,
    deaths = body.deaths,
  }

  logger.info(string.format("KOArbitration applied: winnerSlot=%s tie=%s deaths=%d",
    tostring(body.winnerSlot), tostring(body.tie),
    body.deaths and #body.deaths or 0))
end

return ClientMatch