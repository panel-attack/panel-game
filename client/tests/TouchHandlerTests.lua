local touchHandler = require("client.src.ui.touchHandler")
local ui = require("client.src.ui")
local Layout = require("client.src.ui.Layout")
local NavigationStack = require("client.src.NavigationStack")
local Scene = require("client.src.scenes.Scene")
local logger = require("common.lib.logger")

-- Returns a size by size element, floating at x, y in its parent when given a place
---@param size number
---@param x number?
---@param y number?
---@return UiElement
local function square(size, x, y)
  local floating = x and Layout.floatAt("leftTop", x, y) or nil
  return ui.UiElement({layoutRules = {sizing = Layout.fixedSize(size, size), floating = floating}})
end

-- Lays out the game's tree, holder included, as the frame before a touch does
local function layOut()
  GAME.uiRoot:layOut()
end

-- Runs the test with a 200 by 200 holder on top of everything at 100, 100, taking it away and ending the touch afterwards
---@param test fun(holder: UiElement)
local function withHolder(test)
  local holder = square(200, 100, 100)
  GAME.uiRoot:addChild(holder)
  local ok, err = pcall(test, holder)
  touchHandler:release(0, 0)
  holder:detach()
  if not ok then
    error(err, 0)
  end
end

-- Returns an element in the holder at the given place, recording each touch event it handles in calls
---@param parent UiElement
---@param x number
---@param y number
---@param events string[] the touch events it handles, such as onTouch and onRelease
---@param calls string[] where the events it receives are recorded, as "<name> <event> <x> <y>"
---@param name string
---@return UiElement
local function recordingElement(parent, x, y, events, calls, name)
  local element = square(50, x, y)
  for _, event in ipairs(events) do
    element[event] = function(_, eventX, eventY)
      calls[#calls + 1] = string.format("%s %s %g %g", name, event, eventX or 0, eventY or 0)
    end
  end
  parent:addChild(element)
  return element
end

local function assertCalls(calls, expected)
  local message = "received\n  " .. table.concat(calls, "\n  ") .. "\nexpected\n  " .. table.concat(expected, "\n  ")
  assert(#calls == #expected, message)
  for i = 1, #expected do
    assert(calls[i] == expected[i], message)
  end
end

local function testATouchGoesToTheTopmostElementUnderIt()
  withHolder(function(holder)
    local calls = {}
    recordingElement(holder, 0, 0, {"onTouch"}, calls, "below")
    recordingElement(holder, 20, 20, {"onTouch"}, calls, "above")
    layOut()
    touchHandler:touch(130, 130)

    assertCalls(calls, {"above onTouch 130 130"})
  end)
  logger.trace("passed test testATouchGoesToTheTopmostElementUnderIt")
end

local function testAChildOutsideAParentThatDoesNotClipIsHit()
  withHolder(function(holder)
    local calls = {}
    recordingElement(holder, 250, 0, {"onTouch"}, calls, "outside")
    layOut()
    touchHandler:touch(360, 110)

    assertCalls(calls, {"outside onTouch 360 110"})
  end)
  logger.trace("passed test testAChildOutsideAParentThatDoesNotClipIsHit")
end

local function testAChildInTheFlowOutsideAParentThatClipsIsNotHit()
  withHolder(function(holder)
    local calls = {}
    holder:setLayoutRule("clip", {horizontal = true})
    holder:setLayoutRule("padding", {left = 250})
    local child = square(50)
    child.onTouch = function()
      calls[#calls + 1] = "cut off"
    end
    holder:addChild(child)
    layOut()
    touchHandler:touch(360, 110)

    assertCalls(calls, {})
  end)
  logger.trace("passed test testAChildInTheFlowOutsideAParentThatClipsIsNotHit")
end

local function testAFloatingChildOfAParentThatClipsIsHitOutsideItAndOverTheChildrenInItsFlow()
  withHolder(function(holder)
    local calls = {}
    holder:setLayoutRule("clip", {horizontal = true})
    recordingElement(holder, 150, 0, {"onTouch"}, calls, "floating")
    local inFlow = square(200)
    inFlow.onTouch = function()
      calls[#calls + 1] = "in flow"
    end
    holder:addChild(inFlow)
    recordingElement(holder, 250, 0, {"onTouch"}, calls, "outside")
    layOut()
    touchHandler:touch(260, 110)
    touchHandler:release(260, 110)
    touchHandler:touch(360, 110)

    assertCalls(calls, {"floating onTouch 260 110", "outside onTouch 360 110"})
  end)
  logger.trace("passed test testAFloatingChildOfAParentThatClipsIsHitOutsideItAndOverTheChildrenInItsFlow")
end

local function testATouchTheElementDoesNotHandleGoesToItsParent()
  withHolder(function(holder)
    local calls = {}
    local parent = recordingElement(holder, 0, 0, {"onTouch"}, calls, "parent")
    parent:setFixedSize(200, 200)
    recordingElement(parent, 10, 10, {"onRelease"}, calls, "child")
    layOut()
    touchHandler:touch(120, 120)

    assertCalls(calls, {"parent onTouch 120 120"})
  end)
  logger.trace("passed test testATouchTheElementDoesNotHandleGoesToItsParent")
end

local function testTheTouchedElementIsPressedUntilReleased()
  withHolder(function(holder)
    local element = recordingElement(holder, 0, 0, {"onRelease"}, {}, "button")
    layOut()
    touchHandler:touch(110, 110)
    assert(element:hasState("pressed"), "the element under the touch is pressed")
    touchHandler:release(110, 110)

    assert(not element:hasState("pressed"), "a released element is not pressed")
  end)
  logger.trace("passed test testTheTouchedElementIsPressedUntilReleased")
end

local function testAShortDragStillReleasesOnTheTouchedElement()
  withHolder(function(holder)
    local calls = {}
    local scroller = recordingElement(holder, 0, 0, {"onTouch", "onDrag", "onRelease"}, calls, "scroller")
    scroller:setFixedSize(200, 200)
    recordingElement(scroller, 0, 0, {"onRelease"}, calls, "button")
    layOut()
    touchHandler:touch(110, 110)
    touchHandler:drag(113, 112)
    touchHandler:release(113, 112)

    assertCalls(calls, {"scroller onTouch 110 110", "button onRelease 113 112"})
  end)
  logger.trace("passed test testAShortDragStillReleasesOnTheTouchedElement")
end

-- A parent that drags is told where the touch started when it takes over a touch a child took
local function testALongDragHandsTheTouchToTheParentThatDrags()
  withHolder(function(holder)
    local calls = {}
    local scroller = recordingElement(holder, 0, 0, {"onTouch", "onDrag", "onRelease"}, calls, "scroller")
    scroller:setFixedSize(200, 200)
    recordingElement(scroller, 0, 0, {"onTouch", "onRelease"}, calls, "button")
    layOut()
    touchHandler:touch(110, 110)
    touchHandler:drag(110, 140)
    touchHandler:release(110, 150)

    assertCalls(calls, {
      "button onTouch 110 110",
      "scroller onTouch 110 110",
      "scroller onDrag 110 140",
      "scroller onRelease 110 150",
    })
  end)
  logger.trace("passed test testALongDragHandsTheTouchToTheParentThatDrags")
end

local function testALongDragGoesToTheNearestParentThatDrags()
  withHolder(function(holder)
    local calls = {}
    local scroller = recordingElement(holder, 0, 0, {"onTouch", "onDrag", "onRelease"}, calls, "scroller")
    scroller:setFixedSize(200, 200)
    local button = recordingElement(scroller, 0, 0, {"onRelease"}, calls, "button")
    layOut()
    touchHandler:touch(110, 110)
    touchHandler:drag(110, 140)
    assert(not button:hasState("pressed"), "a button dragged off is no longer pressed")
    touchHandler:release(110, 150)

    assertCalls(calls, {
      "scroller onTouch 110 110",
      "scroller onDrag 110 140",
      "scroller onRelease 110 150",
    })
  end)
  logger.trace("passed test testALongDragGoesToTheNearestParentThatDrags")
end

local function testAnElementThatDragsGetsEveryDrag()
  withHolder(function(holder)
    local calls = {}
    recordingElement(holder, 0, 0, {"onTouch", "onDrag", "onRelease"}, calls, "slider")
    layOut()
    touchHandler:touch(110, 110)
    touchHandler:drag(112, 110)
    touchHandler:release(112, 110)

    assertCalls(calls, {"slider onTouch 110 110", "slider onDrag 112 110", "slider onRelease 112 110"})
  end)
  logger.trace("passed test testAnElementThatDragsGetsEveryDrag")
end

local function testATouchSelectsTheChildInAParentThatSelects()
  withHolder(function(holder)
    local selected
    local list = square(200)
    list.selectChild = function(_, child)
      selected = child
    end
    holder:addChild(list)
    local row = ui.UiElement({layoutRules = {sizing = Layout.fixedSize(200, 50)}})
    list:addChild(row)
    recordingElement(row, 0, 0, {"onRelease"}, {}, "switch")
    layOut()
    touchHandler:touch(110, 110)

    assert(selected == row, "the list should select the row the touch is in")
  end)
  logger.trace("passed test testATouchSelectsTheChildInAParentThatSelects")
end

local function testATouchOnAnElementHiddenSinceReleasesNothing()
  withHolder(function(holder)
    local calls = {}
    local element = recordingElement(holder, 0, 0, {"onDrag", "onRelease"}, calls, "button")
    layOut()
    touchHandler:touch(110, 110)
    holder:setVisibility(false)
    touchHandler:drag(130, 130)
    touchHandler:release(130, 130)

    assertCalls(calls, {})
    assert(not element:hasState("pressed"), "the touch should still end")
  end)
  logger.trace("passed test testATouchOnAnElementHiddenSinceReleasesNothing")
end

-- The navigation stack is disabled while a transition runs
local function testATouchOnAnElementUnderAParentDisabledSinceReleasesNothing()
  withHolder(function(holder)
    local calls = {}
    recordingElement(holder, 0, 0, {"onRelease", "onHold"}, calls, "button")
    layOut()
    touchHandler:touch(110, 110)
    holder.isEnabled = false
    touchHandler:update(1)
    touchHandler:release(110, 110)

    assertCalls(calls, {})
  end)
  logger.trace("passed test testATouchOnAnElementUnderAParentDisabledSinceReleasesNothing")
end

local function testAnElementOfTheSceneOnScreenIsHitThroughTheGamesTree()
  local calls = {}
  ---@class TouchedScene : Scene
  local scene = Scene({})
  scene.name = "TouchedScene"
  recordingElement(scene.uiRoot, 600, 600, {"onTouch"}, calls, "in scene")
  local navigationStack = NavigationStack({})
  -- over the game's own stack rather than beside it
  navigationStack:setLayoutRule("floating", Layout.floatAt("leftTop"))
  navigationStack:push(scene)
  navigationStack:updateSelf(1 / 60)
  GAME.uiRoot:addChild(navigationStack)
  layOut()
  touchHandler:touch(610, 610)
  touchHandler:release(610, 610)
  navigationStack:detach()

  assertCalls(calls, {"in scene onTouch 610 610"})
  logger.trace("passed test testAnElementOfTheSceneOnScreenIsHitThroughTheGamesTree")
end

local function testAClippingElementWithNothingToScrollTakesNoTouch()
  withHolder(function(holder)
    local calls = {}
    recordingElement(holder, 0, 0, {"onTouch"}, calls, "below")
    local clipping = square(50, 0, 0)
    clipping:setLayoutRule("clip", {vertical = true})
    holder:addChild(clipping)
    layOut()
    touchHandler:touch(110, 110)

    assertCalls(calls, {"below onTouch 110 110"})
  end)
  logger.trace("passed test testAClippingElementWithNothingToScrollTakesNoTouch")
end

testATouchGoesToTheTopmostElementUnderIt()
testAnElementOfTheSceneOnScreenIsHitThroughTheGamesTree()
testAClippingElementWithNothingToScrollTakesNoTouch()
testAChildOutsideAParentThatDoesNotClipIsHit()
testAChildInTheFlowOutsideAParentThatClipsIsNotHit()
testAFloatingChildOfAParentThatClipsIsHitOutsideItAndOverTheChildrenInItsFlow()
testATouchTheElementDoesNotHandleGoesToItsParent()
testTheTouchedElementIsPressedUntilReleased()
testAShortDragStillReleasesOnTheTouchedElement()
testALongDragGoesToTheNearestParentThatDrags()
testALongDragHandsTheTouchToTheParentThatDrags()
testAnElementThatDragsGetsEveryDrag()
testATouchSelectsTheChildInAParentThatSelects()
testATouchOnAnElementHiddenSinceReleasesNothing()
testATouchOnAnElementUnderAParentDisabledSinceReleasesNothing()
