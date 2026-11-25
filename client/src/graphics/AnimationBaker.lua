-- Draws the runs of parts in an animation that never change into one image per run when it loads, so each frame draws that image
-- instead of every part in it. A run is the still parts drawn one after another between two parts that move or blend differently,
-- so drawing its image in the first part's place keeps the draw order. Fewer parts drawn means less transform work on the CPU and
-- fewer overlapping pixels blended on the GPU, for the memory of the run images.
local GraphicsUtil = require("client.src.graphics.graphics_util")
local tableUtils = require("common.lib.tableUtils")
local consts = require("common.engine.consts")

local AnimationBaker = {}

-- The size of the square a scene is shown in, the longer side of the canvas either way it is turned
local SHOWN_SIDE = math.max(consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT)

-- Whether a part draws plainly, so drawing it into a transparent image first and that image later looks the same.
-- A repeated image tiles over its size through its quad, which drawing it into a run image doesn't.
---@param node table
---@return boolean
local function drawsPlainly(node)
  return not node.isRepeated and not node.stencil and GraphicsUtil.isDefaultBlendMode(node.blendMode, node.alphaMode)
end

-- Adds the node's image drawing parts to the last run, or ends it at a part that moves or can't be drawn ahead of time.
-- A part moves when it or a node above it has tracks, and siblings a stencil masks with are drawn every frame.
---@param node table
---@param moves boolean whether a node above this one moves, or it is masked with by a stencil
---@param runs table[][] the runs so far, the last one still open
local function collectRuns(node, moves, runs)
  moves = moves or #node.animationTracks > 0
  local run = runs[#runs]
  if node.texture and not moves and drawsPlainly(node) then
    run[#run + 1] = node
  elseif node.texture and #run > 0 then
    runs[#runs + 1] = {}
  end
  local childrenMove = moves or tableUtils.trueForAny(node.children, "stencil")
  for _, child in ipairs(node.children) do
    collectRuns(child, childrenMove, runs)
  end
end

-- Returns the runs of still image drawing parts in draw order, each with at least two parts
---@param drawables table[] the drawables AnimationLoader.loadFromFile built
---@return table[][] runs
function AnimationBaker.findStillRuns(drawables)
  local runs = {{}}
  for _, drawable in ipairs(drawables) do
    collectRuns(drawable, false, runs)
  end
  local longRuns = {}
  for _, run in ipairs(runs) do
    if #run > 1 then
      longRuns[#longRuns + 1] = run
    end
  end
  return longRuns
end

-- Marks every node that draws no image of its own and none under it, so drawing can skip it whole, and records each node's parent
---@param node table
---@param parent table?
---@param parents table<table, table?>
---@return boolean drawsNothing
local function markSubtreesDrawingNothing(node, parent, parents)
  parents[node] = parent
  local drawsNothing = node.texture == nil
  for _, child in ipairs(node.children) do
    if not markSubtreesDrawingNothing(child, node, parents) then
      drawsNothing = false
    end
  end
  node.drawsNothing = drawsNothing
  return drawsNothing
end

-- Returns the run's area on the canvas inside the shown area, on whole pixels at the given density, or nil if none of it shows
---@param run table[]
---@param worlds table<table, love.Transform>
---@param scale number
---@return number? x0
---@return number? y0
---@return number? x1
---@return number? y1
local function runArea(run, worlds, scale)
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, node in ipairs(run) do
    local world = worlds[node]
    local ax, ay = world:transformPoint(0, 0)
    local bx, by = world:transformPoint(node.width, 0)
    local cx, cy = world:transformPoint(0, node.height)
    local dx, dy = world:transformPoint(node.width, node.height)
    x0, y0 = math.min(x0, ax, bx, cx, dx), math.min(y0, ay, by, cy, dy)
    x1, y1 = math.max(x1, ax, bx, cx, dx), math.max(y1, ay, by, cy, dy)
  end
  x0 = math.floor(math.max(0, x0) * scale) / scale
  y0 = math.floor(math.max(0, y0) * scale) / scale
  x1 = math.ceil(math.min(SHOWN_SIDE, x1) * scale) / scale
  y1 = math.ceil(math.min(SHOWN_SIDE, y1) * scale) / scale
  if x1 <= x0 or y1 <= y0 then
    return nil
  end
  return x0, y0, x1, y1
end

-- Draws the run's parts into an image of their area at the given density, one pixel a unit
---@param run table[]
---@param worlds table<table, love.Transform>
---@param scale number
---@param x0 number
---@param y0 number
---@param x1 number
---@param y1 number
---@return love.Texture
local function drawRun(run, worlds, scale, x0, y0, x1, y1)
  local pixelWidth = math.round((x1 - x0) * scale)
  local pixelHeight = math.round((y1 - y0) * scale)
  -- kept at one pixel a unit and scaled down where it's drawn, as LÖVE rounds an image's size in points to whole points
  return GraphicsUtil.renderToTexture(pixelWidth, pixelHeight, function()
    love.graphics.scale(scale)
    love.graphics.translate(-x0, -y0)
    for _, node in ipairs(run) do
      love.graphics.setColor(node.tint[1], node.tint[2], node.tint[3], node.alpha)
      love.graphics.draw(node.texture, worlds[node])
    end
  end, 1, love.graphics.getDefaultFilter())
end

-- Returns the highest node above the run's first part that draws nothing else, the node drawn in the run's place
---@param run table[]
---@param parents table<table, table?>
---@return table
local function runAnchor(run, parents)
  local anchor = run[1]
  while parents[anchor] and parents[anchor].drawsNothing do
    anchor = parents[anchor]
  end
  return anchor
end

-- Bakes every run of still parts into an image drawn in the run's place, taking the parts' own images off them so they aren't drawn.
-- Runs are baked at the density the scene is drawn at, as a coarser image drawn larger blurs edges its parts drew sharp, and only as
-- far as the shown area, as nothing still moves into it.
---@param drawables table[] the drawables AnimationLoader.loadFromFile built
---@param worlds table<table, love.Transform> each node's transform on the canvas
---@param scale number the density the scene is drawn at
function AnimationBaker.bake(drawables, worlds, scale)
  local baked = {}
  for _, run in ipairs(AnimationBaker.findStillRuns(drawables)) do
    local x0, y0, x1, y1 = runArea(run, worlds, scale)
    if x0 then
      baked[#baked + 1] = {run = run, texture = drawRun(run, worlds, scale, x0, y0, x1, y1), x = x0, y = y0}
    end
    for _, node in ipairs(run) do
      node.texture = nil
    end
  end
  local parents = {}
  for _, drawable in ipairs(drawables) do
    markSubtreesDrawingNothing(drawable, nil, parents)
  end
  local identity = love.math.newTransform()
  for _, image in ipairs(baked) do
    local anchor = runAnchor(image.run, parents)
    anchor.bakedRun = {
      texture = image.texture,
      -- drawn under the anchor's parent's transform, so that is undone to place the image on the canvas
      transform = (worlds[parents[anchor]] or identity):inverse():translate(image.x, image.y):scale(1 / scale)
    }
  end
end

return AnimationBaker
