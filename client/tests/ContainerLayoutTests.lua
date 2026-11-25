local ui = require("client.src.ui")
local Layout = require("client.src.ui.Layout")
local touchHandler = require("client.src.ui.touchHandler")
local logger = require("common.lib.logger")

local function box(width, height)
  return ui.UiElement({layoutRules = {sizing = Layout.fixedSize(width, height)}})
end

-- Whether the place is the exact one, or a point off it where the layout rounded it to even points
local function near(place, exact)
  return math.abs(place - exact) <= 1
end

local function screenY(element)
  local _, y = element:getScreenPos()
  return y
end

local function testTopStackPanelStacksItsChildrenAndFitsTheirHeight()
  local panel = ui.StackPanel({
    alignment = "top",
    layoutRules = {sizing = {horizontal = Layout.fixed(100)}, childAlignment = Layout.CENTER_HORIZONTALLY}
  })
  local first, second = box(40, 10), box(40, 20)
  panel:addElement(first)
  panel:addElement(second)
  panel:layOut()
  assert(screenY(second) == 10, "second at " .. screenY(second))
  assert(second.layoutRect.x == 30, "second centered at " .. second.layoutRect.x)
  local rect = panel.layoutRect
  assert(rect.height == 30 and rect.width == 100, "panel " .. rect.width .. "x" .. rect.height)
  logger.trace("passed test testTopStackPanelStacksItsChildrenAndFitsTheirHeight")
end

local function testLeftStackPanelFitsTheWidthOfItsChildren()
  local panel = ui.StackPanel({alignment = "left", layoutRules = {sizing = {vertical = Layout.fixed(20)}}})
  panel:addElement(box(40, 10))
  panel:addElement(box(30, 10))
  panel:layOut()
  assert(panel.layoutRect.width == 70, "width " .. panel.layoutRect.width)
  logger.trace("passed test testLeftStackPanelFitsTheWidthOfItsChildren")
end

local function testStackPanelRemoveClosesTheGap()
  local panel = ui.StackPanel({alignment = "top", layoutRules = {sizing = {horizontal = Layout.fixed(100)}}})
  local first, second = box(40, 10), box(40, 20)
  panel:addElement(first)
  panel:addElement(second)
  panel:remove(first)
  panel:layOut()
  assert(screenY(second) == 0 and panel.layoutRect.height == 20,
         "second at " .. screenY(second) .. ", panel " .. panel.layoutRect.height)
  logger.trace("passed test testStackPanelRemoveClosesTheGap")
end

local function testStackPanelInsertsAtAnIndex()
  local panel = ui.StackPanel({alignment = "top", layoutRules = {sizing = {horizontal = Layout.fixed(100)}}})
  local first, inserted = box(40, 10), box(40, 20)
  panel:addElement(first)
  panel:insertElementAtIndex(inserted, 1)
  panel:layOut()
  assert(screenY(inserted) == 0 and screenY(first) == 20, "inserted at " .. screenY(inserted) .. ", first at " .. screenY(first))
  logger.trace("passed test testStackPanelInsertsAtAnIndex")
end

local function testButtonGroupPlacesItsButtonsInARow()
  local first, second = box(40, 10), box(30, 16)
  local group = ui.ButtonGroup({buttons = {first, second}, values = {1, 2}})
  group:layOut()
  local x = second:getScreenPos()
  assert(near(x, 45), "second at " .. x)
  local rect = group.layoutRect
  -- 40 + 5 + 30 ends at 75, and the layout puts that edge on the even point 76
  assert(rect.width == 76 and rect.height == 16, "group " .. rect.width .. "x" .. rect.height)
  logger.trace("passed test testButtonGroupPlacesItsButtonsInARow")
end

local function testGridPlacesAnElementInItsCells()
  local grid = ui.Grid({unitSize = 50, unitMargin = 4, gridWidth = 4, gridHeight = 3})
  local element = grid:createElementAt(2, 3, 2, 1, "wide", ui.UiElement({}))
  grid:layOut()
  local x, y = element:getScreenPos()
  assert(x == 54 and y == 104, "element at " .. x .. "," .. y)
  local rect = element.layoutRect
  assert(rect.width == 92 and rect.height == 42, "element " .. rect.width .. "x" .. rect.height)
  local gridRect = grid.layoutRect
  assert(gridRect.width == 200 and gridRect.height == 150, "grid " .. gridRect.width .. "x" .. gridRect.height)
  logger.trace("passed test testGridPlacesAnElementInItsCells")
end

local function testScrollContainerMovesItsContent()
  local container = ui.ScrollContainer({layoutRules = {sizing = Layout.fixedSize(100, 100)}})
  local content = box(100, 400)
  container:addChild(content)
  container:layOut()
  container:scrollBy(0, -40)
  assert(screenY(content) == -40, "content at " .. screenY(content))
  logger.trace("passed test testScrollContainerMovesItsContent")
end

local function testScrollMenuStacksItsChildrenBelowItsPadding()
  local menu = ui.ScrollMenu({childGap = 6, padding = 10, layoutRules = {sizing = Layout.fixedSize(100, 100)}})
  local first, second = box(80, 20), box(80, 20)
  menu:addChild(first)
  menu:addChild(second)
  menu:layOut()
  assert(screenY(first) == 10 and screenY(second) == 36, "children at " .. screenY(first) .. " and " .. screenY(second))
  logger.trace("passed test testScrollMenuStacksItsChildrenBelowItsPadding")
