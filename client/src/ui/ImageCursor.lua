local import = require("common.lib.import")
local Cursor = import("./Cursor")
local class = require("common.lib.class")
local consts = require("client.src.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local input = require("client.src.inputManager")


---@class ImageCursor : Cursor
---@field images love.Texture[]
---@field framesPerImage number
---@field private imageWidth integer
---@field private imageHeight integer
---@field quads table<string, love.Quad>
---@field thickness integer
---@field blinking boolean
local ImageCursor = class(
function (self, target, keyInput, cursorImages)
  self.images = cursorImages
  self.imageWidth, self.imageHeight = self.images[1]:getDimensions()
  local quadWidth = self.imageWidth / 2
  local quadHeight = self.imageHeight / 2
  self.quads = {
    topLeft = GraphicsUtil:newRecycledQuad(0, 0, quadWidth, quadHeight, self.imageWidth, self.imageHeight),
    topRight = GraphicsUtil:newRecycledQuad(quadWidth, 0, quadWidth, quadHeight, self.imageWidth, self.imageHeight),
    bottomLeft = GraphicsUtil:newRecycledQuad(0, quadHeight, quadWidth, quadHeight, self.imageWidth, self.imageHeight),
    bottomRight = GraphicsUtil:newRecycledQuad(quadWidth, quadHeight, quadWidth, quadHeight, self.imageWidth, self.imageHeight)
  }
  self.thickness = 3

  self.framesPerImage = 8
  self.blinking = false
end,
Cursor)

function ImageCursor:draw()
  if self.focused then
    local uiElement = self.focusToHover[self.focused]
    GraphicsUtil.setColor(1, 1, 1, 1)
    local x, y = uiElement:getScreenPos()

    local image
    if not self.blinking then
      local n = consts.FRAME_RATE * self.framesPerImage
      local imageIndex = math.ceil((love.timer.getTime() % (n * #self.images)) / n)
      image = self.images[imageIndex]
    else
      -- TODO: Player offset blinking so that cursors blink in turns
      local playerNumber = 1
      if (math.floor(math.round(love.timer.getTime() / consts.FRAME_RATE) / self.framesPerImage) + playerNumber) % 2 + 1 == playerNumber then
        return
      else
        image = self.images[1]
      end
    end

    local scale = math.min(uiElement.width / self.imageWidth, uiElement.height / self.imageHeight)
    local thickness = math.round(self.thickness * scale)
    GraphicsUtil.drawQuad(image, self.quads.topLeft, x - thickness, y - thickness, 0, scale)
    GraphicsUtil.drawQuad(image, self.quads.topRight, x + uiElement.width + thickness, y - thickness, 0, scale, scale, self.imageWidth / 2)
    GraphicsUtil.drawQuad(image, self.quads.bottomLeft, x - thickness, y + uiElement.height / 2 + thickness, 0, scale)
    GraphicsUtil.drawQuad(image, self.quads.bottomRight, x + uiElement.width + thickness, y + uiElement.height / 2 + thickness, 0, scale, scale, self.imageWidth / 2)
  end
end

return ImageCursor