local ui = require("client.src.ui")
local Layout = require("client.src.ui.Layout")
local touchHandler = require("client.src.ui.touchHandler")

local function itemsOfDifferentWidths()
  return {
    ui.MenuItem.createButtonMenuItem("narrow", nil, false, function() end, 60),
    ui.MenuItem.createButtonMenuItem("wide", nil, false, function() end, 200),
  }
end

local function itemsKeepTheirOwnWidthsByDefault()
  local menu = ui.Menu({menuItems = itemsOfDifferentWidths()})
  menu:layOut()

  assert(menu.menuItems[1].layoutRect.width == 60 + 2 * ui.MenuItem.PADDING)
end

local function equalItemWidthsStretchesEveryItemToTheWidest()
  local menu = ui.Menu({menuItems = itemsOfDifferentWidths(), equalItemWidths = true})
  menu:layOut()

  for _, menuItem in ipairs(menu.menuItems) do
    local width = menuItem.layoutRect.width
    assert(width == 200 + 2 * ui.MenuItem.PADDING, "an item is " .. width .. " wide")
  end
end

local function aStretchedButtonFillsItsItem()
  local menu = ui.Menu({menuItems = itemsOfDifferentWidths(), equalItemWidths = true})
  menu:layOut()

  local narrowItem = menu.menuItems[1]
  assert(narrowItem.textButton.layoutRect.width == narrowItem.layoutRect.width - 2 * ui.MenuItem.PADDING)
end

local function aMenuThatFitsItemsOfFractionalHeightsMarksNoneCut()
  local menuItems = {}
  for i = 1, 3 do
    -- the items end at 10.6, 29.2 and 47.8, none on an even point
    menuItems[i] = ui.MenuItem.createMenuItem(ui.UiElement({layoutRules = {sizing = Layout.fixedSize(40, 10.6)}}),
                                              ui.UiElement({layoutRules = {sizing = Layout.fixedSize(40, 10.6)}}))
  end
  local menu = ui.Menu({menuItems = menuItems})
  menu:layOut()

  local last = menuItems[3].layoutRect
  local height = menu.layoutRect.height
  assert(last.y + last.height == height, "the last item ends at " .. last.y + last.height .. " of the menu's " .. height)
  assert(menuItems[3].isVisible, "the menu hides its last item")
  assert(not menu.upIndicator.isVisible and not menu.downIndicator.isVisible, "the menu marks items cut off")
end

-- Returns a laid out menu 50 high of count items at least 20 high, so no more than two of them fit
---@param count integer
---@return Menu
local function scrollingMenu(count)
  local menuItems = {}
  for i = 1, count do
    menuItems[i] = ui.MenuItem.createMenuItem(ui.UiElement({layoutRules = {sizing = Layout.fixedSize(40, 20)}}))
  end
  local menu = ui.Menu({menuItems = menuItems, layoutRules = {sizing = {vertical = Layout.fixed(50)}}})
  menu:layOut()
  return menu
end

local function selectingAnItemBelowScrollsToItWithoutALayout()
  local menu = scrollingMenu(5)
  menu:setSelectedIndex(4)

  assert(not menu.layoutDirty, "selecting an item should leave the layout as it is")
  assert(menu.menuItems[4].isVisible and not menu.menuItems[1].isVisible, "the menu should show the selected item")
  assert(menu.upIndicator.isVisible, "items are cut off above")
end

local function aMenuScrollsNoFurtherThanItsLastItemWhollyInView()
  local menu = scrollingMenu(5)
  menu:scrollBy(0, -1000)

  local _, maxY = menu:getMaxScroll()
  assert(maxY > 0 and menu.scrollY == -maxY, "scrolled to " .. menu.scrollY .. " of " .. maxY)
  assert(menu.menuItems[5].isVisible and not menu.downIndicator.isVisible, "the last item should be wholly in the menu")
end

local function aWheelStepOverAMenuSelectsTheNextItemAndStopsAtTheEnds()
  local menu = scrollingMenu(5)
  menu:setLayoutRule("floating", Layout.floatAt("leftTop", 500, 500))
  GAME.uiRoot:addChild(menu)
  GAME.uiRoot:layOut()
  touchHandler:scroll(510, 510, 0, -1)
  local selectedAfterOneStepDown = menu.selectedIndex
  local secondItemIsShown = menu.menuItems[2].isVisible
  for _ = 1, 3 do
    touchHandler:scroll(510, 510, 0, 1)
  end
  local selectedAfterStepsUp = menu.selectedIndex
  for _ = 1, 9 do
    touchHandler:scroll(510, 510, 0, -1)
  end
  menu:detach()

  assert(selectedAfterOneStepDown == 2, "one step down selected item " .. selectedAfterOneStepDown)
  assert(secondItemIsShown, "the item one step down selected should be in view")
  assert(selectedAfterStepsUp == 1, "steps up past the first item selected item " .. selectedAfterStepsUp)
  assert(menu.selectedIndex == 5, "steps down past the last item selected item " .. menu.selectedIndex)
  assert(menu.menuItems[5].isVisible, "the last item should be in view once it is selected")
end

itemsKeepTheirOwnWidthsByDefault()
aWheelStepOverAMenuSelectsTheNextItemAndStopsAtTheEnds()
selectingAnItemBelowScrollsToItWithoutALayout()
aMenuScrollsNoFurtherThanItsLastItemWhollyInView()
equalItemWidthsStretchesEveryItemToTheWidest()
aStretchedButtonFillsItsItem()
aMenuThatFitsItemsOfFractionalHeightsMarksNoneCut()
