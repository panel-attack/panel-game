local Scene = require("client.src.scenes.Scene")
local class = require("common.lib.class")
local ui = require("client.src.ui")
local inputs = require("client.src.inputManager")
local tableUtils = require("common.lib.tableUtils")
local consts = require("common.engine.consts")
local CharacterLoader = require("client.src.mods.CharacterLoader")
local SoundController = require("client.src.music.SoundController")
local system = require("client.src.system")

local ModManagement = class(function(self, options)
  self.keepMusic = true
  self.receiveMode = "Menu"
  self:load()
end,
Scene)

ModManagement.name = "ModManagement"

function ModManagement:load()
  self.stackPanel = ui.StackPanel(
    {
      alignment = "top",
      width = 600,
      hAlign = "center",
      vAlign = "top",
      x = 0,
      y = 49,
    }
  )

  self.headerLabel = ui.Label({
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

  self.cursor = ui.GridCursor({
    grid = self.characterGrid,
    player = GAME.localPlayer,
    frameImages = themes[config.theme]:getGridCursor(1),
    startPosition = {x = 9, y = 1},
  })

  self.cursor.onMove = function(c)
    local newOffset = c.target.unitSize * (c.selectedGridPos.y - 1)
    if self.scrollContainer then
      self.scrollContainer:keepVisible(-newOffset, c.target.unitSize)
    end
  end

  self.cursor.escapeCallback = function(cursor)
    self.stackPanel:remove(self.scrollContainer)
    self.scrollContainer = nil
    self.stackPanel:detach()
    cursor:setTarget()
    GAME.theme:playCancelSfx()
    self.receiveMode = "Menu"
  end

  self.manageCharactersButton = ui.MenuItem.createButtonMenuItem(
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

  self.manageStagesButton = ui.MenuItem.createButtonMenuItem(
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

  self.openSaveDirectoryButton = ui.MenuItem.createButtonMenuItem(
    "op_openSaveDir", nil, true, function(button, inputs)
      love.system.openURL(love.filesystem.getSaveDirectory())
    end
  )

  self.backButton = ui.MenuItem.createButtonMenuItem("back", nil, true,
    function(button, inputs)
      GAME.theme:playCancelSfx()
      GAME.navigationStack:pop()
    end
  )

  local menuItems = {
    self.manageCharactersButton,
    self.manageStagesButton,
    self.backButton
  }

  if system.supportsFileBrowserOpen() then
    table.insert(menuItems, 3, self.openSaveDirectoryButton)
  end

  self.menu = ui.Menu({
    menuItems = menuItems,
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
  return ui.ScrollContainer({
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
  local stageGrid = ui.Grid({
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
      local icon = ui.ImageContainer({drawBorders = true, image = stage.images.thumbnail, hFill = true, vFill = true, hAlign = "center", vAlign = "center"})
      local enableSelector = ui.BoolSelector({startValue = not not stages[stage.id], hAlign = "center", vAlign = "center", hFill = true, vFill = true})
      enableSelector.onValueChange = function(boolSelector, value)
        GAME.theme:playValidationSfx()
        stage:enable(boolSelector.value)
        if tableUtils.length(visibleStages) == 0 then
          SoundController:stopSfx(GAME.theme.sounds.menu_validate)
          GAME.theme:playCancelSfx()
          boolSelector:setValue(not boolSelector.value)
          stage:enable(boolSelector.value)
        end
        if not boolSelector.value and stage.id == config.stage and #visibleStages > 0 then
          GAME.localPlayer:setStage(stages[consts.RANDOM_STAGE_SPECIAL_VALUE])
        end
      end
      local visibilitySelector = ui.BoolSelector({startValue = stage.isVisible, hAlign = "center", vAlign = "center", hFill = true, vFill = true})
      visibilitySelector.onValueChange = function(boolSelector, value)
      end
      local name = ui.Label({text = stage.display_name, translate = false, hAlign = "center", vAlign = "center"})
      local hasMusicLabel = ui.Label({text = tostring(stage.hasMusic):upper(), translate = false, hAlign = "center", vAlign = "center"})
      local subCount = 0
      if #stage.subIds > 0 then
        for _, c in ipairs(stage.subIds) do
          if allStages[c] then
            subCount = subCount + 1
          end
        end
      end
      local bundleIndicator = ui.Label({text = tostring(subCount), translate = false, hAlign = "center", vAlign = "center"})
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
  local headLine = ui.Grid({
    unitSize = gridUnitSize,
    gridWidth = gridWidth,
    gridHeight = 1,
    unitMargin = gridMargin,
    hAlign = "center",
    vAlign = "top",
    y = headerY,
  })
  headLine:createElementAt(1, 1, 1, 1, "icon", ui.Label({text = "Icon", hAlign = "center", vAlign = "center"}))
  headLine:createElementAt(2, 1, 3, 1, "name", ui.Label({text = "Name", hAlign = "center", vAlign = "center"}))
  headLine:createElementAt(3*columnWidth - 1, 1, columnWidth, 1, "music", ui.Label({text = "Music", hAlign = "center", vAlign = "center"}))
  headLine:createElementAt(4*columnWidth - 1, 1, columnWidth, 1, "subMods", ui.Label({text = "Sub mods", hAlign = "center", vAlign = "center"}))
  --headLine:createElementAt(5*columnWidth - 1, 1, columnWidth, 1, "visible", ui.Label({text = "Visible", hAlign = "center", vAlign = "center"}))
  headLine:createElementAt(5*columnWidth - 1, 1, columnWidth, 1, "enabled", ui.Label({text = "Enabled", hAlign = "center", vAlign = "center"}))

  return headLine
end

function ModManagement:loadCharacterGrid()
  local characterGrid = ui.Grid({
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
      local icon = ui.ImageContainer({drawBorders = true, image = character.images.icon, hFill = true, vFill = true})
      local enableSelector = ui.BoolSelector({startValue = not not characters[character.id], hAlign = "center", vAlign = "center", hFill = true, vFill = true})
      enableSelector.onValueChange = function(boolSelector, value)
        GAME.theme:playValidationSfx()
        character:enable(boolSelector.value)
        if tableUtils.length(visibleCharacters) == 0 then
          SoundController:stopSfx(GAME.theme.sounds.menu_validate)
          GAME.theme:playCancelSfx()
          boolSelector:setValue(not boolSelector.value)
          character:enable(boolSelector.value)
        end
        if not boolSelector.value and character.id == config.character and #visibleCharacters > 0 then
          GAME.localPlayer:setCharacter(characters[consts.RANDOM_CHARACTER_SPECIAL_VALUE])
        end
      end
      local visibilitySelector = ui.BoolSelector({startValue = character.isVisible, hAlign = "center", vAlign = "center", hFill = true, vFill = true})
      visibilitySelector.onValueChange = function(boolSelector, value)
      end
      local displayName = ui.Label({text = character.display_name, translate = false, hAlign = "center", vAlign = "center"})
      local hasMusicLabel = ui.Label({text = tostring(character.hasMusic):upper(), translate = false, hAlign = "center", vAlign = "center"})
      local subCount = 0
      if #character.subIds > 0 then
        for _, c in ipairs(character.subIds) do
          if allCharacters[c] then
            subCount = subCount + 1
          end
        end
      end
      local bundleIndicator = ui.Label({text = tostring(subCount), translate = false, hAlign = "center", vAlign = "center"})
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