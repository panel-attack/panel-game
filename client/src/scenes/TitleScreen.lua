local Scene = require("client.src.scenes.Scene")
local consts = require("common.engine.consts")
local input = require("client.src.inputManager")
local tableUtils = require("common.lib.tableUtils")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local AnimationLoader = require("client.src.graphics.AnimationLoader")
local Flux = require("client.lib.flux.flux")
local fileUtils = require("client.src.FileUtils")

local START_OPACITY = 0.5

local scenePath = themes[config.theme].path .. "/scenes/"

-- The title screen scene
local TitleScreen = class(
  function (self, sceneParams)
    self.backgroundImg = themes[config.theme].images.bg_main
    self.music = "title_screen"
    self.opacity = START_OPACITY
    self.drawables = AnimationLoader.loadFromFile(scenePath, scenePath .. "TitleScreen.json")
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
  local x = (consts.CANVAS_WIDTH / 2) - (textMaxWidth / 2)
  local y = consts.CANVAS_HEIGHT * 0.75
  GraphicsUtil.printf(loc("continue_button"), x, y, textMaxWidth, "center", {1,1,1,opacityTarget}, nil, 16)
end

function TitleScreen:update(dt)
  self.backgroundImg:update(dt)
  -- local keyPressed = tableUtils.trueForAny(input.allKeys.isDown, function(key) return key end)
  -- if love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 or keyPressed then
  --   GAME.theme:playValidationSfx()
  --   self.animation:stop()
  --   GAME.navigationStack:replace(MainMenu())
  -- end
end

function TitleScreen:draw()
  self.backgroundImg:draw()
  self:titleDrawPressStart(((math.sin(5 * love.timer.getTime()) / 2 + .5) ^ .5) / 2 + .5)


  for _,d in ipairs(self.drawables) do
    if d.texture then
      love.graphics.push()

      local px, py = AnimationLoader.anchorOffset(d, d.pivot)
      local wx, wy, wrot, wscale = AnimationLoader.worldTransform(d)

      love.graphics.setColor(1,1,1,d.alpha)
      love.graphics.translate(wx, wy)
      love.graphics.translate(px, py)
      love.graphics.rotate(wrot)
      love.graphics.scale(wscale, wscale)
      love.graphics.translate(-px, -py)
      love.graphics.draw(d.texture, 0, 0)

      love.graphics.pop()
    end
  end
end

return TitleScreen