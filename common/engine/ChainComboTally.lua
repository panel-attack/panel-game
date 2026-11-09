local class = require("common.lib.class")

-- How many combos and finished chains of each size a stack has made.
-- The stack counts into it, puzzle goals are judged from it and the analytics display reads it.
---@class ChainComboTally
---@field combos table<integer, integer> combo size -> how many matches of exactly that many panels
---@field chains table<integer, integer> chain size -> how many chains ended at exactly that size
---@overload fun(): ChainComboTally
local ChainComboTally = class(function(self)
  self.combos = {}
  self.chains = {}
end)

-- Counts a match of the size
---@param size integer number of panels in the match
function ChainComboTally:addCombo(size)
  self.combos[size] = (self.combos[size] or 0) + 1
end

-- Counts a chain that ended at the size
---@param size integer the size the chain ended at
function ChainComboTally:addChain(size)
  self.chains[size] = (self.chains[size] or 0) + 1
end

-- Makes the target count the same as this tally, keeping the target's own tables
---@param target ChainComboTally
function ChainComboTally:copyTo(target)
  table.clear(target.combos)
  table.clear(target.chains)
  for size, count in pairs(self.combos) do
    target.combos[size] = count
  end
  for size, count in pairs(self.chains) do
    target.chains[size] = count
  end
end

return ChainComboTally
