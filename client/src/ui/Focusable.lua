-- use in tandem with FocusDirector.lua

---@class Focusable
---@field receiveInputs fun(any, table, number?)
---@field isFocusable boolean
---@field hasFocus boolean?
---@field yieldFocus fun()?

---@class CursorInteractable
---@field interactsWithCursor boolean
---@field receiveInputs fun(any, Cursor, number?)

local function focusable(uiElement)
  uiElement.isFocusable = true
  uiElement.hasFocus = false
  if uiElement.receiveInputs == nil then
    uiElement.receiveInputs = function(inputs)
      error("Focusable UIElement of type " .. uiElement.TYPE .. " doesn't implement input interpretation")
    end
  end

  -- this function is implemented on the FocusDirector's side cause it is expected to know about what it is focusing
  -- but the focused element probably does not know what is focusing it
  -- table.yieldFocus = function(focusDirector, table)
  --   focusDirector.focused = nil
  --   table.hasFocus = false
  -- end
end

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

return focusable