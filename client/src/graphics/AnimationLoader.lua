local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local FileUtils = require("client.src.FileUtils")
local Flux = require("client.lib.flux.flux")

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

-- A class that loads images from a animation file and sets up their animations.
---@class AnimationLoader
---@field [string] any
local AnimationLoader =
  class(
  function(self)
  end
)

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

local function loadNode(rootPath, node, parent)
  assert((node.size == nil or node.size.width == nil) or node.xScale == nil, "Node has both xScale and width set, pick only one way to specify the width")
  assert((node.size == nil or node.size.height == nil) or node.yScale == nil, "Node has both yScale and height set, pick only one way to specify the height")
  local obj = {
    id       = node.id,
    parent   = parent,
    x        = node.position and node.position.x or 0,
    y        = node.position and node.position.y or 0,
    width    = node.size and node.size.width,
    height   = node.size and node.size.height,
    rotation = node.rotation or 0,
    xScale    = node.xScale,
    yScale    = node.yScale,
    alpha    = node.alpha or 1,
    blendMode = node.blendMode or "alpha",
    alphaMode = node.alphaMode or "alphamultiply",
    stencil = node.stencil == true or false,
    tint     = node.tint or {1, 1, 1},
    anchor   = node.anchor or "topLeft",
    pivot    = node.pivot,
    animationTracks = node.animationTracks or {},
    ref = node.ref
  }
  if parent then
    parent.children[#parent.children+1] = obj
  end
  obj.children = {}
  if node.filePath then
    local texture = GraphicsUtil.loadImageFromSupportedExtensions(rootPath .. node.filePath)
    assert(texture, "couldn't load image for animation filepath " .. rootPath .. node.filePath)
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

      if node.wrap == "repeat" then
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
  for _,track in ipairs(node.animationTracks or {}) do
    buildTrackStep(obj, track, 1, 1)
  end
  for _,child in ipairs(node.children or {}) do
    -- Skip children marked as templateOnly unless they are references
    if child.ref ~= nil or not child.templateOnly then
      loadNode(rootPath, child, obj)
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

function AnimationLoader.resolveNodeReference(nodeTable, idLookupTable, filePath, rootPath)
    local sourceNode = idLookupTable[nodeTable.ref]

    if sourceNode == nil then
        sourceNode = idLookupTable[nodeTable.id]
    end
    
    if sourceNode == nil then
        error("Unknown ref: " .. tostring(nodeTable.ref))
    end

    local clonedNode = AnimationLoader.cloneNodeWithOverrides(
        sourceNode,
        nodeTable.overrides
    )

    local originalRef = nodeTable.ref
    
    for key in pairs(nodeTable) do
        nodeTable[key] = nil
    end

    for key, value in pairs(clonedNode) do
        nodeTable[key] = value
    end
    
    if originalRef then
        nodeTable.ref = originalRef
        nodeTable.templateOnly = nil
    end
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
            AnimationLoader.resolveNodeReference(nodeTable, idLookupTable, filePath, rootPath)
        end
    end

    if nodeTable.children ~= nil then
        for _, childNode in ipairs(nodeTable.children) do
            AnimationLoader.resolveRefsRecursively(childNode, loadedFileTables, idLookupTable, visitedTables, filePath, rootPath)
        end
    end
end

-- Loads all drawables for a animation file.
-- First all files are loaded from JSON and indexed
-- Then all references are resolved.
-- Finally once the full data structure is setup, it is converted into separate drawable objects.
function AnimationLoader.loadFromFile(rootPath, filePath)
  local loadedFileTables = {}   -- filePath → parsed table
  local idLookupTable   = {}    -- "id" → node table

  AnimationLoader.readFileAndCollectIdsRecursively(filePath, loadedFileTables, idLookupTable)

  local rootSceneTable = loadedFileTables[filePath]

  for _, drawable in ipairs(rootSceneTable.drawables) do
    AnimationLoader.resolveRefsRecursively(drawable, loadedFileTables, idLookupTable, {}, filePath, rootPath)
  end

  local results = {}
  if rootSceneTable then
    for _, data in ipairs(rootSceneTable.drawables) do
      -- Skip elements marked as templateOnly unless they are references
      if data.ref ~= nil or not data.templateOnly then
        results[#results+1] = loadNode(rootPath, data, nil)
      end
    end
  end
  return results
end

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
        assert(d.parent, "To use a stencil you need siblings")
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