-- Unbuffered stdout so log output flushes promptly even when the server
-- enters an idle accept loop. With default block buffering, a hung-looking
-- test run is usually just lines stuck in the buffer waiting on activity.
io.stdout:setvbuf("no")

local util = require("common.lib.util")
util.addToCPath("./common/lib/??")
util.addToCPath("./server/lib/??")
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

-- Server runtime should not depend on tests passing.
-- Run tests separately via run_tests.sh, or set PA_RUN_SERVER_TESTS=1 to keep old behavior.
if os.getenv("PA_RUN_SERVER_TESTS") == "1" then
  require("server.tests.LoginTests")
  require("server.tests.ServerTests")
  require("server.tests.LeaderboardTests")
  require("server.tests.RoomTests")
  require("server.tests.TeamRoomTests")
  require("server.tests.LooseSyncServerTests")
end

local database = require("server.PADatabase")
local Server = require("server.server")
local GameModes = require("common.data.GameModes")
local Persistence = require("server.Persistence")

local server = Server(database, Persistence)
server:initializePlayerData("players.txt")
server:initializeLeaderboard(GameModes.getPreset(GameModes.IDs.TWO_PLAYER_VS), "leaderboard.csv")
local isPlayerTableEmpty = database:getPlayerRecordCount() == 0
if isPlayerTableEmpty then
  server:importDatabase()
end
server:start()

while true do
  server:update()
end