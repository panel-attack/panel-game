local Scene = require("client.src.scenes.Scene")
local class = require("common.lib.class")
local ScrollContainer = require("client.src.ui.ScrollContainer")
local StackPanel = require("client.src.ui.StackPanel")
local ImageContainer = require("client.src.ui.ImageContainer")
local BoolSelector = require("client.src.ui.BoolSelector")
local Grid = require("client.src.ui.Grid")
local Label = require("client.src.ui.Label")
local GridCursor = require("client.src.ui.GridCursor")
local inputs = require("common.lib.inputManager")
local tableUtils = require("common.lib.tableUtils")
local consts = require("common.engine.consts")
local CharacterLoader = require("client.src.mods.CharacterLoader")
local Menu = require("client.src.ui.Menu")
local MenuItem = require("client.src.ui.MenuItem")

local ModManagement = class(function(self, options)
  self.keepMusic = true
  self.receiveMode = "Menu"
  self:load()
end,
Scene)

ModManagement.name = "ModManagement"

function ModManagement:load()
  self.stackPanel = StackPanel(
    {
      alignment = "top",
      width = 600,
      hAlign = "center",
      vAlign = "top",
      x = 0,
      y = 49,
    }
  )

  self.headerLabel = Label({
    text = "placeholder",
    hAlign = "center",
    fontSize = 16,
  })

  self.headLine = self:loadGridHeader()

  self.stackPanel:addElement(self.headerLabel)
  self.stackPanel:addElement(self.headLine)

  self.stageGrid = self:loadStageGrid()
  self.characterGrid = self:loadCharacterGrid()

  self.scrollContainer = nil

  self.cursor = GridCursor({
    grid = self.characterGrid,
    player = GAME.localPlayer,
    frameImages = themes[config.theme].images.IMG_char_sel_cursors[1],
    startPosition = {x = 9, y = 1},
  })

  self.cursor.onMove = function(c)
    local newOffset = c.target.unitSize * (c.selectedGridPos.y - 1)
    if self.scrollContainer then
      self.scrollContainer:keepVisible(-newOffset, c.target.unitSize)
    end
  end

  self.cursor.escapeCallback = function(cursor)
    self.headLine:detach()
    self.stackPanel:remove(self.scrollContainer)
    self.scrollContainer = nil
    cursor:setTarget()
    GAME.theme:playCancelSfx()
    self.receiveMode = "Menu"
  end

  self.manageCharactersButton = MenuItem.createButtonMenuItem(
    "characters", nil, true,
    function(button, inputs)
      GAME.theme:playValidationSfx()
      if self.scrollContainer then
        self.stackPanel:remove(self.scrollContainer)
      end
      self.headerLabel:setText("characters")
      self.scrollContainer = self:newScrollContainer()
      self.scrollContainer:addChild(self.characterGrid)
      self.stackPanel:addElement(self.scrollContainer)
      self.uiRoot:addChild(self.stackPanel)
      self.cursor:setTarget(self.characterGrid, {x = 9, y = 1})
      self.receiveMode = "Grid"
    end
  )

  self.manageStagesButton = MenuItem.createButtonMenuItem(
    "stages", nil, true,
    function(button, inputs)
      GAME.theme:playValidationSfx()
      if self.scrollContainer then
        self.stackPanel:remove(self.scrollContainer)
      end
      self.headerLabel:setText("stages")
      self.scrollContainer = self:newScrollContainer()
      self.scrollContainer:addChild(self.stageGrid)
      self.stackPanel:addElement(self.scrollContainer)
      self.uiRoot:addChild(self.stackPanel)
      self.cursor:setTarget(self.stageGrid, {x = 9, y = 1})
      self.receiveMode = "Grid"
    end
  )

  self.backButton = MenuItem.createButtonMenuItem("back", nil, true,
    function(button, inputs)
      GAME.theme:playCancelSfx()
      GAME.navigationStack:pop()
    end
  )

  self.menu = Menu({
    menuItems =
    {
      self.manageCharactersButton,
      self.manageStagesButton,
      self.backButton
    },
    x = 100,
    y = 0,
    hAlign = "left",
    vAlign = "center",
    width = 200,
    height = 300,
  })

  self.uiRoot:addChild(self.menu)
end

function ModManagement:newScrollContainer()
  return ScrollContainer({
    width = 800,
    height = 550,
    hAlign = "center",
    vAlign = "top",
  })
end

local gridUnitSize = 50
local gridWidth = 10
local gridMargin = 4
local columnWidth = 2
local headerY = 90

