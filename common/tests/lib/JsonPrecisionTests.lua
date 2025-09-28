local json = require("common.lib.dkjson")
local logger = require("common.lib.logger")
local JsonSafePrecision = require("common.data.JsonSafePrecision")
local LevelPresets = require("common.data.LevelPresets")
local TestUtils = require("common.tests.TestUtils")

-- Test that too precise floats trigger assertion
local function testCurrentPrecisionFailure()
  -- Test that our debug validation catches unsafe precision during encoding
  local original = 5/7

  local success, errorMessage = TestUtils.expectErrorQuiet(function()
    json.encode({value = original})
  end, "Safe precision failed")
  assert(success, errorMessage)
end

-- Test that too-large integers trigger assertion
local function testTooLargeIntegersFail()
  local success, errorMessage = TestUtils.expectErrorQuiet(function()
    JsonSafePrecision.toSafePrecision(2^54) -- Larger than 2^53
  end, "Integer too large")
  assert(success, errorMessage)
end

-- Test all the fractions used in LevelPresets when protected are safe
local function testLevelPresetFractions()
  local fractions = {
    {1, 7}, {2, 7}, {3, 7}, {4, 7}, {5, 7}, {6, 7}
  }

  for _, fraction in ipairs(fractions) do
    local safePrecision = JsonSafePrecision.fractionToSafePrecision(fraction[1], fraction[2])

    -- Test that the safe precision version survives JSON roundtrip
    local encoded = json.encode({value = safePrecision})
    local decoded = json.decode(encoded)
    assert(decoded)
    assert(safePrecision == decoded.value,
           string.format("Safe precision for %d/%d failed: %.17g vs %.17g",
                        fraction[1], fraction[2], safePrecision, decoded.value))
  end
end

-- Simulate the exact scenario from LevelPresets and network transmission works
local function testAdjacentDenialFrequencySimulation()

  -- Test level 6 which uses 5/7
  local levelData = LevelPresets.getModern(6)
  local originalFreq = levelData.adjacentDenialFrequency

  -- Simulate sending over network (JSON encode/decode)
  local networkData = {levelData = levelData}
  local encoded = json.encode(networkData)
  local decoded = json.decode(encoded)
  assert(decoded)
  local receivedFreq = decoded.levelData.adjacentDenialFrequency

  -- This verifies the fix is working - values should be equal
  assert(originalFreq == receivedFreq, "Expected adjacentDenialFrequency to be preserved exactly after JSON roundtrip")
end

-- Test large integer handling in toSafePrecision
local function testLargeIntegers()
  local testValues = {
    {42, "Small integer"},
    {1234567890123, "13 digit integer"},
    {12345678901234, "14 digit integer"}
  }

  for _, testCase in ipairs(testValues) do
    local value = testCase[1]
    local description = testCase[2]
    local safePrecision = JsonSafePrecision.toSafePrecision(value)

    -- Test that safe precision survives JSON roundtrip
    local encoded = json.encode({value = safePrecision})
    local decoded = json.decode(encoded)
    assert(decoded, "JSON decode failed for " .. description)
    assert(safePrecision == decoded.value,
           string.format("Large integer precision failed for %s: %.0f vs %.0f",
                        description, safePrecision, decoded.value))
  end
end

-- Run all tests
logger.info("Running JSON Precision Tests...")

if DEBUG_ENABLED then
  testCurrentPrecisionFailure()
  testTooLargeIntegersFail()
end
testLevelPresetFractions()
testAdjacentDenialFrequencySimulation()
testLargeIntegers()

logger.info("JSON Precision Tests completed successfully")