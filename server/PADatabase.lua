local logger = require("common.lib.logger")
local sqlite3 = require("lsqlite3")
---@class SqliteDB
---@field exec function
---@field errmsg function
---@field prepare function
---@field last_insert_rowid function
local db = sqlite3.open("PADatabase.sqlite3")

---@alias BanID integer
---@alias DB_Ban {banID: BanID, reason: string, completionTime: integer}
---@alias DB_Player {publicPlayerID: integer, privatePlayerID: integer, username: string, lastLoginTime: integer}

---@class ServerDB
---@field db SqliteDB
local PADatabase = {db = db}

db:exec[[
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS Player(
  publicPlayerID INTEGER PRIMARY KEY AUTOINCREMENT,
  privatePlayerID INTEGER NOT NULL UNIQUE,
  username TEXT NOT NULL,
  lastLoginTime TIME TIMESTAMP DEFAULT (strftime('%s', 'now'))
);

CREATE TABLE IF NOT EXISTS Game(
  gameID INTEGER PRIMARY KEY AUTOINCREMENT,
  ranked BOOLEAN NOT NULL CHECK (ranked IN (0, 1)),
  timePlayed TIME TIMESTAMP NOT NULL DEFAULT (strftime('%s', 'now'))
);

INSERT OR IGNORE INTO Game(gameID, ranked) VALUES (0, 1); -- Placeholder game for imported Elo history

CREATE TABLE IF NOT EXISTS PlayerGameResult(
  publicPlayerID INTEGER NOT NULL,
  gameID INTEGER NOT NULL,
  level INTEGER,
  placement INTEGER NOT NULL,
  FOREIGN KEY(publicPlayerID) REFERENCES Player(publicPlayerID),
  FOREIGN KEY(gameID) REFERENCES Game(gameID)
);

CREATE TABLE IF NOT EXISTS PlayerELOHistory(
  publicPlayerID INTEGER,
  rating REAL NOT NULL,
  gameID INTEGER NOT NULL,
  FOREIGN KEY(gameID) REFERENCES Game(gameID)
);

CREATE TABLE IF NOT EXISTS PlayerMessageList(
  messageID INTEGER PRIMARY KEY NOT NULL,
  publicPlayerID INTEGER NOT NULL,
  message TEXT NOT NULL,
  messageSeen TIME TIMESTAMP,
  FOREIGN KEY(publicPlayerID) REFERENCES Player(publicPlayerID)
);

CREATE TABLE IF NOT EXISTS IPID(
  ip TEXT NOT NULL,
  publicPlayerID INTEGER NOT NULL,
  PRIMARY KEY(ip, publicPlayerID),
  FOREIGN KEY(publicPlayerID) REFERENCES Player(publicPlayerID)
);

CREATE TABLE IF NOT EXISTS PlayerBanList(
  banID INTEGER PRIMARY KEY NOT NULL,
  ip TEXT, 
  publicPlayerID INTEGER,
  reason TEXT NOT NULL,
  completionTime INTEGER,
  banSeen TIME TIMESTAMP,
  FOREIGN KEY(publicPlayerID) REFERENCES Player(publicPlayerID)
);
]]

local insertPlayerStatement = assert(db:prepare("INSERT OR IGNORE INTO Player(privatePlayerID, username) VALUES (?, ?)"))
-- Inserts a new player into the database, ignores the statement if the ID is already used.
---@param privatePlayerID privateUserId
---@param username string
---@return boolean # if the player was successfully inserted
function PADatabase:insertNewPlayer(privatePlayerID, username)
  insertPlayerStatement:bind_values(privatePlayerID, username)
  insertPlayerStatement:step()
  if insertPlayerStatement:reset() ~= sqlite3.OK then
    logger.error(db:errmsg())
    return false
  end
  return true
end

local selectPlayerStatement = assert(db:prepare("SELECT * FROM Player WHERE privatePlayerID = ?"))
-- Retrieves the player from the privatePlayerID
---@param privatePlayerID privateUserId
---@return DB_Player?
function PADatabase:getPlayerFromPrivateID(privatePlayerID)
  assert(privatePlayerID ~= nil)
  selectPlayerStatement:bind_values(privatePlayerID)
  local player = nil
  for row in selectPlayerStatement:nrows() do
    player = row
    break
  end
  if selectPlayerStatement:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return nil
  end
  return player
end

