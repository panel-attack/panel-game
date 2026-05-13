-- provide an abstraction layer to convert messages as defined in common/network/ClientProtocol
-- into the format used by the server's internals
-- so that changes in the ClientProtocol only affect this abstraction layer and not server code
-- and changes in server code likewise only affect this abstraction layer instead of the ClientProtocol
local logger = require("common.lib.logger")
local LevelData = require("common.data.LevelData")
local GameModes = require("common.data.GameModes")

local ClientMessages = {}

-- central sanitization function that picks a sanitization function based on the presence of key fields
function ClientMessages.sanitizeMessage(clientMessage)
  if clientMessage.login_request then
    return ClientMessages.sanitizeLoginRequest(clientMessage)
  elseif clientMessage.challengeUpdate then
    return ClientMessages.sanitizeChallengeUpdate(clientMessage)
  elseif clientMessage.menu_state then
    return ClientMessages.sanitizeMenuState(clientMessage.menu_state)
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
  elseif clientMessage.stackEliminated then
    return ClientMessages.sanitizeStackEliminated(clientMessage)
  elseif clientMessage.joinRoomRequest then
    return ClientMessages.sanitizeJoinRoomRequest(clientMessage)
  elseif clientMessage.logout then
    return clientMessage
  elseif clientMessage.type and clientMessage.type == "roomRequest" then
    return ClientMessages.sanitizeRoomRequest(clientMessage)
  elseif clientMessage.type and clientMessage.type == "matchAbort" then
    return ClientMessages.sanitizeMatchAbort(clientMessage)
  elseif clientMessage.type and clientMessage.type == "pauseToggle" then
    return ClientMessages.sanitizePauseToggle(clientMessage)
  elseif clientMessage.error_report then
    return clientMessage
  elseif clientMessage.flagGame then
    return ClientMessages.sanitizeFlagGame(clientMessage)
  elseif clientMessage.crashSlice then
    return ClientMessages.sanitizeCrashSlice(clientMessage)
  else
    local errorMsg = "Received an unexpected message"
    local messageJson = json.encode(clientMessage)
    if messageJson and type(messageJson) == "string" and messageJson:len() > 10000 then
      errorMsg = errorMsg .. " with " .. messageJson:len() .. " characters"
    else
      errorMsg = errorMsg .. ":\n  " .. tostring(messageJson)
    end
    logger.error(errorMsg)
    return { unknown = true}
  end
end

---@class ServerIncomingPlayerSettings
---@field cursor string?
---@field stage string?
---@field stage_is_random string?
---@field ready boolean?
---@field character string?
---@field character_is_random string?
---@field panels_dir string?
---@field level integer?
---@field ranked boolean?
---@field inputMethod InputMethod?
---@field wants_ready boolean?
---@field loaded boolean?
---@field publicId integer?
---@field levelData LevelData?
---@field wants_ranked_match boolean?

---@return {playerSettings: ServerIncomingPlayerSettings}
function ClientMessages.sanitizeMenuState(playerSettings)
  local sanitized = {}

  sanitized.character = playerSettings.character
  sanitized.character_is_random = playerSettings.character_is_random
  sanitized.cursor = playerSettings.cursor -- nil when from login
  sanitized.inputMethod = (playerSettings.inputMethod or "controller") --one day we will require message to include input method, but it is not this day.
  sanitized.level = playerSettings.level
  sanitized.panels_dir = playerSettings.panels_dir
  sanitized.ready = playerSettings.ready -- nil when from login
  sanitized.stage = playerSettings.stage
  sanitized.stage_is_random = playerSettings.stage_is_random
  sanitized.wants_ranked_match = playerSettings.ranked
  sanitized.loaded = playerSettings.loaded
  sanitized.wants_ready = playerSettings.wants_ready
  if playerSettings.levelData and LevelData.validate(playerSettings.levelData) then
    sanitized.levelData = playerSettings.levelData
    setmetatable(sanitized.levelData, LevelData)
  end

  return {playerSettings = sanitized}
end

