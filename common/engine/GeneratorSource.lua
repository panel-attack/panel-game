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
---@field garbagePanelGenerator PanelGenerator
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
  for i = 1, self:getStartingBoardHeight(stack) do
    self:growPanelBuffer(stack)
  end

  -- legacy crutch, the arcane magic for the non-uniform starting board assumes this is there and it really doesn't work without it
  --  even though the chunk is removed at the end of the function
  local startingBoard = string.rep("0", stack.width) .. self.panelBuffer
  self.panelBuffer = ""
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
function GeneratorSource:generateGarbagePanels(stack)
  local lastRow = self.garbagePanelBuffer:sub(-stack.width)
  local newPanels = ""

  for i = 1, 20 do
    local newRow = self.garbagePanelGenerator:generatePanels(stack.width, stack.levelData.colors, lastRow)
    newPanels = newPanels .. newRow
    lastRow = newRow
  end

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

local counts = {0, 0, 0, 0, 0, 0, 0, 0, 0}

---@param rowString string
---@return boolean
local function isBadRow(rowString)
  for i = 1, #counts do
    counts[i] = 0
  end

  for i = 1, rowString:len() do
    local color = tonumber(rowString:sub(i, i))
    ---@cast color -nil
    counts[color] = counts[color] + 1
  end

  for color, count in ipairs(counts) do
    if count ~= 0 and count ~= 2 then
      return false
    end
  end

  return true
end

---@param stack Stack
function GeneratorSource:growPanelBuffer(stack)
  local lastRow = self.panelBuffer:sub(-stack.width)
  local newPanels

  while newPanels == nil or isBadRow(newPanels) do
    newPanels = self.panelGenerator:generatePanels(stack.width, stack.levelData.colors, lastRow)
  end

  if self.shockEnabled then
    newPanels = self.panelGenerator:assignMetalLocations(newPanels, lastRow)
  end

  self.panelBuffer = self.panelBuffer .. newPanels
end

---@param stack Stack
---@param row integer
---@return Panel[] panelRow
function GeneratorSource:createNewRow(stack, row)
  if string.len(self.panelBuffer) <= 2 * stack.width then
    self:growPanelBuffer(stack)
  end

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
  source.panelGenerator = PanelGenerator(self.seed, stack.levelData.adjacentDenialFrequency)
  source.garbagePanelGenerator = PanelGenerator(math.floor((self.seed + 5) / 2), 1)
  if self.panelGenerator then
    source.panelGenerator:setState(self.panelGenerator:getState())
  end
  if self.garbagePanelGenerator then
    source.garbagePanelGenerator:setState(self.garbagePanelGenerator:getState())
  end
  if self.panelBuffer:len() > 0 then
    source.panelBuffer = self.panelBuffer
  else
    source.panelBuffer = source:generateStartingBoard(stack)
  end

  source.garbagePanelBuffer = self.garbagePanelBuffer
  return source
end

function GeneratorSource:saveForRollback(clock)
  local copy = self.rollbackBuffer:getOldest()

  if not copy then
    copy = table.new(0, 6)
  end

  copy.panelBuffer = self.panelBuffer
  copy.garbagePanelBuffer = self.garbagePanelBuffer
  copy.panelGenState = self.panelGenerator:getState()
  copy.garbagePanelGenState = self.garbagePanelGenerator:getState()
  copy.adjacentAccepted = self.panelGenerator.adjacentAccepted
  copy.adjacentDenied = self.panelGenerator.adjacentDenied

  self.rollbackBuffer:saveCopy(clock, copy)
end

function GeneratorSource:rollbackToFrame(clock)
  local copy = self.rollbackBuffer:rollbackToFrame(clock)

  if not copy then
    error("Could not rollback GeneratorSource")
  end

  self.panelBuffer = copy.panelBuffer
  self.garbagePanelBuffer = copy.garbagePanelBuffer
  self.panelGenerator:setState(copy.panelGenState)
  self.garbagePanelGenerator:setState(copy.garbagePanelGenState)
  self.panelGenerator.adjacentAccepted = copy.adjacentAccepted
  self.panelGenerator.adjacentDenied = copy.adjacentDenied
end

function GeneratorSource:rewindToFrame(clock)
  self:rollbackToFrame(clock)
end

return GeneratorSource