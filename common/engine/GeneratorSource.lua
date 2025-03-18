local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local PanelGenerator = require("common.engine.PanelGenerator")
require("common.lib.util")
table.new = require("table.new")

---@class GeneratorSource : PanelSource
---@field seed integer
---@field allowAdjacentColors boolean
---@field shockEnabled boolean
---@field garbageShockEnabled boolean
---@overload fun(seed: integer, allowAdjacentColors: boolean, shockEnabled: boolean): GeneratorSource
local GeneratorSource = class(
---@param self GeneratorSource
---@param seed integer
---@param allowAdjacentColors boolean
---@param shockEnabled boolean
function(self, seed, allowAdjacentColors, shockEnabled)
  self.seed = seed
  self.panelBuffer = ""
  self.garbagePanelBuffer = ""
  self.panelGenCount = 0
  self.garbageGenCount = 0
  self.allowAdjacentColors = allowAdjacentColors
  self.shockEnabled = shockEnabled
  self.garbageShockEnabled = false
end)

GeneratorSource.TYPE = "GeneratorSource"

---@return ReplayPanelSource
function GeneratorSource:toReplaySource()
  return {
    sourceType = 3,
    seed = self.seed,
    allowAdjacentColors = self.allowAdjacentColors,
    shockEnabled = self.shockEnabled,
    garbageShockEnabled = self.garbageShockEnabled
  }
end

function GeneratorSource:getStartingBoardHeight(stack)
  return 7
end

---@param stack Stack
---@return string
function GeneratorSource:generateStartingBoard(stack)
  PanelGenerator:setSeed(self.seed + self.panelGenCount)

  local ret = PanelGenerator.privateGeneratePanels(self:getStartingBoardHeight(stack), stack.width, stack.levelData.colors, self.panelBuffer, not self.allowAdjacentColors)
  -- technically there can never be metal on the starting board but we need to call it to advance the RNG (compatibility)
  if self.shockEnabled then
    ret = PanelGenerator.assignMetalLocations(ret, stack.width)
  end

  self.panelGenCount = self.panelGenCount + 1

  -- legacy crutch, the arcane magic for the non-uniform starting board assumes this is there and it really doesn't work without it
  ret = string.rep("0", stack.width) .. ret
  -- arcane magic to get a non-uniform starting board
  ret = procat(ret)
  local maxStartingHeight = 7
  local height = tableUtils.map(procat(string.rep(maxStartingHeight, stack.width)), function(s) return tonumber(s) end)
  local to_remove = 2 * stack.width
  while to_remove > 0 do
    local idx = PanelGenerator:random(1, stack.width) -- pick a random column
    if height[idx] > 0 then
      ret[idx + stack.width * (-height[idx] + 8)] = "0" -- delete the topmost panel in this column
      height[idx] = height[idx] - 1
      to_remove = to_remove - 1
    end
  end

  ret = table.concat(ret)
  ret = string.sub(ret, stack.width + 1)

  return ret
end

---@param stack Stack
---@return string
function GeneratorSource:generatePanels(stack)
  PanelGenerator:setSeed(self.seed + self.panelGenCount)

  local panelColors = PanelGenerator.privateGeneratePanels(100, stack.width, stack.levelData.colors, self.panelBuffer, not self.allowAdjacentColors)
  if self.shockEnabled then
    panelColors = PanelGenerator.assignMetalLocations(panelColors, stack.width)
  end

  self.panelGenCount = self.panelGenCount + 1

  return panelColors
end

---@param stack Stack
---@return string
function GeneratorSource:generateGarbagePanels(stack)
  PanelGenerator:setSeed(self.seed + self.garbageGenCount)

  local garbageColors = PanelGenerator.privateGeneratePanels(20, stack.width, stack.levelData.colors, self.garbagePanelBuffer, not self.allowAdjacentColors)
  if self.garbageShockEnabled then
    garbageColors = PanelGenerator.assignMetalLocations(garbageColors, stack.width)
  end

  self.garbageGenCount = self.garbageGenCount + 1

  return garbageColors
end

---@param rowString string
---@param metalPanelCount integer
---@return integer[]
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
---@param row integer
---@return Panel[] panelRow
function GeneratorSource:createNewRow(stack, row)
  if self.panelGenCount == 0 then
    self.panelBuffer = self:generateStartingBoard(stack)
    self.panelBuffer = self:generatePanels(stack)
  else
    if string.len(self.panelBuffer) <= 10 * stack.width then
      self.panelBuffer = self:generatePanels(stack)
    end
  end

  local metal_panels_this_row = 0
  -- assign colors to the new row 0
  if stack.metal_panels_queued > 3 then
    stack.metal_panels_queued = stack.metal_panels_queued - 2
    metal_panels_this_row = 2
  elseif stack.metal_panels_queued > 0 then
    stack.metal_panels_queued = stack.metal_panels_queued - 1
    metal_panels_this_row = 1
  end

  local colors = convertMetalPanels(string.sub(self.panelBuffer, 1, stack.width), metal_panels_this_row)
  self.panelBuffer = string.sub(self.panelBuffer, stack.width + 1)

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
    self.garbagePanelBuffer = self:generateGarbagePanels(stack)
  end
  local garbagePanelRow = string.sub(self.garbagePanelBuffer, 1, stack.width)
  self.garbagePanelBuffer = string.sub(self.garbagePanelBuffer, stack.width + 1)
  garbagePanelRow = table.concat(convertMetalPanels(garbagePanelRow, 0))
  return garbagePanelRow
end

function GeneratorSource:clone()
  local source = GeneratorSource(self.seed, self.allowAdjacentColors, self.shockEnabled)
  source.panelBuffer = self.panelBuffer
  source.garbagePanelBuffer = self.garbagePanelBuffer
  source.panelGenCount = self.panelGenCount
  source.garbageGenCount = self.garbageGenCount
  source.garbageShockEnabled = self.garbageShockEnabled
  return source
end

return GeneratorSource