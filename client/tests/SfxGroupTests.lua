local SfxGroup = require("client.src.music.SfxGroup")
local FileUtils = require("client.src.FileUtils")
local tableUtils = require("common.lib.tableUtils")

local files = {
  "chain2.ogg",
  "chain3.wav",
  "chain4.WAV",
  "chain5.mp3",
}

local matchingGroup1 = {
  "chain2.ogg",
  "chain3.wav",
  "chain5.mp3",
}

local matchingGroup2 = {

}


local function testFileMatching1()
  local pattern = "chain"
  local separator = ""
  local matchingFiles = SfxGroup.getMatchingFiles(files, pattern, separator)

  for _, matched in ipairs(matchingFiles) do
    assert(tableUtils.contains(matchingGroup1, matched), "Unexpectedly matched " .. matched)
  end
  for _, control in ipairs(matchingFiles) do
    assert(tableUtils.contains(matchingGroup1, control), "Expected the matching files to also match " .. control)
  end
end

testFileMatching1()