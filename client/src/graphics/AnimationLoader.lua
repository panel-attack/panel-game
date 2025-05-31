local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local FileUtils = require("client.src.FileUtils")
local Flux = require("client.lib.flux.flux")

-- A class that loads images from a animation file and sets up their animations.
---@class AnimationLoader
---@field [string] any
local AnimationLoader =
  class(
  function(self)
  end
)

function AnimationLoader.anchorOffset(drawable, anchor)
  local w, h = drawable.width, drawable.height
  local map = {
    topLeft={0,0}, topCenter={w/2,0}, topRight={w,0},
    centerLeft={0,h/2}, center={w/2,h/2}, centerRight={w,h/2},
    bottomLeft={0,h}, bottomCenter={w/2,h}, bottomRight={w,h}
  }
  return (map[anchor])[1], (map[anchor])[2]
end

local function buildTrackStep(target, track, currentStep, stepAmount)
  local step = track.steps[currentStep]
  local targetProperties
  if stepAmount > 0 then
    targetProperties = step.animateProperties
  else
    targetProperties = step.reverseProperties
  end
  local tween = Flux.to(target, step.durationSeconds,
                          targetProperties)

  -- Save off the previous properties on the track in case they are needed for looping or yoyo
  if stepAmount > 0 then
    tween:onstart(function ()
      step.reverseProperties = {}
      for k in pairs(step.animateProperties) do
        step.reverseProperties[k] = target[k]
      end
    end)
  end

  tween:ease(step.easeType):delay(step.delaySeconds or 0)

  tween:oncomplete(function()
    local nextStep = currentStep + stepAmount
    if nextStep < 1 or nextStep > #track.steps then
      if track.yoyo then
        -- start going throught the steps backwards
        stepAmount = stepAmount * -1
        nextStep = #track.steps
        if stepAmount > 0 then
          nextStep = 1
        end
      elseif track.loopTrack then
        nextStep = 1
        -- Reset to the first properties in reverse order in case some properties aren't covered by all steps
        for stepIndex = #track.steps, 1, -1 do
          for key, value in pairs(track.steps[stepIndex].reverseProperties) do
            target[key] = value
          end
        end
      end
    end

    if nextStep >= 1 and nextStep <= #track.steps then
      buildTrackStep(target, track, nextStep, stepAmount)
    end
  end)
end

local function loadNode(rootPath, node, parent, drawables)
  local obj = {
    id       = node.id,
    parent   = parent,
    x        = node.localPosition and node.localPosition.x or 0,
    y        = node.localPosition and node.localPosition.y or 0,
    width    = node.size and node.size.width or 0,
    height   = node.size and node.size.height or 0,
    rotation = node.initialRotation or 0,
    scale    = node.initialScale or 1,
    alpha    = node.alpha or 1,
    layer    = node.layer or 0,
    anchor   = node.anchor or "center",
    pivot    = node.pivot or "center",
    animationTracks = node.animationTracks or {}
  }
  if node.filePath then
    local texture = GraphicsUtil.loadImageFromSupportedExtensions(rootPath .. node.filePath)
    if texture then
      obj.texture = texture
      obj.width = texture:getWidth()
      obj.height = texture:getHeight()
    end
  end
  table.insert(drawables, obj)

  for _,track in ipairs(node.animationTracks or {}) do
    buildTrackStep(obj, track, 1, 1)
  end
  for _,child in ipairs(node.children or {}) do
    loadNode(rootPath, child, obj, drawables)
  end
end

function AnimationLoader.loadFromFile(rootPath, filePath)
  local results = {}
  local spriteData  = FileUtils.readJsonFile(filePath)
  loadNode(rootPath, spriteData, nil, results)
  table.sort(results, function(a,b) return a.layer < b.layer end)
  return results
end

local function objectTransform(obj)
  local ax, ay = AnimationLoader.anchorOffset(obj, obj.anchor)
  return obj.x - ax, obj.y - ay, obj.rotation, obj.scale
end

function AnimationLoader.worldTransform(obj)
  if not obj.parent then
    return objectTransform(obj)
  end
  local px, py, prot, pscale = AnimationLoader.worldTransform(obj.parent)
  local ox, oy, oprot, oscale = objectTransform(obj)
  return px + ox, py + oy, prot + oprot, pscale * oscale
end

return AnimationLoader