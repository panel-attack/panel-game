local class = require("common.lib.class")
local AnimationLoader = require("client.src.graphics.AnimationLoader")
local Flux = require("client.lib.flux.flux")
local Theme = require("client.src.mods.Theme")
local fileUtils = require("client.src.FileUtils")
local consts = require("common.engine.consts")

-- An animation file with its own tweens, from the given folder, such as a stage's, or else from the current theme's scenes folder.
-- Its image paths and file refs are relative to the given folder, or else to the theme folder.
-- It reloads itself when the density the canvas draws at changed since it loaded, as its still parts are baked at that density, and one from
-- the theme also when the theme changed, freeing the images it replaces.
-- Without the file it draws its fallback image in the file's place, if it was given one, or else nothing.
-- The file's one top-level drawable is a container the canvas's size at its origin, unscaled, so the scene is laid out in canvas units.
---@class SceneAnimation
---@field fileName string the animation file inside its folder
---@field folder string? the folder holding the file, nil for the current theme's scenes folder
---@field drawables table[] the drawables loaded from the file
---@field tweens table the flux group running the drawables' tracks
---@field themePath string? the path of the theme the drawables were loaded from, nil when it has its own folder
---@field drawScale number the canvas's snapped scale the drawables were loaded for, see GAME:newCanvasSnappedScale
---@field fallbackImage UpdatingImage? the image drawn in place of a missing file
---@overload fun(fileName: string, folder: string?, fallbackImage: UpdatingImage?): SceneAnimation
local SceneAnimation = class(
---@param self SceneAnimation
---@param fileName string
---@param folder string? the folder holding the file, nil for the current theme's scenes folder
---@param fallbackImage UpdatingImage? the image drawn in place of a missing file
function(self, fileName, folder, fallbackImage)
  self.fileName = fileName
  self.folder = folder
  self.fallbackImage = fallbackImage
  self:load()
end)

-- Errors naming the file unless its drawables are one container the canvas's size at the canvas's origin, unscaled and unrotated
---@param drawables table[]
---@param filePath string
local function assertCanvasContainer(drawables, filePath)
  local container = drawables[1]
  local isCanvas = #drawables == 1 and container.texture == nil
    and container.width == consts.CANVAS_WIDTH and container.height == consts.CANVAS_HEIGHT
    and container.x == 0 and container.y == 0 and container.anchor == "topLeft"
    and container.xScale == 1 and container.yScale == 1 and container.rotation == 0
  if not isCanvas then
    error(filePath .. " must have one top-level drawable: a container sized "
      .. consts.CANVAS_WIDTH .. "x" .. consts.CANVAS_HEIGHT .. " at 0,0, anchored at its top left, with no scale or rotation, holding the scene")
  end
end

-- Loads the drawables for the canvas's current snapped scale, from the current theme if it has no folder, dropping any running tracks
-- and freeing the images of the drawables it replaces
function SceneAnimation:load()
  if self.drawables then
    AnimationLoader.releaseImages(self.drawables)
  end
  self.drawScale = GAME:newCanvasSnappedScale()
  self.tweens = Flux.group()
  local rootFolder, filePath
  if self.folder then
    rootFolder = self.folder .. "/"
    filePath = rootFolder .. self.fileName
  else
    self.themePath = themes[config.theme].path
    rootFolder = self.themePath .. "/"
    filePath = rootFolder .. Theme.SCENES_FOLDER .. "/" .. self.fileName
  end
  if fileUtils.exists(filePath) then
    self.drawables = AnimationLoader.loadFromFile(rootFolder, filePath, self.tweens, self.drawScale)
    assertCanvasContainer(self.drawables, filePath)
  else
    self.drawables = {}
  end
end

-- Returns whether the canvas's snapped scale, or the theme it was loaded from, changed since the drawables were loaded
---@return boolean
function SceneAnimation:isStale()
  if self.folder == nil and self.themePath ~= themes[config.theme].path then
    return true
  end
  return self.drawScale ~= GAME:newCanvasSnappedScale()
end

-- Returns the fallback image while the file is missing, nil when the file was found or it has no fallback image
---@return UpdatingImage?
function SceneAnimation:getFallbackImage()
  if #self.drawables == 0 then
    return self.fallbackImage
  end
end

-- Updates the scene
---@param dt number seconds since the last update
function SceneAnimation:update(dt)
  if self:isStale() then
    self:load()
  end
  self.tweens:update(dt)
  local fallbackImage = self:getFallbackImage()
  if fallbackImage then
    fallbackImage:update(dt)
  end
end

-- Draws the scene
function SceneAnimation:draw()
  local fallbackImage = self:getFallbackImage()
  if fallbackImage then
    fallbackImage:draw()
  else
    AnimationLoader.drawDrawables(self.drawables)
  end
end

return SceneAnimation
