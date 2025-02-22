local PATH = (...):gsub('%.[^%.]+$', '')
local Button = require(PATH .. ".Button")
local class = require("common.lib.class")

local TEXT_WIDTH_PADDING = 6
local TEXT_HEIGHT_PADDING = 6

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
  self.width = math.max(width + TEXT_WIDTH_PADDING, self.width)
  self.height = math.max(height + TEXT_HEIGHT_PADDING, self.height)

end, Button)
TextButton.TYPE = "TextButton"

return TextButton
