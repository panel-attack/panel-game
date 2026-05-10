local import = require("common.lib.import")
local IconTextButton = import("./IconTextButton")
local class = require("common.lib.class")
local GameModes = require("common.data.GameModes")

---@class LobbyChallengeButtonOptions : IconTextButtonOptions
---@field proposeImage love.Texture
---@field acceptImage love.Texture
---@field withdrawImage love.Texture
---@field gameModeId GameModeID
---@field playerId PublicPlayerID
---@field roomNumber integer?
---@field slotNumber integer?
---@field challengeState ChallengeState?
---@field icon nil

---@class LobbyChallengeButton : IconTextButton
---@operator call(LobbyChallengeButtonOptions): LobbyChallengeButton
---@field proposeImage love.Texture
---@field acceptImage love.Texture
---@field withdrawImage love.Texture
---@field challengeState ChallengeState
---@field gameModeId GameModeID
---@field playerId PublicPlayerID
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
  self:setState(options.challengeState or self.challengeStates.NEUTRAL)
end,
IconTextButton, "LobbyChallengeButton")

LobbyChallengeButton.TYPE = "LobbyChallengeButton"

---@enum ChallengeState
LobbyChallengeButton.challengeStates  = { CHALLENGED = "CHALLENGED", PROPOSING = "PROPOSING", NEUTRAL = "NEUTRAL" }

---@param challengeMap table<string, boolean>?
---@param roomNumber integer
---@param slotNumber integer?
---@return boolean
local function hasOtherActiveRoomInvite(challengeMap, roomNumber, slotNumber)
  if not challengeMap then
    return false
  end

  for key, active in pairs(challengeMap) do
    if active and type(key) == "string" then
      local roomStr, slotStr = key:match("^room_(%d+)_(%d+)$")
      if roomStr and slotStr and tonumber(roomStr) == tonumber(roomNumber) then
        local invitedSlot = tonumber(slotStr)
        if invitedSlot and invitedSlot ~= tonumber(slotNumber) then
          return true
        end
      end
    end
  end

  return false
end

---@param lobbyData PersonalizedLobbyDataV2
---@param roomNumber integer
---@param slotNumber integer?
---@param targetPlayerId PublicPlayerID
---@return boolean
local function hasSameSlotInviteForOtherPlayer(lobbyData, roomNumber, slotNumber, targetPlayerId)
  if not lobbyData or not roomNumber or not slotNumber then
    return false
  end

  local inviteKey = "room_" .. roomNumber .. "_" .. slotNumber

  for otherPlayerId, challenges in pairs(lobbyData.outgoingChallenges or {}) do
    if otherPlayerId ~= targetPlayerId and challenges and challenges[inviteKey] == true then
      return true
    end
  end

  for otherPlayerId, challenges in pairs(lobbyData.incomingChallenges or {}) do
    if otherPlayerId ~= targetPlayerId and challenges and challenges[inviteKey] == true then
      return true
    end
  end

  return false
end

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
      local outgoing = GAME.netClient.lobbyDataV2.outgoingChallenges[self.playerId]
      local incoming = GAME.netClient.lobbyDataV2.incomingChallenges[self.playerId]
      if hasOtherActiveRoomInvite(outgoing, self.roomNumber, self.slotNumber)
        or hasOtherActiveRoomInvite(incoming, self.roomNumber, self.slotNumber)
        or hasSameSlotInviteForOtherPlayer(GAME.netClient.lobbyDataV2, self.roomNumber, self.slotNumber, self.playerId) then
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