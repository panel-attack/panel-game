local logger = require("common.lib.logger")
local input = require("client.src.inputManager")
local TitleScreen = require("client.src.scenes.TitleScreen")
local MainMenu = require("client.src.scenes.MainMenu")
local ModLoader = require("client.src.mods.ModLoader")
local ModValidationScene = require("client.src.scenes.ModValidationScene")
local LanguageSelectSetup = require("client.src.scenes.LanguageSelectSetup")
local DiscordCommunitySetup = require("client.src.scenes.DiscordCommunitySetup")
local InputConfigMenu = require("client.src.scenes.InputConfigMenu")

---@class SceneCoordinator
---@field joystickAdded boolean
local SceneCoordinator = {
  startupComplete = false
}

-- Called when an unconfigured joystick is added
-- Pushes InputConfigMenu if we're not in the middle of a game
function SceneCoordinator:onUnconfiguredJoystickAdded(joystick)
  -- Check if we're in a game (BattleRoom exists and has an active match)
  local inGame = false
  if GAME.battleRoom and GAME.battleRoom.match ~= nil then
    inGame = true
  end

  if self.startupComplete and not inGame then
    -- Not in a game, so push the InputConfigMenu
    GAME.navigationStack:push(InputConfigMenu({}))
  end
end

-- Called when the BootScene completes asset loading
-- Begins the setup flow sequence
function SceneCoordinator:handleStartupComplete()
  self.startupComplete = true

  if themes[config.theme].images.bg_title then
    GAME.navigationStack:replace(TitleScreen({
      triggerNextScene = function()
        self:handleTitleScreenComplete()
      end
    }))
  else
    self:handleTitleScreenComplete()
  end

  if next(ModLoader.invalidMods) then
    GAME.navigationStack:replace(ModValidationScene())
  end
end

function SceneCoordinator:handleTitleScreenComplete()
  self:continueSetupFlow()
end

function SceneCoordinator:continueSetupFlow()

  -- Check language selection
  if not config.language_code then
    self:showLanguageSelect()
    return true
  end

  -- Check Discord community welcome
  if not config.discordCommunityShown then
    self:showDiscordWelcome()
    return true
  end

  -- Check for unconfigured joysticks
  if input.hasUnsavedChanges or input:hasUnconfiguredJoysticks() then
    self:showInputConfig()
    return true
  end

  GAME.navigationStack:replace(MainMenu({}))
  return true
end

-- Shows the language selection scene with completion callback
function SceneCoordinator:showLanguageSelect()
  local scene = LanguageSelectSetup({
    triggerNextScene = function()
      self:continueSetupFlow()
    end
  })
  GAME.navigationStack:replace(scene)
end

-- Shows the Discord welcome scene with completion callback
function SceneCoordinator:showDiscordWelcome()
  local scene = DiscordCommunitySetup({
    triggerNextScene = function()
      self:continueSetupFlow()
    end
  })
  GAME.navigationStack:replace(scene)
end

-- Shows the input configuration scene with completion callback
function SceneCoordinator:showInputConfig()
  local scene = InputConfigMenu({
    triggerNextScene = function()
      self:continueSetupFlow()
    end
  })
  GAME.navigationStack:replace(scene)
end

return SceneCoordinator
