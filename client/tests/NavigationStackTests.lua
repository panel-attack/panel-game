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

---@param name string
---@return Scene
local function namedScene(name)
  ---@class NamedScene : Scene
  local scene = Scene({})
  scene.name = name
  return scene
end

local function testTheSceneOnTopIsInTheStacksTreeAndLaidOutWithIt()
  local below, top = namedScene("Below"), namedScene("Top")
  local navigationStack = NavigationStack({})
  navigationStack:push(below)
  navigationStack:updateSelf(1 / 60)
  navigationStack:push(top)
  navigationStack:updateSelf(1 / 60)

  navigationStack:layOut()

  assert(top.uiRoot.parent == navigationStack, "the scene on top should be a child of the navigation stack")
  assert(not top.uiRoot.layoutDirty and top.uiRoot.layoutRect.width > 0, "the scene on top should be laid out")
  assert(below.uiRoot.parent == nil and below.uiRoot.layoutDirty, "a scene that isn't shown waits for its next turn on top")
end

local function testATransitionIsLaidOutWithBothItsScenes()
  local oldScene, newScene = namedScene("Old"), namedScene("New")
  local transition = Transition(0, 1)
  local navigationStack = NavigationStack({})
  navigationStack:push(oldScene)
  navigationStack:updateSelf(1 / 60)
  navigationStack:push(newScene, transition)

  navigationStack:layOut()

  for name, root in pairs({transition = transition.uiRoot, old = oldScene.uiRoot, new = newScene.uiRoot}) do
    assert(root.parent == navigationStack and not root.layoutDirty, "the " .. name .. " ui should be laid out")
  end
end

local function testAFinishedTransitionLeavesOnlyTheSceneOnTopInTheTree()
  local oldScene, newScene = namedScene("Old"), namedScene("New")
  local navigationStack = NavigationStack({})
  navigationStack:push(oldScene)
  navigationStack:updateSelf(1 / 60)
  navigationStack:replace(newScene, Transition(0, 1))

  navigationStack:updateSelf(2)

  assert(#navigationStack.children == 1 and navigationStack.children[1] == newScene.uiRoot, "only the new scene stays in the tree")
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
testTheSceneOnTopIsInTheStacksTreeAndLaidOutWithIt()
testATransitionIsLaidOutWithBothItsScenes()
testAFinishedTransitionLeavesOnlyTheSceneOnTopInTheTree()
testDrawingASceneBeforeItsLayoutIsAnError()
