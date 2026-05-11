local NetworkProtocol = require("common.network.NetworkProtocol")
local msgTypes = NetworkProtocol.serverMessageTypes

local ServerProtocol = {}

-------------------------------------------------------------------
-- Helper methods for converting to ServerProtocol table formats --
-------------------------------------------------------------------

---@alias InputMethod ("controller" | "touch")

---@class ServerOutgoingPlayerSettings
---@field cursor string?
---@field stage string?
---@field selectedStage string?
---@field ready boolean?
---@field character string?
---@field selectedCharacter string?
---@field panels string?
---@field level integer?
---@field ranked boolean?
---@field inputMethod InputMethod?
---@field wants_ready boolean?
---@field loaded boolean?
---@field publicId integer?
---@field levelData LevelData?
---@field wants_ranked_match boolean?

function ServerProtocol.toSettings(ready, level, inputMethod, stage, selectedStage, character, selectedCharacter, panels, wantsRanked, wantsReady, loaded, levelData)
  local settings = {
    cursor = "__Ready",
    stage = stage,
    selectedStage = selectedStage,
    ready = ready,
    character = character,
    selectedCharacter = selectedCharacter,
    panels = panels,
    level = level,
    wantsRanked = wantsRanked,
    inputMethod = inputMethod,
    wantsReady = wantsReady,
    loaded = loaded,
    levelData = levelData,
  }
  return settings
end

----------------------------
-- Actual server messages --
----------------------------

-- the way the server currently works all messages sent by the server get immediately serialized to strings
-- and obviously nothing runs in parallel and we have no coroutines(!!)
-- messages templates are slated to be reused for sending all messages in order to avoid allocating extra tables for every message
-- but the moment any non-linear execution is introduced that could lead to a message being generated from the template without the previous one being serialized
--  which would lead to the yet-to-be-serialized previous message to be changed!
-- in that case that would need to get changed

---@class ServerMessage
---@field sender ("player" | "room" | "server")
---@field senderId (string | integer | nil)
---@field type string
---@field content (table | string)

local settingsUpdateTemplate = {
  sender = "player",
  senderId = nil,
  type = "settingsUpdate",
  content = {
    playerNumber = nil,
    level = nil,
    levelData = nil,
    inputMethod = nil,
    wantsReady = nil,
    loaded = nil,
    ready = nil,
    stage = nil,
    selectedStage = nil,
    character = nil,
    selectedCharacter = nil,
    panels = nil,
    wantsRanked = nil,
    cursor = "__Ready",
  }
}

---@param player ServerPlayer
---@return {messageType: table, messageText: ServerMessage}
function ServerProtocol.settingsUpdate(player, settings)
  local settingsUpdateMessage = settingsUpdateTemplate
  settingsUpdateMessage.senderId = player.publicPlayerID

  local content = settingsUpdateMessage.content
  -- need this for compatibility for now while the client still thinks in player numbers
  content.playerNumber = player.player_number
  content.level = settings.level
  content.levelData = settings.levelData
  content.inputMethod = settings.inputMethod
  content.wantsReady = settings.wantsReady
  content.loaded = settings.loaded
  content.ready = settings.ready
  content.stage = settings.stage
  content.selectedStage = settings.selectedStage
  content.character = settings.character
  content.selectedCharacter = settings.selectedCharacter
  content.panels = settings.panels
  content.wantsRanked = settings.wantsRanked

  return {
    messageType = msgTypes.jsonMessage,
    messageText = settingsUpdateMessage,
  }
end

local leaveRoomTemplate =
{
  sender = "room",
  senderId = nil,
  type = "leaveRoom",
  content = { reason = "" }
}

---@param roomId integer
---@param reason string?
---@return {messageType: table, messageText: ServerMessage}
function ServerProtocol.leaveRoom(roomId, reason)
  local leaveRoomMessage = leaveRoomTemplate
  leaveRoomMessage.senderId = roomId
  leaveRoomMessage.content.reason = reason or ""

  return {
    messageType = msgTypes.jsonMessage,
    messageText = leaveRoomMessage,
  }
end

local leaderboardReportTemplate = {
  sender = "server",
  type = "leaderboardReport",
  content = nil
}

---@return {messageType: table, messageText: ServerMessage}
function ServerProtocol.sendLeaderboard(leaderboard)
  local leaderboardReport = leaderboardReportTemplate
  leaderboardReport.content = leaderboard

  return {
    messageType = msgTypes.jsonMessage,
    messageText = leaderboardReport,
  }
end

