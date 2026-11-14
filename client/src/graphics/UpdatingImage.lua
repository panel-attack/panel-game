local class = require("common.lib.class")
local AnimationLoader = require("client.src.graphics.AnimationLoader")
local Flux = require("client.lib.flux.flux")

-- Returns the track scrolling the property one whole image length at the speed, over and over, which looks seamless on a repeated image
---@param property string scrollX or scrollY
---@param speed number pixels a second, its sign the direction
---@param length number the image's length along the property
---@return table track
local function scrollTrack(property, speed, length)
  local distance = speed > 0 and length or -length
  return {
    ["repeat"] = "loop",
    steps = {{durationSeconds = length / math.abs(speed), easeType = "linear", animateProperties = {[property] = distance}}}
  }
end

-- Returns the animation data of the image's drawable
---@param image love.Texture
---@param tiled boolean whether the image repeats over its size at its own size instead of stretching to it
---@param speedX number pixels a second a tiled image scrolls to the left
---@param speedY number pixels a second a tiled image scrolls up
---@param width number the width it covers
---@param height number the height it covers
---@return table
local function drawableData(image, tiled, speedX, speedY, width, height)
  -- stretched from its top left corner, which stays at the origin, instead of around its center
  local data = {texture = image, size = {width = width, height = height}, pivot = "topLeft"}
  if tiled then
    data.wrap = "repeat"
    data.animationTracks = {}
    if speedX ~= 0 then
      data.animationTracks[#data.animationTracks + 1] = scrollTrack("scrollX", speedX, image:getWidth())
    end
    if speedY ~= 0 then
      data.animationTracks[#data.animationTracks + 1] = scrollTrack("scrollY", -speedY, image:getHeight())
    end
  end
  return data
end

-- An image drawn through the animation engine, stretched over its size, or tiled over it and scrolling at a constant speed
---@class UpdatingImage
---@field image love.Texture
---@field tweens table the flux group running the scroll
---@field drawables table[] the image's one drawable
---@overload fun(image: love.Texture, tiled: boolean, speedX: number?, speedY: number?, width: number?, height: number?): UpdatingImage
local UpdatingImage = class(
---@param self UpdatingImage
function(self, image, tiled, speedX, speedY, width, height)
  assert(image ~= nil)
  self.image = image
  self.tweens = Flux.group()
  local data = drawableData(image, tiled, speedX or 0, speedY or 0, width or image:getWidth(), height or image:getHeight())
  self.drawables = AnimationLoader.loadFromData("", {drawables = {data}}, self.tweens)
end)

-- Advances the scroll
---@param dt number seconds since the last update
function UpdatingImage:update(dt)
  self.tweens:update(dt)
end

function UpdatingImage:draw()
  AnimationLoader.drawDrawables(self.drawables)
end

return UpdatingImage
