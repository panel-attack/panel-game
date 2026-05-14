-- Headless server test runner.
--
-- Runs the server-side unit/integration suite in its own luajit process.
-- Does not bind a port, does not touch the real sqlite database (tests
-- use MockPersistence + MockConnection), and does not kill any running
-- dev server. Safe to run while `zsh run_server.sh` is live on port 49569.
--
-- Invoked via `zsh run_server_tests.sh`.

-- Unbuffered stdout so "All tests passed" actually reaches the terminal
-- when stdout is piped to tee or a file.
io.stdout:setvbuf("no")

local util = require("common.lib.util")
util.addToCPath("./common/lib/??")
util.addToCPath("./server/lib/??")
local logger = require("common.lib.logger")

if arg[1] == "debug" then
  logger.setLogLevel(logger.levels.DEBUG)
else
  logger.setLogLevel(logger.levels.INFO)
end

require("server.server_globals")

logger.info("=== running server tests (headless; MockPersistence, no port bound) ===")

require("server.tests.LoginTests")
require("server.tests.TraceWriterTests")
require("server.tests.TraceDiffTests")
require("server.tests.ServerTests")
require("server.tests.LeaderboardTests")
require("server.tests.DualSocketTests")
require("server.tests.RoomTests")
require("server.tests.TeamRoomTests")
require("server.tests.LooseSyncServerTests")

logger.info("=== all server tests passed ===")
os.exit(0)
