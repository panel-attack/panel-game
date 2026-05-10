local import = require("common.lib.import")
local LobbyChallengeButton = import("./LobbyChallengeButton")
local class = require("common.lib.class")

---@class LobbyRoomJoinButtonOptions : IconTextButtonOptions
---@field proposeImage love.Texture
---@field acceptImage love.Texture
---@field withdrawImage love.Texture
---@field roomNumber integer
---@field slotNumber integer
---@field gameModeId GameModeID?

---@class LobbyRoomJoinButton : LobbyChallengeButton
---@operator call(LobbyRoomJoinButtonOptions): LobbyRoomJoinButton
---@field roomNumber integer
---@field slotNumber integer
---@overload fun(options: LobbyRoomJoinButtonOptions): LobbyRoomJoinButton
local LobbyRoomJoinButton = class(
---@param self LobbyRoomJoinButton
---@param options LobbyRoomJoinButtonOptions
function(self, options)
  self.roomNumber = options.roomNumber
  self.slotNumber = options.slotNumber
end,
LobbyChallengeButton, "LobbyRoomJoinButton")

LobbyRoomJoinButton.TYPE = "LobbyRoomJoinButton"

function LobbyRoomJoinButton:onClick()
  GAME.netClient:requestJoinRoom(self.roomNumber, self.slotNumber)
  GAME.theme:playValidationSfx()
end

return LobbyRoomJoinButton
