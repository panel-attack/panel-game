-- provide an abstraction layer to convert messages as defined in common/network/ClientProtocol
-- into the format used by the server's internals
-- so that changes in the ClientProtocol only affect this abstraction layer and not server code
-- and changes in server code likewise only affect this abstraction layer instead of the ClientProtocol

local ClientMessages = {}

-- central sanitization function that picks a sanitization function based on the presence of key fields
function ClientMessages.sanitizeMessage(clientMessage)
  if clientMessage.login_request then
    return ClientMessages.sanitizeLoginRequest(clientMessage)
  elseif clientMessage.game_request then
    return ClientMessages.sanitizeGameRequest(clientMessage)
  elseif clientMessage.menu_state then
    return ClientMessages.sanitizeMenuState(clientMessage)
  elseif clientMessage.spectate_request then
    return ClientMessages.sanitizeSpectateRequest(clientMessage)
  elseif clientMessage.leaderboard_request then
    return ClientMessages.sanitizeLeaderboardRequest(clientMessage)
  elseif clientMessage.leave_room then
    return ClientMessages.sanitizeLeaveRoom(clientMessage)
  elseif clientMessage.taunt then
    return ClientMessages.sanitizeTaunt(clientMessage)
  elseif clientMessage.game_over then
    return ClientMessages.sanitizeGameResult(clientMessage)
  else
    local errorMsg = "Received an unexpected message"
    if clientMessage:len() > 10000 then
      errorMsg = errorMsg .. " with " .. clientMessage:len() .. " characters"
    else
      errorMsg = errorMsg .. ":\n  " .. clientMessage
    end
    logger.error(errorMsg)
    return { unknown = true}
  end
end

function ClientMessages.sanitizeMenuState(playerSettings)
  local sanitized = {}

  sanitized.character = playerSettings.character
  sanitized.character_is_random = playerSettings.character_is_random
  sanitized.character_display_name = playerSettings.character_display_name
  sanitized.cursor = playerSettings.cursor -- nil when from login
  sanitized.inputMethod = (playerSettings.inputMethod or "controller") --one day we will require message to include input method, but it is not this day.
  sanitized.level = playerSettings.level
  sanitized.panels_dir = playerSettings.panels_dir
  sanitized.ready = playerSettings.ready -- nil when from login
  sanitized.stage = playerSettings.stage
  sanitized.stage_is_random = playerSettings.stage_is_random
  sanitized.wants_ranked_match = playerSettings.ranked

  return {menu_state = sanitized}
end

function ClientMessages.sanitizeLoginRequest(loginRequest)
  local sanitized =
  {
    login_request = true,
    user_id = loginRequest.user_id,
    engine_version = loginRequest.engine_version,
    name = loginRequest.name,
    level = loginRequest.level,
    inputMethod = loginRequest.inputMethod,
    panels_dir = loginRequest.panels_dir,
    character_is_random = loginRequest.character_is_random,
    character = loginRequest.character,
    stage_is_random = loginRequest.stage_is_random,
    stage = loginRequest.stage,
    ranked = loginRequest.ranked,
    save_replays_publicly = loginRequest.save_replays_publicly
  }

  return sanitized
end

function ClientMessages.sanitizeGameRequest(gameRequest)
  local sanitized =
  {
    game_request =
    {
      sender = gameRequest.game_request.sender,
      receiver = gameRequest.game_request.receiver,
    }
  }

  return sanitized
end

function ClientMessages.sanitizeSpectateRequest(spectateRequest)
  local sanitized =
  {
    spectate_request =
    {
      sender = spectateRequest.spectate_request.sender,
      roomNumber = spectateRequest.spectate_request.roomNumber,
    }
  }

  return sanitized
end

function ClientMessages.sanitizeLeaderboardRequest(leaderboardRequest)
  local sanitized =
  {
    leaderboard_request = leaderboardRequest.leaderboard_request
  }

  return sanitized
end

function ClientMessages.sanitizeLeaveRoom(leaveRoom)
  local sanitized =
  {
    leave_room = leaveRoom.leave_room
  }

  return sanitized
end

function ClientMessages.sanitizeGameResult(gameResult)
  local sanitized =
  {
    game_over = gameResult.game_over,
    outcome = gameResult.outcome
  }

  return sanitized
end

function ClientMessages.sanitizeTaunt(taunt)
  local sanitized =
  {
    taunt = taunt.taunt,
    type = taunt.type,
    index = taunt.index
  }

  return sanitized
end

return ClientMessages