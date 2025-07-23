local Game = require("client.src.Game")
local Scene = require("client.src.scenes.Scene")
local consts = require("common.engine.consts")
local logger = require("common.lib.logger")
local ui = require("client.src.ui")
local PuzzleLibrary = require("client.src.PuzzleLibrary")
local PuzzleSetIterator = require("client.src.PuzzleSetIterator")
local PuzzleHierarchyDisplay = require("client.src.graphics.PuzzleHierarchyDisplay")
local PuzzleGame = require("client.src.scenes.PuzzleGame")
local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local LevelPresets      = require("common.data.LevelPresets")
local Stack = require("common.engine.Stack")

-- Scene for the puzzle selection menu
---@class PuzzleMenu : Scene
---@field menu Menu
---@field puzzleLibrary PuzzleLibrary
---@field levelSlider LevelSlider
---@field randomColorButtons ButtonGroup
---@field battleRoom BattleRoom
---@field rootPuzzleSet table
---@field currentPuzzleSetIndices table<integer, integer> integer index into sub puzzle sets
---@field puzzlePreviewStack StackElement
---@field puzzleDescriptionLabel Label
local PuzzleMenu = class(
  function (self, sceneParams)
    self.music = "select_screen"
    self.fallbackMusic = "main"
    -- set in load
    self.levelSlider = nil
    self.randomColorButtons = nil
    self.menu = nil
    self.puzzleLibrary = PuzzleLibrary(GAME.scores)
    self.puzzlePreviewStack = nil
    self.puzzleDescriptionLabel = nil
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

function PuzzleMenu:setupPuzzleSetForStartGame(puzzleSet, puzzleSetIterator)

  if (self.levelSlider and config.puzzle_level ~= self.levelSlider.value) or 
     (self.randomColorsButtons and config.puzzle_randomColors ~= self.randomColorsButtons.value) then
    logger.debug("saving settings...")
    write_conf_file()
  end

  -- Set scene parameters for the puzzle game
  self.battleRoom.sceneParameters = {
    puzzleSet = puzzleSet,
    puzzleSetIterator = puzzleSetIterator
  }

  if PuzzleGame.setupNextPuzzle(self.battleRoom, puzzleSetIterator, puzzleSet) == nil then
    assert(false, "could not setup puzzle")
  end
end

function PuzzleMenu:startGame(puzzleSet, puzzleSetIterator)
  assert(puzzleSetIterator)
  self:setupPuzzleSetForStartGame(puzzleSet, puzzleSetIterator)
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
  -- Reload puzzle statistics to show updated completion status
  if self.rootPuzzleSet then
    self.puzzleLibrary:addStatisticsToPuzzleSet(self.rootPuzzleSet)
  end
  self:refreshMenu()
end

function PuzzleMenu:load(sceneParams)
  self:updateCurrentPuzzleSet()

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

  self.puzzlePreviewStack = ui.StackElement({vAlign = "top", hAlign = "center", x = 0, y = 0, scale=2})

  self.puzzleDescriptionLabel = ui.Label({text = "", x = 0, y = 0, width = 400, height = 100, fontSize = 20, translate = false})
  self.puzzleDescriptionLabel:setFillColors(.2, .2, .2, .8)
  self.puzzleDescriptionLabel:setStrokeColors(1, 1, 1, 1)
  self.puzzleDescriptionLabel:setWrap(400, "left")

  -- Edit puzzle button (initially nil, created when needed)
  self.editPuzzleButton = nil

  -- Create PuzzleHierarchyDisplay for navigation
  self.puzzleHierarchyDisplay = PuzzleHierarchyDisplay({
    puzzleSet = self.rootPuzzleSet,
    puzzleSetIndices = self.currentPuzzleSetIndices,
    width = 0,
    height = 0,
    x = 0,
    y = 56,
    hAlign = "center",
    vAlign = "top"
  })

  self:loadMenu()

  self.previewStackPanel = ui.StackPanel(
    {
      alignment = "top",
      width = 400, -- ideally this is determined by children
      hAlign = "left",
      vAlign = "center",
      x = 0,
      y = 0,
    }
  )

  self.previewStackPanel:addElement(self.puzzlePreviewStack)
  self.previewStackPanel:addElement(self.puzzleDescriptionLabel)

  self.containerStackPanel = ui.StackPanel(
    {
      alignment = "left",
      height = self.menu.height,
      hAlign = "center",
      vAlign = "center",
      x = 0,
      y = 0,
    }
  )

  self.containerStackPanel:addElement(self.menu)
  self.containerStackPanel:addElement(self.previewStackPanel)

  self.uiRoot:addChild(self.containerStackPanel)
  self.uiRoot:addChild(self.puzzleHierarchyDisplay)
  
end

function PuzzleMenu:refreshMenu()

  if self.menu then
    self.containerStackPanel:remove(self.menu)
    self.menu = nil
  end

  self:loadMenu()
  self.containerStackPanel:insertElementAtIndex(self.menu, 1)
end

function PuzzleMenu:loadMenu()

  local menuOptions = {}

  if self:currentlyAtRootLevel() == false then
    menuOptions[#menuOptions+1] = ui.MenuItem.createSliderMenuItem("level", nil, nil, self.levelSlider)
    menuOptions[#menuOptions+1] = ui.MenuItem.createToggleButtonGroupMenuItem("randomColors", nil, nil, self.randomColorsButtons)
    for index, value in ipairs(menuOptions) do
      value.onSelectedFunction = self:clearPreviewFunction()
    end
  end

  if self:currentlyAtRootLevel() == false then
    menuOptions[#menuOptions + 1] = self:menuItemToPlayPuzzleSet(self.rootPuzzleSet, self.currentPuzzleSetIndices, nil)
  end

  local currentPuzzleSet = self.rootPuzzleSet:getPuzzleSetFromIndices(self.currentPuzzleSetIndices)

  for index, currentPuzzleSet in ipairs(currentPuzzleSet.puzzleSets) do
    local nextIndices = deepcpy(self.currentPuzzleSetIndices)
    nextIndices[#nextIndices+1] = index
    menuOptions[#menuOptions + 1] = self:menuItemToViewPuzzleSet(self.rootPuzzleSet, nextIndices, index)
  end

  for index, currentPuzzle in ipairs(currentPuzzleSet.puzzles) do
    menuOptions[#menuOptions + 1] = self:menuItemToPlayPuzzleSet(self.rootPuzzleSet, self.currentPuzzleSetIndices, index)
  end

  if self:currentlyAtRootLevel() == false then
    local menuItem = self:menuItemToTrainWithIterator(self.currentPuzzleSetIndices)
    if menuItem then
      menuOptions[#menuOptions + 1] = menuItem
    end
  end

  menuOptions[#menuOptions + 1] = ui.MenuItem.createButtonMenuItem("back", nil, true, function()
      GAME.theme:playCancelSfx()
      if self:currentlyAtRootLevel() then
        self:exit()
      else
        table.remove(self.currentPuzzleSetIndices)
        self:updateCurrentPuzzleSet()
        self:refreshMenu()
      end
    end)

  self.menu = ui.Menu({
    x = 400,
    y = 0,
    hAlign = "center",
    vAlign = "center",
    menuItems = menuOptions,
    height = themes[config.theme].main_menu_max_height
  })
end

function PuzzleMenu:currentlyAtRootLevel()
  return #self.currentPuzzleSetIndices == 0
end

function PuzzleMenu:setPuzzleDescription(puzzleDescription)
  self.puzzleDescriptionLabel:setText(puzzleDescription, nil, false)
end

function PuzzleMenu:clearPreviewFunction()
  return function ()
    self.puzzlePreviewStack:setStack(nil)
    self:setPuzzleDescription(nil)
    -- Remove edit button if it exists
    if self.editPuzzleButton then
      self.previewStackPanel:remove(self.editPuzzleButton)
      self.editPuzzleButton = nil
    end
  end
end

function PuzzleMenu:updatePuzzlePreviewStackForPuzzle(puzzle)
  local stack = self:getDisplayStack(puzzle)
  self.puzzlePreviewStack:setStack(stack)
end

function PuzzleMenu:previewFunctionForPuzzleSet(puzzleSet, puzzleSetIndices, index)
  local currentPuzzleSet = self.rootPuzzleSet:getPuzzleSetFromIndices(puzzleSetIndices)
  if currentPuzzleSet then
    return function ()
      local puzzleSetIterator = PuzzleSetIterator.makePuzzleSetIterator(puzzleSet, puzzleSetIndices, index)
      local firstIndices = puzzleSetIterator:nextPuzzle()
      if firstIndices then
        local puzzle = PuzzleSetIterator.getPuzzleFromIndices(self.rootPuzzleSet, firstIndices)
        if puzzle then
          self:updatePuzzlePreviewStackForPuzzle(puzzle)
        end
      end
      self:setPuzzleDescription(currentPuzzleSet.localizedDescription)
      
      -- Create edit button for individual puzzles (not puzzle sets)
      if currentPuzzleSet.puzzles and currentPuzzleSet.puzzles[index] then
        self:createEditPuzzleButton(currentPuzzleSet, index)
      end
    end
  end
end

function PuzzleMenu:createEditPuzzleButton(puzzleSet, index)
  -- Remove existing edit button if any
  if self.editPuzzleButton then
    self.previewStackPanel:remove(self.editPuzzleButton)
  end
  
  -- Create new edit button with embedded puzzle data
  self.editPuzzleButton = ui.TextButton({
    label = ui.Label({text = "Edit Puzzle"}),
    width = 120,
    height = 30,
    hAlign = "center",
    vAlign = "top",
    x = 0,
    y = 0,
    onClick = function()
      self:openPuzzleEditor(puzzleSet, index)
    end
  })
  
  self.previewStackPanel:addElement(self.editPuzzleButton)
end

function PuzzleMenu:openPuzzleEditor(puzzleSet, index)
  -- Create a match for the editor like BattleRoom does
  local puzzle = puzzleSet.puzzles[index]
  local gameMode = puzzle:toGameMode()
  local BattleRoom = require("client.src.BattleRoom")
  local tempBattleRoom = BattleRoom.createLocalFromGameMode(gameMode)
  tempBattleRoom.panelSource = puzzleSet.puzzles[index]:toPanelSource(false)
  if not tempBattleRoom then
    logger.warn("Failed to create BattleRoom for puzzle editor")
    return
  end
  
  if not tempBattleRoom.players[1].inputConfiguration then
    tempBattleRoom.players[1]:setInputMethod("touch")
    tempBattleRoom.players[1]:restrictInputs(GAME.input.mouse)
  end
  
  local match = tempBattleRoom:createMatch()
  
  -- Start the match to position stacks properly
  match:start()
  
  -- Find the puzzle set with fileSource and adjust the path
  local sourceRootPuzzleSet = self.rootPuzzleSet
  local adjustedPath = {}
  
  -- Walk down the hierarchy to find the first puzzle set with a fileSource
  for i, pathIndex in ipairs(self.currentPuzzleSetIndices) do
    if sourceRootPuzzleSet.puzzleSets[pathIndex] and sourceRootPuzzleSet.puzzleSets[pathIndex].fileSource then
      sourceRootPuzzleSet = sourceRootPuzzleSet.puzzleSets[pathIndex]
      -- Copy the remaining path after this point
      for j = i + 1, #self.currentPuzzleSetIndices do
        adjustedPath[#adjustedPath + 1] = self.currentPuzzleSetIndices[j]
      end
      break
    else
      sourceRootPuzzleSet = sourceRootPuzzleSet.puzzleSets[pathIndex]
    end
  end
  
  local PuzzleEditorScene = require("client.src.scenes.PuzzleEditorScene")
  local editor = PuzzleEditorScene({
    match = match, 
    puzzleSet = puzzleSet, 
    puzzleIndex = index,
    rootPuzzleSet = sourceRootPuzzleSet,
    puzzleSetPath = adjustedPath
  })
  editor:load()
  GAME.navigationStack:push(editor)
end

function PuzzleMenu:menuItemToPlayPuzzleSet(puzzleSet, puzzleSetIndices, index)
  assert(puzzleSet)
  assert(puzzleSetIndices)
  local textString = loc("start")
  if index then
    textString = loc("rp_browser_info_puzzle") .. " " .. index
  end
  if index then
    local nextIndices = deepcpy(puzzleSetIndices)
    nextIndices[#nextIndices+1] = index
    local puzzle = PuzzleSetIterator.getPuzzleFromIndices(puzzleSet, nextIndices)
    assert(puzzle)
    if puzzle.puzzleEverBeaten then
      textString = textString .. " +"
    end
  end
  -- Create a puzzle set iterator for the current puzzle set
  local puzzleSetIterator = PuzzleSetIterator.makePuzzleSetIterator(puzzleSet, puzzleSetIndices, index)
  assert(puzzleSetIterator:totalPuzzleCount() > 0)
  local result = ui.MenuItem.createButtonMenuItem(textString, nil, false, function()
    self:startGame(puzzleSet, puzzleSetIterator)
  end)

  result.onSelectedFunction = self:previewFunctionForPuzzleSet(puzzleSet, puzzleSetIndices, index)

  return result
end

function PuzzleMenu:menuItemToViewPuzzleSet(puzzleSet, puzzleSetIndices, index)
  local currentPuzzleSet = self.rootPuzzleSet:getPuzzleSetFromIndices(puzzleSetIndices)
  local result = ui.MenuItem.createButtonMenuItem(currentPuzzleSet.localizedSetName, nil, false, function() 
    GAME.theme:playValidationSfx()
    self.currentPuzzleSetIndices[#self.currentPuzzleSetIndices+1] = index
    self:updateCurrentPuzzleSet()
    self:refreshMenu()
  end)

  result.onSelectedFunction = self:previewFunctionForPuzzleSet(puzzleSet, puzzleSetIndices, index)

  return result
end

function PuzzleMenu:menuItemToTrainWithIterator(puzzleSetIndices)
  -- Get the training puzzle count by temporarily getting the first puzzle
  local trainingPuzzleSetIterator = PuzzleSetIterator.makeTrainingOrderIterator(self.rootPuzzleSet, puzzleSetIndices, self.puzzleLibrary)
  local puzzleCount = trainingPuzzleSetIterator:totalPuzzleCount()
  
  if puzzleCount == 0 then
    return nil
  end

  local trainingSetName = loc("puzzle_training") .. " " .. puzzleCount
  local result = ui.MenuItem.createButtonMenuItem(trainingSetName, nil, false, function() 
    self:startGame(self.rootPuzzleSet, trainingPuzzleSetIterator)
  end)

  -- Preview the first training puzzle
  result.onSelectedFunction = function()
    local previewIterator = PuzzleSetIterator.makeTrainingOrderIterator(self.rootPuzzleSet, puzzleSetIndices, self.puzzleLibrary)
    local firstIndices = previewIterator:nextPuzzle()
    if firstIndices then
      local puzzle = PuzzleSetIterator.getPuzzleFromIndices(self.rootPuzzleSet, firstIndices)
      if puzzle then
        self:updatePuzzlePreviewStackForPuzzle(puzzle)
        self:setPuzzleDescription("")
      end
    end
  end

  return result
end

function PuzzleMenu:updateCurrentPuzzleSet()
  if self.rootPuzzleSet == nil then
    self.rootPuzzleSet = self.puzzleLibrary:getDefaultPuzzleSet()
  end

  -- Update hierarchy display if it exists
  if self.puzzleHierarchyDisplay then
    self.puzzleHierarchyDisplay:updateDisplay(self.rootPuzzleSet, self.currentPuzzleSetIndices)
  end
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