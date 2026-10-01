local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local DebugSettings = require("client.src.debug.DebugSettings")
local logger = require("common.lib.logger")

---@class UiElement
---@field x number relative x offset to the parent element (canvas if no parent)
---@field y number relative y offset to the parent element (canvas if no parent)
---@field width number width of the element for the sake of resizing children and touch hitboxes
---@field height number height of the element for the sake of resizing children and touch hitboxes
---@field hAlign ("left" | "center" | "right") determines the horizontal alignment relative to the parent
---@field vAlign ("top" | "center" | "bottom") determines the vertical alignment relative to the parent
---@field hFill boolean if the element's width should fill out the entire parent's width
---@field vFill boolean if the element's height should fill out the entire parent's height
---@field isVisible boolean if the element is currently visible for rendering (also disables touch interaction)
---@field isEnabled boolean if the element is currently eligible for touch interaction
---@field parent UiElement the element's parent it is getting position relative to via its properties
---@field children UiElement[] the element's children that get positioned relative to it
---@field id integer unique identifier of the element
---@field onTouch function? touch callback for when the element is being touched
---@field onDrag function? touch callback for when the mouse touching the element is dragged across the screen
---@field onRelease function? touch callback for when the mouse touching the element is released
---@field onHold function? touch callback for when a touch is held on the element for a longer duration
---@field isFocusable boolean true if selecting this element focuses it, so it receives the selecting input source's inputs until it yields focus; false if selecting it only runs its onSelect
---@field focusedChild table<InputSource, UiElement> per input source, the element this one has handed its inputs to
---@field focusCallbacks table<InputSource, function?> per input source, what to run when the focused child gives its focus back
---@field focusedBy table<InputSource, true> the input sources that currently have this element focused
---@field yielded table<InputSource, true> the input sources this element has given focus back for, until the focusing parent takes it
---@field [any] any

---@class UiElementOptions
---@field x number? relative x offset to the parent element (canvas if no parent)
---@field y number? relative y offset to the parent element (canvas if no parent)
---@field width number? width of the element for the sake of resizing children and touch hitboxes
---@field height number? height of the element for the sake of resizing children and touch hitboxes
---@field hAlign ("left" | "center" | "right")? determines the horizontal alignment relative to the parent
---@field vAlign ("top" | "center" | "bottom")? determines the vertical alignment relative to the parent
---@field hFill boolean? if the element's width should fill out the entire parent's width
---@field vFill boolean? if the element's height should fill out the entire parent's height
---@field isVisible boolean? if the element is currently visible for rendering (also disables touch interaction)
---@field isEnabled boolean? if the element is currently eligible for touch interaction

local uniqueId = 0

-- base class for all UI elements
-- takes in a options table for setting default values
-- all valid base options are defined in the constructor
---@class UiElement
---@overload fun(options: UiElementOptions): UiElement
local UIElement = class(
  ---@param self UiElement
  function(self, options)
    -- local position relative to parent (or global pos if parent is nil)
    self.x = options.x or 0
    self.y = options.y or 0

    -- ui dimensions
    self.width = options.width or 0
    self.height = options.height or 0

    -- how to align the element inside the parent element
    self.hAlign = options.hAlign or "left"
    self.vAlign = options.vAlign or "top"

    -- how the size is determined relative to the parent element
    -- hFill true sets the width to the size of the parent
    self.hFill = options.hFill or false
    -- vFill true sets the height to the size of the parent
    self.vFill = options.vFill or false

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
  end
)

UIElement.TYPE = "UIElement"

function UIElement:addChild(uiElement)
  if uiElement.parent ~= self then
    self.children[#self.children + 1] = uiElement
    uiElement.parent = self
    uiElement:resize()
  end
end

function UIElement:resize()
  if self.hFill and self.parent then
    self.width = self.parent.width
  end

  if self.vFill and self.parent then
    self.height = self.parent.height
  end

  self:onResize()

  if self.hFill or self.vFill then
    for _, child in ipairs(self.children) do
      child:resize()
    end
  end
end

-- overridable function to define extra behaviour to the element itself on resize
function UIElement:onResize()
end

function UIElement:detach()
  if self.parent then
    for i, child in ipairs(self.parent.children) do
      if child.id == self.id then
        table.remove(self.parent.children, i)
        self:onDetach()
        self.parent = nil
        break
      end
    end
    return self
  end
end

function UIElement:onDetach()
end

function UIElement:getScreenPos()
  local x, y = 0, 0
  local xOffset, yOffset = 0, 0
  if self.parent then
    x, y = self.parent:getScreenPos()
    xOffset, yOffset = GraphicsUtil.getAlignmentOffset(self.parent, self)
  end

  return x + self.x + xOffset, y + self.y + yOffset
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

function UIElement:drawDebugOutline()
  if DebugSettings.showUIElementBorders() then
    GraphicsUtil.setColor(0, 0, 1, 1)
    GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
end

function UIElement:draw()
  if self.isVisible then
    self:drawDebugOutline()
    self:drawSelf()
    -- if DEBUG_ENABLED then
    --   GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height, 1, 1, 1, 0.5)
    -- end
    love.graphics.push("transform")
    love.graphics.translate(self.x, self.y)
    self:drawChildren()
    love.graphics.pop()
  end
end

-- UiElements can override this method to do custom drawing
-- implementation is optional
function UIElement:drawSelf()
end

function UIElement:drawChildren()
  for _, uiElement in ipairs(self.children) do
    if uiElement.isVisible then
      GraphicsUtil.applyAlignment(self, uiElement)
      uiElement:draw()
      GraphicsUtil.resetAlignment()
    end
  end
end

-- setVisibility is to used on children that are temporarily "offscreen", e.g. as part of a scrolling UiElement
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
  return x > screenX and x < screenX + self.width and y > screenY and y < screenY + self.height
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

---Sets whether selecting this element focuses it, so it receives the selecting input source's inputs until it yields focus, rather than only running its onSelect
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