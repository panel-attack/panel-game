local NavigationStack = require("client.src.NavigationStack")
local Scene = require("client.src.scenes.Scene")
local Transition = require("client.src.scenes.Transitions.Transition")
local class = require("common.lib.class")

local SceneOverridingUpdate = class(function(self)
end, Scene)

function SceneOverridingUpdate:update(dt)
end

local function testActiveSceneAnimatorRunsWhenTheSceneOverridesUpdate()
  local scene = SceneOverridingUpdate()
  local target = {value = 0}
  scene.animator:to(target, 1, {value = 1}):ease("linear")
  local navigationStack = NavigationStack({})
  navigationStack.scenes = {scene}

  navigationStack:updateSelf(0.5)

  assert(math.abs(target.value - 0.5) < 0.0001, "the active scene's animator should advance, got " .. target.value)
end

local function testActiveSceneAnimationPlaysWhenTheSceneOverridesUpdate()
  local scene = SceneOverridingUpdate()
  local playedOn
  scene.sceneAnimation = {play = function(_, animator) playedOn = animator end}
  local navigationStack = NavigationStack({})
  navigationStack.scenes = {scene}

  navigationStack:updateSelf(0.5)

  assert(playedOn == scene.animator, "the active scene's animation should play on the scene's animator")
end

local function testTheSceneOnTopIsLaidOut()
  local below, top = Scene({}), Scene({})
  local navigationStack = NavigationStack({})
  navigationStack.scenes = {below, top}

  navigationStack:layOutScenes()

  assert(not top.uiRoot.layoutDirty and top.uiRoot.layoutRect.width > 0, "the scene on top should be laid out")
  assert(below.uiRoot.layoutDirty, "a scene that isn't shown waits for its next turn on top")
end

local function testATransitionIsLaidOutWithBothItsScenes()
  local oldScene, newScene = Scene({}), Scene({})
  local transition = Transition(0, 1)
  transition.oldScene, transition.newScene = oldScene, newScene
  local navigationStack = NavigationStack({})
  navigationStack.scenes = {newScene}
  navigationStack.transition = transition

  navigationStack:layOutScenes()

  for name, root in pairs({transition = transition.uiRoot, old = oldScene.uiRoot, new = newScene.uiRoot}) do
    assert(not root.layoutDirty, "the " .. name .. " ui should be laid out")
  end
end

local function testDrawingASceneBeforeItsLayoutIsAnError()
  local scene = Scene({})
  local ok, err = pcall(scene.draw, scene)
  assert(not ok and tostring(err):find("a scene is drawn before its ui is laid out"), "drawing gave " .. tostring(err))
  scene:layOut()
  scene:draw()
end

testActiveSceneAnimatorRunsWhenTheSceneOverridesUpdate()
testActiveSceneAnimationPlaysWhenTheSceneOverridesUpdate()
testTheSceneOnTopIsLaidOut()
testATransitionIsLaidOutWithBothItsScenes()
testDrawingASceneBeforeItsLayoutIsAnError()
