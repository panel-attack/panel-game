local input = require("client.src.inputManager")

-- canvas pixels a touch moves before it becomes a drag for an element that doesn't take drags itself
local DRAG_THRESHOLD = 8

-- The touch router: the only place that decides what the mouse or a finger is over and which element gets each event.
-- It hit-tests the elements' layout rects in the game's ui tree, sends every event to the element under the touch and on
-- up through its parents until one handles it, decides a scroll against a tap, scrolls the elements that clip, and sets
-- the touched element's pressed state.
local touchHandler = {
  ---@type UiElement? the element the touch landed on
  touchedElement = nil,
  ---@type UiElement? the element taking the drags and the release: the touched element if it takes drags, or else the
  --- closest of its parents that does once the touch moved past the threshold
  draggingElement = nil,
  ---@type UiElement? the element the touch scrolls, once it moved past the threshold with an element that can scroll
  --- closer to the touched element than any that takes drags
  scrollingElement = nil,
  -- where the scrolling element was scrolled to when the touch started scrolling it
  scrollStartX = 0,
  scrollStartY = 0,
  touchX = 0,
  touchY = 0,
  holdTimer = 0,
  draggedThisFrame = false,
}

-- canvas pixels one notch of the mouse wheel scrolls
touchHandler.WHEEL_SCROLL_STEP = 40

-- Returns whether the element clips content that reaches past it
---@param element UiElement
---@return boolean
local function canScroll(element)
  if not element.layoutRules.clip then
    return false
  end
  local maxX, maxY = element:getMaxScroll()
  return maxX > 0 or maxY > 0
end

-- Returns whether a touch that moved this far scrolls the element: past the drag threshold along an axis the element
-- has content to scroll on
---@param element UiElement
---@param movedX number canvas pixels the touch moved sideways, in either direction
---@param movedY number canvas pixels the touch moved up or down
---@return boolean
local function scrollsWithMovement(element, movedX, movedY)
  local maxX, maxY = element:getMaxScroll()
  return maxX > 0 and movedX >= DRAG_THRESHOLD or maxY > 0 and movedY >= DRAG_THRESHOLD
end

-- Returns whether the element handles any touch event or the mouse wheel, itself or by scrolling
---@param element UiElement
---@return boolean
local function takesTouch(element)
  local handler = element.onTouch or element.onDrag or element.onRelease or element.onHold or element.onScroll
  return handler ~= nil or canScroll(element)
end

-- Returns whether the element can still be touched: it is in the game's ui tree, and it and all its parents are visible
-- and enabled. A scene that leaves the screen during a touch takes the touched element out of reach.
---@param element UiElement
---@return boolean
local function canStillBeTouched(element)
  while element.parent do
    if not element.isVisible or not element.isEnabled then
      return false
    end
    element = element.parent
  end
  return element == GAME.uiRoot and element.isVisible and element.isEnabled
end

local hitTest

-- Returns the topmost of the element's floating children under the point that takes touches, or one inside them
---@param element UiElement
---@param x number
---@param y number
---@return UiElement?
local function hitTestFloatingChildren(element, x, y)
  for i = #element.children, 1, -1 do
    local child = element.children[i]
    local hit = child.layoutRules.floating ~= nil and hitTest(child, x, y)
    if hit then
      return hit
    end
  end
end

-- Returns the topmost of the children in the element's flow under the point that takes touches, or one inside them
---@param element UiElement
---@param x number
---@param y number
---@return UiElement?
local function hitTestFlowChildren(element, x, y)
  for i = #element.children, 1, -1 do
    local child = element.children[i]
    local hit = child.layoutRules.floating == nil and hitTest(child, x, y)
    if hit then
      return hit
    end
  end
end

-- Returns the topmost of the element's children under the point that takes touches, or one inside them
---@param element UiElement
---@param x number
---@param y number
---@return UiElement?
local function hitTestChildren(element, x, y)
  for i = #element.children, 1, -1 do
    local hit = hitTest(element.children[i], x, y)
    if hit then
      return hit
    end
  end
end

-- Returns the topmost visible, enabled element in the tree under the point that takes touches.
-- It hits what is drawn there: a child is hit outside its parent's rect too, unless the parent clips and the child is
-- in its flow, and a clipping parent's floating children are over the ones in its flow.
---@param element UiElement
---@param x number
---@param y number
---@return UiElement?
function hitTest(element, x, y)
  if not element.isVisible or not element.isEnabled then
    return nil
  end
  local isInside = element:inBounds(x, y)
  local hit
  if element.layoutRules.clip then
    hit = hitTestFloatingChildren(element, x, y) or (isInside and hitTestFlowChildren(element, x, y) or nil)
  else
    hit = hitTestChildren(element, x, y)
  end
  if hit then
    return hit
  end
  if isInside and takesTouch(element) then
    return element
  end
end

-- Returns the element under the point in the game's ui tree, which the scene on screen is part of
---@param x number
---@param y number
---@return UiElement?
local function elementAt(x, y)
  return hitTest(GAME.uiRoot, x, y)
end

-- Returns the element or the closest of its parents that has the handler
---@param element UiElement?
---@param handler string
---@return UiElement?
local function handlerOf(element, handler)
  while element and not element[handler] do
    element = element.parent
  end
  return element
