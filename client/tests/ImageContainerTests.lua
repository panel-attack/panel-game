local ImageContainer = require("client.src.ui.ImageContainer")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local logger = require("common.lib.logger")

local function createImage()
  return love.graphics.newImage(love.image.newImageData(4, 4))
end

-- Draws the container and returns every color it set, recorded instead of set since tests may run without a window
---@param container ImageContainer
---@return table[]
local function recordColorsSetWhileDrawing(container)
  local colors = {}
  local setColor = GraphicsUtil.setColor
  GraphicsUtil.setColor = function(r, g, b, a)
    colors[#colors + 1] = {r, g, b, a}
  end
  local success, err = pcall(container.drawSelf, container)
  GraphicsUtil.setColor = setColor
  assert(success, err)
  return colors
end

local function testUntintedImageKeepsTheColorItIsDrawnWith()
  local colors = recordColorsSetWhileDrawing(ImageContainer({image = createImage()}))
  assert(#colors == 0, "an untinted image set " .. #colors .. " colors")
  logger.trace("passed test testUntintedImageKeepsTheColorItIsDrawnWith")
end

local function testTintedImageResetsTheColorAfterDrawing()
  local tint = {0.25, 0.25, 0.25, 1}
  local colors = recordColorsSetWhileDrawing(ImageContainer({image = createImage(), color = tint}))
  assert(#colors == 2 and colors[1][1] == tint, "the tint is set first")
  local last = colors[2]
  assert(last[1] == 1 and last[2] == 1 and last[3] == 1 and last[4] == 1, "the color is reset to white")
  logger.trace("passed test testTintedImageResetsTheColorAfterDrawing")
end

testUntintedImageKeepsTheColorItIsDrawnWith()
testTintedImageResetsTheColorAfterDrawing()
