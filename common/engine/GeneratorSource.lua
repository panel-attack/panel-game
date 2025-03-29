local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local PanelGenerator = require("common.engine.PanelGenerator")
require("common.lib.util")
table.new = require("table.new")
local RollbackBuffer = require("common.engine.RollbackBuffer")

---@class GeneratorSource : PanelSource
---@field seed integer
---@field shockEnabled boolean
---@field panelGenerator PanelGenerator
---@field rollbackBuffer RollbackBuffer
---@overload fun(seed: integer, shockEnabled: boolean): GeneratorSource
local GeneratorSource = class(
---@param self GeneratorSource
---@param seed integer
---@param shockEnabled boolean
function(self, seed, shockEnabled)
  self.seed = seed
  self.shockEnabled = shockEnabled
  self.panelBuffer = ""
  self.garbagePanelBuffer = ""
  self.panelGenCount = 0
  self.garbageGenCount = 0
  self.rollbackBuffer = RollbackBuffer(MAX_LAG + 1)
end)

GeneratorSource.TYPE = "GeneratorSource"

---@return ReplayPanelSource
function GeneratorSource:toReplaySource()
  return {
    sourceType = 3,
    seed = self.seed,
    shockEnabled = self.shockEnabled,
  }
end

function GeneratorSource:getStartingBoardHeight(stack)
  return 7
end

---@param stack Stack
---@return string startingBoard
function GeneratorSource:generateStartingBoard(stack)
  self.panelGenerator:setSeed(self.seed + self.panelGenCount)

  local startingBoard = ""
  local lastRow

  for i = 1, self:getStartingBoardHeight(stack) do
    local newRow = self.panelGenerator:generatePanels(stack.width, stack.levelData.colors, lastRow, self.shockEnabled)
    startingBoard = startingBoard .. newRow
    lastRow = newRow
  end

  self.panelGenCount = self.panelGenCount + 1

  -- legacy crutch, the arcane magic for the non-uniform starting board assumes this is there and it really doesn't work without it
  --  even though the chunk is removed at the end of the function
  startingBoard = string.rep("0", stack.width) .. startingBoard
  -- arcane magic to get a non-uniform starting board
  local startingBoardArray = procat(startingBoard)
  local maxStartingHeight = 7
  local height = tableUtils.map(procat(string.rep(maxStartingHeight, stack.width)), function(s) return tonumber(s) end)
  local toRemove = 2 * stack.width
  while toRemove > 0 do
    local idx = self.panelGenerator:random(1, stack.width) -- pick a random column
    if height[idx] > 0 then
      -- delete the topmost panel in this column
      startingBoardArray[idx + stack.width * (-height[idx] + 8)] = "0"
      height[idx] = height[idx] - 1
      toRemove = toRemove - 1
    end
  end

  startingBoard = table.concat(startingBoardArray)
  startingBoard = string.sub(startingBoard, stack.width + 1)

  return startingBoard
end

---@param stack Stack
---@return string newPanels
function GeneratorSource:generatePanels(stack)
  self.panelGenerator:setSeed(self.seed + self.panelGenCount)

  local lastRow = self.panelBuffer:sub(-stack.width)
  local newPanels = self.panelGenerator:generatePanels(stack.width, stack.levelData.colors, lastRow, self.shockEnabled)

  self.panelGenCount = self.panelGenCount + 1

  return newPanels
end

---@param stack Stack
---@return string newPanels
function GeneratorSource:generateGarbagePanels(stack)
  self.panelGenerator:setSeed(self.seed + self.garbageGenCount)

  local lastRow = self.garbagePanelBuffer:sub(-stack.width)
  local newPanels = ""

  for i = 1, 20 do
    local newRow = self.panelGenerator:generatePanels(stack.width, stack.levelData.colors, lastRow, false)
    newPanels = newPanels .. newRow
    lastRow = newRow
  end

  self.garbageGenCount = self.garbageGenCount + 1

  return newPanels
end

