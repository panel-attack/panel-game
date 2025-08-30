local ui = require("client.src.ui")
local TouchInputDetector = require("client.src.TouchInputDetector")
local class = require("common.lib.class")
local logger = require("common.lib.logger")

---@class PuzzleEditorStackOverlay : UiElement
---@field stack any
---@field touchInputDetector TouchInputDetector
---@field puzzleEditor any
---@field isDragging boolean
---@field lastTouchedRow integer
---@field lastTouchedCol integer
local PuzzleEditorStackOverlay = class(
  function(self, options)
    self.stack = options.stack
    self.touchInputDetector = TouchInputDetector(self.stack)
    self.puzzleEditor = options.puzzleEditor
    
    -- Touch state tracking
    self.isDragging = false
    self.lastTouchedRow = 0
    self.lastTouchedCol = 0
  end,
  ui.UiElement
)

function PuzzleEditorStackOverlay:onTouch(x, y)
  if self.touchInputDetector:isMouseOverStack(x, y) then
    local row, col = self.touchInputDetector:touchedPanelCoordinate(x, y)
    
    if row and col and row > 0 and col > 0 then
      self.isDragging = true
      self.lastTouchedRow = row
      self.lastTouchedCol = col
      
      self.puzzleEditor:startDrag(row, col)
      
      logger.debug("PuzzleEditorStackOverlay: Touch started at row=" .. row .. ", col=" .. col)
    end
  end
end

function PuzzleEditorStackOverlay:onDrag(x, y)
  if not self.isDragging then
    return
  end
  
  local row, col = self.touchInputDetector:touchedPanelCoordinate(x, y)
  
  if row and col and row > 0 and col > 0 then
    -- Only update if we've moved to a different cell
    if row ~= self.lastTouchedRow or col ~= self.lastTouchedCol then
      self.lastTouchedRow = row
      self.lastTouchedCol = col
      
      self.puzzleEditor:updateDrag(row, col)
      
      logger.debug("PuzzleEditorStackOverlay: Drag updated to row=" .. row .. ", col=" .. col)
    end
  end
end

function PuzzleEditorStackOverlay:onRelease(x, y)
  if not self.isDragging then
    return
  end
  
  local row, col = self.touchInputDetector:touchedPanelCoordinate(x, y)
  
  if row and col and row > 0 and col > 0 then
    self.puzzleEditor:finishDrag(row, col)
    
    logger.debug("PuzzleEditorStackOverlay: Touch ended at row=" .. row .. ", col=" .. col)
  else
    self.puzzleEditor:cancelDrag()
    
    logger.debug("PuzzleEditorStackOverlay: Touch cancelled (outside grid)")
  end
  
  self.isDragging = false
  self.lastTouchedRow = 0
  self.lastTouchedCol = 0
end

local GraphicsUtil = require("client.src.graphics.graphics_util")

-- Override drawing functions to add transparency for preview
local originalDrawGfxScaled = nil
local function enablePreviewMode()
  if not originalDrawGfxScaled then
    -- Store reference to original drawGfxScaled from PlayerStack
    originalDrawGfxScaled = GraphicsUtil.draw
  end
  -- Replace with transparent version
  ---@diagnostic disable-next-line: duplicate-set-field
  GraphicsUtil.draw = function(img, x, y, rot, xScale, yScale)
    if not img then return end
    local prevBlendMode, prevAlphaMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("alpha", "alphamultiply")
    love.graphics.setColor(1, 1, 1, 0.7)
    originalDrawGfxScaled(img, x, y, rot, xScale, yScale)
    love.graphics.setBlendMode(prevBlendMode, prevAlphaMode)
  end
end

local function disablePreviewMode()
  if originalDrawGfxScaled then
    GraphicsUtil.draw = originalDrawGfxScaled
    love.graphics.setColor(1, 1, 1, 1)
  end
end

