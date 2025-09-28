local logger = require("common.lib.logger")
local util = require("common.lib.util")
local class = require("common.lib.class")

local TOUCH_SWAP_COOLDOWN = 5  -- default number of cooldown frames between touch-input swaps, applied after the first 2 swaps after a touch is initiated, to prevent excessive or accidental stealths

-- An object that manages touches on the screen and translates them to swaps on a stack
local TouchInputController =
  class(
  function(self, stack)
    self.stack = stack
    -- this is the destination column we will always be trying to swap toward. 
    -- Set to touchedCell.col or if that's 0, use previousTouchedCell.col, or if that's 0, use existing self.touchTargetColumn. 
    -- if target is reached by self.cur_col, set self.touchTargetColumn to 0.
    self.touchTargetColumn = 0
    -- origin of a failed swap due to the target panel being unswappable, leave the cursor here even if the touch is released.
    self.lingeringTouchCursor = {row = 0, col = 0}
    -- number of swaps that have been initiated since the last touch
    self.swapsThisTouch = 0
    -- if this is zero, a swap can happen.
    -- set to TOUCH_SWAP_COOLDOWN on each swap after the first. decrement by 1 each frame.
    self.touchSwapCooldownTimer = 0
  end
)

function TouchInputController:lingeringTouchIsSet()
  if self.lingeringTouchCursor.col ~= 0 and self.lingeringTouchCursor.row ~= 0 then
    return true
  end
  return false
end

function TouchInputController:clearLingeringTouch()
  self.lingeringTouchCursor.row = 0
  self.lingeringTouchCursor.col = 0
end

function TouchInputController:clearSelection()
  self:clearLingeringTouch()
  self.swapsThisTouch = 0
  self.touchSwapCooldownTimer = 0
end

-- Given the current touch state, returns the new row and column of the cursor
function TouchInputController:handleTouch(touchedCell, previousTouchedCell)
  if self.touchSwapCooldownTimer > 0 then
    self.touchSwapCooldownTimer = self.touchSwapCooldownTimer - 1
  end

  if self.stack.cursorLock then
    -- whatever you touch, nothing shall happen if the cursor is locked
    return 0, 0
  else
    -- depending on panel state transformations we may have to undo a lingering touch
    -- if panel at cur_row, cur_col gets certain flags, deselect it, and end the touch
    if self:shouldUnselectPanel() then
      self:clearSelection()
      return 0, 0
    end

    self:updateTouchTargetColumn(touchedCell, previousTouchedCell)

    if self:touchInitiated(touchedCell, previousTouchedCell) then
      self.swapsThisTouch = 0
      self.touchSwapCooldownTimer = 0

      -- check for attempt to swap with self.lingeringTouchCursor
      if self:lingeringTouchIsSet() then
        if self.lingeringTouchCursor.row == touchedCell.row
          and math.abs(touchedCell.col - self.lingeringTouchCursor.col) == 1 then
          -- the touched panel is on the same row and adjacent to the selected panel
          -- thus fulfilling the minimum condition to be swapped
          local cursorRow, cursorColumn = self:tryPerformTouchSwap(touchedCell.col)
          if cursorColumn ~= self.stack.cur_col then
          -- if the swap succeeded, the lingering touch has to be cleared
            self:clearLingeringTouch()
          end

          return cursorRow, cursorColumn
        else
          -- We touched somewhere else on the stack
          -- clear cursor, lingering and touched panel so we can do another initial touch next frame
          self:clearLingeringTouch()
          -- this is so previousTouchedCell is 0, 0 on the next frame allowing us to run into touchInitiated again
          touchedCell.row = 0
          touchedCell.col = 0
          return 0, 0
        end
      else
        if self:panelIsSelectable(touchedCell.row, touchedCell.col) then
          return touchedCell.row, touchedCell.col
        else
          return 0, 0
        end
      end
    elseif self:touchOngoing(touchedCell, previousTouchedCell) then
      if self:lingeringTouchIsSet() then
        -- buffered swaps are currently not enabled due to balancing concerns
        -- always keep the current cursor location and don't try to process a swap under this condition
        -- the lingering cursor should not be cleared so the code keeps running into this branch until the player releases the touch
        return self.stack.cur_row, self.stack.cur_col
      else
        return self:tryPerformTouchSwap(touchedCell.col)
      end
    elseif self:touchReleased(touchedCell, previousTouchedCell) then
      if self:lingeringTouchIsSet() then
        -- once a lingering touch cursor is active, the player has to release and tap again to move the panel
        self.touchTargetColumn = 0
      elseif self.touchTargetColumn ~= 0 then
        -- remove the cursor from display if it has reached self.touchTargetColumn
        return self:tryPerformTouchSwap(self.touchTargetColumn)
      end
      return self.lingeringTouchCursor.row, self.lingeringTouchCursor.col
    else
      -- there is no on-going touch but there may still be a target to swap to from the last release
      if self.touchTargetColumn ~= 0 then
        return self:tryPerformTouchSwap(self.touchTargetColumn)
      end

      return self.lingeringTouchCursor.row, self.lingeringTouchCursor.col
    end
  end
end

