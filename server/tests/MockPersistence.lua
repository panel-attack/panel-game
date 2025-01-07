local PADatabase = require("server.PADatabase")
local FileIO = require("server.server_file_io")
local logger = require("common.lib.logger")

---@type Persistence
local MockPersistence = {}

local VsLeaderboardPath = "leaderboard.csv"
local PlayerIdsToNamesPath = "players.txt"
-- this should be a reference to the same player data the Playerbase holds onto
local PlayerData

function MockPersistence.setLeaderboardPath(path)
end

function MockPersistence.setPlayerIdsPath(path)
end

---@param playerData table<privateUserId, string>
function MockPersistence.setPlayerDataRef(playerData)
  PlayerData = playerData
end

---@param game ServerGame
function MockPersistence.persistGame(game)
end

---@param leaderboard Leaderboard
function MockPersistence.persistLeaderboard(leaderboard)
end

function MockPersistence.getLeaderboardData()
end

---@param userId privateUserId
---@param placementData table
function MockPersistence.persistPlacementGames(userId, placementData)
end

---@param userId privateUserId
function MockPersistence.persistPlacementFinalization(userId)
end

---@param userId privateUserId
function MockPersistence.getPlacementData(userId)
  return {}
end

---@param playerData table<privateUserId, string>
function MockPersistence.persistPlayerData(playerData)
end

function MockPersistence.persistNewPlayer(userId, name)
end

function MockPersistence.persistPlayerNameChange(userId, name)
end

---@return table<privateUserId, string>
function MockPersistence.getPlayerData()
  return {}
end

---@param privateUserId privateUserId
function MockPersistence.getPlayerInfo(privateUserId)
end

return MockPersistence