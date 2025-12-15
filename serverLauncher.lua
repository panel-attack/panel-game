local logger = require("common.lib.logger")

if arg[1] == "debug" then
  -- for debugging in visual studio code
  if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    -- VS Code / VS Codium
    require("lldebugger").start()
  elseif pcall(function() require("mobdebug") end) then
    -- ZeroBrane
    -- afaik there is no good way to detect whether the game was started with zerobrane other than trying the require and succeeding
    require("mobdebug").start()
    require('mobdebug').coro()
  end
  logger.setLogLevel(logger.levels.DEBUG)
else
  logger.setLogLevel(logger.levels.INFO)
end

-- We must launch the server from the root directory so all the requires are the right path relatively.
require("server.server_globals")
local util = require("common.lib.util")
util.addToCPath("./common/lib/??")
util.addToCPath("./server/lib/??")
require("server.tests.ServerTests")
require("server.tests.LeaderboardTests")
require("server.tests.RoomTests")
require("server.tests.LoginTests")

local database = require("server.PADatabase")
local Server = require("server.server")
local GameModes = require("common.data.GameModes")
local Persistence = require("server.Persistence")

local server = Server(database, Persistence)
server:initializePlayerData("players.txt")
server:initializeLeaderboard(GameModes.getPreset("TWO_PLAYER_VS"), "leaderboard.csv")
local isPlayerTableEmpty = database:getPlayerRecordCount() == 0
if isPlayerTableEmpty then
  server:importDatabase()
end
server:start()

while true do
  server:update()
end