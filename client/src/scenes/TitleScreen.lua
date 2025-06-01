local Scene = require("client.src.scenes.Scene")
local consts = require("common.engine.consts")
local input = require("client.src.inputManager")
local tableUtils = require("common.lib.tableUtils")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local MainMenu = require("client.src.scenes.MainMenu")
local AnimationLoader = require("client.src.graphics.AnimationLoader")
local Flux = require("client.lib.flux.flux")

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
  local keyPressed = tableUtils.trueForAny(input.allKeys.isDown, function(key) return key end)
  if love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 or keyPressed then
    GAME.theme:playValidationSfx()
    self.animation:stop()
    GAME.navigationStack:replace(MainMenu())
  end
end

local alphaDiscardShader = love.graphics.newShader([[
    vec4 effect(vec4 tintColor, Image tex, vec2 texCoord, vec2 screenCoord)
    {
        vec4 pixelColor = Texel(tex, texCoord);

        // throw away fragments whose final alpha would be zero
        if (pixelColor.a * tintColor.a <= 0.0)
        {
            discard;
        }

        return vec4(0.0);         // colour does not matter in stencil pass
    }
]])

function TitleScreen:drawNode(d, parent)
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
            self:drawNode(sibling, nil)
          end
          love.graphics.setShader()
        end, "replace", 1, false)
        love.graphics.setStencilTest("equal", 1)
      end
      
      love.graphics.setBlendMode(d.blendMode, d.alphaMode)
      love.graphics.setColor(d.tint[1], d.tint[2], d.tint[3], d.alpha)
      love.graphics.draw(d.texture, 0, 0)
      love.graphics.setStencilTest()
    end

    for _, child in ipairs(d.children) do
      self:drawNode(child, d)
    end

    love.graphics.pop()
end

function TitleScreen:draw()
  self.backgroundImg:draw()
  self:titleDrawPressStart(((math.sin(5 * love.timer.getTime()) / 2 + .5) ^ .5) / 2 + .5)

  for _,d in ipairs(self.drawables) do
    self:drawNode(d)
  end
end

return TitleScreen