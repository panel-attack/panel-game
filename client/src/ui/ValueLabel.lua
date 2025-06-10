local import = require("common.lib.import")
local UiElement = import("./UIElement")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")

-- Draws the text of a current model value on screen
local ValueLabel = class(function(self, options)
  assert(options.valueFunction, "Value labels need a function to poll the value!")
  self.valueFunction = options.valueFunction
end,
UiElement)

function ValueLabel:drawSelf()
  love.graphics.print(self.valueFunction(), 0, 0)
end

return ValueLabel