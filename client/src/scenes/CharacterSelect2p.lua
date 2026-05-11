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

  local levelHeight
  -- Online play has exactly one local player whose selectors are interactive; remote
  -- players' selections come from the server. Stacking N rows into a fixed 100px
  -- band crushes per-row height (5p → ~3px each), so for online we only show the
  -- local row and size the carousel for one row.
  local rowsToShow
  if self.battleRoom.online then
    rowsToShow = 1
  else
    rowsToShow = #self.battleRoom.players
  end
  local panelHeight = (self.ui.grid.unitSize - self.ui.grid.unitMargin * 2) / rowsToShow - self.ui.panelSelection.height
  local stageWidth

  if self.battleRoom.online then
    self.ui.grid:createElementAt(1, 2, 2, 1, "panelSelection", self.ui.panelSelection, nil, true)
    self.ui.grid:createElementAt(5, 2, 2, 1, "stageSelection", self.ui.stageSelection, nil, true)
    self.ui.grid:createElementAt(7, 2, 2, 1, "levelSelection", self.ui.levelSelection, nil, true)

    levelHeight = 12
    stageWidth = self.ui.grid.unitSize - self.ui.grid.unitMargin * 2
  else
    self.ui.grid:createElementAt(1, 2, 2, 1, "panelSelection", self.ui.panelSelection, nil, true)
    self.ui.grid:createElementAt(3, 2, 3, 1, "stageSelection", self.ui.stageSelection, nil, true)
    self.ui.grid:createElementAt(6, 2, 3, 1, "levelSelection", self.ui.levelSelection, nil, true)

    levelHeight = 20
    stageWidth = self.ui.grid.unitSize * 1.5 - self.ui.grid.unitMargin * 2
  end

  self.ui.grid:createElementAt(9, 2, 1, 1, "readyButton", self.ui.readyButton)
  self.ui.grid:createElementAt(1, 3, characterGridWidth, characterGridHeight, "characterSelection", self.ui.characterGrid, true)
  self.ui.grid:createElementAt(5, 6, 1, 1, "pageIndicator", self.ui.pageIndicator)
  self.ui.grid:createElementAt(8, 6, 1, 1, "changeInputButton", self.ui.changeInputButton)
  self.ui.grid:createElementAt(9, 6, 1, 1, "leaveButton", self.ui.leaveButton)

  self.ui.characterIcons = {}

  for i, player in ipairs(self.players) do
    -- Online: only add the local player's selectors so the wrapper sizes for one
    -- row instead of cramming N rows into the same space. Stage was already
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

  -- Up to 4 players: (icon, info) pairs across columns 1-8 (col 9 = readyButton row 2).
  -- 5 players: drop the info column and space 5 icons every-other-column (1,3,5,7,9)
  -- so they fit in the 9-wide grid without overflowing the readyButton column.
  local topSlots
  if #self.players >= 5 then
    topSlots = {
      { iconX = 1 },
      { iconX = 3 },
      { iconX = 5 },
      { iconX = 7 },
      { iconX = 9 },
    }
  else
    topSlots = {
      { iconX = 1, infoX = 2 },
      { iconX = 3, infoX = 4 },
      { iconX = 5, infoX = 6 },
      { iconX = 7, infoX = 8 },
    }
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

  -- need to be created at the end after the character grid has been settled in
  -- otherwise the placement will be wrong
  self.ui.pageTurnButtons = self:createPageTurnButtons(self.ui.characterGrid)
end


return CharacterSelect2p
