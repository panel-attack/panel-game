local ui = require("client.src.ui")

local function itemsOfDifferentWidths()
  return {
    ui.MenuItem.createButtonMenuItem("narrow", nil, false, function() end, 60),
    ui.MenuItem.createButtonMenuItem("wide", nil, false, function() end, 200),
  }
end

local function itemsKeepTheirOwnWidthsByDefault()
  local menu = ui.Menu({menuItems = itemsOfDifferentWidths(), height = 0})

  assert(menu.menuItems[1].width == 60 + 2 * ui.MenuItem.PADDING)
end

local function equalItemWidthsStretchesEveryItemToTheWidest()
  local menu = ui.Menu({menuItems = itemsOfDifferentWidths(), height = 0, equalItemWidths = true})

  for _, menuItem in ipairs(menu.menuItems) do
    assert(menuItem.width == 200 + 2 * ui.MenuItem.PADDING, "an item is " .. menuItem.width .. " wide")
  end
end

local function aStretchedButtonFillsItsItem()
  local menu = ui.Menu({menuItems = itemsOfDifferentWidths(), height = 0, equalItemWidths = true})

  local narrowItem = menu.menuItems[1]
  assert(narrowItem.textButton.width == narrowItem.width - 2 * ui.MenuItem.PADDING)
end

itemsKeepTheirOwnWidthsByDefault()
equalItemWidthsStretchesEveryItemToTheWidest()
aStretchedButtonFillsItsItem()
