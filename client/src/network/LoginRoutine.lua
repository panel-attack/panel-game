local class = require("common.lib.class")
local ClientMessages = require("common.network.ClientProtocol")
local save = require("client.src.save")
local TraceWriter = require("client.src.network.TraceWriter")
local logger = require("common.lib.logger")

-- Pull the chunk of player settings that ride along on a fresh login.
local function toLoginData(configuration, localPlayer)
  local ps = localPlayer.settings
  local c = configuration
  return
    c.name,
    ps.level,
    ps.inputMethod,
    ps.panels,
    ps.selectedCharacterId,
    ps.characterId,
    ps.selectedStageId,
    ps.stageId,
    ps.wantsRanked,
    c.save_replays_publicly
end

-- Wait for a coroutine-driven sendRequest to resolve. Yields the status
-- string while waiting so the caller can drive progress to the UI.
local function awaitResponse(response, waitingMessage)
  local status, value = response:tryGetValue()
  while status == "waiting" do
    coroutine.yield(waitingMessage)
    status, value = response:tryGetValue()
  end
  return status, value
end

-- Full login: version check + full login_request with all player settings.
-- Used once, on the gameplay socket. Returns the full result table.
local function fullLogin(client, ip, port, userId)
  local result = {loggedIn = false, message = ""}

  if not client:connectToServer(ip, port) then
    result.message = loc("ss_could_not_connect")
    return result
  end

  local status, value = awaitResponse(
    client:sendRequest(ClientMessages.requestVersionCompatibilityCheck()),
    "Checking version compatibility with the server")

  if status == "timeout" then
    result.message = loc("nt_conn_timeout")
    return result
  elseif status ~= "received" then
    error("Unexpected status " .. tostring(status) .. " on version check to " .. ip)
  end

  if not value.versionCompatible then
    result.message = loc("nt_ver_err")
    return result
  end

  status, value = awaitResponse(
    client:sendRequest(ClientMessages.requestLogin(userId, toLoginData(config, GAME.localPlayer))),
    "Logging in")

  if status == "timeout" then
    result.message = loc("nt_conn_timeout")
    return result
  elseif status ~= "received" then
    error("Unexpected status " .. tostring(status) .. " on login to " .. ip)
  end

  if not value.login_successful then
    result.message = loc("lb_error_msg") .. "\n" .. (value.reason or "")
    if value.ban_duration then
      result.message = result.message .. "\n" .. value.ban_duration
    end
    return result
  end

  result.loggedIn = true
  result.new_user_id = value.new_user_id
  result.publicId = value.publicId
  result.serverTime = value.serverTime
  result.name_changed = value.name_changed
  result.old_name = value.old_name
  result.new_name = value.new_name
  result.server_notice = value.server_notice
  return result
end

-- Session claim: skip version check, send minimal login_request. The server
-- recognizes the user_id as already logged in via the gameplay socket and
-- attaches this connection to the existing Player.
local function claimSession(client, ip, port, userId, name)
  local result = {loggedIn = false, message = ""}

  if not client:connectToServer(ip, port) then
    result.message = loc("ss_could_not_connect")
    return result
  end

  local status, value = awaitResponse(
    client:sendRequest(ClientMessages.requestSessionClaim(userId, name)),
    "Attaching side-channel socket")

  if status == "timeout" then
    result.message = loc("nt_conn_timeout")
    return result
  elseif status ~= "received" then
    error("Unexpected status " .. tostring(status) .. " on session claim to " .. ip)
  end

  if not value.login_successful then
    result.message = (value.reason or "session claim denied")
    return result
  end

  result.loggedIn = true
  return result
end

-- Drive multiple coroutines per tick until they all finish. Each routine's
-- terminal return value lands in entry.result.
local function runInParallel(routines)
  while true do
    local anyAlive = false
    for _, entry in pairs(routines) do
      if coroutine.status(entry.co) ~= "dead" then
        anyAlive = true
        local ok, ret = coroutine.resume(entry.co)
        if not ok then
          error(ret)
        end
        if coroutine.status(entry.co) == "dead" then
          entry.result = ret
        end
      end
    end
    if not anyAlive then return end
    coroutine.yield("Attaching side channels")
  end
end

