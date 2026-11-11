local PATH = (...):gsub('%.[^%.]+$', '')
local Button = require(PATH .. ".Button")
local class = require("common.lib.class")

---@alias ArrowDirection "up" | "down" | "right"

---@class ArrowButtonOptions : ButtonOptions
---@field direction ArrowDirection

-- corners of the triangle for each direction, as offsets from the button's center in units of the triangle's half size
local CORNERS = {
  up = {0, -0.8, 1, 0.8, -1, 0.8},
  down = {-1, -0.8, 1, -0.8, 0, 0.8},
  right = {-0.8, -1, 0.8, 0, -0.8, 1},
}

-- A button showing a triangle that points in its direction
---@class ArrowButton : Button
---@field direction ArrowDirection
---@overload fun(options: ArrowButtonOptions): ArrowButton
local ArrowButton = class(function(self, options)
  self.direction = options.direction
end, Button)
ArrowButton.TYPE = "ArrowButton"

function ArrowButton:drawSelf()
  Button.drawSelf(self)
  local halfSize = math.min(self.width, self.height) / 5
  local centerX = self.x + self.width / 2
  local centerY = self.y + self.height / 2
  local corners = CORNERS[self.direction]
  love.graphics.polygon("fill",
    centerX + corners[1] * halfSize, centerY + corners[2] * halfSize,
    centerX + corners[3] * halfSize, centerY + corners[4] * halfSize,
    centerX + corners[5] * halfSize, centerY + corners[6] * halfSize)
end

return ArrowButton
