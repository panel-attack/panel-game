local Panel = require("common.engine.Panel")
local Puzzle = require("common.engine.Puzzle")
local class = require("common.lib.class")
local logger = require("common.lib.logger")
local consts = require("common.engine.consts")
local ui = require("client.src.ui")
local TouchInputDetector = require("client.src.TouchInputDetector")
local GameBase = require("client.src.scenes.GameBase")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local focusable = require("client.src.ui.Focusable")
local directsFocus = require("client.src.ui.FocusDirector")
local PuzzleEditorStackOverlay = require("client.src.ui.PuzzleEditorStackOverlay")

---@class PuzzleEditorScene : GameBase
---@field puzzleSet PuzzleSet
---@field puzzleIndex integer
---@field originalPuzzle Puzzle
---@field rootPuzzleSet PuzzleSet?
---@field puzzleSetPath table<integer>
---@field selectedPanelType integer
---@field cursorMode boolean
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
    self.cursorMode = false
    self.garbageMode = false
    self.shockGarbageMode = false
    self.isDraggingGarbage = false
    self.garbageDragStart = nil
    self.garbageDragCurrent = nil
    self.garbageIdCounter = 0
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

    -- Initialize cursor position from puzzle if set
    if self.originalPuzzle.cursorStartLeft then
      self.match.stacks[1].engine.cur_row = self.originalPuzzle.cursorStartLeft.row
      self.match.stacks[1].engine.cur_col = self.originalPuzzle.cursorStartLeft.column
    end

    -- Initialize garbage ID counter from stack's garbageCreatedCount to avoid ID collisions
    ---@diagnostic disable-next-line: invisible
    self.garbageIdCounter = self.match.stacks[1].engine.garbageCreatedCount
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

  -- Create single overlay for all touch interactions and drawing
  local stackOverlay = PuzzleEditorStackOverlay({
    x = scaledOriginX,
    y = scaledOriginY,
    width = stack.engine.width * panelSize,
    height = stack.engine.height * panelSize,
    stack = stack,
    puzzleEditor = self
  })

  -- Store reference for access by other methods
  self.puzzleStackOverlay = stackOverlay

  return stackOverlay
end

function PuzzleEditorScene:createPaletteButtons()
  local colors = Panel.extendedRegularColorsArray()
  table.insert(colors, 1, 0)  -- empty
  table.insert(colors, 8)     -- shock
  table.insert(colors, 9)     -- colorless

  local palettePanel = ui.UiElement({
    width = 280,
    height = 300
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

  -- Add cursor button after the colorless button
  local cursorIndex = #colors + 1
  local row = math.floor((cursorIndex - 1) / buttonsPerRow)
  local col = (cursorIndex - 1) % buttonsPerRow

  local x = col * (buttonSize + spacing)
  local y = row * (buttonSize + spacing)

  local cursorButton = self:createCursorButton(buttonSize)
  cursorButton.x = x
  cursorButton.y = y

  self.paletteButtons[cursorIndex] = {button = cursorButton, color = "cursor"}
  palettePanel:addChild(cursorButton)

  -- Add garbage button
  local garbageIndex = cursorIndex + 1
  row = math.floor((garbageIndex - 1) / buttonsPerRow)
  col = (garbageIndex - 1) % buttonsPerRow

  x = col * (buttonSize + spacing)
  y = row * (buttonSize + spacing)

  local garbageButton = self:createGarbageButton(buttonSize)
  garbageButton.x = x
  garbageButton.y = y

  self.paletteButtons[garbageIndex] = {button = garbageButton, color = "garbage"}
  palettePanel:addChild(garbageButton)

  -- Add shock garbage button
  local shockGarbageIndex = garbageIndex + 1
  row = math.floor((shockGarbageIndex - 1) / buttonsPerRow)
  col = (shockGarbageIndex - 1) % buttonsPerRow

  x = col * (buttonSize + spacing)
  y = row * (buttonSize + spacing)

  local shockGarbageButton = self:createShockGarbageButton(buttonSize)
  shockGarbageButton.x = x
  shockGarbageButton.y = y

  self.paletteButtons[shockGarbageIndex] = {button = shockGarbageButton, color = "shock_garbage"}
  palettePanel:addChild(shockGarbageButton)

  return palettePanel
end

function PuzzleEditorScene:updatePaletteSelection()
  for _, paletteButton in ipairs(self.paletteButtons) do
    if (paletteButton.color == self.selectedPanelType and not self.cursorMode and not self.garbageMode and not self.shockGarbageMode) or
       (paletteButton.color == "cursor" and self.cursorMode) or
       (paletteButton.color == "garbage" and self.garbageMode) or
       (paletteButton.color == "shock_garbage" and self.shockGarbageMode) then
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
        self.cursorMode = false
        self.garbageMode = false
        self.shockGarbageMode = false
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
        self.cursorMode = false
        self.garbageMode = false
        self.shockGarbageMode = false
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
        self.cursorMode = false
        self.garbageMode = false
        self.shockGarbageMode = false
        self:updatePaletteSelection()
        GAME.theme:playValidationSfx()
      end
    })
  end