local addToRoomTemplate = {
  sender = "server",
  type = "addToRoom",
  content = {
    roomNumber = 0,
    ranked = nil,
    replay = nil,
    stage = nil,
    players = nil
  },
}

---@param room Room
---@param replay ReplayV3?
function ServerProtocol.addToRoom(room, replay)
  local addToRoomMessage = addToRoomTemplate
  local content = addToRoomMessage.content
  content.roomNumber = room.roomNumber
  content.gameMode = room.gameMode
  content.ranked = (replay and replay.metadata.ranked or room.ranked)
  content.replay = replay
  content.stage = (replay and replay.metadata.stageId or nil)
  content.players = {}

  for i, player in ipairs(room.players) do
    -- publicId can't be the key as it would disallow developers playing against themselves for testing
    content.players[player.player_number] = {
      settings = player:getSettings(),
      rating = room.ratings[i],
      winCount = room.win_counts[i],
      name = player.name,
      publicId = player.publicPlayerID,
      playerNumber = player.player_number
    }
  end

  -- Always clear before conditionally re-setting because addToRoomTemplate is shared
  -- across calls (every call does `addToRoomMessage = addToRoomTemplate`); a leftover
  -- teamWins from a previous team-room call would otherwise leak into a non-team room.
  content.teamWins = nil
  if room.team_win_counts then
    content.teamWins = {}
    for teamIndex, wins in ipairs(room.team_win_counts) do
      content.teamWins[teamIndex] = wins
    end
  end

  return {
    messageType = msgTypes.jsonMessage,
    messageText = addToRoomMessage,
  }
end

local spectateRequestGrantedTemplate = {
  sender = "server",
  type = "spectateRequestGranted",
  content = {
    roomNumber = 0,
    ranked = nil,
    replay = nil,
    stage = nil,
    players = nil
  },
}

-- effectively spectate grant is just a super set of create room and both can be summarized into addToRoom
-- we need to keep them separate for the client to tell apart for now though
---@param room Room
---@param replay ReplayV3?
---@return {messageType: table, messageText: ServerMessage}
function ServerProtocol.spectateRequestGranted(room, replay)
  local spectateRequestGrantedMessage = spectateRequestGrantedTemplate
  local content = spectateRequestGrantedMessage.content
  content.roomNumber = room.roomNumber
  content.gameMode = room.gameMode
  content.ranked = (replay and replay.metadata.ranked or room.ranked)
  content.replay = replay
  content.stage = (replay and replay.metadata.stageId or nil)
  content.players = {}

  for i, player in ipairs(room.players) do
    content.players[player.player_number] = {
      settings = player:getSettings(),
      rating = room.ratings[i],
      winCount = room.win_counts[i],
      name = player.name,
      publicId = player.publicPlayerID,
      playerNumber = player.player_number
    }
  end

  return {
    messageType = msgTypes.jsonMessage,
    messageText = spectateRequestGrantedMessage,
  }
end

local createRoomTemplate = {
  sender = "server",
  type = "createRoom",
  content = {
    roomNumber = 0,
    ranked = nil,
    players = nil
  },
}

---@param room Room
---@return {messageType: table, messageText: ServerMessage}
function ServerProtocol.createRoom(room)
  local createRoomMessage = createRoomTemplate
  local content = createRoomMessage.content
  content.roomNumber = room.roomNumber
  content.ranked = room.ranked
  content.gameMode = room.gameMode
  content.players = {}

  for i, player in ipairs(room.players) do
    content.players[player.player_number] = {
      settings = player:getSettings(),
      rating = room.ratings[i],
      winCount = room.win_counts[i],
      name = player.name,
      publicId = player.publicPlayerID,
      playerNumber = player.player_number
    }
  end

  return {
    messageType = msgTypes.jsonMessage,
    messageText = createRoomMessage,
  }
end


local matchStartTemplate = {
  sender = "room",
  senderId = nil,
  type = "matchStart",
  content = nil
}

---@param roomNumber integer
---@param replay ReplayV3
---@return {messageType: table, messageText: ServerMessage}
function ServerProtocol.startMatch(roomNumber, replay)
  local startMatchMessage = matchStartTemplate
  startMatchMessage.senderId = roomNumber
  startMatchMessage.content = replay

  return {
    messageType = msgTypes.jsonMessage,
    messageText = startMatchMessage,
  }
end

---@class LobbyStateV2Message : ServerMessage
---@field content LobbyStateV2

local lobbyState2Template = {
  sender = "server",
  type = "lobbyStateV2",
  content = { }
}

