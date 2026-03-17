local NetworkProtocol = require("common.network.NetworkProtocol")
local msgTypes = NetworkProtocol.clientMessageTypes
local consts = require("common.engine.consts")

local ClientProtocol = {}

-------------------------
-- login related requests
-------------------------

function ClientProtocol.requestLogin(userId, name, level, inputMethod, panels, bundleCharacter, character, bundleStage, stage, wantsRanked, saveReplaysPublicly)
  local loginRequestMessage =
  {
    login_request = true,
    user_id = userId,
    engine_version = consts.ENGINE_VERSION,
    name = name,
    level = level,
    inputMethod = inputMethod or "controller",
    panels_dir = panels,
    character_is_random = bundleCharacter,
    character = character,
    stage_is_random = bundleStage,
    stage = stage,
    ranked = wantsRanked,
    save_replays_publicly = saveReplaysPublicly
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = loginRequestMessage,
    responseTypes = {"login_successful", "login_denied"}
  }
end

function ClientProtocol.logout()
  local logoutMessage = {logout = true}

  return {
    messageType = msgTypes.jsonMessage,
    messageText = logoutMessage,
  }
end

function ClientProtocol.requestVersionCompatibilityCheck()
  return {
    messageType = msgTypes.versionCheck,
    messageText = nil,
    responseTypes = {"versionCompatible"}
  }
end

-------------------------
-- Lobby related requests
-------------------------

---@param senderId PublicPlayerID
---@param receiverId PublicPlayerID
---@param gameModeId GameModeID
function ClientProtocol.updateChallengeStatus(senderId, receiverId, gameModeId, challengeActive)
  local playerChallengeV2Message =
  {
    challengeUpdate =
    {
      senderId = senderId,
      receiverId = receiverId,
      gameModeId = gameModeId,
      challengeActive = challengeActive,
    }
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = playerChallengeV2Message,
  }
end

function ClientProtocol.requestSpectate(spectatorName, roomNumber)
  local spectateRequestMessage =
  {
    spectate_request =
    {
      sender = spectatorName,
      roomNumber = roomNumber
    }
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = spectateRequestMessage,
    responseTypes = {"spectate_request_granted"}
  }
end

---@param gameModeId GameModeID
function ClientProtocol.requestLeaderboard(gameModeId)
  local leaderboardRequestMessage = {
    leaderboard_request = true,
    leaderboardType = gameModeId,
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = leaderboardRequestMessage,
    responseTypes = {"leaderboard_report"}
  }
end

------------------------------
-- BattleRoom related requests
------------------------------
function ClientProtocol.leaveRoom()
  local leaveRoomMessage = {leave_room = true}
  return {
    messageType = msgTypes.jsonMessage,
    messageText = leaveRoomMessage,
  }
end

function ClientProtocol.reportLocalGameResult(outcome)
  local gameResultMessage = {game_over = true, outcome = outcome}
  return {
    messageType = msgTypes.jsonMessage,
    messageText = gameResultMessage,
  }
end

function ClientProtocol.sendPlayerSettings(menuState)
  local menuStateMessage = {menu_state = menuState}
  return {
    messageType = msgTypes.jsonMessage,
    messageText = menuStateMessage,
  }
end

function ClientProtocol.sendTaunt(direction, index)
  local type = "taunt_" .. string.lower(direction) .. "s"
  local tauntMessage = {taunt = true, type = type, index = index}
  return {
    messageType = msgTypes.jsonMessage,
    messageText = tauntMessage,
  }
end

---@param gameMode GameMode
function ClientProtocol.sendRoomRequest(gameMode)
  local gameModeData = gameMode:getGameModeJSONData()
  local roomRequestMessage = {
    recipient = "server",
    type = "roomRequest",
    content = { gameMode = gameModeData }
  }
  return {
    messageType = msgTypes.jsonMessage,
    messageText = roomRequestMessage
  }
end

function ClientProtocol.sendMatchAbort(roomNumber)
  local matchAbortMessage = {
    recipient = "room",
    recipientId = roomNumber,
    type = "matchAbort",
    content = true
  }
  return {
    messageType = msgTypes.jsonMessage,
    messageText = matchAbortMessage
  }
end

---@param pause boolean if the client is paused
function ClientProtocol.sendPauseToggle(roomNumber, pause)
  local pauseToggleMessage = {
    recipient = "room",
    recipientId = roomNumber,
    type = "pauseToggle",
    content = pause,
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = pauseToggleMessage
  }
end

-------------------------
-- miscellaneous requests
-------------------------

function ClientProtocol.sendErrorReport(errorData)
  local errorReportMessage = {error_report = errorData}
  return {
    messageType = msgTypes.jsonMessage,
    messageText = errorReportMessage,
  }
end

return ClientProtocol
