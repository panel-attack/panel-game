local class = require("common.lib.class")
local AnimationLoader = require("client.src.graphics.AnimationLoader")
local Flux = require("client.lib.flux.flux")
local Theme = require("client.src.mods.Theme")

-- An animation file from the current theme's scenes folder with its own tweens, its image paths and file refs are relative to the theme folder.
-- It reloads itself when the theme or the canvas scale changed since it loaded, so its images come from the right theme with the right filter.
---@class SceneAnimation
---@field fileName string the animation file inside the theme's scenes folder
---@field drawables table[] the drawables loaded from the file
---@field tweens table the flux group running the drawables' tracks
---@field themePath string the path of the theme the drawables were loaded from
---@field canvasScale number the canvas scale the drawables were loaded for
---@overload fun(fileName: string): SceneAnimation
local SceneAnimation = class(
---@param self SceneAnimation
---@param fileName string
function(self, fileName)
  self.fileName = fileName
  self:load()
end)

-- Loads the drawables from the current theme for the current canvas scale, dropping any running tracks
function SceneAnimation:load()
  self.themePath = themes[config.theme].path
  self.canvasScale = GAME.canvasXScale
  self.tweens = Flux.group()
  local themeFolder = self.themePath .. "/"
  local filePath = themeFolder .. Theme.SCENES_FOLDER .. "/" .. self.fileName
  self.drawables = AnimationLoader.loadFromFile(themeFolder, filePath, self.tweens)
end

-- Returns whether the theme or the canvas scale changed since the drawables were loaded
---@return boolean
function SceneAnimation:isStale()
  return self.themePath ~= themes[config.theme].path or self.canvasScale ~= GAME.canvasXScale
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
