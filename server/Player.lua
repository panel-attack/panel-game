--local logger = require("common.lib.logger")
local class = require("common.lib.class")
local ServerProtocol = require("common.network.ServerProtocol")
local LevelPresets = require("common.data.LevelPresets")
local tableUtils = require("common.lib.tableUtils")
local Signal = require("common.lib.signal")
local logger = require("common.lib.logger")
local TraceWriter = require("server.TraceWriter")

---@alias PlayerState ("lobby" | "character select" | "playing" | "spectating" | "paused")
---@alias PublicPlayerID integer

---@class ServerPlayer : Signal
---@field package connection Connection backward-compat alias for gameplayConnection (legacy callers / tests)
---@field package gameplayConnection Connection? socket carrying I/G/D/K/E/H — required; loss = full disconnect
---@field package lobbyConnection Connection? socket carrying J — optional during rollout; loss = silent reconnect
---@field userId privateUserId
---@field publicPlayerID PublicPlayerID
---@field character string id of the specific character that was picked
---@field character_is_random string? id of the character (bundle) that was selected; will match character if not a bundle
---@field stage string id of the specific stage that was picked
---@field stage_is_random string? id of the stage (bundle) that was selected; will match stage if not a bundle
---@field panels_dir string id of the specific panel set that was selected
---@field wants_ranked_match boolean
---@field inputMethod InputMethod
---@field level integer display property for the level
---@field levelData LevelData
---@field wantsReady boolean
---@field loaded boolean
---@field ready boolean
---@field cursor string?
---@field save_replays_publicly ("not at all" | "anonymously" | "with my name")
---@field name string
---@field player_number integer?
---@field state PlayerState
---@overload fun(privatePlayerID: privateUserId, connection: Connection, name: string, publicId: integer): ServerPlayer
local Player = class(
---@param self ServerPlayer
---@param privatePlayerID privateUserId
---@param connection Connection
---@param name string
---@param publicId integer
function(self, privatePlayerID, connection, name, publicId)
  connection.loggedIn = true
  self.userId = privatePlayerID
  -- Bind the incoming connection to the appropriate channel slot. The
  -- second socket (other channel) attaches later via Player:attachConnection.
  local channel = connection.channel or "gameplay"
  if channel == "lobby" then
    self.lobbyConnection = connection
  else
    self.gameplayConnection = connection
  end
  -- Backward-compat alias: legacy code (server.lua TCP_NODELAY tweaks,
  -- tests reading outgoingMessageQueue) reaches in via player.connection.
  -- Point it at gameplayConnection when available; otherwise lobby.
  self.connection = self.gameplayConnection or self.lobbyConnection
  self.name = name or "noname"
  self.publicPlayerID = publicId

  -- Player Settings
  self.character = nil
  self.character_is_random = nil
  self.cursor = nil
  self.inputMethod = "controller"
  self.level = nil
  self.panels_dir = nil
  self.wantsReady = nil
  self.loaded = nil
  self.ready = nil
  self.stage = nil
  self.stage_is_random = nil
  self.wants_ranked_match = false
  self.levelData = nil

  Signal.turnIntoEmitter(self)
  self:createSignal("settingsUpdated")
end)

function Player:getSettings()
  return ServerProtocol.toSettings(
    self.ready,
    self.level,
    self.inputMethod,
    self.stage,
    self.stage_is_random,
    self.character,
    self.character_is_random,
    self.panels_dir,
    self.wants_ranked_match,
    self.wantsReady,
    self.loaded,
    self.levelData or LevelPresets.getModern(self.level)
  )
end

---@param settings ServerIncomingPlayerSettings
function Player:updateSettings(settings)
  if settings.character ~= nil then
    self.character = settings.character
  end

  if settings.character_is_random ~= nil then
    self.character_is_random = settings.character_is_random
  end
  -- self.cursor = playerSettings.cursor -- nil when from login
  if settings.inputMethod ~= nil then
    self.inputMethod = (settings.inputMethod or "controller")
  end

  if settings.level ~= nil then
    self.level = settings.level
  end

  if settings.panels_dir ~= nil then
    self.panels_dir = settings.panels_dir
  end

  if settings.ready ~= nil then
    self.ready = settings.ready -- nil when from login
  end

  if settings.stage ~= nil then
    self.stage = settings.stage
  end

  if settings.stage_is_random ~= nil then
    self.stage_is_random = settings.stage_is_random
  end

  if settings.ranked ~= nil then
    self.wants_ranked_match = settings.ranked
  end

  if settings.wants_ready ~= nil then
    self.wantsReady = settings.wants_ready
  end

  if settings.loaded ~= nil then
    self.loaded = settings.loaded
  end

  if settings.levelData ~= nil then
    self.levelData = settings.levelData
  end

  self:emitSignal("settingsUpdated", self)
