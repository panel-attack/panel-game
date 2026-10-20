local InputField = require("client.src.ui.InputField")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local logger = require("common.lib.logger")

local function typeEach(field, characters)
  for _, character in ipairs(characters) do
    field:textInput(character)
  end
end

local function testDefaultFilterIsAlphanumeric()
  local field = InputField({charLimit = 20})
  assert(field.filter == InputField.Filter.ALPHANUMERIC, "Default filter should be alphanumeric")
  typeEach(field, {"a", "1", "_", " ", "-", "!"})
  assert(field.value == "a1_", "Alphanumeric filter should keep letters, digits and underscores but got " .. field.value)
  logger.trace("passed test testDefaultFilterIsAlphanumeric")
end

local function testNumericFilter()
  local field = InputField({charLimit = 20, filter = InputField.Filter.NUMERIC})
  typeEach(field, {"1", "a", "2", "_", " ", "3"})
  assert(field.value == "123", "Numeric filter should keep only digits but got " .. field.value)
  logger.trace("passed test testNumericFilter")
end

local function testNoFilter()
  local field = InputField({charLimit = 20, filter = InputField.Filter.NONE})
  typeEach(field, {"a", "1", "_", " ", "-", "!"})
  assert(field.value == "a1_ -!", "No filter should keep every character but got " .. field.value)
  logger.trace("passed test testNoFilter")
end

-- an empty field without a placeholder has zero text height, which used to push the cursor down
local function testCursorHeightDoesNotDependOnText()
  local field = InputField({charLimit = 20, width = 200, height = 25})
  field:setFocus()
  local _, emptyY = field:getCursorPos()
  assert(type(emptyY) == "number", "Cursor position should include a y coordinate")
  field:textInput("1")
  local _, typedY = field:getCursorPos()
  assert(emptyY == typedY, "Cursor should stay at the same height when typing but moved from " .. emptyY .. " to " .. typedY)
  logger.trace("passed test testCursorHeightDoesNotDependOnText")
end

-- the cursor is drawn where getCursorPos says, on the blink phase where it is visible, even in an empty field
local function testCursorIsDrawnAtCursorPos()
  local field = InputField({charLimit = 20, width = 200, height = 25})
  field:setFocus()
  local expectedX, expectedY = field:getCursorPos()

  local originalDraw = GraphicsUtil.draw
  local originalGetTime = love.timer.getTime
  local drawnAt = {}
  -- same parameters as GraphicsUtil.draw so the language server does not infer a different signature for every caller
  ---@diagnostic disable-next-line: duplicate-set-field
  GraphicsUtil.draw = function(_img, x, y, _rot, _xScale, _yScale, _offsetX, _offsetY)
    drawnAt[#drawnAt + 1] = {x = x, y = y}
  end
  ---@diagnostic disable-next-line: duplicate-set-field
  love.timer.getTime = function() return 0 end
  local success, err = pcall(field.drawSelf, field)
  GraphicsUtil.draw = originalDraw
  love.timer.getTime = originalGetTime
  if not success then
    error(err, 0)
  end

  -- the value or placeholder text is drawn first, the cursor last
  local cursor = drawnAt[#drawnAt]
  assert(#drawnAt == 2, "Expected the placeholder and the cursor to be drawn but got " .. #drawnAt .. " draws")
  assert(cursor.x == expectedX and cursor.y == expectedY, "Cursor should be drawn at " .. expectedX .. "," .. expectedY .. " but was drawn at " .. tostring(cursor.x) .. "," .. tostring(cursor.y))
  logger.trace("passed test testCursorIsDrawnAtCursorPos")
end

testDefaultFilterIsAlphanumeric()
testNumericFilter()
testNoFilter()
testCursorHeightDoesNotDependOnText()
testCursorIsDrawnAtCursorPos()
