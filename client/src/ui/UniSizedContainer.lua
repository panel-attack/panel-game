local import = require("common.lib.import")
local UiElement = import("./UIElement")
local class = require("common.lib.class")
local HorizontalWrapLayout = import("./Layouts.HorizontalWrapLayout")
local Focusable = import("./Focusable")
local consts = require("client.src.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local input = require("client.src.inputManager")
local addCursorNavigationInterface = import("./CursorNavigable")
local tableUtils = require("common.lib.tableUtils")

---@class UniSizedContainerOptions : UiElementOptions, CursorNavigableOptions
---@field childrenWidth integer
---@field childrenHeight integer

-- a layout and navigation focused container that arranges children horizontally <br>
-- when not enough width available it will automatically wrap around further elements to the next row <br>
-- due to all children being forced to the same size, it can automatically adjust navigation to offer grid-like navigation
--  but it's not a real grid!
---@class UniSizedContainer : UiElement, CursorNavigable
---@operator call(UniSizedContainerOptions): UniSizedContainer
---@field childrenWidth integer
---@field childrenHeight integer
---@field rows UiElement[][]
---@field childToRow table<UiElement, integer>
---@overload fun(options: UniSizedContainerOptions): UniSizedContainer
local UniSizedContainer = class(
function(self, options)
  assert(options.childrenHeight and options.childrenWidth)

  self.childrenWidth = options.childrenWidth
  self.childrenHeight = options.childrenHeight
  self.minHeight = self.padding * 2 + self.childrenHeight

  addCursorNavigationInterface(self, self.receiveInputs)
  self.onFocus = options.onFocus
  self.onYield = options.onYield
end,
UiElement)

UniSizedContainer.TYPE = "UniSizedContainer"
UniSizedContainer.layout = HorizontalWrapLayout

---@param uiElement UiElement
---@param index integer?
function UniSizedContainer:addChild(uiElement, index)
  uiElement.minWidth = self.childrenWidth
  uiElement.maxWidth = self.childrenWidth
  uiElement.minHeight = self.childrenHeight
  uiElement.maxHeight = math.min(self.childrenHeight, uiElement.maxHeight)

  UiElement.addChild(self, uiElement, index)
end

---@param cursor Cursor
---@return boolean? # if the movement was successful
function UniSizedContainer:moveToPreviousRow(cursor)
  if not self.rows or #self.rows == 1 then
    return false
  end

  local selectedChild = cursor.focusToHover[self]
  local currentRow = self.childToRow[selectedChild]
  local currentCol = tableUtils.indexOf(self.rows[currentRow], selectedChild)
  local nextRow = wrap(1, currentRow - 1, #self.rows)
  if not self.rows[nextRow][currentCol] then
    -- if the wrapped elements don't extend into the selected columns, redo the wrap without considering that row
    nextRow = wrap(1, currentRow - 1, #self.rows - 1)
  end
  if self.rows[nextRow][currentCol] then
    cursor:updateHover(self, self.rows[nextRow][currentCol])
    return true
  else
    return false
  end
end

---@param cursor Cursor
---@return boolean? # if the movement was successful
function UniSizedContainer:moveToNextRow(cursor)
  if not self.rows or #self.rows == 1 then
    return false
  end

  local selectedChild = cursor.focusToHover[self]
  local currentRow = self.childToRow[selectedChild]
  local currentCol = tableUtils.indexOf(self.rows[currentRow], selectedChild)
  local nextRow = wrap(1, currentRow + 1, #self.rows)
  if not self.rows[nextRow][currentCol] then
    -- if the wrapped elements don't extend into the selected columns, redo the wrap without considering that row
    nextRow = wrap(1, currentRow + 1, #self.rows - 1)
  end
  if self.rows[nextRow][currentCol] then
    cursor:updateHover(self, self.rows[nextRow][currentCol])
    return true
  else
    return false
  end
end

---@param cursor Cursor
---@return boolean? # if the movement was successful
function UniSizedContainer:moveToPrevious(cursor)
  local selectedChild = cursor.focusToHover[self]
  local currentRow = self.childToRow[selectedChild]

  if not self.rows or not self.rows[currentRow] or #self.rows[currentRow] == 1 then
    return false
  end

  local currentCol = tableUtils.indexOf(self.rows[currentRow], selectedChild)
  local nextCol = wrap(1, currentCol - 1, #self.rows[currentRow])
  cursor:updateHover(self, self.rows[currentRow][nextCol])
  return true
end

---@param cursor Cursor
---@return boolean? # if the movement was successful
function UniSizedContainer:moveToNext(cursor)
  local selectedChild = cursor.focusToHover[self]
  local currentRow = self.childToRow[selectedChild]

  if not self.rows or not self.rows[currentRow] or #self.rows[currentRow] == 1 then
    return false
  end

  local currentCol = tableUtils.indexOf(self.rows[currentRow], selectedChild)
  local nextCol = wrap(1, currentCol + 1, #self.rows[currentRow])
  cursor:updateHover(self, self.rows[currentRow][nextCol])
  return true
end

---@param cursor Cursor
---@param dt number?
function UniSizedContainer:receiveInputs(cursor, dt)
  local inputs = cursor.keyInput
  if inputs.isDown.Swap2 then
    GAME.theme:playCancelSfx()
    cursor:releaseFocus(self)
  elseif inputs:isPressedWithRepeat("Left", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    if self:moveToPrevious(cursor) then
      GAME.theme:playMoveSfx()
    else
      GAME.theme:playCancelSfx()
    end
  elseif inputs:isPressedWithRepeat("Right", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    if self:moveToNext(cursor) then
      GAME.theme:playMoveSfx()
    else
      GAME.theme:playCancelSfx()
    end
  elseif inputs:isPressedWithRepeat("Up", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    if self:moveToPreviousRow(cursor) then
      GAME.theme:playMoveSfx()
    else
      GAME.theme:playCancelSfx()
    end
  elseif inputs:isPressedWithRepeat("Down", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    if self:moveToNextRow(cursor) then
      GAME.theme:playMoveSfx()
    else
      GAME.theme:playCancelSfx()
    end
  else
    local selectedChild = cursor.focusToHover[self]
    if selectedChild.isNavigable and (inputs.isDown.Swap1 or inputs.isDown.Start) then
      GAME.theme:playValidationSfx()
      cursor:deepenFocus(selectedChild)
    elseif selectedChild.receiveInputs then
      selectedChild:receiveInputs(cursor, dt)
    else
      GAME.theme:playCancelSfx()
    end
  end
end

function UniSizedContainer:onResized()
  if #self.children == 0 then
    return
  end

  local rowIndex = 1
  local rows = {{}}
  local childToRow = {}
  local yOffset = self.children[1].y
  for i, child in ipairs(self.children) do
    if child.y > yOffset then
      yOffset = child.y
      rowIndex = rowIndex + 1
      rows[rowIndex] = {}
    end
    table.insert(rows[rowIndex], child)
    childToRow[child] = rowIndex
  end

  self.rows = rows
  self.childToRow = childToRow
end

function UniSizedContainer:drawSelf()
  UiElement.drawSelf(self)
  if self:isHovered() then
    if input.isDown["Left"] or input.isPressed["Left"] then
      GraphicsUtil.printf("Left", 0, 0)
    elseif input.isDown["Right"] or input.isPressed["Right"] then
      GraphicsUtil.printf("Right", 0, 0)
    elseif input.isDown["Up"] or input.isPressed["Up"] then
      GraphicsUtil.printf("Up", 0, 0)
    elseif input.isDown["Down"] or input.isPressed["Down"] then
      GraphicsUtil.printf("Down", 0, 0)
    end
  end
end

function UniSizedContainer:getMinHeight()
  local h = self.padding * 2
  local maxHeight = 0
  self.tempRows = {}

  local childrenInCurrentRow = 0
  local rowCount = 1
  local width = self.padding
  for i, child in ipairs(self.children) do
    if child.isVisible then
      maxHeight = math.max(maxHeight, child.minHeight, child.layout.getMinHeight(child))
      if width + child.width + self.padding + childrenInCurrentRow * self.childGap > self.width then
        self.tempRows[rowCount] = maxHeight
        rowCount = rowCount + 1
        width = self.padding + child.width
        childrenInCurrentRow = 1
        maxHeight = child.newHeight
      else
        childrenInCurrentRow = childrenInCurrentRow + 1
        width = width + child.width
      end
      child.tempRow = rowCount
    end
  end

  self.tempRows[rowCount] = maxHeight
  h = h + (#self.tempRows - 1) * self.childGap
  for i = 1, #self.tempRows do
    h = h + self.tempRows[i]
  end

  return math.max(h, self.minHeight)
end

function UniSizedContainer:getPreferredWidth()
  return self.padding * 2 + (self.childrenWidth + self.childGap) * #self.children - self.childGap
end

return UniSizedContainer