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

local drawables = {}   -- flat list after recursion ✔ draw-order sorts once

local function anchorOffset(drawable, anchor)
  local w, h = drawable.width, drawable.height
  local map = {
    topLeft={0,0}, topCenter={w/2,0}, topRight={w,0},
    centerLeft={0,h/2}, center={w/2,h/2}, centerRight={w,h/2},
    bottomLeft={0,h}, bottomCenter={w/2,h}, bottomRight={w,h}
  }
  return (map[anchor])[1], (map[anchor])[2]
end

local function buildTrack(target, track)
  local prev
  for i,step in ipairs(track.steps) do
    local tween
    if i == 1 then
      tween = Flux.to(target, step.durationSeconds,
                              step.animateProperties)
    else
      tween = tween:after(target,
                                            step.durationSeconds,
                                            step.animateProperties)
    end
    tween:ease(step.easeType):delay(step.delaySeconds or 0)
    if step.yoyo then
      local rev = {}
      for k in pairs(step.animateProperties) do rev[k] = target[k] end
      tween = tween:after(target, step.durationSeconds, rev):ease(step.easeType)
    end
    prev = tween
  end
  if track.loopTrack then
    prev:oncomplete(function() buildTrack(target, track) end)
  end
end

local function loadNode(node, parent)
  local obj = {
    id       = node.id,
    parent   = parent,
    x        = node.localPosition and node.localPosition.x or 0,
    y        = node.localPosition and node.localPosition.y or 0,
    width    = node.size and node.size.width or 0,
    height   = node.size and node.size.height or 0,
    rotation = node.initialRotation or 0,
    scale    = node.initialScale or 1,
    alpha    = 1,
    layer    = node.layer or 0,
    anchor   = node.anchor or "center",
    pivot    = node.pivot or "center"
  }
  if node.filePath then
    local texture = GraphicsUtil.loadImageFromSupportedExtensions(scenePath .. node.filePath)
    if texture then
      obj.texture = texture
      obj.width = texture:getWidth()
      obj.height = texture:getHeight()
    end
  end
  table.insert(drawables, obj)

  for _,track in ipairs(node.animationTracks or {}) do buildTrack(obj, track) end
  for _,child in ipairs(node.children or {}) do loadNode(child, obj) end
end

loadNode(spriteData, nil)
table.sort(drawables, function(a,b) return a.layer < b.layer end)

local function objectTransform(obj)
  local ax, ay = anchorOffset(obj, obj.anchor)
  return obj.x - ax, obj.y - ay, obj.rotation, obj.scale
end

local function worldTransform(obj)
  if not obj.parent then
    return objectTransform(obj)
  end
  local px, py, prot, pscale = worldTransform(obj.parent)
  local ox, oy, oprot, oscale = objectTransform(obj)
  return px + ox, py + oy, prot + oprot, pscale * oscale
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
  -- local keyPressed = tableUtils.trueForAny(input.allKeys.isDown, function(key) return key end)
  -- if love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 or keyPressed then
  --   GAME.theme:playValidationSfx()
  --   self.animation:stop()
  --   GAME.navigationStack:replace(MainMenu())
  -- end
end

function TitleScreen:draw()
  -- self.backgroundImg:draw()
  self:titleDrawPressStart(((math.sin(5 * love.timer.getTime()) / 2 + .5) ^ .5) / 2 + .5)

  for _,d in ipairs(drawables) do
    if d.texture then
      local px, py = anchorOffset(d, d.pivot)
      local wx, wy, wrot, wscale = worldTransform(d)

      love.graphics.push()

      love.graphics.setColor(1,1,1,d.alpha)

      love.graphics.translate(wx, wy)

      -- 2) shift so *pivot* becomes the origin
      love.graphics.translate(px, py)

      -- 3) apply rotation & scale around that pivot
      love.graphics.rotate(wrot)
      love.graphics.scale(wscale, wscale)

      -- 4) shift back, then draw so (0,0) is sprite top-left
      love.graphics.translate(-px, -py)
      love.graphics.draw(d.texture, 0, 0)

      love.graphics.pop()
    end
  end
end

return TitleScreen