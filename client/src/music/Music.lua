local class = require("common.lib.class")
local musicThread = love.thread.newThread("client/src/music/PlayMusicThread.lua")

local function playSource(source)
  if musicThread:isRunning() then
    musicThread:wait()
  end
  musicThread:start(source)
end

---@class Music
---@operator call:Music
---@field package main love.Source looping source of the music
---@field package start love.Source? start source of the music
---@field package currentSource love.Source? source of the music that is currently being played
---@field package mainStartTime number? the time at which the main source is supposed to replace the start source
---@field package paused boolean if the music is currently paused

-- construct a music object with a looping `main` music and an optional `start` played as the intro
---@class Music
---@overload fun(main: love.Source, start: love.Source): Music
local Music = class(
---@param music Music
---@param main love.Source
---@param start love.Source
function(music, main, start)
  assert(main, "Music needs at least a main audio source!")
  music.main = main
  main:setLooping(true)
  music.start = start
  music.currentSource = nil
  music.mainStartTime = nil
  music.paused = false
end)

-- starts playing the music if it was not already playing
function Music:play()
  if not self.currentSource then
    if self.start then
      self.currentSource = self.start
    else
      self.currentSource = self.main
    end
  end

  if self.currentSource == self.start then
    local duration = self.start:getDuration()
    local position = self.start:tell()
    self.mainStartTime = love.timer.getTime() + duration - position
  end

  playSource(self.currentSource)
  self.paused = false
end

---@return boolean? # if the music is currently playing
function Music:isPlaying()
  return self.currentSource and self.currentSource:isPlaying()
end

-- stops the music and resets it (whether it was playing or not)
function Music:stop()
  self.currentSource = nil
  self.mainStartTime = nil
  self.paused = false
  self.main:stop()
  if self.start then
    self.start:stop()
  end
end

-- pauses the music
function Music:pause()
  self.paused = true
  if self.currentSource then
    self.currentSource:pause()
  end
end

---@return boolean # if the music is currently paused
function Music:isPaused()
  return self.paused
end

---@param volume number sets the volume of the source to a specific number
function Music:setVolume(volume)
  if self.start then
    self.start:setVolume(volume)
  end
  self.main:setVolume(volume)
end

---@return number volume
function Music:getVolume()
  return self.main:getVolume()
end

---@param loop boolean
function Music:setLooping(loop)
  self.main:setLooping(loop)
end

---@return boolean if the main music is currently looping
function Music:isLooping()
  return self.main:isLooping()
end

-- update the music to advance the timer
-- this is important to try and (roughly) get the transition from start to main right
function Music:update()
  if not self.paused then
    if self.start and self.currentSource == self.start then
      if self.mainStartTime - love.timer.getTime() < 0.007 then
        self.currentSource = self.main
        playSource(self.currentSource)
        self.mainStartTime = nil
      end
    end
  end
end

return Music