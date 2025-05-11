local Scene = require("client.src.scenes.Scene")
local class = require("common.lib.class")
local ChallengeMode = require("client.src.ChallengeMode")
local ui = require("client.src.ui")
local CharacterSelectChallenge = require("client.src.scenes.CharacterSelectChallenge")

local ChallengeModeMenu = class(
  function (self, sceneParams)
    self.backgroundImg = themes[config.theme].images.bg_main
    self.keepMusic = true
    self:load(sceneParams)
  end,
  Scene
)

ChallengeModeMenu.name = "ChallengeModeMenu"

local function exitMenu()
  GAME.theme:playCancelSfx()
  GAME.navigationStack:pop()
end

function ChallengeModeMenu:goToCharacterSelect(difficulty)
  GAME.theme:playValidationSfx()
  GAME.battleRoom = ChallengeMode.create(difficulty)
  if GAME.battleRoom then
    GAME.navigationStack:replace(CharacterSelectChallenge({battleRoom = GAME.battleRoom}))
  end
end

function ChallengeModeMenu:load(sceneParams)
  local difficultyLabels = {}
  local challengeModes = {}
  for i = 1, ChallengeMode.numDifficulties do
    table.insert(difficultyLabels, ui.Label({id = "challenge_difficulty_" .. i}))
    table.insert(challengeModes, i)
  end

  local difficultyStepper = ui.Stepper({
      labels = difficultyLabels,
      values = challengeModes,
      selectedIndex = 1,
      width = 70,
      height = 25,
      onChange = function(value)
        GAME.theme:playMoveSfx()
      end
    }
  )

  local challengeModeDifficulty = ui.MenuItem.createStepperMenuItem("difficulty", nil, nil, difficultyStepper)
  local go = ui.MenuItem.createButtonMenuItem("go_", nil, nil, function()
    self:goToCharacterSelect(difficultyStepper.value)
  end)
  local back = ui.MenuItem.createButtonMenuItem("back", nil, nil, exitMenu)

  self.menu = ui.VerticalMenu({
    hAlign = "center",
    minHeight = 480,
    maxHeight = 540,
    childGap = 8,
    padding = 32,
    width = 600,
  })

  self.menu:addChild(challengeModeDifficulty)
  self.menu:addChild(go)
  self.menu:addChild(back)

  self.uiRoot:addChild(self.menu)
end

function ChallengeModeMenu:update(dt)
  self.backgroundImg:update(dt)
  self.menu:receiveInputs()
end

function ChallengeModeMenu:draw()
  self.backgroundImg:draw()
  self.uiRoot:draw()
end

return ChallengeModeMenu