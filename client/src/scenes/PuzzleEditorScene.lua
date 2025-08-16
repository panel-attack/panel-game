local GameBase = require("client.src.scenes.GameBase")
local TouchInputDetector = require("client.src.TouchInputDetector")
local Panel = require("common.engine.Panel")
local Puzzle = require("common.engine.Puzzle")
local class = require("common.lib.class")
local logger = require("common.lib.logger")
local consts = require("common.engine.consts")
local ui = require("client.src.ui")
local focusable = require("client.src.ui.Focusable")
local directsFocus = require("client.src.ui.FocusDirector")

---@class PuzzleEditorScene : GameBase
---@field puzzleSet PuzzleSet
---@field puzzleIndex integer
---@field originalPuzzle Puzzle
---@field rootPuzzleSet PuzzleSet?
---@field puzzleSetPath table<integer>?
---@field selectedPanelType integer
---@field isEditing boolean
---@field hasUnsavedChanges boolean
---@field touchInputDetector any
---@field rootPanel any
---@field gameViewPanel any
---@field editorPanel any
---@field puzzleGrid any
---@field palettePanel any
---@field paletteButtons table
---@field statusLabel any
local PuzzleEditorScene = class(
  function(self, sceneParams)
    self.puzzleSet = sceneParams.puzzleSet
    self.puzzleIndex = sceneParams.puzzleIndex
    self.originalPuzzle = sceneParams.puzzleSet:getPuzzle(sceneParams.puzzleIndex)
    self.rootPuzzleSet = sceneParams.rootPuzzleSet
    self.puzzleSetPath = sceneParams.puzzleSetPath or {}

    self.selectedPanelType = 1
    self.isEditing = true
    self.hasUnsavedChanges = false
  end,
  GameBase
)

PuzzleEditorScene.name = "PuzzleEditorScene"

function PuzzleEditorScene:customLoad()
  self.touchInputDetector = TouchInputDetector(self.match.stacks[1])

  if self.match.stacks[1] then
    self.match.stacks[1].engine.do_countdown = true
  end

  self:createUI()
  self:setupFocusManagement()

  logger.debug("PuzzleEditorScene loaded successfully")
end

function PuzzleEditorScene:createUI()
  self.rootPanel = ui.StackPanel({
    alignment = "left",
    hAlign = "center",
    vAlign = "center",
    width = consts.CANVAS_WIDTH,
    height = consts.CANVAS_HEIGHT
  })

  self.gameViewPanel = ui.UiElement({
    width = consts.CANVAS_WIDTH - 320,
    height = consts.CANVAS_HEIGHT
  })

  self.puzzleGrid = self:createPuzzleGrid()

  self.editorPanel = ui.StackPanel({
    alignment = "top",
    width = 300,
    height = consts.CANVAS_HEIGHT,
    x = 20,
    y = 20
  })

  local controls = self:createEditorControls()
  for _, control in ipairs(controls) do
    self.editorPanel:addElement(control)
  end

  self.rootPanel:addElement(self.gameViewPanel)
  self.rootPanel:addElement(self.editorPanel)

  self.uiRoot:addChild(self.puzzleGrid)
  self.uiRoot:addChild(self.rootPanel)
end

function PuzzleEditorScene:createPuzzleGrid()
  local stack = self.match.stacks[1]

  local panelSize = 16 * stack.gfxScale
  local scaledOriginX = stack.panelOriginX * stack.gfxScale
  local scaledOriginY = stack.panelOriginY * stack.gfxScale

  local puzzleGridContainer = ui.UiElement({
    x = scaledOriginX,
    y = scaledOriginY,
    width = stack.engine.width * panelSize,
    height = stack.engine.height * panelSize
  })

  for row = 1, stack.engine.height do
    for col = 1, stack.engine.width do
      local panelButton = ui.Button({
        x = (col - 1) * panelSize,
        y = (row - 1) * panelSize,
        width = panelSize - 2,
        height = panelSize - 2,
        backgroundColor = {0.2, 0.2, 0.2, 0.0}, 
        outlineColor = {0.5, 0.5, 0.5, 0.0},
        borderWidth = 1,
        onClick = function()
          -- Convert visual row to engine row (flip vertically)
          local engineRow = stack.engine.height - row + 1
          logger.debug("Grid button clicked at visual row=" .. row .. ", engine row=" .. engineRow .. ", col=" .. col .. ", selectedType=" .. self.selectedPanelType)
          self:editPanel(engineRow, col, self.selectedPanelType)
        end
      })

      puzzleGridContainer:addChild(panelButton)
    end
  end

  return puzzleGridContainer
