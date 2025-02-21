local class = require("common.lib.class")
local musicThread = love.thread.newThread("client/src/music/PlayMusicThread.lua")
local FileUtils = require("client.src.FileUtils")
local logger = require("common.lib.logger")

local function playSource(source)
  if musicThread:isRunning() then
    musicThread:wait()
  end
  musicThread:start(source)
end

local BUFFER_SIZE = 4096
local BUFFER_COUNT = 32

---@class Music
---@operator call:Music
---@field package mainDecoder love.Decoder
---@field package startData love.SoundData? start source of the music
---@field package paused boolean? if the music is currently playing (false), paused (true) or stopped (nil)
---@field package queueableSource love.Source
---@field path string?
---@field mainFilename string?
---@field startFilename string?

-- construct a music object with a looping `main` music and an optional `start` played as the intro
-- the music is streamed via a queueable source 
---@class Music
---@overload fun(main: love.Decoder, start: love.SoundData?): Music
local Music = class(
---@param music Music
---@param mainDecoder love.Decoder
---@param startData love.SoundData?
function(music, mainDecoder, startData)
  music.mainDecoder = mainDecoder
  music.startData = startData
  -- with the default buffer count of 8, in some scenarios the music would end prematurely due to Music:update not being called frequently enough
  music.queueableSource = love.audio.newQueueableSource(mainDecoder:getSampleRate(), mainDecoder:getBitDepth(), mainDecoder:getChannelCount(), BUFFER_COUNT)
end)

Music.TYPE = "Music"
Music.buffersize = 4096

function Music:buffer()
  local freeBufferCount = self.queueableSource:getFreeBufferCount()
  for i = 1, freeBufferCount do
    local chunk = self.mainDecoder:decode()
    if not chunk then
      self.mainDecoder:seek(0)
      chunk = self.mainDecoder:decode()
    end
    self.queueableSource:queue(chunk)
  end
end

-- starts playing the music if it was not already playing
function Music:play()
  if self.paused == nil and self.startData then
    self.queueableSource:queue(self.startData)
  end
  self:buffer()

  logger.debug("playing " .. (self.path or "Unknown") .. "/" .. (self.mainFilename or "Unknown"))

  playSource(self.queueableSource)
  self.paused = false
end

---@return boolean? # if the music is currently playing
function Music:isPlaying()
  return self.paused == false
end

-- stops the music and resets it (whether it was playing or not)
function Music:stop()
  logger.debug("stopped " .. (self.path or "Unknown") .. "/" .. (self.mainFilename or "Unknown"))
  self.paused = nil
  self.queueableSource:stop()
  self.mainDecoder:seek(0)
end

-- pauses the music
function Music:pause()
  self.paused = true
  self.queueableSource:pause()
end

---@return boolean # if the music is currently paused
function Music:isPaused()
  return self.paused
end

---@param volume number sets the volume of the source to a specific number
function Music:setVolume(volume)
  self.queueableSource:setVolume(volume)
end

---@return number volume
function Music:getVolume()
  return self.queueableSource:getVolume()
end

function Music:update()
  if self.paused == false then
    self:buffer()
    -- on very long frames it could happen that the music runs out of buffers and stopped due to that even though we never intended to stop the music
    if not self.queueableSource:isPlaying() and not musicThread:isRunning() then
      -- in that case, resume playing rather than starting over
      logger.debug("Resumed music play after interrupt")
      playSource(self.queueableSource)
    end
  end
end

---@param path string
---@param name string
---@return Music?
function Music.load(path, name)
  local startData
  local startName = FileUtils.getSoundFileName(name .. "_start", path)
  local mainName = FileUtils.getSoundFileName(name, path)

  if not mainName then
    return
  end

  if startName then
    startData = FileUtils.loadSoundData(path, startName)
  end

  local mainDecoder = love.sound.newDecoder(path .. "/" .. mainName, BUFFER_SIZE)

  if startData then
    if mainDecoder:getSampleRate() ~= startData:getSampleRate() or mainDecoder:getBitDepth() ~= startData:getBitDepth() or mainDecoder:getChannelCount() ~= startData:getChannelCount() then
      error("Failed to load music " .. name .. " for " .. path .. ":\n"
      .. "Sample rate, bit depth or channel count are different between " .. startName .. " and " .. mainName)
    end
  end

  local duration = mainDecoder:getDuration()
  if duration > 0 and duration < 3 then
    error("Failed to load music " .. mainName .. " for " .. path .. ":\n"
    .. "The looping portion of music has to be at least 3 seconds long")
  end

  local m = Music(mainDecoder, startData)
  m.path = path
  m.mainFilename = mainName
  m.startFilename = startName
  return m
end

return Music