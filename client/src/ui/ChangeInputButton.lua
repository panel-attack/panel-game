local PATH = (...):gsub('%.[^%.]+$', '')
local Button = require(PATH .. ".Button")
local Label = require(PATH .. ".Label")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local InputDeviceUtils = require("client.src.input.InputDeviceUtils")

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

    self.summaryLabel = Label({
      text = self:getInputDeviceSummary(),
      fontSize = math.max(GraphicsUtil.fontSize - 4)
    })
    self.summaryLabel.y = 36
    self.summaryLabel.hAlign = "center"

    self:addChild(self.titleLabel)
    self:addChild(self.summaryLabel)

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
  self.summaryLabel.wrapWidth = math.max(self.width - 16, 0)
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
  local summary = self:getInputDeviceSummary()
  self.summaryLabel:setText(summary ~= "" and summary or "No local players", nil, false)
  self.isEnabled = true
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