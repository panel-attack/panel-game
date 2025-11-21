local Scene = require("client.src.scenes.Scene")
local class = require("common.lib.class")
local ui = require("client.src.ui")
local GameModes = require("common.data.GameModes")
local CharacterSelect2p = require("client.src.scenes.CharacterSelect2p")
local TimeAttackGame = require("client.src.scenes.TimeAttackGame")
local GameBase = require("client.src.scenes.GameBase")

local LocalGameModeSelectionScene = class(
  function (self, sceneParams)
    self.backgroundImg = themes[config.theme].images.bg_main
    self.keepMusic = true
    self:load(sceneParams)
  end,
  Scene
)

LocalGameModeSelectionScene.name = "LocalGameModeSelectionScene"

function LocalGameModeSelectionScene:load(sceneParams)
  local menuItems = {
    ui.MenuItem.createButtonMenuItem("rp_browser_info_time_trial", nil, nil, function ()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("TWO_PLAYER_TIME_ATTACK"), TimeAttackGame)
      if GAME.battleRoom then
        GAME.theme:playValidationSfx()
        GAME.navigationStack:push(CharacterSelect2p({battleRoom = GAME.battleRoom}))
      end
    end),
    ui.MenuItem.createButtonMenuItem("vs", nil, nil, function ()
      GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("TWO_PLAYER_VS"), GameBase)
      if GAME.battleRoom then
        GAME.theme:playValidationSfx()
        GAME.navigationStack:push(CharacterSelect2p({battleRoom = GAME.battleRoom}))
      end
    end),
    ui.MenuItem.createButtonMenuItem("back", nil, nil, Scene.pop)
  }

  self.menu = ui.Menu.createCenteredMenu(menuItems)
  self.uiRoot:addChild(self.menu)
end

function LocalGameModeSelectionScene:updateSelf(dt)
  self.backgroundImg:update(dt)
  self.menu:receiveInputs()
  self.uiRoot:update(dt)
end

function LocalGameModeSelectionScene:draw()
  self.backgroundImg:draw()
  self.uiRoot:draw()
end

return LocalGameModeSelectionScene