local updatePlayerUsernameStatement = assert(db:prepare("UPDATE Player SET username = ? WHERE privatePlayerID = ?"))
-- Updates the username of a player in the database based on their privatePlayerID.
---@param privatePlayerID privateUserId
---@param username string
---@return boolean success if the update of the name was successful
function PADatabase:updatePlayerUsername(privatePlayerID, username)
  updatePlayerUsernameStatement:bind_values(username, privatePlayerID)
  updatePlayerUsernameStatement:step()
  if updatePlayerUsernameStatement:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return false
  end
  return true
end

local insertPlayerELOChangeStatement = assert(db:prepare("INSERT INTO PlayerELOHistory(publicPlayerID, rating, gameID) VALUES ((SELECT publicPlayerID FROM Player WHERE privatePlayerID = ?), ?, ?)"))
-- Inserts a change of a Player's elo.
---@param privatePlayerID privateUserId
---@param rating number
---@param gameID integer
---@return boolean success if the rating change was successfully inserted
function PADatabase:insertPlayerELOChange(privatePlayerID, rating, gameID)
  insertPlayerELOChangeStatement:bind_values(privatePlayerID, rating or 1500, gameID)
  insertPlayerELOChangeStatement:step()
  if insertPlayerELOChangeStatement:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return false
  end
  return true
end

local selectPlayerRecordCount = assert(db:prepare("SELECT COUNT(*) FROM Player"))
-- Returns the amount of players in the Player database.
---@return integer?
function PADatabase:getPlayerRecordCount()
  local result = nil
  for row in selectPlayerRecordCount:rows() do
    result = row[1]
    break
  end
  if selectPlayerRecordCount:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return nil
  end
  return result
end

local insertGameStatement = assert(db:prepare("INSERT INTO Game(ranked) VALUES (?)"))
---@param ranked boolean if the game is ranked
---@return integer? gameID
function PADatabase:insertGame(ranked)
  insertGameStatement:bind_values(ranked and 1 or 0)
  insertGameStatement:step()
  if insertGameStatement:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return nil
  end
  return self.db:last_insert_rowid()
end

local insertPlayerGameResultStatement = assert(db:prepare("INSERT INTO PlayerGameResult(publicPlayerID, gameID, level, placement) VALUES ((SELECT publicPlayerID FROM Player WHERE privatePlayerID = ?), ?, ?, ?)"))
-- Inserts the results of a game.
---@param privatePlayerID privateUserId
---@param gameID integer
---@param level integer? The level preset the player used, can be nil
---@param placement integer The placement for the player with the user id amongst all players in that game \n
--- placement 1 marks the winner
---@return boolean success
function PADatabase:insertPlayerGameResult(privatePlayerID, gameID, level, placement)
  insertPlayerGameResultStatement:bind_values(privatePlayerID, gameID, level, placement)
  insertPlayerGameResultStatement:step()
  if insertPlayerGameResultStatement:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return false
  end
  return true
end

local selectPlayerMessagesStatement = assert(db:prepare("SELECT messageID, message FROM PlayerMessageList WHERE publicPlayerID = ? AND messageSeen IS NULL"))
-- Retrieves player messages that the player has not seen yet.
---@param publicPlayerID integer
---@return table<integer, string> messages
function PADatabase:getPlayerMessages(publicPlayerID)
  selectPlayerMessagesStatement:bind_values(publicPlayerID)
  local playerMessages = {}
  for row in selectPlayerMessagesStatement:nrows() do
    playerMessages[row.messageID] = row.message
  end
  if selectPlayerMessagesStatement:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return {}
  end
  return playerMessages
end

local updatePlayerMessageSeenStatement = assert(db:prepare("UPDATE PlayerMessageList SET messageSeen = strftime('%s', 'now') WHERE messageID = ?"))
-- Marks a message as seen by a player.
---@param messageID integer
---@return boolean success
function PADatabase:playerMessageSeen(messageID)
  updatePlayerMessageSeenStatement:bind_values(messageID)
  updatePlayerMessageSeenStatement:step()
  if updatePlayerMessageSeenStatement:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return false
  end
  return true
end

local insertBanStatement = assert(db:prepare("INSERT INTO PlayerBanList(ip, reason, completionTime) VALUES (?, ?, ?)"))
-- Bans an IP address
---@param ip string
---@param reason string
---@param completionTime integer
---@return DB_Ban?
function PADatabase:insertBan(ip, reason, completionTime)
  insertBanStatement:bind_values(ip, reason, completionTime)
  insertBanStatement:step()
  if insertBanStatement:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return
  end
  return {banID = self.db:last_insert_rowid(), reason = reason, completionTime = completionTime}
end

