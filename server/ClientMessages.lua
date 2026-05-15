-- Server-side wire-message parsers.
--
-- Contract (load-bearing — see docs/TRACE_REPLAY_SHAPE_FIX_PLAN.md Phase 3):
--   parse*(wireMessage) returns a table whose top-level keys are a subset
--   (or copy) of wireMessage's top-level keys. Renaming keys is FORBIDDEN.
--   Adding internal dispatch flags (e.g. `roomRequest = true`, `matchAbort
--   = true`) is allowed. Pulling nested fields out of `content` is allowed
--   for legacy `recipient=room` envelopes (roomRequest/matchAbort/
--   pauseToggle) where the dispatcher routes by `type`. Wrapping/nesting
--   top-level keys is FORBIDDEN.
--
-- Why: server-side trace capture records the wire bytes BEFORE this layer
-- runs (see server.lua Server:processMessage). Re-emitting the trace must
-- route through the same dispatcher, so the parsed shape must be
-- structurally compatible with — not a rename of — the wire shape.
--
-- The pre-2026-05 history of this file used "sanitize*" naming and freely
-- reshaped its inputs; the rename to "parse*" is intentional — the new
-- name does not license arbitrary reshaping.

local logger = require("common.lib.logger")
local LevelData = require("common.data.LevelData")
local GameModes = require("common.data.GameModes")

local ClientMessages = {}

function ClientMessages.parseMessage(clientMessage)
  if clientMessage.login_request then
    return ClientMessages.parseLoginRequest(clientMessage)
  elseif clientMessage.challengeUpdate then
    return ClientMessages.parseChallengeUpdate(clientMessage)
  elseif clientMessage.menu_state then
    return ClientMessages.parseMenuState(clientMessage)
  elseif clientMessage.spectate_request then
    return ClientMessages.parseSpectateRequest(clientMessage)
  elseif clientMessage.leaderboard_request then
    return ClientMessages.parseLeaderboardRequest(clientMessage)
  elseif clientMessage.leave_room then
    return ClientMessages.parseLeaveRoom(clientMessage)
  elseif clientMessage.taunt then
    return ClientMessages.parseTaunt(clientMessage)
  elseif clientMessage.game_over then
    return ClientMessages.parseGameResult(clientMessage)
  elseif clientMessage.joinRoomRequest then
    return ClientMessages.parseJoinRoomRequest(clientMessage)
  elseif clientMessage.logout then
    return clientMessage
  elseif clientMessage.type and clientMessage.type == "roomRequest" then
    return ClientMessages.parseRoomRequest(clientMessage)
  elseif clientMessage.type and clientMessage.type == "matchAbort" then
    return ClientMessages.parseMatchAbort(clientMessage)
  elseif clientMessage.type and clientMessage.type == "pauseToggle" then
    return ClientMessages.parsePauseToggle(clientMessage)
  elseif clientMessage.error_report then
    return clientMessage
  elseif clientMessage.flagGame then
    return ClientMessages.parseFlagGame(clientMessage)
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

local function parsePlayerSettingsFields(settings)
  local out = {}
  out.character = settings.character
  out.character_is_random = settings.character_is_random
  out.cursor = settings.cursor
  out.inputMethod = (settings.inputMethod or "controller")
  out.level = settings.level
  out.panels_dir = settings.panels_dir
  out.ready = settings.ready
  out.stage = settings.stage
  out.stage_is_random = settings.stage_is_random
  out.ranked = settings.ranked
  out.loaded = settings.loaded
  out.wants_ready = settings.wants_ready
  out.endless_no_raise = settings.endless_no_raise == true
  if settings.levelData and LevelData.validate(settings.levelData) then
    out.levelData = settings.levelData
    setmetatable(out.levelData, LevelData)
  end
  return out
end

---@return {menu_state: ServerIncomingPlayerSettings}
function ClientMessages.parseMenuState(clientMessage)
  return { menu_state = parsePlayerSettingsFields(clientMessage.menu_state) }
end

---@class ServerIncomingLoginMessage : ServerIncomingPlayerSettings
---@field login_request boolean
---@field user_id privateUserId
---@field engine_version string
---@field name string
---@field save_replays_publicly ("not at all" | "anonymously" | "with my name")

---@return ServerIncomingLoginMessage
function ClientMessages.parseLoginRequest(loginRequest)
  local sanitized = parsePlayerSettingsFields(loginRequest)
  sanitized.login_request = true
  sanitized.user_id = loginRequest.user_id
  sanitized.engine_version = loginRequest.engine_version
  sanitized.name = loginRequest.name
  sanitized.save_replays_publicly = loginRequest.save_replays_publicly

  return sanitized
end

function ClientMessages.parseChallengeUpdate(message)
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

function ClientMessages.parseFlagGame(clientMessage)
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

function ClientMessages.parseSpectateRequest(spectateRequest)
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

function ClientMessages.parseLeaderboardRequest(leaderboardRequest)
  local sanitized =
  {
    leaderboard_request = leaderboardRequest.leaderboard_request,
    leaderboardType = leaderboardRequest.leaderboardType or GameModes.IDs.TWO_PLAYER_VS,
  }

  return sanitized
end

function ClientMessages.parseLeaveRoom(leaveRoom)
  local sanitized =
  {
    leave_room = leaveRoom.leave_room
  }

  return sanitized
end

function ClientMessages.parseGameResult(gameResult)
  local sanitized =
  {
    game_over = gameResult.game_over,
    outcome = gameResult.outcome
  }

  return sanitized
end

function ClientMessages.parseTaunt(taunt)
  local sanitized =
  {
    taunt = taunt.taunt,
    type = taunt.type,
    index = taunt.index
  }

  return sanitized
end

function ClientMessages.parseRoomRequest(roomRequest)
  local gameMode = nil
  local latencyTolerance = nil

  if roomRequest.content then
    gameMode = roomRequest.content.gameMode
      or roomRequest.content.gameModeId
      or roomRequest.content.gameModeName
      or roomRequest.content.mode
  end

  if roomRequest.content then
    latencyTolerance = roomRequest.content.latencyTolerance
  end

  -- Optional client-supplied PRNG seed for the panel sequence. Honored only
  -- if it's an integer in the same range Game.lua picks from when generating
  -- a random one — keeps reproducible-scenario tests from drifting between
  -- runs without disturbing normal multiplayer (production clients never
  -- set this).
  local seed
  if roomRequest.content then seed = roomRequest.content.seed end
  if type(seed) ~= "number" or seed ~= math.floor(seed) or seed < 1 or seed > 9999999 then
    seed = nil
  end

  local openRoom = false
  if roomRequest.content and roomRequest.content.openRoom == true then
    openRoom = true
  end

  return {
    roomRequest = true,
    gameMode = gameMode,
    latencyTolerance = latencyTolerance,
    seed = seed,
    openRoom = openRoom,
  }
end

function ClientMessages.parseJoinRoomRequest(joinRoomRequest)
  local request = joinRoomRequest.joinRoomRequest or {}
  return {
    joinRoomRequest = {
      roomNumber = request.roomNumber,
      slotNumber = request.slotNumber,
    }
  }
end

function ClientMessages.parseMatchAbort(matchAbort)
  return {
    type = "matchAbort",
    recipientId = matchAbort.recipientId,
    matchAbort = true,
  }
end

function ClientMessages.parsePauseToggle(pauseToggle)
  return {
    type = "pauseToggle",
    recipientId = pauseToggle.recipientId,
    content = pauseToggle.content,
  }
end

return ClientMessages
