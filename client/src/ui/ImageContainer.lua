local PATH = (...):gsub('%.[^%.]+$', '')
local UiElement = require(PATH .. ".UIElement")
local Layout = require(PATH .. ".Layout")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")

-- each childAlignment's share of the room left around the image
local ALIGNMENT_SHARES = {left = 0, top = 0, center = 0.5, right = 1, bottom = 1}
local NO_ALIGNMENT = {}

---@class ImageContainerOptions : UiElementOptions
---@field image love.Texture
---@field scale number?
---@field drawBorders boolean?
---@field outlineColor number[]?
---@field color number[]? red, green, blue and alpha the image is tinted with, untinted if nil

-- An image at a scale. Without sizing that grows both ways it is as large as the image at its scale, or as the box its
-- fixed width and height give at the scale, the image fitted into the box's top left; with sizing that grows both ways
-- the layout gives it its box and it draws the image fitted into it, placed by its childAlignment.
---@class ImageContainer : UiElement
---@field color number[]? red, green, blue and alpha the image is tinted with, untinted if nil
local ImageContainer = class(function(self, options)
  self.drawBorders = options.drawBorders or false
  self.outlineColor = options.outlineColor or {1, 1, 1, 1}
  self.color = options.color

  self:setImage(options.image, Layout.fixedLength(self.layoutRules, "horizontal"), Layout.fixedLength(self.layoutRules, "vertical"),
                options.scale)
end, UiElement)

-- Shows the image, sizing the container to it unless the container grows
---@param image love.Texture
---@param width number? the box's width before the scale
---@param height number? the box's height before the scale
---@param scale number? 1 if not given
function ImageContainer:setImage(image, width, height, scale)
  self.image = image
  self.imageWidth, self.imageHeight = self.image:getDimensions()

  if self:grows() then
    self:fitToBox()
  else
    scale = scale or 1

    local scaledImageWidth = self.imageWidth * scale
    local scaledImageHeight = self.imageHeight * scale

    if width and height then
      -- scale is getting capped to what width and height actually give us
      self.scale = math.min(width / scaledImageWidth, height / scaledImageHeight)
      self:setFixedSize(width * scale, height * scale)
    else
      -- there are no size limits, set the size based on scale
      self:setFixedSize(scaledImageWidth, scaledImageHeight)
      self.scale = scale
    end
  end
end

---@return boolean # true if the sizing along both axes grows, so the layout gives the container its box
function ImageContainer:grows()
  local sizing = self.layoutRules.sizing
  return sizing ~= nil and sizing.horizontal ~= nil and sizing.horizontal.type == "grow" and sizing.vertical ~= nil
         and sizing.vertical.type == "grow"
end

-- Fits the image into the box the last layout gave the container, keeping its aspect ratio
function ImageContainer:fitToBox()
  self.scale = math.min(self.layoutRect.width / self.imageWidth, self.layoutRect.height / self.imageHeight)
end

-- A growing container fits its image into its new box
function ImageContainer:onResize()
  if self:grows() then
    self:fitToBox()
  end
end

---@return number x, number y, number width, number height # where the image is drawn in the container
function ImageContainer:getImageRect()
  local width, height = self.layoutRect.width, self.layoutRect.height
  if not self:grows() then
    return 0, 0, width, height
  end
  local imageWidth, imageHeight = self.imageWidth * self.scale, self.imageHeight * self.scale
  local alignment = self.layoutRules.childAlignment or NO_ALIGNMENT
  local x = (width - imageWidth) * ALIGNMENT_SHARES[alignment.x or "left"]
  local y = (height - imageHeight) * ALIGNMENT_SHARES[alignment.y or "top"]
  return x, y, imageWidth, imageHeight
end

function ImageContainer:drawSelf()
  local x, y, width, height = self:getImageRect()
  if self.color then
    GraphicsUtil.setColor(self.color)
    GraphicsUtil.draw(self.image, x, y, 0, self.scale, self.scale)
    GraphicsUtil.setColor(1, 1, 1, 1)
  else
    GraphicsUtil.draw(self.image, x, y, 0, self.scale, self.scale)
  end

  if self.drawBorders then
    -- border is just drawn on top, not around
    GraphicsUtil.setColor(self.outlineColor)
    GraphicsUtil.drawRectangle("line", x, y, width, height)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
end

return ImageContainer
