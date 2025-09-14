---@class StackBehaviours
---@field passiveRaise boolean? if the stack will passively rise on its own
---@field allowManualRaise boolean? manual raise inputs are ignored or not
---@field swapStallingMode integer? how swaps are treated with respect to stalling passive raise
---@field swapStallingPunish integer? how much health is deducted for stalling swaps
---@field delaySimulationUntil SimulationDelayOptions?

---@alias SimulationDelayOptions ("firstSwap" | "firstInput" | "countdownEnded")

local StackBehaviour = {}

function StackBehaviour.getV048Default()
  return {
    passiveRaise = true,
    allowManualRaise = true,
    swapStallingMode = 0,
    swapStallingPunish = 0,
    delaySimulationUntilFirstInput = nil,
  }
end

function StackBehaviour.getV049Default()
  return {
    passiveRaise = true,
    allowManualRaise = true,
    swapStallingMode = 1,
    swapStallingPunish = 4,
    delaySimulationUntilFirstInput = nil,
  }
end

function StackBehaviour.getDefault()
  return StackBehaviour.getV049Default()
end

return StackBehaviour