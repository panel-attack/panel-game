local ui = require("client.src.ui")
local Layout = require("client.src.ui.Layout")

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
  assert(not menu.downIndicator.isVisible and menu.allContentShowing, "the menu marks items below it")
end

itemsKeepTheirOwnWidthsByDefault()
equalItemWidthsStretchesEveryItemToTheWidest()
aStretchedButtonFillsItsItem()
aMenuThatFitsItemsOfFractionalHeightsMarksNoneCut()
