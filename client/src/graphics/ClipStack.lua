local class = require("common.lib.class")

local loveMajor = love.getVersion()

-- Limits drawing to where every shape pushed and not yet popped overlaps.
-- Each pixel's stencil value counts the open clips it is inside, and drawing passes only where that reaches the depth. The
-- shapes are drawn in the current transform, so unlike a scissor a clip can be rotated, scaled or any shape. The clip stack is
-- the only writer of the stencil and every push is popped, so the stencil reads 0 wherever no clip is open.
---@class ClipStack
---@field private entries ClipEntry[] the shape of each open clip, innermost last; an entry is kept after its pop and refilled by
--- the next push at its depth, so clipping allocates nothing once each depth has been reached
---@field depth integer how many clips are open
local ClipStack = class(function(self)
  self.entries = {}
  self.depth = 0
end)

-- The shape of one open clip: a rectangle, or whatever a function drew
---@class ClipEntry
---@field draw fun(entry: ClipEntry) draws the shape
---@field x number
---@field y number
---@field width number
---@field height number
---@field drawShape fun(owner: any, node: any)? draws the shape of a clip pushed with pushShape
---@field owner any
---@field node any

---@param entry ClipEntry
local function drawRectangle(entry)
  love.graphics.rectangle("fill", entry.x, entry.y, entry.width, entry.height)
end

---@param entry ClipEntry
local function drawGivenShape(entry)
  entry.drawShape(entry.owner, entry.node)
end

-- love.graphics.stencil on 11 takes a function without arguments, so the entry it draws is passed through here
---@type ClipEntry
local entryBeingCounted
local function drawEntryBeingCounted()
  entryBeingCounted.draw(entryBeingCounted)
end

-- Adds one to or takes one from the stencil value of each pixel the entry's shape covers
-- On 12 only pixels whose value is countedValue change, so pixels outside an outer clip are left out and a shape that covers a
-- pixel twice counts it once. 11 can't compare while writing the stencil, so there a shape covering a pixel twice counts it twice.
---@param action "increment" | "decrement"
---@param entry ClipEntry
---@param countedValue integer
local function countShape(action, entry, countedValue)
  if loveMajor >= 12 then
    local red, green, blue, alpha = love.graphics.getColorMask()
    love.graphics.setColorMask(false, false, false, false)
    love.graphics.setStencilState(action, "equal", countedValue)
    entry.draw(entry)
    love.graphics.setColorMask(red, green, blue, alpha)
  else
    entryBeingCounted = entry
    love.graphics.stencil(drawEntryBeingCounted, action, 1, true)
  end
end

-- Limits drawing to the pixels inside every open clip, or lifts the limit when none is open
-- 11 tests for at least the depth, so pixels a shape counted twice still pass.
---@param depth integer
local function testDepth(depth)
  if loveMajor >= 12 and depth == 0 then
    love.graphics.setStencilState()
  elseif loveMajor >= 12 then
    love.graphics.setStencilMode("test", depth)
  elseif depth == 0 then
    love.graphics.setStencilTest()
  else
    love.graphics.setStencilTest("gequal", depth)
  end
end

-- Returns the entry for the next push, kept from an earlier push at that depth when there was one
---@return ClipEntry
function ClipStack:nextEntry()
  local entry = self.entries[self.depth + 1]
  if not entry then
    entry = {draw = drawRectangle, x = 0, y = 0, width = 0, height = 0}
    self.entries[self.depth + 1] = entry
  end
  return entry
end

-- Counts the entry's shape as the innermost clip
---@param entry ClipEntry
function ClipStack:open(entry)
  countShape("increment", entry, self.depth)
  self.depth = self.depth + 1
  testDepth(self.depth)
end

-- Limits drawing to the rectangle, in the current transform, until pop; inside another clip, to where both are
---@param x number
---@param y number
---@param width number
---@param height number
function ClipStack:pushRectangle(x, y, width, height)
  local entry = self:nextEntry()
  entry.draw = drawRectangle
  entry.x, entry.y, entry.width, entry.height = x, y, width, height
  self:open(entry)
end

-- Limits drawing to the pixels drawShape(owner, node) draws, in the current transform, until pop; inside another clip, to
-- where both are. The shape is drawn again by pop, so it must draw the same pixels both times.
---@param drawShape fun(owner: any, node: any) a function made once, not per push, so pushing allocates nothing
---@param owner any
---@param node any
function ClipStack:pushShape(drawShape, owner, node)
  local entry = self:nextEntry()
  entry.draw = drawGivenShape
  entry.drawShape, entry.owner, entry.node = drawShape, owner, node
  self:open(entry)
end

-- Ends the innermost clip; runs in the transform its push ran in
function ClipStack:pop()
  assert(self.depth > 0, "No clip is open to pop")
  local entry = self.entries[self.depth]
  countShape("decrement", entry, self.depth)
  self.depth = self.depth - 1
  testDepth(self.depth)
  -- a shape's owner and node aren't kept alive by a clip that has ended
  entry.owner, entry.node = nil, nil
end

return ClipStack
