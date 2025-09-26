local PATH = (...):gsub('%.[^%.]+$', '')
local Button = require(PATH .. ".Button")
local Label = require(PATH .. ".Label")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local InputDeviceUtils = require("client.src.input.InputDeviceUtils")
local InputPromptRenderer = require("client.src.graphics.InputPromptRenderer")
local StackPanel = require(PATH .. ".StackPanel")
local UiElement = require(PATH .. ".UIElement")

---@class ChangeInputButtonOptions : ButtonOptions
---@field battleRoom BattleRoom?
---@field onChangeInputRequested fun()?

---@class ChangeInputButton : Button
---@field battleRoom BattleRoom?
---@field onChangeInputRequested fun()
---@field titleLabel Label
---@field summaryLabel Label
---@field signalConnections table
local ChangeInputButton = class(
  function(self, options)
    options = options or {}

    -- Set default button styling
    options.backgroundColor = options.backgroundColor or {0.15, 0.15, 0.15, 0.85}
    options.outlineColor = options.outlineColor or {1, 1, 1, 1}
    options.hFill = options.hFill ~= false
    options.vFill = options.vFill ~= false

    self.battleRoom = options.battleRoom
    self.onChangeInputRequested = options.onChangeInputRequested or function() end
    self.signalConnections = {}

    self.titleLabel = Label({
      text = "Change\nInput Device",
    })
    self.titleLabel.y = 6
    self.titleLabel.hFill = true
    self.titleLabel.hAlign = "center"

    self.iconContainer = StackPanel({
      alignment = "top",
      y = 36,
      x = 8,
      width = 120
    })

    self:addChild(self.titleLabel)
    self:addChild(self.iconContainer)

    self.onClick = function(selfElement, inputSource, holdTime)
      selfElement.onChangeInputRequested()
    end
    self.onSelect = self.onClick

    -- Subscribe to player signals and update initial state
    self:subscribeToPlayerSignals()
    self:updateSummary()
  end,
  Button
)


function ChangeInputButton:onResize()
  -- Icon container has fixed width now
end

function ChangeInputButton:getInputDeviceSummary()
  if not self.battleRoom then
    return ""
  end

  local players = self.battleRoom:getLocalHumanPlayers()
  if #players == 0 then
    return "No local players"
  end

  return InputDeviceUtils.formatAssignmentSummary(players)
end

function ChangeInputButton:updateSummary()
  -- Clear existing player rows
  while #self.iconContainer.children > 0 do
    self.iconContainer:remove(self.iconContainer.children[1])
  end

  if not self.battleRoom then
    self.isEnabled = true
    return
  end

  local players = self.battleRoom:getLocalHumanPlayers()
  if #players == 0 then
    self.isEnabled = true
    return
  end

  -- Create a row for each player
  for i, player in ipairs(players) do
    self:addPlayerRow(player, i)

    -- Add spacing between player rows (except after last)
    if i < #players then
      local spacer = UiElement({
        width = 1,
        height = 4,
        hFill = false,
        vFill = false
      })
      self.iconContainer:addElement(spacer)
    end
  end

  self.isEnabled = true
end

function ChangeInputButton:addPlayerRow(player, playerIndex)
  local iconSize = 20

  -- Create horizontal StackPanel for this player's row
  local playerRow = StackPanel({
    alignment = "left"
  })

  self:addPlayerIcons(playerRow, player, playerIndex)
  self.iconContainer:addElement(playerRow)
end

function ChangeInputButton:addPlayerIcons(playerRow, player, playerIndex)
  local iconSize = 20

  -- Add player number icon (P1, P2, etc.)
  local playerIcon = UiElement({
    x = 0,
    y = 0,
    width = iconSize,
    height = iconSize
  })
  playerIcon.drawSelf = function(elementSelf)
    if GAME.theme then
      local playerNumberIcon = GAME.theme:getPlayerNumberIcon(player.playerNumber or playerIndex)
      if playerNumberIcon then
        local scale = iconSize / math.max(playerNumberIcon:getWidth(), playerNumberIcon:getHeight())
        love.graphics.draw(playerNumberIcon, elementSelf.x, elementSelf.y, 0, scale, scale)
      end
    end
  end
  playerRow:addElement(playerIcon)

  -- Add device type icon and index
  local deviceInfo = self:getPlayerDeviceInfo(player)
  if deviceInfo then
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
      InputPromptRenderer.renderIcon(deviceInfo.deviceType, elementSelf.x, elementSelf.y, iconSize, 1)
    end
    playerRow:addElement(deviceIcon)

    -- Index number if there are multiple configs of the same type
    if deviceInfo.showIndex then
      local indexLabel = Label({
        text = tostring(deviceInfo.index),
        fontSize = math.max(GraphicsUtil.fontSize - 6, 8),
        width = 12,
        height = iconSize,
        hAlign = "center",
        vAlign = "center",
        hFill = false,
        vFill = false
      })
      playerRow:addElement(indexLabel)
    end
  end
end

function ChangeInputButton:getPlayerDeviceInfo(player)
  if not player.inputConfiguration then
    return nil
  end

  -- Handle touch input
  if player.inputConfiguration == GAME.input.mouse then
    return {deviceType = "touch", showIndex = false}
  end

  -- Handle controller/keyboard configs
  local devices = InputDeviceUtils.getAssignableDevices()
  local deviceTypeCounts = {}
  local playerDeviceInfo = nil

  -- Count devices by type and find player's device
  for _, device in ipairs(devices) do
    if device.type ~= "touch" then
      deviceTypeCounts[device.type] = (deviceTypeCounts[device.type] or 0) + 1
      if device.config == player.inputConfiguration then
        playerDeviceInfo = {
          deviceType = device.type,
          index = device.index,
          showIndex = false -- will be set below
        }
      end
    end
  end

  -- Show index if there are multiple configs of the same type
  if playerDeviceInfo and deviceTypeCounts[playerDeviceInfo.deviceType] > 1 then
    playerDeviceInfo.showIndex = true
  end

  return playerDeviceInfo
end

function ChangeInputButton:setBattleRoom(battleRoom)
  self:unsubscribeFromPlayerSignals()
  self.battleRoom = battleRoom
  self:subscribeToPlayerSignals()
  self:updateSummary()
end

function ChangeInputButton:subscribeToPlayerSignals()
  if not self.battleRoom then
    return
  end

  local players = self.battleRoom:getLocalHumanPlayers()
  for _, player in ipairs(players) do
    local connection = player:connectSignal("inputConfigurationChanged", self, self.onInputConfigurationChanged)
    self.signalConnections[#self.signalConnections + 1] = {player = player, connection = connection}
  end
end

function ChangeInputButton:unsubscribeFromPlayerSignals()
  for _, connectionInfo in ipairs(self.signalConnections) do
    connectionInfo.player:disconnectSignal("inputConfigurationChanged", connectionInfo.connection)
  end
  self.signalConnections = {}
end

function ChangeInputButton:onInputConfigurationChanged()
  self:updateSummary()
end


return ChangeInputButton