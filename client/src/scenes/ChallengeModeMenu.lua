local Scene = require("client.src.scenes.Scene")
local class = require("common.lib.class")
local ChallengeMode = require("client.src.ChallengeMode")
local ui = require("client.src.ui")
local CharacterSelectChallenge = require("client.src.scenes.CharacterSelectChallenge")
local ChallengeRunRecords = require("client.src.scenes.components.ChallengeRunRecords")

-- how far the menu and the records beside it sit from the middle of the screen
local COLUMN_OFFSET = 150
-- how far above the middle of the screen the discard warning sits, clear of the two answers below it
local WARNING_OFFSET = -60

-- Picks the difficulty of a challenge and whether to continue its unfinished run or start a new one
---@class ChallengeModeMenu : Scene
---@field save ChallengeModeSave
---@field runRecords ChallengeRunRecords
---@field discardWarning Label shown above the menu while it asks whether to throw away the unfinished run
---@field menu Menu
local ChallengeModeMenu = class(
  function (self, sceneParams)
    self.backgroundImg = themes[config.theme].images.bg_main
    self.keepMusic = true
    self.save = sceneParams and sceneParams.save or GAME.challengeModeSave
    self:load(sceneParams)
  end,
  Scene
)

ChallengeModeMenu.name = "ChallengeModeMenu"

local function exitMenu()
  GAME.theme:playCancelSfx()
  GAME.navigationStack:pop()
end

-- Starts the challenge of the difficulty, continuing run or starting a new one if run is nil
---@param difficulty integer
---@param run ChallengeRun?
function ChallengeModeMenu:goToCharacterSelect(difficulty, run)
  GAME.theme:playValidationSfx()
  GAME.battleRoom = ChallengeMode.create(difficulty, self.save, run)
  if GAME.battleRoom then
    GAME.navigationStack:replace(CharacterSelectChallenge({battleRoom = GAME.battleRoom}))
  end
end

function ChallengeModeMenu:load(sceneParams)
  local difficultyLabels = {}
  local challengeModes = {}
  for i = 1, ChallengeMode.numDifficulties do
    table.insert(difficultyLabels, ui.Label({text = "challenge_difficulty_" .. i}))
    table.insert(challengeModes, i)
  end

  self.difficultyStepper = ui.Stepper({
      labels = difficultyLabels,
      values = challengeModes,
      selectedIndex = self.save:getLastDifficulty() or 1,
      width = 70,
      height = 25,
      onChange = function(value)
        GAME.theme:playMoveSfx()
        self:showDifficulty(value)
      end
    }
  )
  self.difficultyMenuItem = ui.MenuItem.createStepperMenuItem("difficulty", nil, nil, self.difficultyStepper)

  self.runRecords = ChallengeRunRecords({alignment = "top", hAlign = "center", vAlign = "center", x = COLUMN_OFFSET})
  self.uiRoot:addChild(self.runRecords)

  self.discardWarning = ui.Label({
    text = "challenge_discard_run_warning", hAlign = "center", vAlign = "center", x = -COLUMN_OFFSET, y = WARNING_OFFSET
  })
  self.discardWarning:setVisibility(false)
  self.uiRoot:addChild(self.discardWarning)

  self.menu = ui.Menu.createCenteredMenu({self.difficultyMenuItem}, nil, {x = -COLUMN_OFFSET, equalItemWidths = true})
  self.uiRoot:addChild(self.menu)
  self:showDifficulty(self.difficultyStepper.value)
end

-- Shows the records of the difficulty and offers to continue its unfinished run if it has one
---@param difficulty integer
function ChallengeModeMenu:showDifficulty(difficulty)
  local run = self.save:getRun(difficulty)
  self.discardWarning:setVisibility(false)
  self.runRecords:show(run, self.save:getBestContinues(difficulty), self.save:getBestTime(difficulty))

  local menuItems = {self.difficultyMenuItem}
  if run then
    menuItems[#menuItems + 1] = ui.MenuItem.createButtonMenuItem("challenge_continue", nil, nil, function()
      self:goToCharacterSelect(difficulty, run)
    end)
    menuItems[#menuItems + 1] = ui.MenuItem.createButtonMenuItem("challenge_new_game", nil, nil, function()
      self:warnBeforeDiscarding(difficulty)
    end)
  else
    menuItems[#menuItems + 1] = ui.MenuItem.createButtonMenuItem("challenge_new_game", nil, nil, function()
      self:goToCharacterSelect(difficulty)
    end)
  end
  menuItems[#menuItems + 1] = ui.MenuItem.createButtonMenuItem("back", nil, nil, exitMenu)
  self.menu:setMenuItems(menuItems)
end

-- Asks the player to confirm that starting a new game throws away the difficulty's unfinished run
---@param difficulty integer
function ChallengeModeMenu:warnBeforeDiscarding(difficulty)
  GAME.theme:playValidationSfx()
  self.discardWarning:setVisibility(true)
  self.menu:setMenuItems({
    ui.MenuItem.createButtonMenuItem("challenge_discard_run_confirm", nil, nil, function()
      self.save:discardRun(difficulty)
      self:goToCharacterSelect(difficulty)
    end),
    ui.MenuItem.createButtonMenuItem("back", nil, nil, function()
      GAME.theme:playCancelSfx()
      self:showDifficulty(difficulty)
    end),
  })
  self.menu:setSelectedIndex(2)
end

function ChallengeModeMenu:updateSelf(dt)
  self.backgroundImg:update(dt)
  self.menu:receiveInputs()
  self.uiRoot:update(dt)
end

function ChallengeModeMenu:draw()
  self.backgroundImg:draw()
  self.uiRoot:draw()
end

return ChallengeModeMenu
