local import = require("common.lib.import")
local Button = import("./Button")
local class = require("common.lib.class")

---@class TextButtonOptions : ButtonOptions
---@field label Label

-- A TextButton is a button that sets itself apart from Button by automatically scaling its own size to fit the text inside
-- This is different from the regular button that scales its content to fit inside itself
---@class TextButton : Button
---@operator call(TextButtonOptions): TextButton
---@field label Label
local TextButton = class(function(self, options)
  self.label = options.label
  self.label.hAlign = "center"
  self.label.vAlign = "center"
  self.hFill = true
  self.padding = options.padding or 8
  self:addChild(self.label)
end, Button)
TextButton.TYPE = "TextButton"

return TextButton
