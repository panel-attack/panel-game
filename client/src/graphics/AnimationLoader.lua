local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local FileUtils = require("client.src.FileUtils")
local TextureAtlas = require("client.src.graphics.TextureAtlas")
local AnimationBaker = require("client.src.graphics.AnimationBaker")

-- A class that loads a heirarchy of images and animations from an animation file and returns the drawable objects.
-- Their tracks run on the animator passed in, so they only move while its owner updates it.
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

-- The ways a track can repeat once it has played all its steps
local TRACK_REPEATS = {none = true, loop = true, yoyo = true}

-- Errors if the track's repeat isn't one of TRACK_REPEATS, it still uses the old loopTrack or yoyo booleans,
-- or it repeats without taking any time, which would start it over forever within one update
local function validateTrackRepeat(track)
  if track.loopTrack ~= nil or track.yoyo ~= nil then
    error("Animation tracks repeat with \"repeat\": \"loop\" or \"yoyo\" instead of loopTrack or yoyo")
  end
  if track["repeat"] ~= nil and not TRACK_REPEATS[track["repeat"]] then
    error("Unknown track repeat " .. tostring(track["repeat"]) .. ", use \"none\", \"loop\" or \"yoyo\"")
  end
  if track["repeat"] == "loop" or track["repeat"] == "yoyo" then
    local seconds = 0
    for _, step in ipairs(track.steps) do
      seconds = seconds + (step.durationSeconds or 0) + (step.delaySeconds or 0)
    end
    if seconds <= 0 then
      error("A repeating animation track takes no time, give one of its steps a duration")
    end
  end
end

-- Builds the given track step on the target in the given animator
---@param animator Animator the animator the step runs on
---@param carriedSeconds number? the time the previous step's last update ran past its end, which this step spends on that same update
local function buildTrackStep(target, track, currentStep, stepAmount, animator, carriedSeconds)
  local step = track.steps[currentStep]
  local targetProperties
  if stepAmount > 0 then
    targetProperties = step.animateProperties
  else
    targetProperties = step.reverseProperties
  end
  local tween = animator:to(target, step.durationSeconds, targetProperties)

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
      if track["repeat"] == "yoyo" then
        -- start going throught the steps backwards
        stepAmount = stepAmount * -1
        nextStep = #track.steps
        if stepAmount > 0 then
          nextStep = 1
        end
      elseif track["repeat"] == "loop" then
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
      buildTrackStep(target, track, nextStep, stepAmount, animator, tween.overshoot)
    end
  end)

  if carriedSeconds then
    animator:advance(tween, carriedSeconds)
  end
end

-- Starts the track on the target in the animator, from its first step
---@param target table the drawable whose properties the track changes
---@param track table the track as an animation file writes it
---@param animator Animator
function AnimationLoader.playTrack(target, track, animator)
  validateTrackRepeat(track)
  buildTrackStep(target, track, 1, 1, animator)
end

-- Stops the tracks of the drawables and their children in the animator, for drawables that are no longer drawn
---@param drawables table[]
---@param animator Animator
function AnimationLoader.stopTracks(drawables, animator)
  for _, drawable in ipairs(drawables) do
    animator:stop(drawable)
    AnimationLoader.stopTracks(drawable.children, animator)
  end
end

-- Returns the image for the given path, loading it only the first time so every node drawing it shares one texture and LÖVE can batch them.
-- Wrap is state on the image itself, so one file can't be used both repeated and clamped.
---@param images table<string, {texture: love.Texture, wrap: string}> the images already loaded for this file by path
---@param path string the image path without extension
---@param wrap string "clamp" or "repeat"
---@return love.Texture
local function loadSharedImage(images, path, wrap)
  local loaded = images[path]
  if loaded then
    if loaded.wrap ~= wrap then
      error("The image " .. path .. " is used with both " .. loaded.wrap .. " and " .. wrap .. " wrap, use one wrap per image")
    end
    return loaded.texture
  end

  local texture = GraphicsUtil.loadImageFromSupportedExtensions(path)
  assert(texture, "couldn't load image for animation filepath " .. path)
  if wrap == "repeat" then
    texture:setWrap("repeat", "repeat")
  end
  images[path] = {texture = texture, wrap = wrap}
  return texture
end

