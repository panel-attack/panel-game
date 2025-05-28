

---@class CursorInteractable
---@field receiveInputs fun(cursorInteractable: CursorInteractable | UiElement, cursor: Cursor, dt: number?)
---@field setHover fun(cursorInteractable: CursorInteractable | UiElement, cursor: Cursor, hovering: boolean)
---@field isHovered fun(cursorInteractable: CursorInteractable | UiElement): boolean
---@field hoveringCursors table<Cursor, boolean?>

---@param cursorInteractable CursorInteractable | UiElement
---@param cursor Cursor
---@param dt number
local function defaultReceiveInputs(cursorInteractable, cursor, dt)
  error("UiElement of type " .. (cursorInteractable.TYPE or "unknown") .. " does not implement receiveInputs")
end

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


---@param uiElement UiElement
---@param receiveInputs fun(cursorInteractable: CursorInteractable | UiElement, cursor: Cursor, dt: number?)?
---@return UiElement | CursorInteractable
local function addCursorInteractionInterface(uiElement, receiveInputs)
  uiElement.hoveringCursors = {}
  uiElement.setHover = setHover
  uiElement.isHovered = isHovered
  uiElement.receiveInputs = receiveInputs or defaultReceiveInputs
  uiElement.isNavigable = false

  ---@cast uiElement +CursorInteractable
  return uiElement
end

return addCursorInteractionInterface