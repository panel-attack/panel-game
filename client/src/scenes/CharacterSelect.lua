local consts = require("common.engine.consts")
local input = require("client.src.inputManager")
local class = require("common.lib.class")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local GameModes = require("common.data.GameModes")
local Scene = require("client.src.scenes.Scene")
local ui = require("client.src.ui")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local Character = require("client.src.mods.Character")
local LevelPresets = require("common.data.LevelPresets")
local InputDeviceOverlay = require("client.src.scenes.components.InputDeviceOverlay")
local Layout = require("client.src.ui.Layout")

-- the sizing of an element that takes its parent's whole size
local FILLS = {horizontal = Layout.GROW, vertical = Layout.GROW}
-- the id the page turn buttons find the character grid by
local CHARACTER_GRID_ID = "characterGrid"

-- an image over its whole parent, fitted into it and centered
local CENTERED_IMAGE_RULES = {
  sizing = FILLS,
  childAlignment = Layout.CENTER,
  floating = Layout.floatAt("centerCenter")
}

-- Returns the rules of the row a slider is centered in, as wide as its parent
---@param height number
---@return LayoutRules
local function sliderWrapperRules(height)
  return {sizing = {horizontal = Layout.GROW, vertical = Layout.fixed(height)}, childAlignment = Layout.CENTER}
end

-- a row of a player's number icon and selector, centered on each other
local SELECTION_ROW_RULES = {childAlignment = Layout.CENTER_VERTICALLY}
local SPACER_RULES = {sizing = Layout.fixedSize(8, 8)}
-- a line of the records box: its label 10 from the left, its value 10 from the right and 4 below the line
local RECORD_LINE_RULES = {sizing = {horizontal = Layout.GROW}, padding = {left = 10, right = 10, bottom = 4}}
local RECORD_LINE_SPACE_RULES = {sizing = {horizontal = Layout.GROW}}

-- The character select screen scene
---@class CharacterSelect : Scene
---@field backgroundImg table
---@field players Player[]
---@field battleRoom BattleRoom
local CharacterSelect = class(
---@param self CharacterSelect
function(self, sceneParams)
  self.backgroundImg = themes[config.theme].images.bg_select_screen
  self.music = "select_screen"
  self.fallbackMusic = "main"
  self.battleRoom = sceneParams.battleRoom
  self.players = shallowcpy(self.battleRoom.players)
  self:load()
end, Scene)

-- begin abstract functions

-- Initalization specific to the child scene
function CharacterSelect:customLoad()
end

-- updates specific to the child scene
function CharacterSelect:customUpdate(sceneParams)
  -- error("The function customUpdate needs to be implemented on the scene")
end

function CharacterSelect:customDraw()

end

-- end abstract functions

function CharacterSelect:load()
  -- display order is driven by locality
  table.sort(self.players, function(a, b)
    if a.isLocal == b.isLocal then
      return a.playerNumber < b.playerNumber
    else
      return a.isLocal
    end
  end)

  self.ui = {}
  self.ui.cursors = {}
  self.ui.characterIcons = {}
  self.ui.playerInfos = {}
  -- the grid each scene adds is centered on the canvas
  self.uiRoot:setLayoutRule("childAlignment", Layout.CENTER)
  self:customLoad()
  
  self:createInputDeviceOverlay()

  self:setChangeInputButtonVisibility(false)
  self:setChangeInputButtonVisibleIfNeeded()

  for _, player in ipairs(self.players) do
    if player:isHuman() then
      if player.isLocal then
        self:initializeFromLocalPlayerSettings(player)
      end
      player:connectSignal("levelDataChanged", self, self.onLevelDataChanged)
      self:onLevelDataChanged(player.settings.levelData, player)
    end
  end
end

function CharacterSelect:onLevelDataChanged(levelData, player)
  local presetInfo = LevelPresets.getStyleAndPreset(levelData)

  if not presetInfo then
    -- Custom levelData, default to current settings
    return
  end

  if presetInfo.style == GameModes.Styles.MODERN then
    player:setStyle(GameModes.Styles.MODERN)
    if presetInfo.level then
      player:setLevel(presetInfo.level)
    end
  else
    player:setStyle(GameModes.Styles.CLASSIC)
    if presetInfo.difficulty then
      player:setDifficulty(presetInfo.difficulty)
    end
  end

  self:refresh()
end

function CharacterSelect:initializeFromLocalPlayerSettings(player)
  player:setStyle(GameModes.Styles.MODERN)
  player:setLevel(player.settings.level)
  player:setLevelData(LevelPresets.getModern(player.settings.level))
end

-- The player outlives the scene, so its callbacks must not capture the scene's UI (see Signal.connectSignal).
-- The load icon carries the ready icon and player instead of capturing them.
---@param loadIcon ImageContainer with readyIcon and player set
---@param loaded boolean
local function onLoadedChanged(loadIcon, loaded)
  loadIcon:setVisibility(not loaded)
  loadIcon.readyIcon:setVisibility(loaded and loadIcon.player.settings.wantsReady)
end

