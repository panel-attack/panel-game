-- General testing utilities for Panel Attack tests
-- These functions provide common functionality needed across different test suites

local TestUtils = {}

---Expect an error without tripping Local Lua Debugger
---@param thunk function Function that should throw an error
---@param pattern string|nil Optional pattern to match in the error message
---@return boolean success True if error was caught and pattern matched (if provided)
---@return string errorMessage Error message if test failed
function TestUtils.expectErrorQuiet(thunk, pattern)
  pcall(function() require("lldebugger").stop() end)

  -- run the code in protected mode so we capture the error
  local ok, err = xpcall(thunk, function(e) return e end)

  -- always try to re-enable the debugger; pass false so it doesn't break on re-start
  pcall(function() require("lldebugger").start(false) end)

  if ok then return false, "no error was raised" end
  if pattern and not tostring(err):match(pattern) then
    return false, ("unexpected error: %s"):format(err)
  end
  return true, ""
end

-- Errors with the message, the expected value and the actual one unless they are equal
---@param actual any
---@param expected any
---@param message string?
function TestUtils.assertEqual(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s: Expected %s, got %s", message or "Assertion failed", tostring(expected), tostring(actual)))
  end
end

-- Returns an image of the given pixel size whose every pixel is the given color
---@param width integer
---@param height integer
---@param color number[] red, green, blue and an optional alpha, 0 to 1
---@param settings table? the settings love.graphics.newImage takes
---@return love.Texture
function TestUtils.solidImage(width, height, color, settings)
  local imageData = love.image.newImageData(width, height)
  imageData:mapPixel(function()
    return color[1], color[2], color[3], color[4] or 1
  end)
  return love.graphics.newImage(imageData, settings)
end

-- Returns the largest difference of any channel between two images of the same size, 0 to 255
---@param a love.ImageData
---@param b love.ImageData
---@return integer
function TestUtils.largestPixelDifference(a, b)
  local largest = 0
  for y = 0, a:getHeight() - 1 do
    for x = 0, a:getWidth() - 1 do
      local r1, g1, b1, a1 = a:getPixel(x, y)
      local r2, g2, b2, a2 = b:getPixel(x, y)
      largest = math.max(largest, math.abs(r1 - r2), math.abs(g1 - g2), math.abs(b1 - b2), math.abs(a1 - a2))
    end
  end
  return math.round(largest * 255)
end

return TestUtils