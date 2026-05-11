local Scene = require("client.src.scenes.Scene")
local consts = require("common.engine.consts")
local ui = require("client.src.ui")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local class = require("common.lib.class")
local GameModes = require("common.data.GameModes")
local DebugSettings = require("client.src.debug.DebugSettings")
local EndlessMenu = require("client.src.scenes.EndlessMenu")
local PuzzleMenu = require("client.src.scenes.PuzzleMenu")
local TimeAttackMenu = require("client.src.scenes.TimeAttackMenu")
local CharacterSelectVsSelf = require("client.src.scenes.CharacterSelectVsSelf")
local TrainingMenu = require("client.src.scenes.TrainingMenu")
local ChallengeModeMenu = require("client.src.scenes.ChallengeModeMenu")
local Lobby = require("client.src.scenes.Lobby")
local LocalGameModeSelectionScene = require("client.src.scenes.LocalGameModeSelectionScene")
local ReplayBrowser = require("client.src.scenes.ReplayBrowser")
local InputConfigMenu = require("client.src.scenes.InputConfigMenu")
local SetNameMenu = require("client.src.scenes.SetNameMenu")
local OptionsMenu = require("client.src.scenes.OptionsMenu")
local DesignHelper = require("client.src.scenes.DesignHelper")
local system = require("client.src.system")

local TimeAttackGame = require("client.src.scenes.TimeAttackGame")
local EndlessGame = require("client.src.scenes.EndlessGame")
local VsSelfGame = require("client.src.scenes.VsSelfGame")
local PuzzleGame = require("client.src.scenes.PuzzleGame")

-- Scene for the main menu
local MainMenu = class(function(self, sceneParams)
  self.music = "main"
  self.menu = self:createMainMenu()
  self.uiRoot:addChild(self.menu)
end, Scene)

MainMenu.name = "MainMenu"

local function switchToScene(scene, transition)
  GAME.theme:playValidationSfx()
  GAME.navigationStack:push(scene, transition)
end

function MainMenu:refresh()
  if self.menu then
    self.menu:detach()
    self.menu = nil
  end

  self.menu = self:createMainMenu()
  self.uiRoot:addChild(self.menu)
end

function MainMenu:createOgMenu()
  local ogItems = {
    ui.MenuItem.createButtonMenuItem("mm_1_endless", nil, nil, function()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset(GameModes.IDs.ONE_PLAYER_ENDLESS), EndlessGame)
      if GAME.battleRoom then
        switchToScene(EndlessMenu({battleRoom = GAME.battleRoom}))
      end
    end),
    ui.MenuItem.createButtonMenuItem("mm_1_puzzle", nil, nil, function()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset(GameModes.IDs.ONE_PLAYER_PUZZLE), PuzzleGame)
      if GAME.battleRoom then
        switchToScene(PuzzleMenu({battleRoom = GAME.battleRoom}))
      end
    end),
    ui.MenuItem.createButtonMenuItem("mm_1_time", nil, nil, function()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset(GameModes.IDs.ONE_PLAYER_TIME_ATTACK), TimeAttackGame)
      if GAME.battleRoom then
        switchToScene(TimeAttackMenu({battleRoom = GAME.battleRoom}))
      end
    end),
    ui.MenuItem.createButtonMenuItem("mm_1_vs", nil, nil, function()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset(GameModes.IDs.ONE_PLAYER_VS_SELF), VsSelfGame)
      if GAME.battleRoom then
        switchToScene(CharacterSelectVsSelf({battleRoom = GAME.battleRoom}))
      end
    end),
    ui.MenuItem.createButtonMenuItem("mm_1_training", nil, nil, function()
      switchToScene(TrainingMenu())
    end),
    ui.MenuItem.createButtonMenuItem("mm_1_challenge_mode", nil, nil, function()
      switchToScene(ChallengeModeMenu())
    end),
    ui.MenuItem.createButtonMenuItem("mm_2_vs_local", nil, nil, function()
      switchToScene(LocalGameModeSelectionScene())
    end),
    ui.MenuItem.createButtonMenuItem("lb_back", nil, nil, function()
      GAME.theme:playCancelSfx()
      self.menu:detach()
      self.menu = self:createMainMenu()
      self.uiRoot:addChild(self.menu)
    end),
  }
  return ui.Menu.createCenteredMenu(ogItems)
end

