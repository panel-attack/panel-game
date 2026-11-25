local Player = require("client.src.Player")
local GameModes = require("common.data.GameModes")
local BattleRoom = require("client.src.BattleRoom")
local NavigationStack = require("client.src.NavigationStack")
local Scene = require("client.src.scenes.Scene")
local CharacterSelect2p = require("client.src.scenes.CharacterSelect2p")

-- Runs test on a fresh navigation stack with the theme's menu sounds counted instead of played,
-- putting both back afterwards even if it fails
---@param test fun(menuSoundCount: fun(): integer)
local function whileCountingMenuSounds(test)
  local theme = GAME.theme
  local originals = {theme.playValidationSfx, theme.playMoveSfx, theme.playCancelSfx}
  local originalNavigationStack = GAME.navigationStack
  local count = 0
  local function countSound()
    count = count + 1
  end
  theme.playValidationSfx = countSound
  theme.playMoveSfx = countSound
  theme.playCancelSfx = countSound
  GAME.navigationStack = NavigationStack({})

  local ok, err = pcall(test, function() return count end)

  theme.playValidationSfx, theme.playMoveSfx, theme.playCancelSfx = originals[1], originals[2], originals[3]
  GAME.navigationStack = originalNavigationStack
  assert(ok, err)
end

-- Changes a remote player's ranked choice and level the way the server's menu state and match start messages do
---@param player Player
local function changeSettingsFromNetwork(player)
  player:updateSettings({wantsRanked = not player.settings.wantsRanked})
  player:setLevel(player.settings.level == 10 and 9 or 10)
end

local function testCharacterSelectPlaysSoundsOnlyWhileShown()
  local room = BattleRoom(GameModes.getPreset(GameModes.IDs.TWO_PLAYER_VS))
  room.online = true
  room.spectating = true
  room:addPlayer(Player("Player1", -1, false))
  room:addPlayer(Player("Player2", -2, false))

  whileCountingMenuSounds(function(menuSoundCount)
    GAME.navigationStack:push(CharacterSelect2p({battleRoom = room}))
    GAME.navigationStack:updateSelf(1 / 60)
    -- the game scene goes on top of character select for the match and the time between matches
    ---@class CharacterSelectSoundTestScene : Scene
    local gameScene = Scene({})
    gameScene.name = "Game"
    GAME.navigationStack:push(gameScene)
    GAME.navigationStack:updateSelf(1 / 60)

    changeSettingsFromNetwork(room.players[1])
    assert(menuSoundCount() == 0, "character select played " .. menuSoundCount() .. " menu sounds under another scene")

    GAME.navigationStack:pop()
    GAME.navigationStack:updateSelf(1 / 60)

    changeSettingsFromNetwork(room.players[1])
    assert(menuSoundCount() == 2, "character select played " .. menuSoundCount() .. " menu sounds for ranked and level changing instead of 2")
  end)

  room:shutdown()
end

testCharacterSelectPlaysSoundsOnlyWhileShown()