-- Loads one drawable from the given file directory root and the given animation data.
-- @return table the drawable or nil if it didn't need to be loaded
---@param animator Animator? the animator the node's tracks run on, needed only when it has tracks
---@param images table the images already loaded for this file, see loadSharedImage
local function loadDrawables(rootPath, animationData, animator, images)
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
  local texture = animationData.texture
  if animationData.filePath then
    texture = loadSharedImage(images, rootPath .. animationData.filePath, animationData.wrap or "clamp")
  elseif texture and animationData.wrap == "repeat" then
    texture:setWrap("repeat", "repeat")
  end
  if texture then
    obj.texture = texture
    local textureWidth, textureHeight = texture:getDimensions()
    if animationData.wrap == "repeat" then
      -- a repeated image tiles over its size instead of stretching to it
      obj.width = obj.width or textureWidth
      obj.height = obj.height or textureHeight
      obj.isRepeated = true
      obj.scrollX = 0
      obj.scrollY = 0
      obj.quad = love.graphics.newQuad(obj.scrollX, obj.scrollY, obj.width, obj.height, textureWidth, textureHeight)
    else
      if obj.width then
        obj.xScale = obj.width / textureWidth
      end
      obj.width = textureWidth
      if obj.height then
        obj.yScale = obj.height / textureHeight
      end
      obj.height = textureHeight
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

  for _,track in ipairs(animationData.animationTracks or {}) do
    assert(animator, "Animation tracks need an animator to run on")
    AnimationLoader.playTrack(obj, track, animator)
  end
  for _, childData in ipairs(animationData.children or {}) do
    local drawable = loadDrawables(rootPath, childData, animator, images)
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

-- Returns the path of the file a ref imports, refs are written from the root folder like image file paths
local function referencedFilePath(rootPath, ref, filePath)
    if ref:find("..", 1, true) then
      error("The ref " .. ref .. " in " .. filePath .. " steps up a folder, refs are written from the root folder")
    end
    return rootPath .. ref:match("(.*%.json)")
end

-- Loads all files referenced and records a map of ID's to their nodes
function AnimationLoader.indexNodesRecursively(rootPath, nodeTable, filePath, idLookupTable, loadedFileTables)
    if nodeTable.ref ~= nil and nodeTable.ref:match("(.*%.json)#?") then
      local referencedPath = referencedFilePath(rootPath, nodeTable.ref, filePath)
      AnimationLoader.readFileAndCollectIdsRecursively(rootPath, referencedPath, loadedFileTables, idLookupTable)
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
            AnimationLoader.indexNodesRecursively(rootPath, childNode, filePath, idLookupTable, loadedFileTables)
        end
    end
end

function AnimationLoader.readFileAndCollectIdsRecursively(rootPath, filePath, loadedFileTables, idLookupTable)
    if loadedFileTables[filePath] ~= nil then
        return
    end

    local sceneTable = FileUtils.readJsonFile(filePath)
    if sceneTable == nil then
      error("Couldn't read the animation file " .. filePath)
    end

    sceneTable.filePath = filePath
    loadedFileTables[filePath] = sceneTable

    if sceneTable.drawables ~= nil then
        for _, drawableNode in ipairs(sceneTable.drawables) do
            AnimationLoader.indexNodesRecursively(rootPath, drawableNode, filePath, idLookupTable, loadedFileTables)
        end
    end
end

-- Changes the nodeTable so it has all the same properties as the reference with overrides applied. Recursive.
function AnimationLoader.resolveNodeReference(nodeTable, idLookupTable)
    if nodeTable.ref == nil then
      return -- nothing to resolve
    end

    local originalRef = nodeTable.ref:match("#(.+)$")

    if originalRef == nil then
      originalRef = nodeTable.ref
    end
    assert(originalRef ~= nil)
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

-- Resolves the refs in the node and its children
function AnimationLoader.resolveRefsRecursively(rootPath, nodeTable, loadedFileTables, idLookupTable, visitedTables)
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
            local referencedFileTable = loadedFileTables[rootPath .. nodeTable.ref]

            nodeTable.ref = nil
            -- every import gets its own copy, so importing a file twice neither shares nodes nor looks circular
            nodeTable.children = deepcpy(referencedFileTable.drawables)
        else
            AnimationLoader.resolveNodeReference(nodeTable, idLookupTable)
        end
    end

    if nodeTable.children ~= nil then
        for _, childNode in ipairs(nodeTable.children) do
            AnimationLoader.resolveRefsRecursively(rootPath, childNode, loadedFileTables, idLookupTable, visitedTables)
        end
    end
end

-- Calls fn with each node under the nodes and its parent, each before its children, in draw order
---@param nodes table[]
---@param fn fun(node: table, parent: table?)
---@param parent table? the node the nodes are children of
local function forEachNode(nodes, fn, parent)
  for _, node in ipairs(nodes) do
    fn(node, parent)
    forEachNode(node.children, fn, node)
  end
