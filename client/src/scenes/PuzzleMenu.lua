local Scene = require("client.src.scenes.Scene")
local consts = require("common.engine.consts")
local logger = require("common.lib.logger")
local ui = require("client.src.ui")
local PuzzleLibrary = require("client.src.PuzzleLibrary")
local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local MessageTransition = require("client.src.scenes.Transitions.MessageTransition")
local LevelPresets      = require("common.data.LevelPresets")
local ClientMatch = require("client.src.ClientMatch")
local Stack = require("common.engine.Stack")

-- Scene for the puzzle selection menu
---@class PuzzleMenu : Scene
---@field menu Menu
---@field puzzleLabel Label
---@field levelSlider LevelSlider
---@field randomColorButtons ButtonGroup
---@field battleRoom BattleRoom
---@field rootPuzzleSet table
---@field currentPuzzleSetIndices table<integer, integer> integer index into sub puzzle sets
---@field puzzlePreviewStack StackElement
local PuzzleMenu = class(
  function (self, sceneParams)
    self.music = "select_screen"
    self.fallbackMusic = "main"
    -- set in load
    self.levelSlider = nil
    self.randomColorButtons = nil
    self.menu = nil
    self.puzzleLabel = nil
    self.puzzleLibrary = PuzzleLibrary(GAME.scores)
    self.puzzlePreviewStack = nil
    self.battleRoom = sceneParams.battleRoom
    self.rootPuzzleSet = nil
    self.currentPuzzleSetIndices = {}

    self:load(sceneParams)
  end,
  Scene
)

PuzzleMenu.name = "PuzzleMenu"

local BUTTON_WIDTH = 60
local BUTTON_HEIGHT = 25

function PuzzleMenu:setupPuzzleSet(puzzleSet, index)
  if not index then
    index = 1
  end

  if config.puzzle_level ~= self.levelSlider.value or config.puzzle_randomColors ~= self.randomColorsButtons.value then
    logger.debug("saving settings...")
    write_conf_file()
  end

  GAME.localPlayer:setPuzzleSet(puzzleSet, index)

  local player = self.battleRoom.players[1]
  local puzzle = player.settings.puzzleSet.puzzles[index]
  self.battleRoom:setGameMode(puzzle:toGameMode())
end

function PuzzleMenu:startGame(puzzleSet, index)
  self:setupPuzzleSet(puzzleSet, index)
  local player = self.battleRoom.players[1]
  player:setWantsReady(true)
  GAME.theme:playValidationSfx()
end

function PuzzleMenu:exit()
  GAME.theme:playValidationSfx()
  self.battleRoom:shutdown()
  GAME.navigationStack:pop()
end


function PuzzleMenu:refresh()
  self:updateCurrentPuzzleSet()
  self:refreshMenu()
end

