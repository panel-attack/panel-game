local class = require("common.lib.class")
local AnimationLoader = require("client.src.graphics.AnimationLoader")
local Flux = require("client.lib.flux.flux")
local Theme = require("client.src.mods.Theme")

-- An animation file with its own tweens, from the given folder, such as a stage's, or else from the current theme's scenes folder.
-- Its image paths and file refs are relative to the given folder, or else to the theme folder.
-- It reloads itself when the canvas scale changed since it loaded, so its images have the right filter, and one from the theme also when the theme changed.
---@class SceneAnimation
---@field fileName string the animation file inside its folder
---@field folder string? the folder holding the file, nil for the current theme's scenes folder
---@field drawables table[] the drawables loaded from the file
---@field tweens table the flux group running the drawables' tracks
---@field themePath string? the path of the theme the drawables were loaded from, nil when it has its own folder
---@field canvasScale number the canvas scale the drawables were loaded for
---@overload fun(fileName: string, folder: string?): SceneAnimation
local SceneAnimation = class(
---@param self SceneAnimation
---@param fileName string
---@param folder string? the folder holding the file, nil for the current theme's scenes folder
function(self, fileName, folder)
  self.fileName = fileName
  self.folder = folder
  self:load()
end)

-- Loads the drawables for the current canvas scale, from the current theme if it has no folder, dropping any running tracks
function SceneAnimation:load()
  self.canvasScale = GAME.canvasXScale
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
  self.drawables = AnimationLoader.loadFromFile(rootFolder, filePath, self.tweens)
end

-- Returns whether the canvas scale, or the theme it was loaded from, changed since the drawables were loaded
---@return boolean
function SceneAnimation:isStale()
  if self.folder == nil and self.themePath ~= themes[config.theme].path then
    return true
  end
  return self.canvasScale ~= GAME.canvasXScale
end

-- Reloads the drawables if they are stale and advances their tracks
---@param dt number seconds since the last update
function SceneAnimation:update(dt)
  if self:isStale() then
    self:load()
  end
  self.tweens:update(dt)
end

-- Draws the drawables, see AnimationLoader.drawDrawables
function SceneAnimation:draw()
  AnimationLoader.drawDrawables(self.drawables)
end

return SceneAnimation