function ModManagement:loadStageGrid()
  local stageGrid = Grid({
    unitSize = gridUnitSize,
    gridWidth = gridWidth,
    gridHeight = #stageIds - 1, -- cannot disable random stage as it's the fallback of fallbacks
    unitMargin = gridMargin,
    hAlign = "center",
    vAlign = "top"
  })

  for index, stageId in ipairs(stageIds) do
    if stageId ~= consts.RANDOM_STAGE_SPECIAL_VALUE then
      local stage = allStages[stageId]
      local icon = ImageContainer({drawBorders = true, image = stage.images.thumbnail, hFill = true, vFill = true, hAlign = "center", vAlign = "center"})
      local enableSelector = BoolSelector({startValue = not not stages[stage.id], hAlign = "center", vAlign = "center", hFill = true, vFill = true})
      enableSelector.onSelect = function(self, cursor)
        if inputs.isDown["Swap1"] then
          self:setValue(not self.value)
          stage:enable(self.value)
          if not self.value and stage.id == config.stage then
            GAME.localPlayer:setStage(stages[consts.RANDOM_STAGE_SPECIAL_VALUE])
          end
        end
      end
      local visibilitySelector = BoolSelector({startValue = stage.isVisible, hAlign = "center", vAlign = "center", hFill = true, vFill = true})
      visibilitySelector.onSelect = function(self, cursor)
        if inputs.isDown["Swap1"] then
          self:setValue(not self.value)
        end
      end
      local name = Label({text = stage.display_name, translate = false, hAlign = "center", vAlign = "center"})
      local hasMusicLabel = Label({text = tostring(stage.hasMusic):upper(), translate = false, hAlign = "center", vAlign = "center"})
      local subCount = 0
      if #stage.subIds > 0 then
        for _, c in ipairs(stage.subIds) do
          if allStages[c] then
            subCount = subCount + 1
          end
        end
      end
      local bundleIndicator = Label({text = tostring(subCount), translate = false, hAlign = "center", vAlign = "center"})
      stageGrid:createElementAt(1, index, 1, 1, "thumbnail", icon)
      stageGrid:createElementAt(2, index, 3, 1, "name", name)
      stageGrid:createElementAt(3*columnWidth - 1, index, columnWidth, 1, "hasMusic", hasMusicLabel)
      stageGrid:createElementAt(4*columnWidth - 1, index, columnWidth, 1, "subModCount", bundleIndicator)
      --stageGrid:createElementAt(5*columnWidth - 1, index, columnWidth, 1, "toggleVisibility", visibilitySelector)
      stageGrid:createElementAt(5*columnWidth - 1, index, columnWidth, 1, "toggleEnable", enableSelector)
    end
  end

  return stageGrid
end

function ModManagement:loadGridHeader()
  local headLine = Grid({
    unitSize = gridUnitSize,
    gridWidth = gridWidth,
    gridHeight = 1,
    unitMargin = gridMargin,
    hAlign = "center",
    vAlign = "top",
    y = headerY,
  })
  headLine:createElementAt(1, 1, 1, 1, "icon", Label({text = "Icon", hAlign = "center", vAlign = "center"}))
  headLine:createElementAt(2, 1, 3, 1, "name", Label({text = "Name", hAlign = "center", vAlign = "center"}))
  headLine:createElementAt(3*columnWidth - 1, 1, columnWidth, 1, "music", Label({text = "Music", hAlign = "center", vAlign = "center"}))
  headLine:createElementAt(4*columnWidth - 1, 1, columnWidth, 1, "subMods", Label({text = "Sub mods", hAlign = "center", vAlign = "center"}))
  --headLine:createElementAt(5*columnWidth - 1, 1, columnWidth, 1, "visible", Label({text = "Visible", hAlign = "center", vAlign = "center"}))
  headLine:createElementAt(5*columnWidth - 1, 1, columnWidth, 1, "enabled", Label({text = "Enabled", hAlign = "center", vAlign = "center"}))

  return headLine
end

function ModManagement:loadCharacterGrid()
  local characterGrid = Grid({
    unitSize = gridUnitSize,
    gridWidth = gridWidth,
    gridHeight = #characterIds - 1, -- cannot disable random character as it's the fallback of fallbacks
    unitMargin = gridMargin,
    hAlign = "center",
    vAlign = "top"
  })

  for index, characterId in ipairs(characterIds) do
    if characterId ~= consts.RANDOM_CHARACTER_SPECIAL_VALUE then
      local character = allCharacters[characterId]
      local icon = ImageContainer({drawBorders = true, image = character.images.icon, hFill = true, vFill = true})
      local enableSelector = BoolSelector({startValue = not not characters[character.id], hAlign = "center", vAlign = "center", hFill = true, vFill = true})
      enableSelector.onSelect = function(self, cursor)
        if inputs.isDown["Swap1"] then
          self:setValue(not self.value)
          character:enable(self.value)
          if not self.value and character.id == config.character then
            GAME.localPlayer:setCharacter(characters[consts.RANDOM_CHARACTER_SPECIAL_VALUE])
          end
        end
      end
      local visibilitySelector = BoolSelector({startValue = character.isVisible, hAlign = "center", vAlign = "center", hFill = true, vFill = true})
      visibilitySelector.onSelect = function(self, cursor)
        if inputs.isDown["Swap1"] then
          self:setValue(not self.value)
        end
      end
      local displayName = Label({text = character.display_name, translate = false, hAlign = "center", vAlign = "center"})
      local hasMusicLabel = Label({text = tostring(character.hasMusic):upper(), translate = false, hAlign = "center", vAlign = "center"})
      local subCount = 0
      if #character.subIds > 0 then
        for _, c in ipairs(character.subIds) do
          if allCharacters[c] then
            subCount = subCount + 1
          end
        end
      end
      local bundleIndicator = Label({text = tostring(subCount), translate = false, hAlign = "center", vAlign = "center"})
      characterGrid:createElementAt(1, index, 1, 1, "icon", icon)
      characterGrid:createElementAt(2, index, 3, 1, "name", displayName)
      characterGrid:createElementAt(3*columnWidth - 1, index, columnWidth, 1, "hasMusic", hasMusicLabel)
      characterGrid:createElementAt(4*columnWidth - 1, index, columnWidth, 1, "subModCount", bundleIndicator)
      --characterGrid:createElementAt(5*columnWidth - 1, index, columnWidth, 1, "toggleVisibility", visibilitySelector)
      characterGrid:createElementAt(5*columnWidth - 1, index, columnWidth, 1, "toggleEnable", enableSelector)
    end
  end

  return characterGrid
end

function ModManagement:draw()
  themes[config.theme].images.bg_main:draw()
  self.uiRoot:draw()
end

function ModManagement:update(dt)
  themes[config.theme].images.bg_main:update(dt)
  if self.receiveMode == "Menu" then
    self.menu:receiveInputs(inputs, dt)
  else
    self.cursor:receiveInputs(inputs, dt)
  end
end

return ModManagement