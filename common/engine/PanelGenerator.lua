local util = require("common.lib.util")
local logger = require("common.lib.logger")
local class = require("common.lib.class")

-- table of static functions used for generating panels
---@class PanelGenerator
---@field rng love.RandomGenerator
---@field generatedCount integer debug property to see how often random was actually called since last setting the seed
---@field seed integer
---@field adjacentDenialFrequency number in percent
---@field adjacentAccepted integer how many rolls of an adjacent panel have been accepted
---@field adjacentDenied integer how many rolls of an adjacent panel have been denied
---@overload fun(seed: integer, adjacentDenialFrequency: number): PanelGenerator
local PanelGenerator = class(
---@param self PanelGenerator
---@param seed integer
---@param adjacentDenialFrequency number
function(self, seed, adjacentDenialFrequency)
  self.seed = seed
  self.generatedCount = 0
  self.adjacentDenialFrequency = adjacentDenialFrequency
  self.adjacentAccepted = 0
  self.adjacentDenied = 0
  self.rng = love.math.newRandomGenerator()
  self.rng:setSeed(seed)
end)

PanelGenerator.PANEL_COLOR_NUMBER_TO_UPPER = {"A", "B", "C", "D", "E", "F", "G", "H", "I", [0] = "0"}
PanelGenerator.PANEL_COLOR_NUMBER_TO_LOWER = {"a", "b", "c", "d", "e", "f", "g", "h", "i", [0] = "0" }
PanelGenerator.PANEL_COLOR_TO_NUMBER = {
  ["A"] = 1, ["B"] = 2, ["C"] = 3, ["D"] = 4, ["E"] = 5, ["F"] = 6, ["G"] = 7, ["H"] = 8, ["I"] = 9, ["J"] = 0,
  ["a"] = 1, ["b"] = 2, ["c"] = 3, ["d"] = 4, ["e"] = 5, ["f"] = 6, ["g"] = 7, ["h"] = 8, ["i"] = 9, ["j"] = 0,
  ["1"] = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["7"] = 7, ["8"] = 8, ["9"] = 9, ["0"] = 0
}

function PanelGenerator:random(min, max)
  self.generatedCount = self.generatedCount + 1
  return self.rng:random(min, max)
end

function PanelGenerator:getState()
  return self.rng:getState()
end

---@param state string
function PanelGenerator:setState(state)
  self.rng:setState(state)
end

-- generates panels for one row based on previousPanels
---@param rowWidth integer
---@param ncolors integer
---@param previousRow string
---@return string newPanels
function PanelGenerator:generatePanels(rowWidth, ncolors, previousRow)
  -- logger.info("generating panels with seed: " .. PanelGenerator.rng:getSeed() ..
  --              "\nbuffer: " .. previousPanels ..
  --              "\ncolors: " .. ncolors)

  if not previousRow or previousRow == "" then
    previousRow = string.rep("0", rowWidth)
  end

  local newPanels = ""

  if ncolors < 2 then
    error("Trying to generate panels with only " .. ncolors .. " colors")
  end

  for n = 1, rowWidth do
    local previousTwoMatchOnThisRow = n > 2 and PanelGenerator.PANEL_COLOR_TO_NUMBER[string.sub(newPanels, -1, -1)] ==
                                          PanelGenerator.PANEL_COLOR_TO_NUMBER[string.sub(newPanels, -2, -2)]
    local nogood = true
    local color = 0
    local belowColor = PanelGenerator.PANEL_COLOR_TO_NUMBER[string.sub(previousRow, n, n)]
    while nogood do
      color = self:random(1, ncolors)

      if color == belowColor then
        -- can't have the same color as above
        nogood = true
      elseif (previousTwoMatchOnThisRow and color == PanelGenerator.PANEL_COLOR_TO_NUMBER[string.sub(newPanels, -1, -1)]) then
        -- can't have three in a row
        nogood = true
      elseif (n > 1 and color == PanelGenerator.PANEL_COLOR_TO_NUMBER[string.sub(newPanels, -1, -1)]) then
        -- only allow horizontally adjacent colors with a certain frequency
        if self.adjacentDenialFrequency >= 1 then
          -- denying everything, no need to track numbers
          nogood = true
        elseif self.adjacentDenialFrequency == 0 then
          nogood = false
        else
          -- a bit jank; frequency evaluates to NaN on the very first call of this function
          local frequency = self.adjacentDenied / (self.adjacentAccepted + self.adjacentDenied)
          -- NaN evaluates to false with all operators except ~= (which evaluates to true, even with itself (IEEE 754 standard lua follows))
          if frequency <= self.adjacentDenialFrequency then
            self.adjacentDenied = self.adjacentDenied + 1
            nogood = true
          else
            -- that means the first double is always accepted as NaN <= adjacentDenialFrequency evaluates to false
            self.adjacentAccepted = self.adjacentAccepted + 1
            nogood = false
          end
        end
      else
        nogood = false
      end
    end
    newPanels = newPanels .. tostring(color)
  end
  -- logger.debug(result)
  -- only return the new panels
  return newPanels
end

---@param rowString string
---@param previousRowString string?
---@return string rowString
function PanelGenerator:assignMetalLocations(rowString, previousRowString)
  local rowWidth = rowString:len()
  if not previousRowString or previousRowString == "" then
    previousRowString = string.rep("0", rowWidth)
  end

  local newString = ""

  -- locations of potential metal panels
  local first, second
  -- just like other panels, we don't want metal panels ghost matching on their own
  -- so reroll until the same position of the previous row is not marked for metal
  while not first or not tonumber(string.sub(previousRowString, first, first)) do
    first = self:random(1, rowWidth)
  end
  while not second or second == first or not tonumber(string.sub(previousRowString, second, second)) do
    second = self:random(1, rowWidth)
  end

  for j = 1, rowWidth do
    local char = string.sub(rowString, j, j)
    local num = tonumber(char)
    if j == first then
      newString = newString .. (PanelGenerator.PANEL_COLOR_NUMBER_TO_UPPER[num] or char or "0")
    elseif j == second then
      newString = newString .. (PanelGenerator.PANEL_COLOR_NUMBER_TO_LOWER[num] or char or "0")
    else
      newString = newString .. char
    end
  end

  return newString
end

return PanelGenerator