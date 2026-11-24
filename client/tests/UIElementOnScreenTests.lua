local NavigationStack = require("client.src.NavigationStack")
local Scene = require("client.src.scenes.Scene")
local UIElement = require("client.src.ui.UIElement")
local BlackFadeTransition = require("client.src.scenes.Transitions.BlackFadeTransition")
local MessageTransition = require("client.src.scenes.Transitions.MessageTransition")
local Easings = require("client.src.Easings")

-- A scene with its own name, as the navigation stack replaces rather than pushes a scene of the same name
---@param name string
---@return Scene
local function namedScene(name)
  ---@class OnScreenTestScene : Scene
  local scene = Scene({})
  scene.name = name
  return scene
end

-- A scene with an element two levels down its ui tree
---@param name string
---@return Scene scene
---@return UiElement container the child of the scene's root
---@return UiElement element the child of container
local function sceneWithElement(name)
  local scene = namedScene(name)
  local container = UIElement({})
  local element = UIElement({})
  scene.uiRoot:addChild(container)
  container:addChild(element)
  return scene, container, element
end

-- Returns a navigation stack that has pushed the given scenes in order, the last one on top, with each push finished
---@param ... Scene
---@return NavigationStack
local function stackWithScenes(...)
  local navigationStack = NavigationStack({})
  for _, scene in ipairs({...}) do
    navigationStack:push(scene)
    navigationStack:updateSelf(1 / 60)
  end
  return navigationStack
end

local function testElementOfTheSceneOnTopIsOnScreen()
  local scene, _, element = sceneWithElement("Only")
  stackWithScenes(scene)
  assert(scene:isOnScreen(), "the scene on top should be on screen")
  assert(element:isOnScreen(), "an element of the scene on top should be on screen")
end

local function testElementUnderAHiddenAncestorIsNotOnScreen()
  local scene, container, element = sceneWithElement("Only")
  stackWithScenes(scene)
  container:setVisibility(false)
  assert(element.isVisible, "hiding the parent should leave the child's own visibility alone")
  assert(not element:isOnScreen(), "an element under a hidden parent should not be on screen")
  container:setVisibility(true)
  element:setVisibility(false)
  assert(not element:isOnScreen(), "a hidden element should not be on screen")
end

local function testSceneUnderAnotherSceneIsNotOnScreen()
  local lowerScene, _, element = sceneWithElement("Lower")
  stackWithScenes(lowerScene, namedScene("Upper"))
  assert(not lowerScene:isOnScreen(), "a scene under another one should not be on screen")
  assert(not element:isOnScreen(), "an element of a scene under another one should not be on screen")
end

local function testSceneNotYetPushedIsNotOnScreen()
  local scene, _, element = sceneWithElement("Loaded")
  assert(not scene:isOnScreen(), "a scene not yet pushed should not be on screen")
  assert(not element:isOnScreen(), "an element of a scene not yet pushed should not be on screen")
end

local function testPopShowsTheSceneBelowAndHidesThePoppedOne()
  local lowerScene, _, lowerElement = sceneWithElement("Lower")
  local upperScene, _, upperElement = sceneWithElement("Upper")
  local navigationStack = stackWithScenes(lowerScene, upperScene)
  navigationStack:pop()
  navigationStack:updateSelf(1 / 60)
  assert(lowerElement:isOnScreen(), "the scene a pop returns to should be on screen")
  assert(not upperElement:isOnScreen(), "a popped scene should not be on screen")
end

local function testElementBesideTheNavigationStackIsOnScreen()
  local navigationStack = stackWithScenes(namedScene("Only"))
  local gameRoot = UIElement({})
  local notification = UIElement({})
  gameRoot:addChild(navigationStack)
  gameRoot:addChild(notification)
  assert(notification:isOnScreen(), "an element in the tree the navigation stack is drawn in should be on screen")
end

local function testFadeShowsTheOldSceneThenTheNewOne()
  local oldScene, _, oldElement = sceneWithElement("Old")
  local newScene, _, newElement = sceneWithElement("New")
  local navigationStack = stackWithScenes(oldScene)
  navigationStack:push(newScene, BlackFadeTransition(0, 1, Easings.getSineIn()))
  navigationStack:updateSelf(0.25)
  assert(oldElement:isOnScreen() and not newElement:isOnScreen(), "the first half of a fade should show the old scene only")
  navigationStack:updateSelf(0.5)
  assert(newElement:isOnScreen() and not oldElement:isOnScreen(), "the second half of a fade should show the new scene only")
end

local function testMessageTransitionShowsNeitherScene()
  local oldScene = namedScene("Old")
  local newScene = namedScene("New")
  local navigationStack = stackWithScenes(oldScene)
  navigationStack:push(newScene, MessageTransition(0, 1, "loading", false))
  navigationStack:updateSelf(0.1)
  assert(not oldScene:isOnScreen() and not newScene:isOnScreen(), "a message transition should show neither scene")
  assert(navigationStack.transition.label:isOnScreen(), "a message transition should show its message")
end

local function testElementSoundsPlayOnlyOnScreen()
  local lowerScene, _, element = sceneWithElement("Lower")
  local theme = GAME.theme
  local originals = {theme.playValidationSfx, theme.playMoveSfx, theme.playCancelSfx}
  local count = 0
  local function countSound()
    count = count + 1
  end
  theme.playValidationSfx, theme.playMoveSfx, theme.playCancelSfx = countSound, countSound, countSound

  local ok, err = pcall(function()
    local navigationStack = stackWithScenes(lowerScene, namedScene("Upper"))
    element:playMoveSfx()
    element:playValidationSfx()
    lowerScene:playCancelSfx()
    assert(count == 0, count .. " sounds played from a scene under another one")
    navigationStack:pop()
    navigationStack:updateSelf(1 / 60)
    element:playMoveSfx()
    element:playValidationSfx()
    lowerScene:playCancelSfx()
    assert(count == 3, count .. " sounds played from the scene on top instead of 3")
  end)

  theme.playValidationSfx, theme.playMoveSfx, theme.playCancelSfx = originals[1], originals[2], originals[3]
  assert(ok, err)
end

testElementOfTheSceneOnTopIsOnScreen()
testElementUnderAHiddenAncestorIsNotOnScreen()
testSceneUnderAnotherSceneIsNotOnScreen()
testSceneNotYetPushedIsNotOnScreen()
testPopShowsTheSceneBelowAndHidesThePoppedOne()
testElementBesideTheNavigationStackIsOnScreen()
testFadeShowsTheOldSceneThenTheNewOne()
testMessageTransitionShowsNeitherScene()
testElementSoundsPlayOnlyOnScreen()
