local PATH = (...):gsub('%.[^%.]+$', '')
local Button = require(PATH .. ".Button")
local ImageContainer = require(PATH .. ".ImageContainer")
local class = require("common.lib.class")

---@class ImageButtonOptions : ButtonOptions
---@field image love.Texture The image to display on the button
---@field width number? The width of the button (defaults to image width)
---@field height number? The height of the button (defaults to image height)

-- An ImageButton is a button that displays an image instead of text
-- This follows the same pattern as TextButton but uses an ImageContainer instead of a Label
-- The button automatically sizes itself to fit the image if width/height are not specified
---@class ImageButton : Button
---@field imageContainer ImageContainer The container holding the image
local ImageButton = class(function(self, options)
  assert(options.image, "ImageButton requires an image")

  local imageWidth = options.width or options.image:getWidth()
  local imageHeight = options.height or options.image:getHeight()
  
  self.imageContainer = ImageContainer({
    image = options.image,
    width = imageWidth,
    height = imageHeight,
    hAlign = "center",
    vAlign = "center"
  })
  
  self:addChild(self.imageContainer)
  
  -- Set button dimensions to match the image container
  self.width = imageWidth
  self.height = imageHeight

end, Button)

ImageButton.TYPE = "ImageButton"

return ImageButton