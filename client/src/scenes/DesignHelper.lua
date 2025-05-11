local class = require("common.lib.class")
local Scene = require("client.src.scenes.Scene")
local ui = require("client.src.ui")
local input = require("client.src.inputManager")

local DesignHelper = class(function(self, sceneParams)
  --self:load(sceneParams)
end, Scene)

DesignHelper.name = "DesignHelper"

function DesignHelper:load()
  self.uiRoot.layout = ui.Layouts.VerticalFlexLayout

  local roomMode = ui.ButtonGroup({
    childGap = 8,
    padding = 8,
    hAlign = "center",
    --hFill = true,
    backgroundColor = {1, 0, 0, 0.5},
  })

  roomMode:addChild(ui.Text({text = "Battle", hAlign = "center", vAlign = "center"}))
  roomMode:addChild(ui.Text({text = "Arcade", hAlign = "center", vAlign = "center"}))

  self.uiRoot:addChild(roomMode)

  local gameMode = ui.HorizontalRadioSelector({
    childGap = 8,
    padding = 8,
    backgroundColor = {0, 0, 1, 0.5},
    hAlign = "center",
  --  hFill = true,
  })

  gameMode:addChild(ui.Text({text = "VS", wrap = false}))
  gameMode:addChild(ui.Text({text = "VS Self", wrap = false}))
  gameMode:addChild(ui.Text({text = "Time Attack", wrap = false}))
  gameMode:addChild(ui.Text({text = "Endless", wrap = false}))
  gameMode:addChild(ui.Text({text = "Puzzle", wrap = false}))
  gameMode:addChild(ui.Text({text = "Training", wrap = false}))
  gameMode:addChild(ui.Text({text = "Line Clear", wrap = false}))

  self.uiRoot:addChild(gameMode)

  local subSelectionSelector = ui.UIElement({
    childGap = 8,
    padding = 8,
    hFill = true,
    backgroundColor = {0, 1, 0, 0.5}
  })

  subSelectionSelector:addChild(ui.Text({text = "Character", wrap = false}))
  subSelectionSelector:addChild(ui.Text({text = "Stage", wrap = false}))
  subSelectionSelector:addChild(ui.Text({text = "Panels", wrap = false}))
  subSelectionSelector:addChild(ui.Text({text = "Ranked", wrap = false}))
  subSelectionSelector:addChild(ui.Text({text = "Level", wrap = false}))
  subSelectionSelector:addChild(ui.Text({text = "Input Selection", wrap = false}))
  subSelectionSelector:addChild(ui.Text({text = "Puzzle", wrap = false}))
  subSelectionSelector:addChild(ui.Text({text = "Attack File", wrap = false}))

  self.uiRoot:addChild(subSelectionSelector)

  local subSelection = ui.UIElement({
    hFill = true,
    minHeight = 400,
    vFill = true,
    padding = 8,
    backgroundColor = {0.7, 0, 0.5, 1},
  })

  subSelection:addChild(ui.Text({}))

  self.uiRoot:addChild(subSelection)

  self.uiRoot:addChild(ui.Text({text = "Ready", hAlign = "center"}))
  self.uiRoot:addChild(ui.Text({text = "Leave", hAlign = "center"}))
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
  if input.allKeys.isDown["MenuEsc"] then
    GAME.navigationStack:pop()
  end
end

function DesignHelper:draw()
  self.uiRoot:draw()
end

return DesignHelper
