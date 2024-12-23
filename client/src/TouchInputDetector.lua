local logger = require("common.lib.logger")
local TouchDataEncoding = require("common.data.TouchDataEncoding")
local class = require("common.lib.class")

-- An object that manages touches on the screen and translates them to swaps on a stack
local TouchInputDetector =
  class(
  function(self, stack)
    self.stack = stack
    self.width = stack.engine.width
    self.height = stack.engine.height
    self.touchInputController = stack.engine.touchInputController
    -- whether the stack (panels) are touched.  Still true if touch is dragged off the stack, but not released yet.
    self.touchingStack = false
    --if any is {row = 0, col = 0}, this is the equivalent if the variable being nil and not refering to any panel on the stack
    -- cell that is currently touched, used to determine touch events (initiate, hold/drag, release) and as input for the current frame
    self.touchedCell = {row = 0, col = 0}
    -- cell that was touched last frame, used to determine touch events (initiate, hold/drag, release)
    self.previousTouchedCell = {row = 0, col = 0}
  end
)

-- Interprets the current touch state and returns an encoded character for the raise and cursor state
function TouchInputDetector:encodedCharacterForCurrentTouchInput()
  local shouldRaise = false
  local rowTouched = 0
  local columnTouched = 0
  --we'll encode the touched panel and if raise is happening in a unicode character
  --only one touched panel is supported, no multitouch.
  local mouseX, mouseY = GAME:transform_coordinates(love.mouse.getPosition())
  if love.mouse.isDown(1) then
    --note: a stack is still "touchingStack" if we touched the stack, and have dragged the mouse or touch off the stack, until we lift the touch
    --check whether the mouse is over this stack
    if self:isMouseOverStack(mouseX, mouseY) then
      self.touchingStack = true
      rowTouched, columnTouched = self:touchedPanelCoordinate(mouseX, mouseY)
    elseif self.touchingStack then --we have touched the stack, and have moved the touch off the edge, without releasing
      --let's say we are still touching the panel we had touched last.
      rowTouched = self.touchedCell.row
      columnTouched = self.touchedCell.col
    elseif self.touchingRaise then
      --note: changed this to an elseif.  
      --This means we won't be able to press raise by accident if we dragged too far off the stack, into the raise button
      --but we also won't be able to input swaps and press raise at the same time, though the network protocol allows touching a panel and raising at the same time
      --Endaris has said we don't need to be able to swap and raise at the same time anyway though (swap suspends raise).
      shouldRaise = true
    else
      shouldRaise = false
    end
  else
    self.touchingStack = false
    shouldRaise = false
    rowTouched = 0
    columnTouched = 0
  end
  if love.mouse.isDown(2) then
    --if using right mouse button on the stack, we are inputting "raise"
    --also works if we have left mouse buttoned the stack, dragged off, are still holding left mouse button, and then also hold down right mouse button.
    if self.touchingStack or self:isMouseOverStack(mouseX, mouseY) then
      shouldRaise = true
    end
  end

  self.previousTouchedCell.row = self.touchedCell.row
  self.previousTouchedCell.col = self.touchedCell.col
  self.touchedCell.row = rowTouched
  self.touchedCell.col = columnTouched

  local cursorRow, cursorColumn = self.touchInputController:handleTouch(self.touchedCell, self.previousTouchedCell)

  local result = TouchDataEncoding.touchDataToLatinString(shouldRaise, cursorRow, cursorColumn, self.width)
  return result
end

function TouchInputDetector:isMouseOverStack(mouseX, mouseY)
  return
    mouseX >= self.stack.panelOriginX * self.stack.gfxScale and mouseX <= (self.stack.panelOriginX + (self.width * 16)) * self.stack.gfxScale and
    mouseY >= self.stack.panelOriginY * self.stack.gfxScale and mouseY <= (self.stack.panelOriginY + (self.height* 16)) * self.stack.gfxScale
end

-- Returns the touched panel coordinate or nil if the stack isn't currently touched
function TouchInputDetector:touchedPanelCoordinate(mouseX, mouseY)
  local stackLeft = (self.stack.panelOriginX * self.stack.gfxScale)
  local stackTop = (self.stack.panelOriginY * self.stack.gfxScale)
  local panelSize = 16 * self.stack.gfxScale
  local stackRight = stackLeft + self.width * panelSize
  local stackBottom = stackTop + self.height * panelSize

  if mouseX < stackLeft then
    return 0, 0
  end
  if mouseY < stackTop then
    return 0, 0
  end
  if mouseX >= stackRight then
    return 0, 0
  end
  if mouseY >= stackBottom then
    return 0, 0
  end

  local displacement =  self.stack.engine.displacement * self.stack.gfxScale
  local row = math.floor((stackBottom - mouseY + displacement) / panelSize)
  local column = math.floor((mouseX - stackLeft) / panelSize) + 1

  return row, column
end

function TouchInputDetector:debugString()
  local inputs_to_print = ""
  inputs_to_print = inputs_to_print .. "\ntouchedCell:"..self.touchedCell.col..","..self.touchedCell.row
  inputs_to_print = inputs_to_print .. "\npreviousTouchedCell:"..self.previousTouchedCell.col..","..self.previousTouchedCell.row
  inputs_to_print = inputs_to_print .. "\ntouchingStack:"..(self.touchingStack and "true" or "false")
  inputs_to_print = inputs_to_print .. "\n" .. self.touchInputController:debugString()

  return inputs_to_print
end


return TouchInputDetector