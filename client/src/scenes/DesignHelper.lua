local class = require("common.lib.class")
local Scene = require("client.src.scenes.Scene")
local ui = require("client.src.ui")
local inputs = require("client.src.inputManager")
local prof = require("common.lib.zoneProfiler")

local DesignHelper = class(function(self, sceneParams)
  self:load(sceneParams)
end, Scene)

DesignHelper.name = "DesignHelper"

local function getSelectorTemplate(id)
  local selector = ui.UiElement({
    layout = ui.Layouts.VerticalFlexLayout,
    childGap = 4,
    vAlign = "center",
    hAlign = "center",
    vFill = true,
  })
  local button = ui.Button({
    hAlign = "center",
    vAlign = "center",
    minWidth = 84,
    minHeight = 84,
    backgroundColor = {1, 1, 1, 0},
  })
  local label = ui.Label({id = id})
  selector:addChild(button)
  selector:addChild(label)

  return selector, button
end

function DesignHelper:load()
  self.uiRoot.layout = ui.Layouts.VerticalFlexLayout
  self.uiRoot.childGap = 8

  local roomMode = ui.UiElement({
    childGap = 8,
    padding = 8,
    hAlign = "center",
    --hFill = true,
    backgroundColor = {1, 0, 0, 0.5},
    layout = ui.Layouts.HorizontalFlexLayout,
  })

  roomMode:addChild(ui.Label({text = "Battle", hAlign = "center", vAlign = "center"}))
  roomMode:addChild(ui.Label({text = "Arcade", hAlign = "center", vAlign = "center"}))

  roomMode.receiveInputs = function() end

  self.uiRoot:addChild(roomMode)

  local gameMode = ui.UiElement({
    childGap = 8,
    padding = 8,
    backgroundColor = {0, 0, 1, 0.5},
    hAlign = "center",
    layout = ui.Layouts.HorizontalFlexLayout,
  --  hFill = true,
  })

  gameMode:addChild(ui.Label({text = "VS"}))
  gameMode:addChild(ui.Label({text = "VS Self"}))
  gameMode:addChild(ui.Label({text = "Time Attack"}))
  gameMode:addChild(ui.Label({text = "Endless"}))
  gameMode:addChild(ui.Label({text = "Puzzle"}))
  gameMode:addChild(ui.Label({text = "Training"}))
  gameMode:addChild(ui.Label({text = "Line Clear"}))

  gameMode.receiveInputs = function() end

  self.uiRoot:addChild(gameMode)

  local subSelectionSelector = ui.UniSizedContainer({
    childGap = 32,
    padding = 8,
    backgroundColor = {0, 1, 0, 0.5},
    childrenWidth = 112,
    childrenHeight = 112,
    hAlign = "center",
    vAlign = "center",
    --scrollOrientation = "horizontal",
  })

  local characterImage = ui.ImageContainer({
    image = characters[GAME.localPlayer.settings.selectedCharacterId].images.icon,
    drawBorders = true,
    outlineColor = {1, 1, 1, 1},
    hFill = true,
    vFill = true,
  })
  local characterSelectionSelector, characterButton = getSelectorTemplate("character")
  characterButton:addChild(characterImage)

  local stageImage = ui.ImageContainer({
    image = stages[GAME.localPlayer.settings.selectedStageId].images.thumbnail,
    drawBorders = true,
    outlineColor = {1, 1, 1, 1},
    hFill = true,
    vFill = true,
  })
  local stageSelectionSelector, stageButton = getSelectorTemplate("stage")
  stageButton:addChild(stageImage)

  local panelSelectionSelector, panelButton = getSelectorTemplate("panels")

  local panelSize = 28
  local panelContainer = ui.UniSizedContainer({
    maxWidth = 3 * panelSize,
    childrenWidth = panelSize,
    childrenHeight = panelSize,
  })

  for color = 1, 8 do
    local panelImage = ui.ImageContainer({
      image = panels[GAME.localPlayer.settings.panelId].displayIcons[color],
      width = panelSize,
      height = panelSize,
    })
    panelContainer:addChild(panelImage)
  end
  panelContainer:addChild(ui.ImageContainer({
    image = panels[GAME.localPlayer.settings.panelId].greyPanel,
    width = panelSize,
    height = panelSize,
  }))
  panelButton:addChild(panelContainer)

  local levelImage = ui.ImageContainer({
    image = GAME.theme.images.IMG_levels[GAME.localPlayer.settings.level or 1],
    hFill = true,
    vFill = true,
  })
  local levelSelectionSelector, levelButton = getSelectorTemplate("level")
  levelButton:addChild(levelImage)


  subSelectionSelector:addChild(characterSelectionSelector)
  subSelectionSelector:addChild(stageSelectionSelector)
  subSelectionSelector:addChild(panelSelectionSelector)
  --subSelectionSelector:addChild(ui.Label({text = "Ranked"}))
  subSelectionSelector:addChild(levelSelectionSelector)
  --subSelectionSelector:addChild(ui.Label({text = "Input Selection"}))
  --subSelectionSelector:addChild(ui.Label({text = "Puzzle"}))
  --subSelectionSelector:addChild(ui.Label({text = "Attack File"}))

  local readyButton = ui.TextButton({
    label = ui.Label({id = "ready"}),
    hAlign = "center",
    vAlign = "center",
    minWidth = 84,
    minHeight = 84,
    maxWidth = 84,
    maxHeight = 84,
  })

  local leaveButton = ui.TextButton({
    label = ui.Label({id = "leave"}),
    hAlign = "center",
    vAlign = "center",
    minWidth = 84,
    minHeight = 84,
    maxWidth = 84,
    maxHeight = 84,
  })

  subSelectionSelector:addChild(readyButton)
  subSelectionSelector:addChild(leaveButton)
  --passThroughSelector:addChild(subSelectionSelector)
  --self.uiRoot:addChild(passThroughSelector)
  self.uiRoot:addChild(subSelectionSelector)

  local subSelection = ui.UiElement({
    hFill = true,
    minHeight = 200,
    vFill = true,
    padding = 8,
    backgroundColor = {0, 1, 0, 0.5}--{0.7, 0, 0.5, 1},
  })

  subSelection.receiveInputs = function() end

  self.uiRoot:addChild(subSelection)

  self.cursor = ui.Cursor({
    target = self.uiRoot,
    hoveredIndex = 3,
  })
end

function DesignHelper:loadRankedSelection(width)
  local rankedSelector = ui.BoolSelector({startValue = true, vFill = true, width = width, vAlign = "center", hAlign = "center"})

  return rankedSelector
end

function DesignHelper:loadPanels()
  self.panelCarousel = ui.PanelCarousel({hAlign = "center", vAlign = "center", hFill = true, vFill = true})
  self.panelCarousel:loadPanels()
end

function DesignHelper:loadStages()
  self.stageCarousel = ui.StageCarousel({hAlign = "center", vAlign = "center", hFill = true, vFill = true})
  self.stageCarousel:loadCurrentStages()
end

function DesignHelper:update(dt)
  if inputs.isDown["MenuEsc"] and not self.cursor.focused then
    GAME.navigationStack:pop()
  end
  self.cursor:receiveInputs(inputs, dt)
end

function DesignHelper:draw()
  self.cursor:draw()
  self.uiRoot:draw()
end

return DesignHelper