end

-- Tells every parent of the element that keeps a selection among its children which of them the touch is in
---@param element UiElement
local function selectTouchedChild(element)
  local child = element
  local parent = element.parent
  while parent do
    if parent.selectChild then
      parent:selectChild(child)
    end
    child = parent
    parent = parent.parent
  end
end

-- Hands the touch over, once it moved far enough, to the closest of the touched element and its parents that takes drags
-- or scrolls the way the touch moved, so the touched element is no longer pressed
---@param x number
---@param y number
local function startDrag(x, y)
  local touched = touchHandler.touchedElement
  ---@cast touched UiElement
  local movedX = math.abs(x - touchHandler.touchX)
  local movedY = math.abs(y - touchHandler.touchY)
  if movedX < DRAG_THRESHOLD and movedY < DRAG_THRESHOLD then
    return
  end
  local element = touched
  while element and not element.onDrag and not scrollsWithMovement(element, movedX, movedY) do
    element = element.parent
  end
  if not element then
    return
  end
  touched:setState("pressed", false)
  if element.onDrag then
    touchHandler.draggingElement = element
    if element.onTouch and element ~= handlerOf(touched, "onTouch") then
      element:onTouch(touchHandler.touchX, touchHandler.touchY)
    end
  else
    touchHandler.scrollingElement = element
    touchHandler.scrollStartX = element.scrollX
    touchHandler.scrollStartY = element.scrollY
  end
end

-- Scrolls the scrolling element by how far the touch moved since it landed
---@param x number
---@param y number
local function scrollWithTouch(x, y)
  local handler = touchHandler
  handler.scrollingElement:setScroll(handler.scrollStartX + x - handler.touchX, handler.scrollStartY + y - handler.touchY)
end

-- Starts a touch on the element under the point, ignoring any other finger while one is down
---@param x number
---@param y number
function touchHandler:touch(x, y)
  if self.touchedElement then
    return
  end
  local element = elementAt(x, y)
  if not element then
    return
  end
  self.touchedElement = element
  self.touchX = x
  self.touchY = y
  if element.onDrag then
    self.draggingElement = element
  end
  element:setState("pressed", true)
  selectTouchedChild(element)
  local handler = handlerOf(element, "onTouch")
  if handler then
    handler:onTouch(x, y)
  end
end

-- Moves the touch: the element taking drags gets it, and a touch that moved far enough becomes a drag of a parent that
-- takes drags, or scrolls an element that can scroll. Nothing moves once the touched element can no longer be touched.
---@param x number
---@param y number
function touchHandler:drag(x, y)
  if not self.touchedElement or not canStillBeTouched(self.touchedElement) then
    return
  end
  self.draggedThisFrame = true
  if not self.draggingElement and not self.scrollingElement then
    startDrag(x, y)
  end
  if self.draggingElement then
    self.draggingElement:onDrag(x, y)
  elseif self.scrollingElement then
    scrollWithTouch(x, y)
  end
end

-- Ends the touch on the element dragging it, or else on the touched element or the closest of its parents that takes
-- releases; a touch that scrolled ends with the scroll and releases nothing, and neither does a touch on an element that
-- can no longer be touched
---@param x number
---@param y number
function touchHandler:release(x, y)
  local touched = self.touchedElement
  if not touched then
    return
  end
  local handler
  if canStillBeTouched(touched) then
    if self.scrollingElement then
      scrollWithTouch(x, y)
    else
      handler = handlerOf(self.draggingElement or touched, "onRelease")
    end
  end
  touched:setState("pressed", false)
  self.touchedElement = nil
  self.draggingElement = nil
  self.scrollingElement = nil
  if handler then
    handler:onRelease(x, y, self.holdTimer)
  end
  self.holdTimer = 0
  self.draggedThisFrame = false
end

-- Gives a mouse wheel movement to the closest element that takes it or can scroll, from the one under the mouse up
-- through its parents. One that takes it gets the movement in wheel notches; one that only scrolls is scrolled, a
-- positive y moving the content down to show what is above
---@param x number
---@param y number
---@param dx number
---@param dy number
function touchHandler:scroll(x, y, dx, dy)
  local element = elementAt(x, y)
  while element and not element.onScroll and not canScroll(element) do
    element = element.parent
  end
  if not element then
    return
  end
  if element.onScroll then
    element:onScroll(dx, dy)
  else
    element:scrollBy(dx * touchHandler.WHEEL_SCROLL_STEP, dy * touchHandler.WHEEL_SCROLL_STEP)
  end
end

-- Counts how long a touch that isn't moving has been held on the element under it, telling the element that takes holds
---@param dt number
function touchHandler:update(dt)
  local touched = self.touchedElement
  if not touched or self.scrollingElement or self.draggingElement and self.draggingElement ~= touched then
    return
  end
  if self.draggedThisFrame then
    self.draggedThisFrame = false
    return
  end
  local handler = handlerOf(touched, "onHold")
  if handler and canStillBeTouched(touched) and touched:inBounds(input.mouse.x, input.mouse.y) then
    self.holdTimer = self.holdTimer + dt
    handler:onHold(self.holdTimer)
  end
end

return touchHandler
