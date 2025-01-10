-- this file forms an abstraction layer to translate the messages sent by the server to a format understood by the client
-- the client should expect the formats specified in common/network/ServerProtocol which may extend to other standardised interop formats in common/data
-- e.g. Replay or LevelData
local ServerMessages = {}

function ServerMessages.toServerMenuState(player)
  -- what we're expected to send:
  --[[
    {
      "character_is_random": "__RandomCharacter", -- somewhat optional (bundles only)
      "stage_is_random": "__RandomStage",         -- somewhat optional (bundles only)
      "character_display_name": "Dragon",         -- I think not even stable is processing this one
      "cursor": "__Ready",                        -- this one uses a different grid system so I don't think it's worth the effort
      "ready": true,
      "level": 5,
      "wants_ready": true,
      "ranked": true,
      "panels_dir": "panelhd_basic_mizunoketsuban",
      "character": "pa_characters_dragon",
      "stage": "pa_stages_wind",
      "loaded": true
    }
  --]]
  local menuState = {}
  menuState.stage_is_random = player.settings.selectedStageId
  menuState.stage = player.settings.stageId
  menuState.character_is_random = player.settings.selectedCharacterId
  menuState.character = player.settings.characterId
  menuState.panels_dir = player.settings.panelId
  menuState.wants_ready = player.settings.wantsReady
  menuState.ranked = player.settings.wantsRanked
  menuState.level = player.settings.level
  menuState.loaded = player.hasLoaded
  menuState.ready = menuState.loaded and menuState.wants_ready
  menuState.inputMethod = player.settings.inputMethod
  menuState.cursor = "__Ready" -- play pretend
  menuState.levelData = player.settings.levelData

  return menuState
end


local function sanitizePlayerSettings1(settings, publicId)
  return {
    cursor = "__Ready",
    stageId = settings.stage,
    selectedStageId = settings.selectedStage,
    characterId = settings.character,
    selectedCharacterId = settings.selectedCharacter,
    panelId = settings.panels,
    level = settings.level,
    levelData = settings.levelData,
    inputMethod = settings.inputMethod,
    wantsRanked = settings.wantsRanked,
    wantsReady = settings.wantsReady,
    hasLoaded = settings.loaded,
    ready = settings.ready,
    publicId = publicId,
    playerNumber = settings.playerNumber
  }
end

local function sanitizePlayerSettings(message)
  return sanitizePlayerSettings1(message.content, message.senderId)
end

function ServerMessages.sanitizeMessage(message)
  if message.sender == "server" then
    return ServerMessages.sanitizeServerMessage(message)
  elseif message.sender == "room" then
    return ServerMessages.sanitizeRoomMessage(message)
  elseif message.sender == "player" then
    return ServerMessages.sanitizePlayerMessage(message)
  end
end

function ServerMessages.sanitizeRoomMessage(message)
  if message.type == "leaveRoom" then
    return {leave_room = true, reason = message.content.reason}
  elseif message.type == "gameResult" then
    return { gameResult = message.content }
  elseif message.type == "matchStart" then
    ---@type Replay
    local replay = message.content
    local settings = { shallowcpy(replay.players[1].settings), shallowcpy(replay.players[2].settings) }
    settings[1].publicId = replay.players[1].publicId
    settings[2].publicId = replay.players[2].publicId
    return
    {
      playerSettings = settings,
      seed = replay.seed,
      ranked = replay.ranked,
      stageId = replay.stageId,
      match_start = true,
    }
  elseif message.type == "spectatorUpdate" then
    return { spectators = message.content }
  elseif message.type == "rankedUpdate" then
    local msg = { reasons = message.content.reasons}

    if message.content.ranked then
      msg.ranked_match_approved = true
    else
      msg.ranked_match_denied = true
    end

    return msg
  end
  return message
end

function ServerMessages.sanitizeServerMessage(message)
  if message.type == "loginResponse" then
    if message.content.approved then
      return
      {
        login_successful = true,
        publicId = message.content.publicId,
        server_notice = message.content.serverNotice,
        new_user_id = message.content.newUserId,
        new_name = message.content.newName,
        old_name = message.content.oldName,
        name_changed = message.content.nameChanged,
      }
    else
      return
      {
        login_denied = true,
        reason = message.content.reason,
        ban_duration = message.content.banDuration,
      }
    end
  elseif message.type == "lobbyState" then
    return message.content
  elseif message.type == "leaderboardReport" then
    return { leaderboard_report = message.content }
  elseif message.type == "spectateRequestGranted" then
    local winCounts = {}
    local players = {}
    for publicId, player in pairs(message.content.players) do
      winCounts[player.playerNumber] = player.winCount
      players[player.playerNumber] = {
        playerNumber = player.playerNumber,
        ratingInfo = player.rating,
        name = player.name,
        publicId = publicId,
        settings = sanitizePlayerSettings1(player.settings),
      }
    end

    return
    {
      spectate_request_granted = true,
      stageId = message.content.stage,
      ranked = message.content.ranked,
      winCounts = winCounts,
      players = players,
      replay = message.content.replay
    }
  elseif message.type == "createRoom" then
    local players = {}
    for i, player in ipairs(message.content.players) do
      players[player.playerNumber] = {
        playerNumber = player.playerNumber,
        ratingInfo = player.rating,
        name = player.name,
        publicId = player.publicId,
        settings = sanitizePlayerSettings1(player.settings),
      }
      players[player.playerNumber].settings.playerNumber = player.playerNumber
    end

    return {
      create_room = true,
      ranked = message.content.ranked,
      players = players,
    }
  else
    return message
  end
end

function ServerMessages.sanitizePlayerMessage(message)
  local content = message.content
  if message.type == "settingsUpdate" then
    return
    {
      menu_state = sanitizePlayerSettings(message),
    }
  elseif message.type == "taunt" then
    return
    {
      taunt = true,
      type = content.type,
      index = content.index,
      player_number = content.playerNumber,
    }
  elseif message.type == "challenge" then
    return
    {
      game_request =
      {
        sender = content.sender,
        receiver = content.receiver,
      }
    }
  end
  return message
end

return ServerMessages