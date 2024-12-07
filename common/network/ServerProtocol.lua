local NetworkProtocol = require("common.network.NetworkProtocol")
local msgTypes = NetworkProtocol.serverMessageTypes

local ServerProtocol = {}

-------------------------------------------------------------------
-- Helper methods for converting to ServerProtocol table formats --
-------------------------------------------------------------------

function ServerProtocol.toSettings(ready, level, inputMethod, stage, selectedStage, character, selectedCharacter, panels, wantsRanked, wantsReady, loaded, publicId, levelData)
  local settings = {
    cursor = "__Ready",
    stage = stage,
    stage_is_random = selectedStage,
    ready = ready,
    character = character,
    character_is_random = selectedCharacter,
    panels_dir = panels,
    level = level,
    ranked = wantsRanked,
    inputMethod = inputMethod,
    wants_ready = wantsReady,
    loaded = loaded,
    publicId = publicId,
    levelData = levelData,
  }
  return settings
end

-- rating in this case is not the table returned from toRating but only the "new" value
function ServerProtocol.toDumbSettings(character, level, panels, playerNumber, inputMethod, rating, publicId, levelData)
  local playerSettings =
  {
    character = character,
    level = level,
    panels_dir = panels,
    player_number = playerNumber,
    inputMethod = inputMethod,
    rating = rating,
    publicId = publicId,
    levelData = levelData
  }

  return playerSettings
end

function ServerProtocol.toRating(oldRating, newRating, ratingDiff, league, placementProgress)
  return
  {
    old = oldRating,
    new = newRating,
    difference = ratingDiff,
    league = league,
    placement_match_progress = placementProgress,
  }
end

----------------------------
-- Actual server messages --
----------------------------

function ServerProtocol.menuState(settings, playerNumber)
  local menuStateMessage = {
    menu_state = settings,
    player_number = playerNumber,
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = menuStateMessage,
  }
end

local leaveRoom = {
  messageType = msgTypes.jsonMessage,
  messageText = {leave_room = true},
}
function ServerProtocol.leaveRoom()
  return leaveRoom
end

function ServerProtocol.sendLeaderboard(leaderboard)
  local leaderboardReport = {
    leaderboard_report = leaderboard
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = leaderboardReport,
  }
end

function ServerProtocol.spectateRequestGranted(roomNumber, settingsA, settingsB, ratingA, ratingB, nameA, nameB, winCounts, stage, replay, ranked, dumbSettingsA, dumbSettingsB)
  local spectateRequestGrantedMessage =
  {
    spectate_request_granted = true,
    spectate_request_rejected = false,
    room_number = roomNumber,
    rating_updates = true,
    ratings = {ratingA, ratingB},
    a_menu_state = settingsA,
    b_menu_state = settingsB,
    a_name = nameA,
    b_name = nameB,
    win_counts = winCounts,
    match_start = replay ~= nil,
    stage = stage,
    replay_of_match_so_far = replay,
    ranked = ranked,
    player_settings = dumbSettingsA,
    opponent_settings = dumbSettingsB,
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = spectateRequestGrantedMessage,
  }
end

function ServerProtocol.createRoom(roomNumber, settingsA, settingsB, ratingA, ratingB, opponentName, opponentNumber)
  local createRoomMessage =
  {
    create_room = true,
    room_number = roomNumber,
    a_menu_state = settingsA,
    b_menu_state = settingsB,
    rating_updates = true,
    ratings = {ratingA, ratingB},
    opponent = opponentName,
    op_player_number = opponentNumber,
    your_player_number = (opponentNumber == 1) and 2 or 1,
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = createRoomMessage,
  }
end

function ServerProtocol.startMatch(seed, ranked, stage, dumbSettingsRecipient, dumbSettingsOpponent)
  local startMatchMessage =
  {
    match_start = true,
    seed = seed,
    ranked = ranked,
    stage = stage,
    player_settings = dumbSettingsRecipient,
    opponent_settings = dumbSettingsOpponent,
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = startMatchMessage,
  }
end

function ServerProtocol.lobbyState(unpaired, rooms, allPlayers)
  local lobbyStateMessage =
  {
    unpaired = unpaired,
    spectatable = rooms,
    players = allPlayers,
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = lobbyStateMessage,
  }
end

function ServerProtocol.approveLogin(notice, newId, newName, oldName, publicId)
  local approveLoginMessage =
  {
    login_successful = true,
    server_notice = notice,
    new_user_id = newId,
    new_name = newName,
    old_name = oldName,
    name_changed = (newName ~= nil),
    publicId = publicId,
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = approveLoginMessage,
  }
end

function ServerProtocol.denyLogin(reason, banDuration)
  local denyLoginMessage =
  {
    login_denied = true,
    reason = reason,
    ban_duration = banDuration,
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = denyLoginMessage,
  }
end

function ServerProtocol.winCounts(p1Wins, p2Wins)
  local winCountMessage =
  {
    win_counts = {p1Wins, p2Wins}
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = winCountMessage,
  }
end

function ServerProtocol.characterSelect(ratingA, ratingB, settingsA, settingsB)
  local characterSelectMessage =
  {
    character_select = true,
    rating_updates = true,
    ratings = {ratingA, ratingB},
    a_menu_state = settingsA,
    b_menu_state = settingsB,
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = characterSelectMessage,
  }
end

function ServerProtocol.updateSpectators(spectators)
  local spectatorUpdateMessage =
  {
    spectators = spectators,
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = spectatorUpdateMessage,
  }
end

function ServerProtocol.updateRankedStatus(ranked, comments)
  local rankedUpdateMessage =
  {
    reasons = comments,
  }

  if ranked then
    rankedUpdateMessage.ranked_match_approved = true
  else
    rankedUpdateMessage.ranked_match_denied = true
  end

  return {
    messageType = msgTypes.jsonMessage,
    messageText = rankedUpdateMessage,
  }
end

function ServerProtocol.taunt(playerNumber, type, index)
  local tauntMessage = {
    taunt = true,
    type = type,
    index = index,
    player_number = playerNumber,
  }
  return {
    messageType = msgTypes.jsonMessage,
    messageText = tauntMessage,
  }
end

function ServerProtocol.sendChallenge(sender, receiver)
  local challengeMessage = {
    game_request =
    {
      sender = sender,
      receiver = receiver,
    }
  }
  return {
    messageType = msgTypes.jsonMessage,
    messageText = challengeMessage,
  }
end

function ServerProtocol.updateRating(ratingA, ratingB)
  local ratingUpdate = {
    rating_updates = true,
    ratings = { ratingA, ratingB }
  }
  return {
    messageType = msgTypes.jsonMessage,
    messageText = ratingUpdate,
  }
end

return ServerProtocol