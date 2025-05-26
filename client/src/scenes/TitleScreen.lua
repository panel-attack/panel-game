local Scene = require("client.src.scenes.Scene")
local consts = require("common.engine.consts")
local input = require("client.src.inputManager")
local tableUtils = require("common.lib.tableUtils")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local MainMenu = require("client.src.scenes.MainMenu")
local Flux = require("client.lib.flux.flux")
local fileUtils = require("client.src.FileUtils")

local START_OPACITY = 0.5

local scenePath = themes[config.theme].path .. "/scenes/"
local spriteData  = fileUtils.readJsonFile(scenePath .. "TitleScreen.json")
local drawableMap = {}

local function applyAnimationTracks(drawable)
  local imageInfo = drawable.animationData
  if imageInfo.animationTracks then
    for _, track in ipairs(imageInfo.animationTracks) do
      local previousTween = nil
      local target        = drawableMap[imageInfo.id]

      for stepIndex, step in ipairs(track.steps) do
        -- First link in the chain
        if stepIndex == 1 then
          previousTween = Flux.to(target, step.durationSeconds,
                                  step.animateProperties)
        else
          previousTween = previousTween:after(target,
                                               step.durationSeconds,
                                               step.animateProperties)
        end

        previousTween:ease(step.easeType)
                     :delay(step.delaySeconds or 0)

        -- inline yoyo = append reverse tween
        if step.yoyo then
          local reverseProps = {}
          for k, v in pairs(step.animateProperties) do
            reverseProps[k] = target[k] -- value **before** tween starts
          end
          previousTween = previousTween:after(target,
                                               step.durationSeconds,
                                               reverseProps)
                                       :ease(step.easeType)
        end
      end

      -- Loop the whole track?
      if track.loopTrack then
        previousTween:oncomplete(function() applyAnimationTracks(drawable) end)
      end
    end
  end
end

for _, imageInfo in ipairs(spriteData.images) do
  local texture = GraphicsUtil.loadImageFromSupportedExtensions(scenePath .. imageInfo.filePath)

  drawableMap[imageInfo.id] = {
    texture      = texture,
    x = imageInfo.initialPosition.x,
    y = imageInfo.initialPosition.y,
    rotation = imageInfo.initialRotation or 0,
    scale = imageInfo.initialScale or 1,
    alpha = 1,
    animationData = imageInfo
  }

  applyAnimationTracks(drawableMap[imageInfo.id])
end

local function anchorOffset(texture, anchor)
  local w, h = texture:getWidth(), texture:getHeight()
  local map = {
    topLeft      = {0,     0},     topCenter    = {w/2, 0},   topRight     = {w,   0},
    centerLeft   = {0,   h/2},     center       = {w/2, h/2}, centerRight  = {w, h/2},
    bottomLeft   = {0,     h},     bottomCenter = {w/2, h},   bottomRight  = {w,   h}
  }
  return (map[anchor] or map.center)[1], (map[anchor] or map.center)[2]
end

-- The title screen scene
local TitleScreen = class(
  function (self, sceneParams)
    self.backgroundImg = themes[config.theme].images.bg_title
    self.music = "title_screen"
    self.opacity = START_OPACITY
    self.direction = 1
    self.animation = nil
    self:startAnimation()
  end,
  Scene
)

function TitleScreen:startAnimation()
  local target = START_OPACITY
  if self.direction == 1 then
    target = 1
  end

  self.animation = Flux.to(self, 0.6, { opacity = target })
      :ease("quadinout")
      :oncomplete(function()
          self.direction = -self.direction
          self:startAnimation()
      end)
end

TitleScreen.name = "TitleScreen"

function TitleScreen:titleDrawPressStart(opacity)
  local opacityTarget = self.opacity
  local textMaxWidth = consts.CANVAS_WIDTH - 40
  local textHeight = 40
  local x = (consts.CANVAS_WIDTH / 2) - (textMaxWidth / 2)
  local y = consts.CANVAS_HEIGHT * 0.75
  GraphicsUtil.printf(loc("continue_button"), x, y, textMaxWidth, "center", {1,1,1,opacityTarget}, nil, 16)
end

function TitleScreen:update(dt)
  self.backgroundImg:update(dt)
  local keyPressed = tableUtils.trueForAny(input.allKeys.isDown, function(key) return key end)
  if love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 or keyPressed then
    GAME.theme:playValidationSfx()
    self.animation:stop()
    GAME.navigationStack:replace(MainMenu())
  end
end

function TitleScreen:draw()
  -- self.backgroundImg:draw()
  self:titleDrawPressStart(((math.sin(5 * love.timer.getTime()) / 2 + .5) ^ .5) / 2 + .5)

  for _, d in pairs(drawableMap) do
    local ox, oy = anchorOffset(d.texture, d.anchor or "center")
    love.graphics.setColor(1,1,1,d.alpha or 1)
    love.graphics.draw(d.texture, d.x, d.y, d.rotation, d.scale, d.scale, ox, oy)
  end
end

return TitleScreen