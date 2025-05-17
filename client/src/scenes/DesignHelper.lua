local class = require("common.lib.class")
local Scene = require("client.src.scenes.Scene")
local ui = require("client.src.ui")
local input = require("client.src.inputManager")
local prof = require("common.lib.zoneProfiler")

local DesignHelper = class(function(self, sceneParams)
  self:load(sceneParams)
end, Scene)

DesignHelper.name = "DesignHelper"

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

  self.uiRoot:addChild(gameMode)

  local subSelectionSelector = ui.ScrollContainer({
    childGap = 32,
    padding = 8,
    hFill = true,
    backgroundColor = {0, 1, 0, 0.5},
    scrollOrientation = "horizontal",
  })

  local characterButton = ui.Button({
    hAlign = "center",
    vAlign = "center",
    minWidth = 64,
    minHeight = 64,
    backgroundColor = {1, 1, 1, 0},
  })
  local characterImage = ui.ImageContainer({
    image = characters[GAME.localPlayer.settings.selectedCharacterId].images.icon,
    drawBorders = true,
    outlineColor = {1, 1, 1, 1},
    hFill = true,
    vFill = true,
  })
  characterButton:addChild(characterImage)
  local characterSelectionSelector = ui.UiElement({
    layout = ui.Layouts.VerticalFlexLayout,
    vAlign = "center",
    vFill = true,
  })
  characterSelectionSelector:addChild(characterButton)
  characterSelectionSelector:addChild(ui.Label({id = "character", hAlign = "center", vAlign = "bottom"}))

  local stageSelectionSelector = ui.UiElement({
    layout = ui.Layouts.VerticalFlexLayout,
    vAlign = "center",
    vFill = true,
  })
  local stageButton = ui.Button({
    hAlign = "center",
    vAlign = "center",
    minWidth = 64,
    minHeight = 64,
    backgroundColor = {1, 1, 1, 0},
  })
  local stageImage = ui.ImageContainer({
    image = stages[GAME.localPlayer.settings.selectedStageId].images.thumbnail,
    drawBorders = true,
    outlineColor = {1, 1, 1, 1},
    hFill = true,
    vFill = true,
  })
  stageButton:addChild(stageImage)
  stageSelectionSelector:addChild(stageButton)
  stageSelectionSelector:addChild(ui.Label({id = "stage", hAlign = "center", vAlign = "bottom"}))


  local panelSelectionSelector = ui.UiElement({
    layout = ui.Layouts.VerticalFlexLayout,
    vAlign = "center",
    vFill = true,
  })
  local panelButton = ui.Button({
    hAlign = "center",
    vAlign = "center",
    minWidth = 64,
    minHeight = 64,
    backgroundColor = {1, 1, 1, 0},
  })

  local panelSize = 24
  local panelContainer = ui.UiElement({
    layout = ui.Layouts.HorizontalWrapLayout,
    maxWidth = 3 * panelSize
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
  panelSelectionSelector:addChild(panelButton)
  panelSelectionSelector:addChild(ui.Label({id = "panels", hAlign = "center", vAlign = "bottom"}))

  local levelSelectionSelector = ui.UiElement({
    layout = ui.Layouts.VerticalFlexLayout,
    vAlign = "center",
    vFill = true,
  })

  local levelButton = ui.Button({
    hAlign = "center",
    vAlign = "center",
    minWidth = 64,
    minHeight = 64,
    backgroundColor = {1, 1, 1, 0},
  })
  local levelImage = ui.ImageContainer({
    image = GAME.theme.images.IMG_levels[GAME.localPlayer.settings.level or 1],
    hFill = true,
    vFill = true,
  })
  levelButton:addChild(levelImage)
  levelSelectionSelector:addChild(levelButton)
  levelSelectionSelector:addChild(ui.Label({id = "level", hAlign = "center", vAlign = "bottom"}))

  subSelectionSelector:addChild(characterSelectionSelector)
  subSelectionSelector:addChild(stageSelectionSelector)
  subSelectionSelector:addChild(panelSelectionSelector)
  subSelectionSelector:addChild(ui.Label({text = "Ranked"}))
  subSelectionSelector:addChild(levelSelectionSelector)
  subSelectionSelector:addChild(ui.Label({text = "Input Selection"}))
  subSelectionSelector:addChild(ui.Label({text = "Puzzle"}))
  subSelectionSelector:addChild(ui.Label({text = "Attack File"}))

  self.uiRoot:addChild(subSelectionSelector)

  local subSelection = ui.UiElement({
    hFill = true,
    minHeight = 200,
    vFill = true,
    padding = 8,
    backgroundColor = {0.7, 0, 0.5, 1},
  })

  --subSelection:addChild(ui.Label({}))

  self.uiRoot:addChild(subSelection)

  self.uiRoot:addChild(ui.Label({text = "Ready", hAlign = "center"}))
  self.uiRoot:addChild(ui.Label({text = "Leave", hAlign = "center"}))
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

function DesignHelper:update()
  if input.isDown["MenuEsc"] then
    GAME.navigationStack:pop()
  end
end

function DesignHelper:draw()
  self.uiRoot:draw()
end

return DesignHelper