function PuzzleMenu:load(sceneParams)
  self.puzzlePreviewStack = ui.StackElement({vAlign = "center", x = 800, y = 0})
  self.uiRoot:addChild(self.puzzlePreviewStack)


  local tickLength = 16
  self.levelSlider = ui.LevelSlider({
      tickLength = tickLength,
      value = config.puzzle_level or 5,
      onValueChange = function(s)
        GAME.theme:playMoveSfx()
        config.puzzle_level = s.value
        GAME.localPlayer:setLevel(s.value)
        GAME.localPlayer:setLevelData(LevelPresets.getModern(s.value))
      end
    })

  self.randomColorsButtons = ui.ButtonGroup(
    {
      buttons = {
        ui.TextButton({label = ui.Label({text = "op_off"}), width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
        ui.TextButton({label = ui.Label({text = "op_on"}), width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
      },
      values = {false, true},
      selectedIndex = config.puzzle_randomColors and 2 or 1,
      onChange = function(group, value)
        GAME.theme:playMoveSfx()
        config.puzzle_randomColors = value
      end
    }
  )

  self.randomlyFlipPuzzleButtons = ui.ButtonGroup(
    {
      buttons = {
        ui.TextButton({label = ui.Label({text = "op_off"}), width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
        ui.TextButton({label = ui.Label({text = "op_on"}), width = BUTTON_WIDTH, height = BUTTON_HEIGHT}),
      },
      values = {false, true},
      selectedIndex = config.puzzle_randomFlipped and 2 or 1,
      onChange = function(group, value)
        GAME.theme:playMoveSfx()
        config.puzzle_randomFlipped = value
      end
    }
  )

  self:refreshMenu()

  local x, y = unpack(themes[config.theme].main_menu_screen_pos)
  self.puzzleLabel = ui.Label({text = "pz_puzzles", x = x - 10, y = y - 40})
  self.uiRoot:addChild(self.puzzleLabel)
end

function PuzzleMenu:refreshMenu()

  if self.menu then
    self.menu:detach()
    self.menu = nil
  end

  local menuOptions = {}

  if self:currentlyAtRootLevel() == false then
    menuOptions[#menuOptions+1] = ui.MenuItem.createSliderMenuItem("level", nil, nil, self.levelSlider)
    menuOptions[#menuOptions+1] = ui.MenuItem.createToggleButtonGroupMenuItem("randomColors", nil, nil, self.randomColorsButtons)
    menuOptions[#menuOptions+1] = ui.MenuItem.createToggleButtonGroupMenuItem("randomHorizontalFlipped", nil, nil, self.randomlyFlipPuzzleButtons)
    for index, value in ipairs(menuOptions) do
      value.onSelectedFunction = self:clearPreviewFunction()
    end
  end

  if self.currentPuzzleSet == nil then
    self:updateCurrentPuzzleSet()
  end

  if self:currentlyAtRootLevel() == false then
    menuOptions[#menuOptions + 1] = self:menuItemToPlayPuzzleSet(self.currentPuzzleSet, self.flatPuzzleSet, 1, nil)
  end

  for index, currentPuzzleSet in ipairs(self.currentPuzzleSet.puzzleSets) do
    menuOptions[#menuOptions + 1] = self:menuItemToViewPuzzleSet(currentPuzzleSet, index)
  end

  for index, currentPuzzle in ipairs(self.currentPuzzleSet.puzzles) do
    menuOptions[#menuOptions + 1] = self:menuItemToPlayPuzzleSet(self.currentPuzzleSet, self.flatPuzzleSet, index, currentPuzzle)
  end

  if self:currentlyAtRootLevel() == false then
    local trainingPuzzleSet = self.currentTrainingPuzzleSet
    if #trainingPuzzleSet.puzzles > 0 then
      menuOptions[#menuOptions + 1] = self:menuItemToTrainPuzzleSet(trainingPuzzleSet)
    end
  end

  menuOptions[#menuOptions + 1] = ui.MenuItem.createButtonMenuItem("back", nil, nil, function()
      GAME.theme:playCancelSfx()
      if self:currentlyAtRootLevel() then
        self:exit()
      else
        table.remove(self.currentPuzzleSetIndices)
        self:updateCurrentPuzzleSet()
        self:refreshMenu()
      end
    end)

  self.menu = ui.Menu.createCenteredMenu(menuOptions)
  self.uiRoot:addChild(self.menu)
end

function PuzzleMenu:currentlyAtRootLevel()
  return #self.currentPuzzleSetIndices == 0
end

function PuzzleMenu:setPreviewPanelBoard(previewStack)
  self.puzzlePreviewStack:setStack(previewStack)
end

function PuzzleMenu:clearPreviewFunction()
  return function ()
    self.puzzlePreviewStack:setStack(nil)
  end
end

function PuzzleMenu:previewFunctionForPuzzleSet(puzzleSet, index)
  if puzzleSet then
    local flatPuzzleSet = self.puzzleLibrary:flattenedPuzzleSetForPuzzleSet(puzzleSet)
    return function ()
      local stack = self:getDisplayStack(flatPuzzleSet.puzzles[index])
      self.puzzlePreviewStack:setStack(stack)
    end
  end
end

function PuzzleMenu:menuItemToPlayPuzzleSet(puzzleSet, flatPuzzleSet, index, puzzle)
  local textString = loc("start")
  if puzzle then
    textString = loc("rp_browser_info_puzzle") .. " " .. index
  end
  if puzzle and puzzle.puzzleEverBeaten then
    textString = textString .. " +"
  end
  local result = ui.MenuItem.createButtonMenuItem(textString, nil, false, function()
    self:startGame(flatPuzzleSet, index)
  end)

  result.onSelectedFunction = self:previewFunctionForPuzzleSet(flatPuzzleSet, index)

  return result
end

function PuzzleMenu:menuItemToViewPuzzleSet(puzzleSet, index)
  local result = ui.MenuItem.createButtonMenuItem(puzzleSet.setName, nil, false, function() 
    GAME.theme:playValidationSfx()
    self.currentPuzzleSetIndices[#self.currentPuzzleSetIndices+1] = index
    self:updateCurrentPuzzleSet()
    self:refreshMenu()
  end)

  result.onSelectedFunction = self:previewFunctionForPuzzleSet(puzzleSet, 1)

  return result
end

function PuzzleMenu:menuItemToTrainPuzzleSet(puzzleSet)
  local result = ui.MenuItem.createButtonMenuItem(puzzleSet.setName, nil, false, function() 
    -- GAME.theme:playValidationSfx()
    self:startGame(puzzleSet)
  end)

  result.onSelectedFunction = self:previewFunctionForPuzzleSet(puzzleSet, 1)

  return result
end

function PuzzleMenu:updateCurrentPuzzleSet()
  if self.rootPuzzleSet == nil then
    local directory = consts.PUZZLES_SAVE_DIRECTORY
    self.rootPuzzleSet = self.puzzleLibrary:puzzleSetFromPath(directory)
  end

  self.currentPuzzleSet = self.rootPuzzleSet
  for index, value in ipairs(self.currentPuzzleSetIndices) do
    self.currentPuzzleSet = self.currentPuzzleSet.puzzleSets[value]
  end
  self.flatPuzzleSet = self.puzzleLibrary:flattenedPuzzleSetForPuzzleSet(self.currentPuzzleSet)
  self.currentTrainingPuzzleSet = self.puzzleLibrary:currentTrainingPuzzleSetForPuzzleSet(self.currentPuzzleSet)
end

function PuzzleMenu:update(dt)
  self.menu:receiveInputs()
end

function PuzzleMenu:draw()
  themes[config.theme].images.bg_main:draw()
  self.uiRoot:draw()
end

---@param puzzle Puzzle
function PuzzleMenu:getDisplayStack(puzzle)
  local gameMode = puzzle:toGameMode()
  local args = {
    which = 1,
    levelData = LevelPresets.getModern(config.puzzle_level or 5),
    is_local = false,
    stackOverConditions = gameMode.matchRules.stackOverConditions,
    stackWinConditions = gameMode.matchRules.stackWinConditions,
    panelSource = puzzle:toPanelSource(),
    inputMethod = "controller",
    stackSetupModifications = gameMode.matchRules.stackSetupModifications or {},
    engineVersion = consts.ENGINE_VERSION,
  }
  local engineStack = Stack(args)

  local playerStack = GAME.localPlayer:createClientStack(engineStack)
  playerStack:moveForRenderIndex(1)
  engineStack:starting_state()

  return playerStack
end

return PuzzleMenu