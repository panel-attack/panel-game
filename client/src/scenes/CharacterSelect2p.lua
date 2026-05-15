local CharacterSelect = require("client.src.scenes.CharacterSelect")
local class = require("common.lib.class")
local ui = require("client.src.ui")

---@class CharacterSelect2p : CharacterSelect
local CharacterSelect2p = class(
  function (self, sceneParams)
  end,
  CharacterSelect
)

CharacterSelect2p.name = "CharacterSelect2p"

function CharacterSelect2p:customLoad(sceneParams)
  self:loadUserInterface()
end

function CharacterSelect2p:loadUserInterface()
  -- ≤4 players: 9-col grid. 5+ players: 16-col grid so all (icon, info) pairs
  -- fit on one centered row. unitSize stays 100; everything else (selectors,
  -- char grid, buttons) keeps its existing 9-col placements.
  local playerCount = #self.players
  local gridWidth = (playerCount >= 5) and 16 or 9
  local selectorsRow, charGridStartRow, charGridHeight, bottomRow = 2, 3, 3, 6
  self._layout = {
    gridWidth = gridWidth,
    selectorsRow = selectorsRow,
    charGridStartRow = charGridStartRow,
    charGridHeight = charGridHeight,
    bottomRow = bottomRow,
    topRowCount = 1,
  }

  -- Shift down to clear the team banner + garbage-mode/latency labels drawn
  -- by TeamBannerHeader at y=4..~80. y=35 leaves ~5px less gap than y=40.
  self.ui.grid = ui.Grid({unitSize = 100, gridWidth = gridWidth, gridHeight = bottomRow, unitMargin = 8, hAlign = "center", vAlign = "center", y = 35})
  self.uiRoot:addChild(self.ui.grid)

  self.ui.panelSelection = ui.MultiPlayerSelectionWrapper({hFill = true, alignment = "top", hAlign = "center", vAlign = "top"})
  self.ui.panelSelection:setTitle("panels")
  self.ui.stageSelection = ui.MultiPlayerSelectionWrapper({vFill = true, alignment = "left", hAlign = "center", vAlign = "center"})
  self.ui.stageSelection:setTitle("stage")
  self.ui.levelSelection = ui.MultiPlayerSelectionWrapper({hFill = true, alignment = "top", hAlign = "center", vAlign = "top"})
  self.ui.levelSelection:setTitle("level")

  self.ui.readyButton = self:createReadyButton()

  local characterButtons = self:getCharacterButtons()
  -- Char grid keeps its original 9-col footprint even when the parent grid is
  -- 16 wide. The extra cols are only used by the top-row icon/info pairs.
  local characterGridWidth, characterGridHeight = 9, self._layout.charGridHeight
  self.ui.characterGrid = self:createCharacterGrid(characterButtons, self.ui.grid, characterGridWidth, characterGridHeight)

  self.ui.pageIndicator = self:createPageIndicator(self.ui.characterGrid)

  self.ui.leaveButton = self:createLeaveButton()
  self.ui.changeInputButton = self:createChangeInputButton()

  local selectorsRow = self._layout.selectorsRow
  local charGridStartRow = self._layout.charGridStartRow
  local bottomRow = self._layout.bottomRow

  -- Selectors / char grid / bottom buttons keep their original 9-col cell
  -- placements regardless of total gridWidth — the extra cols on a 16-wide
  -- grid are only used to lay out the (icon, info) pairs in row 1.
  if self.battleRoom.online then
    self.ui.grid:createElementAt(1, selectorsRow, 2, 1, "panelSelection", self.ui.panelSelection, nil, true)
    self.ui.grid:createElementAt(5, selectorsRow, 2, 1, "stageSelection", self.ui.stageSelection, nil, true)
    self.ui.grid:createElementAt(7, selectorsRow, 2, 1, "levelSelection", self.ui.levelSelection, nil, true)
  else
    self.ui.grid:createElementAt(1, selectorsRow, 2, 1, "panelSelection", self.ui.panelSelection, nil, true)
    self.ui.grid:createElementAt(3, selectorsRow, 3, 1, "stageSelection", self.ui.stageSelection, nil, true)
    self.ui.grid:createElementAt(6, selectorsRow, 3, 1, "levelSelection", self.ui.levelSelection, nil, true)
  end

  self.ui.grid:createElementAt(9, selectorsRow, 1, 1, "readyButton", self.ui.readyButton)
  self.ui.grid:createElementAt(1, charGridStartRow, characterGridWidth, characterGridHeight, "characterSelection", self.ui.characterGrid, true)
  self.ui.grid:createElementAt(5, bottomRow, 1, 1, "pageIndicator", self.ui.pageIndicator)
  self.ui.grid:createElementAt(8, bottomRow, 1, 1, "changeInputButton", self.ui.changeInputButton)
  self.ui.grid:createElementAt(9, bottomRow, 1, 1, "leaveButton", self.ui.leaveButton)

  self:setupRoster()

  -- need to be created at the end after the character grid has been settled in
  -- otherwise the placement will be wrong
  self.ui.pageTurnButtons = self:createPageTurnButtons(self.ui.characterGrid)
