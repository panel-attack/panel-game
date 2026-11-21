local GraphicsUtil = require("client.src.graphics.graphics_util")
local logger = require("common.lib.logger")

-- readbackTexture reads a Canvas's pixels
local function readbackTextureReadsACanvas()
  if not love.graphics.isActive() then
    -- without a window there is nothing to draw on
    return
  end
  local canvas = love.graphics.newCanvas(2, 2)
  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 1, 0, 1)
  love.graphics.pop()
  local r, g, b, a = GraphicsUtil.readbackTexture(canvas):getPixel(1, 1)
  assert(r == 0 and g == 1 and b == 0 and a == 1, "a canvas should read back the colour drawn into it")
end

-- readbackTexture reads an Image's pixels exactly as they were made, at the image's own pixel size,
-- whatever the caller's colour, transform and blend mode
local function readbackTextureReadsAnImageAsItWasMade()
  if not love.graphics.isActive() then
    -- without a window there is nothing to draw on
    return
  end
  local source = love.image.newImageData(2, 2)
  source:setPixel(0, 0, 1, 0, 0, 0.5)
  source:setPixel(1, 0, 0, 1, 0, 1)
  source:setPixel(0, 1, 0, 0, 1, 0.25)
  -- a dpi scale that differs from the window's, so the image's size in pixels and in units differ
  local image = love.graphics.newImage(source, {dpiscale = love.graphics.getDPIScale() * 2})

  love.graphics.push("all")
  love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
  love.graphics.translate(1, 1)
  love.graphics.setBlendMode("alpha")
  local pixels = GraphicsUtil.readbackTexture(image)
  love.graphics.pop()

  assert(pixels:getWidth() == 2 and pixels:getHeight() == 2,
    "the image should read back at its 2x2 pixel size, got " .. pixels:getWidth() .. "x" .. pixels:getHeight())
  for y = 0, 1 do
    for x = 0, 1 do
      local expected = table.concat({source:getPixel(x, y)}, ",")
      local actual = table.concat({pixels:getPixel(x, y)}, ",")
      assert(actual == expected, "pixel " .. x .. "," .. y .. " should read back as " .. expected .. ", got " .. actual)
    end
  end
end

readbackTextureReadsACanvas()
readbackTextureReadsAnImageAsItWasMade()

-- a file that is there but is not an image loads as a transparent stand in, so whatever draws it draws nothing
local function anImageThatCannotBeLoadedIsTransparent()
  local folder = "graphicsUtilTestsImages"
  love.filesystem.createDirectory(folder)
  love.filesystem.write(folder .. "/broken.png", "not a png")
  local logged
  local originalError = logger.error
  logger.error = function(message)
    logged = message
  end

  local image = GraphicsUtil.loadImageFromSupportedExtensions(folder .. "/broken")

  logger.error = originalError
  love.filesystem.remove(folder .. "/broken.png")
  love.filesystem.remove(folder)
  assert(logged and logged:find("broken.png", 1, true), "the broken file is reported")
  assert(image and image:getWidth() == 1 and image:getHeight() == 1, "the broken file loads as a transparent pixel")
end

anImageThatCannotBeLoadedIsTransparent()
