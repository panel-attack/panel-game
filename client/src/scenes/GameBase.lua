local class = require("common.lib.class")
local Scene = require("client.src.scenes.Scene")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local logger = require("common.lib.logger")
local analytics = require("client.src.analytics")
local input = require("client.src.inputManager")
local tableUtils = require("common.lib.tableUtils")
local consts = require("common.engine.consts")
local StageLoader = require("client.src.mods.StageLoader")
local ModController = require("client.src.mods.ModController")
local SoundController = require("client.src.music.SoundController")
local UpdatingImage = require("client.src.graphics.UpdatingImage")
local prof = require("common.lib.zoneProfiler")
local ui = require("client.src.ui")
local FileUtils = require("client.src.FileUtils")
local ClientStack = require("client.src.ClientStack")
local MatchRules = require("common.data.MatchRules")
local GameModes = require("common.data.GameModes")
local DebugSettings = require("client.src.debug.DebugSettings")
local TeamUtils = require("common.data.TeamUtils")
local socket = require("common.lib.socket")

-- Grace period after a local player dies before the spectator controls
-- (cycle hint, focused-stack border, "Viewing: <name>" label, arrow-key
-- focus cycling) become available. Without this, the UI floods in at the
-- exact moment of death, which players read as "the game broke" rather
-- than "I died and can now watch teammates".
local DEAD_LOCAL_GRACE_SECONDS = 3

-- Chip-background uses the canonical palette with translucency (alpha 0.85).
local CHIP_ALPHA = 0.85

local function teamColorForStack(match, stack, stackIndex)
  local player = match.players and match.players[stackIndex]
  return TeamUtils.teamColorForPlayer(match, player, stackIndex, CHIP_ALPHA)
end

local isSharedTeamMode = TeamUtils.isSharedTeamMode
local isFFA = TeamUtils.isFFA

-- Scene template for running any type of game instance (endless, vs-self, replays, etc.)
---@class GameBase : Scene
---@field saveReplay boolean
---@field text string
---@field pauseState table
---@field minDisplayTime number
---@field maxDisplayTime number
---@field gameOverStartTime number?
---@field fadeOutMusicOnGameOver boolean
---@field frameInfo table
---@field droppedFrameCount integer
---@field match ClientMatch
---@field customDraw fun()?
---@field stage Stage
---@field stageTrack StageTrack?
local GameBase = class(
---@param self GameBase
  function (self, sceneParams)
    self.saveReplay = true

    -- set in load
    self.text = nil
    self.keepMusic = false
    self.pauseState = {
      musicWasPlaying = false
    }

    self.minDisplayTime = 1 -- the minimum amount of seconds the game over screen will be displayed for
    self.maxDisplayTime = -1 -- the maximum amount of seconds the game over screen will be displayed for, -1 means no max time
    self.gameOverStartTime = nil -- timestamp for when game over screen was first displayed
    self.fadeOutMusicOnGameOver = true

    self.frameInfo = {
      frameCount = nil,
      startTime = nil,
      currentTime = nil,
      expectedFrameCount = nil
    }
    self.droppedFrameCount = 0

    self.match = sceneParams.match
  end,
  Scene
)

GameBase.name = "GameBase"

-- begin abstract functions

-- Game mode specific game state setup
-- Called during load()
function GameBase:customLoad() end

-- Game mode specific behavior for leaving the game
-- called during runGame()
function GameBase:abortGame() end

-- Game mode specific behavior for running the game
-- called during runGame()
function GameBase:customRun() end

-- Game mode specific state setup for a game over
-- called during setupGameOver()
function GameBase:customGameOverSetup() end

-- end abstract functions

local teamLetter = TeamUtils.teamLetter

