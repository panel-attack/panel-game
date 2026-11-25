local class = require("common.lib.class")
local AnimationLoader = require("client.src.graphics.AnimationLoader")

-- Returns the track scrolling the property one whole image length on from where it is at the speed, over and over,
-- which looks seamless on a repeated image
---@param property string scrollX or scrollY
---@param speed number pixels a second, its sign the direction
---@param length number the image's length along the property
---@param from number where the scroll is now
---@return table track
local function scrollTrack(property, speed, length, from)
  local distance = speed > 0 and length or -length
  return {
    ["repeat"] = "loop",
    steps = {{durationSeconds = length / math.abs(speed), easeType = "linear", animateProperties = {[property] = from + distance}}}
  }
end

-- Returns the scrolls of a tiled image, each a property and its speed
---@param image love.Texture
---@param speedX number pixels a second a tiled image scrolls to the left
---@param speedY number pixels a second a tiled image scrolls up
---@return {property: string, speed: number, length: number}[]
local function scrollsOf(image, speedX, speedY)
  local scrolls = {}
  if speedX ~= 0 then
    scrolls[#scrolls + 1] = {property = "scrollX", speed = speedX, length = image:getWidth()}
  end
  if speedY ~= 0 then
    scrolls[#scrolls + 1] = {property = "scrollY", speed = -speedY, length = image:getHeight()}
  end
  return scrolls
end

-- An image drawn through the animation engine, stretched over its size, or tiled over it and scrolling at a constant speed.
-- The scroll runs on the animator of the scene showing it, so it only moves while that scene is shown.
---@class UpdatingImage
---@field image love.Texture
---@field drawables table[] the image's one drawable
---@field scrolls {property: string, speed: number, length: number}[] the scrolls of a tiled image, none for a stretched one
---@field animator Animator? the animator running the scroll
---@overload fun(image: love.Texture, tiled: boolean, speedX: number?, speedY: number?, width: number?, height: number?): UpdatingImage
local UpdatingImage = class(
---@param self UpdatingImage
function(self, image, tiled, speedX, speedY, width, height)
  assert(image ~= nil)
  self.image = image
  width = width or image:getWidth()
  height = height or image:getHeight()
  -- stretched from its top left corner, which stays at the origin, instead of around its center
  local data = {texture = image, size = {width = width, height = height}, pivot = "topLeft", wrap = tiled and "repeat" or nil}
  self.drawables = AnimationLoader.loadFromData("", {drawables = {data}})
  self.scrolls = tiled and scrollsOf(image, speedX or 0, speedY or 0) or {}
end)

-- Runs the scroll on the animator, carrying on from where it is when it moves from another animator
---@param animator Animator
function UpdatingImage:play(animator)
  if self.animator == animator then
    return
  end
  local drawable = self.drawables[1]
  if self.animator then
    self.animator:stop(drawable)
  end
  self.animator = animator
  for _, scroll in ipairs(self.scrolls) do
    AnimationLoader.playTrack(drawable, scrollTrack(scroll.property, scroll.speed, scroll.length, drawable[scroll.property]), animator)
  end
end

function UpdatingImage:draw()
  AnimationLoader.drawDrawables(self.drawables)
end

return UpdatingImage
