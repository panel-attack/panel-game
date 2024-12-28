local FileUtils = require("client.src.FileUtils")
local tableUtils = require("common.lib.tableUtils")

local files = {
  "chain2.ogg",
  "chain3.wav",
  -- upper case file extension
  "chain4.WAV",
  "chain5.mp3",
  -- 6e2 is a number for lua
  "chain6e2.mp3",
  -- 7.7 is a number for lua
  "chain7.7.mp3",
  -- leading 0
  "chain08.ogg",
  -- prefix
  "mychain9.ogg",
  -- suffix
  "chain10.ogg.bak",
  -- string throwin
  "chain08alt.ogg",
  -- with separator
  "chain2_2.ogg",
  "chain2_3.ogg",
  "chain2_04.ogg",
  "chain3_2.ogg",
  -- extra number before separator
  "chain22_2.ogg",
  "panel11.png",
  "panel102.png",
  "ppanel13.png",
  "panel1_4.png",
  "panel15.PNG",
  "panel01_6.png",
  "panel017.png",
  "panel-2.png",
  "panel00.png",
  "panel18.png.jpg",
  "panel109.jpag",
}

local function testFileMatching(pattern, validExtensions, separator, controlGroup)
  local matchingFiles = FileUtils.getMatchingFiles(files, pattern, validExtensions, separator)

  for _, matched in ipairs(matchingFiles) do
    assert(tableUtils.contains(controlGroup, matched), "Unexpectedly matched " .. matched)
  end
  for _, control in ipairs(controlGroup) do
    assert(tableUtils.contains(matchingFiles, control), "Expected the matching files to also match " .. control)
  end
end

local function testFileMatching1()
  local pattern = "chain"
  local separator = ""
  local expected = {
    "chain2.ogg",
    "chain3.wav",
    "chain5.mp3",
    "chain08.ogg",
  }

  testFileMatching(pattern, FileUtils.SUPPORTED_SOUND_FORMATS, separator, expected)
end

local function testfileMatching2()
  local pattern = "chain2"
  local separator = "_"
  local expected = {
    "chain2.ogg",
    "chain2_2.ogg",
    "chain2_3.ogg",
    "chain2_04.ogg",
  }

  testFileMatching(pattern, FileUtils.SUPPORTED_SOUND_FORMATS, separator, expected)
end

local function testfileMatching3()
  local pattern = "panel1"
  local separator = ""
  local expected = {
    "panel11.png",
    "panel102.png",
  }

  testFileMatching(pattern, FileUtils.SUPPORTED_IMAGE_FORMATS, separator, expected)
end

testFileMatching1()
testfileMatching2()
testfileMatching3()