function PuzzleEditorStackOverlay:drawSelf()
  self:drawGarbagePreview()
end

function PuzzleEditorStackOverlay:drawGarbagePreview()
  if not self.puzzleEditor.isDraggingGarbage or not self.puzzleEditor.garbageDragStart or not self.puzzleEditor.garbageDragCurrent then
    return
  end
  
  local stack = self.stack
  
  local startRow = self.puzzleEditor.garbageDragStart.row
  local startCol = self.puzzleEditor.garbageDragStart.column
  local endRow = self.puzzleEditor.garbageDragCurrent.row
  local endCol = self.puzzleEditor.garbageDragCurrent.column

  -- Calculate garbage dimensions and position (same logic as placeGarbageBlock)
  local minRow = math.min(startRow, endRow)
  local maxRow = math.max(startRow, endRow)
  local minCol = math.min(startCol, endCol)
  local maxCol = math.max(startCol, endCol)
  
  local width = maxCol - minCol + 1
  local height = maxRow - minRow + 1
  
  -- Shock garbage is limited to 1 panel high
  if self.puzzleEditor.shockGarbageMode and height > 1 then
    -- Keep only the start row for shock garbage
    maxRow = startRow
    minRow = startRow
    height = 1
  elseif height > 1 and not self.puzzleEditor.shockGarbageMode then
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

  -- Enable transparent drawing mode
  enablePreviewMode()
  
  if self.puzzleEditor.shockGarbageMode then
    -- Draw shock garbage using existing PlayerStack logic
    local panelsData = panels[stack.panels_dir]
    if panelsData and panelsData.images and panelsData.images.metals then
      local shockImages = panelsData.images.metals
      local metal_w, metal_h = shockImages.mid:getDimensions()
      local metall_w, metall_h = shockImages.left:getDimensions()
      local metalr_w, metalr_h = shockImages.right:getDimensions()
      
      -- For shock garbage, the bottom-right panel is at (minRow, maxCol) since y_offset=0 is at minRow
      local bottomRightRow = minRow
      local bottomRightCol = maxCol
      local draw_x = stack.panelOriginX + (bottomRightCol - 1) * 16 
      local draw_y = stack.panelOriginY + (11 - bottomRightRow) * 16 + stack.engine.displacement
      
      -- Use GraphicsUtil.draw which is now overridden with transparency
      GraphicsUtil.draw(shockImages.left, (draw_x - (16 * (width - 1))) * stack.gfxScale, draw_y * stack.gfxScale, 0, (8 / metall_w) * stack.gfxScale, (16 / metall_h) * stack.gfxScale)
      GraphicsUtil.draw(shockImages.right, (draw_x + 8) * stack.gfxScale, draw_y * stack.gfxScale, 0, (8 / metalr_w) * stack.gfxScale, (16 / metalr_h) * stack.gfxScale)
      for i = 0, 2 * (width - 1) - 1 do
        GraphicsUtil.draw(shockImages.mid, (draw_x - 8 * i) * stack.gfxScale, draw_y * stack.gfxScale, 0, (8 / metal_w) * stack.gfxScale, (16 / metal_h) * stack.gfxScale)
      end
    end
  else
    -- Create a mock panel object for drawGarbageBlock
    local mockPanel = {
      width = width,
      height = height
    }
    
    -- For regular garbage, the bottom-right panel is at (minRow, maxCol) since y_offset=0 is at minRow
    local bottomRightRow = minRow  
    local bottomRightCol = maxCol
    local drawX = stack.panelOriginX + (bottomRightCol - 1) * 16 
    local drawY = stack.panelOriginY + (11 - bottomRightRow) * 16 + stack.engine.displacement
    
    -- Reuse existing drawGarbageBlock method
    stack:drawGarbageBlock(mockPanel, drawX, drawY, stack.character.images)
  end
  
  -- Restore normal drawing mode
  disablePreviewMode()
end

return PuzzleEditorStackOverlay