---@return {messageType: table, messageText: LobbyStateV2Message}
function ServerProtocol.lobbyStateV2(players, rooms)
  local lobbyStateV2Message = lobbyState2Template

  lobbyStateV2Message.content.players = players
  lobbyStateV2Message.content.rooms = rooms

  return {
    messageType = msgTypes.jsonMessage,
    messageText = lobbyStateV2Message,
  }
end

local loginResponseTemplate = {
  sender = "server",
  type = "loginResponse",
  content = nil
}

---@param publicId integer
---@param notice string
---@param newId privateUserId?
---@param newName string?
---@param oldName string?
---@return {messageType: table, messageText: ServerMessage}
function ServerProtocol.approveLogin(publicId, notice, newId, newName, oldName)
  local approveLoginMessage = loginResponseTemplate
  local content = {}
  content.approved = true
  content.newUserId = newId
  content.publicId = publicId
  content.serverNotice = notice
  content.newName = newName
  content.oldName = oldName
  content.nameChanged = (newName ~= nil)
  content.serverTime = os.time()

  approveLoginMessage.content = content

  return {
    messageType = msgTypes.jsonMessage,
    messageText = approveLoginMessage,
  }
end

---@param reason string
---@param banDuration string?
---@return {messageType: table, messageText: ServerMessage}
function ServerProtocol.denyLogin(reason, banDuration)
  local denyLoginMessage = loginResponseTemplate
  local content = {}
  content.approved = false
  content.reason = reason
  content.banDuration = banDuration

  denyLoginMessage.content = content
  return {
    messageType = msgTypes.jsonMessage,
    messageText = denyLoginMessage,
  }
end

local gameResultTemplate = {
  sender = "room",
  senderId = nil,
  type = "gameResult",
  content = nil
}

---@param game ServerGame
---@param room Room
function ServerProtocol.gameResult(game, room)
  local gameResultMessage = gameResultTemplate
  local content = {}
  for _, player in ipairs(game.players) do
    -- publicId can't be the key as it would disallow developers playing against themselves for testing
    content[player.player_number] = {
      rating = room.ratings[player.player_number],
      winCount = room.win_counts[player.player_number],
      placement = game:getPlacement(player),
      publicId = player.publicPlayerID
    }
  end

  gameResultMessage.content = content

  -- For team games, attach per-team wins as a sibling field on the message itself rather
  -- than inside content. content is encoded as a JSON array (integer keys); adding a
  -- string-keyed sibling there would force dkjson to encode the whole thing as an object,
  -- which would break every client that does `for i in ipairs(content)` or
  -- `content[playerNumber]`. Keeping teamWins outside content sidesteps that.
  gameResultMessage.teamWins = nil
  if room.team_win_counts then
    local teamWins = {}
    for teamIndex, wins in ipairs(room.team_win_counts) do
      teamWins[teamIndex] = wins
    end
    gameResultMessage.teamWins = teamWins
  end

  return {
    messageType = msgTypes.jsonMessage,
    messageText = gameResultMessage,
  }
end

local spectatorUpdateTemplate = {
  sender = "room",
  senderId = nil,
  type = "spectatorUpdate",
  content = nil
}

---@param roomNumber integer
---@param spectators string[]
---@return {messageType: table, messageText: ServerMessage}
function ServerProtocol.updateSpectators(roomNumber, spectators)
  local spectatorUpdateMessage = spectatorUpdateTemplate
  spectatorUpdateMessage.senderId = roomNumber
  spectatorUpdateMessage.content = spectators

  return {
    messageType = msgTypes.jsonMessage,
    messageText = spectatorUpdateMessage,
  }
end

local rankedUpdateTemplate = {
  sender = "room",
  senderId = nil,
  type = "rankedUpdate",
  content = {}
}

---@return {messageType: table, messageText: ServerMessage}
function ServerProtocol.updateRankedStatus(roomNumber, ranked, comments)
  local rankedUpdateMessage = rankedUpdateTemplate
  rankedUpdateMessage.senderId = roomNumber
  rankedUpdateMessage.content.ranked = ranked
  rankedUpdateMessage.content.reasons = comments

  return {
    messageType = msgTypes.jsonMessage,
    messageText = rankedUpdateMessage,
  }
end

local tauntTemplate = {
  sender = "player",
  senderId = nil,
  type = "taunt",
  content = { type = "", index = 0 }
}

---@param player ServerPlayer
---@param type ("up" | "down")
---@param index integer
---@return {messageType: table, messageText: ServerMessage}
function ServerProtocol.taunt(player, type, index)
  local tauntMessage = tauntTemplate
  tauntMessage.senderId = player.publicPlayerID
  tauntMessage.content.type = type
  tauntMessage.content.index = index
  -- to support the transition
  tauntMessage.content.playerNumber = player.player_number

  return {
    messageType = msgTypes.jsonMessage,
    messageText = tauntMessage,
  }
