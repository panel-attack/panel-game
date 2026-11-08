local ModManagement = require("client.src.scenes.ModManagement")
local consts = require("common.engine.consts")
local GridCursor = require("client.src.ui.GridCursor")

local function testOneModUsesTheSingularText()
  local key = ModManagement.getModCountLocalizationKey(1)
  assert(key == "mod_manage_mod_count_one", "expected the singular key, got " .. key)
end

local function testSeveralModsUseThePluralText()
  local key = ModManagement.getModCountLocalizationKey(2)
  assert(key == "mod_manage_mod_count", "expected the plural key, got " .. key)
end

-- Returns the horizontal center of the element on screen
---@param element UiElement
---@return number
local function screenCenterX(element)
  local x = element:getScreenPos()
  return x + element.width / 2
end

local function testTitleReadsModManagement()
  local title = loc(ModManagement().titleLabel.text)
  assert(title == "Mod Management", "expected Mod Management, got " .. title)
end

local function testTabNamesAreCapitalized()
  local expected = {"Characters", "Stages", "Panel Sets"}
  for i, tab in ipairs(ModManagement.TABS) do
    assert(loc(tab.title) == expected[i], "expected " .. expected[i] .. ", got " .. loc(tab.title))
  end
end

local function testTopLevelMenuIsCentered()
  local scene = ModManagement()
  local centerX = screenCenterX(scene.menu)
  assert(centerX == consts.CANVAS_WIDTH / 2, "the menu is centered at " .. centerX .. ", not " .. consts.CANVAS_WIDTH / 2)
  assert(screenCenterX(scene.titleLabel) == consts.CANVAS_WIDTH / 2, "the title is centered")
end

local function testOpenTabReplacesTheMenuWithACenteredTab()
  local scene = ModManagement()
  scene:openTab(ModManagement.TABS[1])

  assert(not scene.menu.isVisible, "the menu is hidden while a tab is open, since the centered tab would cover it")
  assert(screenCenterX(scene.panel) == consts.CANVAS_WIDTH / 2, "the tab is centered at " .. screenCenterX(scene.panel))
  assert(loc(scene.titleLabel.text) == "Characters", "the title names the open tab")

  scene:closeTab()
  assert(scene.menu.isVisible, "the menu is back once the tab closes")
  assert(loc(scene.titleLabel.text) == "Mod Management", "the title is back once the tab closes")
end

-- Returns inputs where only the named menu inputs are pressed, for driving the scene without a keyboard
---@param pressed table<string, boolean>
local function fakeInputs(pressed)
  return {
    isDown = pressed,
    isPressedWithRepeat = function(_, key)
      return pressed[key] == true
    end,
  }
end

-- Returns a scene with the Characters tab open and the cursor on its last row
local function sceneOnLastRow()
  local scene = ModManagement()
  scene:openTab(ModManagement.TABS[1])
  local grid = scene.cursor.target
  scene.cursor:updatePosition(ModManagement.findNearestSelectableColumn(grid, grid.gridHeight, 1), grid.gridHeight)
  return scene
end

local function testOpenTabShowsACenteredBackButtonBelowTheList()
  local scene = ModManagement()
  scene:openTab(ModManagement.TABS[1])

  local button = scene.backButton
  local _, buttonY = button:getScreenPos()
  local _, listY = scene.scrollContainer:getScreenPos()
  assert(button.parent ~= nil and button.isVisible, "the back button is on screen while a tab is open")
  assert(screenCenterX(button) == consts.CANVAS_WIDTH / 2, "the back button is centered at " .. screenCenterX(button))
  assert(buttonY >= listY + scene.scrollContainer.height, "the back button overlaps the list")
  assert(buttonY + button.height <= consts.CANVAS_HEIGHT, "the back button runs off the bottom of the screen")
end

local function testClickingTheBackButtonReturnsToTheMenu()
  local scene = ModManagement()
  scene:openTab(ModManagement.TABS[1])

  scene.backButton:onClick()

  assert(scene.tab == nil and scene.menu.isVisible, "clicking back returns to the menu")
end

local function testDownFromTheLastRowFocusesTheBackButton()
  local scene = sceneOnLastRow()

  scene.cursor:move(GridCursor.directions.down)

  assert(scene.receiveMode == "Back", "down from the last row moves to the back button, receiving " .. scene.receiveMode)
  assert(not scene.cursor.isVisible, "the row cursor is hidden while the back button has the focus")
end

local function testConfirmingTheFocusedBackButtonReturnsToTheMenu()
  local scene = sceneOnLastRow()
  scene.cursor:move(GridCursor.directions.down)

  scene:receiveBackButtonInputs(fakeInputs({Swap1 = true}))

  assert(scene.tab == nil and scene.menu.isVisible, "confirming back returns to the menu")
end

local function testUpFromTheBackButtonReturnsToTheLastRow()
  local scene = sceneOnLastRow()
  local lastRow = scene.cursor.target.gridHeight
  scene.cursor:move(GridCursor.directions.down)

  scene:receiveBackButtonInputs(fakeInputs({Up = true}))

  assert(scene.receiveMode == "Grid" and scene.cursor.isVisible, "up gives the focus back to the rows")
  assert(scene.cursor.selectedGridPos.y == lastRow, "the cursor is back on the last row")
end

testOneModUsesTheSingularText()
testSeveralModsUseThePluralText()
testTitleReadsModManagement()
testTabNamesAreCapitalized()
testTopLevelMenuIsCentered()
testOpenTabReplacesTheMenuWithACenteredTab()
testOpenTabShowsACenteredBackButtonBelowTheList()
testClickingTheBackButtonReturnsToTheMenu()
testDownFromTheLastRowFocusesTheBackButton()
testConfirmingTheFocusedBackButtonReturnsToTheMenu()
testUpFromTheBackButtonReturnsToTheLastRow()
