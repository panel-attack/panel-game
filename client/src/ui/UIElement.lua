local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local DebugSettings = require("client.src.debug.DebugSettings")
local LayoutSolver = require("client.src.ui.LayoutSolver")
local Layout = require("client.src.ui.Layout")
local logger = require("common.lib.logger")

-- the keys of Clay's element declaration, the only rules an element has
local LAYOUT_RULE_KEYS = {
  id = true, sizing = true, padding = true, childGap = true, childAlignment = true, layoutDirection = true, clip = true,
  floating = true,
}

---@class UiElement
---@field isVisible boolean the element's own switch for being drawn, updated and touched; it stays true while a parent is
--- hidden, such as the root of a scene the navigation stack does not draw, so ask isOnScreen whether the element is shown
---@field isEnabled boolean if the element is currently eligible for touch interaction
---@field parent UiElement the element's parent it is getting position relative to via its properties
---@field children UiElement[] the element's children that get positioned relative to it
---@field id integer unique identifier of the element
---@field onTouch function? touch callback for when the element is being touched
---@field onDrag function? touch callback for when the mouse touching the element is dragged across the screen
---@field onRelease function? touch callback for when the mouse touching the element is released
---@field onHold function? touch callback for when a touch is held on the element for a longer duration
---@field isFocusable boolean true if selecting this element focuses it (see setFocusable)
---@field focusedChild table<InputSource, UiElement> per input source, the element this one has handed its inputs to
---@field focusCallbacks table<InputSource, function?> per input source, what to run when the focused child gives its focus back
---@field focusedBy table<InputSource, true> the input sources that currently have this element focused
---@field yielded table<InputSource, true> the input sources this element has given focus back for, until the focusing parent takes it
---@field layoutRect LayoutRect where the last layout placed the element, x and y measured from the parent, and the only size it has
---@field layoutState table the layout solver's working data
---@field layoutDirty boolean true from a change to the element or a child until its tree is next laid out
---@field isBeingLaidOut boolean? true on a root while the layout solver runs on its tree
---@field resizePending boolean true from the element being added until a layout runs its onResize
---@field layoutRules LayoutRules the element's LayoutRules: how it is sized and placed and how it places its children.
--- It is in its parent's flow unless the rules say it floats. The table and the tables in it are never changed, so
--- many elements can share them; setLayoutRule replaces the table with a changed copy.
---@field [any] any

---@class UiElementOptions
---@field isVisible boolean? if the element is currently visible for rendering (also disables touch interaction)
---@field isEnabled boolean? if the element is currently eligible for touch interaction
---@field layoutRules LayoutRules? the element's own LayoutRules: how it is sized and placed and how it places its children

local uniqueId = 0

-- The base class of every UI element. An element's place and size come only from the layout solver (see LayoutSolver):
-- code reads them from layoutRect, the last layout's result, and never computes or writes them itself.
-- An element sits in its parent's flow unless its rules make it float; only what overlaps others or sits outside the
-- flow should float.
-- Whatever owns a tree's root, like Game, a scene or a transition, lays the root out once a frame between the update and
-- the draw, and only a tree that changed since is solved again. Change rules or children in response to an event (input,
-- a data change, a new screen), never every frame, and never during a layout or a draw.
-- Drawing reads state and never changes it; an animation moves what is drawn rather than the layout, and starts once a
-- layout has given it any size it depends on.
---@class UiElement
---@overload fun(options: UiElementOptions): UiElement
local UIElement = class(
  ---@param self UiElement
  function(self, options)
    -- whether the ui element is visible
    self.isVisible = options.isVisible or options.isVisible == nil and true
    -- whether the ui element recieves events
    self.isEnabled = options.isEnabled or options.isEnabled == nil and true

    -- the parent element, position is relative to it
    self.parent = options.parent
    -- list of children elements
    self.children = options.children or {}

    self.isFocusable = false
    self.focusedChild = {}
    self.focusCallbacks = {}
    self.focusedBy = {}
    self.yielded = {}

    self.id = uniqueId
    uniqueId = uniqueId + 1

    self.layoutRules = options.layoutRules or {}
    for key in pairs(self.layoutRules) do
      assert(LAYOUT_RULE_KEYS[key], "no layout rule is called " .. tostring(key))
    end
    self.layoutRect = {x = 0, y = 0, width = 0, height = 0}
    self.layoutState = {}
    self.resizePending = false
    self:markLayoutDirty()
  end
)

UIElement.TYPE = "UIElement"

-- Notes that the element's tree needs laying out again, from the element up to its root
function UIElement:markLayoutDirty()
  assert(not self:getRoot().isBeingLaidOut, "the layout changed while it was being laid out")
  local element = self
  while element and not element.layoutDirty do
    element.layoutDirty = true
    element = element.parent
  end
