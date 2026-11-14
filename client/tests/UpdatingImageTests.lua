local UpdatingImage = require("client.src.graphics.UpdatingImage")

-- 64x64
local IMAGE_PATH = "client/tests/AnimationLoaderTestData/test_image.png"

local function assertApproxEqual(actual, expected, message)
  if math.abs(actual - expected) > 0.001 then
    error(string.format("%s: Expected %f, got %f", message, expected, actual))
  end
end

local function image()
  return love.graphics.newImage(IMAGE_PATH)
end

-- An image that isn't tiled is stretched over its size
local function testStillImageStretchesOverItsSize()
  local updatingImage = UpdatingImage(image(), false, 0, 0, 1280, 720)

  local drawable = updatingImage.drawables[1]
  assertApproxEqual(drawable.xScale, 20, "The image should be stretched across the canvas")
  assertApproxEqual(drawable.yScale, 11.25, "The image should be stretched down the canvas")
end

-- A tiled image repeats over its size at the image's own size
local function testTiledImageTilesOverItsSize()
  local updatingImage = UpdatingImage(image(), true, 0, 0, 1280, 720)

  local drawable = updatingImage.drawables[1]
  assert(drawable.width == 1280 and drawable.height == 720, "The tiles should cover the canvas")
  assert(drawable.xScale == 1 and drawable.yScale == 1, "The tiles should not be stretched")
end

local function testTiledImageScrollsAcrossAtItsSpeed()
  local updatingImage = UpdatingImage(image(), true, 10, 0, 1280, 720)

  updatingImage:update(2)

  assertApproxEqual(updatingImage.drawables[1].scrollX, 20, "The image should have scrolled 10 pixels a second")
end

-- A positive y speed moves the image up the screen, as it always has
local function testTiledImageScrollsUpForAPositiveYSpeed()
  local updatingImage = UpdatingImage(image(), true, 0, 10, 1280, 720)

  updatingImage:update(2)

  assertApproxEqual(updatingImage.drawables[1].scrollY, -20, "The image should have scrolled 10 pixels a second")
end

-- Scrolling one whole image length looks the same as not scrolling, so it starts over from there
local function testTiledImageScrollStartsOverAfterAWholeImage()
  local updatingImage = UpdatingImage(image(), true, 32, 0, 1280, 720)

  updatingImage:update(2)
  updatingImage:update(0.5)

  assertApproxEqual(updatingImage.drawables[1].scrollX, 16, "The scroll should have started over after 64 pixels")
end

testStillImageStretchesOverItsSize()
testTiledImageTilesOverItsSize()
testTiledImageScrollsAcrossAtItsSpeed()
testTiledImageScrollsUpForAPositiveYSpeed()
testTiledImageScrollStartsOverAfterAWholeImage()