-- Full login on gameplay (one real handshake). Then lobby and spectate
-- attach in parallel via the lightweight session-claim path.
local function login(gameplayClient, ip, gameplayPort, lobbyClient, lobbyPort, spectateClient, spectatePort)
  GAME.connected_server_ip = ip
  GAME.connected_server_port = gameplayPort

  local storedUserId = save.read_user_id_file(ip) or "need a new user id"
  local gameplayResult = fullLogin(gameplayClient, ip, gameplayPort, storedUserId)
  if not gameplayResult.loggedIn then
    return gameplayResult
  end

  -- If the server issued a new user_id, persist it and use it for the
  -- session-claim handshakes so they match the right Player.
  local effectiveUserId = storedUserId
  if gameplayResult.new_user_id then
    save.write_user_id_file(gameplayResult.new_user_id, ip)
    effectiveUserId = gameplayResult.new_user_id
  end

  local routines = {
    lobby = { co = coroutine.create(function()
      return claimSession(lobbyClient, ip, lobbyPort, effectiveUserId, config.name)
    end)},
  }
  if spectateClient then
    routines.spectate = { co = coroutine.create(function()
      return claimSession(spectateClient, ip, spectatePort, effectiveUserId, config.name)
    end)}
  end
  runInParallel(routines)

  if not routines.lobby.result or not routines.lobby.result.loggedIn then
    logger.warn("Lobby socket session-claim failed ("
      .. tostring(routines.lobby.result and routines.lobby.result.message or "no result")
      .. "). Continuing without lobby HoL protection — JSON falls back to gameplay.")
    lobbyClient:resetNetwork()
  end
  if spectateClient then
    if not routines.spectate.result or not routines.spectate.result.loggedIn then
      logger.warn("Spectate socket session-claim failed ("
        .. tostring(routines.spectate.result and routines.spectate.result.message or "no result")
        .. "). Continuing without spectate isolation — opponent traffic falls back to gameplay.")
      spectateClient:resetNetwork()
    end
  end

  -- Assemble the user-facing message from the gameplay login (the side
  -- sockets are bookkeeping and have nothing new to say).
  local message
  if gameplayResult.new_user_id then
    message = loc("lb_user_new", config.name)
  elseif gameplayResult.name_changed then
    message = loc("lb_user_update", gameplayResult.old_name, gameplayResult.new_name)
  else
    message = loc("lb_welcome_back", config.name)
  end
  if gameplayResult.server_notice then
    message = message .. "\n" .. gameplayResult.server_notice:gsub("\\n", "\n")
  end

  if gameplayResult.publicId then
    GAME.localPlayer.publicId = gameplayResult.publicId
  end

  TraceWriter.beginSession(os.time())

  return {
    loggedIn = true,
    message = message,
    serverTime = gameplayResult.serverTime,
  }
end

-- Coroutine wrapper. Advance via progress() each frame.
local LoginRoutine = class(function(self, gameplayClient, ip, gameplayPort, lobbyClient, lobbyPort, spectateClient, spectatePort)
  self.gameplayClient = gameplayClient
  self.lobbyClient = lobbyClient
  self.spectateClient = spectateClient
  self.routine = coroutine.create(login)
  self.ip = ip
  self.gameplayPort = gameplayPort
  self.lobbyPort = lobbyPort or ((gameplayPort or 49569) + 1)
  self.spectatePort = spectatePort or ((gameplayPort or 49569) + 2)
end)

-- false + progress string while in flight, true + result table when done.
function LoginRoutine:progress()
  if coroutine.status(self.routine) == "dead" then
    return true, self.result
  end
  local success, status = coroutine.resume(
    self.routine,
    self.gameplayClient, self.ip, self.gameplayPort,
    self.lobbyClient, self.lobbyPort,
    self.spectateClient, self.spectatePort)
  if not success then
    GAME.crashTrace = debug.traceback(self.routine)
    error(status)
  end
  if type(status) == "table" then
    self.result = status
    if self.result.loggedIn == false then
      self.gameplayClient:resetNetwork()
      if self.lobbyClient then self.lobbyClient:resetNetwork() end
      if self.spectateClient then self.spectateClient:resetNetwork() end
    end
    return true, status
  end
  self.status = status
  return false, status
end

return LoginRoutine
