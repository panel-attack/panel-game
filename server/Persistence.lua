local PADatabase = require("server.PADatabase")
local FileIO = require("server.server_file_io")
local logger = require("common.lib.logger")

---@class Persistence
local Persistence = {}

local VsLeaderboardPath = "leaderboard.csv"
local PlayerIdsToNamesPath = "players.txt"
-- this should be a reference to the same player data the Playerbase holds onto
local PlayerData

function Persistence.setLeaderboardPath(path)
  VsLeaderboardPath = path
end

function Persistence.setPlayerIdsPath(path)
  PlayerIdsToNamesPath = path
end

---@param playerData table<privateUserId, string>
function Persistence.setPlayerDataRef(playerData)
  PlayerData = playerData
end

---@param game ServerGame
function Persistence.persistGame(game)
  local gameID = PADatabase:insertGame(game.ranked)
  if not gameID then
    logger.error("Failed to persist game to database.")
  else
    game:setId(gameID)
  end

  local resultValue = 0.5
  for i, player in ipairs(game.players) do
    local level = not player:usesModifiedLevelData() and player.level or nil
    if game.id then
      PADatabase:insertPlayerGameResult(player.userId, game.id, level, game:getPlacement(player))
    end
    if player.publicPlayerID == game.winnerId then
      if i == 1 then
        resultValue = 1
      elseif i == 2 then
        resultValue = 0
      end
    end
  end

  local rankedValue = game.ranked and 1 or 0
  FileIO.logGameResult(game.players[1].userId, game.players[2].userId, resultValue, rankedValue)

  FileIO.saveReplay(game)
end

---@param leaderboard Leaderboard
function Persistence.persistLeaderboard(leaderboard)
  FileIO.write_leaderboard_file(leaderboard, VsLeaderboardPath)
end

function Persistence.getLeaderboardData()
  return FileIO.readCsvFile(VsLeaderboardPath)
end

---@param userId privateUserId
---@param placementData table
function Persistence.persistPlacementGames(userId, placementData)
  FileIO.write_user_placement_match_file(userId, placementData)
end

---@param userId privateUserId
function Persistence.persistPlacementFinalization(userId)
  FileIO.move_user_placement_file_to_complete(userId)
end

---@param userId privateUserId
function Persistence.getPlacementData(userId)
  local read_success, matches = FileIO.read_user_placement_match_file(userId)
  if read_success then
    logger.debug("loaded placement matches from file")
    if matches then
      return matches
    else
      return {}
    end
  else
    return {}
  end
end

---@param playerData table<privateUserId, string>
function Persistence.persistPlayerData(playerData)
  FileIO.writeAsJson(playerData, PlayerIdsToNamesPath)
end

function Persistence.persistNewPlayer(userId, name)
  PADatabase:insertNewPlayer(userId, name)
  Persistence.persistPlayerData(PlayerData)
end

function Persistence.persistPlayerNameChange(userId, name)
  PADatabase:updatePlayerUsername(userId, name)
  Persistence.persistPlayerData(PlayerData)
end

---@return table<privateUserId, string>
function Persistence.getPlayerData()
  return FileIO.readJson(PlayerIdsToNamesPath)
end

---@param privateUserId privateUserId
function Persistence.getPlayerInfo(privateUserId)
  return PADatabase:getPlayerFromPrivateID(privateUserId)
end

return Persistence