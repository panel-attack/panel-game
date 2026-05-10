local Scene = require("client.src.scenes.Scene")
local consts = require("common.engine.consts")
local input = require("client.src.inputManager")
local tableUtils = require("common.lib.tableUtils")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local MainMenu = require("client.src.scenes.MainMenu")

-- The title screen scene
local TitleScreen = class(
  function (self, sceneParams)
    self.backgroundImg = themes[config.theme].images.bg_title
    self.music = "title_screen"
  end,
  Scene
)

TitleScreen.name = "TitleScreen"

local function titleDrawPressStart(percent)
  local textMaxWidth = consts.CANVAS_WIDTH - 40
  local textHeight = 40
  local x = (consts.CANVAS_WIDTH / 2) - (textMaxWidth / 2)
  local y = consts.CANVAS_HEIGHT * 0.75
  GraphicsUtil.printf(loc("continue_button"), x, y, textMaxWidth, "center", {1,1,1,percent}, nil, 16)
end

local function drawCustomTitleLogo(image)
  local imageWidth, imageHeight = image:getDimensions()
  local maxWidth = 420
  local maxHeight = 260
  local scale = math.min(maxWidth / imageWidth, maxHeight / imageHeight)
  local drawWidth = imageWidth * scale
  local drawHeight = imageHeight * scale
  local x = (consts.CANVAS_WIDTH - drawWidth) / 2
  local y = 70

  -- Draw a subtle backing plate so the replacement logo cleanly covers baked-in title logos.
  GraphicsUtil.drawRectangle("fill", x - 12, y - 12, drawWidth + 24, drawHeight + 24, 0, 0, 0, 0.78)
  GraphicsUtil.drawRectangle("line", x - 12, y - 12, drawWidth + 24, drawHeight + 24, 1, 1, 1, 0.2)
  GraphicsUtil.draw(image, x, y, 0, scale, scale)
end

function TitleScreen:update(dt)
  self.backgroundImg:update(dt)
  local keyPressed = tableUtils.trueForAny(input.allKeys.isDown, function(key) return key end)
  if love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 or keyPressed then
    GAME.theme:playValidationSfx()
    GAME.navigationStack:replace(MainMenu())
  end
end

function TitleScreen:draw()
  self.backgroundImg:draw()
  if GAME.theme.images.unofficial_brand_square then
    drawCustomTitleLogo(GAME.theme.images.unofficial_brand_square)
  end
  titleDrawPressStart(((math.sin(5 * love.timer.getTime()) / 2 + .5) ^ .5) / 2 + .5)
end

return TitleScreen