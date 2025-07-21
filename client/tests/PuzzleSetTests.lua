local PuzzleSet = require("client.src.PuzzleSet")
local Puzzle = require("common.engine.Puzzle")
local json = require('common.lib.dkjson')
local FileUtils = require('client.src.FileUtils')
local class = require("common.lib.class")

local PuzzleSetTests = class(function() end)

function PuzzleSetTests.updatePuzzleValid()
  local puzzle1 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 5, stack = "1254216999999952"})
  local puzzle2 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 3, stack = "2134567890123456"})
  local puzzleSet = PuzzleSet("Test Set", "Test description", {puzzle1})
  
  local newPuzzle = Puzzle({puzzleType = "chain", startTiming = "countdown", moves = 1, stack = "9876543210987654"})
  puzzleSet:updatePuzzle(1, newPuzzle)
  
  local updatedPuzzle = puzzleSet:getPuzzle(1)
  assert(updatedPuzzle.puzzleType == "chain")
  assert(updatedPuzzle.startTiming == "countdown")
  assert(updatedPuzzle.moves == 1)
  assert(updatedPuzzle.stack == "9876543210987654")
end

function PuzzleSetTests.generateSaveDataValid()
  local puzzle1 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 5, stack = "1254216999999952"})
  local puzzle2 = Puzzle({puzzleType = "chain", startTiming = "countdown", moves = 3, stack = "2134567890123456", cursorStartLeft = {row = 2, column = 3}})
  local puzzleSet = PuzzleSet("Test Set", "A test description", {puzzle1, puzzle2})
  
  local data = puzzleSet:generateSaveData()
  
  assert(data.Version == 3)
  assert(data["Puzzle Sets"] ~= nil)
  assert(#data["Puzzle Sets"] == 1)
  
  local puzzleSetData = data["Puzzle Sets"][1]
  assert(puzzleSetData["Set Name"] == "Test Set")
  assert(puzzleSetData["Description"] == "A test description")
  assert(puzzleSetData["Puzzles"] ~= nil)
  assert(#puzzleSetData["Puzzles"] == 2)
  
  local puzzleData1 = puzzleSetData["Puzzles"][1]
  assert(puzzleData1["Puzzle Type"] == "moves")
  assert(puzzleData1["StartTiming"] == "immediately")
  assert(puzzleData1["Moves"] == 5)
  assert(puzzleData1["Stack"] == "1254216999999952")
  assert(puzzleData1["CursorStartLeft"] == nil)
  
  local puzzleData2 = puzzleSetData["Puzzles"][2]
  assert(puzzleData2["Puzzle Type"] == "chain")
  assert(puzzleData2["StartTiming"] == "countdown")
  assert(puzzleData2["Moves"] == 3)
  assert(puzzleData2["Stack"] == "2134567890123456")
  assert(puzzleData2["CursorStartLeft"] ~= nil)
  assert(puzzleData2["CursorStartLeft"].Row == 2)
  assert(puzzleData2["CursorStartLeft"].Column == 3)
end

function PuzzleSetTests.generateSaveDataNoPuzzles()
  local puzzleSet = PuzzleSet("Test Set", "A test description", {})
  
  local data = puzzleSet:generateSaveData()
  
  assert(data.Version == 3)
  assert(data["Puzzle Sets"] ~= nil)
  assert(#data["Puzzle Sets"] == 1)
  assert(data["Puzzle Sets"][1]["Set Name"] == "Test Set")
  assert(data["Puzzle Sets"][1]["Description"] == "A test description")
  assert(data["Puzzle Sets"][1]["Puzzles"] ~= nil)
  assert(#data["Puzzle Sets"][1]["Puzzles"] == 0)
end

function PuzzleSetTests.generateSaveDataWithOptionalFields()
  local puzzle = Puzzle({
    puzzleType = "clear", 
    startTiming = "firstSwap", 
    moves = 10, 
    stack = "9876543210987654",
    stopTime = 15,
    shakeTime = 8,
    panelBuffer = "111222333",
    garbagePanelBuffer = "444555666"
  })
  local puzzleSet = PuzzleSet("Complex Set", nil, {puzzle})
  
  local data = puzzleSet:generateSaveData()
  local puzzleData = data["Puzzle Sets"][1]["Puzzles"][1]
  
  assert(puzzleData["Stop"] == 15)
  assert(puzzleData["Shake"] == 8)
  assert(puzzleData["PanelBuffer"] == "111222333")
  assert(puzzleData["GarbagePanelBuffer"] == "444555666")
end

function PuzzleSetTests.testJSONValidityRequirement1()
  local puzzle1 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 1, stack = "2100001200001200"})
  local puzzle2 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 1, stack = "6400006400004600006400006400"})
  local puzzleSet = PuzzleSet("Test Set", "Test description", {puzzle1, puzzle2})
  
  local data = puzzleSet:generateSaveData()
  
  local baseEncoded = json.encode(data, {indent = true, pretty = true, keyorder = PuzzleSet.keyOrder})
  local encoded = FileUtils.prettifyJson(baseEncoded)
  
  -- Test that the JSON is valid by attempting to decode it
  local decoded, pos, err = json.decode(encoded)
  assert(decoded ~= nil, "JSON should be valid and decodable: " .. tostring(err or "unknown error"))
  assert(err == nil, "JSON should not have decode errors: " .. tostring(err))
  
  -- Test that there are no duplicate keys by checking structure integrity
  assert(decoded.Version == 3, "Version should be preserved correctly")
  assert(decoded["Puzzle Sets"] ~= nil, "Puzzle Sets should exist")
  assert(#decoded["Puzzle Sets"] == 1, "Should have exactly one puzzle set")
  assert(decoded["Puzzle Sets"][1]["Puzzles"] ~= nil, "Puzzles should exist")
  assert(#decoded["Puzzle Sets"][1]["Puzzles"] == 2, "Should have exactly two puzzles")
end

function PuzzleSetTests.testUnchangedPuzzlePreservationRequirement3()
  -- Puzzles that were not edited shouldn't be changed when you use the puzzle editor
  -- This tests that when we update one puzzle in a set, the other puzzles remain exactly the same
  local puzzle1 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 1, stack = "2100001200001200"})
  local puzzle2 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 2, stack = "6400006400004600006400006400"})
  local puzzle3 = Puzzle({puzzleType = "chain", startTiming = "countdown", moves = 3, stack = "1234567890123456"})
  
  local originalPuzzleSet = PuzzleSet("Test Set", "Test description", {puzzle1, puzzle2, puzzle3})
  
  -- Generate the original save data
  local originalData = originalPuzzleSet:generateSaveData()
  local originalEncoded = json.encode(originalData, {indent = true, pretty = true, keyorder = PuzzleSet.keyOrder})
  
  -- Get the original puzzle data for comparison
  local originalPuzzle1Data = originalData["Puzzle Sets"][1]["Puzzles"][1]
  local originalPuzzle2Data = originalData["Puzzle Sets"][1]["Puzzles"][2]  
  local originalPuzzle3Data = originalData["Puzzle Sets"][1]["Puzzles"][3]
  
  -- Now simulate editing only the second puzzle
  local modifiedPuzzle2 = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 5, stack = "9999999999999999"})
  originalPuzzleSet:updatePuzzle(2, modifiedPuzzle2)
  
  -- Generate the new save data
  local newData = originalPuzzleSet:generateSaveData()
  local newEncoded = json.encode(newData, {indent = true, pretty = true, keyorder = PuzzleSet.keyOrder})
  
  -- Get the new puzzle data for comparison
  local newPuzzle1Data = newData["Puzzle Sets"][1]["Puzzles"][1]
  local newPuzzle2Data = newData["Puzzle Sets"][1]["Puzzles"][2]
  local newPuzzle3Data = newData["Puzzle Sets"][1]["Puzzles"][3]
  
  -- Test that puzzle 1 (unchanged) remains exactly the same
  assert(originalPuzzle1Data["Stack"] == newPuzzle1Data["Stack"], "Puzzle 1 stack should be unchanged")
  assert(originalPuzzle1Data["Moves"] == newPuzzle1Data["Moves"], "Puzzle 1 moves should be unchanged")
  assert(originalPuzzle1Data["Puzzle Type"] == newPuzzle1Data["Puzzle Type"], "Puzzle 1 type should be unchanged")
  assert(originalPuzzle1Data["StartTiming"] == newPuzzle1Data["StartTiming"], "Puzzle 1 start timing should be unchanged")
  
  -- Test that puzzle 3 (unchanged) remains exactly the same
  assert(originalPuzzle3Data["Stack"] == newPuzzle3Data["Stack"], "Puzzle 3 stack should be unchanged")
  assert(originalPuzzle3Data["Moves"] == newPuzzle3Data["Moves"], "Puzzle 3 moves should be unchanged")
  assert(originalPuzzle3Data["Puzzle Type"] == newPuzzle3Data["Puzzle Type"], "Puzzle 3 type should be unchanged")
  assert(originalPuzzle3Data["StartTiming"] == newPuzzle3Data["StartTiming"], "Puzzle 3 start timing should be unchanged")
  
  -- Test that puzzle 2 (changed) has been updated correctly
  assert(newPuzzle2Data["Stack"] == "9999999999999999", "Puzzle 2 stack should be updated")
  assert(newPuzzle2Data["Moves"] == 5, "Puzzle 2 moves should be updated")
  assert(originalPuzzle2Data["Stack"] ~= newPuzzle2Data["Stack"], "Puzzle 2 stack should be different from original")
  assert(originalPuzzle2Data["Moves"] ~= newPuzzle2Data["Moves"], "Puzzle 2 moves should be different from original")