function MainMenu:createMainMenu()

  local menuItems = {
    ui.MenuItem.createButtonMenuItem("mm_2_vs_online", {""}, nil, function()
      switchToScene(Lobby({serverIp = "104.156.250.136"}))
    end),
    ui.MenuItem.createButtonMenuItem("mm_configure", nil, nil, function()
      switchToScene(InputConfigMenu())
    end),
    ui.MenuItem.createButtonMenuItem("mm_set_name", nil, nil, function()
      switchToScene(SetNameMenu())
    end),
    ui.MenuItem.createButtonMenuItem("mm_options", nil, nil, function()
      switchToScene(OptionsMenu())
    end),
    ui.MenuItem.createButtonMenuItem("mm_fullscreen", {"\n(Alt+Enter)"}, nil, function()
      GAME.theme:playValidationSfx()
      GAME:toggleFullscreen()
    end),
    ui.MenuItem.createButtonMenuItem("mm_quit", nil, nil, function() love.event.quit() end),
    ui.MenuItem.createButtonMenuItem("og stuff", nil, false, function()
      self.menu:detach()
      self.menu = self:createOgMenu()
      self.uiRoot:addChild(self.menu)
    end),
  }

  local menu = ui.Menu.createCenteredMenu(menuItems)

  if DebugSettings.showDebugServers() then
    menu:addMenuItem(#menu.menuItems + 1, ui.MenuItem.createButtonMenuItem("Replay Browser", nil, false, function() switchToScene(ReplayBrowser()) end))
    menu:addMenuItem(#menu.menuItems + 1, ui.MenuItem.createButtonMenuItem("Beta Server", nil, false, function() switchToScene(Lobby({serverIp = "betaserver.panelattack.com", serverPort = 59569})) end))
    menu:addMenuItem(#menu.menuItems + 1, ui.MenuItem.createButtonMenuItem("Localhost Server", nil, false, function() switchToScene(Lobby({serverIp = "Localhost"})) end))
  end
  if DebugSettings.showDesignHelper() then
    menu:addMenuItem(#menu.menuItems + 1, ui.MenuItem.createButtonMenuItem("Design Helper", nil, nil, function()
      switchToScene(DesignHelper())
    end))
  end

  return menu
end

local nextUpdate = 900
local checked = false
local interval = 900
local updateAvailable = false
function MainMenu:checkForUpdates()
  if GAME.updater then
    if not updateAvailable and GAME.timer > nextUpdate then
      checked = false
      nextUpdate = nextUpdate + interval
      if GAME.updater.activeReleaseStream.name == GAME.updater.activeVersion.releaseStream.name then
        GAME.updater:getAvailableVersions(GAME.updater.activeReleaseStream)
      end
    end
    GAME.updater:update()
    if not checked and GAME.updater.state == GAME_UPDATER_STATES.idle then
      checked = true
      updateAvailable = GAME.updater:updateAvailable(GAME.updater.activeReleaseStream)
    end
  end
end

function MainMenu:updateSelf(dt)
  GAME.theme.images.bg_main:update(dt)
  self.menu:receiveInputs(GAME.input, dt)

  self:checkForUpdates()
end

function MainMenu:drawSelf()
  GAME.theme.images.bg_main:draw()
  local fontHeight = GraphicsUtil.getGlobalFont():getHeight()
  local infoYPosition = 705 - fontHeight / 2

  local loveString = system.loveVersionString()
  if loveString == "11.3.0" then
    GraphicsUtil.printf(loc("love_version_warning"), -5, infoYPosition, consts.CANVAS_WIDTH, "right")
    infoYPosition = infoYPosition - fontHeight
  end

  if GAME.updater then
    local version
    if updateAvailable then
      version = "New " .. GAME.updater.activeReleaseStream.name .. " version available! Restart the game to download!"
    else
      if DEBUG_ENABLED then
        version = "PA Version: debug"
      else
        version = "PA Version: " .. GAME.updater.activeReleaseStream.name .. " " .. (GAME.updater.activeVersion and GAME.updater.activeVersion.version or "dev")
      end
    end
    GraphicsUtil.printf(version, -5, infoYPosition, consts.CANVAS_WIDTH, "right")
    infoYPosition = infoYPosition - fontHeight


    local showUpdaterUpdateWarning = false
    if system.meetsLoveVersionRequirement(12, 0) and GAME.updater.version.major < 2 or (GAME.updater.version.major == 2 and GAME.updater.version.minor < 0) then
      showUpdaterUpdateWarning = true
    elseif GAME.updater.version.major == 1 and GAME.updater.version.minor < 2 then
      local _, _, vendor, _ = love.graphics.getRendererInfo( )
      local systemIsAffected = (love.system.getOS() == "Windows" and (vendor == "ATI Technologies Inc." or vendor == "AMD"))
      -- only contains a startup fix for the related systems so everyone else shouldn't have to update
      if systemIsAffected then
        showUpdaterUpdateWarning = true
      end
    end

    if showUpdaterUpdateWarning then
      GraphicsUtil.printf(loc("auto_updater_version_warning") .. " https://panelattack.com", -5, infoYPosition, consts.CANVAS_WIDTH, "right")
      infoYPosition = infoYPosition - fontHeight
    end
  end
end

return MainMenu