end

function Player:addToRoom(room)
  if self.room then
    logger.info("Switching player " .. self.name .. " from room " .. self.room.roomNumber .. " to room " .. room.roomNumber)
  else
    logger.info("Setting room to " .. room.roomNumber .. " for player " .. self.name)
  end

  self.room = room
  self.wantsReady = false
  self.ready = false
  -- Apply game-mode timeouts to both sockets so neither prematurely closes.
  local timeoutSeconds = room.gameMode and room.gameMode.connectionTimeoutSeconds
  local sendRetryLimit = room.gameMode and room.gameMode.sendRetryLimit
  for _, conn in ipairs({self.gameplayConnection, self.lobbyConnection}) do
    if conn then
      if timeoutSeconds then conn.timeoutSeconds = timeoutSeconds end
      if sendRetryLimit then conn.sendRetryLimit = sendRetryLimit end
    end
  end
end

function Player:removeFromRoom(room, reason)
  -- Idempotent: cascading disconnects (mid-match all-leave) call this twice for
  -- the same player — once via handleLeaveRoom, once via Room:close iterating
  -- slots. The second call has nothing to clean up; logging it as an error
  -- caused the E2E harness to flag healthy teardowns as failures.
  if not self.room then
    return
  end

  logger.info("Clearing room " .. room.roomNumber .. " for player " .. self.name)
  -- Liveness is checked via the gameplay socket — that's the one whose loss
  -- triggers full disconnect. Lobby loss alone shouldn't reset room state.
  local gameplayLive = self.gameplayConnection and self.gameplayConnection.socket
  if gameplayLive then
    self.state = "lobby"
    self.player_number = nil
    self:sendJson(ServerProtocol.leaveRoom(room.roomNumber, reason))
  end

  self.room = nil
  self.wantsReady = false
  self.ready = false
  -- Restore default per-connection timeouts on both sockets.
  for _, conn in ipairs({self.gameplayConnection, self.lobbyConnection}) do
    if conn then
      conn.timeoutSeconds = nil
      conn.sendRetryLimit = 5
    end
  end
end

-- Attach the second-channel connection after the first one logged in.
-- Called by the login flow when the OTHER socket authenticates as the same
-- player (matched by privateUserId).
function Player:attachConnection(connection)
  connection.loggedIn = true
  local channel = connection.channel or "gameplay"
  if channel == "lobby" then
    self.lobbyConnection = connection
  else
    self.gameplayConnection = connection
  end
  self.connection = self.gameplayConnection or self.lobbyConnection
end

-- Pick the destination connection for an outbound JSON message: lobby if
-- present, otherwise fall back to gameplay so old single-socket clients
-- still receive JSON during rollout. Returns nil if neither is usable.
local function _jsonConnection(self)
  local lc = self.lobbyConnection
  if lc and lc.socket then return lc end
  local gc = self.gameplayConnection
  if gc and gc.socket then return gc end
  return nil
end

-- Pick the destination connection for a raw prefixed message. J → lobby,
-- everything else → gameplay, with cross-channel fallback during rollout.
local function _rawConnection(self, message)
  local prefix = type(message) == "string" and #message > 0 and message:sub(1, 1)
  if prefix == "J" then
    return _jsonConnection(self)
  end
  local gc = self.gameplayConnection
  if gc and gc.socket then return gc end
  -- Last-resort fallback so gameplay messages don't silently disappear
  -- if the gameplay channel hasn't connected (shouldn't happen in steady
  -- state, but possible during the brief window before both sockets are up).
  local lc = self.lobbyConnection
  if lc and lc.socket then return lc end
  return nil
end

function Player:sendJson(message)
  local conn = _jsonConnection(self)
  if not conn then
    return
  end
  conn:sendJson(message)
  pcall(function()
    if self.publicPlayerID then
      TraceWriter.send(self.publicPlayerID, "J", message and message.messageText)
    end
  end)
end

function Player:send(message)
  local conn = _rawConnection(self, message)
  if not conn then
    return
  end
  conn:send(message)
  pcall(function()
    if self.publicPlayerID and type(message) == "string" and #message > 0 then
      TraceWriter.send(self.publicPlayerID, message:sub(1, 1), message)
    end
  end)
end

---@return boolean
function Player:isReady()
  return self.wantsReady and self.loaded and self.ready
end

function Player:setup_game()
  if self.state ~= "spectating" then
    self.state = "playing"
  end
end

---@return boolean
function Player:usesModifiedLevelData()
  if self.levelData == nil then
    return false
  else
    return not tableUtils.deep_content_equal(self.levelData, LevelPresets.getModern(self.level))
  end
end

---@param state PlayerState
function Player:setState(state)
  self.state = state
end

return Player
