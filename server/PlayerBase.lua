local class = require("common.lib.class")
local logger = require("common.lib.logger")
require("server.server_file_io")
local tableUtils = require("common.lib.tableUtils")
local Signal = require("common.lib.signal")

-- Represents all player accounts on the server.
Playerbase =
  class(
  function(self, name, playerData)
    self.name = name
    self.players = playerData or {}
    --{["e2016ef09a0c7c2fa70a0fb5b99e9674"]="Bob",
    --["d28ac48ba5e1a82e09b9579b0a5a7def"]="Alice"}
    logger.info(tableUtils.length(self.players) .. " players loaded")

    Signal.turnIntoEmitter(self)
    self:createSignal("playerUpdated")
  end
)

function Playerbase:addPlayer(userID, username)
  self:updatePlayer(userID, username)
end

function Playerbase:updatePlayer(user_id, user_name)
  self.players[user_id] = user_name
  self:emitSignal("playerUpdated", user_name)
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