local Scene = require("client.src.scenes.Scene")
local ui = require("client.src.ui")
local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local CharacterSelectVsSelf = require("client.src.scenes.CharacterSelectVsSelf")
local GameModes = require("common.data.GameModes")
local GameBase = require("client.src.scenes.GameBase")
local save = require("client.src.save")

local TrainingMenu = class(
  function (self, sceneParams)
    self.keepMusic = true
    self:load(sceneParams)
  end,
  Scene
)

TrainingMenu.name = "TrainingMenu"

local function exitMenu()
  GAME.theme:playCancelSfx()
  GAME.navigationStack:pop()
end

local function createBasicTrainingMode(name, width, height)
  local delayBeforeStart = 150
  local delayBeforeRepeat = 900
  local attacksPerVolley = 50
  local attackPatterns = {}

  for i = 1, attacksPerVolley do
    table.insert(attackPatterns, {width = width, height = height, startTime = i, metal = false, chain = false, endsChain = false})
  end

  local customTrainingModeData = {delayBeforeStart = delayBeforeStart, delayBeforeRepeat = delayBeforeRepeat, attackPatterns = attackPatterns}

  return customTrainingModeData
end

function TrainingMenu:goToCharacterSelect(value, width, height)
  if value == nil then
    value = createBasicTrainingMode("", width, height)
  end
  GAME.battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("ONE_PLAYER_TRAINING"), GameBase)
  if GAME.battleRoom then
    GAME.localPlayer:setAttackEngineSettings(value)
    GAME.navigationStack:push(CharacterSelectVsSelf({battleRoom = GAME.battleRoom}))
  end
end

function TrainingMenu:load(sceneParams)
  local garbagePatternNames = {"Custom", "combo_storm", "factory", "large_garbage"}
  local garbagePatternValues = {
    nil,
    createBasicTrainingMode(loc("combo_storm"), 4, 1),
    createBasicTrainingMode(loc("factory"), 6, 2),
    createBasicTrainingMode(loc("large_garbage"), 6, 12),
  }
  local translatableGarbagePatternNames = {"combo_storm", "factory", "large_garbage"}
  for _, value in ipairs(save.readAttackFiles("training")) do
    table.insert(garbagePatternNames, value.name)
    table.insert(garbagePatternValues, value)
  end
  
  local garbagePatternLabels = {}
  for _, garbagepatternName in ipairs(garbagePatternNames) do
    table.insert(garbagePatternLabels, ui.Label({
        text = garbagepatternName,
        translate = tableUtils.contains(translatableGarbagePatternNames, garbagepatternName),
        width = 70,
        height = 25}))
  end

  local garbagePatternStepper = ui.Stepper({
      labels = garbagePatternLabels,
      values = garbagePatternValues,
      selectedIndex = 1,
      onChange = function(value)
        GAME.theme:playMoveSfx()
      end
    }
  )

  local widthSlider = ui.Slider({
    min = 1,
    max = 6,
    value = 1,
    tickLength = 15,
    onValueChange = function() garbagePatternStepper:setState(1) end
  })

  local heightSlider = ui.Slider({
    min = 1,
    max = 99,
    value = 1,
    onValueChange = function() garbagePatternStepper:setState(1) end
  })


    local presets = ui.MenuItem.createStepperMenuItem("Garbage Pattern", nil, false, garbagePatternStepper)
    local width = ui.MenuItem.createSliderMenuItem("width", nil, nil, widthSlider)
    local height = ui.MenuItem.createSliderMenuItem("height", nil, nil, heightSlider)
    local go = ui.MenuItem.createButtonMenuItem("go_", nil, nil, function() self:goToCharacterSelect(garbagePatternStepper.value, widthSlider.value, heightSlider.value) end)
    local back = ui.MenuItem.createButtonMenuItem("back", nil, nil, exitMenu)

  self.menu = ui.VerticalMenu({
    hAlign = "center",
    minHeight = 480,
    maxHeight = 540,
    childGap = 8,
    padding = 32,
    width = 600,
  })

  self.menu:addChild(presets)
  self.menu:addChild(width)
  self.menu:addChild(height)
  self.menu:addChild(go)
  self.menu:addChild(back)

  self.uiRoot:addChild(self.menu)
end

function TrainingMenu:update(dt)
  GAME.theme.images.bg_main:update(dt)
  self.menu:receiveInputs()
end

function TrainingMenu:draw()
  GAME.theme.images.bg_main:draw()
  self.uiRoot:draw()
end

return TrainingMenu