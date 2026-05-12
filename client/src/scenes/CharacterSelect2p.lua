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
  self.ui.grid = ui.Grid({unitSize = 100, gridWidth = 9, gridHeight = 6, unitMargin = 8, hAlign = "center", vAlign = "center"})
  self.uiRoot:addChild(self.ui.grid)

  self.ui.panelSelection = ui.MultiPlayerSelectionWrapper({hFill = true, alignment = "top", hAlign = "center", vAlign = "top"})
  self.ui.panelSelection:setTitle("panels")
  self.ui.stageSelection = ui.MultiPlayerSelectionWrapper({vFill = true, alignment = "left", hAlign = "center", vAlign = "center"})
  self.ui.stageSelection:setTitle("stage")
  self.ui.levelSelection = ui.MultiPlayerSelectionWrapper({hFill = true, alignment = "top", hAlign = "center", vAlign = "top"})
  self.ui.levelSelection:setTitle("level")

  self.ui.readyButton = self:createReadyButton()

  local characterButtons = self:getCharacterButtons()
  local characterGridWidth, characterGridHeight = self.ui.grid.gridWidth, 3
  self.ui.characterGrid = self:createCharacterGrid(characterButtons, self.ui.grid, characterGridWidth, characterGridHeight)

  self.ui.pageIndicator = self:createPageIndicator(self.ui.characterGrid)

  self.ui.leaveButton = self:createLeaveButton()
  self.ui.changeInputButton = self:createChangeInputButton()

  if self.battleRoom.online then
    self.ui.grid:createElementAt(1, 2, 2, 1, "panelSelection", self.ui.panelSelection, nil, true)
    self.ui.grid:createElementAt(5, 2, 2, 1, "stageSelection", self.ui.stageSelection, nil, true)
    self.ui.grid:createElementAt(7, 2, 2, 1, "levelSelection", self.ui.levelSelection, nil, true)
  else
    self.ui.grid:createElementAt(1, 2, 2, 1, "panelSelection", self.ui.panelSelection, nil, true)
    self.ui.grid:createElementAt(3, 2, 3, 1, "stageSelection", self.ui.stageSelection, nil, true)
    self.ui.grid:createElementAt(6, 2, 3, 1, "levelSelection", self.ui.levelSelection, nil, true)
  end

  self.ui.grid:createElementAt(9, 2, 1, 1, "readyButton", self.ui.readyButton)
  self.ui.grid:createElementAt(1, 3, characterGridWidth, characterGridHeight, "characterSelection", self.ui.characterGrid, true)
  self.ui.grid:createElementAt(5, 6, 1, 1, "pageIndicator", self.ui.pageIndicator)
  self.ui.grid:createElementAt(8, 6, 1, 1, "changeInputButton", self.ui.changeInputButton)
  self.ui.grid:createElementAt(9, 6, 1, 1, "leaveButton", self.ui.leaveButton)

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

  -- Slot layouts on the 9-wide grid (col 9 row 2 = readyButton):
  --   ≤4: (icon, info) pairs in cols 1-8 — info card carries the wins display.
  --   5:  icons every-other-col 1,3,5,7,9 — evenly distributed, no info cards.
  --   6+: icons in consecutive cols 1..N — info cards dropped, wins shown on
  --       the icon itself (see CharacterSelect:createPlayerIcon).
  local topSlots = {}
  local playerCount = #self.players
  if playerCount >= 6 then
    for i = 1, playerCount do
      topSlots[i] = { iconX = i }
    end
  elseif playerCount == 5 then
    topSlots = {
      { iconX = 1 },
      { iconX = 3 },
      { iconX = 5 },
      { iconX = 7 },
      { iconX = 9 },
    }
  else
    for i = 1, playerCount do
      topSlots[i] = { iconX = (i - 1) * 2 + 1, infoX = (i - 1) * 2 + 2 }
    end
  end
  for i, player in ipairs(self.players) do
    local slot = topSlots[i]
    if slot then
      self.ui.grid:createElementAt(slot.iconX, 1, 1, 1, "p" .. i .. " icon", self.ui.characterIcons[i])
      if slot.infoX then
        self.ui.grid:createElementAt(slot.infoX, 1, 1, 1, "player " .. i .. " info", self.ui.playerInfos[i])
      end
    end
  end
end

-- Drop-in / drop-out hook for open FFA. Tears down all per-player widgets and
-- rebuilds them from the current self.players list.
function CharacterSelect2p:refreshRoster()
  -- Row 1: detach all top-row icons + info cards from the grid.
  if self.ui.grid and self.ui.grid.removeElementsIn then
    self.ui.grid:removeElementsIn(1, 1, self.ui.grid.gridWidth, 1)
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
