---@diagnostic disable: missing-fields, duplicate-set-field, inject-field

---@type Persistence
local MockPersistence = {}
local testData

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
  return true
end

function MockPersistence.persistPlayerNameChange(userId, name)
  return true
end

---@return table<privateUserId, string>
function MockPersistence.getPlayerData()
  if PlayerData then
    return PlayerData
  end
  return {}
end

---@param privateUserId privateUserId
---@return DB_Player?
function MockPersistence.getPlayerInfo(privateUserId)
  --publicPlayerID: integer, privatePlayerID: integer, username: string, lastLoginTime: integer
  return {publicPlayerID = testData[tonumber(privateUserId)].publicPlayerID, privatePlayerID = privateUserId, username = testData[tonumber(privateUserId)].name, lastLoginTime = 0}
end

function MockPersistence.setTestData(playerData)
  testData = playerData
end

return MockPersistence