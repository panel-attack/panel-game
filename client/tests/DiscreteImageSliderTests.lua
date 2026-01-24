local DiscreteImageSlider = require("client.src.ui.DiscreteImageSlider")
local logger = require("common.lib.logger")

local function createMockImage(width, height)
  local imageData = love.image.newImageData(width, height)
  return love.graphics.newImage(imageData)
end

local function createMockValue(id, width, height)
  width = width or 50
  height = height or 50
  return {
    id = id,
    image = createMockImage(width, height),
    scale = 1
  }
end

local function testBasicConstruction()
  local values = {
    createMockValue("item1", 50, 50),
    createMockValue("item2", 50, 50),
    createMockValue("item3", 50, 50)
  }

  local slider = DiscreteImageSlider({
    values = values,
    selectedValue = "item2"
  })

  assert(slider ~= nil, "Slider should be created")
  assert(#slider.values == 3, "Should have 3 values")
  assert(slider.value == 2, "Should select item2 (index 2)")
  assert(slider:getSelectedId() == "item2", "Should return correct selected ID")
  assert(slider.min == 1, "Min should be 1")
  assert(slider.max == 3, "Max should be 3")

  logger.trace("passed test testBasicConstruction")
end

local function testEmptyConstruction()
  local slider = DiscreteImageSlider({
    values = {}
  })

  assert(slider ~= nil, "Slider should be created with empty values")
  assert(#slider.values == 0, "Should have 0 values")
  assert(slider.value == 1, "Value should default to 1")
  assert(slider.min == 1, "Min should be 1")
  assert(slider.max == 1, "Max should be 1 even when empty")

  logger.trace("passed test testEmptyConstruction")
end

local function testIndexIdMapping()
  local values = {
    createMockValue("alpha", 50, 50),
    createMockValue("beta", 50, 50),
    createMockValue("gamma", 50, 50)
  }

  local slider = DiscreteImageSlider({
    values = values
  })

  assert(slider:getIndexForId("alpha") == 1, "Should map alpha to index 1")
  assert(slider:getIndexForId("beta") == 2, "Should map beta to index 2")
  assert(slider:getIndexForId("gamma") == 3, "Should map gamma to index 3")
  assert(slider:getIndexForId("nonexistent") == nil, "Should return nil for invalid ID")

  assert(slider:getIdForIndex(1) == "alpha", "Should map index 1 to alpha")
  assert(slider:getIdForIndex(2) == "beta", "Should map index 2 to beta")
  assert(slider:getIdForIndex(3) == "gamma", "Should map index 3 to gamma")
  assert(slider:getIdForIndex(0) == nil, "Should return nil for index 0")
  assert(slider:getIdForIndex(4) == nil, "Should return nil for out of bounds index")

  logger.trace("passed test testIndexIdMapping")
end

local function testValueSelection()
  local values = {
    createMockValue("item1", 50, 50),
    createMockValue("item2", 50, 50),
    createMockValue("item3", 50, 50)
  }

  local slider = DiscreteImageSlider({
    values = values
  })

  slider:setSelectedId("item3", false)
  assert(slider.value == 3, "Should select item3")
  assert(slider:getSelectedId() == "item3", "Should return item3")

  slider:setSelectedId("item1", false)
  assert(slider.value == 1, "Should select item1")
  assert(slider:getSelectedId() == "item1", "Should return item1")

  slider:setSelectedId("nonexistent", false)
  assert(slider.value == 1, "Should not change value for invalid ID")

  logger.trace("passed test testValueSelection")
end

local function testValueChangeCallback()
  local values = {
    createMockValue("item1", 50, 50),
    createMockValue("item2", 50, 50),
    createMockValue("item3", 50, 50)
  }

  local callbackCount = 0
  local callbackSlider = nil

  local slider = DiscreteImageSlider({
    values = values,
    onValueChange = function(s)
      callbackCount = callbackCount + 1
      callbackSlider = s
    end
  })

  slider:setSelectedId("item2", true)
  assert(callbackCount == 1, "Callback should be called when committed=true")
  assert(callbackSlider == slider, "Callback should receive slider instance")

  slider:setSelectedId("item3", false)
  assert(callbackCount == 2, "Callback should be called even when committed=false (onlyChangeOnRelease=false)")

  logger.trace("passed test testValueChangeCallback")
end

local function testValueChangeCallbackOnlyOnRelease()
  local values = {
    createMockValue("item1", 50, 50),
    createMockValue("item2", 50, 50),
    createMockValue("item3", 50, 50)
  }

  local callbackCount = 0

  local slider = DiscreteImageSlider({
    values = values,
    onlyChangeOnRelease = true,
    onValueChange = function(s)
      callbackCount = callbackCount + 1
    end
  })

  slider:setSelectedId("item2", false)
  assert(callbackCount == 0, "Callback should not be called when committed=false and onlyChangeOnRelease=true")

  slider:setSelectedId("item3", true)
  assert(callbackCount == 1, "Callback should be called when committed=true")

  logger.trace("passed test testValueChangeCallbackOnlyOnRelease")
end

local function testSetValues()
  local values1 = {
    createMockValue("a", 50, 50),
    createMockValue("b", 50, 50)
  }

  local slider = DiscreteImageSlider({
    values = values1,
    selectedValue = "b"
  })

  assert(slider.value == 2, "Should start at value 2")
  assert(slider.max == 2, "Max should be 2")

  local values2 = {
    createMockValue("x", 50, 50),
    createMockValue("y", 50, 50),
    createMockValue("z", 50, 50),
    createMockValue("w", 50, 50)
  }

  slider:setValues(values2)
  assert(#slider.values == 4, "Should have 4 values after setValues")
  assert(slider.max == 4, "Max should be 4")
  assert(slider.value == 2, "Value should be maintained if valid")
  assert(slider:getSelectedId() == "y", "Should now reference new value at index 2")

  logger.trace("passed test testSetValues")
end

local function testSetValuesWithClampedValue()
  local values1 = {
    createMockValue("a", 50, 50),
    createMockValue("b", 50, 50),
    createMockValue("c", 50, 50),
    createMockValue("d", 50, 50),
    createMockValue("e", 50, 50)
  }

  local slider = DiscreteImageSlider({
    values = values1,
    selectedValue = "e"
  })

  assert(slider.value == 5, "Should start at value 5")

  local values2 = {
    createMockValue("x", 50, 50),
    createMockValue("y", 50, 50)
  }

  slider:setValues(values2)
  assert(slider.value == 2, "Value should be clamped to max when reduced")
  assert(slider:getSelectedId() == "y", "Should select last item")

  logger.trace("passed test testSetValuesWithClampedValue")
end

local function testLayoutDimensions()
  local values = {
    createMockValue("item1", 50, 60),
    createMockValue("item2", 40, 60),
    createMockValue("item3", 30, 60)
  }

  local slider = DiscreteImageSlider({
    values = values,
    itemSpacing = 10
  })

  -- Expected width: 50 + 10 + 40 + 10 + 30 = 140
  assert(slider.width == 140, "Width should sum all items and spacing")
  assert(slider.height == 60, "Height should match item height")

  logger.trace("passed test testLayoutDimensions")
end

local function testLayoutDimensionsNoSpacing()
  local values = {
    createMockValue("item1", 50, 60),
    createMockValue("item2", 40, 60),
    createMockValue("item3", 30, 60)
  }

  local slider = DiscreteImageSlider({
    values = values,
    itemSpacing = 0
  })

  -- Expected width: 50 + 40 + 30 = 120
  assert(slider.width == 120, "Width should sum all items without spacing")

  logger.trace("passed test testLayoutDimensionsNoSpacing")
end

local function testStackPanelLayoutPositions()
  local values = {
    createMockValue("item1", 50, 50),
    createMockValue("item2", 40, 50),
    createMockValue("item3", 30, 50)
  }

  local slider = DiscreteImageSlider({
    values = values,
    itemSpacing = 5
  })

  local children = slider.stackPanel.children
  local itemCount = 0
  local positions = {}

  for _, child in ipairs(children) do
    if child.discreteIndex then
      itemCount = itemCount + 1
      positions[child.discreteIndex] = child.x
    end
  end

  assert(itemCount == 3, "Should have 3 item children")
  assert(positions[1] == 0, "Item 1 should be at x=0")
  assert(positions[2] == 55, "Item 2 should be at x=55 (50 + 5)")
  assert(positions[3] == 100, "Item 3 should be at x=100 (50 + 5 + 40 + 5)")

  logger.trace("passed test testStackPanelLayoutPositions")
end

local function testGetValueForPos()
  local values = {
    createMockValue("item1", 50, 50),
    createMockValue("item2", 50, 50),
    createMockValue("item3", 50, 50)
  }

  local slider = DiscreteImageSlider({
    values = values,
    itemSpacing = 0
  })

  slider.x = 100
  slider.y = 100

  -- Click near center of first item (x=100, width=50, center=125)
  local index1 = slider:getValueForPos(125)
  assert(index1 == 1, "Should return index 1 for x=125")

  -- Click near center of second item (x=150, width=50, center=175)
  local index2 = slider:getValueForPos(175)
  assert(index2 == 2, "Should return index 2 for x=175")

  -- Click near center of third item (x=200, width=50, center=225)
  local index3 = slider:getValueForPos(225)
  assert(index3 == 3, "Should return index 3 for x=225")

  logger.trace("passed test testGetValueForPos")
end

local function testSingleValue()
  local values = {
    createMockValue("only", 50, 50)
  }

  local slider = DiscreteImageSlider({
    values = values
  })

  assert(slider.value == 1, "Should have value 1")
  assert(slider.min == 1, "Min should be 1")
  assert(slider.max == 1, "Max should be 1")
  assert(slider:getSelectedId() == "only", "Should select the only item")

  logger.trace("passed test testSingleValue")
end

local function testMixedWidthsAndHeights()
  local values = {
    createMockValue("small", 20, 30),
    createMockValue("medium", 50, 60),
    createMockValue("large", 80, 90),
    createMockValue("tiny", 10, 15)
  }

  local slider = DiscreteImageSlider({
    values = values,
    itemSpacing = 0
  })

  -- Width should be sum: 20 + 50 + 80 + 10 = 160
  assert(slider.width == 160, "Width should handle mixed widths")
  -- Height should be max: 90
  assert(slider.height == 90, "Height should be tallest item")

  logger.trace("passed test testMixedWidthsAndHeights")
end

local function testDuplicateIds()
  local values = {
    createMockValue("duplicate", 50, 50),
    createMockValue("unique", 50, 50),
    createMockValue("duplicate", 50, 50)
  }

  local slider = DiscreteImageSlider({
    values = values
  })

  -- With duplicate IDs, the last one wins in the map
  local index = slider:getIndexForId("duplicate")
  assert(index == 3, "Should map to last occurrence of duplicate ID")

  logger.trace("passed test testDuplicateIds")
end

testBasicConstruction()
testEmptyConstruction()
testIndexIdMapping()
testValueSelection()
testValueChangeCallback()
testValueChangeCallbackOnlyOnRelease()
testSetValues()
testSetValuesWithClampedValue()
testLayoutDimensions()
testLayoutDimensionsNoSpacing()
testStackPanelLayoutPositions()
testGetValueForPos()
testSingleValue()
testMixedWidthsAndHeights()
testDuplicateIds()

logger.trace("All DiscreteImageSlider tests passed!")
