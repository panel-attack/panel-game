local PATH = (...):gsub('%.[^%.]+$', '')
local Button = require(PATH .. ".Button")
local ImageContainer = require(PATH .. ".ImageContainer")
local Layout = require(PATH .. ".Layout")
local class = require("common.lib.class")

---@class ImageButtonOptions : ButtonOptions
---@field image love.Texture shown on the button; a fixed width and height size the button and image, else the image's size

-- An ImageButton is a button that displays an image instead of text
-- This follows the same pattern as TextButton but uses an ImageContainer instead of a Label
-- The button automatically sizes itself to fit the image if width/height are not specified
---@class ImageButton : Button
---@field imageContainer ImageContainer The container holding the image
local ImageButton = class(function(self, options)
  assert(options.image, "ImageButton requires an image")

  local imageWidth = Layout.fixedLength(self.layoutRules, "horizontal") or options.image:getWidth()
  local imageHeight = Layout.fixedLength(self.layoutRules, "vertical") or options.image:getHeight()

  self.imageContainer = ImageContainer({
    image = options.image,
    layoutRules = {sizing = Layout.fixedSize(imageWidth, imageHeight)},
  })

  -- the button is the image's size, the image centered in it
  self:setLayoutRule("sizing", Layout.fixedSize(imageWidth, imageHeight))
  self:setLayoutRule("childAlignment", Layout.CENTER)
  self:addChild(self.imageContainer)
end, Button)

ImageButton.TYPE = "ImageButton"

return ImageButton
