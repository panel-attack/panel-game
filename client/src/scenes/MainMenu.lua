local Scene = require("client.src.scenes.Scene")
local consts = require("common.engine.consts")
local Menu = require("client.src.ui.Menu")
local MenuItem = require("client.src.ui.MenuItem")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local class = require("common.lib.class")
local GameModes = require("common.engine.GameModes")
local EndlessMenu = require("client.src.scenes.EndlessMenu")
local PuzzleMenu = require("client.src.scenes.PuzzleMenu")
local TimeAttackMenu = require("client.src.scenes.TimeAttackMenu")
local CharacterSelectVsSelf = require("client.src.scenes.CharacterSelectVsSelf")
local TrainingMenu = require("client.src.scenes.TrainingMenu")
local ChallengeModeMenu = require("client.src.scenes.ChallengeModeMenu")
local Lobby = require("client.src.scenes.Lobby")
local CharacterSelect2p = require("client.src.scenes.CharacterSelect2p")
local ReplayBrowser = require("client.src.scenes.ReplayBrowser")
local InputConfigMenu = require("client.src.scenes.InputConfigMenu")
local SetNameMenu = require("client.src.scenes.SetNameMenu")
local OptionsMenu = require("client.src.scenes.OptionsMenu")
local DesignHelper = require("client.src.scenes.DesignHelper")

local TimeAttackGame = require("client.src.scenes.TimeAttackGame")
local EndlessGame = require("client.src.scenes.EndlessGame")
local VsSelfGame = require("client.src.scenes.VsSelfGame")
local Game2pVs = require("client.src.scenes.Game2pVs")
local PuzzleGame = require("client.src.scenes.PuzzleGame")


-- @module MainMenu
-- Scene for the main menu
local MainMenu = class(function(self, sceneParams)
  self.music = "main"
  self.menu = self:createMainMenu()
  self.uiRoot:addChild(self.menu)
end, Scene)

MainMenu.name = "MainMenu"

local function switchToScene(sceneName, transition)
  GAME.theme:playValidationSfx()
  GAME.navigationStack:push(sceneName, transition)
end

function MainMenu:createMainMenu()

  local menuItems = {MenuItem.createButtonMenuItem("mm_1_endless", nil, nil, function()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("ONE_PLAYER_ENDLESS"), EndlessGame)
      if GAME.battleRoom then
        switchToScene(EndlessMenu())
      end
    end),
    MenuItem.createButtonMenuItem("mm_1_puzzle", nil, nil, function()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("ONE_PLAYER_PUZZLE"), PuzzleGame)
      if GAME.battleRoom then
        switchToScene(PuzzleMenu())
      end
    end),
    MenuItem.createButtonMenuItem("mm_1_time", nil, nil, function()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("ONE_PLAYER_TIME_ATTACK"), TimeAttackGame)
      if GAME.battleRoom then
        switchToScene(TimeAttackMenu())
      end
    end),
    MenuItem.createButtonMenuItem("mm_1_vs", nil, nil, function()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("ONE_PLAYER_VS_SELF"), VsSelfGame)
      if GAME.battleRoom then
        switchToScene(CharacterSelectVsSelf())
      end
    end),
    MenuItem.createButtonMenuItem("mm_1_training", nil, nil, function()
      switchToScene(TrainingMenu())
    end),
    MenuItem.createButtonMenuItem("mm_1_challenge_mode", nil, nil, function()
      switchToScene(ChallengeModeMenu())
    end),
    MenuItem.createButtonMenuItem("mm_2_vs_online", {""}, nil, function()
      switchToScene(Lobby({serverIp = "panelattack.com"}))
    end),
    MenuItem.createButtonMenuItem("mm_2_vs_local", nil, nil, function()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("TWO_PLAYER_VS"), Game2pVs)
      if GAME.battleRoom then
        switchToScene(CharacterSelect2p())
      end
    end),
    MenuItem.createButtonMenuItem("mm_replay_browser", nil, nil, function()
      switchToScene(ReplayBrowser())
    end),
    MenuItem.createButtonMenuItem("mm_configure", nil, nil, function()
      switchToScene(InputConfigMenu())
    end),
    MenuItem.createButtonMenuItem("mm_set_name", nil, nil, function()
      switchToScene(SetNameMenu())
    end),
    MenuItem.createButtonMenuItem("mm_options", nil, nil, function()
      switchToScene(OptionsMenu())
    end),
    MenuItem.createButtonMenuItem("mm_fullscreen", {"\n(Alt+Enter)"}, nil, function()
      GAME.theme:playValidationSfx()
      local fullscreen = love.window.getFullscreen()
      love.window.setFullscreen(not fullscreen, "desktop")
      fullscreen = not fullscreen
      if not fullscreen and config.maximizeOnStartup and not love.window.isMaximized() then
        love.window.maximize()
      end
    end),
    MenuItem.createButtonMenuItem("mm_quit", nil, nil, function() love.event.quit() end )
  }

  local menu = Menu.createCenteredMenu(menuItems)

  local debugMenuItems = {MenuItem.createButtonMenuItem("Beta Server", nil, nil, function() switchToScene(Lobby({serverIp = "betaserver.panelattack.com", serverPort = 59569})) end),
                          MenuItem.createButtonMenuItem("Localhost Server", nil, nil, function() switchToScene(Lobby({serverIp = "Localhost"})) end)
                        }

  local function addDebugMenuItems()
    if config.debugShowServers then
      for i, menuItem in ipairs(debugMenuItems) do
        menu:addMenuItem(i + 7, menuItem)
      end
    end
    if config.debugShowDesignHelper then
      menu:addMenuItem(#menu.menuItems, MenuItem.createButtonMenuItem("Design Helper", nil, nil, function()
          switchToScene(DesignHelper())
        end))
    end
  end

  local function removeDebugMenuItems()
    for i, menuItem in ipairs(debugMenuItems) do
      menu:removeMenuItem(menuItem[1].id)
    end
  end

  addDebugMenuItems()
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

function MainMenu:update(dt)
  GAME.theme.images.bg_main:update(dt)
  self.menu:receiveInputs()

  self:checkForUpdates()
end

function MainMenu:draw()
  GAME.theme.images.bg_main:draw()
  self.uiRoot:draw()
  local fontHeight = GraphicsUtil.getGlobalFont():getHeight()
  local infoYPosition = 705 - fontHeight / 2

  local loveString = GAME:loveVersionString()
  if loveString == "11.3.0" then
    GraphicsUtil.printf(loc("love_version_warning"), -5, infoYPosition, consts.CANVAS_WIDTH, "right")
    infoYPosition = infoYPosition - fontHeight
  end

  if GAME.updater then
    local version
    if updateAvailable then
      version = "New " .. GAME.updater.activeReleaseStream.name .. " version available! Restart the game to download!"
    else
      version = "PA Version: " .. GAME.updater.activeReleaseStream.name .. " " .. GAME.updater.activeVersion.version
    end
    GraphicsUtil.printf(version, -5, infoYPosition, consts.CANVAS_WIDTH, "right")
    infoYPosition = infoYPosition - fontHeight
  end
end

return MainMenu
