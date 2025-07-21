local PuzzleHierarchyDisplay = require("client.src.graphics.PuzzleHierarchyDisplay")
local PuzzleSet = require("client.src.PuzzleSet")
local Puzzle = require("common.engine.Puzzle")
local class = require("common.lib.class")

local PuzzleHierarchyDisplayTests = class(function() end)

function PuzzleHierarchyDisplayTests.testClassExists()
  -- Test that PuzzleHierarchyDisplay class exists and can be instantiated
  assert(PuzzleHierarchyDisplay ~= nil, "PuzzleHierarchyDisplay class should exist")
  
  local puzzle1 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 1, stack = "1111111111111111"})
  local puzzleSet = PuzzleSet("Test Set", "Test description", {puzzle1})
  
  local display = PuzzleHierarchyDisplay({
    puzzleSet = puzzleSet,
    puzzleSetIndices = {1},
    width = 200,
    height = 100
  })
  assert(display ~= nil, "PuzzleHierarchyDisplay should be instantiable")
  assert(display.puzzleSet == puzzleSet, "Should store puzzle set")
  assert(display.puzzleSetIndices[1] == 1, "Should store puzzle set indices")
end

function PuzzleHierarchyDisplayTests.testHierarchyDisplay()
  -- Test that the hierarchy display component works with nested puzzle sets
  local puzzle1 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 1, stack = "1111111111111111"})
  local puzzle2 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 2, stack = "2222222222222222"})
  local puzzle3 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 3, stack = "3333333333333333"})
  
  local childSet = PuzzleSet("Child Set", "Child description", {puzzle3})
  local parentSet = PuzzleSet("Parent Set", "Parent description", {puzzle1, puzzle2}, {childSet})
  
  -- Test display for puzzle in child set
  local display = PuzzleHierarchyDisplay({
    puzzleSet = parentSet,
    puzzleSetIndices = {1, 1}, -- First child set, first puzzle
    width = 200,
    height = 100
  })
  
  -- Test that the display can be drawn without errors
  assert(type(display.drawSelf) == "function", "Should have drawSelf method")
  assert(type(display.drawHierarchyWithStyling) == "function", "Should have drawHierarchyWithStyling method")
  
  -- Test that it correctly stores the puzzle set and indices
  assert(display.puzzleSet == parentSet, "Should store correct puzzle set")
  assert(#display.puzzleSetIndices == 2, "Should store correct number of indices")
  assert(display.puzzleSetIndices[1] == 1 and display.puzzleSetIndices[2] == 1, "Should store correct indices")
end

function PuzzleHierarchyDisplayTests.testUpdateMethodUpdatesDisplay()
  -- Test that PuzzleHierarchyDisplay has an update method to refresh its state
  local puzzle1 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 1, stack = "1111111111111111"})
  local puzzle2 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 2, stack = "2222222222222222"})
  
  local childSet = PuzzleSet("Child Set", "Child description", {puzzle1, puzzle2})
  local parentSet = PuzzleSet("Parent Set", "Parent description", {}, {childSet})
  
  local display = PuzzleHierarchyDisplay({
    puzzleSet = parentSet,
    puzzleSetIndices = {1}, -- Initially at child set
    width = 200,
    height = 100
  })
  
  -- The display should have an update method to refresh when indices change
  assert(type(display.updateDisplay) == "function", "PuzzleHierarchyDisplay should have an updateDisplay method")
  
  -- Test that calling update with new indices works
  display:updateDisplay(parentSet, {1, 2}) -- Navigate to second puzzle
  assert(display.puzzleSetIndices[#display.puzzleSetIndices] == 2, "Should update to show latest puzzle index (2)")
end

function PuzzleHierarchyDisplayTests.testUsesLocalizedNames()
  -- Test that PuzzleHierarchyDisplay uses localizedSetName instead of setName
  local puzzle1 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 1, stack = "1111111111111111"})
  
  local childSet = PuzzleSet("Child Set", "Child description", {puzzle1})
  childSet.localizedSetName = "Localized Child Name"
  
  local parentSet = PuzzleSet("Parent Set", "Parent description", {}, {childSet})
  parentSet.localizedSetName = "Localized Parent Name"
  
  local display = PuzzleHierarchyDisplay({
    puzzleSet = parentSet,
    puzzleSetIndices = {1, 1}, -- Navigate to child set, first puzzle
    width = 200,
    height = 100
  })
  
  -- The display should use localizedSetName when available
  -- We need to test the drawHierarchyWithStyling method uses localized names
  -- Since we can't easily test visual output, we'll add a method to get the display text
  assert(type(display.getDisplayText) == "function", "PuzzleHierarchyDisplay should have getDisplayText method to test localization")
  
  local displayText = display:getDisplayText()
  assert(string.find(displayText, "Localized Parent Name"), "Should use localized parent name")
  assert(string.find(displayText, "Localized Child Name"), "Should use localized child name")
  assert(not string.find(displayText, "Parent Set"), "Should not use raw setName")
  assert(not string.find(displayText, "Child Set"), "Should not use raw setName")
end

-- Run the tests
PuzzleHierarchyDisplayTests.testClassExists()
PuzzleHierarchyDisplayTests.testHierarchyDisplay()
PuzzleHierarchyDisplayTests.testUpdateMethodUpdatesDisplay()
PuzzleHierarchyDisplayTests.testUsesLocalizedNames()

return PuzzleHierarchyDisplayTests