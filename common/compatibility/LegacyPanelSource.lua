local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local LegacyPanelGenerator = require("common.compatibility.LegacyPanelGenerator")
require("common.lib.util")
local RollbackBuffer       = require("common.engine.RollbackBuffer")

---@class LegacyPanelSource : PanelSource
---@field seed integer
---@field allowAdjacentColors boolean
---@field allowAdjacentColorsOnStartingBoard boolean
---@field shockEnabled boolean
---@field rollbackBuffer RollbackBuffer
---@field panelGenCount integer How many times the panelBuffer was extended; relevant to keep PRNG deterministic for replays
---@field garbageGenCount integer How many times the garbagePanelBuffer was extended; relevant to keep PRNG deterministic for replays
---@overload fun(seed: integer, shockEnabled: boolean): LegacyPanelSource
local LegacyPanelSource = class(
---@param self LegacyPanelSource
---@param seed integer
---@param shockEnabled boolean
function(self, seed, shockEnabled)
  self.seed = seed
  self.panelBuffer = ""
  self.garbagePanelBuffer = ""
  self.panelGenCount = 0
  self.garbageGenCount = 0
  self.allowAdjacentColors = false
  self.allowAdjacentColorsOnStartingBoard = false
  self.shockEnabled = shockEnabled
  self.rollbackBuffer = RollbackBuffer(MAX_LAG + 1)
end)

LegacyPanelSource.TYPE = "LegacyPanelSource"

---@return ReplayPanelSource
function LegacyPanelSource:toReplaySource()
  return {
    sourceType = 1,
    seed = self.seed,
    allowAdjacentColors = self.allowAdjacentColors,
    allowAdjacentColorsOnStartingBoard = self.allowAdjacentColorsOnStartingBoard,
    shockEnabled = self.shockEnabled
  }
end

---@param allow boolean
function LegacyPanelSource:setAllowAdjacentColorsOnStartingBoard(allow)
  self.allowAdjacentColorsOnStartingBoard = allow
end

function LegacyPanelSource:getStartingBoardHeight(stack)
  return 7
end

---@param stack Stack
---@return string
function LegacyPanelSource:generateStartingBoard(stack)
  LegacyPanelGenerator:setSeed(self.seed + self.panelGenCount)

  local ret = LegacyPanelGenerator.privateGeneratePanels(self:getStartingBoardHeight(stack), stack.width, stack.levelData.colors, self.panelBuffer, not self.allowAdjacentColorsOnStartingBoard)
  -- technically there can never be metal on the starting board but we need to call it to advance the RNG (compatibility)
  ret = LegacyPanelGenerator.assignMetalLocations(ret, stack.width)

  self.panelGenCount = self.panelGenCount + 1

  -- legacy crutch, the arcane magic for the non-uniform starting board assumes this is there and it really doesn't work without it
  ret = string.rep("0", stack.width) .. ret
  -- arcane magic to get a non-uniform starting board
  ret = procat(ret)
  local maxStartingHeight = 7
  local height = tableUtils.map(procat(string.rep(maxStartingHeight, stack.width)), function(s) return tonumber(s) end)
  local to_remove = 2 * stack.width
  while to_remove > 0 do
    local idx = LegacyPanelGenerator:random(1, stack.width) -- pick a random column
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
function LegacyPanelSource:generatePanels(stack)
  LegacyPanelGenerator:setSeed(self.seed + self.panelGenCount)

  local panelColors = LegacyPanelGenerator.privateGeneratePanels(100, stack.width, stack.levelData.colors, self.panelBuffer, not self.allowAdjacentColors)
  panelColors = LegacyPanelGenerator.assignMetalLocations(panelColors, stack.width)

  self.panelGenCount = self.panelGenCount + 1

  return panelColors
end

---@param stack Stack
---@return string
function LegacyPanelSource:generateGarbagePanels(stack)
  LegacyPanelGenerator:setSeed(self.seed + self.garbageGenCount)
  self.garbageGenCount = self.garbageGenCount + 1
  return LegacyPanelGenerator.privateGeneratePanels(20, stack.width, stack.levelData.colors, self.garbagePanelBuffer, not self.allowAdjacentColors)
end

