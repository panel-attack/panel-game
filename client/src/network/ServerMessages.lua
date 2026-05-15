local ReplayV3 = require("common.data.ReplayV3")
local GameModes = require("common.data.GameModes")
local tableUtils = require("common.lib.tableUtils")
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
  if player.settings.style == GameModes.Styles.MODERN then
    menuState.level = player.settings.level
  else
    menuState.level = player.settings.difficulty
  end
  menuState.loaded = player.hasLoaded
  menuState.ready = menuState.loaded and menuState.wants_ready
  menuState.inputMethod = player.settings.inputMethod
  menuState.cursor = "__Ready" -- play pretend
  menuState.levelData = player.settings.levelData
  menuState.endless_no_raise = player.settings.endlessNoRaise == true

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
    playerNumber = settings.playerNumber,
    endlessNoRaise = settings.endless_no_raise == true
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
    for i, player in ipairs(message.content) do
      player.ratingInfo = player.rating
      player.rating = nil
    end
    -- teamWins / winnerTeamIndex / winnerIndex live at the outer message level
    -- (sibling of content) to keep `content` a JSON array — see
    -- ServerProtocol.gameResult for why.
    return {
      gameResult = message.content,
      teamWins = message.teamWins,
      winnerTeamIndex = message.winnerTeamIndex,
      winnerIndex = message.winnerIndex,
    }
  elseif message.type == "matchStart" then
    local replay = ReplayV3.createFromTable(message.content, false)

    return
    {
      replay = replay,
      match_start = true,
      startAtMs = message.startAtMs,
    }
  elseif message.type == "spectatorUpdate" then
    return { spectators = message.content }
  elseif message.type == "rankedUpdate" then
    return {
      ranked_match_approved = message.content.ranked,
      reasons = message.content.reasons,
    }
  elseif message.type == "playerJoinedRoom" then
    local joined = message.content
    return {
      playerJoinedRoom = {
        playerNumber = joined.playerNumber,
        name = joined.name,
        publicId = joined.publicId,
        settings = joined.settings and sanitizePlayerSettings1(joined.settings, joined.publicId) or nil,
      }
    }
  elseif message.type == "playerLeftRoom" then
    return {
      playerLeftRoom = {
        publicId = message.content.publicId,
        name = message.content.name,
        voidReason = message.content.voidReason,
        heldSlots = message.content.heldSlots,
      }
    }
  elseif message.type == "gameAbort" then
    return { gameAbort = true, source = message.content.source }
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
        serverTime = message.content.serverTime
      }
    else
      return
      {
        login_denied = true,
        reason = message.content.reason,
        ban_duration = message.content.banDuration,
      }
    end
  elseif message.type == "lobbyStateV2" then
    ---@type LobbyStateV2
    local content = message.content
    content.players = tableUtils.reassignIntegerKeysAfterJsonification(content.players)
    content.rooms = tableUtils.reassignIntegerKeysAfterJsonification(content.rooms)
    
    return { lobbyStateV2 = true, content = content }
  elseif message.type == "leaderboardReport" then
    return { leaderboard_report = message.content }
  elseif message.type == "spectateRequestGranted" or message.type == "joinQueued" then
    local winCounts = {}
    local players = {}
    for index, player in pairs(message.content.players) do
      winCounts[player.playerNumber] = player.winCount
      players[player.playerNumber] = {
        playerNumber = player.playerNumber,
        ratingInfo = player.rating,
        name = player.name,
        publicId = player.publicId or -index,
        settings = sanitizePlayerSettings1(player.settings),
      }
    end

    if message.content.replay then
      message.content.replay = ReplayV3.createFromTable(message.content.replay, false)
    end

    local result = {
      stageId = message.content.stage,
      ranked = message.content.ranked,
      winCounts = winCounts,
      players = players,
      gameMode = message.content.gameMode,
      replay = message.content.replay,
      roomNumber = message.content.roomNumber,
    }
    result.spectate_request_granted = true
    if message.type == "joinQueued" then
      result.joinQueued = true
      result.pendingPromotion = true
    end
    return result
  elseif message.type == "createRoom" then
    local players = {}
    for index, player in pairs(message.content.players) do
      players[player.playerNumber] = {
        playerNumber = player.playerNumber,
        ratingInfo = player.rating,
        name = player.name,
        publicId = player.publicId or -index,
        settings = sanitizePlayerSettings1(player.settings),
      }
      players[player.playerNumber].settings.playerNumber = player.playerNumber
    end

    return {
      create_room = true,
      ranked = message.content.ranked,
      players = players,
      roomNumber = message.content.roomNumber,
      gameMode = message.content.gameMode,
      teamWins = message.content.teamWins,
    }
  elseif message.type == "addToRoom" then
    local players = {}
    for index, player in pairs(message.content.players) do
      players[player.playerNumber] = {
        playerNumber = player.playerNumber,
        ratingInfo = player.rating,
        name = player.name,
        publicId = player.publicId or -index,
        settings = sanitizePlayerSettings1(player.settings),
      }
      players[player.playerNumber].settings.playerNumber = player.playerNumber
    end

    return {
      addToRoom = true,
      ranked = message.content.ranked,
      players = players,
      roomNumber = message.content.roomNumber,
      gameMode = message.content.gameMode,
      teamWins = message.content.teamWins,
      heldSlots = message.content.heldSlots,
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
  elseif message.type == "challengeUpdate" then
    return
    {
      challengeUpdate =
      {
        senderId = content.senderId,
        receiverId = content.receiverId,
        gameModeId = content.gameModeId,
        challengeActive = content.challengeActive,
        roomNumber = content.roomNumber,
        slotNumber = content.slotNumber,
      }
    }
  end
  return message
end

return ServerMessages