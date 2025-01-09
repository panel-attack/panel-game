-- this file forms an abstraction layer to translate the messages sent by the server to a format understood by the client
-- the client should expect the formats specified common/network/ServerProtocol and other standardised interop formats
-- e.g. Replay or LevelData
local ServerMessages = {}

local Replay = require("common.data.Replay")

function ServerMessages.sanitizeMenuState(menuState)
  --[[
    "b_menu_state": {
        "character_is_random": "__RandomCharacter",
        "stage_is_random": "__RandomStage",
        "character_display_name": "",
        "cursor": "__Ready",
        "panels_dir": "panelhd_basic_mizunoketsuban",
        "ranked": true,
        "stage": "__RandomStage",
        "character": "__RandomCharacter",
        "level": 5,
        "inputMethod": "controller"
    },

    or 

    "character_is_random": "__RandomCharacter",
    "stage_is_random": "__RandomStage",
    "character_display_name": "Dragon",
    "cursor": "__Ready",
    "ready": true,
    "level": 5,
    "wants_ready": true,
    "ranked": true,
    "panels_dir": "panelhd_basic_mizunoketsuban",
    "character": "pa_characters_dragon",
    "stage": "pa_stages_wind",
    "loaded": true
  --]]

  local sanitized = { sanitized = true}
  sanitized.panelId = menuState.panels_dir
  sanitized.characterId = menuState.character
  sanitized.selectedCharacterId = menuState.character_is_random
  sanitized.stageId = menuState.stage
  sanitized.selectedStageId = menuState.stage_is_random
  sanitized.level = menuState.level
  sanitized.wantsRanked = menuState.ranked
  sanitized.inputMethod = menuState.inputMethod

  sanitized.wantsReady = menuState.wants_ready
  sanitized.hasLoaded = menuState.loaded
  sanitized.ready = menuState.ready
  sanitized.publicId = menuState.publicId

  -- ignoring cursor for now
  --sanitized.cursorPosCode = menuState.cursor
  -- categorically ignoring character display name


  return sanitized
end

function ServerMessages.sanitizeCreateRoom(message)
  -- how these messages look
  --[[
  "a_menu_state": {
        see sanitizeMenuState
    },
    "b_menu_state": {
        see sanitizeMenuState
    },
    "create_room": true,
    "your_player_number": 2,
    "op_player_number": 1,
    "ratings": [{
            "new": 1391,
            "league": "Silver",
            "old": 1391,
            "difference": 0
        }, {
            "league": "Newcomer",
            "placement_match_progress": "0/30 placement matches played.",
            "new": 0,
            "old": 0,
            "difference": 0
        }
    ],
    "opponent": "oh69fermerchan",
    "rating_updates": true
}
  ]]--
  local players = {}
  players[1] = ServerMessages.sanitizeMenuState(message.a_menu_state)
  -- convention, a_menu_state belongs to player_number 1
  players[1].playerNumber = 1
  players[2] = ServerMessages.sanitizeMenuState(message.b_menu_state)
  -- convention, b_menu_state belongs to player_number 2
  players[2].playerNumber = 2
  if message.rating_updates then
    players[1].ratingInfo = message.ratings[1]
    if players[1].ratingInfo.new == 0 and players[1].ratingInfo.placement_match_progress then
      players[1].ratingInfo.new = players[1].ratingInfo.placement_match_progress
    end
    players[2].ratingInfo = message.ratings[2]
    if players[2].ratingInfo.new == 0 and players[2].ratingInfo.placement_match_progress then
      players[2].ratingInfo.new = players[2].ratingInfo.placement_match_progress
    end
  end

  if message.your_player_number == 2 then
    -- players 1 is expected to be the local player
    players[1], players[2] = players[2], players[1]
  end

  players[2].name = message.opponent

  return { create_room = true, sanitized = true, players = players}
end

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

function ServerMessages.sanitizeSettings(settings)
  return
  {
    playerNumber = settings.player_number,
    level = settings.level,
    characterId = settings.character,
    panelId = settings.panels_dir,
    inputMethod = settings.inputMethod,
    publicId = settings.publicId,
    sanitized = true
  }
end

function ServerMessages.sanitizeStartMatch(message)
  --[[
    "ranked": false,
    "opponent_settings": {
        "character_display_name": "Bumpty",
        "player_number": 2,
        "level": 8,
        "panels_dir": "pdp_ta_common",
        "character": "pa_characters_bumpty"
    },
    "stage": "pa_stages_fire",
    "player_settings": {
        "character_display_name": "Blargg",
        "player_number": 1,
        "level": 8,
        "panels_dir": "panelhd_basic_mizunoketsuban",
        "character": "pa_characters_blargg"
    },
    "seed": 3245472,
    "match_start": true
  --]]
  local playerSettings = {}
  playerSettings[1] = ServerMessages.sanitizeSettings(message.player_settings)
  playerSettings[2] = ServerMessages.sanitizeSettings(message.opponent_settings)

  local matchStart = {
    playerSettings = playerSettings,
    seed = message.seed,
    ranked = message.ranked,
    stageId = message.stage,
    match_Start = true,
    sanitized = true
  }

  return matchStart
