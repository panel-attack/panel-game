if arg[1] == "debug" then
  -- for debugging in visual studio code
  pcall(function() require("lldebugger").start() end)
end

-- We must launch the server from the root directory so all the requires are the right path relatively.
require("server.server_globals")
local util = require("common.lib.util")
util.addToCPath("./common/lib/??")
util.addToCPath("./server/lib/??")
require("server.tests.ConnectionTests")

local database = require("server.PADatabase")
local Server = require("server.server")


local server = Server(database)
server:initializePlayerData("players.txt")
server:initializeLeaderboard("leaderboard.csv")
local isPlayerTableEmpty = database:getPlayerRecordCount() == 0
if isPlayerTableEmpty then
  server:importDatabase()
end

while true do
  server:update()
end