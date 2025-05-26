local PATH = (...):gsub('%.[^%.]+$', '')
local UiElement = require(PATH .. ".UIElement")
local class = require("common.lib.class")
local HorizontalWrapLayout = require(PATH .. ".Layouts.HorizontalWrapLayout")
local Focusable = require(PATH .. ".Focusable")
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local input = require("client.src.inputManager")

---@class UniSizedContainerOptions : UiElementOptions
---@field childrenWidth integer
---@field childrenHeight integer

---@class UniSizedContainer : UiElement
---@operator call(UniSizedContainerOptions): UniSizedContainer
---@field childrenWidth integer
---@field childrenHeight integer
---@field selectedRow integer
---@field selectedColumn integer
---@field rows UiElement[][]
local UniSizedContainer = class(
function(self, options)
  assert(options.childrenHeight and options.childrenWidth)

  self.childrenWidth = options.childrenWidth
  self.childrenHeight = options.childrenHeight
  self.minHeight = self.padding * 2 + self.childrenHeight

  self.selectedRow = 1
  self.selectedColumn = 1
end,
UiElement)

Focusable(UniSizedContainer)
UniSizedContainer.layout = HorizontalWrapLayout

---@param uiElement UiElement
---@param index integer?
function UniSizedContainer:addChild(uiElement, index)
  uiElement.minWidth = self.childrenWidth
  uiElement.maxWidth = self.childrenWidth
  uiElement.minHeight = self.childrenHeight
  uiElement.maxHeight = math.min(self.childrenHeight, uiElement.maxHeight)
  uiElement.hAlign = self.hAlignChildren
  uiElement.vAlign = self.vAlignChildren

  UiElement.addChild(self, uiElement, index)
end

---@return boolean? # if the movement was successful
function UniSizedContainer:moveToPreviousRow()
  if not self.rows or #self.rows == 1 then
    return false
  end

  local nextRow = wrap(1, self.selectedRow - 1, #self.rows)
  if self.rows[nextRow][self.selectedColumn] then
    self.selectedRow = nextRow
    self.hovered = self.rows[self.selectedRow][self.selectedColumn]
    return true
  else
    return false
  end
end

---@return boolean? # if the movement was successful
function UniSizedContainer:moveToNextRow()
  if not self.rows or #self.rows == 1 then
    return false
  end

  local nextRow = wrap(1, self.selectedRow + 1, #self.rows)
  if self.rows[nextRow][self.selectedColumn] then
    self.selectedRow = nextRow
    self.hovered = self.rows[self.selectedRow][self.selectedColumn]
    return true
  else
    return false
  end
end

---@return boolean? # if the movement was successful
function UniSizedContainer:moveToPrevious()
  if not self.rows or not self.rows[self.selectedRow] or #self.rows[self.selectedRow] == 1 then
    return false
  end

  self.selectedColumn = wrap(1, self.selectedColumn - 1, #self.rows[self.selectedRow])
  self.hovered = self.rows[self.selectedRow][self.selectedColumn]
  return true
end

---@return boolean? # if the movement was successful
function UniSizedContainer:moveToNext()
  if not self.rows or not self.rows[self.selectedRow] or #self.rows[self.selectedRow] == 1 then
    return false
  end

  self.selectedColumn = wrap(1, self.selectedColumn + 1, #self.rows[self.selectedRow])
  self.hovered = self.rows[self.selectedRow][self.selectedColumn]
  return true
end

function UniSizedContainer:receiveInputs(inputs, dt)
  if self.focused then
    self.focused:receiveInputs(inputs, dt, self.player)
  elseif inputs.isDown.Swap2 then
    if self.yieldFocus then
      GAME.theme:playCancelSfx()
      self:yieldFocus()
    end
  elseif inputs:isPressedWithRepeat("Left", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    if self:moveToPrevious() then
      GAME.theme:playMoveSfx()
    end
  elseif inputs:isPressedWithRepeat("Right", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    if self:moveToNext() then
      GAME.theme:playMoveSfx()
    end
  elseif inputs:isPressedWithRepeat("Up", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    if self:moveToPreviousRow() then
      GAME.theme:playMoveSfx()
    end
  elseif inputs:isPressedWithRepeat("Down", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    if self:moveToNextRow() then
      GAME.theme:playMoveSfx()
    end
  elseif inputs.isDown.Swap1 or inputs.isDown.Start then
    if self.hovered.isFocusable then
      GAME.theme:playValidationSfx()
      self:setFocus(self.hovered)
    elseif self.hovered.receiveInputs then
      self.hovered:receiveInputs(inputs, dt)
    else
      GAME.theme:playCancelSfx()
    end
  end
end

function UniSizedContainer:onResized()
  if #self.children == 0 then
    return
  end

  local selectedChild
  if self.rows then
    selectedChild = self.rows[self.selectedRow][self.selectedColumn]
  end

  local rowIndex = 1
  local rows = {{}}
  local yOffset = self.padding
  for i, child in ipairs(self.children) do
    if child.y > yOffset then
      yOffset = child.y
      rowIndex = rowIndex + 1
      rows[rowIndex] = {}
    end
    table.insert(rows[rowIndex], child)
  end

  self.rows = rows

  if selectedChild then
    for row = 1, #self.rows do
      for col = 1, #self.rows[row] do
        if self.rows[row][col] == selectedChild then
          self.selectedRow = row
          self.selectedColumn = col
          break
        end
      end
    end
  end
end

function UniSizedContainer:drawSelf()
  UiElement.drawSelf(self)
  if self.hasFocus then
    local selectedChild = self.rows[self.selectedRow][self.selectedColumn]
    local x, y = selectedChild:getScreenPos()
    GraphicsUtil.setColor(1, 1, 1, 0.2)
    love.graphics.rectangle("fill", x, y, selectedChild.width, selectedChild.height)
    GraphicsUtil.setColor(1, 1, 1, 1)

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