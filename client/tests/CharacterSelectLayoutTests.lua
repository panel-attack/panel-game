local BattleRoom = require("client.src.BattleRoom")
local GameModes = require("common.data.GameModes")
local EndlessMenu = require("client.src.scenes.EndlessMenu")
local EndlessGame = require("client.src.scenes.EndlessGame")
local TimeAttackMenu = require("client.src.scenes.TimeAttackMenu")
local TimeAttackGame = require("client.src.scenes.TimeAttackGame")
local CharacterSelect2p = require("client.src.scenes.CharacterSelect2p")
local GameBase = require("client.src.scenes.GameBase")
local logger = require("common.lib.logger")

-- Runs the test with the character select scene set up on a local battle room of the game mode, laid out
---@param gameModeId string
---@param gameScene table
---@param sceneClass table
---@param test fun(scene: CharacterSelect)
local function withScene(gameModeId, gameScene, sceneClass, test)
  local battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset(gameModeId), gameScene)
  assert(battleRoom, "the battle room is set up")
  local ok, err = pcall(function()
    local scene = sceneClass({battleRoom = battleRoom})
    scene.uiRoot:layOut()
    test(scene)
  end)
  battleRoom:shutdown()
  assert(ok, err)
end

-- Returns the element's top and bottom on screen
---@param element UiElement
---@return number top
---@return number bottom
local function verticalSpan(element)
  local _, y = element:getScreenPos()
  return y, y + element.layoutRect.height
end

-- Asserts the player's style toggle is centered down the style box, under its title
---@param scene CharacterSelect
local function assertStyleToggleIsCenteredInItsBox(scene)
  local selection = scene.ui.styleSelection
  local container = selection.wrappedElements[scene.players[1]]
  local boxTop, boxBottom = verticalSpan(selection)
  local top, bottom = verticalSpan(container.styleSelector)
  local _, titleBottom = verticalSpan(selection.title)
  assert(top - boxTop == boxBottom - bottom, "the toggle is centered down its box: " .. top - boxTop .. " above, "
         .. boxBottom - bottom .. " below")
  assert(top >= titleBottom, "the toggle is under the title")
end

local function testEndlessCentersTheStyleToggleInItsBox()
  withScene(GameModes.IDs.ONE_PLAYER_ENDLESS, EndlessGame, EndlessMenu, assertStyleToggleIsCenteredInItsBox)
  logger.trace("passed test testEndlessCentersTheStyleToggleInItsBox")
end

local function testTimeAttackCentersTheStyleToggleInItsBox()
  withScene(GameModes.IDs.ONE_PLAYER_TIME_ATTACK, TimeAttackGame, TimeAttackMenu, assertStyleToggleIsCenteredInItsBox)
  logger.trace("passed test testTimeAttackCentersTheStyleToggleInItsBox")
end

local function testTwoPlayersShareTheRoomUnderThePanelsAndLevelTitles()
  withScene(GameModes.IDs.TWO_PLAYER_VS, GameBase, CharacterSelect2p, function(scene)
    local grid = scene.ui.grid
    for _, selection in ipairs({scene.ui.panelSelection, scene.ui.levelSelection}) do
      local _, titleHeight = selection.title:getEffectiveDimensions()
      local expected = (grid.unitSize - grid.unitMargin * 2) / #scene.players - titleHeight
      local _, titleBottom = verticalSpan(selection.title)
      local rowTop = titleBottom
      for _, player in ipairs(scene.players) do
        local element = selection.wrappedElements[player]
        local top, bottom = verticalSpan(element)
        assert(element.layoutRect.height == expected, "a player's row is " .. element.layoutRect.height .. " tall, not " .. expected)
        assert(top == rowTop, "the rows stack straight under the title")
        rowTop = bottom
      end
    end
  end)
  logger.trace("passed test testTwoPlayersShareTheRoomUnderThePanelsAndLevelTitles")
end

local function testEndlessGivesThePanelsTheRoomUnderTheirTitle()
  withScene(GameModes.IDs.ONE_PLAYER_ENDLESS, EndlessGame, EndlessMenu, function(scene)
    local grid = scene.ui.grid
    local selection = scene.ui.panelSelection
    local _, titleHeight = selection.title:getEffectiveDimensions()
    local expected = grid.unitSize - grid.unitMargin * 2 - titleHeight
    assert(scene:getHeightUnderTitle(selection) == expected, "the cell leaves " .. expected .. " under the title")
    local height = selection.wrappedElements[scene.players[1]].layoutRect.height
    assert(height == expected, "the panels are " .. height .. " tall, not " .. expected)
  end)
  logger.trace("passed test testEndlessGivesThePanelsTheRoomUnderTheirTitle")
end

logger.info("running CharacterSelectLayoutTests")
testEndlessCentersTheStyleToggleInItsBox()
testTimeAttackCentersTheStyleToggleInItsBox()
testTwoPlayersShareTheRoomUnderThePanelsAndLevelTitles()
testEndlessGivesThePanelsTheRoomUnderTheirTitle()
