local class = require("common.lib.class")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")

-- Represents all player accounts on the server.
---@class Playerbase
---@field players table<privateUserId, string>
---@field persistence Persistence
---@field publicIdToPrivateId privateUserId[]
---@field privateIdToPublicId table<privateUserId, integer>
local Playerbase =
  class(
  function(self, playerData, persistence)
    self.persistence = persistence
    self.players = playerData or {}
    self.publicIdToPrivateId = {}
    self.privateIdToPublicId = {}

    for privateId, _ in pairs(self.players) do
      local playerInfo = self.persistence.getPlayerInfo(privateId)
      if playerInfo then
        self.publicIdToPrivateId[playerInfo.publicPlayerID] = privateId
        self.privateIdToPublicId[privateId] = playerInfo.publicPlayerID
      else
        self.publicIdToPrivateId[#self.publicIdToPrivateId+1] = privateId
        self.privateIdToPublicId[privateId] = #self.publicIdToPrivateId
      end
    end

    logger.info(tableUtils.length(self.players) .. " players loaded")
  end
)

function Playerbase:addPlayer(userID, username)
  self.players[userID] = username
  if self.persistence.persistNewPlayer(userID, username) then
    local playerInfo = self.persistence.getPlayerInfo(userID)
    if playerInfo then
      self.publicIdToPrivateId[playerInfo.publicPlayerID] = userID
      self.privateIdToPublicId[userID] = playerInfo.publicPlayerID
    else
      self.publicIdToPrivateId[#self.publicIdToPrivateId+1] = userID
      self.privateIdToPublicId[userID] = #self.publicIdToPrivateId
    end
    return true
  else
    return false
  end
end

function Playerbase:updatePlayer(user_id, user_name)
  self.players[user_id] = user_name
  self.persistence.persistPlayerNameChange(self.players)
end

-- returns true if the name is taken by a different user already
function Playerbase:nameTaken(userID, playerName)

  for key, value in pairs(self.players) do
    if value:lower() == playerName:lower() then
      if key ~= userID then
        return true
      end
    end
  end

  return false
end

return Playerbase