---@param rowString string
---@param metalPanelCount integer
---@return integer[] colorArray
local function convertMetalPanels(rowString, metalPanelCount)
  local colors = table.new(rowString:len(), 0)

  for i = 1, rowString:len() do
    local colorString = rowString:sub(i, i)
    local color = 0
    if tonumber(colorString) then
      color = colorString + 0
    elseif colorString >= "A" and colorString <= "Z" then
      if metalPanelCount > 0 then
        color = 8
      else
        color = PanelGenerator.PANEL_COLOR_TO_NUMBER[colorString]
      end
    elseif colorString >= "a" and colorString <= "z" then
      if metalPanelCount > 1 then
        color = 8
      else
        color = PanelGenerator.PANEL_COLOR_TO_NUMBER[colorString]
      end
    end
    colors[i] = tonumber(color)
  end

  return colors
end

---@param stack Stack
function GeneratorSource:growPanelBuffer(stack)
  if self.panelGenCount == 0 then
    self.panelBuffer = self:generateStartingBoard(stack)
    self.panelBuffer = self.panelBuffer .. self:generatePanels(stack)
  else
    if string.len(self.panelBuffer) <= 2 * stack.width then
      self.panelBuffer = self.panelBuffer .. self:generatePanels(stack)
    end
  end
end

---@param stack Stack
---@param row integer
---@return Panel[] panelRow
function GeneratorSource:createNewRow(stack, row)
  self:growPanelBuffer(stack)

  local metalPanelsThisRow = 0
  if self.shockEnabled then
    -- assign colors to the new row 0
    if stack.metalPanelsQueued > 3 then
      stack.metalPanelsQueued = stack.metalPanelsQueued - 2
      metalPanelsThisRow = 2
    elseif stack.metalPanelsQueued > 0 then
      stack.metalPanelsQueued = stack.metalPanelsQueued - 1
      metalPanelsThisRow = 1
    end
  end

  local colors = convertMetalPanels(self.panelBuffer:sub(1, stack.width), metalPanelsThisRow)
  self.panelBuffer = self.panelBuffer:sub(stack.width + 1)

  for col = 1, stack.width do
    local panel = stack:createPanelAt(row, col)
    panel.color = colors[col]
    panel.state = "dimmed"
  end

  return stack.panels[row]
end

---@param stack Stack
---@return string
function GeneratorSource:getGarbagePanelRowString(stack)
  if string.len(self.garbagePanelBuffer) <= 10 * stack.width then
    self.garbagePanelBuffer = self.garbagePanelBuffer .. self:generateGarbagePanels(stack)
  end
  local garbagePanelRow = self.garbagePanelBuffer:sub(1, stack.width)
  self.garbagePanelBuffer = self.garbagePanelBuffer:sub(stack.width + 1)
  return garbagePanelRow
end

-- creates a standalone clone that uses the Stack's level data settings
---@param stack Stack
---@return GeneratorSource
function GeneratorSource:clone(stack)
  local source = GeneratorSource(self.seed, self.shockEnabled)
  source.panelBuffer = self.panelBuffer
  source.garbagePanelBuffer = self.garbagePanelBuffer
  source.panelGenCount = self.panelGenCount
  source.garbageGenCount = self.garbageGenCount
  source.panelGenerator = PanelGenerator(self.seed, stack.levelData.adjacentDenialFrequency)
  return source
end

function GeneratorSource:saveForRollback(frame)
  local copy = self.rollbackBuffer:getOldest()

  if not copy then
    copy = table.new(0, 6)
  end

  copy.panelBuffer = self.panelBuffer
  copy.garbagePanelBuffer = self.garbagePanelBuffer
  copy.panelGenCount = self.panelGenCount
  copy.garbageGenCount = self.garbageGenCount
  copy.adjacentAccepted = self.panelGenerator.adjacentAccepted
  copy.adjacentDenied = self.panelGenerator.adjacentDenied

  self.rollbackBuffer:saveCopy(frame, copy)
end

function GeneratorSource:rollbackToFrame(frame)
  local copy = self.rollbackBuffer:rollbackToFrame(frame)

  if not copy then
    error("Could not rollback GeneratorSource")
  end

  self.panelBuffer = copy.panelBuffer
  self.garbagePanelBuffer = copy.garbagePanelBuffer
  self.panelGenCount = copy.panelGenCount
  self.garbageGenCount = copy.garbageGenCount
  self.panelGenerator.adjacentAccepted = copy.adjacentAccepted
  self.panelGenerator.adjacentDenied = copy.adjacentDenied
end

function GeneratorSource:rewindToFrame(frame)
  self:rollbackToFrame(frame)
end

return GeneratorSource