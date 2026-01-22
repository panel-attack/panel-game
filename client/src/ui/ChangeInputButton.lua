local PATH = (...):gsub('%.[^%.]+$', '')
local Button = require(PATH .. ".Button")
local Label = require(PATH .. ".Label")
local class = require("common.lib.class")
local InputPromptRenderer = require("client.src.graphics.InputPromptRenderer")
local StackPanel = require(PATH .. ".StackPanel")
local UiElement = require(PATH .. ".UIElement")

---@class ChangeInputButtonOptions : ButtonOptions
---@field players Player[]
---@field openInputDeviceOverlay fun()

-- Button that displays current player input assignments and allows changing them
---@class ChangeInputButton : Button
---@field players Player[] The players we query assignments for
---@field openInputDeviceOverlay fun() Callback invoked when button is clicked to change inputs
---@field titleLabel Label Title text label
---@field iconContainer StackPanel Container for player assignment icons
---@field signalConnections table[] Array of signal subscriptions for live updates
local ChangeInputButton = class(
  function(self, options)
    options = options or {}

    self.players = options.players
    self.localHumanPlayers = {}
    for _, player in ipairs(self.players) do
      if player.isLocal and player.human then
        self.localHumanPlayers[#self.localHumanPlayers+1] = player
      end
    end

    self.openInputDeviceOverlay = options.openInputDeviceOverlay

    self.signalConnections = {}

    local width = 80

    self.titleLabel = Label({
      -- fontSize = 8,
      wrapWidth = width,
      text = "change_input_device",
    })
    self.titleLabel.hAlign = "center"

    self.iconContainer = StackPanel({
      alignment = "top",
      hAlign = "center",
      vAlign = "center",
      width = width
    })

    self:addChild(self.iconContainer)

    -- Subscribe to player signals and update initial state
    self:subscribeToPlayerSignals()
    self:updateSummary()
  end,
  Button
)

function ChangeInputButton:onClick()
  if #self.localHumanPlayers == 0 then
    GAME.theme:playCancelSfx()
    return
  else
    local released = false
    for i, player in ipairs(self.localHumanPlayers) do
      if player.inputConfiguration then
        player:clearInputDeviceAssignment()
        released = true
      end
    end

    if released then
      GAME.theme:playCancelSfx()
      self.openInputDeviceOverlay()
    else
      GAME.theme:playMoveSfx()
    end
  end
end

function ChangeInputButton:onSelect()
  self:onClick()
end

function ChangeInputButton:onResize()
  -- Icon container has fixed width now
end

function ChangeInputButton:updateSummary()
  -- Clear existing player rows
  while #self.iconContainer.children > 0 do
    self.iconContainer:remove(self.iconContainer.children[1])
  end

  if not self.localHumanPlayers then
    self.isEnabled = true
    return
  end

  if #self.localHumanPlayers == 0 then
    self.isEnabled = true
    return
  end

  self.iconContainer:addElement(self.titleLabel)

  local spacer = UiElement({
    width = 1,
    height = 4
  })
  self.iconContainer:addElement(spacer)
      
  -- Create a row for each player
  for i, player in ipairs(self.localHumanPlayers) do
    self:addPlayerRow(player, i)

    -- Add spacing between player rows (except after last)
    if i < #self.localHumanPlayers then
      spacer = UiElement({
        width = 1,
        height = 4
      })
      self.iconContainer:addElement(spacer)
    end
  end

  self.isEnabled = true
end

local iconSize = 20

---@param player Player
---@param playerIndex number
function ChangeInputButton:addPlayerRow(player, playerIndex)
  -- Create horizontal StackPanel for this player's row
  local playerRow = StackPanel({
    alignment = "left",
    height = iconSize,
    hAlign = "center"
  })

  self:addPlayerIcons(playerRow, player, playerIndex)
  self.iconContainer:addElement(playerRow)
end

---@param playerRow StackPanel
---@param player Player
---@param playerIndex number
function ChangeInputButton:addPlayerIcons(playerRow, player, playerIndex)

  -- Add player number icon (P1, P2, etc.)
  local playerIcon = UiElement({
    x = 0,
    y = 2,
    width = iconSize,
    height = iconSize
  })
  playerIcon.drawSelf = function(elementSelf)
    if GAME.theme then
      local playerNumberIcon = GAME.theme:getPlayerNumberIcon(playerIndex)
      if playerNumberIcon then
        local scale = iconSize / math.max(playerNumberIcon:getWidth(), playerNumberIcon:getHeight())
        love.graphics.draw(playerNumberIcon, elementSelf.x, elementSelf.y, 0, scale, scale)
      end
    end
  end
  playerRow:addElement(playerIcon)

  -- Add device type icon and index
  if player.inputConfiguration then
    -- Small spacing between player icon and device icon
    local smallSpacer = UiElement({
      width = 4,
      height = iconSize
    })
    playerRow:addElement(smallSpacer)

    -- Device icon
    local deviceIcon = UiElement({
      width = iconSize,
      height = iconSize
    })
    deviceIcon.drawSelf = function(elementSelf)
      InputPromptRenderer.renderIconWithNumber(
        player.inputConfiguration.deviceType,
        elementSelf.x + iconSize/2,
        elementSelf.y + iconSize/2,
        iconSize,
        1,
        player.inputConfiguration.controllerImageVariant,
        player.inputConfiguration.deviceNumber
      )
    end
    playerRow:addElement(deviceIcon)
  end
end

function ChangeInputButton:subscribeToPlayerSignals()
  if not self.localHumanPlayers then
    return
  end

  for _, player in ipairs(self.localHumanPlayers) do
    local connection = player:connectSignal("inputConfigurationChanged", self, self.updateSummary)
    self.signalConnections[#self.signalConnections + 1] = {player = player, connection = connection}
  end
end

return ChangeInputButton