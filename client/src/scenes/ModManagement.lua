local Scene = require("client.src.scenes.Scene")
local class = require("common.lib.class")
local ui = require("client.src.ui")
local inputs = require("client.src.inputManager")
local CharacterLoader = require("client.src.mods.CharacterLoader")
local StageLoader = require("client.src.mods.StageLoader")
local PanelLoader = require("client.src.mods.PanelLoader")
local ModSettings = require("client.src.mods.ModSettings")
local ModLoader = require("client.src.mods.ModLoader")
local ModFolderTree = require("client.src.mods.ModFolderTree")
local system = require("client.src.system")
local consts = require("common.engine.consts")

local UNIT_SIZE = 40
local UNIT_MARGIN = 4
local GRID_WIDTH = 19
local NAME_WIDTH = 7
local STATUS_WIDTH = 2
local STATUSES = {"off", "hidden", "shown"}
local STATUS_X = {off = 8, hidden = 10, shown = 12}
local UP_X = 14
local DOWN_X = 15
local MUSIC_X = 16
local SUB_MODS_X = 18
local EXTRA_WIDTH = 2
-- deeper rows stop indenting so the name keeps room next to the arrow and icon
local MAX_INDENT = NAME_WIDTH - 4
-- the tab is centered on the screen, like the menu it replaces
local PANEL_X = (consts.CANVAS_WIDTH - GRID_WIDTH * UNIT_SIZE) / 2
local PANEL_Y = 16
-- the column headings sit below the tabs
local HEADER_Y = 50
local SCROLL_HEIGHT = 14 * UNIT_SIZE
-- space between a row's name and the grey text after it
local NAME_GAP = 6
-- the back button sits centered under the list, inside the panel
local BACK_WIDTH = 4 * UNIT_SIZE
local BACK_HEIGHT = UNIT_SIZE - 2 * UNIT_MARGIN
local BACK_Y = HEADER_Y + UNIT_SIZE + SCROLL_HEIGHT + UNIT_MARGIN

local PICKED_COLOR = {.5, .5, 1, .7}
local LOCKED_BACKGROUND_COLOR = {.3, .3, .3, .25}
local LOCKED_OUTLINE_COLOR = {.5, .5, .5, .25}
local LOCKED_TEXT_COLOR = {1, 1, 1, .3}
local OFF_COLOR = {1, 1, 1, .45}
local COUNT_COLOR = {1, 1, 1, .6}

---@class ModManagementTab
---@field title string localization key of the tab's name
---@field loader ModTypeLoader CharacterLoader, StageLoader or PanelLoader
---@field getIcon fun(mod: table): love.Texture
---@field getAllMods (fun(): table<string, table>)? every installed mod by id, nil for a tab without music and sub mods

---@type ModManagementTab[]
local TABS = {
  {
    title = "mod_manage_characters",
    loader = CharacterLoader,
    getIcon = function(character) return character.images.icon end,
    getAllMods = function() return allCharacters end,
  },
  {
    title = "mod_manage_stages",
    loader = StageLoader,
    getIcon = function(stage) return stage.images.thumbnail end,
    getAllMods = function() return allStages end,
  },
  {
    title = "mod_manage_panels",
    loader = PanelLoader,
    getIcon = function(panelSet) return panelSet.displayIcons[1] end,
  },
}

-- Lets the player set the status and order of every mod folder and mod, one tab per mod type
---@class ModManagement : Scene
---@field TABS ModManagementTab[]
---@field tab ModManagementTab? the tab on display
---@field collapsedKeys table<ModManagementTab, table<string, boolean>> keys of the collapsed folders per tab
---@field backButton TextButton closes the open tab, below its list
---@field receiveMode "Menu" | "Grid" | "Back" what takes the inputs: the menu, the rows or the back button
local ModManagement = class(function(self, options)
  self.keepMusic = true
  self.receiveMode = "Menu"
  self.collapsedKeys = {}
  for _, tab in ipairs(TABS) do
    self.collapsedKeys[tab] = {}
  end
  self:load()
end,
Scene)

ModManagement.name = "ModManagement"
ModManagement.TABS = TABS