---@param stack Stack
---@param row integer
---@return Panel[] panelRow
function LegacyPanelSource:createNewRow(stack, row)
  if self.panelGenCount == 0 then
    self.panelBuffer = self:generateStartingBoard(stack)
  else
    if string.len(self.panelBuffer) <= 10 * stack.width then
      self.panelBuffer = self:generatePanels(stack)
    end
  end


  -- assign colors to the new row 0
  local metal_panels_this_row = 0
  if self.shockEnabled then
    if stack.metalPanelsQueued > 3 then
      stack.metalPanelsQueued = stack.metalPanelsQueued - 2
      metal_panels_this_row = 2
    elseif stack.metalPanelsQueued > 0 then
      stack.metalPanelsQueued = stack.metalPanelsQueued - 1
      metal_panels_this_row = 1
    end
  end

  for col = 1, stack.width do
    local panel = stack:createPanelAt(row, col)
    local colorString = self.panelBuffer:sub(col, col)
    local color = 0
    if tonumber(colorString) then
      color = colorString + 0
    elseif colorString >= "A" and colorString <= "Z" then
      if metal_panels_this_row > 0 then
        color = 8
      else
        color = LegacyPanelGenerator.PANEL_COLOR_TO_NUMBER[colorString]
      end
    elseif colorString >= "a" and colorString <= "z" then
      if metal_panels_this_row > 1 then
        color = 8
      else
        color = LegacyPanelGenerator.PANEL_COLOR_TO_NUMBER[colorString]
      end
    end
    panel.color = color
    panel.state = "dimmed"
  end

  self.panelBuffer = string.sub(self.panelBuffer, stack.width + 1)

  return stack.panels[row]
end

---@param stack Stack
---@return string
function LegacyPanelSource:getGarbagePanelRowString(stack)
  if string.len(self.garbagePanelBuffer) <= 10 * stack.width then
    -- generateGarbagePanels already appends to the existing garbagePanelBuffer
    local newGarbagePanels = self:generateGarbagePanels(stack)
    -- and then we append that result to the remaining buffer
    self.garbagePanelBuffer = self.garbagePanelBuffer .. newGarbagePanels
    -- that means the next 10 rows of garbage will use the same colors as the 10 rows after
    -- that's a bug
    -- it is relatively hard to abuse as 
    -- a) players would need to accurately track the 10 row cycles
    -- b) "solve into the same thing" only applies to a limited degree:
    --   a garbage panel row of 123456 solves into 1234 for ====00 but into 3456 for 00====
    --   that means information may be incomplete and partial memorization may prove unreliable
    -- c) garbage panels change every (10 + n * 20 rows) with n>0 in ℕ 
    --    so the player needs to always survive the first 20 rows to start abusing
    --    and can then only abuse for every 10 rows out of 20
    -- overall it is to be expected that the strain of trying to memorize outweighs the gains
    -- this bug is in part why this LegacyPanelSource was replaced with GeneratorSource
  end
  local garbagePanelRow = string.sub(self.garbagePanelBuffer, 1, stack.width)
  self.garbagePanelBuffer = string.sub(self.garbagePanelBuffer, stack.width + 1)
  return garbagePanelRow
end

---@param stack Stack
---@return LegacyPanelSource
function LegacyPanelSource:clone(stack)
  local source = LegacyPanelSource(self.seed, self.shockEnabled)
  source.panelBuffer = self.panelBuffer
  source.garbagePanelBuffer = self.garbagePanelBuffer
  source.panelGenCount = self.panelGenCount
  source.garbageGenCount = self.garbageGenCount
  source.allowAdjacentColors = (stack.levelData.adjacentDenialFrequency == 0)
  source.allowAdjacentColorsOnStartingBoard = self.allowAdjacentColorsOnStartingBoard
  return source
end

function LegacyPanelSource:saveForRollback(frame)
  local copy = self.rollbackBuffer:getOldest()

  if not copy then
    copy = table.new(0, 4)
  end

  copy.panelBuffer = self.panelBuffer
  copy.garbagePanelBuffer = self.garbagePanelBuffer
  copy.panelGenCount = self.panelGenCount
  copy.garbageGenCount = self.garbageGenCount

  self.rollbackBuffer:saveCopy(frame, copy)
end

function LegacyPanelSource:rollbackToFrame(frame)
  local copy = self.rollbackBuffer:rollbackToFrame(frame)

  if not copy then
    error("Could not rollback LegacyPanelSource")
  end

  self.panelBuffer = copy.panelBuffer
  self.garbagePanelBuffer = copy.garbagePanelBuffer
  self.panelGenCount = copy.panelGenCount
  self.garbageGenCount = copy.garbageGenCount
end

function LegacyPanelSource:rewindToFrame(frame)
  self:rollbackToFrame(frame)
end

return LegacyPanelSource