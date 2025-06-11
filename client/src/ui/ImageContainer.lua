local import = require("common.lib.import")
local UiElement = import("./UIElement")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")

---@class ImageOptions : UiElementOptions
---@field image love.Texture
---@field forceIntegerScaling boolean? force the image scale to snap to integer scales even if it doesn't fill up the available space, e.g. 1/4, 1/3, 1/2, 1/1, 2/1, 3/1 etc.
---@field minScale number?

---@class Image : UiElement
---@operator call(ImageOptions): Image
---@overload fun(options: ImageOptions): Image
---@field image love.Texture
---@field drawBorders boolean
---@field outlineColor color
---@field forceIntegerScaling boolean if the image scale is forced to snap to a fraction number with 1 in numerator or denominator
---@field minScale number the minimum the image can be scaled down to
local ImageContainer = class(
function(self, options)
  self.drawBorders = options.drawBorders or false
  self.outlineColor = options.outlineColor or {1, 1, 1, 1}

  if options.forceIntegerScaling ~= nil then
    self.forceIntegerScaling = options.forceIntegerScaling
  else
    self.forceIntegerScaling = false
  end

  self.minScale = 0.125

  self:setImage(options.image, options.width, options.height, options.scale)
end,
UiElement)

ImageContainer.TYPE = "Image"

function ImageContainer:setImage(image, width, height, scale)
  self.image = image
  self.imageWidth, self.imageHeight = self.image:getDimensions()
  self.minWidth = math.max(self.imageWidth * self.minScale, self.minWidth)
  self.minHeight = math.max(self.imageHeight * self.minScale, self.minHeight)

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
  self.scale = math.min(self.width / self.imageWidth, self.height / self.imageHeight)
  if self.forceIntegerScaling then
    if self.scale >= 1 then
      self.scale = math.floor(self.scale)
    else
      for i = 1, math.floor(1 / self.minScale) do
        if 1 / i < self.scale then
          self.scale = 1 / i
          break
        end
      end
    end
  end
end

function ImageContainer:drawSelf()
  UiElement.drawSelf(self)

  local x, y = GraphicsUtil.getAlignmentOffset(self, {width = self.imageWidth * self.scale, height = self.imageHeight * self.scale})
  GraphicsUtil.draw(self.image, x, y, 0, self.scale, self.scale)

  if self.drawBorders then
    -- border is just drawn on top, not around
    GraphicsUtil.setColor(self.outlineColor)
    GraphicsUtil.drawRectangle("line", 0, 0, self.width, self.height)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
end

function ImageContainer:getPreferredWidth()
  return self.imageWidth
end

function ImageContainer:getPreferredHeight()
  return self.imageHeight * (self.width / self.imageWidth)
end

return ImageContainer
