local import = require("common.lib.import")
local class = require("common.lib.class")
local Button = import("./Button")
local consts = require("client.src.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local input = require("client.src.inputManager")
local Panel = require("common.engine.Panel")
local LevelPresets = require("common.data.LevelPresets")


---@class PanelButtonOptions : ButtonOptions
---@field panelSet PanelSet

---@class PanelButton : Button
---@field panelSet PanelSet
---@field dangerTimer integer
---@field panels Panel[]
local PanelButton = class(
function (self, options)
  self.panelSet = options.panelSet
  self.panels = {}

  local frameTimes = LevelPresets.getModern(5).frameConstants
  if GAME.localPlayer and GAME.localPlayer.settings.levelData then
    frameTimes = GAME.localPlayer.settings.levelData.frameConstants
  end

  for i = 1, 9 do
    local panel = Panel(1, 1, i, frameTimes)
    panel.color = i
    self.panels[i] = panel
  end

  self.minWidth = 9 * 16

  self.dangerTimer = 0
end,
Button)

---@param inputSource table
function PanelButton:action(inputSource)
  ---@type MatchParticipant
  local player
  if inputSource and inputSource.player then
    player = inputSource.player
  else
    player = GAME.localPlayer
  end
  player:setPanels(self.panelSet.id)
end

function PanelButton:getMinHeight()
  return math.ceil(self.width / 9) + 4 + GraphicsUtil.getTextHeightForWidth("normal", self.panelSet.name or self.panelSet.id, self.width, "center")
end

function PanelButton:drawSelf()
  self.panelSet:prepareDraw()
  love.graphics.push("transform")
  love.graphics.translate(self.x, self.y)
  local width = math.floor(self.width / 9)

  if self:isHovered() then
    self.dangerTimer = self.dangerTimer + 1
  else
    self.dangerTimer = 0
  end

  local x = 0
  local scale = width / 16

  for i = 1, 9 do
    -- 16 because panelSet draw multiplies the location by the scale argument as well and 16 is the base value
    x = (i - 1) * 16
    local panel = self.panels[i]
    self.panelSet:addToDraw(panel, x, 0, scale, { self:isHovered() }, self.dangerTimer, 0)
  end

  self.panelSet:drawBatch()

  GraphicsUtil.printf(self.panelSet.name or self.panelSet.id, 0, width + 4, self.width, "center", nil, nil, "normal")

  love.graphics.pop()
end



return PanelButton