local InputField = require("client.src.ui.InputField")
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

testDefaultFilterIsAlphanumeric()
testNumericFilter()
testNoFilter()
