local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local FileUtils = require("client.src.FileUtils")
local Flux = require("client.lib.flux.flux")

-- A class that loads a heirarchy of images and animations from an animation file and returns the drawable objects. Animations are setup to update with the flux engine.
---@class AnimationLoader
local AnimationLoader =
  class(
  function(self)
  end
)

-- Returns the offset to apply for the drawable and it's given anchor.
function AnimationLoader.anchorOffset(drawable, anchor)
  if anchor == "topLeft" then
    return 0, 0
  end

  local w, h = drawable.width, drawable.height

  if anchor == "topCenter" then
    return w/2, 0
  elseif anchor == "topRight" then
    return w, 0
  elseif anchor == "centerLeft" then
    return 0, h/2
  elseif anchor == "center" then
    return w/2, h/2
  elseif anchor == "centerRight" then
    return w, h/2
  elseif anchor == "bottomLeft" then
    return 0, h
  elseif anchor == "bottomCenter" then
    return w/2, h
  elseif anchor == "bottomRight" then
    return w, h
  else
    return 0, 0  -- fallback to topLeft
  end
end

-- Builds the flux animation for the given track step on the target
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
  target.fluxTweens[#target.fluxTweens+1] = tween

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

-- Loads one drawable from the given file directory root and the given animation data.
-- @return table the drawable or nil if it didn't need to be loaded
local function loadDrawables(rootPath, animationData)
  if animationData.ref == nil and animationData.templateOnly then
    -- Skip templateOnly items unless they are references
    return nil
  end

  assert((animationData.size == nil or animationData.size.width == nil) or animationData.xScale == nil, "Node has both xScale and width set, pick only one way to specify the width")
  assert((animationData.size == nil or animationData.size.height == nil) or animationData.yScale == nil, "Node has both yScale and height set, pick only one way to specify the height")
  local obj = {
    id = animationData.id,
    x = animationData.position and animationData.position.x or 0,
    y = animationData.position and animationData.position.y or 0,
    width = animationData.size and animationData.size.width,
    height = animationData.size and animationData.size.height,
    rotation = animationData.rotation or 0,
    xScale = animationData.xScale,
    yScale = animationData.yScale,
    alpha = animationData.alpha or 1,
    blendMode = animationData.blendMode or "alpha",
    alphaMode = animationData.alphaMode or "alphamultiply",
    stencil = animationData.stencil == true or false,
    tint = animationData.tint or {1, 1, 1},
    anchor = animationData.anchor or "topLeft",
    pivot = animationData.pivot,
    animationTracks = animationData.animationTracks or {},
    originalRef = animationData.originalRef
  }
  obj.children = {}
  if animationData.filePath then
    local texture = GraphicsUtil.loadImageFromSupportedExtensions(rootPath .. animationData.filePath)
    assert(texture, "couldn't load image for animation filepath " .. rootPath .. animationData.filePath)
    if texture then
      obj.texture = texture
      local textureWidth = texture:getWidth()
      local textureHeight = texture:getHeight()
      if obj.width then
        obj.xScale = obj.width / textureWidth
      end
      obj.width = textureWidth
      if obj.height then
        obj.yScale = obj.height / textureHeight
      end
      obj.height = textureHeight

      if animationData.wrap == "repeat" then
        obj.scrollX = 0
        obj.scrollY = 0
        obj.texture:setWrap("repeat", "repeat")
        obj.quad = love.graphics.newQuad(obj.scrollX, obj.scrollY, obj.width, obj.height, obj.width, obj.height)
      end
    end
  end

  if obj.pivot == nil then
    if obj.texture then
      obj.pivot = "center"
    else
      obj.pivot = "topLeft" -- Allows containers to work if they don't set height and width
    end
  end

  if obj.xScale == nil then
    obj.xScale = 1
  end
  if obj.yScale == nil then
    obj.yScale = 1
  end

  assert(obj.anchor == "topLeft" or obj.width > 0 and obj.height > 0, "Objects must have width and height if you have a non top left anchor")
  assert(obj.pivot == "topLeft" or obj.width > 0 and obj.height > 0, "Objects must have width and height if you have a non top left pivot")

  obj.fluxTweens = {}
  for _,track in ipairs(animationData.animationTracks or {}) do
    buildTrackStep(obj, track, 1, 1)
  end
  for _, childData in ipairs(animationData.children or {}) do
    local drawable = loadDrawables(rootPath, childData)
    if drawable then
      obj.children[#obj.children+1] = drawable
    end
  end

  return obj
end

function AnimationLoader.applyOverridesRecursively(destinationTable, overridesTable)
    for key, overrideValue in pairs(overridesTable) do
        local destinationValue = destinationTable[key]

        if type(overrideValue) == "table"
        and type(destinationValue) == "table" then
            AnimationLoader.applyOverridesRecursively(destinationValue, overrideValue)
        else
            destinationTable[key] = overrideValue
        end
    end
end

function AnimationLoader.cloneNodeWithOverrides(sourceNode, overridesTable)
    assert(sourceNode and sourceNode.id)
    local clonedNode = deepcpy(sourceNode)

    if overridesTable ~= nil then
        AnimationLoader.applyOverridesRecursively(clonedNode, overridesTable)
    end

    return clonedNode
end

-- Loads all files referenced and records a map of ID's to their nodes
function AnimationLoader.indexNodesRecursively(nodeTable, filePath, idLookupTable, loadedFileTables)
    if nodeTable.ref ~= nil and nodeTable.ref:match("%.json$") then
      local directoryPart = filePath:match("(.*/)") or ""
      local referencedFilePath = directoryPart .. nodeTable.ref
      AnimationLoader.readFileAndCollectIdsRecursively(referencedFilePath, loadedFileTables, idLookupTable)
    end
    if nodeTable.id ~= nil then
        local qualifiedId = nodeTable.id

        if idLookupTable[qualifiedId] ~= nil then
            error("Duplicate id detected: " .. qualifiedId)
        end

        idLookupTable[qualifiedId] = nodeTable
    end

    if nodeTable.children ~= nil then
        for _, childNode in ipairs(nodeTable.children) do
            AnimationLoader.indexNodesRecursively(childNode, filePath, idLookupTable, loadedFileTables)
        end
    end
end

function AnimationLoader.readFileAndCollectIdsRecursively(filePath, loadedFileTables, idLookupTable)
    if loadedFileTables[filePath] ~= nil then
        return
    end

    local sceneTable  = FileUtils.readJsonFile(filePath)

    sceneTable.filePath = filePath
    loadedFileTables[filePath] = sceneTable

    if sceneTable then
      if sceneTable.drawables ~= nil then
          for _, drawableNode in ipairs(sceneTable.drawables) do
              AnimationLoader.indexNodesRecursively(drawableNode, filePath, idLookupTable, loadedFileTables)
          end
      end
    end
end

-- Changes the nodeTable so it has all the same properties as the reference with overrides applied. Recursive.
function AnimationLoader.resolveNodeReference(nodeTable, idLookupTable)
    if nodeTable.ref == nil then
      return -- nothing to resolve
    end

    local originalRef = nodeTable.ref
    local sourceNode = idLookupTable[originalRef]
    
    if sourceNode == nil then
        error("Unknown ref: " .. tostring(originalRef))
    end

    -- Validate the reference doesn't have invalid keys, the user likely intended overrides.
    for key in pairs(nodeTable) do
      assert(key == "id" or
      key == "ref" or
      key == "overrides" or
      key == "templateOnly", "Reference has unexpected key " .. key .. " did you mean to override instead?")
    end

    if sourceNode.ref then
      AnimationLoader.resolveNodeReference(sourceNode, idLookupTable)
    end

    local clonedNode = AnimationLoader.cloneNodeWithOverrides(
        sourceNode,
        nodeTable.overrides
    )
    clonedNode.id = nodeTable.id

    for key, value in pairs(clonedNode) do
      if key ~= "templateOnly" then
        nodeTable[key] = value
      end
    end
    nodeTable.overrides = nil
    nodeTable.ref = nil
    nodeTable.originalRef = originalRef
    
end

function AnimationLoader.resolveRefsRecursively(nodeTable, loadedFileTables, idLookupTable, visitedTables, filePath, rootPath)
    if type(nodeTable) ~= "table" then
        return
    end

    if visitedTables[nodeTable] ~= nil then
        error("Circular ref detected at " .. tostring(nodeTable.ref))
    end

    visitedTables[nodeTable] = true

    if nodeTable.ref ~= nil then

        -- Check if this is a file reference (ends with .json)
        if nodeTable.ref:match("%.json$") then
            local directoryPart = filePath:match("(.*/)") or ""
            local referencedFilePath = directoryPart .. nodeTable.ref
            local referencedFileTable = loadedFileTables[referencedFilePath]

            nodeTable.ref = nil
            nodeTable.children = referencedFileTable.drawables
            -- fall through to children now
        else
            AnimationLoader.resolveNodeReference(nodeTable, idLookupTable)
        end
    end

    if nodeTable.children ~= nil then
        for _, childNode in ipairs(nodeTable.children) do
            AnimationLoader.resolveRefsRecursively(childNode, loadedFileTables, idLookupTable, visitedTables, filePath, rootPath)
        end
    end
end

-- Loads all drawables for a animation file.
-- @param rootPath String the full directory to the file to load
-- @param fillPath String just the file name part of the file to load
-- @return table an array of drawables representing all the objects with flux animations setup
function AnimationLoader.loadFromFile(rootPath, filePath)
  local loadedFileTables = {}   -- filePath → parsed table
  local idLookupTable   = {}    -- "id" → node table

  -- First all files are loaded from JSON and indexed
  AnimationLoader.readFileAndCollectIdsRecursively(filePath, loadedFileTables, idLookupTable)

  local rootData = loadedFileTables[filePath]

  -- Then all references are resolved with overrides applied
  for _, drawable in ipairs(rootData.drawables) do
    AnimationLoader.resolveRefsRecursively(drawable, loadedFileTables, idLookupTable, {}, filePath, rootPath)
  end

  -- Finally once the full data structure is setup, it is converted into separate drawable objects.
  local drawables = {}
  if rootData then
    for _, data in ipairs(rootData.drawables) do
      local drawable = loadDrawables(rootPath, data)
      if drawable then
        drawables[#drawables+1] = drawable
      end
    end
  end
  return drawables
end

function AnimationLoader.stopFluxTweensOnDrawable(drawable)
    for _, tween in ipairs(drawable.fluxTweens) do
      tween:stop()
    end
    for _, child in ipairs(drawable.children) do
      AnimationLoader.stopFluxTweensOnDrawable(child)
    end
end

-- DRAWING CODE

-- Shader used for clipping using a stencil pass
local alphaDiscardShader = love.graphics.newShader([[
    vec4 effect(vec4 tintColor, Image tex, vec2 texCoord, vec2 screenCoord)
    {
        vec4 pixelColor = Texel(tex, texCoord);

        if (pixelColor.a * tintColor.a <= 0.0)
        {
            discard;
        }

        return vec4(0.0);
    }
]])

function AnimationLoader.objectTransform(obj)
  local ax, ay = AnimationLoader.anchorOffset(obj, obj.anchor)
  return obj.x - ax, obj.y - ay, obj.rotation, obj.xScale, obj.yScale
end


function AnimationLoader.drawNode(d, parent)
    love.graphics.push("all")

    local px, py = AnimationLoader.anchorOffset(d, d.pivot)
    local wx, wy, wrot, xScale, yScale = AnimationLoader.objectTransform(d)

    love.graphics.translate(wx, wy)

    love.graphics.translate(px, py)
    love.graphics.rotate(wrot)
    love.graphics.scale(xScale, yScale)
    love.graphics.translate(-px, -py)

    if d.texture then
      if d.stencil then
        assert(parent, "To use a stencil you need siblings")
        love.graphics.stencil(function()
          love.graphics.setShader(alphaDiscardShader)
          for _, sibling in ipairs(parent.children) do
            if sibling == d then
              break
            end
            AnimationLoader.drawNode(sibling, nil)
          end
          love.graphics.setShader()
        end, "replace", 1, false)
        love.graphics.setStencilTest("equal", 1)
      end

      love.graphics.setBlendMode(d.blendMode, d.alphaMode)
      love.graphics.setColor(d.tint[1], d.tint[2], d.tint[3], d.alpha)
      if d.quad then
        d.quad:setViewport(d.scrollX, d.scrollY, d.width, d.height)
        love.graphics.draw(d.texture, d.quad, 0, 0)
      else
        love.graphics.draw(d.texture, 0, 0)
      end
      love.graphics.setStencilTest()
    end

    for _, child in ipairs(d.children) do
      AnimationLoader.drawNode(child, d)
    end

    love.graphics.pop()
end

return AnimationLoader