end

function PuzzleEditorScene:createPaletteButtons()
  local colors = Panel.extendedRegularColorsArray()
  table.insert(colors, 1, 0)  -- empty
  table.insert(colors, 8)     -- shock
  table.insert(colors, 9)     -- colorless

  local palettePanel = ui.UiElement({
    width = 280,
    height = 200
  })

  self.paletteButtons = {}

  -- Arrange buttons in a 3x3 grid with one extra
  local buttonSize = 40
  local spacing = 10
  local buttonsPerRow = 3
  
  for i, color in ipairs(colors) do
    local row = math.floor((i - 1) / buttonsPerRow)
    local col = (i - 1) % buttonsPerRow
    
    local x = col * (buttonSize + spacing)
    local y = row * (buttonSize + spacing)
    
    local button = self:createPanelButtonSmall(color, buttonSize)
    button.x = x
    button.y = y

    if i == 1 then
      button.backgroundColor = {.5, .5, 1, .7}
    end

    self.paletteButtons[i] = {button = button, color = color}
    palettePanel:addChild(button)
  end

  return palettePanel
end

function PuzzleEditorScene:updatePaletteSelection()
  for _, paletteButton in ipairs(self.paletteButtons) do
    if paletteButton.color == self.selectedPanelType then
      paletteButton.button.backgroundColor = {.5, .5, 1, .7}
    else
      paletteButton.button.backgroundColor = {.3, .3, .3, .7}
    end
  end
end

