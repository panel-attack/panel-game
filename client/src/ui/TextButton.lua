local PATH = (...):gsub('%.[^%.]+$', '')
local Button = require(PATH .. ".Button")
local Layout = require(PATH .. ".Layout")
local class = require("common.lib.class")

---@class TextButtonOptions : ButtonOptions
---@field label Label

-- A TextButton is a button that sets itself apart from Button by automatically scaling its own size to fit the text inside
-- This is different from the regular button that scales its content to fit inside itself
---@class TextButton : Button
---@field label Label centered in the button, in its flow
local TextButton = class(function(self, options)
  self.label = options.label
  self.label.textAlign = "center"
  self.label:refreshFormatting()
  if not self.layoutRules.padding then
    self:setLayoutRule("padding", {left = self.WIDTH_PADDING, right = self.WIDTH_PADDING, top = self.HEIGHT_PADDING,
                                   bottom = self.HEIGHT_PADDING})
  end
  self:setLayoutRule("childAlignment", Layout.CENTER)
  -- stretch to fit text, at least as large as a fixed size the caller gave
  local sizing = self.layoutRules.sizing or {}
  self:setLayoutRule("sizing", {horizontal = self.fitAtLeast(sizing.horizontal), vertical = self.fitAtLeast(sizing.vertical)})
  self:addChild(self.label)
end, Button)
TextButton.TYPE = "TextButton"

-- Returns the sizing that fits the label, at least as large as a fixed size; a growing or fitting sizing is kept
---@param sizing LayoutSizing?
---@return LayoutSizing
function TextButton.fitAtLeast(sizing)
  if sizing == nil then
    return Layout.FIT
  elseif sizing.type == "fixed" then
    return Layout.fit(sizing.min)
  end
  return sizing
end

return TextButton