local function joinPlayerNames(players)
  local names = {}
  for _, player in ipairs(players) do
    names[#names + 1] = player.name
  end
  return table.concat(names, ", ")
end

-- Match a winner (Player / PlayerStack wrapper / engine Stack — different
-- call paths produce different shapes) to the corresponding Player.
local function winnerToPlayer(winner, players)
  for _, p in ipairs(players) do
    if winner == p then return p end
    if winner.player and winner.player == p then return p end
    if winner.engine and p.stack and p.stack.engine == winner.engine then return p end
    if p.stack and p.stack == winner then return p end
    if p.stack and p.stack.engine == winner then return p end
    if winner.which and p.playerNumber and winner.which == p.playerNumber then return p end
  end
  return nil
end

function GameBase.buildTeamResultText(match, winners)
  local gameMode = match.gameMode
  if not gameMode or gameMode.stackInteraction ~= GameModes.StackInteractions.TEAM_VERSUS then
    return nil
  end

  local localTeam = nil
  for index, player in ipairs(match.players) do
    if player.isLocal then
      localTeam = TeamUtils.teamIndexForPlayer(match, player, index)
      break
    end
  end

  local winnerTeamIndex = nil

  -- Server is authoritative for online matches. Its arbitration considers
  -- a simultaneous-KO across all teams (everyone dead in the same window)
  -- as a draw — something the engine's local getWinners heuristic ("highest
  -- game_over_clock") can't see, so it would otherwise crown the team that
  -- died last. Trust the server's verdict; fall back to engine winners only
  -- when there is no server (offline / replay).
  if match.hasServerOutcome and match:hasServerOutcome() then
    winnerTeamIndex = match:getServerWinnerTeamIndex()
  else
    local winnerTeams = {}
    for _, winner in ipairs(winners) do
      local matched = winnerToPlayer(winner, match.players)
      if matched then
        local teamIndex = TeamUtils.teamIndexForPlayer(match, matched)
        if teamIndex then
          winnerTeams[teamIndex] = true
        end
      end
    end
    local count = 0
    for teamIndex, _ in pairs(winnerTeams) do
      winnerTeamIndex = teamIndex
      count = count + 1
    end
    if count ~= 1 then
      winnerTeamIndex = nil
    end
  end

  if winnerTeamIndex then
    if localTeam then
      return (localTeam == winnerTeamIndex) and "YOUR TEAM WINS" or "YOUR TEAM LOSES"
    end
    -- Spectator without a team allegiance: keep a minimal neutral message.
    return "Team " .. teamLetter(winnerTeamIndex) .. " wins"
  end

  return "DRAW"
end

-- returns "stage" or "character" depending on which should be used according to the config.use_music_from setting
function GameBase:getPreferredMusicSourceType()
  if config.use_music_from == "stage" or config.use_music_from == "characters" then
    return config.use_music_from
  end

  local percent = math.random(1, 4)
  if config.use_music_from == "either" then
    return (percent <= 2 and "stage" or "characters")
  elseif config.use_music_from == "often_stage" then
    return (percent == 1 and "characters" or "stage")
  else
    return (percent == 1 and "stage" or "characters")
  end
end

-- returns the stage or character that is used as the music source
-- returns nil in case none of them has music
function GameBase:pickMusicSource()
  local character = self.match:getWinningPlayerCharacter()
  local stageHasMusic = self.stage.musics and self.stage.musics["normal_music"]
  local characterHasMusic = character and character.musics and character.musics["normal_music"]
  local preferredMusicSourceType = self:getPreferredMusicSourceType()

  if not stageHasMusic and not characterHasMusic then
    -- fallback to default stage music if possible
    if GAME.theme.defaultStage and GAME.theme.defaultStage.hasMusic then
      return GAME.theme.defaultStage
    else
      return nil
    end
  elseif preferredMusicSourceType == "stage" or not characterHasMusic then
    if stageHasMusic then
      return self.stage
    elseif GAME.theme.defaultStage and GAME.theme.defaultStage.hasMusic then
      return GAME.theme.defaultStage
    else
      return nil
    end
  else --if preferredMusicSourceType == "characters" and characterHasMusic then
    return character
  end
end

---@return StageTrack? stageTrack
function GameBase:getStageTrack()
  -- the active track could be a regular Music instead of a StageTrack; checking for changeMusic assures it to be a StageTrack (or having the interface of one)
  if self.keepMusic and SoundController.activeTrack and SoundController.activeTrack.changeMusic and SoundController.activeTrack:isPlaying() then
    return SoundController.activeTrack
  else
    local musicSource = self:pickMusicSource()
    if musicSource then
      return musicSource.stageTrack
    end
  end
end

-- unlike regular asset load, this function connects the used assets to the match so they cannot be unloaded
function GameBase:loadAssets(match)
  for i, stack in ipairs(match.stacks) do
    logger.debug("Force loading character " .. stack.character.id .. " as part of GameBase:load")
    ModController:loadModFor(stack.character, stack, true)
    stack.character:register(match)
  end

  if not match.stageId then
    logger.debug("Match has somehow no stageId at GameBase:load()")
    match.stageId = StageLoader.fullyResolveStageSelection(match.stageId)
  end
  local stage = stages[match.stageId]
  if stage.fullyLoaded then
    logger.debug("Match stage " .. stage.id .. " already fully loaded in GameBase:load()")
    stage:register(match)
  else
    logger.debug("Force loading stage " .. stage.id .. " as part of GameBase:load")
    ModController:loadModFor(stage, match, true)
  end
end

function GameBase:initializeFrameInfo()
  self.frameInfo.startTime = nil
  self.frameInfo.frameCount = 0
  self.droppedFrameCount = 0
end

function GameBase:load()
  self:loadAssets(self.match)
  self.match:connectSignal("matchEnded", self, self.genericOnMatchEnded)
  self.match:connectSignal("dangerMusicChanged", self, self.changeMusic)
  self.match:connectSignal("countdownEnded", self, self.onGameStart)

  self.stage = stages[self.match.stageId]
  self.backgroundImage = UpdatingImage(self.stage.images.background, false, 0, 0, consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT)
  self.stageTrack = self:getStageTrack()

  local pauseMenuItems = {
    ui.MenuItem.createButtonMenuItem("pause_resume", nil, true, function()
      GAME.theme:playValidationSfx()
      self.pauseMenu:setVisibility(false)
      -- Clear focus when pause menu is hidden
      self.uiRoot:setFocus(nil)
      self:_resumeFromScrub()
      self.match:togglePause()
      if self.stageTrack and self.pauseState.musicWasPlaying then
        SoundController:playMusic(self.stageTrack)
      end
      self:initializeFrameInfo()
    end),
    ui.MenuItem.createButtonMenuItem("back", nil, true, function()
      GAME.theme:playCancelSfx()
      if self.match.endScrub then
        self.match:endScrub(nil)
      end
      self.scrubCursor = nil
      self.scrubPauseFrame = nil
      self.match:abort()
      self:startNextScene()
    end),
  }

  self.pauseMenu = ui.Menu({
    x = 0,
    y = 0,
    hAlign = "center",
    vAlign = "center",
    menuItems = pauseMenuItems,
    height = 200
  })
  self.pauseMenu:setVisibility(false)
  self.uiRoot:addChild(self.pauseMenu)

  leftover_time = 1 / 120

  self:initializeFrameInfo()

  self:customLoad()
end

local function playerPressingStart(match)
  for _, player in ipairs(match.players) do
    if player.inputConfiguration and player.inputConfiguration.isDown["Start"] then
      return true
    end
  end
  return false
end

function GameBase:handlePause()
  if not self.match.isPaused then
    if self.match.supportsPause and (playerPressingStart(self.match) or input.allKeys.isDown["escape"] or (not GAME.focused and not self.match.isPaused)) then
      self.match:togglePause()
      self.pauseMenu:setVisibility(true)
      self:_initScrubState()

      if self.stageTrack then
        self.pauseState.musicWasPlaying = self.stageTrack:isPlaying()
        SoundController:pauseMusic()
      end
      GAME.theme:playValidationSfx()
    end
  else
    self:_handleScrubInput()
    -- Only the player who can act on the menu (resume / quit) should focus
    -- it. Specs receive isPaused=true via pauseNotification but have no
    -- agency over pause — focusing the invisible menu let them activate
    -- the resume callback on a non-pausable match, which crashed.
    if self.match.supportsPause
        and (self.pauseMenu.hasFocus == nil or self.pauseMenu.hasFocus == false)
        and playerPressingStart(self.match) == false then
      self.uiRoot:setFocus(self.pauseMenu)
    end
  end
end

local SCRUB_STEP_FRAMES = 30

-- Subclasses opt in by setting `supportsScrub = true` on the class.
GameBase.supportsScrub = false

function GameBase:_canScrub()
  return self.supportsScrub == true
end

function GameBase:_initScrubState()
  if not self:_canScrub() then return end
  local clock = self.match.engine and self.match.engine.clock or 0
  self.scrubPauseFrame = clock
  self.scrubCursor = clock
end

function GameBase:_scrubMinCursor()
  return 0
end

function GameBase:_handleScrubInput()
  if not self.scrubCursor then return end
  local minCursor = self:_scrubMinCursor()
  local maxCursor = self.scrubPauseFrame
  if input:isPressedWithRepeat("MenuLeft") and self.scrubCursor > minCursor then
    self.scrubCursor = math.max(minCursor, self.scrubCursor - SCRUB_STEP_FRAMES)
    self.match:scrubToFrame(self.scrubCursor)
    GAME.theme:playValidationSfx()
  elseif input:isPressedWithRepeat("MenuRight") and self.scrubCursor < maxCursor then
    self.scrubCursor = math.min(maxCursor, self.scrubCursor + SCRUB_STEP_FRAMES)
    self.match:scrubToFrame(self.scrubCursor)
    GAME.theme:playValidationSfx()
  end
end

function GameBase:_resumeFromScrub()
  if not self.scrubCursor then return end
  if self.match.endScrub then
    local commitFrame = (self.scrubCursor < self.scrubPauseFrame) and self.scrubCursor or nil
    self.match:endScrub(commitFrame)
  end
  self.scrubCursor = nil
  self.scrubPauseFrame = nil
end

function GameBase:drawScrubIndicator()
  if not self.match.isPaused or not self.scrubCursor then return end
  local minCursor = self:_scrubMinCursor()
  local atStart = self.scrubCursor <= minCursor
  local atEnd = self.scrubCursor >= self.scrubPauseFrame
  local y = 500
  local w = consts.CANVAS_WIDTH

  -- Disabled side renders gray+translucent (not just dim white) so it reads
  -- as blocked at the boundary instead of merely subtle.
  local activeR, activeG, activeB = 1, 1, 1
  local disabledR, disabledG, disabledB, disabledA = 0.4, 0.4, 0.4, 0.5

  if atStart then
    GraphicsUtil.setColor(disabledR, disabledG, disabledB, disabledA)
  else
    GraphicsUtil.setColor(activeR, activeG, activeB, 1)
  end
  GraphicsUtil.printf("< Rewind", 0, y, w * 0.45, "right")

  GraphicsUtil.setColor(1, 1, 1, 1)
  local function fmt(frame)
    local s = math.max(0, math.floor(frame / 60))
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
  end
  local label = string.format("%s -> %s",
    fmt(self.scrubCursor), fmt(self.scrubPauseFrame))
  GraphicsUtil.printf(label, 0, y, w, "center")

  if atEnd then
    GraphicsUtil.setColor(disabledR, disabledG, disabledB, disabledA)
  else
    GraphicsUtil.setColor(activeR, activeG, activeB, 1)
  end
  GraphicsUtil.printf("Forward >", w * 0.55, y, w * 0.45, "left")

  GraphicsUtil.setColor(1, 1, 1, 1)
end

function GameBase:setupGameOver()
  -- timestamp for when game over screen was first displayed
  self.gameOverStartTime = love.timer.getTime()
  self.minDisplayTime = 1 -- the minimum amount of seconds the game over screen will be displayed for
  self.maxDisplayTime = -1

  if self.fadeOutMusicOnGameOver then
    SoundController:fadeOutActiveTrack(3)
  end

  local winners = self.match:getWinners()
  if self.text == nil then
    if #self.match.players == 1 then
      self.text = loc("pl_gameover")
    elseif isFFA(self.match.gameMode) then
      if self.match:hasLocalPlayer() then
        local localWon = false
        for _, winner in ipairs(winners) do
          if winner.isLocal then
            localWon = true
            break
          end
        end
        if localWon then
          self.text = loc("pl_you_win")
        elseif #winners > 0 then
          self.text = loc("pl_you_lose")
        else
          self.text = loc("ss_draw")
        end
      elseif #winners == 1 then
        self.text = loc("ss_p_wins", winners[1].name)
      else
        self.text = loc("ss_draw")
      end
    elseif self.match.gameMode and self.match.gameMode.stackInteraction == GameModes.StackInteractions.TEAM_VERSUS then
      self.text = GameBase.buildTeamResultText(self.match, winners)
    elseif #winners == 1 then
      self.text = loc("ss_p_wins", winners[1].name)
    else
      self.text = loc("ss_draw")
    end
  end

  self:customGameOverSetup()
end

-- Build the per-frame placement list. Computed fresh each draw so it picks
-- up gameResult populated AFTER setupGameOver runs (the locally-detected
-- match-end fires the game-over screen before the server's payload arrives).
function GameBase:_buildPlacementLines()
  if not self.match or not self.match.players or #self.match.players < 3 then
    return nil
  end
  local rows = {}
  for _, p in ipairs(self.match.players) do
    if p.lastPlacement and p.name then
      rows[#rows + 1] = { placement = p.lastPlacement, name = p.name }
    end
  end
  if #rows == 0 then return nil end
  table.sort(rows, function(a, b) return a.placement < b.placement end)
  local lines = {}
  for _, r in ipairs(rows) do
    lines[#lines + 1] = r.placement .. ". " .. r.name
  end
  return lines
end

function GameBase:runGameOver()
  -- gameOverStartTime is normally set by setupGameOver, which runs from the
  -- matchEnded signal listener (wired in load()). A spectator who joins a
  -- match that's already in its end-of-match window can land here with
  -- match.ended already true but the signal already fired before our listener
  -- attached — i.e. setupGameOver never ran for us. Lazy-initialize the
  -- timing fields so the subtraction below doesn't crash.
  if self.gameOverStartTime == nil then
    self:setupGameOver()
  end
  local displayTime = love.timer.getTime() - self.gameOverStartTime

  self.match:run()

  local minDisplayMet = displayTime >= self.minDisplayTime
  local maxDisplayMet = self.maxDisplayTime ~= -1 and displayTime >= self.maxDisplayTime

  -- Post-death rewind: escape opens the pause/rewind menu in scenes that
  -- opt into scrub. Any other key continues to the next scene. Check both
  -- the raw key (love's love.keypressed) AND the menu-level binding —
  -- different code paths can populate one without the other.
  local escapePressed = input.allKeys.isDown["escape"] or input.isDown["MenuEsc"]
  local keyPressed = self:readyToProceedToNextScene()

  if minDisplayMet and escapePressed and self:_canScrub() then
    logger.info("Post-death escape: entering pause/rewind")
    self:_enterPostDeathPause()
    return
  end

  if minDisplayMet and escapePressed and not self:_canScrub() then
    logger.info(string.format(
      "Post-death escape: scrub disabled (supportsScrub=%s, specs=%d)",
      tostring(self.supportsScrub),
      self.match and self.match.spectators and #self.match.spectators or -1))
  end

  if maxDisplayMet or (minDisplayMet and keyPressed) then
    GAME.theme:playValidationSfx()
    collectgarbage("collect")
    collectgarbage("collect")
    self:startNextScene()
  end
end

function GameBase:_enterPostDeathPause()
  if not self.match.supportsPause then return end
  -- Resurrect the match so update() flows to runGame (→ handlePause) instead
  -- of runGameOver. If the user resumes without actually rewinding, the
  -- engine's stack is still game-over so shouldFinalize re-fires
  -- handleMatchEnd next tick and we land back in the game-over screen.
  self.match.ended = false
  self.gameOverStartTime = nil

  self.match:togglePause()
  self.pauseMenu:setVisibility(true)
  self:_initScrubState()

  if self.stageTrack then
    self.pauseState.musicWasPlaying = self.stageTrack:isPlaying()
    SoundController:pauseMusic()
  end
  GAME.theme:playValidationSfx()
end

function GameBase:readyToProceedToNextScene()
  return (tableUtils.length(input.isDown) > 0) or (tableUtils.length(input.mouse.isDown) > 0)
end

function GameBase:startNextScene()
  -- match:deinit is the responsibility of the one switching out of the game scene
  GAME.navigationStack:pop(nil, function() self.match:deinit() end)
end

-- Pop back to the waiting room (CharacterSelect2p) without aborting or
-- deiniting the match. Used when a dead local player wants to leave the game
-- view but stay in the room — teammates keep playing, and the match stays on
-- BattleRoom so they can spectate it again from CharacterSelect.
function GameBase:exitToWaitingRoom()
  GAME.navigationStack:pop()
end

-- Fail-loud recovery: when the engine throws, asserts trip, or the freeze
-- watchdog fires, snapshot diagnostics and drop back to the lobby instead of
-- leaving the player staring at a frozen scene. Everything is pcall-wrapped so
-- partial state can't block the navigation pop.
function GameBase:bailOnFrozenMatch(reason)
  logger.error("[freeze-recovery] aborting match: " .. tostring(reason))
  pcall(function()
    if self.match and self.match.stacks then
      for i, stack in ipairs(self.match.stacks) do
        local engine = stack and stack.engine
        local clk = engine and engine.clock or "?"
        local goc = engine and engine.game_over_clock or "?"
        local buf = engine and engine.confirmedInput and #engine.confirmedInput or "?"
        logger.error(string.format(
          "[freeze-recovery] stack %d: clock=%s game_over_clock=%s confirmedInput=%s",
          i, tostring(clk), tostring(goc), tostring(buf)))
      end
    end
  end)
  pcall(function()
    if self.match then self.match:abort() end
  end)
  -- Online vs offline teardown. Offline scenes (PuzzleGame, ReplayGame, etc)
  -- don't have a "Lobby" in their nav stack, so popToName would unwind too far.
  -- Freeze-recovery explicitly bails out of the room — announce the leave to
  -- the server before tearing down local state.
  local isOnline = GAME.netClient and GAME.netClient:isConnected() and GAME.battleRoom
  if isOnline then
    pcall(function() GAME.netClient:leaveRoom() end)
    pcall(function() GAME.battleRoom:shutdown() end)
    pcall(function() GAME.navigationStack:popToName("Lobby") end)
  else
    pcall(function() GAME.navigationStack:pop() end)
  end
end

function GameBase:runGame(dt)
  self:handlePause()

  if self.match.isPaused then
    if self.frameInfo.startTime then
      self.frameInfo.startTime = self.frameInfo.startTime + dt
    end
    return
  end

  if self.frameInfo.startTime == nil then
    -- Server-scheduled start: hold engine ticks until the target wall-clock,
    -- then anchor frameInfo.startTime to the scheduled moment so catch-up math
    -- advances the engine to where it should be. Falls back to start-on-arrival
    -- if no schedule was received (first match before offset is estimated, or
    -- offline modes).
    local schedMs = self.match and self.match.scheduledStartLocalMs
    if schedMs then
      local nowMs = math.floor(socket.gettime() * 1000)
      if nowMs < schedMs then
        return  -- hold; engine starts on the next tick that crosses the target
      end
      local latenessSec = (nowMs - schedMs) / 1000
      self.frameInfo.startTime = love.timer.getTime() - latenessSec
    else
      self.frameInfo.startTime = love.timer.getTime()
    end
  end

  local framesRun = 0
  self.frameInfo.currentTime = love.timer.getTime()
  self.frameInfo.expectedFrameCount = math.ceil((self.frameInfo.currentTime - self.frameInfo.startTime) * 60)
  repeat
    prof.push("Match:run")--, self.match.clock)
    self.frameInfo.frameCount = self.frameInfo.frameCount + 1
    framesRun = framesRun + 1
    self.match:run()
    prof.pop("Match:run")
  until (self.frameInfo.frameCount >= self.frameInfo.expectedFrameCount)
  self.droppedFrameCount = self.droppedFrameCount + (framesRun - 1)

  self:customRun()
end

function GameBase:musicCanChange()
  -- technically this condition shouldn't keep music from changing, just from actually playing above 0% volume
  -- this may become a use case when users can change volume from any scene in the game
  if GAME.muteSound then
    return false
  end

  if self.match.isPaused then
    return false
  end

  -- someone is still catching up
  if tableUtils.trueForAny(self.match.stacks, ClientStack.isCatchingUp) then
    return false
  end

  -- music waits until countdown is over
  if self.match.engine.doCountdown and self.match.engine.clock < (consts.COUNTDOWN_START + consts.COUNTDOWN_LENGTH) then
    return false
  end

  if self.match.ended then
    return false
  end

  return true
end

function GameBase:onGameStart()
  if self.stageTrack then
    SoundController:playMusic(self.stageTrack)
  end
end

function GameBase:changeMusic(useDangerMusic)
  if self.stageTrack and self:musicCanChange() then
    self.stageTrack:changeMusic(useDangerMusic)
  end
end

-- 10 seconds of zero engine.clock progress while the match should be running.
-- Real network stalls are absorbed by stack:shouldRun's catch-up well before this.
-- Conservative on purpose to avoid false-positives from any path I haven't audited.
local FREEZE_THRESHOLD_SECONDS = 10

function GameBase:update(dt)
  if self.match.ended then
    local ok, err = xpcall(function() self:runGameOver() end, debug.traceback)
    if not ok then
      self:bailOnFrozenMatch("runGameOver error: " .. tostring(err))
    end
    self.uiRoot:handleFocusedInput(input, dt)
    self.uiRoot:update(dt)
    return
  end

  do
    local isPureSpectator = not self.match:hasLocalPlayer()
    local isDeadLocal = self.match:isLocalPlayerEliminated()

    if isPureSpectator then
      if input.isDown["MenuEsc"] then
        GAME.theme:playCancelSfx()
        self.match:abort()
        if GAME.netClient:isConnected() then
          GAME.netClient:leaveRoom()
          GAME.battleRoom:shutdown()
        end
        GAME.navigationStack:popToName("Lobby")
        return
      end
    elseif isDeadLocal then
      -- Dead local player: let them duck back to the waiting room without
      -- aborting the match. Teammates keep playing on the server; this client
      -- just unmounts the game scene. The match stays on BattleRoom so they
      -- can re-enter to spectate by clicking ready in CharacterSelect.
      if input.isDown["MenuEsc"] then
        GAME.theme:playCancelSfx()
        self:exitToWaitingRoom()
        return
      end
    end

    -- Real-time grace timer after local death. Accumulates in wall-clock dt
    -- (not engine frames) so a paused or laggy game still progresses through
    -- the window. Reset whenever we aren't a dead local — covers respawn
    -- between rounds and the pure-spectator path.
    if isDeadLocal then
      self.deathGraceTimer = (self.deathGraceTimer or 0) + dt
    else
      self.deathGraceTimer = nil
    end

    -- Spectator focus cycling: available to pure spectators immediately, and
    -- to dead local players only after a short grace period (so the cycle
    -- hint / focused-stack snap doesn't pop in at the exact instant of death).
    local spectatorControlsReady = isPureSpectator
      or (isDeadLocal and (self.deathGraceTimer or 0) >= DEAD_LOCAL_GRACE_SECONDS)
    if spectatorControlsReady then
      if isDeadLocal and not self.match.spectatorFocus then
        -- First grace-period expiry after death: snap focus to your own stack
        -- so the "Viewing: <yourname>" label appears. Arrow keys cycle to live
        -- teammates from there, which swaps the focused stack into the
        -- big-left container via ClientMatch:cycleSpectatorFocus.
        for _, stack in ipairs(self.match.stacks) do
          if stack.is_local then
            self.match.spectatorFocus = stack.player_number
            self.match:moveStacks()
            break
          end
        end
      end
      if input:isPressedWithRepeat("MenuLeft") then
        self.match:cycleSpectatorFocus(-1)
      elseif input:isPressedWithRepeat("MenuRight") then
        self.match:cycleSpectatorFocus(1)
      end
    end

    -- Freeze watchdog: bail to lobby if engine.clock stops advancing for too
    -- long. Pause is excluded — we reset the baseline while paused so unpause
    -- starts fresh, otherwise an idle pause would trip the watchdog.
    -- Pure spectators / pending joiners are excluded: their engine is
    -- input-driven and will stall naturally when the real match ends (inputs
    -- stop arriving). A stalled clock is expected, not a bug, for them.
    local nowSeconds = love.timer.getTime()
    if isPureSpectator then
      self._lastClockProgressTime = nowSeconds
      self._lastObservedClock = self.match.engine and self.match.engine.clock or 0
    elseif self.match.isPaused then
      self._lastClockProgressTime = nowSeconds
      self._lastObservedClock = self.match.engine and self.match.engine.clock or 0
    else
      local engineClock = self.match.engine and self.match.engine.clock or 0
      if engineClock ~= self._lastObservedClock then
        self._lastObservedClock = engineClock
        self._lastClockProgressTime = nowSeconds
      elseif self._lastClockProgressTime
          and (nowSeconds - self._lastClockProgressTime) > FREEZE_THRESHOLD_SECONDS then
        self:bailOnFrozenMatch(string.format(
          "engine clock stalled %.1fs at %s", nowSeconds - self._lastClockProgressTime,
          tostring(engineClock)))
        return
      end
    end

    local ok, err = xpcall(function() self:runGame(dt) end, debug.traceback)
    if not ok then
      self:bailOnFrozenMatch("runGame error: " .. tostring(err))
      return
    end
  end

  self.uiRoot:handleFocusedInput(input, dt)
  self.uiRoot:update(dt)
end

function GameBase:draw()
  if not self.match.isPaused or self.match.renderDuringPause then
    prof.push("GameBase:draw")
    self:drawBackground()
    prof.push("Match:render")
    self.match:render()
    prof.pop("Match:render")
    prof.push("GameBase:drawHUD")
    self:drawHUD()
    self:drawEndGameText()
    prof.pop("GameBase:drawHUD")
    if self.customDraw then
      self:customDraw()
    end
    self:drawForegroundOverlay()
    self:drawSpectatorHint()
    prof.pop("GameBase:draw")
  end

  if self.match.isPaused then
    self.match:draw_pause()
    self:drawScrubIndicator()
  end

  self.uiRoot:draw()

  if config.show_fps then
    GraphicsUtil.printf("Dropped Frames: " .. self.droppedFrameCount, 1, 12)
  end
end

function GameBase:drawBackground()
  if self.backgroundImage then
    self.backgroundImage:draw()
  end
  local backgroundOverlay = themes[config.theme].images.bg_overlay
  if backgroundOverlay then
    backgroundOverlay:draw()
  end
end

function GameBase:drawForegroundOverlay()
  local foregroundOverlay = themes[config.theme].images.fg_overlay
  if foregroundOverlay then
    foregroundOverlay:draw()
  end
end

function GameBase:drawHUD()
  if not self.match.isPaused then
    -- "shared team" = real teams with multiple players (2v2, 1v2 asymmetric).
    -- FFA (3p/4p) falls through this and shows per-player WINS in the LSS column.
    local isTeamMode = isSharedTeamMode(self.match.gameMode)

    for i, stack in ipairs(self.match.stacks) do
      stack._teamColor = teamColorForStack(self.match, stack, i)

      stack:withPanelTransform(function()
        if stack.engine.stackOverConditions[MatchRules.StackOverConditions.SWAPS] then
          stack:drawMoveCount()
        end
        if config.show_ingame_infos then
          if not stack.engine.stackOverConditions[MatchRules.StackOverConditions.SWAPS] then
            stack:drawScore()
            stack:drawSpeed()
          end
          stack:drawMultibar()
        end

        if stack.player then
          stack:drawPlayerName()
          stack:drawRating()
          -- Non-team modes: per-player wins go in the LSS panel below SPEED
          -- (theme winLabel_Pos is anchored there). Team modes suppress it
          -- because the team scoreboard at the top already shows team W/L.
          if not isTeamMode then
            stack:drawWinCount()
          end
        end

        if stack.analytic and not DebugSettings.showStackDebugInfo() then
          stack:drawAnalyticData()
        end
        stack:drawLevel()
      end)
    end

    if not DebugSettings.showStackDebugInfo() and GAME.battleRoom and GAME.battleRoom.spectatorString then -- this is printed in the same space as the debug details
      GraphicsUtil.print(GAME.battleRoom.spectatorString, themes[config.theme].spectators_Pos[1], themes[config.theme].spectators_Pos[2])
    end
  end
end

function GameBase:drawSpectatorHint()
  -- Pure spectators and dead-but-still-watching local players both get the
  -- "<  >  Switch Player" hint and the focused-player highlight. Live local
  -- players don't (they're playing, not spectating). Dead locals are gated by
  -- a brief grace period so the UI doesn't flood in at the moment of death
  -- (deathGraceTimer accumulates in GameBase:update while isDeadLocal).
  if self.match:hasLocalPlayer() then
    if not self.match:isLocalPlayerEliminated() then return end
    if (self.deathGraceTimer or 0) < DEAD_LOCAL_GRACE_SECONDS then return end
  end
  local consts = require("common.engine.consts")
  local font = GraphicsUtil.getGlobalFont()
  local hint = "<  >  Switch Player"
  local hintW = font:getWidth(hint)
  local hintX = (consts.CANVAS_WIDTH - hintW) / 2
  local hintY = consts.CANVAS_HEIGHT - font:getHeight() - 6

  -- focused player name + highlight border around their stack
  local focusName
  if self.match.spectatorFocus then
    for _, stack in ipairs(self.match.stacks) do
      if stack.player_number == self.match.spectatorFocus and stack.player then
        focusName = stack.player.name
        if stack.canvas then
          local x = stack.frameOriginX * stack.gfxScale
          local y = stack.frameOriginY * stack.gfxScale
          local w = stack:canvasWidth()
          local h = stack:canvasHeight()
          local pad = 4
          local prevLineWidth = love.graphics.getLineWidth()
          love.graphics.setLineWidth(3)
          GraphicsUtil.drawRectangle("line", x - pad, y - pad, w + pad * 2, h + pad * 2, 1, 1, 0.4, 1)
          love.graphics.setLineWidth(prevLineWidth)
        end
        break
      end
    end
  end

  if focusName then
    local nameText = "Viewing: " .. focusName
    local nameW = font:getWidth(nameText)
    local nameX = (consts.CANVAS_WIDTH - nameW) / 2
    GraphicsUtil.print(nameText, nameX + 1, hintY - font:getHeight() - 3 + 1, {0, 0, 0, 0.7})
    GraphicsUtil.print(nameText, nameX,     hintY - font:getHeight() - 3,     {1, 1, 1, 1})
  end

  GraphicsUtil.print(hint, hintX + 1, hintY + 1, {0, 0, 0, 0.7})
  GraphicsUtil.print(hint, hintX,     hintY,     {1, 1, 0.6, 1})
end

function GameBase:drawEndGameText()
  if self.match.ended then

    local message = self.text or ""
    local continueText = loc("continue_button")

    local gameOverPosition = themes[config.theme].gameover_text_Pos
    local font = GraphicsUtil.getGlobalFont()
    local padding = 4
    local lineHeight = font:getHeight()

    local placementLines = self:_buildPlacementLines() or {}

    -- Width is max across every drawn line.
    local maxWidth = math.max(font:getWidth(message), font:getWidth(continueText))
    for _, line in ipairs(placementLines) do
      local w = font:getWidth(line)
      if w > maxWidth then maxWidth = w end
    end

    -- Height: message + N placement lines + continue prompt + padding between each.
    local totalLines = 2 + #placementLines
    local height = lineHeight * totalLines + (totalLines + 1) * padding
    local drawY = gameOverPosition[2]

    GraphicsUtil.drawRectangle("fill", gameOverPosition[1] - maxWidth/2 - padding, drawY, maxWidth + 2*padding, height, 0, 0, 0, 0.8)

    local cursorY = drawY + padding
    GraphicsUtil.print(message, gameOverPosition[1] - font:getWidth(message)/2, cursorY)
    cursorY = cursorY + lineHeight + padding
    for _, line in ipairs(placementLines) do
      GraphicsUtil.print(line, gameOverPosition[1] - font:getWidth(line)/2, cursorY)
      cursorY = cursorY + lineHeight + padding
    end
    GraphicsUtil.print(continueText, gameOverPosition[1] - font:getWidth(continueText)/2, cursorY)
  end
end

---@param match ClientMatch
function GameBase:genericOnMatchEnded(match)
  self:setupGameOver()
  -- matches always sort players to have locals in front so if 1 isn't local, none is
  if match.players[1].isLocal then
    analytics.game_ends(match.players[1].stack.analytic)
  end

  if self.saveReplay then
    FileUtils.saveReplay(match.replay)
  end
end

-- Override this method in subclasses to disable taunt sounds
function GameBase:shouldDisableTauntSounds()
  return false
end

return GameBase
