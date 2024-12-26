local class = require("common.lib.class")
local util = require("common.lib.util")

---@class StageTrack
---@field normalMusic Music
---@field dangerMusic Music?
---@field currentMusic Music? holds the reference to the music currently being played (normal or danger)
---@field state string a human readable representation of which music currentMusic currently holds
---@field volumeMultiplier number Multiplier for the StageTrack's setVolume function

---@class StageTrack
---@overload fun(normalMusic: Music, dangerMusic: Music?, volumeMultiplier: number?): StageTrack
local StageTrack = class(
---@param stageTrack StageTrack
---@param normalMusic Music
---@param dangerMusic Music?
function(stageTrack, normalMusic, dangerMusic, volumeMultiplier)
  assert(normalMusic, "A stage track needs at least a normal music!")
  stageTrack.normalMusic = normalMusic
  stageTrack.dangerMusic = dangerMusic
  stageTrack.currentMusic = nil
  stageTrack.state = "normal"
  volumeMultiplier = volumeMultiplier or 1
  stageTrack.volumeMultiplier = util.bound(0, volumeMultiplier, 1)
end)

function StageTrack:changeMusic(useDangerMusic)
  if self.dangerMusic then
    local stateChanged = false
    if useDangerMusic then
      stateChanged = self.state == "normal"
      self.state = "danger"
    else
      stateChanged = self.state == "danger"
      self.state = "normal"
    end
    if stateChanged and self:isPlaying() then
      self.currentMusic:stop()
      self:play()
    end
  end
end

function StageTrack:update()
  if self.currentMusic then
    self.currentMusic:update()
  end
end

function StageTrack:play()
  if self.state == "normal" then
    self.currentMusic = self.normalMusic
  else
    self.currentMusic = self.dangerMusic
  end

  self.currentMusic:play()
end

function StageTrack:isPlaying()
  if self.currentMusic then
    return self.currentMusic:isPlaying()
  else
    return false
  end
end

function StageTrack:stop()
  self.normalMusic:stop()
  if self.dangerMusic then
    self.dangerMusic:stop()
  end

  self.currentMusic = nil
  self.state = "normal"
end

-- pauses the currently running music
function StageTrack:pause()
  if self.currentMusic then
    self.currentMusic:pause()
  end
end

-- sets the volume of the track in % relative to the configured music volume
function StageTrack:setVolume(volume)
  self.normalMusic:setVolume(volume * self.volumeMultiplier)
  if self.dangerMusic then
    self.dangerMusic:setVolume(volume * self.volumeMultiplier)
  end
end

-- returns the volume of the track in % relative to the configured music volume
function StageTrack:getVolume()
  return self.normalMusic:getVolume()
end

---@param volumeMultiplier number between 0 and 1
function StageTrack:setVolumeMultiplier(volumeMultiplier)
  volumeMultiplier = volumeMultiplier or 1
  self.volumeMultiplier = util.bound(0, volumeMultiplier, 1)
end

return StageTrack