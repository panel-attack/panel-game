local CharacterSelect = require("client.src.scenes.CharacterSelect")
local class = require("common.lib.class")
local ui = require("client.src.ui")
local Layout = require("client.src.ui.Layout")

-- a selection stacking its players' elements top to bottom across its whole cell
local COLUMN_SELECTION_RULES = {sizing = {horizontal = Layout.GROW}}
-- a selection putting its players' elements side by side as tall as its cell, centered on each other
local ROW_SELECTION_RULES = {sizing = {vertical = Layout.GROW}, childAlignment = Layout.CENTER_VERTICALLY}

---@class CharacterSelectChallenge : CharacterSelect
local CharacterSelectChallenge = class(
  function (self, sceneParams)
  end,
  CharacterSelect
)

CharacterSelectChallenge.name = "CharacterSelectChallenge"

function CharacterSelectChallenge:customLoad(sceneParams)
  self:loadUserInterface()
end

function CharacterSelectChallenge:loadUserInterface()
  self.ui.grid = ui.Grid({
    unitSize = 100, gridWidth = 9, gridHeight = 6, unitMargin = 8
  })
  self.uiRoot:addChild(self.ui.grid)

  self.ui.panelSelection = ui.MultiPlayerSelectionWrapper({alignment = "top", layoutRules = COLUMN_SELECTION_RULES})
  self.ui.panelSelection:setTitle("panels")
  self.ui.stageSelection = ui.MultiPlayerSelectionWrapper({alignment = "left", layoutRules = ROW_SELECTION_RULES})
  self.ui.stageSelection:setTitle("stage")
  self.ui.readyButton = self:createReadyButton()
  local characterButtons = self:getCharacterButtons()
  local characterGridWidth, characterGridHeight = self.ui.grid.gridWidth, 3
  self.ui.characterGrid = self:createCharacterGrid(characterButtons, self.ui.grid, characterGridWidth, characterGridHeight)
  self.ui.pageIndicator = self:createPageIndicator(self.ui.characterGrid)
  self.ui.leaveButton = self:createLeaveButton()
  self.ui.changeInputButton = self:createChangeInputButton()

  local panelHeight
  local stageWidth

  self.ui.grid:createElementAt(1, 2, 3, 1, "panelSelection", self.ui.panelSelection)
  local stageCell = self.ui.grid:createElementAt(4, 2, 3, 1, "stageSelection", self.ui.stageSelection)
  stageCell:setLayoutRule("childAlignment", Layout.CENTER_HORIZONTALLY)

  panelHeight = self:getHeightUnderTitle(self.ui.panelSelection)
  stageWidth = self.ui.grid.unitSize * 1.5 - self.ui.grid.unitMargin * 2

  self.ui.grid:createElementAt(9, 2, 1, 1, "readyButton", self.ui.readyButton)
  self.ui.grid:createElementAt(1, 3, characterGridWidth, characterGridHeight, "characterSelection", self.ui.characterGrid, true)
  local pageIndicatorCell = self.ui.grid:createElementAt(5, 6, 1, 1, "pageIndicator", self.ui.pageIndicator)
  pageIndicatorCell:setLayoutRule("childAlignment", Layout.CENTER_HORIZONTALLY)
  self.ui.grid:createElementAt(8, 6, 1, 1, "changeInputButton", self.ui.changeInputButton)
  self.ui.grid:createElementAt(9, 6, 1, 1, "leaveButton", self.ui.leaveButton)

  self.ui.characterIcons = {}
  for i = 1, #self.battleRoom.players do
    local player = self.battleRoom.players[i]

    if player.human then
      local panelCarousel = self:createPanelCarousel(player, panelHeight)
      self.ui.panelSelection:addElement(panelCarousel, player)

      local cursor = self:createCursor(self.ui.grid, player)
      cursor.raise1Callback = function()
        self.ui.characterGrid:turnPage(-1)
      end
      cursor.raise2Callback = function()
        self.ui.characterGrid:turnPage(1)
      end
      self.ui.cursors[i] = cursor
    end

    local stageCarousel = self:createStageCarousel(player, stageWidth)
    self.ui.stageSelection:addElement(stageCarousel, player)

    self.ui.characterIcons[i] = self:createPlayerIcon(player)
  end

  self.ui.grid:createElementAt(1, 1, 1, 1, "p1 icon", self.ui.characterIcons[1])
  self.ui.grid:createElementAt(9, 1, 1, 1, "p2 icon", self.ui.characterIcons[2])

  -- need to be created at the end after the character grid has been settled in
  -- otherwise the placement will be wrong
  self.ui.pageTurnButtons = self:createPageTurnButtons(self.ui.characterGrid)
end

return CharacterSelectChallenge