end

-- Returns each node's transform from the scene's origin, as it is when the data loads
---@param drawables table[]
---@return table<table, love.Transform>
local function worldTransforms(drawables)
  local worlds = {}
  local identity = love.math.newTransform()
  local nodeTransform = love.math.newTransform()
  forEachNode(drawables, function(node, parent)
    worlds[node] = (worlds[parent] or identity):clone():apply(AnimationLoader.setNodeTransform(nodeTransform, node))
  end)
  return worlds
end

-- Returns each image the nodes draw once, in draw order
---@param drawables table[]
---@return love.Texture[]
local function drawnImages(drawables)
  local textures = {}
  local seen = {}
  forEachNode(drawables, function(node)
    if node.texture and not seen[node.texture] then
      seen[node.texture] = true
      textures[#textures + 1] = node.texture
    end
  end)
  return textures
end

-- Packs the images the nodes draw into atlas pages so their draws batch, each node drawing its region
---@param drawables table[] drawables built from a file, whose images only they draw
local function moveOntoAtlas(drawables)
  local regions = TextureAtlas.build(drawnImages(drawables))
  forEachNode(drawables, function(node)
    local region = regions[node.texture]
    if region then
      node.texture = region.texture
      node.quad = region.quad
    end
  end)
end

-- Frees the images the file loaded that no node draws any more, as baking and the atlas took them off their nodes
---@param drawables table[]
---@param images table the images loaded for the file, see loadSharedImage
local function releaseUndrawnImages(drawables, images)
  local drawn = {}
  for _, texture in ipairs(drawnImages(drawables)) do
    drawn[texture] = true
  end
  for _, loaded in pairs(images) do
    if not drawn[loaded.texture] then
      loaded.texture:release()
    end
  end
end

-- Builds the drawables of animation data that has no refs left to resolve
---@param rootPath string the folder image file paths are written from
---@param rootData table the animation data, with its nodes in drawables
---@param animator Animator? the animator the tracks run on, its owner updates it, needed only when the data has tracks
---@return table[] drawables
---@return table images the images loaded for the data's file paths, see loadSharedImage
local function buildDrawables(rootPath, rootData, animator)
  local drawables = {}
  local images = {}
  for _, data in ipairs(rootData.drawables) do
    local drawable = loadDrawables(rootPath, data, animator, images)
    if drawable then
      drawables[#drawables+1] = drawable
    end
  end
  return drawables, images
end

-- Loads all drawables for a animation file.
-- When a window can draw them, the parts that never change are baked into one image per run at the given density, as far as the
-- longer side of the canvas either way it is turned, and the images left are packed into atlas pages, so the caller reloads the file
-- when the density it draws at changes. Only the file's drawables draw its images, so releaseImages can free them.
-- @param rootPath String the folder image file paths and file refs are written from
-- @param filePath String the full path of the file to load
---@param animator Animator the animator the tracks run on, its owner updates it
---@param drawScale number the pixel density the drawables are drawn at, GAME:newCanvasSnappedScale() for the canvas
-- @return table an array of drawables representing all the objects with their tracks running
function AnimationLoader.loadFromFile(rootPath, filePath, animator, drawScale)
  local loadedFileTables = {}   -- filePath → parsed table
  local idLookupTable   = {}    -- "id" → node table

  -- First all files are loaded from JSON and indexed
  AnimationLoader.readFileAndCollectIdsRecursively(rootPath, filePath, loadedFileTables, idLookupTable)

  local rootData = loadedFileTables[filePath]

  -- Then all references are resolved with overrides applied
  for _, drawable in ipairs(rootData.drawables) do
    AnimationLoader.resolveRefsRecursively(rootPath, drawable, loadedFileTables, idLookupTable, {})
  end

  -- Finally once the full data structure is setup, it is converted into separate drawable objects.
  local drawables, images = buildDrawables(rootPath, rootData, animator)
  -- without a window there is nothing to draw run images or pages with
  if love.graphics.isActive() then
    AnimationBaker.bake(drawables, worldTransforms(drawables), drawScale)
    moveOntoAtlas(drawables)
    releaseUndrawnImages(drawables, images)
  end
  return drawables
end

-- Frees the images the drawables loadFromFile returned draw, their run images included, once nothing draws them any more.
-- An image holds memory the garbage collector doesn't see, so a caller replacing its drawables frees the old ones at once.
---@param drawables table[] the drawables loadFromFile returned
function AnimationLoader.releaseImages(drawables)
  for _, texture in ipairs(drawnImages(drawables)) do
    texture:release()
  end
  forEachNode(drawables, function(node)
    if node.bakedRun then
      node.bakedRun.texture:release()
    end
  end)
end

-- Loads the drawables of animation data that has no refs left to resolve, such as data made in code, drawing each part on its own.
-- Data made in code can give a node a texture, an image that's already loaded, in place of its filePath.
---@param rootPath string the folder image file paths are written from
---@param rootData table the animation data, with its nodes in drawables
---@param animator Animator? the animator the tracks run on, its owner updates it, needed only when the data has tracks
---@return table[] drawables
function AnimationLoader.loadFromData(rootPath, rootData, animator)
  return (buildDrawables(rootPath, rootData, animator))
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

-- Sets the transform to the node's position, anchor, rotation and scale about its pivot, from its parent's space into its own.
-- LÖVE builds it in one call, where translating, rotating and scaling one step at a time would take five.
---@param transform love.Transform
---@param node table
---@return love.Transform transform
function AnimationLoader.setNodeTransform(transform, node)
  local px, py = AnimationLoader.anchorOffset(node, node.pivot)
  local wx, wy, wrot, xScale, yScale = AnimationLoader.objectTransform(node)
  return transform:setTransformation(wx + px, wy + py, wrot, xScale, yScale, px, py)
end

-- Reused by every node drawn, as applying it copies it onto the graphics transform
local nodeTransform = love.math.newTransform()


local function drawSiblingsBeforeNode(parent, node)
  love.graphics.setShader(alphaDiscardShader)
  for _, sibling in ipairs(parent.children) do
    if sibling == node then
      break
    end
    AnimationLoader.drawNode(sibling, nil)
  end
  love.graphics.setShader()
end

-- Draws a scene's drawables in order, starting from the default blend mode the nodes assume and restoring the graphics state afterwards so their colors don't leak into what draws next.
-- Each node only pushes its transform, saving and restoring the whole state once per scene instead of once per node.
---@param drawables table[] the drawables loadFromFile returned
function AnimationLoader.drawDrawables(drawables)
  love.graphics.push("all")
  love.graphics.setBlendMode("alpha", "alphamultiply")
  for _, drawable in ipairs(drawables) do
    AnimationLoader.drawNode(drawable)
  end
  love.graphics.pop()
end

-- Draws one node and its children, it sets its own color and resets the blend mode it changes; a node that uses a stencil is
-- drawn only where its siblings before it drew, inside any clip already open.
-- A node holding a baked run draws the run's image first, and one whose subtree draws no image of its own draws nothing else.
function AnimationLoader.drawNode(d, parent)
    if d.bakedRun then
      -- the run's image holds its parts' color already multiplied by their alpha
      love.graphics.setBlendMode("alpha", "premultiplied")
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(d.bakedRun.texture, d.bakedRun.transform)
      love.graphics.setBlendMode("alpha", "alphamultiply")
    end
    if d.drawsNothing then
      return
    end

    love.graphics.push()
    love.graphics.applyTransform(AnimationLoader.setNodeTransform(nodeTransform, d))

    if d.texture then
      local usesStencil = d.stencil
      local usesBlendAlphaMode = not GraphicsUtil.isDefaultBlendMode(d.blendMode, d.alphaMode)

      if usesStencil then
        assert(parent, "To use a stencil you need siblings")
        GraphicsUtil.clipStack:pushShape(drawSiblingsBeforeNode, parent, d)
      end

      if usesBlendAlphaMode then
        love.graphics.setBlendMode(d.blendMode, d.alphaMode)
      end

      love.graphics.setColor(d.tint[1], d.tint[2], d.tint[3], d.alpha)
      if d.quad then
        if d.isRepeated then
          -- whole pixels, so the scrolling image's edges stay sharp
          d.quad:setViewport(math.floor(d.scrollX), math.floor(d.scrollY), d.width, d.height)
        end
        love.graphics.draw(d.texture, d.quad, 0, 0)
      else
        love.graphics.draw(d.texture, 0, 0)
      end

      if usesBlendAlphaMode then
        love.graphics.setBlendMode("alpha", "alphamultiply")
      end

      if usesStencil then
        GraphicsUtil.clipStack:pop()
      end
    end

    for _, child in ipairs(d.children) do
      AnimationLoader.drawNode(child, d)
    end

    love.graphics.pop()
end

return AnimationLoader