local insertIPIDStatement = assert(db:prepare("INSERT OR IGNORE INTO IPID(ip, publicPlayerID) VALUES (?, ?)"))
-- Maps an IP address to a publicPlayerID.
---@param ip string
---@param publicPlayerID integer
---@return boolean success
function PADatabase:insertIPID(ip, publicPlayerID)
  insertIPIDStatement:bind_values(ip, publicPlayerID)
  insertIPIDStatement:step()
  if insertIPIDStatement:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return false
  end
  return true
end

local selectIPIDStatement = assert(db:prepare("SELECT publicPlayerID FROM IPID WHERE ip = ?"))
---@param ip string
---@return integer[] # all publicPlayerIDs that have been used with the given IP address
function PADatabase:getIPIDS(ip)
  selectIPIDStatement:bind_values(ip)
  local publicPlayerIDs = {}
  for row in selectIPIDStatement:nrows() do
    publicPlayerIDs[#publicPlayerIDs+1] = row.publicPlayerID
  end
  if selectIPIDStatement:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return {}
  end
  return publicPlayerIDs
end

local selectIPBansStatement = assert(db:prepare("SELECT banID, reason, completionTime FROM PlayerBanList WHERE ip = ?"))
-- Selects all bans associated with the ip given.
---@param ip string
---@return DB_Ban[]
function PADatabase:getIPBans(ip)
  selectIPBansStatement:bind_values(ip)
  local bans = {}
  for row in selectIPBansStatement:nrows() do
    bans[#bans+1] = {banID = row.banID, reason = row.reason, completionTime = row.completionTime}
  end
  if selectIPBansStatement:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return {}
  end
  return bans
end

local selectIDBansStatement = assert(db:prepare("SELECT banID, reason, completionTime FROM PlayerBanList WHERE publicPlayerID = ?"))
-- Selects all bans associated with the publicPlayerID given.
---@param publicPlayerID integer
---@return DB_Ban[]
function PADatabase:getIDBans(publicPlayerID)
  selectIDBansStatement:bind_values(publicPlayerID)
  local bans = {}
  for row in selectIDBansStatement:nrows() do
    bans[#bans+1] = {banID = row.banID, reason = row.reason, completionTime = row.completionTime}
  end
  if selectIDBansStatement:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return {}
  end
  return bans
end

-- Checks if a logging in player is banned based off their IP.
---@param ip string
---@return DB_Ban?
function PADatabase:getBanByIP(ip)
  -- all ids associated with the information given
  local publicPlayerIDs = {}
  if ip then
    publicPlayerIDs = self:getIPIDS(ip)
  end

  local bans = {}
  local ipBans = self:getIPBans(ip)
  for banID, ban in ipairs(ipBans) do
    bans[banID] = ban
  end

  for _, id in pairs(publicPlayerIDs) do
    for banID, ban in ipairs(self:getIDBans(id)) do
      bans[banID] = ban
    end
  end

  local longestBan = nil
  for _, ban in pairs(bans) do
    if (os.time() < ban.completionTime) and ((not longestBan) or (ban.completionTime > longestBan.completionTime)) then
      longestBan = ban
    end
  end
  return longestBan
end

local selectPlayerUnseenBansStatement = assert(db:prepare("SELECT banID, reason FROM PlayerBanList WHERE publicPlayerID = ? AND banSeen IS NULL"))
-- Retrieves player messages that the player has not seen yet.
---@param publicPlayerID integer
---@return table<BanID, string> # reasons for each ban, mapped by BanID
function PADatabase:getPlayerUnseenBans(publicPlayerID)
  selectPlayerUnseenBansStatement:bind_values(publicPlayerID)
  local banReasons = {}
  for row in selectPlayerUnseenBansStatement:nrows() do
    banReasons[row.banID] = row.reason
  end
  if selectPlayerUnseenBansStatement:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return {}
  end
  return banReasons
end

local updatePlayerBanSeenStatement = assert(db:prepare("UPDATE PlayerBanList SET banSeen = strftime('%s', 'now') WHERE banID = ?"))
-- Marks a ban as seen by a player.
---@param banID integer
---@return boolean success
function PADatabase:playerBanSeen(banID)
  updatePlayerBanSeenStatement:bind_values(banID)
  updatePlayerBanSeenStatement:step()
  if updatePlayerBanSeenStatement:reset() ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return false
  end
  return true
end

-- Stop statements from being committed until commitTransaction is called
function PADatabase:beginTransaction()
  if db:exec("BEGIN;") ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return false
  end
  return true
end

-- Commit all statements that were run since the start of beginTransaction
function PADatabase:commitTransaction()
  if db:exec("COMMIT;") ~= sqlite3.OK then
    logger.error(self.db:errmsg())
    return false
  end
  return true
end

return PADatabase