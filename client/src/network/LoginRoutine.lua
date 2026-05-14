local class = require("common.lib.class")
local ClientMessages = require("common.network.ClientProtocol")
local save = require("client.src.save")
local TraceWriter = require("client.src.network.TraceWriter")
local logger = require("common.lib.logger")

-- abstraction level function
-- returns things as a parameter list so the API in ClientProtocol can be more explicit about which parameters it expects
--  (which it cannot if things are passed as tables)
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

-- Run version-check + login for a single tcp client. Returns a table:
--   { loggedIn = bool, message = string, new_user_id = ?, publicId = ?, serverTime = ?,
--     name_changed = bool, old_name = ?, new_name = ?, server_notice = ? }
-- Used twice by the dual-socket flow: once for gameplay, once for lobby.
local function loginOnClient(client, ip, port, userId)
  local result = {loggedIn = false, message = ""}

  if not client:connectToServer(ip, port) then
    result.loggedIn = false
    result.message = loc("ss_could_not_connect")
    return result
  end

  local response = client:sendRequest(ClientMessages.requestVersionCompatibilityCheck())
  local status, value = response:tryGetValue()
  while status == "waiting" do
    coroutine.yield("Checking version compatibility with the server")
    status, value = response:tryGetValue()
  end

  if status == "timeout" then
    result.loggedIn = false
    result.message = loc("nt_conn_timeout")
    return result
  elseif status ~= "received" then
    error("Unexpected status " .. tostring(status) .. " on version check to " .. ip)
  end

  if not value.versionCompatible then
    result.loggedIn = false
    result.message = loc("nt_ver_err")
    return result
  end

  response = client:sendRequest(ClientMessages.requestLogin(userId, toLoginData(config, GAME.localPlayer)))
  status, value = response:tryGetValue()
  while status == "waiting" do
    coroutine.yield("Logging in")
    status, value = response:tryGetValue()
  end

  if status == "timeout" then
    result.loggedIn = false
    result.message = loc("nt_conn_timeout")
    return result
  elseif status ~= "received" then
    error("Unexpected status " .. tostring(status) .. " on login to " .. ip)
  end

  if not value.login_successful then
    result.loggedIn = false
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

-- Triple-socket login: gameplay first (creates the Player server-side),
-- then lobby and spectate use the same user_id so the server attaches both
-- to the same Player via privateUserId. Lobby and spectate failures are
-- non-fatal — fallbacks in Player keep the session playable.
local function login(gameplayClient, ip, gameplayPort, lobbyClient, lobbyPort, spectateClient, spectatePort)
  GAME.connected_server_ip = ip
  GAME.connected_server_port = gameplayPort

  local storedUserId = save.read_user_id_file(ip) or "need a new user id"

  local gameplayResult = loginOnClient(gameplayClient, ip, gameplayPort, storedUserId)
  if not gameplayResult.loggedIn then
    return gameplayResult
  end

  -- After the first successful login, the server may have issued a new user
  -- id. Persist it and use it for the lobby/spectate logins so the server
  -- can match all sockets to the same Player.
  local effectiveUserId = storedUserId
  if gameplayResult.new_user_id then
    save.write_user_id_file(gameplayResult.new_user_id, ip)
    effectiveUserId = gameplayResult.new_user_id
  end

  local lobbyResult = loginOnClient(lobbyClient, ip, lobbyPort, effectiveUserId)
  if not lobbyResult.loggedIn then
    logger.warn("Lobby socket login failed (" .. tostring(lobbyResult.message)
      .. "). Continuing without lobby HoL protection — JSON falls back to gameplay.")
    lobbyClient:resetNetwork()
  end

  if spectateClient then
    local spectateResult = loginOnClient(spectateClient, ip, spectatePort, effectiveUserId)
    if not spectateResult.loggedIn then
      logger.warn("Spectate socket login failed (" .. tostring(spectateResult.message)
        .. "). Continuing without spectate isolation — opponent traffic falls back to gameplay.")
      spectateClient:resetNetwork()
    end
  end

  -- Assemble the user-facing message from the gameplay result (the lobby
  -- login is server-side bookkeeping that doesn't have new messages to convey).
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

  pcall(function() TraceWriter.beginSession(os.time()) end)

  return {
    loggedIn = true,
    message = message,
    serverTime = gameplayResult.serverTime,
  }
end

-- A wrapper class around the login process
-- Allows to advance the login process bit by bit via calling progress
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

-- returns false and the current progress of the login process as a string message while in progress
-- returns true and a result table {loggedIn = val, message = "msg"} when finishing and on further queries
function LoginRoutine:progress()
  if coroutine.status(self.routine) == "dead" then
    return true, self.result
  else
    local success, status = coroutine.resume(
      self.routine,
      self.gameplayClient, self.ip, self.gameplayPort,
      self.lobbyClient, self.lobbyPort,
      self.spectateClient, self.spectatePort)
    if success then
      if type(status) == "table" then
        self.result = status
        if self.result.loggedIn == false then
          self.gameplayClient:resetNetwork()
          if self.lobbyClient then self.lobbyClient:resetNetwork() end
          if self.spectateClient then self.spectateClient:resetNetwork() end
        end
        return true, status
      else
        self.status = status
        return false, status
      end
    else
      GAME.crashTrace = debug.traceback(self.routine)
      error(status)
    end
  end
end


return LoginRoutine
