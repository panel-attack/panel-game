local import = require("common.lib.import")
local LobbyChallengeButton = import("./LobbyChallengeButton")
local class = require("common.lib.class")

---@class LobbyRoomInviteButtonOptions : IconTextButtonOptions
---@field proposeImage love.Texture
---@field acceptImage love.Texture
---@field withdrawImage love.Texture
---@field playerId PublicPlayerID
---@field roomNumber integer
---@field slotNumber integer
---@field gameModeId GameModeID

---@class LobbyRoomInviteButton : LobbyChallengeButton
---@operator call(LobbyRoomInviteButtonOptions): LobbyRoomInviteButton
---@field roomNumber integer
---@field slotNumber integer
---@field inviteKey string
---@overload fun(options: LobbyRoomInviteButtonOptions): LobbyRoomInviteButton
local LobbyRoomInviteButton = class(
---@param self LobbyRoomInviteButton
---@param options LobbyRoomInviteButtonOptions
function(self, options)
  self.roomNumber = options.roomNumber
  self.slotNumber = options.slotNumber
  -- The key used to track this specific slot invite in the challenges tables
  self.inviteKey = "room_" .. options.roomNumber .. "_" .. options.slotNumber
end,
LobbyChallengeButton, "LobbyRoomInviteButton")

LobbyRoomInviteButton.TYPE = "LobbyRoomInviteButton"

function LobbyRoomInviteButton:onClick()
  -- Reuse shared room-invite handling so slot-open guards and conflict checks apply consistently.
  LobbyChallengeButton.onClick(self)
end

return LobbyRoomInviteButton
