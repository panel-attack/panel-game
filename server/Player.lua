--local logger = require("common.lib.logger")
local class = require("common.lib.class")
local ServerProtocol = require("common.network.ServerProtocol")
local LevelPresets = require("common.data.LevelPresets")
local Signal = require("common.lib.signal")
local logger = require("common.lib.logger")

---@alias PlayerState ("lobby" | "character select" | "playing" | "spectating")

---@class ServerPlayer : Signal
---@field package connection Connection ONLY FOR SENDING; accessing this in tests is fine, otherwise not, all message processing has to go through server
---@field userId privateUserId
---@field publicPlayerID integer
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
---@field opponent ServerPlayer to be removed
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
  self.connection = connection
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

  if settings.wants_ranked_match ~= nil then
    self.wants_ranked_match = settings.wants_ranked_match
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
end

function Player:removeFromRoom(room, reason)
  if self.room then
    logger.info("Clearing room " .. room.roomNumber .. " for player " .. self.name)
    -- if there is no socket the room got closed because the player hard DCd so shouldn't update state in that case
    if self.connection.socket then
      self.opponent = nil
      self.state = "lobby"
      self.player_number = nil
      self:sendJson(ServerProtocol.leaveRoom(room.roomNumber, reason))
    end
  else
    logger.error("Trying to remove player " .. self.name .. " from room " .. room.roomNumber .. " even though they have no room assigned")
  end

  self.room = nil
end

function Player:sendJson(message)
  self.connection:sendJson(message)
end

function Player:send(message)
  self.connection:send(message)
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
    return not deep_content_equal(self.levelData, LevelPresets.getModern(self.level))
  end
end

---@param state PlayerState
function Player:setState(state)
  self.state = state
end

return Player
