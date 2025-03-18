local class = require("common.lib.class")

---@class PuzzleSource : PanelSource
---@field puzzleString string
---@field panels Panel[]
---@overload fun(puzzleString: string, panelBuffer: string?, garbageBuffer: string?): PuzzleSource
local PuzzleSource = class(
---@param self PuzzleSource
---@param puzzleString string
---@param panelBuffer string?
---@param garbageBuffer string?
function(self, puzzleString, panelBuffer, garbageBuffer)
  self.puzzleString = puzzleString
  self.panelBuffer = panelBuffer or ""
  self.garbagePanelBuffer = garbageBuffer or ""
  self.panelGenCount = 0
  self.garbageGenCount = 0

  self.panels = {}
end)

PuzzleSource.TYPE = "PuzzleSource"

function PuzzleSource:toReplaySource()
  return {
    sourceType = 2,
    puzzleString = self.puzzleString,
    panelBuffer = self.panelBuffer,
    garbagePanelBuffer = self.garbagePanelBuffer
  }
end

---@param stack Stack
---@param column integer
---@return Panel panel
local function createPanelWithoutPosition(stack, column)
  return stack.panelTemplate(0, column)
end


function PuzzleSource:getStartingBoardHeight(stack)
  return math.ceil(self.puzzleString:len() / stack.width)
end

function PuzzleSource:generateStartingBoard(stack)
  self.panelGenCount = self.panelGenCount + 1
  return self.puzzleString
end

function PuzzleSource:generatePanels(stack)
  self.panelGenCount = self.panelGenCount + 1
  local panels = ""
  local desiredCount = stack.width * 100
  if self.panelBuffer:len() > desiredCount then
    panels = self.panelBuffer:sub(1, desiredCount)
    self.panelBuffer = self.panelBuffer:sub(desiredCount + 1)
  else
    panels = self.panelBuffer
    self.panelBuffer = ""
    panels = panels .. string.rep(9, desiredCount - panels:len())
  end

  return panels
end

function PuzzleSource:generateGarbagePanels(stack)
  self.garbageGenCount = self.garbageGenCount + 1
  return string.rep(9, stack.width * 20)
end

---@param stack Stack
---@param row integer
function PuzzleSource:createNewRow(stack, row)
  if self.panelGenCount == 0 then
    self.panelBuffer = self:generateStartingBoard(stack)
  else
    if self.panelBuffer == "" then
      self.panelBuffer = self:generatePanels(stack, 20)
    end
  end

  if #self.panels < stack.width then
    self:createPanelBuffer(stack)
  end

  for col = 1, stack.width do
    local panel = table.remove(self.panels, 1)
    panel.row = row
    stack.panels[row][col] = panel
  end
end

---@param stack Stack
function PuzzleSource:createPanelBuffer(stack)
  local panels = {}

  local puzzleString = self.panelBuffer
  local garbageStartRow = nil
  local garbageStartColumn = nil
  local isMetal = false
  local connectedGarbagePanels = {}
  local rowCount = string.len(puzzleString) / 6
  -- chunk the puzzle string into rows
  -- it is necessary to go bottom up because garbage block panels contain the offset relative to their bottom left corner
  for row = 1, rowCount do
    local rowString = string.sub(puzzleString, #puzzleString - 5, #puzzleString)
    puzzleString = string.sub(puzzleString, 1, #puzzleString - 6)
    -- copy the panels into the row
    panels[row] = {}
    for column = 6, 1, -1 do
      local panel = createPanelWithoutPosition(stack, column)
      panels[row][column] = panel

      local color = string.sub(rowString, column, column)
      if not garbageStartRow and tonumber(color) then
        panel.color = tonumber(color)
      else
        -- start of a garbage block
        if color == "]" or color == "}" then
          garbageStartRow = row
          garbageStartColumn = column
          connectedGarbagePanels = {}
          -- use the stack prop to avoid collisions in garbage id
          ---@diagnostic disable-next-line: invisible
          stack.garbageCreatedCount = stack.garbageCreatedCount + 1
          if color == "}" then
            isMetal = true
          else
            isMetal = false
          end
        end
        ---@diagnostic disable-next-line: invisible
        panel.garbageId = stack.garbageCreatedCount
        panel.isGarbage = true
        panel.color = 9
        panel.y_offset = row - garbageStartRow
        -- iterating the row right to left to make sure we catch the start of each garbage block
        -- but the offset is expected left to right, therefore we can't know the x_offset before reaching the end of the garbage
        -- instead save the column index in that field to calculate it later
        panel.x_offset = column
        panel.metal = isMetal
        table.insert(connectedGarbagePanels, panel)
        -- garbage ends here
        if color == "[" or color == "{" then
          -- calculate dimensions of the garbage and add it to the relevant width/height properties
          local height = connectedGarbagePanels[#connectedGarbagePanels].y_offset + 1
          -- this is disregarding the possible existence of irregularly shaped garbage
          local width = garbageStartColumn - column + 1
          local shake_time = stack:shakeFramesForGarbageSize(width, height)
          for i = 1, #connectedGarbagePanels do
            connectedGarbagePanels[i].x_offset = connectedGarbagePanels[i].x_offset - column
            connectedGarbagePanels[i].height = height
            connectedGarbagePanels[i].width = width
            if row > stack.height then
              -- only garbage panels that end up off screen should grant shake time on land
              connectedGarbagePanels[i].shake_time = shake_time
            end
            ---@diagnostic disable-next-line: invisible
            connectedGarbagePanels[i].garbageId = stack.garbageCreatedCount
            -- panels are already in the main table and they should already be updated by reference
          end
          garbageStartRow = nil
          garbageStartColumn = nil
          connectedGarbagePanels = nil
          isMetal = false
        end
      end
    end
  end

  self.panelBuffer = ""

  -- finally unroll the panels for consumption
  for row = #panels, 1, -1 do
    for col = 1, #panels[row] do
      self.panels[#self.panels+1] = panels[row][col]
    end
  end
end

function PuzzleSource:getGarbagePanelRowString(stack)
  if self.garbagePanelBuffer:len() < stack.width then
    self.garbagePanelBuffer = self.garbagePanelBuffer .. self:generateGarbagePanels(stack)
  end

  local garbagePanelRow = string.sub(self.garbagePanelBuffer, 1, stack.width)
  self.garbagePanelBuffer = string.sub(self.garbagePanelBuffer, stack.width + 1)
  return garbagePanelRow
end

function PuzzleSource:clone()
  local source = PuzzleSource(self.puzzleString, self.panelBuffer, self.garbagePanelBuffer)
  source.panelGenCount = self.panelGenCount
  source.panels = deepcpy(self.panels)
  return source
end

return PuzzleSource