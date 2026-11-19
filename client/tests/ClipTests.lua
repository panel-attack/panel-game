local GraphicsUtil = require("client.src.graphics.graphics_util")
local logger = require("common.lib.logger")

local WIDTH = 20

-- Returns a row of 20 pixels after draw drew in white on black, # for each pixel it drew and . for the rest
---@param draw fun()
---@return string
local function pixelsAfter(draw)
  local canvas = love.graphics.newCanvas(WIDTH, 1)
  love.graphics.push("all")
  love.graphics.setCanvas({canvas, stencil = true})
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.setColor(1, 1, 1, 1)
  draw()
  love.graphics.pop()
  local imageData = love.graphics.readbackTexture and love.graphics.readbackTexture(canvas) or canvas:newImageData()
  local pixels = {}
  for x = 0, WIDTH - 1 do
    pixels[#pixels + 1] = imageData:getPixel(x, 0) > 0.5 and "#" or "."
  end
  return table.concat(pixels)
end

local function fillRow()
  love.graphics.rectangle("fill", 0, 0, WIDTH, 1)
end

local function testAClipInsideAClipDrawsOnlyWhereBothAre()
  local pixels = pixelsAfter(function()
    GraphicsUtil.clipStack:pushRectangle(0, 0, 10, 1)
    GraphicsUtil.clipStack:pushRectangle(5, 0, 10, 1)
    fillRow()
    GraphicsUtil.clipStack:pop()
    GraphicsUtil.clipStack:pop()
  end)
  assert(pixels == ".....#####..........", "drew " .. pixels)
  logger.trace("passed test testAClipInsideAClipDrawsOnlyWhereBothAre")
end

local function testDrawingAfterAnInnerClipEndsStaysInsideTheOuterClip()
  local pixels = pixelsAfter(function()
    GraphicsUtil.clipStack:pushRectangle(0, 0, 10, 1)
    GraphicsUtil.clipStack:pushRectangle(5, 0, 10, 1)
    GraphicsUtil.clipStack:pop()
    fillRow()
    GraphicsUtil.clipStack:pop()
  end)
  assert(pixels == "##########..........", "drew " .. pixels)
  logger.trace("passed test testDrawingAfterAnInnerClipEndsStaysInsideTheOuterClip")
end

local function testAClipAfterAnotherDrawsOnlyInsideItself()
  local pixels = pixelsAfter(function()
    GraphicsUtil.clipStack:pushRectangle(0, 0, 5, 1)
    GraphicsUtil.clipStack:pop()
    GraphicsUtil.clipStack:pushRectangle(10, 0, 5, 1)
    fillRow()
    GraphicsUtil.clipStack:pop()
  end)
  assert(pixels == "..........#####.....", "drew " .. pixels)
  logger.trace("passed test testAClipAfterAnotherDrawsOnlyInsideItself")
end

local function drawLeftHalfTwice()
  love.graphics.rectangle("fill", 0, 0, 10, 1)
  love.graphics.rectangle("fill", 0, 0, 10, 1)
end

local function testAShapeThatCoversItsPixelsTwiceStillClipsToThem()
  local pixels = pixelsAfter(function()
    GraphicsUtil.clipStack:pushShape(drawLeftHalfTwice)
    fillRow()
    GraphicsUtil.clipStack:pop()
  end)
  assert(pixels == "##########..........", "drew " .. pixels)
  logger.trace("passed test testAShapeThatCoversItsPixelsTwiceStillClipsToThem")
end

local function testAShapeInsideAClipDrawsOnlyWhereBothAre()
  local pixels = pixelsAfter(function()
    GraphicsUtil.clipStack:pushRectangle(5, 0, 10, 1)
    GraphicsUtil.clipStack:pushShape(fillRow)
    fillRow()
    GraphicsUtil.clipStack:pop()
    GraphicsUtil.clipStack:pop()
  end)
  assert(pixels == ".....##########.....", "drew " .. pixels)
  logger.trace("passed test testAShapeInsideAClipDrawsOnlyWhereBothAre")
end

local function testClippingAllocatesNothingOnceEachDepthIsReached()
  local grownKilobytes
  pixelsAfter(function()
    local clipStack = GraphicsUtil.clipStack
    local function clipOnce()
      clipStack:pushRectangle(0, 0, 10, 1)
      clipStack:pushShape(fillRow)
      clipStack:pop()
      clipStack:pop()
    end
    -- reaches each depth and lets LuaJIT compile the loop, which allocates a few kilobytes once
    for _ = 1, 1000 do
      clipOnce()
    end
    collectgarbage("stop")
    local before = collectgarbage("count")
    for _ = 1, 10000 do
      clipOnce()
    end
    grownKilobytes = collectgarbage("count") - before
    collectgarbage("restart")
  end)
  -- a table a push would make is at least 32 bytes, over 300 kilobytes in the 10000 rounds; the LÖVE calls alone grow by about 2
  assert(grownKilobytes < 10, "clipping 10000 times allocated " .. grownKilobytes .. " kilobytes")
  logger.trace("passed test testClippingAllocatesNothingOnceEachDepthIsReached")
end

if love.graphics.isActive() then
  testAClipInsideAClipDrawsOnlyWhereBothAre()
  testDrawingAfterAnInnerClipEndsStaysInsideTheOuterClip()
  testAClipAfterAnotherDrawsOnlyInsideItself()
  testAShapeThatCoversItsPixelsTwiceStillClipsToThem()
  testAShapeInsideAClipDrawsOnlyWhereBothAre()
  testClippingAllocatesNothingOnceEachDepthIsReached()
else
  logger.warn("skipped the clip tests, which need a window to draw in")
end