end

function PuzzleEditorScene:createCursorButton(size)
  local cursorImage = GAME.theme.images.cursor[1].image

  return ui.ImageButton({
    image = cursorImage,
    width = size,
    height = size,
    onClick = function()
      self.cursorMode = true
      self.garbageMode = false
      self.shockGarbageMode = false
      self:updatePaletteSelection()
      GAME.theme:playValidationSfx()
    end
  })
end

function PuzzleEditorScene:createGarbageButton(size)
  local stack = self.match.stacks[1]
  local garbageImage = stack.character.images.pop

  return ui.ImageButton({
    image = garbageImage,
    width = size,
    height = size,
    onClick = function()
      self.garbageMode = true
      self.shockGarbageMode = false
      self.cursorMode = false
      self:updatePaletteSelection()
      GAME.theme:playValidationSfx()
    end
  })
end

function PuzzleEditorScene:createShockGarbageButton(size)
  local stack = self.match.stacks[1]
  local panelsData = panels[stack.panels_dir]
  local shockImages = panelsData.images.metals

  local dpiscale = shockImages.mid:getDPIScale()
  local filterMin, filterMag = shockImages.mid:getFilter()

  local garbageImage = GraphicsUtil.renderToImage(
    size,
    size,
    function()
      local leftImage = shockImages.left
      local midImage = shockImages.mid
      local rightImage = shockImages.right

      local targetWidth = size * 0.8
      local targetHeight = size * 0.6

      local leftWidth = targetWidth * 0.25
      love.graphics.draw(leftImage, size * 0.1, size * 0.2, 0, leftWidth / leftImage:getWidth(), targetHeight / leftImage:getHeight())

      local midWidth = targetWidth * 0.5
      local midX = size * 0.1 + leftWidth
      love.graphics.draw(midImage, midX, size * 0.2, 0, midWidth / midImage:getWidth(), targetHeight / midImage:getHeight())

      local rightWidth = targetWidth * 0.25
      local rightX = midX + midWidth
      love.graphics.draw(rightImage, rightX, size * 0.2, 0, rightWidth / rightImage:getWidth(), targetHeight / rightImage:getHeight())
    end,
    dpiscale,
    filterMin,
    filterMag
  )

  return ui.ImageButton({
    image = garbageImage,
    width = size,
    height = size,
    onClick = function()
      self.shockGarbageMode = true
      self.garbageMode = false
      self.cursorMode = false
      self:updatePaletteSelection()
      GAME.theme:playValidationSfx()
    end
  })
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

function PuzzleEditorScene:startDrag(row, column)
  if self.garbageMode or self.shockGarbageMode then
    self.isDraggingGarbage = true
    self.garbageDragStart = {row = row, column = column}
    self.garbageDragCurrent = {row = row, column = column}
    logger.debug("Started garbage drag at row=" .. row .. ", column=" .. column)
  else
    -- For normal panel editing, just place the panel immediately
    self:editPanel(row, column, self.selectedPanelType)
  end
end

function PuzzleEditorScene:updateDrag(row, column)
  if self.isDraggingGarbage then
    self.garbageDragCurrent = {row = row, column = column}
  else
    -- For normal panel editing, continue painting panels
    self:editPanel(row, column, self.selectedPanelType)
  end
end

function PuzzleEditorScene:finishDrag(row, column)
  if self.isDraggingGarbage then
    self.garbageDragCurrent = {row = row, column = column}
    self:placeGarbageBlock()
    self:cancelDrag()
  end
end

function PuzzleEditorScene:cancelDrag()
  self.isDraggingGarbage = false
  self.garbageDragStart = nil
  self.garbageDragCurrent = nil
end

function PuzzleEditorScene:clearGarbageBlock(row, column)
  local stack = self.match.stacks[1]
  local panel = stack.engine.panels[row][column]

  -- If this panel is not garbage, nothing to clear
  if not panel.isGarbage then
    return
  end

  local garbageId = panel.garbageId

  -- Find and clear all panels with the same garbage ID
  for r = 1, stack.engine.height do
    for c = 1, stack.engine.width do
      local p = stack.engine.panels[r][c]
      if p.isGarbage and p.garbageId == garbageId then
        p:clear(true, false)
        p.color = 0  -- Set to empty
        p.stateChanged = true
      end
    end
  end
end


