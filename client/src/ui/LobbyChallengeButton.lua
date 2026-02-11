local import = require("common.lib.import")
local Button = import("./Button")
local Label = import("./Label")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local GameModes = require("common.data.GameModes")

---@class LobbyChallengeButtonOptions : ButtonOptions
---@field text string
---@field proposeImage love.Texture
---@field acceptImage love.Texture
---@field withdrawImage love.Texture
---@field iconSize integer
---@field gameModeId GameModeID
---@field playerId PublicPlayerID


---@class LobbyChallengeButton : Button
---@operator call(LobbyChallengeButtonOptions): LobbyChallengeButton
---@field proposeImage love.Texture
---@field acceptImage love.Texture
---@field withdrawImage love.Texture
---@field challengeState ChallengeState
---@field iconSize integer
---@field text string
---@field gameModeId GameModeID
---@field playerId PublicPlayerID
---@overload fun(options: LobbyChallengeButtonOptions): LobbyChallengeButton
local LobbyChallengeButton = class(
---@param self LobbyChallengeButton
---@param options LobbyChallengeButtonOptions
function(self, options)
  self.text = options.text
  self.challengeState = self.challengeStates.NEUTRAL
  self.proposeImage = options.proposeImage
  self.acceptImage = options.acceptImage
  self.withdrawImage = options.withdrawImage
  self.iconSize = options.iconSize
  self.playerId = options.playerId
  self.gameModeId = options.gameModeId
end,
Button, "LobbyChallengeButton")

LobbyChallengeButton.TYPE = "LobbyChallengeButton"

---@enum ChallengeState
LobbyChallengeButton.challengeStates  = { CHALLENGED = "CHALLENGED", PROPOSING = "PROPOSING", NEUTRAL = "NEUTRAL" }

---@param challengeState ChallengeState
function LobbyChallengeButton:setState(challengeState)
  self.challengeState = challengeState
end

function LobbyChallengeButton:onClick()
  if self.challengeState == LobbyChallengeButton.challengeStates.PROPOSING then
    --GAME.netClient:withdrawChallenge(self.playerId, self.gameModeId)
    GAME.theme:playValidationSfx()
  else
    if GAME.localPlayer.settings.style ~= GameModes.Styles.MODERN then
      GAME.localPlayer:setStyle(GameModes.Styles.MODERN)
      GAME.netClient:sendPlayerSettings(GAME.localPlayer)
    end
    GAME.netClient:challengePlayerById(self.playerId, self.gameModeId)
    GAME.theme:playValidationSfx()
  end
end

local padding = 4

function LobbyChallengeButton:drawSelf()
  self:drawBackground()
  self:drawOutline()

  local icon
  if self.challengeState == LobbyChallengeButton.challengeStates.NEUTRAL then
    icon = self.proposeImage
  elseif self.challengeState == LobbyChallengeButton.challengeStates.CHALLENGED then
    icon = self.acceptImage
  elseif self.challengeState == LobbyChallengeButton.challengeStates.PROPOSING then
    icon = self.withdrawImage
  end

  local imageWidth, imageHeight = icon:getDimensions()
  local scale = math.min(self.iconSize / imageWidth, self.iconSize / imageHeight)
  GraphicsUtil.draw(icon, self.x + padding, self.y + padding, 0, scale, scale)

  GraphicsUtil.printf(loc(self.text), self.x + padding * 2 + self.iconSize, self.y + padding, self.width - (padding * 2 + self.iconSize), "left")
end

return LobbyChallengeButton