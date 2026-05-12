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

-- Player chip background colors keyed by team index. Mirrors the palette used by
-- ClientMatch:drawTeamScoreboard so the chip above each stack matches the
-- scoreboard tint at the top of the screen.
local TEAM_COLORS = {
  {1,    0.55, 0.75, 0.85}, -- pink   (team 1)
  {0.65, 0.4,  0.95, 0.85}, -- purple (team 2)
  {0.45, 1,    0.45, 0.85}, -- green
  {1,    1,    0.45, 0.85}, -- yellow
  {1,    0.6,  0.2,  0.85}, -- orange
  {0.45, 0.7,  1,    0.85}, -- blue
  {0.45, 1,    1,    0.85}, -- cyan
  {1,    0.45, 0.45, 0.85}, -- red
}

local function teamColorForStack(match, stack, stackIndex)
  local teams = match.engine and match.engine.teams
  local idx = teams and TeamUtils.getPlayerTeamIndex(teams, stackIndex) or stackIndex
  return TEAM_COLORS[idx] or TEAM_COLORS[1]
end

-- "Shared team mode" = TEAM_VERSUS with at least one team containing multiple
-- players. FFA (3p/4p) is technically TEAM_VERSUS in the data model but every
-- team is size 1, so wins are per-individual — we treat it like a non-team mode
-- for HUD purposes (LSS shows WINS, no top team scoreboard).
local function isSharedTeamMode(gameMode)
  if not gameMode or gameMode.stackInteraction ~= GameModes.StackInteractions.TEAM_VERSUS then
    return false
  end
  local p = gameMode.playersPerTeam
  if type(p) == "number" then return p > 1 end
  if type(p) == "table" then
    for _, n in ipairs(p) do
      if n > 1 then return true end
    end
    return false
  end
  return false
end

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

local function teamLetter(teamIndex)
  return string.char(string.byte("A") + (teamIndex - 1))
end

local function joinPlayerNames(players)
  local names = {}
  for _, player in ipairs(players) do
    names[#names + 1] = player.name
  end
  return table.concat(names, ", ")
end

local function buildTeamResultText(match, winners)
  local gameMode = match.gameMode
  if not gameMode or gameMode.stackInteraction ~= GameModes.StackInteractions.TEAM_VERSUS then
    return nil
  end

  local teams = {}
  local winnerTeams = {}
  local localTeam = nil

  for index, player in ipairs(match.players) do
    local teamIndex = getTeamIndexForPlayerPosition(gameMode, index)
    if teamIndex then
      teams[teamIndex] = teams[teamIndex] or {}
      teams[teamIndex][#teams[teamIndex] + 1] = player
      if player.isLocal then
        localTeam = teamIndex
      end
    end
  end

  for _, winner in ipairs(winners) do
    for index, player in ipairs(match.players) do
      if player == winner then
        local teamIndex = getTeamIndexForPlayerPosition(gameMode, index)
        if teamIndex then
          winnerTeams[teamIndex] = true
        end
        break
      end
    end
  end

  local winnerTeamIndex = nil
  local winnerTeamCount = 0
  for teamIndex, _ in pairs(winnerTeams) do
    winnerTeamIndex = teamIndex
    winnerTeamCount = winnerTeamCount + 1
  end

  if winnerTeamCount == 1 and winnerTeamIndex then
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
      self.match:togglePause()
      if self.stageTrack and self.pauseState.musicWasPlaying then
        SoundController:playMusic(self.stageTrack)
      end
      self:initializeFrameInfo()
    end),
    ui.MenuItem.createButtonMenuItem("back", nil, true, function()
      GAME.theme:playCancelSfx()
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

      if self.stageTrack then
        self.pauseState.musicWasPlaying = self.stageTrack:isPlaying()
        SoundController:pauseMusic()
      end
      GAME.theme:playValidationSfx()
    end
  else
    if (self.pauseMenu.hasFocus == nil or self.pauseMenu.hasFocus == false) and playerPressingStart(self.match) == false then
      self.uiRoot:setFocus(self.pauseMenu)
    end
  end
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
    elseif self.match.gameMode and self.match.gameMode.stackInteraction == GameModes.StackInteractions.TEAM_VERSUS then
      self.text = buildTeamResultText(self.match, winners)
    elseif #winners == 1 then
      self.text = loc("ss_p_wins", winners[1].name)
    else
      self.text = loc("ss_draw")
    end
  end
  
  self:customGameOverSetup()
end

function GameBase:runGameOver()
  -- wait()
  local displayTime = love.timer.getTime() - self.gameOverStartTime

  self.match:run()

  -- if conditions are met, leave the game over screen
  local keyPressed = self:readyToProceedToNextScene()

  if ((displayTime >= self.maxDisplayTime and self.maxDisplayTime ~= -1) or (displayTime >= self.minDisplayTime and keyPressed)) then
    GAME.theme:playValidationSfx()
    collectgarbage("collect")
    collectgarbage("collect")
    self:startNextScene()
  end
end

function GameBase:readyToProceedToNextScene()
  return (tableUtils.length(input.isDown) > 0) or (tableUtils.length(input.mouse.isDown) > 0)
end

function GameBase:startNextScene()
  -- match:deinit is the responsibility of the one switching out of the game scene
  GAME.navigationStack:pop(nil, function() self.match:deinit() end)
end

function GameBase:runGame(dt)
  self:handlePause()

  if self.frameInfo.startTime == nil then
    self.frameInfo.startTime = love.timer.getTime()
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

function GameBase:update(dt)
  if self.match.ended then
    self:runGameOver()
  else
    if not self.match:hasLocalPlayer() then
      if input.isDown["MenuEsc"] then
        GAME.theme:playCancelSfx()
        self.match:abort()
        if GAME.netClient:isConnected() then
          GAME.battleRoom:shutdown()
        end
        GAME.navigationStack:popToName("Lobby")
        return
      end
      if input:isPressedWithRepeat("MenuLeft") then
        self.match:cycleSpectatorFocus(-1)
      elseif input:isPressedWithRepeat("MenuRight") then
        self.match:cycleSpectatorFocus(1)
      end
    end
    self:runGame(dt)
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
  if self.match:hasLocalPlayer() then return end
  local consts = require("common.engine.consts")
  local font = GraphicsUtil.getGlobalFont()
  local hint = "<  >  Switch Player"
  local hintW = font:getWidth(hint)
  local hintX = (consts.CANVAS_WIDTH - hintW) / 2
  local hintY = consts.CANVAS_HEIGHT - font:getHeight() - 6

  -- focused player name
  local focusName
  if self.match.spectatorFocus then
    for _, stack in ipairs(self.match.stacks) do
      if stack.player_number == self.match.spectatorFocus and stack.player then
        focusName = stack.player.name
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

    local message = self.text
    if message == nil then
      message = ""
    end

    local gameOverPosition = themes[config.theme].gameover_text_Pos
    local font = GraphicsUtil.getGlobalFont()
    local padding = 4
    local maxWidth = math.max(font:getWidth(message), font:getWidth(loc("continue_button")))
    local height = font:getHeight() * 2 + 3*padding
    local drawY = gameOverPosition[2]

    -- Background
    GraphicsUtil.drawRectangle("fill", gameOverPosition[1] - maxWidth/2 - padding, drawY, maxWidth + 2*padding, height, 0, 0, 0, 0.8)

    GraphicsUtil.print(message, gameOverPosition[1] - font:getWidth(message)/2, drawY + padding)
    GraphicsUtil.print(loc("continue_button"), gameOverPosition[1] - font:getWidth(loc("continue_button"))/2, drawY + padding + font:getHeight() + padding )
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
