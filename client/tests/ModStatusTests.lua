local ModLoader = require("client.src.mods.ModLoader")
local ModSettings = require("client.src.mods.ModSettings")
local ModFolderTree = require("client.src.mods.ModFolderTree")
local CharacterLoader = require("client.src.mods.CharacterLoader")
local Character = require("client.src.mods.Character")
local Stage = require("client.src.mods.Stage")
local StageLoader = require("client.src.mods.StageLoader")
local StageCarousel = require("client.src.ui.StageCarousel")
local tableUtils = require("common.lib.tableUtils")

-- saves in these tests go to this folder of the save directory so they never touch the player's settings
local DIRECTORY = "modStatusTests"

local function removeTestFiles()
  love.filesystem.remove(DIRECTORY .. "/" .. ModSettings.FILE_NAME)
  love.filesystem.remove(DIRECTORY .. "/characters/blacklist.txt")
  love.filesystem.remove(DIRECTORY .. "/characters")
  love.filesystem.remove(DIRECTORY)
end

local function fakeMod(id, path, subIds)
  return {id = id, path = "characters/" .. path, isVisible = true, subIds = subIds or {}}
end

-- a pack folder with two characters and a bundle of them, and a character on its own
local function buildFolderTree()
  local mods = {
    fakeMod("brock", "Pack/Brock"),
    fakeMod("leaders", "Pack/Leaders", {"brock", "misty"}),
    fakeMod("misty", "Pack/Misty"),
    fakeMod("chocola", "chocola"),
  }
  return ModFolderTree.fromMods(mods, "characters", ModSettings(DIRECTORY))
end

local function run(test)
  removeTestFiles()
  local success, err = pcall(test)
  removeTestFiles()
  assert(success, err)
end

local function assertIds(actual, expected, what)
  local actualText, expectedText = table.concat(actual, ","), table.concat(expected, ",")
  assert(actualText == expectedText, "expected " .. what .. " to be " .. expectedText .. ", got " .. actualText)
end

local function sortedKeys(tab)
  local keys = tableUtils.getKeys(tab)
  table.sort(keys)
  return keys
end

local function testHiddenModIsEnabledButNotVisible()
  local tree = buildFolderTree()
  tree.settings:setStatus("characters", "chocola", "hidden")

  local _, enabled, visible = tree:listModsByStatus()

  assert(enabled.chocola, "a hidden mod can still be picked by an opponent")
  assert(not tableUtils.contains(visible, "chocola"), "a hidden mod is not in the selection")
end

local function testOffModIsNeitherEnabledNorVisible()
  local tree = buildFolderTree()
  tree.settings:setStatus("characters", "chocola", "off")

  local _, enabled, visible = tree:listModsByStatus()

  assert(not enabled.chocola and not tableUtils.contains(visible, "chocola"), "an off mod is gone")
end

local function testVisibleFollowsTheTreeOrder()
  local tree = buildFolderTree()
  tree.settings:setOrder("characters", "", {"chocola", "Pack"}, "shown")

  local ids, _, visible = tree:listModsByStatus()

  assertIds(ids, {"chocola", "brock", "leaders", "misty"}, "the ids")
  assertIds(visible, {"chocola", "brock", "leaders", "misty"}, "the visible ids")
end

local function testBundleWithEverySubModOffIsOff()
  local tree = buildFolderTree()
  tree.settings:setStatus("characters", "Pack/Brock", "off")
  tree.settings:setStatus("characters", "Pack/Misty", "off")

  local _, enabled = tree:listModsByStatus()

  assertIds(sortedKeys(enabled), {"chocola"}, "the enabled ids")
end

local function testEveryModOffFallsBackToAllOfThem()
  local tree = buildFolderTree()
  tree.settings:setStatus("characters", "Pack", "off")
  tree.settings:setStatus("characters", "chocola", "off")

  local _, enabled, visible = tree:listModsByStatusWithFallbacks()

  assertIds(sortedKeys(enabled), {"brock", "chocola", "leaders", "misty"}, "the enabled ids")
  assertIds(visible, {"brock", "leaders", "misty", "chocola"}, "the visible ids")
