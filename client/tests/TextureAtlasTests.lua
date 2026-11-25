local TextureAtlas = require("client.src.graphics.TextureAtlas")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local TestUtils = require("common.tests.TestUtils")

local assertEqual = TestUtils.assertEqual
local solidImage = TestUtils.solidImage

-- Whether two placed images, each with its repeated edge around it, share any pixel
local function overlap(a, aSize, b, bSize)
  local border = TextureAtlas.EDGE
  return a.x - border < b.x + bSize.width + border and b.x - border < a.x + aSize.width + border
    and a.y - border < b.y + bSize.height + border and b.y - border < a.y + aSize.height + border
end

-- Every packed image and its repeated edge sit on its page without touching another image's
local function testPackedImagesDontOverlap()
  local sizes = {}
  for i = 1, 40 do
    sizes[i] = {width = 7 + (i * 37) % 90, height = 5 + (i * 53) % 70}
  end
  local pages, placements = TextureAtlas.pack(sizes, 256)

  for i, size in ipairs(sizes) do
    local place = placements[i]
    assert(place, "Image " .. i .. " should be placed")
    local page = pages[place.page]
    assert(place.x - TextureAtlas.EDGE >= 0 and place.y - TextureAtlas.EDGE >= 0, "Image " .. i .. " should start on its page")
    assert(place.x + size.width + TextureAtlas.EDGE <= page.width, "Image " .. i .. " should end inside its page's width")
    assert(place.y + size.height + TextureAtlas.EDGE <= page.height, "Image " .. i .. " should end inside its page's height")
    for j = i + 1, #sizes do
      local other = placements[j]
      if other.page == place.page then
        assert(not overlap(place, size, other, sizes[j]), "Images " .. i .. " and " .. j .. " should not overlap")
      end
    end
  end
end

