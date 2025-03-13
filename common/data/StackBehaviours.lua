---@class StackBehaviours
---@field passiveRaise boolean? if the stack will passively rise on its own
---@field allowManualRaise boolean? manual raise inputs are ignored or not
---@field swapStallingMode integer? how swaps are treated with respect to stalling passive raise
---@field swapStallingPunish integer? how much health is deducted for stalling swaps
---@field allowAdjacentColors boolean? deprecated in v049, lives on the PanelSource now; if the panel generator is allowed to put panels of the same color next to each other (horizontally only)

local StackBehaviour = {}

---@param level integer?
function StackBehaviour.getV048Default(level)
  local allowAdjacentColors = true
  if level then
    allowAdjacentColors = (level < 8)
  end
  return {
    passiveRaise = true,
    allowManualRaise = true,
    swapStallingMode = 0,
    swapStallingPunish = 0,
    -- was level based in v048 and before
    allowAdjacentColors = allowAdjacentColors,
  }
end

function StackBehaviour.getV049Default()
  return {
    passiveRaise = true,
    allowManualRaise = true,
    swapStallingMode = 1,
    swapStallingPunish = 4,
    -- allowAdjacentColors was deprecated as a Stack setting, lives on the PanelSource now
  }
end

function StackBehaviour.getDefault()
  return StackBehaviour.getV049Default()
end

return StackBehaviour