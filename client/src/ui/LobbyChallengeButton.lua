local import = require("common.lib.import")
local IconTextButton = import("./IconTextButton")
local class = require("common.lib.class")
local GameModes = require("common.data.GameModes")
local GraphicsUtil = require("client.src.graphics.graphics_util")

---@class LobbyChallengeButtonOptions : IconTextButtonOptions
---@field proposeImage love.Texture
---@field acceptImage love.Texture
---@field withdrawImage love.Texture
---@field gameModeId GameModeID
---@field playerId PublicPlayerID
---@field roomNumber integer?
---@field slotNumber integer?
---@field challengeState ChallengeState?
---@field teamTint number[]? RGBA tint for the button background; matches the team being joined
---@field icon nil

---@class LobbyChallengeButton : IconTextButton
---@operator call(LobbyChallengeButtonOptions): LobbyChallengeButton
---@field proposeImage love.Texture
---@field acceptImage love.Texture
---@field withdrawImage love.Texture
---@field challengeState ChallengeState
---@field gameModeId GameModeID
---@field playerId PublicPlayerID
---@field teamTint number[]?
---@overload fun(options: LobbyChallengeButtonOptions): LobbyChallengeButton
local LobbyChallengeButton = class(
---@param self LobbyChallengeButton
---@param options LobbyChallengeButtonOptions
function(self, options)
  self.proposeImage = options.proposeImage
  self.acceptImage = options.acceptImage
  self.withdrawImage = options.withdrawImage
  self.playerId = options.playerId
  self.gameModeId = options.gameModeId
  self.roomNumber = options.roomNumber
  self.slotNumber = options.slotNumber
  self.teamTint = options.teamTint
  self:setState(options.challengeState or self.challengeStates.NEUTRAL)
end,
IconTextButton, "LobbyChallengeButton")

-- When the button represents joining/inviting to a specific team, paint the
-- background in that team's color so the choice is visually obvious. Selected
-- state still uses the theme's selected-highlight color so keyboard focus
-- remains visible against the team tint.
function LobbyChallengeButton:drawBackground()
  if self.teamTint and not (self.selected or self.currentlyPressed) then
    local t = self.teamTint
    GraphicsUtil.drawRectangle("fill", self.x, self.y, self.width, self.height,
      t[1], t[2], t[3], t[4] or 0.85,
      self.CORNER_RADIUS, self.CORNER_RADIUS)
    GraphicsUtil.setColor(1, 1, 1, 1)
  else
    IconTextButton.drawBackground(self)
  end
end

LobbyChallengeButton.TYPE = "LobbyChallengeButton"

---@param lobbyData PersonalizedLobbyDataV2?
---@param roomNumber integer?
---@param slotNumber integer?
---@return boolean
local function isSlotOpenInLobbyData(lobbyData, roomNumber, slotNumber)
  if not lobbyData or not roomNumber or not slotNumber then
    return false
  end

  local room = lobbyData.rooms and lobbyData.rooms[roomNumber]
  if not room or not room.openSlots then
    return false
  end

  for _, openSlot in ipairs(room.openSlots) do
    if tonumber(openSlot) == tonumber(slotNumber) then
      return true
    end
  end

  return false
end

---@enum ChallengeState
LobbyChallengeButton.challengeStates  = { CHALLENGED = "CHALLENGED", PROPOSING = "PROPOSING", NEUTRAL = "NEUTRAL" }


---@param challengeState ChallengeState
function LobbyChallengeButton:setState(challengeState)
  self.challengeState = challengeState
  if self.challengeState == LobbyChallengeButton.challengeStates.NEUTRAL then
    self.icon = self.proposeImage
  elseif self.challengeState == LobbyChallengeButton.challengeStates.CHALLENGED then
    self.icon = self.acceptImage
  elseif self.challengeState == LobbyChallengeButton.challengeStates.PROPOSING then
    self.icon = self.withdrawImage
  end
end

function LobbyChallengeButton:onClick()
  if self.challengeState == LobbyChallengeButton.challengeStates.PROPOSING then
    if self.roomNumber then
      GAME.netClient:withdrawRoomInvite(self.playerId, self.roomNumber, self.slotNumber, self.gameModeId)
    else
      GAME.netClient:withdrawChallengeForId(self.playerId, self.gameModeId)
    end
    GAME.theme:playValidationSfx()
  else
    if GAME.localPlayer.settings.style ~= GameModes.Styles.MODERN then
      GAME.localPlayer:setStyle(GameModes.Styles.MODERN)
      GAME.netClient:sendPlayerSettings(GAME.localPlayer)
    end
    if self.roomNumber then
      if not isSlotOpenInLobbyData(GAME.netClient.lobbyDataV2, self.roomNumber, self.slotNumber) then
        GAME.theme:playCancelSfx()
        return
      end
      GAME.netClient:invitePlayerToRoom(self.playerId, self.roomNumber, self.slotNumber, self.gameModeId)
    else
      GAME.netClient:challengePlayerById(self.playerId, self.gameModeId)
    end
    GAME.theme:playValidationSfx()
  end
end

function LobbyChallengeButton:receiveInputs(input)
  if input.isDown["MenuSelect"] then
    self:onClick()
  end
end

return LobbyChallengeButton