-- Images that don't fit on one page go on another
local function testPackOpensAnotherPageWhenFull()
  local pages, placements = TextureAtlas.pack({{width = 60, height = 60}, {width = 60, height = 60}}, 100)

  assertEqual(#pages, 2, "Two images too big to share a page should get a page each")
  assert(placements[1].page ~= placements[2].page, "The images should be on different pages")
end

-- A page is only as big as the images on it need
local function testPageIsCroppedToItsImages()
  local pages = TextureAtlas.pack({{width = 10, height = 20}}, 4096)

  assertEqual(pages[1].width, 10 + TextureAtlas.EDGE * 2, "The page should be as wide as the image and its edge")
  assertEqual(pages[1].height, 20 + TextureAtlas.EDGE * 2, "The page should be as tall as the image and its edge")
end

-- An image bigger than a page isn't placed, so it keeps drawing from its own texture
local function testImageBiggerThanAPageIsLeftOut()
  local pages, placements = TextureAtlas.pack({{width = 200, height = 10}, {width = 10, height = 10}}, 100)

  assertEqual(placements[1], nil, "The image wider than a page should not be placed")
  assert(placements[2], "The image that fits should still be placed")
  assertEqual(#pages, 1, "Only the image that fits should need a page")
end

-- Packing several images uses little more memory than the images themselves
local function testPackingWastesLittleSpace()
  local sizes = {}
  local area = 0
  for i = 1, 100 do
    sizes[i] = {width = 20 + (i * 37) % 300, height = 20 + (i * 53) % 200}
    area = area + (sizes[i].width + TextureAtlas.EDGE * 2) * (sizes[i].height + TextureAtlas.EDGE * 2)
  end
  local pages = TextureAtlas.pack(sizes, 4096)

  local pageArea = 0
  for _, page in ipairs(pages) do
    pageArea = pageArea + page.width * page.height
  end
  assert(pageArea <= area * 1.15, string.format("The pages should waste at most 15%%, they waste %.0f%%", (pageArea / area - 1) * 100))
end

-- Draws the texture, or its region of the atlas, scaled up at the top left of a new canvas and returns the pixels
local function drawScaled(texture, quad, scale, size)
  local canvas = love.graphics.newCanvas(size, size)
  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.origin()
  love.graphics.translate(4, 4)
  love.graphics.scale(scale, scale)
  if quad then
    love.graphics.draw(texture, quad, 0, 0)
  else
    love.graphics.draw(texture, 0, 0)
  end
  love.graphics.pop()
  return GraphicsUtil.readbackTexture(canvas)
end

-- Each image drawn from the atlas looks the same as drawn from its own texture, its edges included
local function testAtlasDrawsLikeTheImages()
  local red = solidImage(3, 2, {1, 0, 0, 1})
  local imageData = love.image.newImageData(4, 4)
  imageData:mapPixel(function(x, y)
    return x / 3, y / 3, 1, (x + y) % 2 == 0 and 1 or 0.5
  end)
  local gradient = love.graphics.newImage(imageData)
  local regions = TextureAtlas.build({red, gradient})

  for _, texture in ipairs({red, gradient}) do
    local region = regions[texture]
    assert(region, "Every image should get a region")
    local expected = drawScaled(texture, nil, 6, 40)
    local actual = drawScaled(region.texture, region.quad, 6, 40)
    assertEqual(TestUtils.largestPixelDifference(expected, actual), 0, "The region should draw the same pixels as the image")
  end
  assertEqual(regions[red].texture, regions[gradient].texture, "Both images should share one page")
end

-- A page an odd number of pixels wide at double density is a fractional number of points wide, which LÖVE rounds, and
-- an image an odd number of pixels wide is drawn over its rounded width, so regions still have to sample the same pixels
local function testOddSizedDoubleScaleImagesDrawLikeTheImages()
  local imageData = love.image.newImageData(5, 4)
  imageData:mapPixel(function(x, y)
    return x / 4, y / 3, 1, 1
  end)
  local gradient = love.graphics.newImage(imageData, {dpiscale = 2})
  local red = solidImage(4, 2, {1, 0, 0, 1}, {dpiscale = 2})
  local regions = TextureAtlas.build({gradient, red})

  assertEqual(regions[gradient].texture:getPixelWidth() % 2, 1, "The page should be an odd number of pixels wide")
  for _, texture in ipairs({gradient, red}) do
    local expected = drawScaled(texture, nil, 5, 40)
    local actual = drawScaled(regions[texture].texture, regions[texture].quad, 5, 40)
    assertEqual(TestUtils.largestPixelDifference(expected, actual), 0, "The region should draw the same pixels as the image")
  end
end

-- Images at different pixel densities are drawn at their own size, so they go on different pages
local function testImagesAtDifferentScalesGetTheirOwnPages()
  local single = solidImage(4, 4, {1, 1, 1, 1})
  local otherSingle = solidImage(4, 4, {1, 1, 1, 1})
  local double = solidImage(4, 4, {1, 1, 1, 1}, {dpiscale = 2})
  local otherDouble = solidImage(4, 4, {1, 1, 1, 1}, {dpiscale = 2})
  local regions = TextureAtlas.build({single, double, otherSingle, otherDouble})

  assert(regions[single].texture ~= regions[double].texture, "The two scales should not share a page")
  assertEqual(regions[single].texture, regions[otherSingle].texture, "Images at the same scale should share a page")
  local _, _, width, height = regions[double].quad:getViewport()
  assertEqual(width .. "x" .. height, "2x2", "The double scale image's region should be its size in points")
end

-- An image alone at its scale has nothing to batch with, so it keeps its own texture
local function testLoneImageIsLeftOut()
  local single = solidImage(4, 4, {1, 1, 1, 1})
  local double = solidImage(4, 4, {1, 1, 1, 1}, {dpiscale = 2})
  local otherDouble = solidImage(4, 4, {1, 1, 1, 1}, {dpiscale = 2})
  local regions = TextureAtlas.build({single, double, otherDouble})

  assertEqual(regions[single], nil, "The only image at its scale should not get a region")
end

-- An image that repeats samples across its own edges, which a page can't do, so it keeps its own texture
local function testRepeatingImageIsLeftOut()
  local repeating = solidImage(4, 4, {1, 1, 1, 1})
  repeating:setWrap("repeat", "repeat")
  local regions = TextureAtlas.build({repeating, solidImage(4, 4, {1, 1, 1, 1}), solidImage(4, 4, {1, 1, 1, 1})})

  assertEqual(regions[repeating], nil, "A repeating image should not get a region")
end

local function runAllTests()
  testPackedImagesDontOverlap()
  testPackOpensAnotherPageWhenFull()
  testPageIsCroppedToItsImages()
  testImageBiggerThanAPageIsLeftOut()
  testPackingWastesLittleSpace()
  -- without a window there is nothing to draw on
  if love.graphics.isActive() then
    testAtlasDrawsLikeTheImages()
    testOddSizedDoubleScaleImagesDrawLikeTheImages()
    testImagesAtDifferentScalesGetTheirOwnPages()
    testLoneImageIsLeftOut()
    testRepeatingImageIsLeftOut()
  end
end

runAllTests()
