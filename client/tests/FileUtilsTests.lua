local FileUtils = require("client.src.FileUtils")
local tableUtils = require("common.lib.tableUtils")
local logger = require("common.lib.logger")

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
  "garbage_match.ogg",
  "garbage_match2.ogg",
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

local function testFileMatching2()
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

local function testFileMatching3()
  local pattern = "panel1"
  local separator = ""
  local expected = {
    "panel11.png",
    "panel102.png",
  }

  testFileMatching(pattern, FileUtils.SUPPORTED_IMAGE_FORMATS, separator, expected)
end

local function testFileMatching4()
  local pattern = "garbage_match"
  local separator = ""
  local expected = {
    "garbage_match.ogg",
    "garbage_match2.ogg"
  }

  testFileMatching(pattern, FileUtils.SUPPORTED_SOUND_FORMATS, separator, expected)
end

local function testJsonFileSources()
  local path = "common/tests/data/puzzles_v2_format.json"
  local fromPath = assert(FileUtils.readJsonFile(path))
  local file = assert(FileUtils.openFile(path, "r"))
  local fromFile = assert(FileUtils.readJsonFromFile(file))
  assert(json.encode(fromFile) == json.encode(fromPath), "Paths and file objects should use the same JSON decoding")
  assert(not file:isOpen(), "Reading JSON should close the file")

  local missing = "__FileUtilsTests_missing.json"
  assert(not FileUtils.exists(missing))
  local value, failure = FileUtils.readJsonFile(missing)
  assert(value == nil and failure == "read")
  local missingFile, openError = FileUtils.openFile(missing, "r")
  assert(missingFile == nil and openError, "opening a missing file for reading should fail with a message")
end

local function testDecodeFailureLogsOnlyTheStartOfTheFile()
  local contents = string.rep("not json ", 100000)
  local file = {}
  function file:getFilename()
    return "large-video.mp4"
  end
  function file:isOpen()
    return false
  end
  function file:open()
    return true
  end
  function file:read()
    return contents, #contents
  end
  function file:close()
    return true
  end

  local logged = {}
  local originalError, originalWarn = logger.error, logger.warn
  logger.error = function(message)
    logged[#logged + 1] = message
  end
  logger.warn = logger.error
  local value, failure = FileUtils.readJsonFromFile(file)
  logger.error, logger.warn = originalError, originalWarn

  assert(value == nil and failure == "decode")
  assert(#logged == 1 and logged[1]:find("large-video.mp4", 1, true), "A decode failure should be logged once with the filename")
  assert(#logged[1] < 1000, "A decode failure must not log the whole file, logged " .. #logged[1] .. " characters")
end

-- openFile opens the file in the mode it is given
local function openFileOpensInTheGivenMode()
  local path = "common/tests/data/puzzles_v2_format.json"
  local opened = assert(FileUtils.openFile(path, "r"))
  assert(opened:isOpen() and opened:getMode() == "r", "openFile in mode r should open the file for reading")
  assert(opened:read() == love.filesystem.read(path), "the opened file should read the file's contents")
  opened:close()
end

-- readbackTexture reads a Canvas's pixels
local function readbackTextureReadsACanvas()
  if not love.graphics.isActive() then
    -- without a window there is nothing to draw on
    return
  end
  local canvas = love.graphics.newCanvas(2, 2)
  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 1, 0, 1)
  love.graphics.pop()
  local r, g, b, a = FileUtils.readbackTexture(canvas):getPixel(1, 1)
  assert(r == 0 and g == 1 and b == 0 and a == 1, "a canvas should read back the colour drawn into it")
end

-- readbackTexture reads an Image's pixels exactly as they were made, at the image's own pixel size,
-- whatever the caller's colour, transform and blend mode
local function readbackTextureReadsAnImageAsItWasMade()
  if not love.graphics.isActive() then
    -- without a window there is nothing to draw on
    return
  end
  local source = love.image.newImageData(2, 2)
  source:setPixel(0, 0, 1, 0, 0, 0.5)
  source:setPixel(1, 0, 0, 1, 0, 1)
  source:setPixel(0, 1, 0, 0, 1, 0.25)
  -- a dpi scale that differs from the window's, so the image's size in pixels and in units differ
  local image = love.graphics.newImage(source, {dpiscale = love.graphics.getDPIScale() * 2})

  love.graphics.push("all")
  love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
  love.graphics.translate(1, 1)
  love.graphics.setBlendMode("alpha")
  local pixels = FileUtils.readbackTexture(image)
  love.graphics.pop()

  assert(pixels:getWidth() == 2 and pixels:getHeight() == 2,
    "the image should read back at its 2x2 pixel size, got " .. pixels:getWidth() .. "x" .. pixels:getHeight())
  for y = 0, 1 do
    for x = 0, 1 do
      local expected = table.concat({source:getPixel(x, y)}, ",")
      local actual = table.concat({pixels:getPixel(x, y)}, ",")
      assert(actual == expected, "pixel " .. x .. "," .. y .. " should read back as " .. expected .. ", got " .. actual)
    end
  end
end

-- a replay is written where getReplayPath says, so a path recorded before the replay is saved finds it
local function aReplayIsSavedAtItsReplayPath()
  local folder = "fileUtilsTestsReplays"
  local replay = setmetatable({frames = 1}, {__index = {
    generatePath = function(_, separator) return folder .. separator .. "day" end,
    generateFileName = function() return "replay" end,
  }})
  local lastReplayPath = GAME.lastReplayPath

  FileUtils.saveReplay(replay)

  local path = FileUtils.getReplayPath(replay)
  GAME.lastReplayPath = lastReplayPath
  local saved = love.filesystem.getInfo(path) ~= nil
  love.filesystem.remove(folder .. "/day/replay.json")
  love.filesystem.remove(folder .. "/day")
  love.filesystem.remove(folder)
  assert(saved, "the replay is at " .. path)
end

testFileMatching1()
testFileMatching2()
testFileMatching3()
testFileMatching4()
testJsonFileSources()
testDecodeFailureLogsOnlyTheStartOfTheFile()
openFileOpensInTheGivenMode()
readbackTextureReadsACanvas()
readbackTextureReadsAnImageAsItWasMade()
aReplayIsSavedAtItsReplayPath()