end

function ServerMessages.sanitizeSpectatorJoin(message)
  --[[
    "rating_updates": true,
    "spectate_request_rejected": false,
    "win_counts": [1, 11],
    "match_start": false,
    "ranked": false,
    "stage": "pa_stages_flower",
    "spectate_request_granted": true,
    "a_menu_state": { as usual },
    "b_menu_state": { as usual },
    "ratings": [{
            "new": 0,
            "old": 0,
            "difference": 0,
            "league": "Newcomer",
            "placement_match_progress": "0/30 placement matches played."
        }, {
            "new": 0,
            "old": 0,
            "difference": 0,
            "league": "Newcomer",
            "placement_match_progress": "0/30 placement matches played."
        }
    ],
    -- we can effectively ignore these in favor of menu state
    -- only override the level just to be sure
    "player_settings": {
      anomaly: no panel id
        "level": 5,
        "character_display_name": "Froggy",
        "character": "pa_characters_froggy",
        "player_number": 1
    },
    "opponent_settings": {
      anomaly: no panel id
        "level": 5,
        "character_display_name": "Yoshi",
        "character": "pa_characters_yoshi",
        "player_number": 2
    },
    "replay_of_match_so_far": {
        "vs": {
            "P2_level": 8,
            "P2_name": "kornflakes_apk",
            "P2_char": "pa_characters_bumpty",
            "seed": 343818,
            "P1_level": 8,
            "in_buf": "omitted for brevity, in_buf contains encoded inputs for P1",
            "I": "omitted for brevity, I contains encoded inputs for P2",
            "Q": "",
            "R": "",
            "do_countdown": true,
            "ranked": false,
            "P": "",
            "O": "",
            "P1_name": "fightmeyoucoward",
            "P1_char": "pa_characters_blargg"
        }
    },
    "spectate_request_rejected": false
  ]]--
  local playerSettings = {}
  playerSettings[1] = ServerMessages.sanitizeSettings(message.player_settings)
  playerSettings[2] = ServerMessages.sanitizeSettings(message.opponent_settings)
  local players = {}
  players[1] = ServerMessages.sanitizeMenuState(message.a_menu_state)
  -- "you" is player 1
  players[1].playerNumber = message.your_player_number
  players[1].name = message.a_name
  players[1].playerNumber = playerSettings[1].playerNumber
  players[1].ratingInfo = message.ratings[1]
  if players[1].ratingInfo.new == 0 and players[1].ratingInfo.placement_match_progress then
    players[1].ratingInfo.new = players[1].ratingInfo.placement_match_progress
  end  
  players[1].level = playerSettings[1].level

  players[2] = ServerMessages.sanitizeMenuState(message.b_menu_state)
  players[2].name = message.b_name
  players[2].playerNumber = playerSettings[2].playerNumber
  players[2].ratingInfo = message.ratings[2]
  if players[2].ratingInfo.new == 0 and players[2].ratingInfo.placement_match_progress then
    players[2].ratingInfo.new = players[2].ratingInfo.placement_match_progress
  end
  players[2].level = playerSettings[2].level

  local replay = message.replay_of_match_so_far
  if replay then
    replay = Replay.createFromTable(replay, false)

    for i, p in ipairs(replay.players) do
      players[i].name = p.name
    end
  end

  return{
    spectate_request_granted = true,
    stageId = message.stage,
    ranked = message.ranked,
    winCounts = message.win_counts,
    players = players,
    replay = replay
  }
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
    loaded = settings.loaded,
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
    -- this is a new type, need to handle in client code
    return message
  elseif message.type == "startMatch" then
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
      match_Start = true,
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
        level = player.settings.level,
        levelData = player.settings.levelData,
        publicId = player.publicId,
        settings = sanitizePlayerSettings1(player.settings),
      }
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
  if message.type == "settingsUpdate" then
    local content = message.content
    return
    {
      menu_state = sanitizePlayerSettings(message),
      player_number = content.playerNumber
    }
  elseif message.type == "taunt" then
    return
    {
      taunt = true,
      type = message.content.type,
      index = message.content.index,
      player_number = message.content.playerNumber,
    }
  elseif message.type == "challenge" then
    return
    {
      game_request =
      {
        sender = message.content.sender,
        receiver = message.content.receiver,
      }
    }
  end
  return message
end

return ServerMessages