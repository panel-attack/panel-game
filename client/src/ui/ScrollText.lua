local PATH = (...):gsub('%.[^%.]+$', '')
local UiElement = require(PATH .. ".UIElement")
local class = require("common.lib.class")

-- technically this value should be derived from the font size set for the label
local SCROLL_STEP = 14
local VERTICAL_CLIP = {vertical = true}

-- Text that scrolls up and down inside its rect, by the keys and as every element that clips does. The label is in its flow.
---@class ScrollText : UiElement
---@field label Label
local ScrollText = class(function(self, options)
  assert(options.label, "ScrollText needs a self.label for display!")

  self.label = options.label
  self:addChild(self.label)
  self:setLayoutRule("clip", VERTICAL_CLIP)

  self:setFocusable(true)
end,
UiElement)

function ScrollText:receiveInputsSelf(inputSource, dt)
  local inputs = inputSource:getInputs()
  local pageStep = self.layoutRect.height - SCROLL_STEP
  if inputs:isPressedWithRepeat("MenuUp", .25, 0.03) then
    self:playMoveSfx()
    self:scrollBy(0, SCROLL_STEP)
  end
  if inputs:isPressedWithRepeat("MenuDown", .25, 0.03) then
    self:playMoveSfx()
    self:scrollBy(0, -SCROLL_STEP)
  end
  if inputs.isDown.MenuLeft then
    self:playMoveSfx()
    self:scrollBy(0, pageStep)
  end
  if inputs.isDown.MenuRight then
    self:playMoveSfx()
    self:scrollBy(0, -pageStep)
  end
  if inputs.isDown["MenuEsc"] then
    self:playCancelSfx()
    self:onBack(inputSource)
  end
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