function ModManagement:load()
  self.panel = ui.UiElement({x = PANEL_X, y = PANEL_Y, width = GRID_WIDTH * UNIT_SIZE, height = consts.CANVAS_HEIGHT - PANEL_Y})
  self.titleLabel = ui.Label({text = "mod_manage_title", y = PANEL_Y, hAlign = "center", fontSize = 16})
  self.uiRoot:addChild(self.titleLabel)
  self.headerGrid = self:createHeaderGrid()
  self.panel:addChild(self.headerGrid)
  self.scrollContainer = ui.ScrollContainer({
    y = self.headerGrid.y + UNIT_SIZE,
    width = GRID_WIDTH * UNIT_SIZE,
    height = SCROLL_HEIGHT,
  })
  self.panel:addChild(self.scrollContainer)
  self.backButton = ui.TextButton({
    label = ui.Label({text = "back"}),
    y = BACK_Y,
    width = BACK_WIDTH,
    height = BACK_HEIGHT,
    hAlign = "center",
  })
  self.backButton.onClick = function()
    self:pressBackButton()
  end
  self.backButtonColor = self.backButton.backgroundColor
  self.panel:addChild(self.backButton)

  self.cursor = ui.GridCursor({
    player = GAME.localPlayer,
    frameImages = themes[config.theme]:getGridCursor(1),
  })
  self.cursor.onMove = function(cursor)
    self.scrollContainer:keepVisible(-UNIT_SIZE * (cursor.selectedGridPos.y - 1), UNIT_SIZE)
  end
  self.cursor.escapeCallback = function(cursor)
    self:pressBackButton()
  end
  -- down from the lowest button of a column goes to the back button below the list instead of wrapping to the first row
  local move = self.cursor.move
  self.cursor.move = function(cursor, direction)
    if direction == ui.GridCursor.directions.down and not ModManagement.hasSelectableBelow(cursor) then
      self:focusBackButton()
    else
      move(cursor, direction)
    end
  end

  local menuItems = {}
  for _, tab in ipairs(TABS) do
    menuItems[#menuItems + 1] = ui.MenuItem.createButtonMenuItem(tab.title, nil, true, function()
      GAME.theme:playValidationSfx()
      self:openTab(tab)
    end)
  end
  if system.supportsFileBrowserOpen() then
    menuItems[#menuItems + 1] = ui.MenuItem.createButtonMenuItem("op_openSaveDir", nil, true, function()
      love.system.openURL("file://" .. love.filesystem.getSaveDirectory())
    end)
  end
  menuItems[#menuItems + 1] = ui.MenuItem.createButtonMenuItem("back", nil, true, function()
    GAME.theme:playCancelSfx()
    GAME.navigationStack:pop()
  end)

  self.menu = ui.Menu({
    menuItems = menuItems,
    x = 0,
    y = 0,
    hAlign = "center",
    vAlign = "center",
    width = 200,
    height = 300,
  })

  self.uiRoot:addChild(self.menu)
end

