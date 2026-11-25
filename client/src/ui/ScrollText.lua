local PATH = (...):gsub('%.[^%.]+$', '')
local UiElement = require(PATH .. ".UIElement")
local LayoutSolver = require(PATH .. ".LayoutSolver")
local class = require("common.lib.class")

-- technically this value should be derived from the font size set for the label
local SCROLL_STEP = 14

-- Text that scrolls up and down. The label is in its flow, placed by its padding, and moved up and down from there.
---@class ScrollText : UiElement
---@field label Label
---@field labelY number how far the label's top is below the ScrollText's top
local ScrollText = class(function(self, options)
  assert(options.label, "ScrollText needs a self.label for display!")

  self.label = options.label
  self:addChild(self.label)
  local padding = self.layoutRules.padding
  self.labelY = padding and padding.top or 0

  self:setFocusable(true)
end,
UiElement)

-- Moves the label to the height
---@param y number how far the label's top is below the ScrollText's top
function ScrollText:setLabelY(y)
  if y ~= self.labelY then
    self.labelY = y
    self:markLayoutDirty()
  end
end

---@param axis LayoutAxis
---@return number # how far the label is moved from where the padding places it
function ScrollText:getChildOffset(axis)
  if axis == LayoutSolver.Y_AXIS then
    local padding = self.layoutRules.padding
    return self.labelY - (padding and padding.top or 0)
  end
  return 0
end

function ScrollText:receiveInputsSelf(inputSource, dt)
  local inputs = inputSource:getInputs()
  local height = self.layoutRect.height
  local labelHeight = self.label.layoutRect.height
  if inputs:isPressedWithRepeat("MenuUp", .25, 0.03) then
    self:playMoveSfx()
    if labelHeight > height - (SCROLL_STEP + 1) then
      self:setLabelY(math.min((SCROLL_STEP + 1), self.labelY + SCROLL_STEP))
    end
  end
  if inputs:isPressedWithRepeat("MenuDown", .25, 0.03) then
    self:playMoveSfx()
    if labelHeight > height - (SCROLL_STEP + 1) then
      self:setLabelY(math.max(self.labelY - SCROLL_STEP, (height - (SCROLL_STEP + 1)) - labelHeight))
    end
  end
  if inputs.isDown.MenuLeft then
    self:playMoveSfx()
    if labelHeight > height - (SCROLL_STEP + 1) then
      self:setLabelY(math.min((SCROLL_STEP + 1), self.labelY + (height - (SCROLL_STEP + 1))))
    end
  end
  if inputs.isDown.MenuRight then
    self:playMoveSfx()
    if labelHeight > height - (SCROLL_STEP + 1) then
      self:setLabelY(math.max(self.labelY - (height - (SCROLL_STEP + 1)), (height - (SCROLL_STEP + 1)) - labelHeight))
    end
  end
  if inputs.isDown["MenuEsc"] then
    self:playCancelSfx()
    self:onBack(inputSource)
  end
end

function ScrollText:onTouch(x, y)
  self.swiping = true
  self.initialTouchY = y
  self.originalY = self.labelY
end

function ScrollText:onDrag(x, y)
  local yOffset = y - self.initialTouchY
  if yOffset > 0 then
    self:setLabelY(math.min((SCROLL_STEP + 1), self.originalY + yOffset))
  else
    self:setLabelY(math.max(self.originalY + yOffset, (self.layoutRect.height - (SCROLL_STEP + 1)) - self.label.layoutRect.height))
  end
end

function ScrollText:onRelease(x, y)
  self:onDrag(x, y)
  self.swiping = false
end

-- this should/may be overwritten by the parent
---@param inputSource InputSource
function ScrollText:onBack(inputSource)
  if self.onBackCallback then
    self.onBackCallback()
  end
  self:yieldFocus(inputSource)
end

return ScrollText