---@param player Player
---@return UiElement playerIcon
function CharacterSelect:createPlayerIcon(player)
  local playerIcon = ui.UiElement({layoutRules = {sizing = FILLS}})

  local selectedCharacterIcon = ui.ImageContainer({
    layoutRules = {sizing = FILLS},
    image = characters[player.settings.selectedCharacterId].images.icon,
    drawBorders = true,
    outlineColor = {1, 1, 1, 1}
  })

   -- character image
   selectedCharacterIcon.onCharacterChanged = function(selfElement, characterId)
    selfElement:setImage(characters[characterId].images.icon)
  end
  player:connectSignal("selectedCharacterIdChanged", selectedCharacterIcon, selectedCharacterIcon.onCharacterChanged)

  playerIcon:addChild(selectedCharacterIcon)

  -- level icon
  if player.settings.style == GameModes.Styles.MODERN and player.settings.level then
    local levelIcon = ui.ImageContainer({
      image = themes[config.theme].images.IMG_levels[player.settings.level],
      layoutRules = {floating = Layout.floatAt("rightBottom", -2, -2)}
    })

    levelIcon.onLevelChanged = function(selfElement, level)
      selfElement:setImage(themes[config.theme].images.IMG_levels[level])
    end
    player:connectSignal("levelChanged", levelIcon, levelIcon.onLevelChanged)

    playerIcon:addChild(levelIcon)
  end

  -- player number icon
  local playerIndex = tableUtils.indexOf(self.players, player)
  local playerNumberIcon = ui.ImageContainer({
    image = themes[config.theme].images.IMG_players[playerIndex],
    layoutRules = {floating = Layout.floatAt("leftBottom", 2, -2)},
    scale = 3
  })
  playerIcon:addChild(playerNumberIcon)

  -- player name
  local playerName = ui.Label({
    text = player.name,
    translate = false,
    layoutRules = {floating = Layout.floatAt("centerTop")}
  })
  playerIcon:addChild(playerName)

  -- load icon
  local loadIcon = ui.ImageContainer({
    image = themes[config.theme].images.IMG_loading,
    layoutRules = CENTERED_IMAGE_RULES,
    isVisible = not player.hasLoaded
  })
  playerIcon:addChild(loadIcon)

  -- ready icon
  local readyIcon = ui.ImageContainer({
    image = themes[config.theme].images.IMG_ready,
    layoutRules = CENTERED_IMAGE_RULES,
    isVisible = player.settings.wantsReady and player.hasLoaded
  })
  playerIcon:addChild(readyIcon)

  loadIcon.readyIcon = readyIcon
  loadIcon.player = player
  player:connectSignal("hasLoadedChanged", loadIcon, onLoadedChanged)
  readyIcon.onReadyChanged = function(selfElement, wantsReady)
    selfElement:setVisibility(wantsReady and player.hasLoaded)
  end
  player:connectSignal("wantsReadyChanged", readyIcon, readyIcon.onReadyChanged)

  return playerIcon
end

---@return TextButton readyButton
function CharacterSelect:createReadyButton()
  local readyButton = ui.TextButton({
    layoutRules = {sizing = FILLS},
    label = ui.Label({text = "ready"}),
    backgroundColor = {1, 1, 1, 0},
    outlineColor = {1, 1, 1, 1}
  })

  -- assign player generic callback
  readyButton.onClick = function(self, inputSource, holdTime)
    local player
    if inputSource and inputSource.player then
      player = inputSource.player
    else
      player = GAME.localPlayer
    end
    player:setWantsReady(not player.settings.wantsReady)
    GAME.theme:playValidationSfx()
  end
  readyButton.onSelect = readyButton.onClick

  return readyButton
end

---@return TextButton leaveButton
function CharacterSelect:createLeaveButton()
  local leaveButton = ui.TextButton({
    layoutRules = {sizing = FILLS},
    label = ui.Label({text = "leave"}),
    backgroundColor = {1, 1, 1, 0},
    outlineColor = {1, 1, 1, 1},
    onClick = function()
        GAME.theme:playCancelSfx()
        self:leave()
      end
  })
  leaveButton.onSelect = leaveButton.onClick

  return leaveButton
end