end

-- Adds the child after the element's other children, in its flow unless its rules say it floats
---@param uiElement UiElement
function UIElement:addChild(uiElement)
  if uiElement.parent ~= self then
    self.children[#self.children + 1] = uiElement
    uiElement.parent = self
    uiElement.resizePending = true
    uiElement.layoutDirty = false
    uiElement:markLayoutDirty()
  end
end

-- Moves a child to the index in the children, which is its place in the flow
---@param uiElement UiElement
---@param index integer
function UIElement:moveChild(uiElement, index)
  for i, child in ipairs(self.children) do
    if child == uiElement then
      table.remove(self.children, i)
      break
    end
  end
  table.insert(self.children, index, uiElement)
  self:markLayoutDirty()
end

-- Sets one of the element's LayoutRules, by its key in Clay's element declaration, when the value is a different one.
-- The element's rules table is never changed: it is replaced by a copy with the rule set, so the elements sharing the
-- old table, like the ones a layout file's rules were given to, keep theirs. The value is kept, never changed, too.
---@param key string
---@param value any
function UIElement:setLayoutRule(key, value)
  assert(LAYOUT_RULE_KEYS[key], "no layout rule is called " .. tostring(key))
  if self.layoutRules[key] ~= value then
    local rules = shallowcpy(self.layoutRules)
    rules[key] = value
    self.layoutRules = rules
    self:markLayoutDirty()
  end
end

---@param sizing LayoutSizing?
---@param size number
---@return boolean # whether the sizing fixes the size along its axis
local function isFixedAt(sizing, size)
  return sizing ~= nil and sizing.type == "fixed" and sizing.min == size and sizing.max == size
end

-- Gives the element a fixed size, leaving its rules as they are when they already fix it at that size
---@param width number
---@param height number
function UIElement:setFixedSize(width, height)
  local sizing = self.layoutRules.sizing
  if not sizing or not isFixedAt(sizing.horizontal, width) or not isFixedAt(sizing.vertical, height) then
    self:setLayoutRule("sizing", Layout.fixedSize(width, height))
  end
end

-- overridable function to define extra behaviour to the element itself on resize
function UIElement:onResize()
end

-- Called by the layout solver with the element's final size; runs onResize when the element was added or its size changed
---@param width number
---@param height number
function UIElement:onLayoutSized(width, height)
  if self.resizePending or width ~= self.sizedWidth or height ~= self.sizedHeight then
    self.sizedWidth, self.sizedHeight = width, height
    self.resizePending = false
    self:onResize()
  end
end

---@return UiElement # the element at the top of this element's tree
function UIElement:getRoot()
  local root = self
  while root.parent do
    root = root.parent
  end
  return root
end

-- Clears the dirty marks of the element's tree
---@param element UiElement
local function markLaidOut(element)
  element.layoutDirty = false
  for _, child in ipairs(element.children) do
    markLaidOut(child)
  end
end

-- Lays out the tree under this root if anything in it changed since its last layout
function UIElement:layOut()
  assert(not self.parent, "only the root of a tree is laid out")
  assert(not self.isBeingLaidOut, "a layout of the tree started while it was being laid out")
  if self.layoutDirty then
    self.isBeingLaidOut = true
    LayoutSolver.solve(self)
    self.isBeingLaidOut = false
    markLaidOut(self)
  end
end

function UIElement:detach()
  if self.parent then
    for i, child in ipairs(self.parent.children) do
      if child.id == self.id then
        table.remove(self.parent.children, i)
        self:onDetach()
        self.parent:markLayoutDirty()
        self.parent = nil
        -- not drawn on its own, so laid out only when added again or asked to
        self.layoutDirty = true
        break
      end
    end
    return self
  end
end

function UIElement:onDetach()
end

-- The element's position on screen, from the layout rects of the element and its parents
---@return number x
---@return number y
function UIElement:getScreenPos()
  local x, y = 0, 0
  local element = self
  while element do
    x = x + element.layoutRect.x
    y = y + element.layoutRect.y
    element = element.parent
  end
  return x, y
end

---@return UiElement # the element at the top of this element's tree
function UIElement:getRoot()
  local root = self
  while root.parent do
    root = root.parent
  end
  return root
end

-- Returns whether the element is shown right now: it and every parent up to its root are visible. The navigation stack
-- hides the root of every scene it does not draw, so an element of a scene under another one is not on screen.
-- Worked out on every call from isVisible, so it never goes stale.
---@return boolean
function UIElement:isOnScreen()
  local element = self
  while element do
    if not element.isVisible then
      return false
    end
    element = element.parent
  end
  return true
end

-- The element's menu sounds, played only while it is on screen so a scene under another one stays silent
function UIElement:playMoveSfx()
  if self:isOnScreen() then
    GAME.theme:playMoveSfx()
  end
end

function UIElement:playValidationSfx()
  if self:isOnScreen() then
    GAME.theme:playValidationSfx()
  end
end

function UIElement:playCancelSfx()
  if self:isOnScreen() then
    GAME.theme:playCancelSfx()
  end
end

-- passes a retranslation request through the tree to reach all Labels
function UIElement:refreshLocalization()
  for _, uiElement in ipairs(self.children) do
    uiElement:refreshLocalization()
  end
end

function UIElement:update(dt)
  if self.isVisible then
    self:updateSelf(dt)
    self:updateChildren(dt)
  end
end

-- UiElements can override this method to do custom update logic
-- implementation is optional
function UIElement:updateSelf(dt)
end

function UIElement:updateChildren(dt)
  for _, uiElement in ipairs(self.children) do
    uiElement:update(dt)
  end
end

-- Outlines the element while element borders are shown
function UIElement:drawDebugOutline()
  if DebugSettings.showUIElementBorders() then
    GraphicsUtil.setColor(0, 0, 1, 1)
    GraphicsUtil.drawRectangle("line", 0, 0, self.layoutRect.width, self.layoutRect.height)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
end

-- Draws the element and its children moved to its layout rect, which is measured from its parent's
function UIElement:draw()
  if self.isVisible then
    local rect = self.layoutRect
    love.graphics.push("transform")
    love.graphics.translate(rect.x, rect.y)
    self:drawDebugOutline()
    self:drawSelf()
    self:drawChildren()
    love.graphics.pop()
  end
end

-- UiElements can override this method to do custom drawing at their layout rect, whose top left is 0, 0
-- implementation is optional
function UIElement:drawSelf()
end

-- Draws the children; an element that clips draws the children in its flow inside its rect, and its floating children on top
function UIElement:drawChildren()
  if self.layoutRules.clip then
    GraphicsUtil.clipStack:pushRectangle(0, 0, self.layoutRect.width, self.layoutRect.height)
    self:drawChildrenInFlow(true)
    GraphicsUtil.clipStack:pop()
    self:drawChildrenInFlow(false)
  else
    for _, uiElement in ipairs(self.children) do
      uiElement:draw()
    end
  end
end

-- Draws the children that are in the flow, or the ones that float
---@param inFlow boolean
function UIElement:drawChildrenInFlow(inFlow)
  for _, uiElement in ipairs(self.children) do
    if (uiElement.layoutRules.floating == nil) == inFlow then
      uiElement:draw()
    end
  end
end

-- Switches the element itself on or off for drawing, updating and touch, as for children that are temporarily
-- "offscreen", e.g. as part of a scrolling UiElement; whether it is shown also depends on its parents and scene (isOnScreen)
-- if you want to stop drawing an element, e.g. due to changing a subscreen,
--  the more opportune method is to simply remove it from the ui tree via detach()
function UIElement:setVisibility(isVisible)
  self.isVisible = isVisible
  self:onVisibilityChanged()
end

function UIElement:onVisibilityChanged()
end

function UIElement:setEnabled(isEnabled)
  self.isEnabled = isEnabled
  for _, uiElement in ipairs(self.children) do
    uiElement:setEnabled(isEnabled)
  end
end

function UIElement:inBounds(x, y)
  local screenX, screenY = self:getScreenPos()
  local rect = self.layoutRect
  return x > screenX and x < screenX + rect.width and y > screenY and y < screenY + rect.height
end

function UIElement:isTouchable()
  return self.onTouch
  or self.onHold
  or self.onDrag
  or self.onRelease
end

---Returns the foremost visible, enabled element containing the given screen-space coordinates.
---@param x number screen x coordinate of the touch
---@param y number screen y coordinate of the touch
---@return UiElement? element the coordinates intersect, or nil when none match
function UIElement:getTouchedElement(x, y)
  if self.isVisible and self.isEnabled and self:inBounds(x, y) then
    local touchedElement
    -- Check children in reverse order (last drawn = first touched)
    for i = #self.children, 1, -1 do
      touchedElement = self.children[i]:getTouchedElement(x, y)
      if touchedElement then
        return touchedElement
      end
    end

    if self:isTouchable() then
      return self
    end
  end
end

---Passes one input source's presses for this frame to the element it focused, or else handles them itself
---@param inputSource InputSource
---@param dt number
function UIElement:receiveInputs(inputSource, dt)
  if self.focusedChild[inputSource] then
    self:receiveInputsChild(inputSource, dt)
  else
    self:receiveInputsSelf(inputSource, dt)
  end
end

-- UiElements can override this method to interpret inputs while no child is focused
-- implementation is optional
---@param inputSource InputSource
---@param dt number
function UIElement:receiveInputsSelf(inputSource, dt)
end

---Forwards the inputs to the element focused for this input source and takes back focus if it yielded
---@param inputSource InputSource
---@param dt number
function UIElement:receiveInputsChild(inputSource, dt)
  local child = self.focusedChild[inputSource]
  child:receiveInputs(inputSource, dt)
  if child.yielded[inputSource] then
    self:unfocusChild(inputSource)
  end
end

---Sets whether selecting this element focuses it, so it receives the selecting input source's inputs until it yields,
---rather than only running its onSelect
---@param isFocusable boolean
function UIElement:setFocusable(isFocusable)
  self.isFocusable = isFocusable
end

---@return boolean # if this element interprets inputs itself rather than ignoring them
function UIElement:handlesInputs()
  return self.receiveInputsSelf ~= UIElement.receiveInputsSelf
end

---Hands this input source's inputs to child until it yields
---@param child UiElement
---@param inputSource InputSource
---@param onYield function? called once the child gives its focus back
function UIElement:focusChild(child, inputSource, onYield)
  local previous = self.focusedChild[inputSource]
  if previous then
    previous.focusedBy[inputSource] = nil
    previous:onUnfocus(inputSource)
  end
  self.focusedChild[inputSource] = child
  self.focusCallbacks[inputSource] = onYield
  child.focusedBy[inputSource] = true
  child.yielded[inputSource] = nil
  child:onFocus(inputSource)
end

---Hands this input source's inputs to child, and gives this element's own focus back once the child yields
---@param child UiElement
---@param inputSource InputSource
---@param onYield function? called once the child gives its focus back, before this element gives its own back
function UIElement:forwardFocus(child, inputSource, onYield)
  self:focusChild(child, inputSource, function()
    -- a release from outside has already taken this element's focus, so there is nothing to give back
    if self:hasFocus(inputSource) then
      if onYield then
        onYield()
      end
      self:yieldFocus(inputSource)
    end
  end)
end

-- UiElements can override this method to react to gaining focus for an input source, such as passing it on with forwardFocus
---@param inputSource InputSource
function UIElement:onFocus(inputSource)
end

---Called when this element loses focus for an input source; releases whatever this element focused in turn
---@param inputSource InputSource
function UIElement:onUnfocus(inputSource)
  self:unfocusChild(inputSource)
end

---Takes focus back from the child focused for this input source, running its yield callback
---@param inputSource InputSource
function UIElement:unfocusChild(inputSource)
  local child = self.focusedChild[inputSource]
  if not child then
    return
  end
  child.focusedBy[inputSource] = nil
  child.yielded[inputSource] = nil
  local onYield = self.focusCallbacks[inputSource]
  self.focusedChild[inputSource] = nil
  self.focusCallbacks[inputSource] = nil
  child:onUnfocus(inputSource)
  if onYield then
    onYield()
  end
end

---Gives focus back to whichever element focused this one for the input source, which takes it once this input pass returns to it.
---Only call this while receiving inputs; to release focus from outside an input pass, call unfocusChild on the parent.
---@param inputSource InputSource
function UIElement:yieldFocus(inputSource)
  self.focusedBy[inputSource] = nil
  self.yielded[inputSource] = true
end

---@param inputSource InputSource? checks for any input source if omitted
---@return boolean
function UIElement:hasFocus(inputSource)
  if inputSource then
    return self.focusedBy[inputSource] == true
  end
  return next(self.focusedBy) ~= nil
end

---Returns a formatted tree of this element and all children with class name, TYPE, and root position
---@return string
function UIElement:toStringWithDepth()
  local function getElementInfo(element, depth)
    local indent = string.rep("  ", depth)
    local typeStr = element.TYPE and (" [" .. element.TYPE .. "]") or ""
    local x, y = element:getScreenPos()
    local info = string.format("%s%s @ (%.1f, %.1f)", indent, typeStr, x, y)

    local lines = {info}
    for _, child in ipairs(element.children) do
      local childInfo = getElementInfo(child, depth + 1)
      table.insert(lines, childInfo)
    end

    return table.concat(lines, "\n")
  end

  return getElementInfo(self, 0)
end

---Returns a formatted list of this element and its direct children only (non-recursive)
---@return string
function UIElement:toString()
  local typeStr = self.TYPE and (" [" .. self.TYPE .. "]") or ""
  local x, y = self:getScreenPos()
  local lines = {string.format("%s @ (%.1f, %.1f)", typeStr, x, y)}

  for _, child in ipairs(self.children) do
    local childTypeStr = child.TYPE and (" [" .. child.TYPE .. "]") or ""
    local childX, childY = child:getScreenPos()
    table.insert(lines, string.format("  %s @ (%.1f, %.1f)", childTypeStr, childX, childY))
  end

  return table.concat(lines, "\n")
end

return UIElement