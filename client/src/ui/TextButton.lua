local PATH = (...):gsub('%.[^%.]+$', '')
local Button = require(PATH .. ".Button")
local class = require("common.lib.class")

---@class TextButtonOptions : ButtonOptions
---@field label Label

-- A TextButton is a button that sets itself apart from Button by automatically scaling its own size to fit the text inside
-- This is different from the regular button that scales its content to fit inside itself
---@class TextButton : Button
---@field label Label
local TextButton = class(function(self, options)
  self.label = options.label
  self.label.hAlign = "center"
  self.label.vAlign = "center"
  self:addChild(self.label)

  -- stretch to fit text
  local width, height = self.label:getEffectiveDimensions()
  self.width = math.max(width + self.WIDTH_PADDING * 2, self.width)
  self.height = math.max(height + self.HEIGHT_PADDING * 2, self.height)
end, Button)
TextButton.TYPE = "TextButton"

return TextButton