function PuzzleEditorScene:placeGarbageBlock()
  if not self.garbageDragStart or not self.garbageDragCurrent then
    return
  end

  local stack = self.match.stacks[1]
  local startRow = self.garbageDragStart.row
  local startCol = self.garbageDragStart.column
  local endRow = self.garbageDragCurrent.row
  local endCol = self.garbageDragCurrent.column

  -- Calculate garbage dimensions and position
  local minRow = math.min(startRow, endRow)
  local maxRow = math.max(startRow, endRow)
  local minCol = math.min(startCol, endCol)
  local maxCol = math.max(startCol, endCol)

  local width = maxCol - minCol + 1
  local height = maxRow - minRow + 1

  -- Shock garbage is limited to 1 panel high
  if self.shockGarbageMode and height > 1 then
    -- Keep only the start row for shock garbage
    maxRow = startRow
    minRow = startRow
    height = 1
  elseif height > 1 and not self.shockGarbageMode then
    -- Regular garbage can expand to 6-wide when dragging vertically
    minCol = 1
    maxCol = 6
    width = 6
  end

  -- Ensure we don't exceed board boundaries
  if maxCol > stack.engine.width then
    local excess = maxCol - stack.engine.width
    minCol = minCol - excess
    maxCol = stack.engine.width
  end
  if minCol < 1 then
    local deficit = 1 - minCol
    minCol = 1
    maxCol = maxCol + deficit
    width = maxCol - minCol + 1
  end
  if maxRow > stack.engine.height then
    local excess = maxRow - stack.engine.height
    minRow = minRow - excess
    maxRow = stack.engine.height
  end
  if minRow < 1 then
    minRow = 1
    height = maxRow - minRow + 1
  end

  -- Clear any intersecting garbage blocks
  local clearedGarbageIds = {}
  for row = minRow, maxRow do
    for col = minCol, maxCol do
      if row >= 1 and row <= stack.engine.height and col >= 1 and col <= stack.engine.width then
        local panel = stack.engine.panels[row][col]
        if panel.isGarbage and not clearedGarbageIds[panel.garbageId] then
          self:clearGarbageBlock(row, col)
          clearedGarbageIds[panel.garbageId] = true
        end
      end
    end
  end

  -- Create garbage block
  self.garbageIdCounter = self.garbageIdCounter + 1
  local garbageId = self.garbageIdCounter

  for row = minRow, maxRow do
    for col = minCol, maxCol do
      if row >= 1 and row <= stack.engine.height and col >= 1 and col <= stack.engine.width then
        local panel = stack.engine.panels[row][col]
        panel:clear(true, false)
        panel.isGarbage = true
        panel.metal = self.shockGarbageMode
        panel.color = 9 -- colorless
        panel.garbageId = garbageId
        panel.x_offset = col - minCol
        panel.y_offset = row - minRow
        panel.width = width
        panel.height = height
        panel.stateChanged = true
      end
    end
  end

  if not self.hasUnsavedChanges then
    self.hasUnsavedChanges = true
    self.statusLabel:setText("* Unsaved changes")
  end

  logger.debug("Placed " .. (self.shockGarbageMode and "shock " or "") .. "garbage block: " .. width .. "x" .. height .. " at (" .. minRow .. "," .. minCol .. ")")
end

function PuzzleEditorScene:editPanel(row, column, newColor)
  logger.debug("editPanel called: row=" .. row .. ", column=" .. column .. ", newColor=" .. newColor .. ", cursorMode=" .. tostring(self.cursorMode))
  local stack = self.match.stacks[1]

  if row < 1 or row > #stack.engine.panels or column < 1 or column > stack.engine.width then
    logger.warn("editPanel: Invalid coordinates")
    return
  end

  if self.cursorMode then
    -- Handle cursor position setting
    if column >= 1 and column <= 5 then
      -- Set cursor start position
      self.originalPuzzle.cursorStartLeft = {row = row, column = column}
      -- Update the live stack cursor position
      stack.engine.cur_row = row
      stack.engine.cur_col = column
      logger.debug("Cursor start position set to row=" .. row .. ", column=" .. column)
    else
      -- Remove cursor start position if clicked outside columns 1-5
      self.originalPuzzle.cursorStartLeft = nil
      -- Reset cursor to default position when removed
      stack.engine.cur_row = 7
      stack.engine.cur_col = 3
      logger.debug("Cursor start position removed")
    end

    if not self.hasUnsavedChanges then
      self.hasUnsavedChanges = true
      self.statusLabel:setText("* Unsaved changes")
    end

    -- Stay in cursor mode until user selects a different tool
    return
  end

  if self.garbageMode or self.shockGarbageMode then
    -- Garbage mode handled by drag events, not single clicks
    return
  end

  local panel = stack.engine.panels[row][column]

  if panel.color ~= newColor then
    if not self.hasUnsavedChanges then
      self.hasUnsavedChanges = true
      self.statusLabel:setText("* Unsaved changes")
    end

    -- If we're overwriting a garbage panel, clear the entire garbage block
    if panel.isGarbage then
      self:clearGarbageBlock(row, column)
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
  ---@cast targetPuzzleSet PuzzleSet
  for _, pathIndex in ipairs(self.puzzleSetPath) do
    local nextSet = targetPuzzleSet.puzzleSets[pathIndex]
    assert(nextSet)
    ---@cast nextSet PuzzleSet
    targetPuzzleSet = nextSet
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
    local player = self.match.stacks[1].player
    ---@cast player Player
    player:unrestrictInputs()
  end
  GAME.navigationStack:pop()
end

return PuzzleEditorScene