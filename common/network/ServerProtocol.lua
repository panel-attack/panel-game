local NetworkProtocol = require("common.network.NetworkProtocol")
local msgTypes = NetworkProtocol.serverMessageTypes
local consts = require("common.engine.consts")

local ServerMessages = {}

-------------------------------------------------------------------
-- Helper methods for converting to ServerProtocol table formats --
-------------------------------------------------------------------

function ServerMessages.toSettings(ready, level, inputMethod, stage, selectedStage, character, selectedCharacter, panels, wantsRanked)
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
    inputMethod = inputMethod
  }
  return settings
end

function ServerMessages.toDumbSettings(character, level, panels, playerNumber, inputMethod, rating)
  local playerSettings =
  {
    character = character,
    level = level,
    panels_dir = panels,
    player_number = playerNumber,
    inputMethod = inputMethod,
    rating = rating,
  }

  return playerSettings
end

function ServerMessages.toReplay(levelA, levelB, inputMethodA, inputMethodB, inputsA, inputsB, characterA, characterB, ranked)
  local replay =
  {
    do_countdown = true,
    in_buf = inputsA or "",
    I = inputsB or "",
    P1_level = levelA,
    P2_level = levelB,
    P1_inputMethod = inputMethodA,
    P2_inputMethod = inputMethodB,
    P1_char = characterA,
    P2_char = characterB,
    ranked = ranked,
  }

  return replay
end

function ServerMessages.toRating(oldRating, newRating, ratingDiff, league, placementProgress)
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

function ServerMessages.leaveRoom()
  local leaveRoomMessage = {leave_room = true}
  return {
    messageType = msgTypes.jsonMessage,
    messageText = leaveRoomMessage,
  }
end

function ServerMessages.spectateRequestGranted(roomNumber, settingsA, settingsB, ratingA, ratingB, nameA, nameB, winCounts, stage, replay, ranked, dumbSettingsA, dumbSettingsB)
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

function ServerMessages.createRoom(roomNumber, settingsA, settingsB, ratingA, ratingB, opponentName, opponentNumber)
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

function ServerMessages.startMatch(seed, ranked, stage, dumbSettingsRecipient, dumbSettingsOpponent)
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

function ServerMessages.lobbyState(unpaired, rooms, allPlayers)
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

function ServerMessages.approveLogin(notice, newId, newName, oldName)
  local approveLoginMessage =
  {
    login_successful = true,
    server_notice = notice,
    new_user_id = newId,
    new_name = newName,
    old_name = oldName,
    name_changed = (newName ~= nil)
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = approveLoginMessage,
  }
end

function ServerMessages.denyLogin(reason, banDuration)
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

function ServerMessages.winCounts(p1Wins, p2Wins)
  local winCountMessage =
  {
    win_counts = {p1Wins, p2Wins}
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = winCountMessage,
  }
end

function ServerMessages.characterSelect(ratingA, ratingB, settingsA, settingsB)
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

function ServerMessages.updateSpectators(spectators)
  local spectatorUpdateMessage =
  {
    spectators = spectators,
  }

  return {
    messageType = msgTypes.jsonMessage,
    messageText = spectatorUpdateMessage,
  }
end

function ServerMessages.updateRankedStatus(ranked, comments)
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

function ServerMessages.taunt(playerNumber, type, index)
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

function ServerMessages.confirmVersionCompatibility()
  return {
    messageType = msgTypes.versionCorrect
  }
end

function ServerMessages.rejectVersionCompatibility()
  return {
    messageType = msgTypes.versionWrong
  }
end

function ServerMessages.ping()

end

return ServerMessages