end

local function testScrollMenuScrollsToTheSelectedChild()
  local menu = ui.ScrollMenu({childGap = 0, padding = 0, layoutRules = {sizing = Layout.fixedSize(100, 50)}})
  local children = {}
  for i = 1, 4 do
    children[i] = ui.TextButton({label = ui.Label({text = "x", translate = false}), layoutRules = {sizing = Layout.fixedSize(80, 20)}})
    menu:addChild(children[i])
  end
  menu:layOut()
  menu:select(children[4])
  local bottom = screenY(children[4]) + children[4].layoutRect.height
  assert(near(bottom, 50), "last child ends at " .. bottom)
  logger.trace("passed test testScrollMenuScrollsToTheSelectedChild")
end

local function testATouchOnAScrollMenuChildPartlyInViewSelectsItWithoutScrolling()
  local menu = ui.ScrollMenu({
    childGap = 0,
    padding = 0,
    layoutRules = {sizing = Layout.fixedSize(100, 50), floating = Layout.floatAt("leftTop", 500, 500)}
  })
  for _ = 1, 4 do
    menu:addChild(ui.TextButton({label = ui.Label({text = "x", translate = false}), layoutRules = {sizing = Layout.fixedSize(80, 20)}}))
  end
  GAME.uiRoot:addChild(menu)
  GAME.uiRoot:layOut()
  -- the third child reaches from 40 to 60, 10 past the menu's end
  touchHandler:touch(510, 545)
  local scrolledByTheTouch = menu.scrollY
  touchHandler:release(0, 0)
  menu:detach()
  assert(menu.selectedIndex == 3, "selected child " .. tostring(menu.selectedIndex))
  assert(scrolledByTheTouch == 0, "the touch scrolled the menu to " .. scrolledByTheTouch)
  logger.trace("passed test testATouchOnAScrollMenuChildPartlyInViewSelectsItWithoutScrolling")
end

local function menuItems(count)
  local items = {}
  for i = 1, count do
    items[i] = ui.MenuItem.createButtonMenuItem("item" .. i, nil, false, function() end, 100)
  end
  return items
end

local function testMenuStacksItsItems()
  local menu = ui.Menu({menuItems = menuItems(3)})
  menu:layOut()
  local items = menu.menuItems
  local itemHeight = items[1].layoutRect.height
  local step = itemHeight + ui.Menu.BUTTON_VERTICAL_PADDING
  assert(near(screenY(items[2]) - screenY(items[1]), step), "items " .. step .. " apart expected")
  local height = menu.layoutRect.height
  assert(height == 3 * itemHeight + 2 * ui.Menu.BUTTON_VERTICAL_PADDING, "menu height " .. height)
  for i, item in ipairs(items) do
    assert(item.isVisible, "item " .. i .. " of a menu that fits its items is hidden")
  end
  assert(not menu.upIndicator.isVisible and not menu.downIndicator.isVisible, "a menu showing all its items marks none cut")
  logger.trace("passed test testMenuStacksItsItems")
end

local function testMenuStretchesEveryItemToItsWidth()
  local menu = ui.Menu({menuItems = {}, equalItemWidths = true})
  local items = menuItems(2)
  items[1] = ui.MenuItem.createButtonMenuItem("wide", nil, false, function() end, 200)
  menu:setMenuItems(items)
  menu:layOut()
  assert(items[2].layoutRect.width == items[1].layoutRect.width, "last item " .. items[2].layoutRect.width .. " wide")
  logger.trace("passed test testMenuStretchesEveryItemToItsWidth")
end

local function testMenuScrollsTheSelectedItemIntoView()
  local items = menuItems(6)
  -- each item's height before it is in the menu
  items[1]:layOut()
  local itemHeight = items[1].layoutRect.height
  local menu = ui.Menu({
    menuItems = items,
    layoutRules = {sizing = {vertical = Layout.fixed(itemHeight * 2 + ui.Menu.BUTTON_VERTICAL_PADDING)}}
  })
  menu:layOut()
  menu:setSelectedIndex(6)
  menu:layOut()
  local menuTop = screenY(menu)
  local itemTop = screenY(items[6])
  assert(items[6].isVisible, "item 6 is hidden")
  assert(itemTop >= menuTop and itemTop + itemHeight <= menuTop + menu.layoutRect.height,
         "item 6 at " .. itemTop .. ", menu at " .. menuTop)
  assert(menu.upIndicator.isVisible and not menu.downIndicator.isVisible, "only the up indicator shows")
  assert(not items[1].isVisible, "a menu hides the items cut off")
  logger.trace("passed test testMenuScrollsTheSelectedItemIntoView")
end

testTopStackPanelStacksItsChildrenAndFitsTheirHeight()
testLeftStackPanelFitsTheWidthOfItsChildren()
testStackPanelRemoveClosesTheGap()
testStackPanelInsertsAtAnIndex()
testButtonGroupPlacesItsButtonsInARow()
testGridPlacesAnElementInItsCells()
testScrollContainerMovesItsContent()
testScrollMenuStacksItsChildrenBelowItsPadding()
testScrollMenuScrollsToTheSelectedChild()
testATouchOnAScrollMenuChildPartlyInViewSelectsItWithoutScrolling()
testMenuStacksItsItems()
testMenuStretchesEveryItemToItsWidth()
testMenuScrollsTheSelectedItemIntoView()