---@return table grid with the column names
function ModManagement:createHeaderGrid()
  local headerGrid = ui.Grid({unitSize = UNIT_SIZE, unitMargin = UNIT_MARGIN, gridWidth = GRID_WIDTH, gridHeight = 1, y = HEADER_Y})
  local function addHeader(x, width, text, hAlign)
    headerGrid:createElementAt(x, 1, width, 1, text, ui.Label({text = text, hAlign = hAlign or "center", vAlign = "center"}))
  end
  addHeader(1, NAME_WIDTH, "mod_manage_name", "left")
  addHeader(STATUS_X.off, STATUS_WIDTH * #STATUSES, "mod_manage_status")
  addHeader(UP_X, DOWN_X - UP_X + 1, "mod_manage_order")
  self.musicHeader = ui.Label({text = "mod_manage_music", hAlign = "center", vAlign = "center"})
  self.subModsHeader = ui.Label({text = "mod_manage_submods", hAlign = "center", vAlign = "center"})
  headerGrid:createElementAt(MUSIC_X, 1, EXTRA_WIDTH, 1, "music", self.musicHeader)
  headerGrid:createElementAt(SUB_MODS_X, 1, EXTRA_WIDTH, 1, "subMods", self.subModsHeader)
  return headerGrid
end

-- Shows the tab in place of the menu and hands the inputs to the cursor on its rows
---@param tab ModManagementTab
function ModManagement:openTab(tab)
  self.tab = tab
  self.menu:setVisibility(false)
  self.titleLabel:setText(tab.title)
  local hasExtras = tab.getAllMods ~= nil
  self.musicHeader:setVisibility(hasExtras)
  self.subModsHeader:setVisibility(hasExtras)
  self.scrollContainer:setScrollOffset(0)
  self:rebuildRows(nil, STATUS_X.shown)
  self.uiRoot:addChild(self.panel)
  self.receiveMode = "Grid"
end

-- Hides the tab and gives the screen and the inputs back to the menu
function ModManagement:closeTab()
  self.cursor:setVisibility(true)
  self.backButton.backgroundColor = self.backButtonColor
  self.cursor:setTarget()
  self.panel:detach()
  self.tab = nil
  self.titleLabel:setText("mod_manage_title")
  self.menu:setVisibility(true)
  self.receiveMode = "Menu"
end

-- Plays the cancel sound, closes the tab and returns to the menu
function ModManagement:pressBackButton()
  GAME.theme:playCancelSfx()
  self:closeTab()
end

-- Moves the focus from the rows to the back button below them
function ModManagement:focusBackButton()
  self.receiveMode = "Back"
  self.cursor:setVisibility(false)
  self.backButton.backgroundColor = PICKED_COLOR
end

-- Gives the focus back to the rows, putting the cursor on the row at y
---@param y integer
function ModManagement:focusRows(y)
  self.receiveMode = "Grid"
  self.cursor:setVisibility(true)
  self.backButton.backgroundColor = self.backButtonColor
  local grid = self.cursor.target
  self.cursor:updatePosition(ModManagement.findNearestSelectableColumn(grid, y, self.cursor.selectedGridPos.x), y)
end

-- Takes the menu inputs while the back button has the focus: confirm or back closes the tab, up and down return to
-- the last and the first row
---@param inputs table
function ModManagement:receiveBackButtonInputs(inputs)
  if inputs.isDown.Swap1 or inputs.isDown.Start or inputs.isDown.Swap2 then
    self:pressBackButton()
  elseif inputs:isPressedWithRepeat("Up", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    self:focusRows(self.cursor.target.gridHeight)
  elseif inputs:isPressedWithRepeat("Down", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    self:focusRows(1)
  end
end

-- Rebuilds the rows of the tab on display, putting the cursor on the row of the node or the first row
---@param focusNode ModFolderNode?
---@param cursorX integer column the cursor should stay in, or the nearest one it can select on that row
---@param focusLinkedFrom ModFolderNode? the bundle the focused row is listed under when it is a sub mod from another folder
function ModManagement:rebuildRows(focusNode, cursorX, focusLinkedFrom)
  local tree = self.tab.loader.tree
  local rows = tree:getDisplayRows(self.collapsedKeys[self.tab])
  local grid = ui.Grid({unitSize = UNIT_SIZE, unitMargin = UNIT_MARGIN, gridWidth = GRID_WIDTH, gridHeight = #rows})
  local cursorY = 1
  for y, row in ipairs(rows) do
    self:addRow(grid, tree, row, y)
    if row.node == focusNode and row.linkedFrom == focusLinkedFrom then
      cursorY = y
    end
  end

  self.scrollContainer:setContent(grid)

  self.cursor:setTarget(grid, {x = ModManagement.findNearestSelectableColumn(grid, cursorY, cursorX), y = cursorY})
  self.cursor:onMove()
end

-- Returns whether a row below the cursor holds something the cursor can press in its column
---@param cursor table
---@return boolean
function ModManagement.hasSelectableBelow(cursor)
  local grid = cursor.target
  local x = cursor.selectedGridPos.x
  for y = cursor.selectedGridPos.y + 1, grid.gridHeight do
    if grid:getElementAt(y, x).onSelect then
      return true
    end
  end
  return false
end

-- Returns the column on the row closest to x that holds something the cursor can press, preferring the right
---@param grid table
---@param y integer
---@param x integer
---@return integer
function ModManagement.findNearestSelectableColumn(grid, y, x)
  for distance = 0, grid.gridWidth do
    for _, column in ipairs({x + distance, x - distance}) do
      if column >= 1 and column <= grid.gridWidth and grid:getElementAt(y, column).onSelect then
        return column
      end
    end
  end
  return x
end

-- Adds the row at y: indented expand arrow, icon and name, status and order buttons, and the music and sub mod columns
---@param grid table
---@param tree ModFolderTree
---@param row ModFolderRow
---@param y integer
function ModManagement:addRow(grid, tree, row, y)
  local node = row.node
  local status = tree:getEffectiveStatus(node)
  local x = 1 + math.min(row.depth, MAX_INDENT)
  if row.modCount > 0 then
    grid:createElementAt(x, y, 1, 1, "expand", self:createExpandButton(node))
    x = x + 1
  end
  if node.mod then
    local icon = ui.ImageContainer({
      image = self.tab.getIcon(node.mod),
      drawBorders = true,
      hFill = true,
      vFill = true,
      hAlign = "center",
      vAlign = "center",
      color = status == "off" and OFF_COLOR or nil,
    })
    grid:createElementAt(x, y, 1, 1, "icon", icon)
    x = x + 1
  end
  grid:createElementAt(x, y, NAME_WIDTH + 1 - x, 1, "name", self:createNameLabel(row, status))

  self:addStatusButtons(grid, tree, row, status, y)
  if not row.linkedFrom then
    self:addOrderButtons(grid, row, y)
  end
  if node.mod and self.tab.getAllMods then
    self:addMusicAndSubModColumns(grid, node.mod, status, y)
  end
end

-- Returns the arrow that collapses or expands the folder's rows
---@param node ModFolderNode
---@return ArrowButton
function ModManagement:createExpandButton(node)
  local collapsedKeys = self.collapsedKeys[self.tab]
  local button = ui.ArrowButton({direction = collapsedKeys[node.key] and "right" or "down", hFill = true, vFill = true})
  local function toggle()
    GAME.theme:playValidationSfx()
    collapsedKeys[node.key] = not collapsedKeys[node.key] or nil
    self:rebuildRows(node, self.cursor.selectedGridPos.x)
  end
  button.onClick = toggle
  button.onSelect = toggle
  return button
end

-- Returns how a row's folder is named next to a sub mod listed under a bundle in another folder
---@param folder ModFolderNode
---@return string
local function getLinkedFolderText(folder)
  local builtin = ModFolderTree.BUILTIN
  if folder.key:sub(1, #builtin) == builtin then
    return loc("mod_manage_builtin") .. folder.key:sub(#builtin + 1)
  end
  return folder.key
end

-- Returns the localization key for the number of mods listed under a row
---@param count integer
---@return string
function ModManagement.getModCountLocalizationKey(count)
  if count == 1 then
    return "mod_manage_mod_count_one"
  end
  return "mod_manage_mod_count"
end

-- Returns the row's name followed by its mod count or, for a linked sub mod, its folder, greyed out while it is off
---@param row ModFolderRow
---@param status ModStatus effective status of the node
---@return UiElement
function ModManagement:createNameLabel(row, status)
  local node = row.node
  local textColor = status == "off" and OFF_COLOR or nil
  local name = ui.UiElement({hFill = true, vFill = true})
  local nameLabel
  if node.mod then
    local modName = node.mod.display_name or node.mod.name or node.mod.id
    nameLabel = ui.Label({text = modName, translate = false, vAlign = "center", textColor = textColor})
  elseif node.key == ModFolderTree.BUILTIN then
    nameLabel = ui.Label({text = "mod_manage_builtin", vAlign = "center", textColor = textColor})
  else
    nameLabel = ui.Label({text = node.name, translate = false, vAlign = "center", textColor = textColor})
  end
  name:addChild(nameLabel)

  if row.linkedFrom then
    name:addChild(ui.Label({
      text = getLinkedFolderText(node.parent),
      translate = false,
      x = nameLabel.width + NAME_GAP,
      vAlign = "center",
      textColor = textColor or COUNT_COLOR,
    }))
  elseif row.modCount > 0 then
    name:addChild(ui.Label({
      text = ModManagement.getModCountLocalizationKey(row.modCount),
      replacements = {tostring(row.modCount)},
      x = nameLabel.width + NAME_GAP,
      vAlign = "center",
      textColor = textColor or COUNT_COLOR,
    }))
  end
  return name
end

-- Creates a button the cursor and touch can press that fills its grid cell
---@param text string localization key
---@param onPress function
---@return TextButton
local function createTextButton(text, onPress)
  local button = ui.TextButton({label = ui.Label({text = text}), hFill = true, vFill = true})
  button.onClick = onPress
  button.onSelect = onPress
  return button
end

-- Adds the Off, Hidden and Shown buttons, marking the row's status and locking the ones above its folder's
---@param grid table
---@param tree ModFolderTree
---@param row ModFolderRow
---@param status ModStatus effective status of the node
---@param y integer
function ModManagement:addStatusButtons(grid, tree, row, status, y)
  local node = row.node
  local limit = tree:getHighestAllowedStatus(node)
  for _, buttonStatus in ipairs(STATUSES) do
    local isLocked = ModSettings.STATUS_RANK[buttonStatus] > ModSettings.STATUS_RANK[limit]
    local button = createTextButton("mod_manage_" .. buttonStatus, function()
      self:onStatusButtonPressed(row, buttonStatus, isLocked)
    end)
    if isLocked then
      button.backgroundColor = LOCKED_BACKGROUND_COLOR
      button.outlineColor = LOCKED_OUTLINE_COLOR
      button.label:setTextColor(unpack(LOCKED_TEXT_COLOR))
    elseif buttonStatus == status then
      button.backgroundColor = PICKED_COLOR
    end
    grid:createElementAt(STATUS_X[buttonStatus], y, STATUS_WIDTH, 1, buttonStatus, button)
  end
end

-- Adds the up and down arrows that move the node within its folder
---@param grid table
---@param row ModFolderRow
---@param y integer
function ModManagement:addOrderButtons(grid, row, y)
  local node = row.node
  local function addMoveButton(x, direction, offset)
    local button = ui.ArrowButton({direction = direction, hFill = true, vFill = true})
    local function move()
      self:onMoveButtonPressed(node, offset)
    end
    button.onClick = move
    button.onSelect = move
    grid:createElementAt(x, y, 1, 1, direction, button)
  end
  if row.position > 1 then
    addMoveButton(UP_X, "up", -1)
  end
  if row.position < row.siblingCount then
    addMoveButton(DOWN_X, "down", 1)
  end
end

-- Adds the mod's music and sub mod count columns
---@param grid table
---@param mod table
---@param status ModStatus effective status of the mod
---@param y integer
function ModManagement:addMusicAndSubModColumns(grid, mod, status, y)
  local allMods = self.tab.getAllMods()
  local subModCount = 0
  for _, subId in ipairs(mod.subIds) do
    if allMods[subId] then
      subModCount = subModCount + 1
    end
  end
  local textColor = status == "off" and OFF_COLOR or nil
  local hasMusic = tostring(mod.hasMusic):upper()
  local music = ui.Label({text = hasMusic, translate = false, hAlign = "center", vAlign = "center", textColor = textColor})
  local subMods = ui.Label({text = tostring(subModCount), translate = false, hAlign = "center", vAlign = "center", textColor = textColor})
  grid:createElementAt(MUSIC_X, y, EXTRA_WIDTH, 1, "music", music)
  grid:createElementAt(SUB_MODS_X, y, EXTRA_WIDTH, 1, "subMods", subMods)
end

-- Sets the row's node's status unless the button is locked or the change would leave nothing to select
---@param row ModFolderRow
---@param status ModStatus
---@param isLocked boolean
function ModManagement:onStatusButtonPressed(row, status, isLocked)
  if isLocked or not ModLoader.setModStatusAndRefresh(self.tab.loader, row.node, status) then
    GAME.theme:playCancelSfx()
    return
  end
  GAME.theme:playValidationSfx()
  GAME.localPlayer:refreshDisabledSelections()
  self:rebuildRows(row.node, self.cursor.selectedGridPos.x, row.linkedFrom)
end

-- Moves the node within its folder unless it is already first or last, keeping the cursor on it
---@param node ModFolderNode
---@param offset integer -1 to move up, 1 to move down
function ModManagement:onMoveButtonPressed(node, offset)
  if not ModLoader.moveModInDisplayOrder(self.tab.loader, node, offset) then
    GAME.theme:playCancelSfx()
    return
  end
  GAME.theme:playMoveSfx()
  self:rebuildRows(node, self.cursor.selectedGridPos.x)
end

function ModManagement:draw()
  themes[config.theme].images.bg_main:draw()
  self.uiRoot:draw()
end

function ModManagement:update(dt)
  themes[config.theme].images.bg_main:update(dt)
  if self.receiveMode == "Menu" then
    self.menu:receiveInputs(inputs, dt)
  elseif self.receiveMode == "Back" then
    self:receiveBackButtonInputs(inputs)
  else
    self.cursor:receiveInputs(inputs, dt)
  end
end

return ModManagement
