local class = require("common.lib.class")
local Scene = require("client.src.scenes.Scene")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local logger = require("common.lib.logger")
local analytics = require("client.src.analytics")
local input = require("client.src.inputManager)
local tableUtils = require("common.lib.tableUtils")
local consts = require("common.engine.consts")
local StageLoader = require("client.src.mods.StageLoader")
local ModController = require("client.src.mods.ModController")
local SoundController = require("client.src.music.SoundController")
local UpdatingImage = require("client.src.graphics.UpdatingImage")
local prof = require("common.lib.jprof.jprof")
local Menu = require("client.src.ui.Menu")
local MenuItem = require("client.src.ui.MenuItem")
local FileUtils = require("client.src.FileUtils")
local ClientStack = require("client.src.ClientStack")

-- Scene template for running any type of game instance (endless, vs-self, replays, etc.)
local GameBase = class(
  function (self, sceneParams)
    self.saveReplay = true

    -- set in load
    self.text = nil
    self.keepMusic = false
    self.currentStage = config.stage
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

    self:load(sceneParams)
  end,
  Scene
)

GameBase.name = "GameBase"

-- begin abstract functions

-- Game mode specific game state setup
-- Called during load()
function GameBase:customLoad(sceneParams) end

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
    return nil
  elseif (preferredMusicSourceType == "stage" and stageHasMusic) or not characterHasMusic then
    return self.stage
  else --if preferredMusicSourceType == "characters" and characterHasMusic then
    return character
  end
end

-- unlike regular asset load, this function connects the used assets to the match so they cannot be unloaded
function GameBase:loadAssets(match)
  for i, stack in ipairs(match.stacks) do
    local character = characters[stack.character]
    logger.debug("Force loading character " .. character.id .. " as part of GameBase:load")
    ModController:loadModFor(character, stack, true)
    character:register(match)
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
  GAME.droppedFrames = 0
end

function GameBase:load(sceneParams)
  self:loadAssets(sceneParams.match)
  self.match = sceneParams.match
  self.match:connectSignal("matchEnded", self, self.genericOnMatchEnded)
  self.match:connectSignal("dangerMusicChanged", self, self.changeMusic)
  self.match:connectSignal("countdownEnded", self, self.onGameStart)

  self.stage = stages[self.match.stageId]
  self.backgroundImage = UpdatingImage(self.stage.images.background, false, 0, 0, consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT)
  self.musicSource = self:pickMusicSource()
  if self.musicSource and self.musicSource.stageTrack and not self.keepMusic then
    -- reset the track to make sure it starts from the default settings
    self.musicSource.stageTrack:stop()
    SoundController:stopMusic()
  end

  local pauseMenuItems = {
    MenuItem.createButtonMenuItem("pause_resume", nil, true, function()
      GAME.theme:playValidationSfx()
      self.pauseMenu:setVisibility(false)
      self.match:togglePause()
      if self.musicSource and self.musicSource.stageTrack and self.pauseState.musicWasPlaying then
        SoundController:playMusic(self.musicSource.stageTrack)
      end
      self:initializeFrameInfo()
    end),
    MenuItem.createButtonMenuItem("back", nil, true, function()
      GAME.theme:playCancelSfx()
      self.match:abort()
      self:startNextScene()
    end),
  }

  self.pauseMenu = Menu({
    x = 0,
    y = 0,
    hAlign = "center",
    vAlign = "center",
    menuItems = pauseMenuItems,
    height = 200
  })
  self.pauseMenu:setVisibility(false)
  self.uiRoot:addChild(self.pauseMenu)

  self:customLoad(sceneParams)

  leftover_time = 1 / 120

  self:initializeFrameInfo()
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

      if self.musicSource and self.musicSource.stageTrack then
        self.pauseState.musicWasPlaying = self.musicSource.stageTrack:isPlaying()
        SoundController:pauseMusic()
      end
      GAME.theme:playValidationSfx()
    end
  else
    self.pauseMenu:receiveInputs()
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
    self:startNextScene()
  end
end

function GameBase:readyToProceedToNextScene()
  return (tableUtils.length(input.isDown) > 0) or (tableUtils.length(input.mouse.isDown) > 0)
end

function GameBase:startNextScene()
  GAME.navigationStack:pop()
end

function GameBase:runGame(dt)
  if self.frameInfo.startTime == nil then
    self.frameInfo.startTime = love.timer.getTime()
  end

  local framesRun = 0
  self.frameInfo.currentTime = love.timer.getTime()
  self.frameInfo.expectedFrameCount = math.ceil((self.frameInfo.currentTime - self.frameInfo.startTime) * 60)
  repeat
    prof.push("Match:run", self.match.clock)
    self.frameInfo.frameCount = self.frameInfo.frameCount + 1
    framesRun = framesRun + 1
    self.match:run()
    prof.pop("Match:run")
  until (self.frameInfo.frameCount >= self.frameInfo.expectedFrameCount)
  GAME.droppedFrames = GAME.droppedFrames + (framesRun - 1)

  self:customRun()

  self:handlePause()
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
  if self.musicSource then
    SoundController:playMusic(self.musicSource.stageTrack)
  end
end

function GameBase:changeMusic(useDangerMusic)
  if self.musicSource and self.musicSource.stageTrack and self:musicCanChange() then
    self.musicSource.stageTrack:changeMusic(useDangerMusic)
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
    end
    self:runGame(dt)
  end
end

function GameBase:draw()
  if not self.match.paused or self.match.renderDuringPause then
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
    prof.pop("GameBase:draw")
  end

  if self.match.isPaused then
    self.match:draw_pause()
    self.uiRoot:draw()
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
    for i, stack in ipairs(self.match.stacks) do
      if stack.puzzle then
        stack:drawMoveCount()
      end
      if config.show_ingame_infos then
        if not stack.puzzle then
          stack:drawScore()
          stack:drawSpeed()
        end
        stack:drawMultibar()
      end

      -- Draw VS HUD
      if stack.player then
        stack:drawPlayerName()
        stack:drawWinCount()
        stack:drawRating()
      end

      stack:drawLevel()
      if stack.analytic then
        prof.push("Stack:drawAnalyticData")
        stack:drawAnalyticData()
        prof.pop("Stack:drawAnalyticData")
      end
    end

    if not config.debug_mode and GAME.battleRoom and GAME.battleRoom.spectatorString then -- this is printed in the same space as the debug details
      GraphicsUtil.print(GAME.battleRoom.spectatorString, themes[config.theme].spectators_Pos[1], themes[config.theme].spectators_Pos[2])
    end

    self:drawCommunityMessage()
  end
end

function GameBase:drawEndGameText()
  if self.match.ended then

    local winners = self.match:getWinners()
    local message = self.text
    if message == nil then
      if #winners == 1 then
        message = loc("ss_p_wins", winners[1].name)
      else
        message = loc("ss_draw")
      end
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

return GameBase
