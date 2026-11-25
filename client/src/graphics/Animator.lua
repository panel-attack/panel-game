local class = require("common.lib.class")
local Flux = require("client.lib.flux.flux")

-- Runs tracks, properties of a target changing over time, on its owner's clock: they move only while the owner updates it.
-- A scene's animator runs everything the scene shows and the notification center's runs the notifications.
---@class Animator
---@field tweens table the flux group holding the running tracks, which no one else touches
---@overload fun(): Animator
local Animator = class(
---@param self Animator
function(self)
  self.tweens = Flux.group()
end)

-- Starts a track taking the target's properties to the given values, returning it to ease, delay or chain
---@param target table
---@param seconds number
---@param properties table<string, number> the values the properties end at
---@return table track the flux tween
function Animator:to(target, seconds, properties)
  return self.tweens:to(target, seconds, properties)
end

-- Runs one track on by the given seconds, for a track that starts part way through an update
---@param track table a track this animator runs
---@param seconds number
function Animator:advance(track, seconds)
  self.tweens:advance(track, seconds)
end

-- Runs every track on by the given seconds
---@param dt number seconds since the last update
function Animator:update(dt)
  self.tweens:update(dt)
end

-- Ends every track on the target where it is, without finishing it, so nothing chained after it starts
---@param target table
function Animator:stop(target)
  local tracks = self.tweens[target]
  if not tracks then
    return
  end
  for track in pairs(tracks) do
    track:stop()
  end
end

return Animator
