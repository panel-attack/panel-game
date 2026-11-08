local Scene = require("client.src.scenes.Scene")
local consts = require("common.engine.consts")
local input = require("client.src.inputManager")
local tableUtils = require("common.lib.tableUtils")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local MainMenu = require("client.src.scenes.MainMenu")
local SceneAnimation = require("client.src.graphics.SceneAnimation")
local Theme = require("client.src.mods.Theme")

local START_OPACITY = 0.5

-- The title screen scene, drawing the theme's title image and its title scene on top, each only if the theme has it
local TitleScreen = class(
  function (self, sceneParams)
    local theme = themes[config.theme]
    self.backgroundImg = theme.images.bg_title
    if theme:hasScene(Theme.TITLE_SCENE_FILE) then
      self.sceneAnimation = SceneAnimation(Theme.TITLE_SCENE_FILE)
    end
    self.music = "title_screen"
    self.opacity = START_OPACITY
    self.direction = 1
    self:startAnimation()
  end,
  Scene
)

function TitleScreen:startAnimation()
  local target = START_OPACITY
  if self.direction == 1 then
    target = 1
  end

  self.tweens:to(self, 0.6, { opacity = target })
      :ease("quadinout")
      :oncomplete(function()
          self.direction = -self.direction
          self:startAnimation()
      end)
end

TitleScreen.name = "TitleScreen"

function TitleScreen:titleDrawPressStart()
  local textMaxWidth = consts.CANVAS_WIDTH - 40
  local x = (consts.CANVAS_WIDTH / 2) - (textMaxWidth / 2)
  local y = consts.CANVAS_HEIGHT * 0.75
  GraphicsUtil.printf(loc("continue_button"), x, y, textMaxWidth, "center", {1,1,1,self.opacity}, nil, 16)
end

function TitleScreen:update(dt)
  if self.backgroundImg then
    self.backgroundImg:update(dt)
  end
  local keyPressed = tableUtils.trueForAny(input.allKeys.isDown, function(key) return key end)
  if love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 or keyPressed then
    GAME.theme:playValidationSfx()
    -- a direction held from here would otherwise keep scrolling the main menu
    input:ignoreHeldKeysUntilReleased()
    GAME.navigationStack:replace(MainMenu())
  end
end

function TitleScreen:draw()
  if self.backgroundImg then
    self.backgroundImg:draw()
  end
  if self.sceneAnimation then
    self.sceneAnimation:draw()
  end
  self:titleDrawPressStart()
end

return TitleScreen