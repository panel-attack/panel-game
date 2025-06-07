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

local function loadNode(rootPath, node, parent)
  local obj = {
    id       = node.id,
    parent   = parent,
    x        = node.position and node.position.x or 0,
    y        = node.position and node.position.y or 0,
    width    = node.size and node.size.width or 0,
    height   = node.size and node.size.height or 0,
    rotation = node.rotation or 0,
    scale    = node.scale or 1,
    alpha    = node.alpha or 1,
    blendMode = node.blendMode or "alpha",
    alphaMode = node.alphaMode or "alphamultiply",
    stencil = node.stencil == true or false,
    tint     = node.tint or {1, 1, 1},
    anchor   = node.anchor or "topLeft",
    pivot    = node.pivot or "center",
    animationTracks = node.animationTracks or {}
  }
  if parent then
    parent.children[#parent.children+1] = obj
  end
  obj.children = {}
  if node.filePath then
    local texture = GraphicsUtil.loadImageFromSupportedExtensions(rootPath .. node.filePath)
    if texture then
      obj.texture = texture
      obj.width = texture:getWidth()
      obj.height = texture:getHeight()
      if node.wrap == "repeat" then
        obj.scrollX = 0
        obj.scrollY = 0
        obj.texture:setWrap("repeat", "repeat")
        obj.texture:setFilter("nearest", "nearest")
        obj.quad = love.graphics.newQuad(obj.scrollX, obj.scrollY, obj.width, obj.height, obj.width, obj.height)
      end
    end
  end

  for _,track in ipairs(node.animationTracks or {}) do
    buildTrackStep(obj, track, 1, 1)
  end
  for _,child in ipairs(node.children or {}) do
    loadNode(rootPath, child, obj)
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
    local clonedNode = deepcpy(sourceNode)

    if overridesTable ~= nil then
        AnimationLoader.applyOverridesRecursively(clonedNode, overridesTable)
    end

    return clonedNode
end

function AnimationLoader.indexNodesRecursively(nodeTable, filePath, idLookupTable)
    if nodeTable.id ~= nil then
        local qualifiedId = filePath .. "#" .. nodeTable.id

        if idLookupTable[qualifiedId] ~= nil then
            error("Duplicate id detected: " .. qualifiedId)
        end

        idLookupTable[qualifiedId] = nodeTable
    end

    if nodeTable.children ~= nil then
        for _, childNode in ipairs(nodeTable.children) do
            AnimationLoader.indexNodesRecursively(childNode, filePath, idLookupTable)
        end
    end
end

function AnimationLoader.readFileAndCollectIds(filePath, loadedFileTables, idLookupTable)
    if loadedFileTables[filePath] ~= nil then
        return
    end

    local sceneTable  = FileUtils.readJsonFile(filePath)

    sceneTable.filePath = filePath
    loadedFileTables[filePath] = sceneTable

    if sceneTable then
      if sceneTable.drawables ~= nil then
          for _, drawableNode in ipairs(sceneTable.drawables) do
              AnimationLoader.indexNodesRecursively(drawableNode, filePath, idLookupTable)
          end
      end

      if sceneTable.imports ~= nil then
          local directoryPart = filePath:match("(.*/)") or ""

          for _, relativePath in ipairs(sceneTable.imports) do
              local fullImportPath = directoryPart .. relativePath
              AnimationLoader.readFileAndCollectIds(fullImportPath, loadedFileTables, idLookupTable)
          end
      end
    end
end

function AnimationLoader.resolveRefsRecursively(nodeTable, idLookupTable, visitedTables, filePath, rootPath)
    if type(nodeTable) ~= "table" then
        return
    end

    if nodeTable.ref ~= nil then
        if visitedTables[nodeTable] ~= nil then
            error("Circular ref detected at " .. tostring(nodeTable.ref))
        end

        visitedTables[nodeTable] = true

        local sourceNode = idLookupTable[rootPath .. "#" .. nodeTable.ref]

        if sourceNode == nil then
          sourceNode = idLookupTable[filePath .. "#" .. nodeTable.ref]
        end

        if sourceNode == nil then
            error("Unknown ref: " .. tostring(nodeTable.ref))
        end

        local clonedNode = AnimationLoader.cloneNodeWithOverrides(
            sourceNode,
            nodeTable.overrides
        )

        for key in pairs(nodeTable) do
            nodeTable[key] = nil
        end

        for key, value in pairs(clonedNode) do
            nodeTable[key] = value
        end
    end

    if nodeTable.children ~= nil then
        for _, childNode in ipairs(nodeTable.children) do
            AnimationLoader.resolveRefsRecursively(childNode, idLookupTable, visitedTables)
        end
    end
end

function AnimationLoader.loadScene(rootFilePath)
    local loadedFileTables = {}   -- filePath → parsed table
    local idLookupTable   = {}    -- "file#id" → node table

    AnimationLoader.readFileAndCollectIds(rootFilePath, loadedFileTables, idLookupTable)

    local rootSceneTable = loadedFileTables[rootFilePath]

    AnimationLoader.resolveRefsRecursively(rootSceneTable, idLookupTable, {})

    return rootSceneTable
end

function AnimationLoader.loadFromFile(rootPath, filePath)
  local loadedFileTables = {}   -- filePath → parsed table
  local idLookupTable   = {}    -- "file#id" → node table

  AnimationLoader.readFileAndCollectIds(filePath, loadedFileTables, idLookupTable)

  local rootSceneTable = loadedFileTables[filePath]

  for _, drawable in ipairs(rootSceneTable.drawables) do
    AnimationLoader.resolveRefsRecursively(drawable, idLookupTable, {}, filePath, rootPath)
  end

  local results = {}
  if rootSceneTable then
    for _, data in ipairs(rootSceneTable.drawables) do
      results[#results+1] = loadNode(rootPath, data, nil)
    end
  end
  return results
end

function AnimationLoader.objectTransform(obj)
  local ax, ay = AnimationLoader.anchorOffset(obj, obj.anchor)
  return obj.x - ax, obj.y - ay, obj.rotation, obj.scale
end


function AnimationLoader.drawNode(d, parent)
    love.graphics.push("all")

    local px, py = AnimationLoader.anchorOffset(d, d.pivot)
    local wx, wy, wrot, wscale = AnimationLoader.objectTransform(d)

    love.graphics.translate(wx, wy)

    love.graphics.translate(px, py)
    love.graphics.rotate(wrot)
    love.graphics.scale(wscale, wscale)
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