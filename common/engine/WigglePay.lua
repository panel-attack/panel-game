--[[
  WigglePay is named after a move that was coined by the community as "wiggling".
  To wiggle means to chain swaps so rapidly that the passive raise of the stack is fully halted.
  While physically intense, players with the required talents could stall death for several seconds without actually interacting with the stack.
  Even more talented players could even move during a wiggle, thus potentially reaching solves they could not have with their legitimate invincibility frames alone.
  This module adds functions that attach a health cost to each swap of a wiggle if and only if a wiggle is used to stall death (rather than a stack raise)
  Notably swaps are only considered part of a wiggle if they repeat a swap between two panels that were already swapped to escape death once.
  In that scenario, a set amount of health (swapStallingPunish) is subtracted from the Stack's health provided the player health would still be at least 1 afterwards.
  If there is not enough health, the swap is denied instead.
]]
local WigglePay = {}

---@param stack Stack
---@return boolean # if the stack is in a state where swaps are the only thing keeping the player alive
function WigglePay.isActive(stack)
  if stack.behaviours.swapStallingMode == 0 then
    return false
  elseif stack.behaviours.swapStallingPunish == 0 then
    return false
  elseif not stack:isToppedOut() then
    return false
  elseif stack.pre_stop_time ~= 0 then
    return false
  elseif stack.stop_time ~= 0 then
    return false
  elseif stack.shake_time ~= 0 then
    return false
  elseif (stack.n_active_panels - stack.swappingPanelCount) ~= 0 then
    return false
  end

  return true
end

---@param stack Stack
---@param panel1 Panel
---@param panel2 Panel
---@return boolean # if the panels can be swapped
---@return integer healthCost
function WigglePay.canSwap(stack, panel1, panel2)
  if not WigglePay.isActive(stack) then
    return true, 0
  end

  local row = stack.cur_row
  local col = stack.cur_col
  for _, oldRecord in ipairs(stack.swapStallingBackLog) do
    if oldRecord.leftId == panel1.id and oldRecord.rightId == panel2.id and oldRecord.row == row and oldRecord.col == col then
      if stack.health > stack.behaviours.swapStallingPunish then
        return true, stack.behaviours.swapStallingPunish
      else
        return false, 0
      end
    end
  end

  return true, 0
end

---@param stack Stack
---@param panel1 Panel
---@param panel2 Panel
---@param healthCost integer
function WigglePay.registerSwap(stack, panel1, panel2, healthCost)
  if WigglePay.isActive(stack) then
    if healthCost == 0 then
      local newRecord = { leftId = panel1.id, rightId = panel2.id, row = stack.cur_row, col = stack.cur_col }
      -- mark the reverse swap of the swap initiated just now
      stack.swapStallingBackLog[#stack.swapStallingBackLog+1] = { leftId = newRecord.rightId, rightId = newRecord.leftId, row = stack.cur_row, col = stack.cur_col }
      -- and the swap itself so it's already marked in case the reverse swap happens and logic stays simple for when data is added
      stack.swapStallingBackLog[#stack.swapStallingBackLog+1] = newRecord
    else
      stack.health = stack.health - healthCost
    end
  elseif #stack.swapStallingBackLog > 0 then
    stack.swapStallingBackLog = {}
  end
end


return WigglePay