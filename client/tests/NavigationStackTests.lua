local NavigationStack = require("client.src.NavigationStack")
local Scene = require("client.src.scenes.Scene")
local class = require("common.lib.class")

local SceneOverridingUpdate = class(function(self)
end, Scene)

function SceneOverridingUpdate:update(dt)
end

local function testActiveSceneTweensRunWhenTheSceneOverridesUpdate()
  local scene = SceneOverridingUpdate()
  local target = {value = 0}
  scene.tweens:to(target, 1, {value = 1}):ease("linear")
  local navigationStack = NavigationStack({})
  navigationStack.scenes = {scene}

  navigationStack:updateSelf(0.5)

  assert(math.abs(target.value - 0.5) < 0.0001, "the active scene's tweens should advance, got " .. target.value)
end

testActiveSceneTweensRunWhenTheSceneOverridesUpdate()