---@param player Player
---@param width number
---@return UiElement stageCarousel
function CharacterSelect:createStageCarousel(player, width)
  local stageCarousel = ui.StageCarousel({
    isEnabled = player.isLocal,
    layoutRules = {sizing = {horizontal = Layout.fixed(width), vertical = Layout.GROW}}
  })
  stageCarousel:loadCurrentStages()

  -- stage carousel
  stageCarousel.onSelectCallback = function()
    -- Just update on every passenger change
  end

  stageCarousel.onBackCallback = function()
    -- Just update on every passenger change
  end

  stageCarousel.onPassengerUpdateCallback = function(carousel, selectedPassenger)
    player:setStage(selectedPassenger.id)
  end

  stageCarousel:setPassengerById(player.settings.selectedStageId)

  -- to update the UI if code gets changed from the backend (e.g. network messages)
  player:connectSignal("selectedStageIdChanged", stageCarousel, stageCarousel.setPassengerById)

  -- player number icon
  local playerIndex = tableUtils.indexOf(self.players, player)
  local playerNumberIcon = ui.ImageContainer({
    image = themes[config.theme].images.IMG_players[playerIndex],
    scale = 2,
  })

  if #self.players > 1 then
    playerNumberIcon:setLayoutRule("floating", Layout.floatAt("centerTop", 0, 2))
  else
    -- 4 left of the centered stage thumbnail
    local thumbnailWidth = Layout.fixedLength(stageCarousel:getSelectedPassenger().image.layoutRules, "horizontal")
    playerNumberIcon:setLayoutRule("floating", {
      attachTo = "parent",
      attachPoints = {element = "rightCenter", parent = "centerCenter"},
      offset = {x = -thumbnailWidth / 2 - 4, y = 0}
    })
  end

  stageCarousel.playerNumberIcon = playerNumberIcon
  stageCarousel:addChild(stageCarousel.playerNumberIcon)

  return stageCarousel
end

function CharacterSelect:createInputDeviceOverlay()

  self.inputDeviceOverlay = InputDeviceOverlay({
    players = self.battleRoom.players,
    onClose = function()
      self:onInputDeviceOverlayClosed()
    end,
    onCancel = function()
      self:leave()
    end
  })
  self.uiRoot:addChild(self.inputDeviceOverlay)
end

function CharacterSelect:onInputDeviceOverlayClosed()
  self:setChangeInputButtonVisibleIfNeeded()
end

function CharacterSelect:setChangeInputButtonVisibleIfNeeded()
  if self.ui and self.ui.changeInputButton then
    if #self.battleRoom:getLocalHumanPlayers() > 0 then
      self.ui.changeInputButton:setVisibility(true)
    end
  end
end

function CharacterSelect:setChangeInputButtonVisibility(isVisible)
  if self.ui and self.ui.changeInputButton then
    self.ui.changeInputButton:setVisibility(isVisible)
  end
end

function CharacterSelect:createChangeInputButton()
  return ui.ChangeInputButton({
    layoutRules = {sizing = FILLS},
    players = self.battleRoom.players,
    openInputDeviceOverlay = function ()
      self.inputDeviceOverlay:openWithAssignmentsReleased()
    end
  })
end

local super_select_pixelcode = [[
      uniform float percent;
      vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
      {
          vec4 c = Texel(tex, texture_coords) * color;
          if( texture_coords.x < percent )
          {
            return c;
          }
          float ret = (c.x+c.y+c.z)/3.0;
          return vec4(ret, ret, ret, c.a);
      }
  ]]

