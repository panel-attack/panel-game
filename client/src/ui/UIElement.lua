local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")

---@alias color { [1]: number, [2]: number, [3]: number, [4]: number }

---@class UiElement
---@field x number relative x offset to the parent element (canvas if no parent)
---@field y number relative y offset to the parent element (canvas if no parent)
---@field minWidth number the minimum width of the element, independent of children and layout
---@field width number width of the element for the sake of resizing children and touch hitboxes
---@field maxWidth number
---@field minHeight number the minimum height of the element, independent of children and layout
---@field height number height of the element for the sake of resizing children and touch hitboxes
---@field maxHeight number
---@field hAlign ("left" | "center" | "right") determines the horizontal alignment relative to the parent
---@field vAlign ("top" | "center" | "bottom") determines the vertical alignment relative to the parent
---@field hFill boolean if the element's width should fill out the entire parent's width
---@field vFill boolean if the element's height should fill out the entire parent's height
---@field isVisible boolean if the element is currently visible for rendering (also disables touch interaction)
---@field isEnabled boolean if the element is currently eligible for touch interaction
---@field parent UiElement the element's parent it is getting position relative to via its properties
---@field children UiElement[] the element's children that get positioned relative to it
---@field backgroundColor color
---@field padding number
---@field childGap number
---@field id integer unique identifier of the element
---@field layout Layout
---@field onTouch function? touch callback for when the element is being touched
---@field onDrag function? touch callback for when the mouse touching the element is dragged across the screen
---@field onRelease function? touch callback for when the mouse touching the element is released
---@field onHold function? touch callback for when a touch is held on the element for a longer duration
---@field onResized function? layout callback for when a UIElement and all of its children have been resized and positioned
---@field [any] any

---@class UiElementOptions
---@field x number? relative x offset to the parent element (canvas if no parent)
---@field y number? relative y offset to the parent element (canvas if no parent)
---@field minWidth number?
---@field width number? width of the element for the sake of resizing children and touch hitboxes
---@field maxWidth number?
---@field minHeight number?
---@field height number? height of the element for the sake of resizing children and touch hitboxes
---@field maxHeight number?
---@field hAlign ("left" | "center" | "right")? determines the horizontal alignment relative to the parent
---@field vAlign ("top" | "center" | "bottom")? determines the vertical alignment relative to the parent
---@field hFill boolean? if the element's width should fill out the entire parent's width
---@field vFill boolean? if the element's height should fill out the entire parent's height
---@field isVisible boolean? if the element is currently visible for rendering (also disables touch interaction)
---@field isEnabled boolean? if the element is currently eligible for touch interaction
---@field layout Layout?
---@field backgroundColor color?
---@field padding number?
---@field childGap number?

local uniqueId = 0

-- base class for all UI elements
-- takes in a options table for setting default values
-- all valid base options are defined in the constructor
---@class UiElement
---@operator call(UiElementOptions): UiElement
---@overload fun(options: UiElementOptions): UiElement
local UIElement = class(
  ---@param self UiElement
  function(self, options)
    -- local position relative to parent (or global pos if parent is nil)
    self.x = options.x or 0
    self.y = options.y or 0

    self.backgroundColor = options.backgroundColor or {1, 1, 1, 0}
    self.layout = options.layout
    self.padding = options.padding or 0
    self.childGap = options.childGap or 0
    self.wraps = options.wraps or false

    -- ui dimensions
    self.minWidth = options.minWidth or options.width or 0
    self.width = options.width or 0
    self.maxWidth = options.maxWidth or options.width or math.huge
    self.minHeight = options.minHeight or options.height or 0
    self.height = options.height or 0
    self.maxHeight = options.maxHeight or options.height or math.huge

    if self.padding * 2 > self.maxHeight or self.padding * 2 > self.maxWidth then
      error("The size of the padding cannot exceed the UIElements maximum dimensions")
    end

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

    self.id = uniqueId
    uniqueId = uniqueId + 1
  end
)

UIElement.TYPE = "UIElement"

