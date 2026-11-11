local ScrollContainer = require("client.src.ui.ScrollContainer")
local UiElement = require("client.src.ui.UIElement")
local touchHandler = require("client.src.ui.touchHandler")
local logger = require("common.lib.logger")

-- Returns a 100 pixel high container holding content 400 pixels high
local function createContainer()
  local container = ScrollContainer({x = 0, y = 0, width = 100, height = 100})
  container:addChild(UiElement({x = 0, y = 0, width = 100, height = 400}))
  return container
end

local function testHorizontalContainerScrollsSideways()
  local container = ScrollContainer({x = 0, y = 0, width = 100, height = 100, scrollOrientation = "horizontal"})
  container:addChild(UiElement({x = 0, y = 0, width = 400, height = 100}))
  container:onScroll(-1, 0)
  assert(container.scrollOffset == -ScrollContainer.SCROLL_STEP, "offset " .. container.scrollOffset)
  logger.trace("passed test testHorizontalContainerScrollsSideways")
end

local function testSetContentReplacesTheChildAndLowersTheScrollLimit()
  local container = createContainer()
  container:setScrollOffset(-300)
  local content = UiElement({x = 0, y = 0, width = 100, height = 150})
  container:setContent(content)
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
  local holder = UiElement({x = 500, y = 500, width = 100, height = 100})
  local container = createContainer()
  holder:addChild(container)
  GAME.uiRoot:addChild(holder)
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
