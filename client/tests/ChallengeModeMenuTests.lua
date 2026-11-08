local ChallengeModeMenu = require("client.src.scenes.ChallengeModeMenu")
local ChallengeModeSave = require("client.src.ChallengeModeSave")
local ChallengeRun = require("client.src.ChallengeRun")
local tableUtils = require("common.lib.tableUtils")

local SAVE_NAME = "challengeModeMenuTests"

local function removeSaveFiles()
  love.filesystem.remove(ChallengeModeSave.path(SAVE_NAME))
end

-- runs the test with a menu on a save nobody else uses, recording the challenges it starts instead of starting them
---@param prepareSave fun(save: ChallengeModeSave)?
---@param test fun(menu: table, save: ChallengeModeSave, started: table[])
local function withMenu(prepareSave, test)
  removeSaveFiles()
  local save = ChallengeModeSave.load(SAVE_NAME)
  if prepareSave then
    prepareSave(save)
  end
  local menu = ChallengeModeMenu({save = save})
  local started = {}
  menu.goToCharacterSelect = function(_, difficulty, run)
    started[#started + 1] = {difficulty = difficulty, run = run}
  end
  local ok, err = pcall(test, menu, save, started)
  removeSaveFiles()
  assert(ok, err)
end

---@return string text the localization key of the menu item's button or label
local function itemText(menuItem)
  local label = menuItem.textButton and menuItem.textButton.label or menuItem.children[1]
  return label.text
end

local function itemTexts(menu)
  return tableUtils.map(menu.menu.menuItems, itemText)
end

local function findItem(menu, text)
  for _, menuItem in ipairs(menu.menu.menuItems) do
    if itemText(menuItem) == text then
      return menuItem
    end
  end
  error("the menu has no item " .. text .. ", it has " .. table.concat(itemTexts(menu), ", "))
end

local function press(menu, text)
  findItem(menu, text).textButton.onClick()
end

local function isShown(element)
  return element.parent ~= nil
end

local function runOnStageTwo(difficulty)
  local run = ChallengeRun(difficulty, 10)
  run:startStage(5)
  run:finishStage(ChallengeRun.results.WIN, 600)
  return run
end

local function withoutAnUnfinishedRunNewGameStartsANewRunWithoutAsking()
  withMenu(nil, function(menu, save, started)
    assert(not tableUtils.contains(itemTexts(menu), "challenge_continue"))
    assert(not tableUtils.contains(itemTexts(menu), "go_"))

    press(menu, "challenge_new_game")

    assert(#started == 1 and started[1].difficulty == 1 and started[1].run == nil)
  end)
end

local function anUnfinishedRunCanBeContinued()
  withMenu(function(save) save:saveRun(runOnStageTwo(1)) end, function(menu, save, started)
    assert(not tableUtils.contains(itemTexts(menu), "go_"))
    assert(findItem(menu, "challenge_continue").textButton.label.replacementTable[1] == nil, "the button holds only its label")

    press(menu, "challenge_continue")

    assert(#started == 1 and started[1].run == save:getRun(1))
  end)
end

local function changingTheDifficultyShowsThatDifficultysRun()
  withMenu(function(save) save:saveRun(runOnStageTwo(2)) end, function(menu)
    menu.difficultyStepper:setState(1)
    assert(not tableUtils.contains(itemTexts(menu), "challenge_continue"))

    menu.difficultyStepper:setState(2)

    assert(tableUtils.contains(itemTexts(menu), "challenge_continue"))
  end)
end

local function theMenuOpensOnTheLastPlayedDifficulty()
  withMenu(function(save) save:saveRun(runOnStageTwo(3)) end, function(menu)
    assert(menu.difficultyStepper.value == 3, tostring(menu.difficultyStepper.value))
    assert(tableUtils.contains(itemTexts(menu), "challenge_continue"))
  end)
end

local function withoutAPlayedDifficultyTheMenuOpensOnTheEasiest()
  withMenu(nil, function(menu)
    assert(menu.difficultyStepper.value == 1)
  end)
end

local function aNewGameAsksBeforeThrowingAwayTheUnfinishedRun()
  withMenu(function(save) save:saveRun(runOnStageTwo(1)) end, function(menu, save, started)
    press(menu, "challenge_new_game")

    assert(#started == 0, "nothing starts before the player confirms")
    assert(tableUtils.contains(itemTexts(menu), "challenge_discard_run_warning"))
    assert(save:getRun(1) ~= nil)
  end)
end

local function confirmingTheNewGameThrowsAwayTheUnfinishedRun()
  withMenu(function(save) save:saveRun(runOnStageTwo(1)) end, function(menu, save, started)
    press(menu, "challenge_new_game")

    press(menu, "challenge_discard_run_confirm")

    assert(ChallengeModeSave.load(SAVE_NAME):getRun(1) == nil)
    assert(#started == 1 and started[1].run == nil)
  end)
end

local function backingOutOfTheNewGameKeepsTheRun()
  withMenu(function(save) save:saveRun(runOnStageTwo(1)) end, function(menu, save, started)
    press(menu, "challenge_new_game")

    press(menu, "back")

    assert(save:getRun(1) ~= nil and #started == 0)
    assert(tableUtils.contains(itemTexts(menu), "challenge_continue"), "the menu is back to the run")
  end)
end

local function assertItemsLineUp(menu)
  local items = menu.menu.menuItems
  for _, menuItem in ipairs(items) do
    assert(menuItem.x == items[1].x and menuItem.width == items[1].width,
           tostring(itemText(menuItem)) .. " is " .. menuItem.width .. " wide at " .. menuItem.x .. ", the first item " .. items[1].width .. " at " .. items[1].x)
  end
end

local function theBestTimeOfTheSelectedDifficultyIsShown()
  local function beatenIn250Frames(save)
    local run = ChallengeRun(2, 1)
    run:startStage(1)
    run:finishStage(ChallengeRun.results.LOSS, 100)
    run:startStage(2)
    run:finishStage(ChallengeRun.results.WIN, 150)
    save:saveRun(run)
  end
  withMenu(beatenIn250Frames, function(menu)
    local records = menu.runRecords
    menu.difficultyStepper:setState(1)
    assert(not isShown(records.bestTimeValue), "a difficulty never beaten has no best time")

    menu.difficultyStepper:setState(2)

    assert(isShown(records.bestTimeValue) and records.bestTimeValue.text == frames_to_time_string(250, true))
  end)
end

local function theButtonsLineUpWithTheDifficultyWithoutARun()
  withMenu(nil, assertItemsLineUp)
end

local function theButtonsLineUpWithTheDifficultyWithARun()
  withMenu(function(save) save:saveRun(runOnStageTwo(1)) end, assertItemsLineUp)
end

local function theNewGameConfirmationLinesUp()
  withMenu(function(save) save:saveRun(runOnStageTwo(1)) end, function(menu)
    press(menu, "challenge_new_game")

    assertItemsLineUp(menu)
  end)
end

local function theRecordsShowTheUnfinishedRunsStageContinuesAndTime()
  local function runWithALossOnStageTwo(save)
    local run = runOnStageTwo(1)
    run:startStage(6)
    run:finishStage(ChallengeRun.results.LOSS, 300)
    save:saveRun(run)
  end
  withMenu(runWithALossOnStageTwo, function(menu)
    local records = menu.runRecords

    assert(isShown(records.stageValue) and records.stageValue.text == "2")
    assert(isShown(records.continuesValue) and records.continuesValue.text == "1")
    assert(isShown(records.timeValue) and records.timeValue.text == frames_to_time_string(900, true))
    assert(not isShown(records.noRunLabel))
  end)
end

local function withoutAnUnfinishedRunTheRecordsSayNoRunIsInProgress()
  withMenu(nil, function(menu)
    local records = menu.runRecords

    assert(isShown(records.noRunLabel))
    assert(not isShown(records.stageValue) and not isShown(records.continuesValue) and not isShown(records.timeValue))
  end)
end

local function theBestContinuesOfTheSelectedDifficultyIsShown()
  local function beatenWithOneContinue(save)
    local run = ChallengeRun(2, 1)
    run:startStage(1)
    run:finishStage(ChallengeRun.results.LOSS, 100)
    run:startStage(2)
    run:finishStage(ChallengeRun.results.WIN, 100)
    save:saveRun(run)
  end
  withMenu(beatenWithOneContinue, function(menu)
    local records = menu.runRecords
    menu.difficultyStepper:setState(1)
    assert(isShown(records.notBeatenLabel) and not isShown(records.bestValue))

    menu.difficultyStepper:setState(2)

    assert(isShown(records.bestValue) and records.bestValue.text == "1")
    assert(not isShown(records.notBeatenLabel))
  end)
end

withoutAnUnfinishedRunNewGameStartsANewRunWithoutAsking()
anUnfinishedRunCanBeContinued()
changingTheDifficultyShowsThatDifficultysRun()
theMenuOpensOnTheLastPlayedDifficulty()
withoutAPlayedDifficultyTheMenuOpensOnTheEasiest()
aNewGameAsksBeforeThrowingAwayTheUnfinishedRun()
confirmingTheNewGameThrowsAwayTheUnfinishedRun()
backingOutOfTheNewGameKeepsTheRun()
theButtonsLineUpWithTheDifficultyWithoutARun()
theButtonsLineUpWithTheDifficultyWithARun()
theNewGameConfirmationLinesUp()
theRecordsShowTheUnfinishedRunsStageContinuesAndTime()
withoutAnUnfinishedRunTheRecordsSayNoRunIsInProgress()
theBestContinuesOfTheSelectedDifficultyIsShown()
theBestTimeOfTheSelectedDifficultyIsShown()