end

function PuzzleSetTests.testExactJSONFormatting()
  local logger = require("common.lib.logger")
  
  -- Test exact character-for-character formatting
  local puzzle = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = 1, stack = "000000000000000000000000000000000000000000000000000000000000000000060660"})
  local puzzleSet = PuzzleSet("Test Set", "Test description", {puzzle})
  
  local data = puzzleSet:generateSaveData()
  local encoded = json.encode(data, {indent = true, pretty = true, keyorder = PuzzleSet.keyOrder})
  local prettified = FileUtils.prettifyJson(encoded)
  
  logger.info("=== CURRENT PRETTIFIED OUTPUT ===")
  logger.info(prettified)
  logger.info("=== ESCAPED VERSION ===")
  logger.info(string.gsub(prettified, "\n", "\\n\n"))
  
  -- Define the exact expected format
  local expected = [[{
  "Version": 3,
  "Puzzle Sets":
  [
    {
      "Set Name": "Test Set",
      "Description": "Test description",
      "Puzzles":
      [
        {
          "Puzzle Type": "moves",
          "StartTiming": "immediately",
          "Moves": 1,
          "Stack": "000000000000000000000000000000000000000000000000000000000000000000060660"
        }
      ]
    }
  ]
}]]

  logger.info("=== EXPECTED FORMAT ===")
  logger.info(expected)
  logger.info("=== EXPECTED ESCAPED ===")
  logger.info(string.gsub(expected, "\n", "\\n\n"))
  
  -- Character by character comparison
  assert(prettified == expected, "JSON formatting should match exactly")
end

-- Run the tests
PuzzleSetTests.updatePuzzleValid()
PuzzleSetTests.generateSaveDataValid()
PuzzleSetTests.generateSaveDataNoPuzzles()
PuzzleSetTests.generateSaveDataWithOptionalFields()
PuzzleSetTests.testJSONValidityRequirement1()
PuzzleSetTests.testUnchangedPuzzlePreservationRequirement3()
PuzzleSetTests.testExactJSONFormatting()

return PuzzleSetTests