

---@class CursorInteractable
---@field receiveInputs fun(cursorInteractable: CursorInteractable | UiElement, cursor: Cursor, dt: number?)
---@field setHover fun(cursorInteractable: CursorInteractable | UiElement, cursor: Cursor, hovering: boolean)
---@field isHovered fun(cursorInteractable: CursorInteractable | UiElement): boolean
---@field hoveringCursors table<Cursor, boolean?>

---@param cursorInteractable CursorInteractable | UiElement
---@param cursor Cursor
---@param hovering boolean
local function setHover(cursorInteractable, cursor, hovering)
  if not hovering then
    cursorInteractable.hoveringCursors[cursor] = nil
  else
    cursorInteractable.hoveringCursors[cursor] = true
  end
end

---@param cursorInteractable CursorInteractable | UiElement
local function isHovered(cursorInteractable)
  if next(cursorInteractable.hoveringCursors) then
    return true
  else
    return false
  end
end

-- always call this on an instance, not the class
-- that is to make sure that the per-instance fields are set on the instance
---@param uiElement UiElement
---@param receiveInputs fun(cursorInteractable: CursorInteractable | UiElement, cursor: Cursor, dt: number?)
---@return UiElement | CursorInteractable
local function addCursorInteractionInterface(uiElement, receiveInputs)
  uiElement.hoveringCursors = {}
  uiElement.setHover = setHover
  uiElement.isHovered = isHovered
  if not uiElement.receiveInputs or uiElement.receiveInputs ~= receiveInputs then
    uiElement.receiveInputs = receiveInputs
  end
  uiElement.isNavigable = false

  ---@cast uiElement +CursorInteractable
  return uiElement
end

return addCursorInteractionInterface