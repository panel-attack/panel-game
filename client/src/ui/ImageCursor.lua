local import = require("common.lib.import")
local Cursor = import("./Cursor")
local class = require("common.lib.class")
local consts = require("client.src.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local input = require("client.src.inputManager")


---@class ImageCursor : Cursor
---@field image love.Texture
local ImageCursor = class(
function (self, target, keyInput, image)
  self.image = image
end,
Cursor)

function ImageCursor:draw()
 -- GraphicsUtil.setColor(0, 0, 0, 0.2)
  -- love.graphics.rectangle("fill", self.target.x, self.target.y, self.target.width, self.target.height)
  if self.focused then
    local uiElement = self.focusToHover[self.focused]
    GraphicsUtil.setColor(1, 1, 1, 1)
    local x, y = uiElement:getScreenPos()
    local imageWidth, imageHeight = self.image:getDimensions()
    GraphicsUtil.draw(self.image, x, y, 0, uiElement.width / imageWidth, uiElement.height / imageHeight)
  end
end

return ImageCursor