---@return Button[] characterButtons
function CharacterSelect:getCharacterButtons()
  local characterButtons = {}
  local enableButtons = self.battleRoom:hasLocalPlayer()

  for i = 0, #visibleCharacters do
    local characterButton = ui.Button({
      layoutRules = {sizing = FILLS},
      isEnabled = enableButtons,
    })

    local character
    if i == 0 then
      character = Character.getRandom()
    else
      character = characters[visibleCharacters[i]]
    end

    characterButton.characterId = character.id
    characterButton.image = ui.ImageContainer({image = character.images.icon, layoutRules = {sizing = FILLS}})
    characterButton:addChild(characterButton.image)
    characterButton.label = ui.Label({
      text = character.display_name,
      translate = character.id == consts.RANDOM_CHARACTER_SPECIAL_VALUE,
      layoutRules = {floating = Layout.floatAt("centerTop")},
      wrap = true
    })
    characterButton:addChild(characterButton.label)

    if character.flag and themes[config.theme].images.flags[character.flag] then
      characterButton.flag = ui.ImageContainer({
        image = themes[config.theme].images.flags[character.flag],
        layoutRules = {sizing = Layout.fixedSize(16, 16), floating = Layout.floatAt("rightBottom", -2, -2)}
      })
      characterButton:addChild(characterButton.flag)
    end

    if character.stage and stages[character.stage] then
      -- draw the stage icon in the center
      characterButton.stageIcon = ui.ImageContainer({
        image = stages[character.stage].images.thumbnail,
        layoutRules = {sizing = Layout.fixedSize(32, 16), floating = Layout.floatAt("centerBottom", 0, -2)}
      })
      characterButton:addChild(characterButton.stageIcon)
    end

    if character.panels and panels[character.panels] then
      local panels = panels[character.panels]
      local dpiscale = panels.sheets[1]:getDPIScale()
      local filterMin, filterMag = panels.sheets[1]:getFilter()

      local panelImage = GraphicsUtil.renderToTexture(
        panels.size,
        panels.size,
        function()
          panels:drawPanelFrame(1, "normal", 0, 0, panels.size)
        end,
        dpiscale,
        filterMin,
        filterMag
      )

      characterButton.panelIcon = ui.ImageContainer({
        image = panelImage,
        layoutRules = {sizing = Layout.fixedSize(16, 16), floating = Layout.floatAt("leftBottom", 2, -2)}
      })
      characterButton:addChild(characterButton.panelIcon)
    end

    characterButtons[#characterButtons + 1] = characterButton
  end

  -- assign player generic callbacks
  for i = 1, #characterButtons do
    local characterButton = characterButtons[i]
    characterButton.onClick = function(selfElement, inputSource, holdTime)
      local character = characters[selfElement.characterId]
      local player
      if inputSource and inputSource.player then
        player = inputSource.player
      elseif tableUtils.trueForAny(self.players, function(p) return p == GAME.localPlayer end) then
         player = GAME.localPlayer
      else
        return
      end

      if character then
        if character:canSuperSelect() and holdTime > consts.SUPER_SELECTION_START + consts.SUPER_SELECTION_DURATION then
          -- super select
          if character.panels and panels[character.panels] then
            player:setPanels(character.panels)
          end
          if character.stage and stages[character.stage] then
            player:setStage(character.stage)
          end
        end
        character:playSelectionSfx()
      else
        GAME.theme:playValidationSfx()
      end

      player:setCharacter(selfElement.characterId)
      local cursor = tableUtils.first(self.ui.cursors, function(c) return c.player == player end)
      if cursor then
        cursor:updatePosition(9, 2, true)
      end
    end

    if characters[characterButton.characterId] and characters[characterButton.characterId]:canSuperSelect() then
      self.applySuperSelectInteraction(characterButton)
    else
      characterButton.onSelect = characterButton.onClick
    end
  end

  return characterButtons
end

local function updateSuperSelectShader(image, timer)
  if timer > consts.SUPER_SELECTION_START then
    if image.isVisible == false then
      image:setVisibility(true)
    end
    local progress = (timer - consts.SUPER_SELECTION_START) / consts.SUPER_SELECTION_DURATION
    if progress <= 1 then
      image.shader:send("percent", progress)
    end
  else
    if image.isVisible then
      image:setVisibility(false)
    end
    image.shader:send("percent", 0)
  end
end

---@param characterButton Button
function CharacterSelect.applySuperSelectInteraction(characterButton)
  -- creating the super select image + shader
  local superSelectImage = ui.ImageContainer({
    image = themes[config.theme].images.IMG_super,
    layoutRules = CENTERED_IMAGE_RULES
  })
  superSelectImage.shader = love.graphics.newShader(super_select_pixelcode)
  superSelectImage.drawSelf = function(self)
    local x, y = self:getImageRect()
    GraphicsUtil.setShader(self.shader)
    GraphicsUtil.draw(self.image, x, y, 0, self.scale, self.scale)
    GraphicsUtil.setShader()
  end

  -- add it to the button
  characterButton.superSelectImage = superSelectImage
  characterButton:addChild(characterButton.superSelectImage)
  superSelectImage:setVisibility(false)

  -- set the generic update function
  characterButton.updateSuperSelectShader = updateSuperSelectShader

  -- touch interaction
  -- by implementing onHold we can provide updates to the shader
  characterButton.onHold = function(self, timer)
    self.updateSuperSelectShader(self.superSelectImage, timer)
  end

  -- we need to override the standard onRelease to reset the shader
  ---@diagnostic disable-next-line: duplicate-set-field
  characterButton.onRelease = function(self, x, y, timeHeld)
    self.updateSuperSelectShader(self.superSelectImage, 0)
    if self:inBounds(x, y) then
      self:onClick(input.mouse, timeHeld)
    end
  end

  -- keyboard / controller interaction
  -- by applying focusable we can turn it into an "on release" interaction rather than on press by taking control of input interpretation
  characterButton:setFocusable(true)
  characterButton.holdTime = 0
  ---@diagnostic disable-next-line: duplicate-set-field
  characterButton.receiveInputsSelf = function(self, inputSource, dt)
    local inputs = inputSource:getInputs()
    if inputs.isPressed["Swap1"] then
      -- measure the time the press is held for
      self.holdTime = self.holdTime + dt
    else
      self:yieldFocus(inputSource)
      -- apply the actual click on release with the held time and reset it afterwards
      self:onClick(inputs, self.holdTime)
      self.holdTime = 0
    end
    self.updateSuperSelectShader(self.superSelectImage, self.holdTime)
  end
end

-- Returns the height a player's element gets in the selection's grid cell under its title, the players sharing the cell
---@param selection {title: Label} a MultiPlayerSelectionWrapper with its title set, in a cell of the scene's grid
---@param playerCount integer? how many players' elements share the cell, 1 if not given
---@return number
function CharacterSelect:getHeightUnderTitle(selection, playerCount)
  local grid = self.ui.grid
  local _, titleHeight = selection.title:getEffectiveDimensions()
  return (grid.unitSize - grid.unitMargin * 2) / (playerCount or 1) - titleHeight
end

function CharacterSelect:createCharacterGrid(characterButtons, grid, width, height)
  local characterGrid = ui.PagedUniGrid({
    unitSize = grid.unitSize,
    gridWidth = width,
    gridHeight = height,
    unitMargin = grid.unitMargin,
    layoutRules = {id = CHARACTER_GRID_ID}
  })

  for i = 1, #characterButtons do
    characterGrid:addElement(characterButtons[i])
  end

  return characterGrid
end

function CharacterSelect:createPageIndicator(pagedUniGrid)
  local pageCounterLabel = ui.Label({
    text = loc("page") .. " " .. pagedUniGrid.currentPage .. "/" .. #pagedUniGrid.pages,
    translate = false
  })
  pageCounterLabel.onPageChanged = function(selfElement, grid, page)
    selfElement:setText(loc("page") .. " " .. page .. "/" .. #grid.pages)
  end
  pagedUniGrid:connectSignal("pageTurned", pageCounterLabel, pageCounterLabel.onPageChanged)
  return pageCounterLabel
end

-- Puts the grid's page turn buttons on the scene's root, half a unit outside the grid's sides and centered on them
function CharacterSelect:createPageTurnButtons(pagedUniGrid)
  local gap = pagedUniGrid.unitSize / 2
  pagedUniGrid.pageTurnButtons.left:setLayoutRule("floating", {
    attachTo = "element",
    parentId = CHARACTER_GRID_ID,
    attachPoints = {element = "rightCenter", parent = "leftCenter"},
    offset = {x = -gap, y = 0}
  })
  pagedUniGrid.pageTurnButtons.right:setLayoutRule("floating", {
    attachTo = "element",
    parentId = CHARACTER_GRID_ID,
    attachPoints = {element = "leftCenter", parent = "rightCenter"},
    offset = {x = gap, y = 0}
  })

  self.uiRoot:addChild(pagedUniGrid.pageTurnButtons.left)
  self.uiRoot:addChild(pagedUniGrid.pageTurnButtons.right)
  return pagedUniGrid.pageTurnButtons
end

function CharacterSelect:createCursor(grid, player)
  local cursor = ui.GridCursor({
    grid = grid,
    activeArea = {x1 = 1, y1 = 2, x2 = 9, y2 = 5},
    translateSubGrids = true,
    startPosition = {x = 9, y = 2},
    player = player,
    -- this needs to be index, not playerNumber, as playerNumber is a server prop
    frameImages = themes[config.theme]:getGridCursor(tableUtils.indexOf(self.players, player)),
  })

  player:connectSignal("wantsReadyChanged", cursor, cursor.setRapidBlinking)

  cursor.escapeCallback = function()
    GAME.theme:playCancelSfx()
    if cursor.selectedGridPos.x == 9 and cursor.selectedGridPos.y == 6 then
      self:leave()
    elseif player.settings.wantsReady then
      player:setWantsReady(false)
    else
      cursor:updatePosition(9, 6, false)
    end
  end

  player:connectSignal("wantsReadyChanged", cursor, cursor.trap)

  grid:addChild(cursor)
  self.uiRoot:focusChild(cursor, player.inputSource)

  return cursor
end

function CharacterSelect:createPanelCarousel(player, height)
  local panelCarousel = ui.PanelCarousel({
    isEnabled = player.isLocal,
    layoutRules = {sizing = {horizontal = Layout.GROW, vertical = Layout.fixed(height)}}
  })
  panelCarousel:setColorCount(player.settings.levelData.colors)
  panelCarousel:loadPanels()

  -- panel carousel
  panelCarousel.onSelectCallback = function()
    -- Just update on every passenger change
  end

  panelCarousel.onBackCallback = function()
    -- Just update on every passenger change
  end

  panelCarousel.onPassengerUpdateCallback = function(carousel, selectedPassenger)
    player:setPanels(selectedPassenger.id)
  end

  panelCarousel:setPassengerById(player.settings.panelId)

  local updateColor = function(carousel, levelData)
    carousel:setColorCount(levelData.colors)
  end

  local updatePanelSelection = function(carousel, panelId)
    carousel:setPassengerById(panelId)
  end

  -- to update the UI if code gets changed from the backend (e.g. network messages)
  player:connectSignal("levelDataChanged", panelCarousel, updateColor)
  player:connectSignal("panelIdChanged", panelCarousel, updatePanelSelection)

  -- player number icon
  local playerIndex = tableUtils.indexOf(self.players, player)
  local playerNumberIcon = ui.ImageContainer({
    image = themes[config.theme].images.IMG_players[playerIndex],
    layoutRules = {floating = Layout.floatAt("leftCenter", 2)},
    scale = 2
  })

  panelCarousel.playerNumberIcon = playerNumberIcon
  panelCarousel:addChild(panelCarousel.playerNumberIcon)

  return panelCarousel
end

---@param player Player
---@param imageWidth number
---@param height number
---@return UiElement levelSliderContainer
function CharacterSelect:createLevelSlider(player, imageWidth, height)
  local levelSlider = ui.LevelSlider({
    isEnabled = player.isLocal,
    tickLength = imageWidth,
    value = player.settings.level,
    onValueChange = function(s)
      GAME.theme:playMoveSfx()
    end,
  })

  levelSlider:setFocusable(true)
  ---@diagnostic disable-next-line: duplicate-set-field
  levelSlider.receiveInputsSelf = function(self, inputSource, dt)
    local inputs = inputSource:getInputs()
    if inputs:isPressedWithRepeat("Left") then
      self:setValue(self.value - 1)
    end

    if inputs:isPressedWithRepeat("Right") then
      self:setValue(self.value + 1)
    end

    if inputs.isDown["Swap2"] then
      if self.onBackCallback then
        self:onBackCallback()
      end
      GAME.theme:playCancelSfx()
      self:yieldFocus(inputSource)
    end

    if inputs.isDown["Swap1"] or inputs.isDown["Start"] then
      if self.onSelectCallback then
        self:onSelectCallback()
      end
      GAME.theme:playValidationSfx()
      self:yieldFocus(inputSource)
    end
  end

  -- level slider
  levelSlider.onSelectCallback = function(self)
    player:setLevel(self.value)
    player:setLevelData(LevelPresets.getModern(self.value))
  end

  ---@diagnostic disable-next-line: duplicate-set-field
  levelSlider.setValueFromPos = function(self, x)
    local screenX, screenY = self:getScreenPos()
    self:setValue(math.floor((x - screenX) / self.tickLength) + self.min)
    player:setLevel(self.value)
    player:setLevelData(LevelPresets.getModern(self.value))
  end

  levelSlider.onBackCallback = function(self)
    self:setValue(player.settings.level)
  end

  -- wrap in an extra element so we can offset properly as levelslider is fixed height + width
  local uiElement = ui.UiElement({layoutRules = sliderWrapperRules(height)})
  uiElement.levelSlider = levelSlider
  uiElement:addChild(levelSlider)
  uiElement.onFocus = function(self, inputSource)
    self:forwardFocus(self.levelSlider, inputSource)
  end

  -- to update the UI if code gets changed from the backend (e.g. network messages)
  player:connectSignal("levelChanged", levelSlider, levelSlider.setValue)

  -- player number icon
  local playerIndex = tableUtils.indexOf(self.players, player)
  local playerNumberIcon = ui.ImageContainer({
    image = themes[config.theme].images.IMG_players[playerIndex],
    layoutRules = {floating = Layout.floatAt("leftCenter", 2)},
    scale = 2
  })

  uiElement.playerNumberIcon = playerNumberIcon
  uiElement:addChild(uiElement.playerNumberIcon)

  return uiElement
end

---@param player Player
---@param width number
---@return StackPanel rankedSelectionContainer
function CharacterSelect:createRankedSelection(player, width)

  -- player number icon
  local playerIndex = tableUtils.indexOf(self.players, player)
  local playerNumberIcon = ui.ImageContainer({
    image = themes[config.theme].images.IMG_players[playerIndex],
    scale = 2
  })

  local rankedSelector = ui.BoolSelector({startValue = player.settings.wantsRanked, isEnabled = player.isLocal})
  rankedSelector.onValueChange = function(boolSelector, value)
    GAME.theme:playValidationSfx()
    player:setWantsRanked(value)
  end

  rankedSelector:setFocusable(true)

  player:connectSignal("wantsRankedChanged", rankedSelector, rankedSelector.setValue)

  local container = ui.StackPanel({alignment = "left", layoutRules = SELECTION_ROW_RULES})
  container.playerNumberIcon = playerNumberIcon
  container.rankedSelector = rankedSelector
  container:addElement(playerNumberIcon)
  container:addElement(ui.UiElement({layoutRules = SPACER_RULES}))
  container:addElement(rankedSelector)
  container:addElement(ui.UiElement({layoutRules = SPACER_RULES}))

  return container
end

---@param styleSelector BoolSelector
---@param style Styles
local function onStyleChanged(styleSelector, style)
  styleSelector:setValue(style == GameModes.Styles.MODERN)
end

---@param player Player
---@param width number
---@return StackPanel styleSelectionContainer
---@return BoolSelector styleSelector
function CharacterSelect:createStyleSelection(player, width)
  -- player number icon
  local playerIndex = tableUtils.indexOf(self.players, player)
  local playerNumberIcon = ui.ImageContainer({
    image = themes[config.theme].images.IMG_players[playerIndex],
    scale = 2
  })

  local styleSelector = ui.BoolSelector({
    startValue = (player.settings.style == GameModes.Styles.MODERN),
    isEnabled = player.isLocal
  })

  -- onValueChange should get implemented by the caller
  -- as likely the UI needs to be altered to accomodate the style choice

  styleSelector:setFocusable(true)

  player:connectSignal("styleChanged", styleSelector, onStyleChanged)

  local container = ui.StackPanel({alignment = "left", layoutRules = SELECTION_ROW_RULES})
  container.playerNumberIcon = playerNumberIcon
  container.styleSelector = styleSelector
  container:addElement(playerNumberIcon)
  container:addElement(ui.UiElement({layoutRules = SPACER_RULES}))
  container:addElement(styleSelector)
  container:addElement(ui.UiElement({layoutRules = SPACER_RULES}))

  return container, styleSelector
end

function CharacterSelect:createRecordsBox(lastText)
  local stackPanel = ui.StackPanel({
    alignment = "top",
    layoutRules = {sizing = {horizontal = Layout.GROW}}
  })

  local lastLines = ui.UiElement({layoutRules = RECORD_LINE_RULES})
  local lastLinesLabel = ui.PixelFontLabel({ text = lastText, xScale = 0.5, yScale = 1})
  local lastLinesValue = ui.PixelFontLabel({ text = self.lastScore, xScale = 0.5, yScale = 1})
  lastLines.label = lastLinesLabel
  lastLines.value = lastLinesValue
  lastLines:addChild(lastLinesLabel)
  lastLines:addChild(ui.UiElement({layoutRules = RECORD_LINE_SPACE_RULES}))
  lastLines:addChild(lastLinesValue)
  stackPanel.lastLines = lastLines
  stackPanel:addElement(lastLines)

  local record = ui.UiElement({layoutRules = RECORD_LINE_RULES})
  local recordLabel = ui.PixelFontLabel({ text = "record", xScale = 0.5, yScale = 1})
  local recordValue = ui.PixelFontLabel({ text = self.record, xScale = 0.5, yScale = 1})
  record.label = recordLabel
  record.value = recordValue
  record:addChild(recordLabel)
  record:addChild(ui.UiElement({layoutRules = RECORD_LINE_SPACE_RULES}))
  record:addChild(recordValue)
  stackPanel.record = record
  stackPanel:addElement(record)

  stackPanel.setLastResult = function(stackPanel, value)
    stackPanel.lastLines.value:setText(value)
  end

  stackPanel.setRecord = function(stackPanel, value)
    stackPanel.record.value:setText(value)
  end

  return stackPanel
end

function CharacterSelect:createPlayerInfo(player)
  local stackPanel = ui.StackPanel({alignment = "top", layoutRules = {sizing = {horizontal = Layout.GROW}, padding = {left = 4}}})

  stackPanel.leagueLabel = ui.Label({
    text = loc("ss_rating") .. " " .. ((player.league) or "none"),
    translate = false
  })
  stackPanel.leagueLabel.updateLabel = function(self, league)
    self:setText(loc("ss_rating") .. " " .. (league or "none"))
  end

  stackPanel.ratingLabel = ui.Label({
    text = player.rating or "",
    translate = false
  })
  stackPanel.ratingLabel.updateLabel = function(self, rating, ratingDiff)
    if ratingDiff > 0 then
      self:setText(tostring(rating) .. " (+" .. ratingDiff .. ")", nil, false)
    elseif ratingDiff < 0 then
      self:setText(tostring(rating) .. " (" .. ratingDiff .. ")", nil, false)
    else
      self:setText(tostring(rating), nil, false)
    end
  end

  stackPanel.winsLabel = ui.Label({
    text = loc("ss_wins") .. " " .. player:getWinCountForDisplay(),
    translate = false
  })
  stackPanel.winsLabel.updateLabel = function(self, winCount)
    self:setText(loc("ss_wins") .. " " .. winCount, nil, false)
  end

  stackPanel.winrateLabel = ui.Label({
    text = "ss_winrate"
  })

  stackPanel.winrateValueLabel = ui.Label({
    text = "  " .. loc("ss_current_rating") .. " " .. tostring(player.winrate) .. "%",
    translate = false
  })
  stackPanel.winrateValueLabel.updateLabel = function(self, winrate)
    self:setText("  " .. loc("ss_current_rating") .. tostring(winrate) .. "%", nil, false)
  end

  stackPanel.winrateExpectedLabel = ui.Label({
    text = ""
  })
  if self.battleRoom.ranked then
    stackPanel.winrateExpectedLabel:setText(loc("ss_expected_rating") .. " " .. player.expectedWinrate .. "%")
  end
  stackPanel.winrateExpectedLabel.updateLabel = function(self, expectedWinrate)
    self:setText("  " .. loc("ss_expected_rating") .. tostring(expectedWinrate) .. "%", nil, false)
  end

  player:connectSignal("leagueChanged", stackPanel.leagueLabel, stackPanel.leagueLabel.updateLabel)
  player:connectSignal("ratingChanged", stackPanel.ratingLabel, stackPanel.ratingLabel.updateLabel)
  player:connectSignal("winsChanged", stackPanel.winsLabel, stackPanel.winsLabel.updateLabel)
  player:connectSignal("winrateChanged", stackPanel.winrateValueLabel, stackPanel.winrateValueLabel.updateLabel)
  player:connectSignal("expectedWinrateChanged", stackPanel.winrateExpectedLabel, stackPanel.winrateExpectedLabel.updateLabel)

  stackPanel:addElement(stackPanel.leagueLabel)
  stackPanel:addElement(stackPanel.ratingLabel)
  stackPanel:addElement(stackPanel.winsLabel)
  stackPanel:addElement(stackPanel.winrateLabel)
  stackPanel:addElement(stackPanel.winrateValueLabel)

  return stackPanel
end

function CharacterSelect:createRankedStatusPanel()
  local rankedStatus = ui.StackPanel({
    alignment = "top",
    layoutRules = {
      sizing = {horizontal = Layout.fixed(300)},
      childAlignment = Layout.CENTER_HORIZONTALLY,
      floating = Layout.floatAt("centerTop", 0, 40)
    }
  })
  rankedStatus.rankedLabel = ui.Label({
    text = ""
  })
  if self.battleRoom.ranked then
    rankedStatus.rankedLabel:setText("ss_ranked")
  else
    rankedStatus.rankedLabel:setText("ss_casual")
  end
  rankedStatus.commentLabel = ui.Label({
    text = self.battleRoom.rankedComments or "",
    translate = false
  })
  rankedStatus:addElement(rankedStatus.rankedLabel)
  rankedStatus:addElement(rankedStatus.commentLabel)

  rankedStatus.updateFromRankedStatusChanged = function(selfElement, ranked, comments)
    if ranked then
      selfElement.rankedLabel:setText("ss_ranked")
    else
      selfElement.rankedLabel:setText("ss_casual")
    end
    selfElement.commentLabel:setText(comments, nil, false)
  end

  self.battleRoom:connectSignal("rankedStatusChanged", rankedStatus, rankedStatus.updateFromRankedStatusChanged)

  return rankedStatus
end

---@param player Player
---@param height number
---@param min integer?
---@return UiElement speedSliderContainer
function CharacterSelect:createSpeedSlider(player, height, min)
  local speedSlider = ui.Slider({
    min = min or 1,
    max = 99,
    value = player.settings.speed,
    onValueChange = function(slider)
      player:setSpeed(slider.value)
      GAME.theme:playMoveSfx()
    end,
  })
  speedSlider:setFocusable(true)

  player:connectSignal("startingSpeedChanged", speedSlider, speedSlider.setValue)

  -- wrap in an extra element so we can offset properly as speedSlider is fixed height + width
  local uiElement = ui.UiElement({layoutRules = sliderWrapperRules(height)})
  uiElement.speedSlider = speedSlider
  uiElement:addChild(speedSlider)
  uiElement.onFocus = function(self, inputSource)
    self:forwardFocus(self.speedSlider, inputSource, function()
      GAME.theme:playValidationSfx()
    end)
  end

  return uiElement
end

function CharacterSelect:createDifficultyCarousel(player, height, getPresetFunc)
  local passengers = {
    { id = 1, uiElement = ui.Label({text = "easy", layoutRules = {floating = Layout.floatAt("centerCenter")}})},
    { id = 2, uiElement = ui.Label({text = "normal", layoutRules = {floating = Layout.floatAt("centerCenter")}})},
    { id = 3, uiElement = ui.Label({text = "hard", layoutRules = {floating = Layout.floatAt("centerCenter")}})},
    { id = 4, uiElement = ui.Label({text = "ss_ex_mode", layoutRules = {floating = Layout.floatAt("centerCenter")}})},
  }
  local difficultyCarousel = ui.Carousel({
    isEnabled = player.isLocal,
    layoutRules = {sizing = {horizontal = Layout.GROW, vertical = Layout.fixed(height)}},
    passengers = passengers,
    selectedId = player.settings.difficulty
  })

  difficultyCarousel.onSelectCallback = function()
    -- Just update on every passenger change
  end

  difficultyCarousel.onBackCallback = function()
    -- Just update on every passenger change
  end

  difficultyCarousel.onPassengerUpdateCallback = function(carousel, selectedPassenger)
    player:setDifficulty(selectedPassenger.id)
    if getPresetFunc then
      player:setLevelData(getPresetFunc(selectedPassenger.id))
    end
    GAME.theme:playMoveSfx()
  end

  -- to update the UI if code gets changed from the backend (e.g. network messages)
  player:connectSignal("difficultyChanged", difficultyCarousel, difficultyCarousel.setPassengerById)

  return difficultyCarousel
end

function CharacterSelect:updateSelf(dt)
  self.inputDeviceOverlay:openInputDeviceOverlayIfNeeded()
  -- a cursor only reads its player's own device, so a device no player has asks for the devices again
  self.inputDeviceOverlay:openIfUnassignedDeviceUsed()

  if self.inputDeviceOverlay:isActive() then
    return
  end

  for _, cursor in ipairs(self.ui.cursors) do
    local player = cursor.player
    -- an earlier cursor this frame can release every local device (change input device), so skip players left without one
    if player.isLocal and player.human and player.inputConfiguration and player.settings.inputMethod == "controller" then
      self.uiRoot:receiveInputs(player.inputSource, dt)
    end
  end
  if self.battleRoom and self.battleRoom.spectating then
    if input.isDown["MenuEsc"] then
      GAME.theme:playCancelSfx()
      self:leave()
    end
  end
  if self:customUpdate() then
    return
  end
end

function CharacterSelect:drawSelf()
  self.backgroundImg:draw()
  self:customDraw()
end

function CharacterSelect:leave()
  GAME.navigationStack:pop(nil,
    function()
      if self.battleRoom then
        self.battleRoom:shutdown()
      end
    end)
end

return CharacterSelect