function TouchInputController:updateTouchTargetColumn(touchedCell, previousTouchedCell)
  if touchedCell and touchedCell.col ~= 0 then
    self.touchTargetColumn = touchedCell.col
  elseif previousTouchedCell and previousTouchedCell.col ~= 0 then
    self.touchTargetColumn = previousTouchedCell.col
    --else retain the value set to self.touchTargetColumn previously
  end

  -- upon arriving at the target column or when the cursor is lost, target is lost as well
  if self.touchTargetColumn == self.stack.cur_col or self.stack.cur_col == 0 then
    self.touchTargetColumn = 0
  end
end

function TouchInputController:shouldUnselectPanel()
  if (self.stack.cur_row ~= 0 and self.stack.cur_col ~= 0) then
    return not self:panelIsSelectable(self.stack.cur_row, self.stack.cur_col)
  end
  return false
end

function TouchInputController:panelIsSelectable(row, column)
  local panel = self.stack.panels[row][column]
  if not panel.isGarbage and
     (panel.state == "normal" or
      panel.state == "landing" or
      panel.state == "swapping") then
    return true
  else
    return false
  end
end

-- returns the coordinate of the cursor after the swap
-- returns 0, 0 or an alternative coordinate if no swap happened
function TouchInputController:tryPerformTouchSwap(targetColumn)
  if self.touchSwapCooldownTimer == 0
  and self.stack.cur_col ~= 0 and targetColumn ~= self.stack.cur_col then
    local swapSuccessful = false
    -- +1 for swapping to the right, -1 for swapping to the left
    local swapDirection = math.sign(targetColumn - self.stack.cur_col)
    local swapOrigin = {row = self.stack.cur_row, col = self.stack.cur_col}
    local swapDestination = {row = self.stack.cur_row, col = self.stack.cur_col + swapDirection}

    if swapDirection == 1 then
      swapSuccessful = self.stack:canSwap(swapOrigin.row, swapOrigin.col)
    else
      swapSuccessful = self.stack:canSwap(swapDestination.row, swapDestination.col)
    end

    if swapSuccessful then
      self.swapsThisTouch = self.swapsThisTouch + 1
      --third swap onward is slowed down to prevent excessive or accidental stealths
      if self.swapsThisTouch >= 2 then
        self.touchSwapCooldownTimer = TOUCH_SWAP_COOLDOWN
      end
      return self.stack.cur_row, swapDestination.col
    else
      --we failed to swap toward the target
      --if both origin and destination are blank panels
      if (self.stack.panels[swapOrigin.row][swapOrigin.col].color == 0
        and self.stack.panels[swapDestination.row][swapDestination.col].color == 0) then
        --we tried to swap two empty panels.  Let's put the cursor on swap_destination
        return swapDestination.row, swapDestination.col
      elseif not self.stack.panels[swapDestination.row][swapDestination.col]:canSwap() then
        -- there are unswappable (likely clearing) panels in the way of the swap 
        -- let's set lingeringTouchCursor to the origin of the failed swap
        logger.trace("lingeringTouchCursor was set because destination panel was not swappable")
        self.lingeringTouchCursor.row = self.stack.cur_row
        self.lingeringTouchCursor.col = self.stack.cur_col
        -- and cancel the swap for consecutive frames
        self.touchTargetColumn = 0
      end
    end
  end
  -- either we didn't move or the cursor stays where it is, could be either 0,0 or on the previously touched panel
  -- in any case, the respective tracking fields (lingering, previous etc) have been set on a previous frame already
  return self.stack.cur_row, self.stack.cur_col
end

function TouchInputController:touchInitiated(touchedCell, previousTouchedCell)
  return (not previousTouchedCell or (previousTouchedCell.row == 0 and previousTouchedCell.col == 0)) 
  and touchedCell and not (touchedCell.row == 0 and touchedCell.col == 0)
end

function TouchInputController:touchOngoing(touchedCell, previousTouchedCell)
  return touchedCell and not (touchedCell.row == 0 and touchedCell.col == 0)
  and previousTouchedCell and previousTouchedCell.row ~= 0 and previousTouchedCell.column ~= 0
end

function TouchInputController:touchReleased(touchedCell, previousTouchedCell)
  return (previousTouchedCell and not (previousTouchedCell.row == 0 and previousTouchedCell.col == 0))
  and (not touchedCell or (touchedCell.row == 0 and touchedCell.col == 0))
end

function TouchInputController:stackIsCreatingNewRow()
  if self.lingeringTouchCursor and self.lingeringTouchCursor.row and self.lingeringTouchCursor.row ~= 0 then
    self.lingeringTouchCursor.row = util.bound(1,self.lingeringTouchCursor.row + 1, self.stack.top_cur_row)
  end
end

-- Returns a debug string useful for printing on screen during debugging
function TouchInputController:debugString()
  local inputs_to_print = ""
  inputs_to_print = inputs_to_print .. "\ncursor:".. self.stack.cur_col ..",".. self.stack.cur_row
  inputs_to_print = inputs_to_print .. "\ntouchTargetColumn:"..self.touchTargetColumn
  inputs_to_print = inputs_to_print .. "\nlingeringTouchCursor:"..self.lingeringTouchCursor.col..","..self.lingeringTouchCursor.row
  inputs_to_print = inputs_to_print .. "\nswapsThisTouch:"..self.swapsThisTouch
  inputs_to_print = inputs_to_print .. "\ntouchSwapCooldownTimer:"..self.touchSwapCooldownTimer
  return inputs_to_print
end

return TouchInputController