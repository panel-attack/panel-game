if arg[1] == "debug" then
  -- for debugging in visual studio code
  pcall(function() require("lldebugger").start() end)
end

-- We must launch the server from the root directory so all the requires are the right path relatively.
require("server.server_globals")
local util = require("common.lib.util")
util.addToCPath("./common/lib/??")
util.addToCPath("./server/lib/??")
require("server.tests.LoginTests")
require("server.tests.RoomTests")
require("server.tests.LeaderboardTests")
require("server.tests.ServerTests")

local database = require("server.PADatabase")
local Server = require("server.server")
local GameModes = require("common.engine.GameModes")

local server = Server(database)
server:initializePlayerData("players.txt")
server:initializeLeaderboard(GameModes.getPreset("TWO_PLAYER_VS"), "leaderboard.csv")
local isPlayerTableEmpty = database:getPlayerRecordCount() == 0
if isPlayerTableEmpty then
  server:importDatabase()
end

while true do
  server:update()
end