end

local function testNothingShownFallsBackToEveryEnabledMod()
  local tree = buildFolderTree()
  tree.settings:setStatus("characters", "Pack", "hidden")
  tree.settings:setStatus("characters", "chocola", "off")

  local _, _, visible = tree:listModsByStatusWithFallbacks()

  assertIds(visible, {"brock", "leaders", "misty"}, "the visible ids")
end

local function testStatusChangeIsSaved()
  local tree = buildFolderTree()

  local changed = tree:setStatusAndSave(tree:getNodeByKey("chocola"), "hidden")

  assert(changed, "the change is accepted")
  local reloaded = ModSettings(DIRECTORY)
  reloaded:load()
  assert(reloaded:getStatus("characters", "chocola") == "hidden", "the change is in the file")
end

local function testOffIsMirroredToTheBlacklist()
  local tree = buildFolderTree()

  tree:setStatusAndSave(tree:getNodeByKey("Pack/Brock"), "off")

  assertIds(tree.settings:readBlacklist("characters"), {"brock"}, "the blacklist")
end

local function testFolderOffIsMirroredForEveryModInside()
  local tree = buildFolderTree()
  tree:setStatusAndSave(tree:getNodeByKey("chocola"), "shown")

  tree:setStatusAndSave(tree:getNodeByKey("Pack"), "off")

  assertIds(tree.settings:readBlacklist("characters"), {"brock", "leaders", "misty"}, "the blacklist")
end

local function testHidingTheLastShownModIsRefused()
  local tree = buildFolderTree()
  tree:setStatusAndSave(tree:getNodeByKey("Pack"), "hidden")

  local changed = tree:setStatusAndSave(tree:getNodeByKey("chocola"), "off")

  assert(not changed, "something has to stay in the selection")
  assert(tree:getEffectiveStatus(tree:getNodeByKey("chocola")) == "shown", "the refused change is undone")
end

-- https://github.com/panel-attack/panel-game/issues/775
local function testTurningOffTheLastSubModOfAnEnabledBundleIsRefused()
  local tree = buildFolderTree()
  tree:setStatusAndSave(tree:getNodeByKey("Pack/Brock"), "off")

  local changed = tree:setStatusAndSave(tree:getNodeByKey("Pack/Misty"), "off")

  assert(not changed, "a bundle that is on needs one sub mod left")
  assert(tree:getEffectiveStatus(tree:getNodeByKey("Pack/Misty")) == "shown", "the refused change is undone")
end

local function testTurningOffTheFolderOfABundleAndItsSubModsIsAllowed()
  local tree = buildFolderTree()

  local changed = tree:setStatusAndSave(tree:getNodeByKey("Pack"), "off")

  assert(changed, "the bundle goes off together with its sub mods")
end

local function testMovingAModUpSavesTheFolderOrder()
  local tree = buildFolderTree()

  local moved = tree:moveWithinFolderAndSave(tree:getNodeByKey("Pack/Misty"), -1)

  assert(moved, "misty can move up")
  assertIds(tree.settings:getEntries("characters")["Pack"].order, {"Brock", "Misty", "Leaders"}, "the pack's order")
  assert(tree.settings:getStatus("characters", "Pack") == "shown", "the new entry records the folder's status")
end

local function testMovingTheFirstModUpIsRefused()
  local tree = buildFolderTree()

  assert(not tree:moveWithinFolderAndSave(tree:getNodeByKey("Pack/Brock"), -1), "the first mod cannot move up")
end

local function testThemeListsNoLongerFilterTheSelection()
  local themeFolder = "modStatusTestsTheme"
  local previousTheme = config.theme
  local visibleBefore = shallowcpy(visibleCharacters)
  love.filesystem.createDirectory(themeFolder)
  love.filesystem.write(themeFolder .. "/characters.txt", visibleCharacters[1])
  themes[themeFolder] = {path = themeFolder}
  config.theme = themeFolder

  local success, err = pcall(CharacterLoader.refreshCharacters)
  local visibleAfter = shallowcpy(visibleCharacters)

  config.theme = previousTheme
  themes[themeFolder] = nil
  love.filesystem.remove(themeFolder .. "/characters.txt")
  love.filesystem.remove(themeFolder)
  CharacterLoader.refreshCharacters()
  assert(success, err)
  assertIds(visibleAfter, visibleBefore, "the visible characters")