---@class ServerIncomingLoginMessage
---@field playerSettings ServerIncomingPlayerSettings
---@field login_request boolean
---@field user_id privateUserId
---@field engine_version string
---@field name string
---@field save_replays_publicly ("not at all" | "anonymously" | "with my name")

---@return ServerIncomingLoginMessage
function ClientMessages.sanitizeLoginRequest(loginRequest)
  ---@type ServerIncomingLoginMessage
  local sanitized = ClientMessages.sanitizeMenuState(loginRequest)
  sanitized.login_request = true
  sanitized.user_id = loginRequest.user_id
  sanitized.engine_version = loginRequest.engine_version
  sanitized.name = loginRequest.name
  sanitized.save_replays_publicly = loginRequest.save_replays_publicly

  return sanitized
end

function ClientMessages.sanitizeChallengeUpdate(message)
  local sanitized =
  {
    challengeUpdate =
    {
      senderId = message.challengeUpdate.senderId,
      receiverId = message.challengeUpdate.receiverId,
      gameModeId = message.challengeUpdate.gameModeId,
      challengeActive = message.challengeUpdate.challengeActive,
      roomNumber = message.challengeUpdate.roomNumber,
      slotNumber = message.challengeUpdate.slotNumber,
    }
  }

  return sanitized
end

-- Client-nominated crash flag. Trim everything hostile or oversized at the
-- door so the routing/storage code can trust its inputs. See
-- docs/CRASH_REPLAY_PLAN.md "Wire shape — flagGame" for the contract.
local MAX_TRACE_FRAGMENT = 1024
local MAX_TRACE_HASH     = 64
local MAX_REASON         = 32

local function _truncString(v, cap)
  if type(v) ~= "string" then return nil end
  if #v > cap then return v:sub(1, cap) end
  return v
end

function ClientMessages.sanitizeFlagGame(clientMessage)
  local raw = clientMessage.flagGame
  if type(raw) ~= "table" then return { flagGame = nil } end

  local gk
  if type(raw.gameKey) == "table" then
    gk = {
      roomNumber = tonumber(raw.gameKey.roomNumber),
      gameId     = tonumber(raw.gameKey.gameId),
      startTs    = tonumber(raw.gameKey.startTs),
    }
  end

  local clientMeta
  if type(raw.clientMeta) == "table" then
    clientMeta = {
      engineVersion = _truncString(raw.clientMeta.engineVersion, 16),
      os            = _truncString(raw.clientMeta.os,            32),
      loveVersion   = _truncString(raw.clientMeta.loveVersion,   16),
      branch        = _truncString(raw.clientMeta.branch,        64),
    }
  end

  return {
    flagGame = {
      gameKey       = gk,
      reason        = _truncString(raw.reason,        MAX_REASON),
      traceHash     = _truncString(raw.traceHash,     MAX_TRACE_HASH),
      traceFragment = _truncString(raw.traceFragment, MAX_TRACE_FRAGMENT),
      clientMeta    = clientMeta,
      schemaVer     = tonumber(raw.schemaVer) or 1,
    },
  }
end

