local consts = require("common.engine.consts")
local tableUtils = require("common.lib.tableUtils")
local import = require("common.lib.import")
local addCursorInteractionInterface = import("./CursorInteractable")

---@class CursorNavigableOptions
---@field onFocus fun(cursorNavigable: CursorNavigable | UiElement)?
---@field onYield fun(cursorNavigable: CursorNavigable | UiElement)?

---@class CursorNavigable : CursorInteractable
---@field isNavigable boolean
---@field receiveFocus fun(cursorNavigable: CursorNavigable | UiElement, cursor: Cursor)
---@field receiveInputs fun(cursorNavigable: CursorNavigable | UiElement, cursor: Cursor, dt: number?)
---@field moveToNext fun(cursorNavigable: CursorNavigable | UiElement, cursor: Cursor)
---@field moveToPrevious fun(cursorNavigable: CursorNavigable | UiElement, cursor: Cursor)
---@field onFocus fun(cursorNavigable: CursorNavigable | UiElement)?
---@field onYield fun(cursorNavigable: CursorNavigable | UiElement)?

---@param cursorNavigable CursorNavigable | UiElement
---@param cursor Cursor
local function receiveFocus(cursorNavigable, cursor)
  if cursorNavigable.onFocus then
    cursorNavigable:onFocus()
  end

  for i, child in ipairs(cursorNavigable.children) do
    if child.receiveInputs and child.isVisible and child.isEnabled then
      cursor:updateHover(cursorNavigable, child)
      break
    end
  end
end

---@param cursorNavigable CursorNavigable | UiElement
---@param cursor Cursor
local function moveToNext(cursorNavigable, cursor)
  local hoveredIndex = tableUtils.indexOf(cursorNavigable.children, cursor.focusToHover[cursorNavigable])
  for i = hoveredIndex + 1, hoveredIndex + #cursorNavigable.children do
    local index = wrap(1, i, #cursorNavigable.children)
    local child = cursorNavigable.children[index]
    if child.receiveInputs and child.isEnabled and child.isVisible then
      cursor:updateHover(cursorNavigable, child)
      break
    end
  end
end

---@param cursorNavigable CursorNavigable | UiElement
---@param cursor Cursor
local function moveToPrevious(cursorNavigable, cursor)
  local hoveredIndex = tableUtils.indexOf(cursorNavigable.children, cursor.focusToHover[cursorNavigable])
  for i = hoveredIndex - 1, hoveredIndex - #cursorNavigable.children, -1 do
    local index = wrap(1, i, #cursorNavigable.children)
    local child = cursorNavigable.children[index]
    if child.receiveInputs and child.isEnabled and child.isVisible then
      cursor:updateHover(cursorNavigable, child)
      break
    end
  end
end

---@param cursorNavigable CursorNavigable | UiElement
---@param cursor Cursor
---@param dt number
local function defaultReceiveInputs(cursorNavigable, cursor, dt)
  local inputs = cursor.keyInput
  if inputs.isDown.Swap2 then
    GAME.theme:playCancelSfx()
    cursor:releaseFocus(cursorNavigable)
  elseif cursor.focusToHover[cursorNavigable].isNavigable and (inputs.isDown.Swap1 or inputs.isDown.Start) then
    GAME.theme:playValidationSfx()
    cursor:deepenFocus(cursor.focusToHover[cursorNavigable])
  elseif cursorNavigable.layout.characteristic == "horizontal" then
    if inputs:isPressedWithRepeat("Left", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
      GAME.theme:playMoveSfx()
      cursorNavigable:moveToPrevious(cursor)
    elseif inputs:isPressedWithRepeat("Right", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
        GAME.theme:playMoveSfx()
        cursorNavigable:moveToNext(cursor)
    elseif cursor.focusToHover[cursorNavigable].receiveInputs then
      local hovered = cursor.focusToHover[cursorNavigable]
      hovered:receiveInputs(cursor, dt)
    end
  elseif cursorNavigable.layout.characteristic == "vertical" then
    if inputs:isPressedWithRepeat("Up", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
      GAME.theme:playMoveSfx()
      cursorNavigable:moveToPrevious(cursor)
    elseif inputs:isPressedWithRepeat("Down", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
      GAME.theme:playMoveSfx()
      cursorNavigable:moveToNext(cursor)
    elseif cursor.focusToHover[cursorNavigable].receiveInputs then
      local hovered = cursor.focusToHover[cursorNavigable]
      hovered:receiveInputs(cursor, dt)
    end
  else
    GAME.theme:playCancelSfx()
  end
end

-- always call this on an instance, not the class
-- that is to make sure that the per-instance fields are set on the instance
---@param uiElement UiElement
---@param receiveInputs fun(cursorNavigable: CursorNavigable | UiElement, cursor: Cursor, dt: number?)?
---@return UiElement | CursorNavigable
local function addCursorNavigationInterface(uiElement, receiveInputs)
  addCursorInteractionInterface(uiElement, receiveInputs or defaultReceiveInputs)
  uiElement.receiveFocus = receiveFocus
  uiElement.moveToNext = moveToNext
  uiElement.moveToPrevious = moveToPrevious
  uiElement.isNavigable = true

  ---@cast uiElement +CursorNavigable
  return uiElement
end


return addCursorNavigationInterface