function UIElement:onChildrenChanged()
  if self.parent then
    -- resizing segments does not make much sense if the segments have to be resized later anyway
    -- so bubble just straight up
    self.parent:onChildrenChanged()
  else
    -- and then only resize from the root element
    local oWidth = self.width
    local oHeight = self.height

    -- if DEBUG_ENABLED then
    --   self.layout.resize(self)
    -- end

    if self.controlsWindow then
      --if not DEBUG_ENABLED then
        self.layout.resize(self)
      --end
      if oWidth ~= self.width or oHeight ~= self.height then
        GraphicsUtil.updateMode(self.width, self.height, {})
      end
    end
  end
end

---@param uiElement UiElement
---@param index integer?
function UIElement:addChild(uiElement, index)
  if uiElement.parent then
    if uiElement.parent ~= self then
      error("Tried to give a uiElement more than one parent")
    end
  else
    if index then
      table.insert(self.children, index, uiElement)
    else
      self.children[#self.children + 1] = uiElement
    end
    uiElement.parent = self
    self:onChildrenChanged()
  end
end

function UIElement:detach()
  if self.parent then
    for i, child in ipairs(self.parent.children) do
      if child.id == self.id then
        table.remove(self.parent.children, i)
        self:onDetach()
        self.parent:onChildrenChanged()
        self.parent = nil
        break
      end
    end
    return self
  end
end

function UIElement:onDetach()
end

---@param whoIsAsking table?
function UIElement:getScreenPos(whoIsAsking)
  local x, y = 0, 0
  if self.parent then
    x, y = self.parent:getScreenPos(self)
  end

  return x + self.x, y + self.y
end

-- passes a retranslation request through the tree to reach all Labels
function UIElement:refreshLocalization()
  for _, uiElement in ipairs(self.children) do
    uiElement:refreshLocalization()
  end
end

function UIElement:draw()
  if self.isVisible then
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

-- UiElements containing children draw the children-independent part in this function
-- implementation is optional so layout elements don't have to
function UIElement:drawSelf()
  love.graphics.setColor(self.backgroundColor)
  love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
  love.graphics.setColor(1, 1, 1, 1)
  --if self.padding > 0 then
    -- love.graphics.rectangle("line", self.x + self.padding, self.y + self.padding, 1, self.height - self.padding * 2)
    -- love.graphics.rectangle("line", self.x + self.padding, self.y + self.padding, self.width - self.padding * 2, 1)
    -- love.graphics.rectangle("line", self.x + self.width - self.padding, self.y + self.padding, 1, self.height - self.padding * 2)
    -- love.graphics.rectangle("line", self.x + self.padding, self.y + self.height - self.padding, self.width - self.padding *2, 1)
  --end
  --love.graphics.print(self.width .. ", " .. self.height, self.x + 5, self.y + 5)
end

function UIElement:drawChildren()
  for _, uiElement in ipairs(self.children) do
    if uiElement.isVisible then
      uiElement:draw()
    end
  end
end

-- setVisibility is to used on children that are temporarily "offscreen", e.g. as part of a scrolling UiElement
-- if you want to stop drawing an element, e.g. due to changing a subscreen, 
--  the more opportune method is to simply remove it from the ui tree via detach()
function UIElement:setVisibility(isVisible)
  if self.isVisible ~= isVisible then
    self.isVisible = isVisible
    self:onVisibilityChanged()
  end
end

function UIElement:onVisibilityChanged()
  if self.parent then
    self.parent:onChildrenChanged()
  end
end

function UIElement:setEnabled(isEnabled)
  self.isEnabled = isEnabled
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

function UIElement:getTouchedElement(x, y)
  if self.isVisible and self.isEnabled and self:inBounds(x, y) then
    local touchedElement
    for i = 1, #self.children do
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

--- defaults to minWidth; elements that can wrap have to override this getter with a function returning their preferred width
---@return integer # the width the UIElement would prefer to take up if any space is available
function UIElement:getPreferredWidth()
  return self.minWidth
end

return UIElement