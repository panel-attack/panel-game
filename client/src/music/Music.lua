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

---@class Music
---@operator call:Music
---@field package main love.SoundData looping source of the music
---@field package start love.SoundData? start source of the music
---@field package mainStartTime number? the time at which the main source is supposed to replace the start source
---@field package paused boolean if the music is currently paused
---@field package queueableSource love.Source
---@field package loopDuration number in seconds
---@field package timeStarted number in seconds for love.timer.getTime
---@field package loopsQueued integer
---@field package sourceDuration number
---@field path string?
---@field mainFilename string?
---@field startFilename string?

-- construct a music object with a looping `main` music and an optional `start` played as the intro
---@class Music
---@overload fun(main: love.SoundData, start: love.SoundData): Music
local Music = class(
---@param music Music
---@param main love.SoundData
---@param start love.SoundData
function(music, main, start)
  assert(main, "Music needs at least a main audio!")

  music.main = main
  music.start = start
  music.loopDuration = main:getDuration()
  music.mainStartTime = nil
  music.queueableSource = love.audio.newQueueableSource(main:getSampleRate(), main:getBitDepth(), main:getChannelCount(), 2)
  music.queueableSource:stop()

  music.timeStarted = 0
  music.loopsQueued = 1
  music.sourceDuration = 0
  music.paused = false
end)

-- starts playing the music if it was not already playing
function Music:play()
  if not self.queueableSource:isPlaying() and not self.paused then
    if self.start then
      self.queueableSource:queue(self.start)
      self.sourceDuration = self.sourceDuration + self.start:getDuration()
    end
    self.queueableSource:queue(self.main)
    self.loopsQueued = 1
    self.sourceDuration = self.sourceDuration + self.loopDuration
  end

  logger.debug("playing " .. (self.path or "Unknown") .. "/" .. (self.mainFilename or "Unknown"))

  self.timeStarted = love.timer.getTime()
  playSource(self.queueableSource)
  self.paused = false
end

---@return boolean? # if the music is currently playing
function Music:isPlaying()
  return self.queueableSource:isPlaying()
end

-- stops the music and resets it (whether it was playing or not)
function Music:stop()
  self.paused = false
  self.sourceDuration = 0
  self.loopsQueued = 0
  self.queueableSource:stop()
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

-- update the music to advance the timer
-- this is important to try and (roughly) get the transition from start to main right
function Music:update()
  local timePlaying = love.timer.getTime() - self.timeStarted
  local assumedSourceLength = (self.loopDuration * self.loopsQueued)
  if self.start then
    assumedSourceLength = assumedSourceLength + self.start:getDuration()
  end

  if assumedSourceLength - timePlaying < 2 then
    self.queueableSource:queue(self.main)
    self.loopsQueued = self.loopsQueued + 1
  end
end

---@param path string
---@param filename string
---@return Music?
function Music.load(path, filename)
  local main, mainFilename = FileUtils.loadSoundDataFromSupportedExtensions(path, filename)
  local start, startFilename = FileUtils.loadSoundDataFromSupportedExtensions(path, filename .. "_start")

  if main then
    if start then
      if main:getSampleRate() ~= start:getSampleRate() or main:getBitDepth() ~= start:getBitDepth() or main:getChannelCount() ~= start:getChannelCount() then
        error("Failed to load music " .. filename .. " for " .. path .. ":\n"
        .. "Sample rate, bit depth or channel count are different between " .. startFilename .. " and " .. mainFilename)
      end
    end

    if main:getDuration() < 3 then
      error("Failed to load music " .. mainFilename .. " for " .. path .. ":\n"
      .. "The looping portion of music has to be at least 3 seconds long")
    end

    local m = Music(main, start)
    m.path = path
    m.mainFilename = mainFilename
    m.startFilename = startFilename
    return m
  end
end

return Music