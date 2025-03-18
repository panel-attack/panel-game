local consts = require("common.engine.consts")
local logger = require("common.lib.logger")
local FileGroup = require("client.src.FileGroup")
local fileUtils = require("client.src.FileUtils")
local SfxGroup = require("client.src.music.SfxGroup")

local function test(func)
  func()
end

local function testNormalPlayAndStop()
  local fileGroup = FileGroup("client/assets/default_data/characters/Esme", "chain", fileUtils.SUPPORTED_SOUND_FORMATS)
  local chainSounds = SfxGroup(fileGroup, 1)

  assert(chainSounds ~= nil)
  assert(chainSounds:isPlaying() == false)
  chainSounds:play(1)
  assert(chainSounds:isPlaying())
  chainSounds:stop()
  assert(chainSounds:isPlaying() == false)
end

-- test(testNormalPlayAndStop)

local function testPlayNewStopsOld()
  local fileGroup = FileGroup("client/assets/default_data/characters/Esme", "chain", fileUtils.SUPPORTED_SOUND_FORMATS)
  local chainSounds = SfxGroup(fileGroup, 1)

  assert(chainSounds ~= nil)
  chainSounds:play(1)
  local oldSound = chainSounds.lastPlaying
  assert(oldSound:isPlaying())
  chainSounds:play(2)
  assert(oldSound:isPlaying() == false)
  assert(chainSounds:isPlaying())
  chainSounds:stop()
end

-- test(testPlayNewStopsOld)

local function testPlayStop()
  local fileGroup = FileGroup("client/assets/default_data/characters/Esme", "chain", fileUtils.SUPPORTED_SOUND_FORMATS)
  local chainSounds = SfxGroup(fileGroup, 1)

  assert(chainSounds ~= nil)
  chainSounds:play(1)
  chainSounds:stop()
  assert(chainSounds:isPlaying() == false)
  chainSounds:play(2)
  chainSounds:stop()
  assert(chainSounds:isPlaying() == false)
  chainSounds:stop()
end

test(testPlayStop)