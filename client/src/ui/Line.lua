local import = require("common.lib.import")
local UiElement = import("./UIElement")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")

---@class LineOptions : UiElementOptions
---@field points number[]
---@field lineWidth integer?
---@field color number[]?

---@class Line : UiElement
---@operator call(LineOptions): Line
---@field points number[]
---@field lineWidth integer
---@field color number[]
local Line = class(
function(self, options)
  self.points = options.points
  self.lineWidth = options.lineWidth or 2
  self.color = options.color or {1, 1, 1, 0.6}
end,
UiElement)

function Line:drawSelf()
  love.graphics.setColor(self.color)
  love.graphics.setLineWidth(self.lineWidth)
  love.graphics.line(self.points)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

function Line:setPoints(points)
  self.points = points
end

return Line