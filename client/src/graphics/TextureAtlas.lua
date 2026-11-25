-- Packs images into shared atlas pages, so draws of different images can come from one texture and LÖVE can batch them into one draw call.
-- Each image keeps its edge pixels repeated around it on the page, so linear filtering at its edges samples what clamping its own
-- texture did.
local GraphicsUtil = require("client.src.graphics.graphics_util")

---@class AtlasRect
---@field x integer
---@field y integer
---@field width integer
---@field height integer

---@class AtlasPage
---@field width integer how far right the images on it reach, in pixels
---@field height integer how far down the images on it reach, in pixels
---@field freeRects AtlasRect[] the overlapping rectangles nothing is placed in yet

local TextureAtlas = {}

-- How many pixels of each image's edge are repeated around it
TextureAtlas.EDGE = 1
-- The widest and tallest a page gets, a size every GPU the game runs on can hold
local MAX_PAGE_SIZE = 4096

-- Returns the free rectangle the given size fits in nearest the top, then the left, and where it goes
---@param freeRects AtlasRect[]
---@param width integer
---@param height integer
---@return AtlasRect?
local function findPosition(freeRects, width, height)
  local best
  for _, free in ipairs(freeRects) do
    local fits = width <= free.width and height <= free.height
    if fits and (not best or free.y < best.y or (free.y == best.y and free.x < best.x)) then
      best = free
    end
  end
  return best
end

-- Whether the two rectangles share any pixel
---@param a AtlasRect
---@param b AtlasRect
---@return boolean
local function intersects(a, b)
  return a.x < b.x + b.width and b.x < a.x + a.width and a.y < b.y + b.height and b.y < a.y + a.height
end

-- Whether every pixel of inner is in outer
---@param outer AtlasRect
---@param inner AtlasRect
---@return boolean
local function contains(outer, inner)
  return inner.x >= outer.x and inner.y >= outer.y
    and inner.x + inner.width <= outer.x + outer.width and inner.y + inner.height <= outer.y + outer.height
end

