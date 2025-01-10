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
---@param replay Replay?
function ServerProtocol.addToRoom(room, replay)
  local addToRoomMessage = addToRoomTemplate
  local content = addToRoomMessage.content
  content.roomNumber = room.roomNumber
  content.gameMode = room.gameMode
  content.ranked = (replay and replay.ranked or room.ranked)
  content.replay = replay
  content.stage = (replay and replay.stageId or nil)
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
---@param replay Replay?
---@return {messageType: table, messageText: ServerMessage}
function ServerProtocol.spectateRequestGranted(room, replay)
  local spectateRequestGrantedMessage = spectateRequestGrantedTemplate
  local content = spectateRequestGrantedMessage.content
  content.roomNumber = room.roomNumber
  content.gameMode = room.gameMode
  content.ranked = (replay and replay.ranked or room.ranked)
  content.replay = replay
  content.stage = (replay and replay.stageId or nil)
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
---@param replay Replay
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

local lobbyStateTemplate = {
  sender = "server",
  type = "lobbyState",
  content = { }
}

---@return {messageType: table, messageText: ServerMessage}
function ServerProtocol.lobbyState(unpaired, rooms, allPlayers)
  local lobbyStateMessage = lobbyStateTemplate

  lobbyStateMessage.content.unpaired = unpaired
  lobbyStateMessage.content.spectatable = rooms
  lobbyStateMessage.content.players = allPlayers

  return {
    messageType = msgTypes.jsonMessage,
    messageText = lobbyStateMessage,
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

local challengeTemplate = {
  sender = "player",
  senderId = nil,
  type = "challenge",
  content = {}
}

---@param sender ServerPlayer
---@param receiver ServerPlayer
---@return {messageType: table, messageText: ServerMessage}
function ServerProtocol.sendChallenge(sender, receiver)
  local challengeMessage = challengeTemplate
  challengeMessage.senderId = sender.publicPlayerID
  challengeMessage.content.sender = sender.name
  challengeMessage.content.receiver = receiver.name

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
function ServerProtocol.sendGameAbort(source)
  local abortGameMessage = abortGameTemplate
  abortGameMessage.content.source = source.name

  return {
    messageType = msgTypes.jsonMessage,
    messageText = abortGameMessage,
  }
end

return ServerProtocol