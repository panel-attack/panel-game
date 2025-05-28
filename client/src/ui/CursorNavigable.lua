local consts = require("common.engine.consts")
local tableUtils = require("common.lib.tableUtils")

---@class CursorNavigable
---@field receiveFocus fun(cursorNavigable: CursorNavigable | UiElement, cursor: Cursor)
---@field processCursorInput fun(cursorNavigable: CursorNavigable | UiElement, dt)
---@field receiveInputs fun(cursorNavigable: CursorNavigable | UiElement, inputs: KeyConfiguration, dt: number?)
---@field moveToNext fun(cursorNavigable: CursorNavigable | UiElement)
---@field moveToPrevious fun(cursorNavigable: CursorNavigable | UiElement)
---@field interactsWithCursor boolean
---@field isFocusable boolean
---@field cursor Cursor?
---@field hoveredElement UiElement?


local function receiveFocus(cursorNavigable, cursor)
  cursorNavigable.cursor = cursor
  if not cursorNavigable.hoveredElement then
    for i, child in ipairs(cursorNavigable.children) do
      if child.isVisible and child.isEnabled then
        cursorNavigable.hoveredElement = child
        break
      end
    end
  end
end

---@param cursorNavigable CursorNavigable | UiElement
local function moveToNext(cursorNavigable)
  local hoveredIndex = tableUtils.indexOf(cursorNavigable.children, cursorNavigable.hoveredElement)
  for i = hoveredIndex + 1, hoveredIndex + #cursorNavigable.children do
    local index = wrap(1, i, #cursorNavigable.children)
    local child = cursorNavigable.children[index]
    if child.receiveInputs and child.isEnabled and child.isVisible then
      hoveredIndex = index
      cursorNavigable.hoveredElement = cursorNavigable.children[hoveredIndex]
      break
    end
  end
end

---@param cursorNavigable CursorNavigable | UiElement
local function moveToPrevious(cursorNavigable)
  local hoveredIndex = tableUtils.indexOf(cursorNavigable.children, cursorNavigable.hoveredElement)
  for i = hoveredIndex - 1, hoveredIndex - #cursorNavigable.children, -1 do
    local index = wrap(1, i, #cursorNavigable.children)
    local child = cursorNavigable.children[index]
    if child.receiveInputs and child.isEnabled and child.isVisible then
      hoveredIndex = index
      cursorNavigable.hoveredElement = cursorNavigable.children[hoveredIndex]
      break
    end
  end
end

---@param cursorNavigable CursorNavigable | UiElement
---@param inputs KeyConfiguration
---@param dt number
local function defaultReceiveInputs(cursorNavigable, inputs, dt)
  if inputs.isDown.Swap2 then
    GAME.theme:playCancelSfx()
    cursorNavigable:escapeCallback()
  elseif cursorNavigable.layout.characteristic == "horizontal" then
    if inputs:isPressedWithRepeat("Left", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
      GAME.theme:playMoveSfx()
      cursorNavigable:moveToPrevious()
    elseif inputs:isPressedWithRepeat("Right", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
        GAME.theme:playMoveSfx()
        cursorNavigable:moveToNext()
    end
  elseif cursorNavigable.layout.characteristic == "vertical" then
    if inputs:isPressedWithRepeat("Up", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
      GAME.theme:playMoveSfx()
      cursorNavigable:moveToPrevious()
    elseif inputs:isPressedWithRepeat("Down", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
      GAME.theme:playMoveSfx()
      cursorNavigable:moveToNext()
    end
  elseif cursorNavigable.hoveredElement.isFocusable then
    if inputs.isDown.Swap1 or inputs.isDown.Start then
      GAME.theme:playValidationSfx()
      cursorNavigable:setFocus(cursorNavigable.hovered)
    end
  elseif cursorNavigable.hovered.receiveInputs then
    cursorNavigable.hovered:receiveInputs(inputs, dt)
  else
    GAME.theme:playCancelSfx()
  end
end

---@param cursorNavigable CursorNavigable | UiElement
---@param dt number
local function processCursorInput(cursorNavigable, dt)
  if cursorNavigable.cursor then
    cursorNavigable:receiveInputs(cursorNavigable.cursor.keyInput, dt)
  else
    error("Tried to process cursor inputs without a cursor")
  end
end

--[[ 
when adding it to a class instead of a single element: <br>
- make sure to annotate the class table as its own type using ---@type to get rid of the warning<br>
- have the class definition inherit CursorNavigable <br>
- you can discard the return value; it is only returned so that when doing it for an instance LuaLS can easily infer the new union type
]]
---@param uiElement UiElement
---@return UiElement | CursorNavigable
local function addCursorNavigationInterface(uiElement)
  uiElement.processCursorInput = processCursorInput
  uiElement.receiveFocus = receiveFocus
  uiElement.moveToNext = moveToNext
  uiElement.moveToPrevious = moveToPrevious
  uiElement.receiveInputs = defaultReceiveInputs

  ---@cast uiElement +CursorNavigable
  return uiElement
end


return addCursorNavigationInterface