-- Adds the parts of the free rectangle the used one doesn't cover to into, as up to four overlapping rectangles
---@param free AtlasRect
---@param used AtlasRect
---@param into AtlasRect[]
local function splitFreeRect(free, used, into)
  if used.x > free.x then
    into[#into + 1] = {x = free.x, y = free.y, width = used.x - free.x, height = free.height}
  end
  if used.x + used.width < free.x + free.width then
    into[#into + 1] = {x = used.x + used.width, y = free.y, width = free.x + free.width - used.x - used.width, height = free.height}
  end
  if used.y > free.y then
    into[#into + 1] = {x = free.x, y = free.y, width = free.width, height = used.y - free.y}
  end
  if used.y + used.height < free.y + free.height then
    into[#into + 1] = {x = free.x, y = used.y + used.height, width = free.width, height = free.y + free.height - used.y - used.height}
  end
end

-- Whether another of the rectangles holds the one at index i, the earlier of two equal ones counting as the holder
---@param rects AtlasRect[]
---@param i integer
---@return boolean
local function isHeld(rects, i)
  for j, other in ipairs(rects) do
    if i ~= j and contains(other, rects[i]) and (not contains(rects[i], other) or j < i) then
      return true
    end
  end
  return false
end

-- Takes the used rectangle out of the page's free rectangles, dropping any free rectangle another one holds
---@param page AtlasPage
---@param used AtlasRect
local function occupy(page, used)
  local split = {}
  for _, free in ipairs(page.freeRects) do
    if intersects(free, used) then
      splitFreeRect(free, used, split)
    else
      split[#split + 1] = free
    end
  end
  local kept = {}
  for i, free in ipairs(split) do
    if not isHeld(split, i) then
      kept[#kept + 1] = free
    end
  end
  page.freeRects = kept
  page.width = math.max(page.width, used.x + used.width)
  page.height = math.max(page.height, used.y + used.height)
end

-- Returns an empty page that can grow to maxSize either way
---@param maxSize integer
---@return AtlasPage
local function newPage(maxSize)
  return {width = 0, height = 0, freeRects = {{x = 0, y = 0, width = maxSize, height = maxSize}}}
end

-- Returns the first page with room for the size and the free rectangle it goes in, adding a page when none has room
---@param pages AtlasPage[]
---@param width integer
---@param height integer
---@param maxSize integer
---@return integer pageIndex
---@return AtlasRect free
local function findRoom(pages, width, height, maxSize)
  for i, page in ipairs(pages) do
    local free = findPosition(page.freeRects, width, height)
    if free then
      return i, free
    end
  end
  pages[#pages + 1] = newPage(maxSize)
  return #pages, pages[#pages].freeRects[1]
end

-- Places images on as few pages as fit them, tallest first, each nearest the top left of the first page with room.
-- Each page is cropped to the images on it. An image bigger than a page is left out.
---@param sizes {width: integer, height: integer}[] the images' sizes in pixels
---@param maxSize integer the widest and tallest a page may be in pixels
---@return {width: integer, height: integer}[] pages the pages, with their sizes in pixels
---@return table<integer, {page: integer, x: integer, y: integer}> placements by image index, where each image's own pixels start
function TextureAtlas.pack(sizes, maxSize)
  local order = {}
  for i = 1, #sizes do
    order[i] = i
  end
  table.sort(order, function(a, b)
    if sizes[a].height ~= sizes[b].height then
      return sizes[a].height > sizes[b].height
    end
    if sizes[a].width ~= sizes[b].width then
      return sizes[a].width > sizes[b].width
    end
    return a < b
  end)

  local pages = {}
  local placements = {}
  for _, index in ipairs(order) do
    local width = sizes[index].width + TextureAtlas.EDGE * 2
    local height = sizes[index].height + TextureAtlas.EDGE * 2
    if width <= maxSize and height <= maxSize then
      local pageIndex, free = findRoom(pages, width, height, maxSize)
      occupy(pages[pageIndex], {x = free.x, y = free.y, width = width, height = height})
      placements[index] = {page = pageIndex, x = free.x + TextureAtlas.EDGE, y = free.y + TextureAtlas.EDGE}
    end
  end

  return pages, placements
end

-- Copies the texture onto the page canvas being drawn with its own pixels starting at x, y, and its edge pixels repeated EDGE pixels
-- around it, by drawing a quad that reaches EDGE pixels past the texture, which its clamp wrap fills with its edge pixels
---@param texture love.Texture
---@param x integer
---@param y integer
local function copyOntoPage(texture, x, y)
  local width, height = texture:getPixelWidth(), texture:getPixelHeight()
  local e = TextureAtlas.EDGE
  -- the quad's reference size is in pixels, so it draws one unit per pixel on the 1x page canvas
  local quad = GraphicsUtil:newRecycledQuad(-e, -e, width + e * 2, height + e * 2, width, height)
  love.graphics.draw(texture, quad, x - e, y - e)
  GraphicsUtil:releaseQuad(quad)
end

-- Draws the images onto a page and returns it, with their filter
---@param page AtlasPage
---@param onPage {texture: love.Texture, place: {x: integer, y: integer}}[]
---@return love.Texture
local function drawPage(page, onPage)
  local minFilter, magFilter = onPage[1].texture:getFilter()
  return GraphicsUtil.renderToTexture(page.width, page.height, function()
    -- copies each pixel as it is, without blending or multiplying its color by its alpha
    love.graphics.setBlendMode("replace", "premultiplied")
    for _, image in ipairs(onPage) do
      local texture = image.texture
      texture:setFilter("nearest", "nearest")
      copyOntoPage(texture, image.place.x, image.place.y)
      texture:setFilter(minFilter, magFilter)
    end
  end, 1, minFilter, magFilter)
end

-- Whether the texture clamps on both axes, so sampling past its edges gives its edge pixels as a page's repeated edge does
---@param texture love.Texture
---@return boolean
local function clamps(texture)
  local horizontal, vertical = texture:getWrap()
  return horizontal == "clamp" and vertical == "clamp"
end

-- Splits the clamping textures into groups that can share a page, those at the same pixel density and filter, in the order they
-- first appear, leaving out the others
---@param textures love.Texture[]
---@return love.Texture[][]
local function groupClampingByDensityAndFilter(textures)
  local groups = {}
  local groupByKey = {}
  for _, texture in ipairs(textures) do
    if clamps(texture) then
      local minFilter, magFilter = texture:getFilter()
      local key = texture:getDPIScale() .. " " .. minFilter .. " " .. magFilter
      if not groupByKey[key] then
        groupByKey[key] = {}
        groups[#groups + 1] = groupByKey[key]
      end
      local group = groupByKey[key]
      group[#group + 1] = texture
    end
  end
  return groups
end

-- Packs a group of textures that can share pages, draws the pages and adds each placed texture's page and quad to regions
---@param group love.Texture[]
---@param regions table<love.Texture, {texture: love.Texture, quad: love.Quad}>
local function addGroupRegions(group, regions)
  local sizes = {}
  for i, texture in ipairs(group) do
    sizes[i] = {width = texture:getPixelWidth(), height = texture:getPixelHeight()}
  end
  local pages, placements = TextureAtlas.pack(sizes, math.min(love.graphics.getSystemLimits().texturesize, MAX_PAGE_SIZE))
  local onPages = {}
  for i, texture in ipairs(group) do
    local place = placements[i]
    if place then
      onPages[place.page] = onPages[place.page] or {}
      table.insert(onPages[place.page], {texture = texture, place = place})
    end
  end
  for pageIndex, page in ipairs(pages) do
    local image = drawPage(page, onPages[pageIndex])
    for _, placed in ipairs(onPages[pageIndex]) do
      local texture, place = placed.texture, placed.place
      -- the points its own texture spreads each pixel over, as LÖVE rounds the width in points of a texture whose pixels
      -- don't divide by its density, so the quad samples the page's pixels where drawing the texture sampled its own
      local xPoints = texture:getWidth() / texture:getPixelWidth()
      local yPoints = texture:getHeight() / texture:getPixelHeight()
      regions[texture] = {
        texture = image,
        quad = love.graphics.newQuad(place.x * xPoints, place.y * yPoints, texture:getWidth(), texture:getHeight(),
          image:getPixelWidth() * xPoints, image:getPixelHeight() * yPoints)
      }
    end
  end
end

-- Builds atlas pages for the textures and returns where each one is on them. Needs an active graphics module to draw pages with.
-- A texture that doesn't clamp, is bigger than a page, or is the only one at its density and filter gets no region.
---@param textures love.Texture[] distinct textures, in the order they are drawn
---@return table<love.Texture, {texture: love.Texture, quad: love.Quad}> regions the page and the quad on it for each texture
function TextureAtlas.build(textures)
  local regions = {}
  for _, group in ipairs(groupClampingByDensityAndFilter(textures)) do
    if #group > 1 then
      addGroupRegions(group, regions)
    end
  end
  return regions
end

return TextureAtlas
