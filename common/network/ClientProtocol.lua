local NetworkProtocol = require("common.network.NetworkProtocol")
local msgTypes = NetworkProtocol.clientMessageTypes
local consts = require("common.engine.consts")

local ClientMessages = {}

-------------------------
-- login related requests
-------------------------

function ClientMessages.requestLogin(userId, name, level, inputMethod, panels, bundleCharacter, character, bundleStage, stage, wantsRanked, saveReplaysPublicly)
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

function ClientMessages.logout()
  local logoutMessage = {logout = true}

  return {
    messageType = msgTypes.jsonMessage,
    messageText = logoutMessage,
  }
end

function ClientMessages.requestVersionCompatibilityCheck()
  return {
    messageType = msgTypes.versionCheck,
    messageText = nil,
    responseTypes = {"versionCompatible"}
  }
end

-------------------------
-- Lobby related requests
-------------------------

-- players are challenged by their current name on the server
function ClientMessages.challengePlayer(senderName, receiverName)
  local playerChallengeMessage =
  {
    game_request =
    {
      sender = senderName,
      receiver = receiverName
    }
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = playerChallengeMessage,
  }
end

function ClientMessages.requestSpectate(spectatorName, roomNumber)
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

function ClientMessages.requestLeaderboard()
  local leaderboardRequestMessage = {leaderboard_request = true}

  return {
    messageType = msgTypes.jsonMessage,
    messageText = leaderboardRequestMessage,
    responseTypes = {"leaderboard_report"}
  }
end

------------------------------
-- BattleRoom related requests
------------------------------
function ClientMessages.leaveRoom()
  local leaveRoomMessage = {leave_room = true}
  return {
    messageType = msgTypes.jsonMessage,
    messageText = leaveRoomMessage,
  }
end

function ClientMessages.reportLocalGameResult(outcome)
  local gameResultMessage = {game_over = true, outcome = outcome}
  return {
    messageType = msgTypes.jsonMessage,
    messageText = gameResultMessage,
  }
end

function ClientMessages.sendMenuState(menuState)
  local menuStateMessage = {menu_state = menuState}
  return {
    messageType = msgTypes.jsonMessage,
    messageText = menuStateMessage,
  }
end

function ClientMessages.sendTaunt(direction, index)
  local type = "taunt_" .. string.lower(direction) .. "s"
  local tauntMessage = {taunt = true, type = type, index = index}
  return {
    messageType = msgTypes.jsonMessage,
    messageText = tauntMessage,
  }
end

-------------------------
-- miscellaneous requests
-------------------------

function ClientMessages.sendErrorReport(errorData)
  local errorReportMessage = {error_report = errorData}
  return {
    messageType = msgTypes.jsonMessage,
    messageText = errorReportMessage,
  }
end

return ClientMessages
