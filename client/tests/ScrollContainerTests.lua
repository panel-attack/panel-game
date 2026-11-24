local ScrollContainer = require("client.src.ui.ScrollContainer")
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
  container:onScroll(-1, 0)
  assert(container.scrollOffset == -ScrollContainer.SCROLL_STEP, "offset " .. container.scrollOffset)
  logger.trace("passed test testHorizontalContainerScrollsSideways")
end

local function testSetContentReplacesTheChildAndLowersTheScrollLimit()
  local container = createContainer()
  container:setScrollOffset(-300)
  local content = box(100, 150)
  container:setContent(content)
  container:layOut()
  assert(#container.children == 1 and container.children[1] == content, "the content is the only child")
  assert(container.maxScrollOffset == 50, "max offset " .. container.maxScrollOffset)
  assert(container.scrollOffset == -50, "offset " .. container.scrollOffset)
  logger.trace("passed test testSetContentReplacesTheChildAndLowersTheScrollLimit")
end

local function testWheelDownScrollsOneStep()
  local container = createContainer()
  container:onScroll(0, -1)
  assert(container.scrollOffset == -ScrollContainer.SCROLL_STEP, "offset " .. container.scrollOffset)
  logger.trace("passed test testWheelDownScrollsOneStep")
end

local function testWheelUpStopsAtTheTop()
  local container = createContainer()
  container:onScroll(0, 1)
  assert(container.scrollOffset == 0, "offset " .. container.scrollOffset)
  logger.trace("passed test testWheelUpStopsAtTheTop")
end

local function testWheelDownStopsAtTheBottom()
  local container = createContainer()
  container:onScroll(0, -100)
  assert(container.scrollOffset == -300, "offset " .. container.scrollOffset)
  logger.trace("passed test testWheelDownStopsAtTheBottom")
end

local function testWheelScrollsTheContainerUnderTheMouse()
  local holder = UiElement({
    layoutRules = {sizing = Layout.fixedSize(100, 100), floating = Layout.floatAt("leftTop", 500, 500)}
  })
  local container = createContainer()
  holder:addChild(container)
  GAME.uiRoot:addChild(holder)
  GAME.uiRoot:layOut()
  touchHandler:scroll(550, 550, 0, -1)
  holder:detach()
  assert(container.scrollOffset == -ScrollContainer.SCROLL_STEP, "offset " .. container.scrollOffset)
  logger.trace("passed test testWheelScrollsTheContainerUnderTheMouse")
end

testWheelDownScrollsOneStep()
testWheelUpStopsAtTheTop()
testWheelDownStopsAtTheBottom()
testWheelScrollsTheContainerUnderTheMouse()
testHorizontalContainerScrollsSideways()
testSetContentReplacesTheChildAndLowersTheScrollLimit()
