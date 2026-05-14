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
---@param challengeActive boolean
---@param roomNumber integer? optional room number for team room invites
---@param slotNumber integer? optional slot number (player index) for team room invites
function ClientProtocol.updateChallengeStatus(senderId, receiverId, gameModeId, challengeActive, roomNumber, slotNumber)
  local playerChallengeV2Message =
  {
    challengeUpdate =
    {
      senderId = senderId,
      receiverId = receiverId,
      gameModeId = gameModeId,
      challengeActive = challengeActive,
      roomNumber = roomNumber,
      slotNumber = slotNumber,
    }
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = playerChallengeV2Message,
  }
end

--- Request to join an existing room at a specific slot
---@param roomNumber integer
---@param slotNumber integer the player index to join as
function ClientProtocol.requestJoinRoom(roomNumber, slotNumber)
  local joinRoomMessage = {
    joinRoomRequest = {
      roomNumber = roomNumber,
      slotNumber = slotNumber,
    }
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = joinRoomMessage,
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
---@param latencyTolerance ("strict"|"normal"|"relaxed")? optional room abort-latency tolerance
---@param openRoom boolean? true if the room should accept direct joiners (no invite handshake).
---  Independent of min/max roster — an Open Team 2v2 has min==max==4 (team structure is fixed)
---  but should still accept drop-in joiners. The lobby uses this flag to choose join vs invite buttons.
function ClientProtocol.sendRoomRequest(gameMode, latencyTolerance, openRoom)
  local gameModeData = gameMode:getGameModeJSONData()
  local roomRequestMessage = {
    recipient = "server",
    type = "roomRequest",
    content = {
      gameMode = gameModeData,
      latencyTolerance = latencyTolerance,
      openRoom = openRoom and true or false,
    }
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

---Loose-sync: send a GarbageEvent — sender's local sim has resolved garbage
---for one or more remote targets. Body is wrapped as a marked G-prefix message,
---not a JSON envelope.
---@param body table parsed payload (will be JSON-encoded on send)
function ClientProtocol.sendGarbageEvent(body)
  return {
    messageType = msgTypes.garbageEvent,
    messageText = body,
  }
end

---Loose-sync: send a DeathEvent — sender's local sim has reached game over.
---@param body table parsed payload (will be JSON-encoded on send)
function ClientProtocol.sendDeathEvent(body)
  return {
    messageType = msgTypes.deathEvent,
    messageText = body,
  }
end

---Crash-replay nomination. Sent on next quiescent moment (post-login
---or lobby return) per docs/CRASH_REPLAY_PLAN.md. Carries the gameKey
---+ trace metadata only — the actual JSONL trace file ships separately
---via the (forthcoming) traceFile message in response to the server's
---requestTrace.
---@param gameKey {roomNumber: integer, gameId: integer, startTs: integer}
---@param reason string e.g. "client_crash", "user_reported"
---@param traceHash string? short fingerprint used by the server to dedup
---@param traceFragment string? short error excerpt for forensic context
---@param clientMeta table? engineVersion / os / loveVersion / branch
function ClientProtocol.flagGame(gameKey, reason, traceHash, traceFragment, clientMeta)
  return {
    messageType = msgTypes.jsonMessage,
    messageText = {
      flagGame = {
        gameKey       = gameKey,
        reason        = reason,
        traceHash     = traceHash,
        traceFragment = traceFragment,
        clientMeta    = clientMeta,
        schemaVer     = 1,
      },
    },
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
