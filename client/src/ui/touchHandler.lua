local input = require("client.src.inputManager")
-- handles all touch interactions
-- all elements that implement touch interactions must register themselves with the touch handler on construction

local touchHandler = {
  ---@type UiElement?
  touchedElement = nil,
  holdTimer = 0,
  draggedThisFrame = false,
}

-- Returns the element a touch at the position lands on
---@param x number
---@param y number
---@return UiElement?
local function getElementAt(x, y)
  local element = GAME.uiRoot:getTouchedElement(x, y)
  if not element then
    local activeScene = GAME.navigationStack:getActiveScene()
    if activeScene and activeScene.uiRoot then
      element = activeScene.uiRoot:getTouchedElement(x, y)
    end
  end
  return element
end

function touchHandler:touch(x, y)
  -- prevent multitouch
  if not self.touchedElement then
    self.touchedElement = getElementAt(x, y)

    if self.touchedElement and self.touchedElement.onTouch then
      self.touchedElement:onTouch(x, y)
    end
  end
end

function touchHandler:drag(x, y)
  if self.touchedElement then
    self.draggedThisFrame = true
    if self.touchedElement.onDrag then
      self.touchedElement:onDrag(x, y)
    end
  end
end

function touchHandler:release(x, y)
  if self.touchedElement then
    if self.touchedElement.onRelease then
      self.touchedElement:onRelease(x, y, self.holdTimer)
    end
    self.touchedElement = nil
    self.holdTimer = 0
    self.draggedThisFrame = false
  end
end

-- Passes a mouse wheel movement to the element under the mouse or the closest of its parents that scrolls
---@param x number
---@param y number
---@param dx number
---@param dy number
function touchHandler:scroll(x, y, dx, dy)
  local element = getElementAt(x, y)
  while element and not element.onScroll do
    element = element.parent
  end
  if element then
    element:onScroll(dx, dy)
  end
end

function touchHandler:update(dt)
  if self.touchedElement then
    if not self.draggedThisFrame then
      if self.touchedElement.onHold and self.touchedElement:inBounds(input.mouse.x, input.mouse.y) then
        self.holdTimer = self.holdTimer + dt
        self.touchedElement:onHold(self.holdTimer)
      end
    else
      self.draggedThisFrame = false
    end
  end
end

return touchHandler
