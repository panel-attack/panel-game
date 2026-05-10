local PATH = (...):gsub('%.[^%.]+$', '')
local UiElement = require(PATH .. ".UIElement")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local logger = require("common.lib.logger")

local fallbackImage = nil

---@return love.Texture?
local function getFallbackImage()
  if fallbackImage then
    return fallbackImage
  end

  if love and love.image and love.graphics then
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, 1, 1, 1, 0)
    fallbackImage = love.graphics.newImage(data)
    return fallbackImage
  end

  return nil
end

---@class ImageContainer : UiElement
local ImageContainer = class(function(self, options)
  self.drawBorders = options.drawBorders or false
  self.outlineColor = options.outlineColor or {1, 1, 1, 1}

  self:setImage(options.image, options.width, options.height, options.scale)
end, UiElement)

function ImageContainer:setImage(image, width, height, scale)
  if not image then
    logger.warn("ImageContainer received nil image; using 1x1 transparent fallback")
  end

  self.image = image or getFallbackImage()
  if self.image then
    self.imageWidth, self.imageHeight = self.image:getDimensions()
  else
    -- Defensive fallback for environments where love.graphics is unavailable.
    self.imageWidth, self.imageHeight = 1, 1
  end

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

function ImageContainer:onResize()
  self.scale = math.min(self.width / self.imageWidth, self.height / self.imageHeight)
  self.width = self.imageWidth * self.scale
  self.height = self.imageHeight * self.scale
end

function ImageContainer:drawSelf()
  if self.image then
    GraphicsUtil.draw(self.image, self.x, self.y, 0, self.scale, self.scale)
  end

  if self.drawBorders then
    -- border is just drawn on top, not around
    GraphicsUtil.setColor(self.outlineColor)
    GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
end

return ImageContainer
