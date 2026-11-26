local ScrollContainer = require("client.src.ui.ScrollContainer")
local Slider = require("client.src.ui.Slider")
local UiElement = require("client.src.ui.UIElement")
local Layout = require("client.src.ui.Layout")
local touchHandler = require("client.src.ui.touchHandler")
local logger = require("common.lib.logger")

local function box(width, height)
  return UiElement({layoutRules = {sizing = Layout.fixedSize(width, height)}})
end

-- Returns a 100 pixel high container holding content 400 pixels high, laid out
local function createContainer()
  local container = ScrollContainer({layoutRules = {sizing = Layout.fixedSize(100, 100)}})
  container:addChild(box(100, 400))
  container:layOut()
  return container
end

local function testHorizontalContainerScrollsSideways()
  local container = ScrollContainer({layoutRules = {sizing = Layout.fixedSize(100, 100)}, scrollOrientation = "horizontal"})
  container:addChild(box(400, 100))
  container:layOut()
  container:scrollBy(-40, -40)
  assert(container.scrollX == -40 and container.scrollY == 0, "scrolled to " .. container.scrollX .. ", " .. container.scrollY)
  logger.trace("passed test testHorizontalContainerScrollsSideways")
end

local function testSetContentReplacesTheChildAndLowersTheScrollLimit()
  local container = createContainer()
  container:setScroll(0, -300)
  local content = box(100, 150)
  container:setContent(content)
  container:layOut()
  assert(#container.children == 1 and container.children[1] == content, "the content is the only child")
  local _, maxY = container:getMaxScroll()
  assert(maxY == 50, "max scroll " .. maxY)
  assert(container.scrollY == -50, "scrolled to " .. container.scrollY)
  logger.trace("passed test testSetContentReplacesTheChildAndLowersTheScrollLimit")
end

-- Returns the container laid out in the game's ui tree at 500, 500, and the element holding it there
---@return ScrollContainer container
---@return UiElement holder
local function createContainerOnScreen()
  local holder = UiElement({
    layoutRules = {sizing = Layout.fixedSize(100, 100), floating = Layout.floatAt("leftTop", 500, 500)}
  })
  local container = createContainer()
  holder:addChild(container)
  GAME.uiRoot:addChild(holder)
  GAME.uiRoot:layOut()
  return container, holder
end

local function testWheelDownScrollsOneStep()
  local container, holder = createContainerOnScreen()
  touchHandler:scroll(550, 550, 0, -1)
  holder:detach()
  assert(container.scrollY == -touchHandler.WHEEL_SCROLL_STEP, "scrolled to " .. container.scrollY)
  logger.trace("passed test testWheelDownScrollsOneStep")
end

local function testWheelUpStopsAtTheTop()
  local container, holder = createContainerOnScreen()
  touchHandler:scroll(550, 550, 0, 1)
  holder:detach()
  assert(container.scrollY == 0, "scrolled to " .. container.scrollY)
  logger.trace("passed test testWheelUpStopsAtTheTop")
end

local function testWheelDownStopsAtTheBottom()
  local container, holder = createContainerOnScreen()
  touchHandler:scroll(550, 550, 0, -100)
  holder:detach()
  assert(container.scrollY == -300, "scrolled to " .. container.scrollY)
  logger.trace("passed test testWheelDownStopsAtTheBottom")
end

local function testWheelScrollsWithoutALayout()
  local _, holder = createContainerOnScreen()
  touchHandler:scroll(550, 550, 0, -1)
  local stayedLaidOut = not GAME.uiRoot.layoutDirty
  holder:detach()
  assert(stayedLaidOut, "scrolling should leave the layout as it is")
  logger.trace("passed test testWheelScrollsWithoutALayout")
end

local function testADragScrollsTheContainerAndReleasesNothing()
  local container, holder = createContainerOnScreen()
  local released = false
  container.children[1].onRelease = function()
    released = true
  end
  touchHandler:touch(550, 550)
  touchHandler:drag(550, 530)
  local scrolledByDrag = container.scrollY
  touchHandler:release(550, 520)
  holder:detach()
  assert(scrolledByDrag == -20, "scrolled to " .. scrolledByDrag .. " by the drag")
  assert(container.scrollY == -30, "scrolled to " .. container.scrollY .. " at the release")
  assert(not released, "a touch that scrolled should release nothing")
  logger.trace("passed test testADragScrollsTheContainerAndReleasesNothing")
end

local function testAShortDragOverAContainerStillReleasesOnItsContent()
  local container, holder = createContainerOnScreen()
  local released = false
  container.children[1].onRelease = function()
    released = true
  end
  touchHandler:touch(550, 550)
  touchHandler:drag(552, 553)
  touchHandler:release(552, 553)
  holder:detach()
  assert(container.scrollY == 0, "scrolled to " .. container.scrollY)
  assert(released, "a touch that moved less than the threshold is a tap")
  logger.trace("passed test testAShortDragOverAContainerStillReleasesOnItsContent")
end

local function testASidewaysDragOverAContainerThatScrollsVerticallyStillReleasesOnItsContent()
  local container, holder = createContainerOnScreen()
  local released = false
  container.children[1].onRelease = function()
    released = true
  end
  touchHandler:touch(550, 550)
  touchHandler:drag(560, 552)
  touchHandler:release(560, 552)
  holder:detach()
  assert(container.scrollY == 0, "scrolled to " .. container.scrollY)
  assert(released, "a touch that moved only along the axis the container can't scroll is a tap")
  logger.trace("passed test testASidewaysDragOverAContainerThatScrollsVerticallyStillReleasesOnItsContent")
end

local function testADragOnASliderInAContainerMovesTheSliderAndScrollsNothing()
  local container, holder = createContainerOnScreen()
  local slider = Slider({min = 1, max = 99, value = 1})
  container.children[1]:addChild(slider)
  GAME.uiRoot:layOut()
  touchHandler:touch(520, 520)
  local valueAtTouch = slider.value
  touchHandler:drag(550, 560)
  local valueAfterDrag = slider.value
  touchHandler:release(550, 560)
  holder:detach()
  assert(valueAfterDrag == valueAtTouch + 30, "the slider went from " .. valueAtTouch .. " to " .. valueAfterDrag)
  assert(container.scrollY == 0, "scrolled to " .. container.scrollY)
  logger.trace("passed test testADragOnASliderInAContainerMovesTheSliderAndScrollsNothing")
end

testWheelDownScrollsOneStep()
testWheelUpStopsAtTheTop()
testWheelDownStopsAtTheBottom()
testWheelScrollsWithoutALayout()
testADragScrollsTheContainerAndReleasesNothing()
testAShortDragOverAContainerStillReleasesOnItsContent()
testASidewaysDragOverAContainerThatScrollsVerticallyStillReleasesOnItsContent()
testADragOnASliderInAContainerMovesTheSliderAndScrollsNothing()
testHorizontalContainerScrollsSideways()
testSetContentReplacesTheChildAndLowersTheScrollLimit()