end

local challengeUpdateTemplate = {
  sender = "player",
  senderId = nil,
  type = "challengeUpdate",
  content = {}
}

---@param sender ServerPlayer
---@param receiver ServerPlayer
---@param gameModeId GameModeID? nil if the challenged picks the game mode
---@param challengeActive boolean
---@param roomNumber integer? optional room number for team room invites
---@param slotNumber integer? optional slot number for team room invites
---@return {messageType: table, messageText: ServerMessage}
function ServerProtocol.sendChallengeUpdate(sender, receiver, gameModeId, challengeActive, roomNumber, slotNumber)
  local challengeMessage = challengeUpdateTemplate
  challengeMessage.senderId = sender.publicPlayerID
  challengeMessage.content.sender = sender.name
  challengeMessage.content.senderId = sender.publicPlayerID
  challengeMessage.content.receiver = receiver.name
  challengeMessage.content.receiverId = receiver.publicPlayerID
  challengeMessage.content.gameModeId = gameModeId
  challengeMessage.content.challengeActive = challengeActive
  challengeMessage.content.roomNumber = roomNumber
  challengeMessage.content.slotNumber = slotNumber

  return {
    messageType = msgTypes.jsonMessage,
    messageText = challengeMessage,
  }
end

local abortGameTemplate = {
  sender = "room",
  senderId = nil,
  type = "gameAbort",
  content = { source = nil }
}

---@param source ServerPlayer who requested the abort
---@param reason string? additional information to localize; may be nil for 1p aborts
function ServerProtocol.sendGameAbort(source, reason)
  local abortGameMessage = abortGameTemplate
  abortGameMessage.content.source = source.name
  abortGameMessage.content.reason = reason

  return {
    messageType = msgTypes.jsonMessage,
    messageText = abortGameMessage,
  }
end

local pauseNotificationTemplate = {
  sender = "room",
  senderId = nil,
  type = "pauseNotification",
  content = {
    source = nil,
    paused = nil,
  }
}

---@param source ServerPlayer who paused the game
function ServerProtocol.sendPauseNotification(roomNumber, source, paused)
  local pauseNotificationMessage = pauseNotificationTemplate
  pauseNotificationMessage.content.source = source.publicPlayerID
  pauseNotificationMessage.content.paused = paused
  pauseNotificationMessage.senderId = roomNumber

  return {
    messageType = msgTypes.jsonMessage,
    messageText = pauseNotificationMessage,
  }
end

local playerJoinedRoomTemplate = {
  sender = "room",
  senderId = nil,
  type = "playerJoinedRoom",
  content = {
    playerNumber = nil,
    name = nil,
    publicId = nil,
    settings = nil,
  }
}

---@param room Room
---@param player ServerPlayer
---@return {messageType: table, messageText: ServerMessage}
function ServerProtocol.playerJoinedRoom(room, player)
  local playerJoinedRoomMessage = playerJoinedRoomTemplate
  playerJoinedRoomMessage.senderId = room.roomNumber
  playerJoinedRoomMessage.content.playerNumber = player.player_number
  playerJoinedRoomMessage.content.name = player.name
  playerJoinedRoomMessage.content.publicId = player.publicPlayerID
  playerJoinedRoomMessage.content.settings = player:getSettings()

  return {
    messageType = msgTypes.jsonMessage,
    messageText = playerJoinedRoomMessage,
  }
end

local playerLeftRoomTemplate = {
  sender = "room",
  senderId = nil,
  type = "playerLeftRoom",
  content = {
    publicId = nil,
    name = nil,
    voidReason = nil,
  }
}

---Sent to remaining players + spectators when a player leaves/disconnects from a
---multi-player room. Tells the client to remove that player from the local room
---view and mark the room as voided (no further matches can start).
---@param roomNumber roomNumber
---@param publicId integer the leaver's publicPlayerID
---@param name string the leaver's display name
---@param voidReason string human-readable reason ("X left")
---@return {messageType: table, messageText: ServerMessage}
function ServerProtocol.playerLeftRoom(roomNumber, publicId, name, voidReason)
  local msg = playerLeftRoomTemplate
  msg.senderId = roomNumber
  msg.content.publicId = publicId
  msg.content.name = name
  msg.content.voidReason = voidReason
  return {
    messageType = msgTypes.jsonMessage,
    messageText = msg,
  }
end

return ServerProtocol