end

local function testHidingACharacterTakesItOutOfRandom()
  local character = characters[visibleCharacters[1]]
  local node = CharacterLoader.tree:getNodeOfMod(character)
  local settings = CharacterLoader.tree.settings
  local previousEntry = settings:copyEntry("characters", node.key)

  local changed = ModLoader.setModStatusAndRefresh(CharacterLoader, node, "hidden")
  local stillEnabled = characters[character.id] ~= nil
  local randomPool = shallowcpy(Character.getRandom().subIds)
  local visible = shallowcpy(visibleCharacters)

  settings:restoreEntry("characters", node.key, previousEntry)
  CharacterLoader.tree:saveAndMirrorBlacklist()
  CharacterLoader.refreshCharacters()
  assert(changed, "hiding one character is allowed")
  assert(stillEnabled, "a hidden character can still be used")
  assert(not tableUtils.contains(visible, character.id), "a hidden character is not in the selection")
  assertIds(randomPool, visible, "random's choices")
end

local function testRandomStageChoosesFromTheVisibleStages()
  assertIds(Stage.getRandom().subIds, visibleStages, "random's choices")
  assert(stages[stageIds[#stageIds]] == Stage.getRandom(), "random comes last in the ids")
end

local function testHiddenConfiguredStageStaysSelectedInTheCarousel()
  local stageId = visibleStages[1]
  local node = StageLoader.tree:getNodeOfMod(stages[stageId])
  local settings = StageLoader.tree.settings
  local previousEntry = settings:copyEntry("stages", node.key)
  local previousConfigStage = config.stage
  config.stage = stageId

  local changed = ModLoader.setModStatusAndRefresh(StageLoader, node, "hidden")
  local success, selectedId = pcall(function()
    local carousel = StageCarousel({})
    carousel:loadCurrentStages()
    local selected = carousel:getSelectedPassenger()
    return selected and selected.id
  end)

  settings:restoreEntry("stages", node.key, previousEntry)
  StageLoader.tree:saveAndMirrorBlacklist()
  StageLoader.refreshStages()
  config.stage = previousConfigStage
  assert(success, selectedId)
  assert(changed, "hiding one stage is allowed")
  assert(selectedId == stageId, "expected " .. stageId .. " selected, got " .. tostring(selectedId))
end

local function testStageCarouselFindsAPassengerById()
  local carousel = StageCarousel({})
  carousel:loadCurrentStages()

  local passenger = carousel:getPassengerById(visibleStages[1])

  assert(passenger and passenger.id == visibleStages[1], "the passenger of " .. visibleStages[1])
  assert(carousel:getPassengerById("not a stage") == nil, "an id without a passenger finds nothing")
end

run(testHiddenModIsEnabledButNotVisible)
run(testOffModIsNeitherEnabledNorVisible)
run(testVisibleFollowsTheTreeOrder)
run(testBundleWithEverySubModOffIsOff)
run(testEveryModOffFallsBackToAllOfThem)
run(testNothingShownFallsBackToEveryEnabledMod)
run(testStatusChangeIsSaved)
run(testOffIsMirroredToTheBlacklist)
run(testFolderOffIsMirroredForEveryModInside)
run(testHidingTheLastShownModIsRefused)
run(testTurningOffTheLastSubModOfAnEnabledBundleIsRefused)
run(testTurningOffTheFolderOfABundleAndItsSubModsIsAllowed)
run(testMovingAModUpSavesTheFolderOrder)
run(testMovingTheFirstModUpIsRefused)
testThemeListsNoLongerFilterTheSelection()
testHidingACharacterTakesItOutOfRandom()
testRandomStageChoosesFromTheVisibleStages()
testHiddenConfiguredStageStaysSelectedInTheCarousel()
testStageCarouselFindsAPassengerById()