-- Phase 2 of the two-phase spool: client returns its slice (full replay
-- payload) in response to the server's earlier crashSliceRequest. The
-- 2 MB byte cap is enforced downstream in CrashReports:recordSlice
-- (which encodes once and bounds the result); this sanitize just
-- type-checks the wrapping fields. The `replay` blob is passed through
-- as-is — replays are big and validating each replay-internal field
-- here would duplicate the work Match.createFromReplay already does
-- when the fixture is loaded for testing.
function ClientMessages.sanitizeCrashSlice(clientMessage)
  local raw = clientMessage.crashSlice
  if type(raw) ~= "table" then return { crashSlice = nil } end

  local gameContext
  if type(raw.gameContext) == "table" then
    gameContext = {
      roomNumber   = tonumber(raw.gameContext.roomNumber),
      gameId       = tonumber(raw.gameContext.gameId),
      frame        = tonumber(raw.gameContext.frame),
      gameModeName = _truncString(raw.gameContext.gameModeName, 64),
      matchCount   = tonumber(raw.gameContext.matchCount),
    }
  end

  local clientMeta
  if type(raw.clientMeta) == "table" then
    clientMeta = {
      engineVersion = _truncString(raw.clientMeta.engineVersion, 16),
      os            = _truncString(raw.clientMeta.os,            32),
      loveVersion   = _truncString(raw.clientMeta.loveVersion,   16),
      branch        = _truncString(raw.clientMeta.branch,        64),
    }
  end

  -- logTail is an array of strings; cap each line and the array length
  -- so a hostile client can't slip megabytes of "log" past the wire.
  local logTail
  if type(raw.logTail) == "table" then
    logTail = {}
    for i = 1, math.min(#raw.logTail, 200) do
      logTail[i] = _truncString(raw.logTail[i], 1024)
    end
  end

  return {
    crashSlice = {
      incidentId    = _truncString(raw.incidentId, 64),
      error         = _truncString(raw.error,      MAX_TRACE_FRAGMENT),
      trace         = _truncString(raw.trace,      MAX_TRACE_FRAGMENT * 4),
      traceHash     = _truncString(raw.traceHash,  MAX_TRACE_HASH),
      clientMeta    = clientMeta,
      gameContext   = gameContext,
      replay        = type(raw.replay) == "table" and raw.replay or nil,
      logTail       = logTail,
      schemaVer     = tonumber(raw.schemaVer) or 1,
    },
  }
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
    leaderboard_request = leaderboardRequest.leaderboard_request,
    -- default value only for slow adaption, remove and sanity check later
    gameModeId = leaderboardRequest.leaderboardType or GameModes.IDs.TWO_PLAYER_VS,
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

function ClientMessages.sanitizeStackEliminated(message)
  return {
    stackEliminated = message.stackEliminated,
    frame = tonumber(message.frame),
  }
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

function ClientMessages.sanitizeRoomRequest(roomRequest)
  local gameMode = nil
  local latencyTolerance = nil

  -- Preferred format from ClientProtocol.sendRoomRequest
  if roomRequest.content then
    gameMode = roomRequest.content.gameMode
      or roomRequest.content.gameModeId
      or roomRequest.content.gameModeName
      or roomRequest.content.mode
  end

  -- Legacy/fallback formats
  if not gameMode then
    gameMode = roomRequest.gameMode
      or roomRequest.gameModeId
      or roomRequest.gameModeName
      or roomRequest.mode
  end

  -- Some older callers may place the serialized game mode directly in content.
  if not gameMode and roomRequest.content and roomRequest.content.name then
    gameMode = roomRequest.content
  end

  if roomRequest.content then
    latencyTolerance = roomRequest.content.latencyTolerance
  end

  if not latencyTolerance then
    latencyTolerance = roomRequest.latencyTolerance
  end

  -- Optional client-supplied PRNG seed for the panel sequence. Honored only
  -- if it's an integer in the same range Game.lua picks from when generating
  -- a random one — keeps reproducible-scenario tests from drifting between
  -- runs without disturbing normal multiplayer (production clients never
  -- set this).
  local seed
  if roomRequest.content then seed = roomRequest.content.seed end
  if seed == nil then seed = roomRequest.seed end
  if type(seed) ~= "number" or seed ~= math.floor(seed) or seed < 1 or seed > 9999999 then
    seed = nil
  end

  return {
    roomRequest = true,
    gameMode = gameMode,
    latencyTolerance = latencyTolerance,
    seed = seed,
  }
end

function ClientMessages.sanitizeJoinRoomRequest(joinRoomRequest)
  local request = joinRoomRequest.joinRoomRequest or {}
  return {
    joinRoomRequest = {
      roomNumber = request.roomNumber,
      slotNumber = request.slotNumber,
    }
  }
end

function ClientMessages.sanitizeMatchAbort(matchAbort)
  local sanitized =
  {
    roomNumber = matchAbort.recipientId,
    matchAbort = true
  }

  return sanitized
end

function ClientMessages.sanitizePauseToggle(pauseToggle)
  local sanitized =
  {
    roomNumber = pauseToggle.recipientId,
    paused = pauseToggle.content,
    type = "pauseToggle",
  }

  return sanitized
end

return ClientMessages