end

-- Creates all per-player UI: panel/stage/level selectors, cursors, top-row
-- character icons and player info cards. Roster-dependent; called from
-- loadUserInterface and rebuilt by refreshRoster on drop-in/drop-out.
function CharacterSelect2p:setupRoster()
  -- Online play has exactly one local player whose selectors are interactive; remote
  -- players' selections come from the server. Size the carousel for one row.
  local rowsToShow
  if self.battleRoom.online then
    rowsToShow = 1
  else
    rowsToShow = math.max(1, #self.battleRoom.players)
  end
  local panelHeight = (self.ui.grid.unitSize - self.ui.grid.unitMargin * 2) / rowsToShow - self.ui.panelSelection.height
  local levelHeight, stageWidth
  if self.battleRoom.online then
    levelHeight = 12
    stageWidth = self.ui.grid.unitSize - self.ui.grid.unitMargin * 2
  else
    levelHeight = 20
    stageWidth = self.ui.grid.unitSize * 1.5 - self.ui.grid.unitMargin * 2
  end

  self.ui.characterIcons = {}
  self.ui.playerInfos = {}

  for i, player in ipairs(self.players) do
    -- Online: only add the local player's selectors. Stage was already
    -- local-only; panels and level now match.
    local showSelectors = (not self.battleRoom.online) or player.isLocal
    if showSelectors then
      local panelCarousel = self:createPanelCarousel(player, panelHeight)
      self.ui.panelSelection:addElement(panelCarousel, player)
    end

    if player.isLocal then
      local stageCarousel = self:createStageCarousel(player, stageWidth)
      self.ui.stageSelection:addElement(stageCarousel, player)
    end

    if showSelectors then
      local levelSlider = self:createLevelSlider(player, levelHeight, panelHeight)
      self.ui.levelSelection:addElement(levelSlider, player)
    end

    local cursor = self:createCursor(self.ui.grid, player)
    cursor.raise1Callback = function()
      self.ui.characterGrid:turnPage(-1)
    end
    cursor.raise2Callback = function()
      self.ui.characterGrid:turnPage(1)
    end
    self.ui.cursors[i] = cursor

    self.ui.characterIcons[i] = self:createPlayerIcon(player)
    self.ui.playerInfos[i] = self:createPlayerInfo(player)
  end

  -- All pairs in a single centered row. Each pair = 2 cols wide.
  local n = #self.players
  local startCol = math.floor((self.ui.grid.gridWidth - n * 2) / 2) + 1
  for i, player in ipairs(self.players) do
    local iconX = startCol + (i - 1) * 2
    local infoX = iconX + 1
    self.ui.grid:createElementAt(iconX, 1, 1, 1, "p" .. i .. " icon", self.ui.characterIcons[i])
    self.ui.grid:createElementAt(infoX, 1, 1, 1, "player " .. i .. " info", self.ui.playerInfos[i])
  end
end

-- Drop-in / drop-out hook for open FFA. Tears down all per-player widgets and
-- rebuilds them from the current self.players list.
function CharacterSelect2p:refreshRoster()
  -- Detach every top-row (icons + info pairs) — the layout may have wrapped
  -- across multiple rows depending on the prior player count.
  if self.ui.grid and self.ui.grid.removeElementsIn then
    local topRowCount = (self._layout and self._layout.topRowCount) or 1
    self.ui.grid:removeElementsIn(1, 1, self.ui.grid.gridWidth, topRowCount)
  end

  -- Clear the panel/stage/level wrappers and reset their stacking state. Using
  -- bare child:detach() leaves StackPanel.pixelsTaken/height stale (see the
  -- IMPORTANT note on StackPanel:remove) — next addElement positions children
  -- at the stale y offset, pushing carousels/sliders outside their cell. We
  -- nuke the children entirely (including the title), reset stack counters to
  -- zero, then re-add the title via StackPanel.addElement so its y/height
  -- bookkeeping starts fresh.
  for _, wrapper in ipairs({self.ui.panelSelection, self.ui.stageSelection, self.ui.levelSelection}) do
    if wrapper and wrapper.children then
      for i = #wrapper.children, 1, -1 do
        wrapper.children[i]:detach()
      end
      wrapper.pixelsTaken = 0
      wrapper.height = 0
      wrapper.width = 0
      wrapper.wrappedElements = {}
      if wrapper.title then
        wrapper.title.x = 0
        wrapper.title.y = 0
        wrapper:applyStackPanelSettings(wrapper.title)
        wrapper:addChild(wrapper.title)
      end
    end
  end

  -- Detach existing cursors from the grid.
  for _, cursor in pairs(self.ui.cursors or {}) do
    if cursor and cursor.detach then cursor:detach() end
  end
  self.ui.cursors = {}

  self:setupRoster()
end


return CharacterSelect2p
