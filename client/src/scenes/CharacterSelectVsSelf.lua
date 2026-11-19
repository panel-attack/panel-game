local CharacterSelect = require("client.src.scenes.CharacterSelect")
local class = require("common.lib.class")
local ui = require("client.src.ui")
local Layout = require("client.src.ui.Layout")

-- a selection stacking its players' elements top to bottom across its whole cell
local COLUMN_SELECTION_RULES = {sizing = {horizontal = Layout.GROW}}
-- a selection putting its players' elements side by side as tall as its cell, centered on each other
local ROW_SELECTION_RULES = {sizing = {vertical = Layout.GROW}, childAlignment = Layout.CENTER_VERTICALLY}

-- The character select screen scene
local CharacterSelectVsSelf = class(
  function (self, sceneParams)
    self.lastScore = nil
    self.record = nil
  end,
  CharacterSelect
)

CharacterSelectVsSelf.name = "CharacterSelectVsSelf"

function CharacterSelectVsSelf:customLoad(sceneParams)
  self:loadUserInterface()
end

function CharacterSelectVsSelf:loadUserInterface()
  local player = self.battleRoom.players[1]

  self.ui.grid = ui.Grid({
    unitSize = 100, gridWidth = 9, gridHeight = 6, unitMargin = 8
  })
  self.uiRoot:addChild(self.ui.grid)

  self.ui.characterIcons[1] = self:createPlayerIcon(player)
  self.ui.grid:createElementAt(1, 1, 1, 1, "selectedCharacter", self.ui.characterIcons[1])

  self.ui.recordBox = self:createRecordsBox("last lines")
  self:refresh()
  local recordCell = self.ui.grid:createElementAt(2, 1, 2, 1, "recordBox", self.ui.recordBox)
  recordCell:setLayoutRule("childAlignment", Layout.CENTER_VERTICALLY)

  self.ui.panelSelection = ui.MultiPlayerSelectionWrapper({alignment = "top", layoutRules = COLUMN_SELECTION_RULES})
  self.ui.panelSelection:setTitle("panels")
  local panelCarousel = self:createPanelCarousel(player, self:getHeightUnderTitle(self.ui.panelSelection))
  self.ui.panelSelection:addElement(panelCarousel, player)
  self.ui.grid:createElementAt(1, 2, 2, 1, "panelSelection", self.ui.panelSelection)

  local stageCarousel = self:createStageCarousel(player, self.ui.grid.unitSize * 3 - self.ui.grid.unitMargin * 2)
  self.ui.stageSelection = ui.MultiPlayerSelectionWrapper({alignment = "left", layoutRules = ROW_SELECTION_RULES})
  self.ui.stageSelection:setTitle("stage")
  self.ui.stageSelection:addElement(stageCarousel, player)
  local stageCell = self.ui.grid:createElementAt(3, 2, 3, 1, "stageSelection", self.ui.stageSelection)
  stageCell:setLayoutRule("childAlignment", Layout.CENTER_HORIZONTALLY)

  self.ui.levelSelection = ui.MultiPlayerSelectionWrapper({alignment = "top", layoutRules = COLUMN_SELECTION_RULES})
  self.ui.levelSelection:setTitle("level")
  local levelSlider = self:createLevelSlider(player, 20, self:getHeightUnderTitle(self.ui.levelSelection))
  local oldOnValueChange = levelSlider.onValueChange
  levelSlider.onValueChange = function(ls)
    oldOnValueChange(ls)
    self.lastScore = GAME.scores:lastVsScoreForLevel(ls.value)
    self.record = GAME.scores:recordVsScoreForLevel(ls.value)
    self.ui.recordBox:setLastResult(self.lastScore)
    self.ui.recordBox:setRecord(self.record)
  end
  self.ui.levelSelection:addElement(levelSlider, player)
  self.ui.grid:createElementAt(6, 2, 3, 1, "levelSelection", self.ui.levelSelection)

  self.ui.readyButton = self:createReadyButton()
  self.ui.grid:createElementAt(9, 2, 1, 1, "readyButton", self.ui.readyButton)

  local characterButtons = self:getCharacterButtons()
  local characterGridWidth, characterGridHeight = 9, 3
  self.ui.characterGrid = self:createCharacterGrid(characterButtons, self.ui.grid, characterGridWidth, characterGridHeight)
  self.ui.grid:createElementAt(1, 3, characterGridWidth, characterGridHeight, "characterSelection", self.ui.characterGrid, true)

  self.ui.pageIndicator = self:createPageIndicator(self.ui.characterGrid)
  local pageIndicatorCell = self.ui.grid:createElementAt(5, 6, 1, 1, "pageIndicator", self.ui.pageIndicator)
  pageIndicatorCell:setLayoutRule("childAlignment", Layout.CENTER_HORIZONTALLY)

  self.ui.pageTurnButtons = self:createPageTurnButtons(self.ui.characterGrid)

  self.ui.leaveButton = self:createLeaveButton()
  self.ui.changeInputButton = self:createChangeInputButton()
  self.ui.grid:createElementAt(8, 6, 1, 1, "changeInputButton", self.ui.changeInputButton)
  self.ui.grid:createElementAt(9, 6, 1, 1, "leaveButton", self.ui.leaveButton)

  self.ui.cursors[1] = self:createCursor(self.ui.grid, player)
  self.ui.cursors[1].raise1Callback = function()
    self.ui.characterGrid:turnPage(-1)
  end
  self.ui.cursors[1].raise2Callback = function()
    self.ui.characterGrid:turnPage(1)
  end
end

function CharacterSelectVsSelf:refresh()
  local level
  if self.battleRoom then
    level = self.battleRoom.players[1].settings.level
    self.lastScore = GAME.scores:lastVsScoreForLevel(level)
    self.record = GAME.scores:recordVsScoreForLevel(level)
    if self.ui.recordBox then
      self.ui.recordBox:setLastResult(self.lastScore)
      self.ui.recordBox:setRecord(self.record)
    end
  end
end

return CharacterSelectVsSelf
