local import = require("common.lib.import")
local UiElement = import("./UIElement")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")

---@class ImageOptions : UiElementOptions
---@field image love.Texture
---@field scalePower integer the power of scale to which the element snaps, e.g. if it's 2, only allow scale 0.25, 0.5, 1, 2, 4, 8

---@class Image : UiElement
---@operator call(ImageOptions): Image
---@overload fun(options: ImageOptions): Image
---@field image love.Texture
---@field drawBorders boolean
---@field outlineColor color
local ImageContainer = class(
function(self, options)
  self.drawBorders = options.drawBorders or false
  self.outlineColor = options.outlineColor or {1, 1, 1, 1}

  self.scalePower = options.scalePower or 2

  self:setImage(options.image, options.width, options.height, options.scale)
end,
UiElement)

ImageContainer.TYPE = "Image"

function ImageContainer:setImage(image, width, height, scale)
  self.image = image
  self.imageWidth, self.imageHeight = self.image:getDimensions()
  self.minWidth = math.max(self.imageWidth, self.minWidth)
  self.minHeight = math.max(self.imageHeight, self.minHeight)

  if self.hFill and self.vFill then
    self.scale = math.min(self.width / self.imageWidth, self.height / self.imageHeight)
  else
    scale = scale or 1
  
    local scaledImageWidth = self.imageWidth * scale
    local scaledImageHeight = self.imageHeight * scale
  
    if width and height then
      -- scale is getting capped to what width and height actually give us
      self.scale = math.min(width / scaledImageWidth, height / scaledImageHeight)
      self.width = width * scale
      self.height = height * scale
    else
      -- there are no size limits, set the size based on scale
      self.width = scaledImageWidth
      self.height = scaledImageHeight
      self.scale = scale
    end
  end
end

function ImageContainer:onResized()
  self.scale = math.floor(math.min(self.width / self.imageWidth, self.height / self.imageHeight))
end

function ImageContainer:drawSelf()
  local x, y = GraphicsUtil.getAlignmentOffset(self, {width = self.imageWidth * self.scale, height = self.imageHeight * self.scale})
  GraphicsUtil.draw(self.image, x, y, 0, self.scale, self.scale)

  if self.drawBorders then
    -- border is just drawn on top, not around
    GraphicsUtil.setColor(self.outlineColor)
    GraphicsUtil.drawRectangle("line", 0, 0, self.width, self.height)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
end

return ImageContainer