function PuzzleEditorScene:createEditorControls()
  local controls = {}

  controls[#controls + 1] = ui.Label({
    text = "Panel Editor",
    fontSize = 16,
    hAlign = "center",
    translate = false
  })

  controls[#controls + 1] = ui.Label({
    text = "Panel Type:",
    fontSize = 12,
    translate = false
  })

  self.palettePanel = self:createPaletteButtons()
  controls[#controls + 1] = self.palettePanel

  controls[#controls + 1] = ui.TextButton({
    label = ui.Label({text = "Clear Solution"}),
    width = 100,
    height = 25,
    onClick = function() self:clearSolution() end
  })

  controls[#controls + 1] = ui.TextButton({
    label = ui.Label({text = "Save Puzzle"}),
    width = 100,
    height = 25,
    onClick = function() self:savePuzzle() end
  })

  controls[#controls + 1] = ui.TextButton({
    label = ui.Label({text = "Exit Editor"}),
    width = 100,
    height = 25,
    onClick = function() self:exitEditor() end
  })

  self.statusLabel = ui.Label({
    text = "Saved",
    fontSize = 10,
    translate = false
  })
  controls[#controls + 1] = self.statusLabel

  return controls
end

function PuzzleEditorScene:setupFocusManagement()
  focusable(self.editorPanel)
  directsFocus(self)

  ---@diagnostic disable-next-line: undefined-field
  self:setFocus(self.palettePanel)
end

function PuzzleEditorScene:createPanelButton(color)
  return self:createPanelButtonSmall(color, 60)
end

function PuzzleEditorScene:createPanelButtonSmall(color, size)
  if color == 0 then
    -- Empty panel - use a text button
    return ui.TextButton({
      label = ui.Label({
        text = "Empty",
        fontSize = size > 50 and 12 or 8,
        translate = false
      }),
      width = size,
      height = size,
      onClick = function()
        self.selectedPanelType = color
        self:updatePaletteSelection()
        GAME.theme:playValidationSfx()
      end
    })
  elseif color == 9 then
    -- Colorless panel - use the actual panel image
    local stack = self.match.stacks[1]
    local panelsData = panels[stack.panels_dir]
    
    return ui.ImageButton({
      image = panelsData.greyPanel,
      width = size,
      height = size,
      onClick = function()
        self.selectedPanelType = color
        self:updatePaletteSelection()
        GAME.theme:playValidationSfx()
      end
    })
  else
    -- Regular colored panels (1-8) - use the actual panel image
    local stack = self.match.stacks[1]
    local panelsData = panels[stack.panels_dir]
    local panelImage = panelsData.displayIcons[color]
    
    return ui.ImageButton({
      image = panelImage,
      width = size,
      height = size,
      onClick = function()
        self.selectedPanelType = color
        self:updatePaletteSelection()
        GAME.theme:playValidationSfx()
      end
    })
  end
end

function PuzzleEditorScene:getColorName(color)
  local names = {
    [0] = "Empty",
    [1] = "Hearts",
    [2] = "Circles",
    [3] = "Triangles",
    [4] = "Stars",
    [5] = "Diamonds",
    [6] = "Inv Tri",
    [7] = "Squares",
    [8] = "Shock",
    [9] = "Colorless"
  }
  return names[color] or "Unknown"
end

function PuzzleEditorScene:editPanel(row, column, newColor)
  logger.debug("editPanel called: row=" .. row .. ", column=" .. column .. ", newColor=" .. newColor)
  local stack = self.match.stacks[1]

  if row < 1 or row > #stack.engine.panels or column < 1 or column > stack.engine.width then
    logger.warn("editPanel: Invalid coordinates")
    return
  end

  local panel = stack.engine.panels[row][column]

  if panel.color ~= newColor then
    if not self.hasUnsavedChanges then
      self.hasUnsavedChanges = true
      self.statusLabel:setText("* Unsaved changes")
    end

    -- Properly clear all panel state before setting new color
    panel:clear(true, false)
    panel.color = newColor
    panel.stateChanged = true
  end
end

function PuzzleEditorScene:keypressed(key)
  if key == "escape" then
    if self.hasUnsavedChanges then
      self:promptSave()
    else
      self:exitEditor()
    end
  elseif key == "s" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
    self:savePuzzle()
  elseif key >= "0" and key <= "9" then
    local newType = tonumber(key)
    if newType then
      self.selectedPanelType = newType
    end
    self:updatePaletteSelection()
  end
end

function PuzzleEditorScene:savePuzzle()
  local stack = self.match.stacks[1]
  if not stack then
    logger.warn("Error: No stack available for saving")
    return
  end

  local newPuzzleString = Puzzle.toPuzzleString(stack.engine.panels)
  local updatedPuzzle = Puzzle.newPuzzleWithPuzzleString(newPuzzleString, self.originalPuzzle)

  assert(self.rootPuzzleSet)
  assert(self.rootPuzzleSet.fileSource)

  local targetPuzzleSet = self.rootPuzzleSet
  for _, pathIndex in ipairs(self.puzzleSetPath) do
    targetPuzzleSet = targetPuzzleSet.puzzleSets[pathIndex]
  end

  targetPuzzleSet:updatePuzzle(self.puzzleIndex, updatedPuzzle)
  
  self.rootPuzzleSet:saveTargetPuzzleToFile(targetPuzzleSet, self.puzzleIndex, updatedPuzzle)

  self.hasUnsavedChanges = false
  self.statusLabel:setText("Saved")
  logger.debug("Puzzle saved successfully!")
end

function PuzzleEditorScene:promptSave()
  logger.debug("Auto-saving before exit...")
  self:savePuzzle()
  self:exitEditor()
end

function PuzzleEditorScene:clearSolution()
  -- Clear the solution from the original puzzle
  self.originalPuzzle.solution = nil
  
  -- Mark as having unsaved changes
  if not self.hasUnsavedChanges then
    self.hasUnsavedChanges = true
    self.statusLabel:setText("* Unsaved changes")
  end
  
  logger.debug("Puzzle solution cleared")
end

function PuzzleEditorScene:exitEditor()
  -- Clean up input configuration to prevent double claiming
  if self.match and self.match.stacks[1] and self.match.stacks[1].player then
    self.match.stacks[1].player:unrestrictInputs()
  end
  GAME.navigationStack:pop()
end

return PuzzleEditorScene