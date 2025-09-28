---@diagnostic disable: duplicate-set-field
-- with love 12 you can pass the name of a lua file as an argument when starting love
-- this will cause that file to be used in place of main.lua
-- so by passing "./testLauncher.lua" as the first arg this becomes a testrunner that shares the game's conf.lua
-- Usage: 
--   love ./testLauncher.lua [debug] [test_name]
--   Examples:
--     love ./testLauncher.lua debug PuzzleSetIteratorTests
--     love ./testLauncher.lua PuzzleSetIteratorTests
--     love ./testLauncher.lua debug
if arg[2] == "debug" then
  require("client.src.developer")
end
local t = love.timer.getTime()
--jit.off()
print("jit version: " .. require("jit").version)
-- for luajit's built-in profiler to run, luajit with the version matching love's has to be installed
-- jit.version yields the timestamp of the commit that was used to build as its patch number
-- clone the luajit repo, checkout the commit belonging to the time stamp and compile and jit.p should "just work"
-- assuming it is in the lua path which on linux may require this next line to be used
--package.path = package.path .. ";/usr/local/share/luajit-2.1/?.lua"
--require("jit.p").start("vFi1m1", "profiling/jitProfile.log")

require("common.lib.mathExtensions")
local util = require("common.lib.util")
util.addToCPath("./common/lib/??")
util.addToCPath("./server/lib/??")
local logger = require("common.lib.logger")

-- Set log level based on debug argument
if arg[2] == "debug" then
  logger.setLogLevel(logger.DEBUG)
else
  logger.setLogLevel(logger.INFO)
end

require("client.src.globals")
local Game = require("client.src.Game")

function love.load()
  -- this is necessary setup of globals while non-client tests still depend on client components
  GAME = Game()
  GAME:load()
  GAME.muteSound = true

  local cr = coroutine.create(GAME.setupRoutine)
  while coroutine.status(cr) ~= "dead" do
    local success, status = coroutine.resume(cr, GAME)
    if not success then
      GAME.crashTrace = debug.traceback(cr)
      error(status)
    end
  end
end

local allTests = {
  "common.tests.lib.JsonPrecisionTests",
  "common.tests.engine.PanelGenTests",
  "common.tests.engine.HealthTests",
  "common.tests.engine.RollbackBufferTests",
  "common.tests.engine.StackTests",
  "common.tests.engine.ReplayTests",
  "common.tests.engine.StackReplayTests",
  "common.tests.engine.GarbageQueueTests",
  "common.tests.engine.PuzzleTests",
  "common.tests.PuzzleHintHelperTests",
  "common.tests.engine.StackTouchReplayTests",
  "common.tests.engine.StackRollbackReplayTests",
  -- disabled for testLauncher because it needs the client love callbacks
  --"common.tests.lib.InputTests",
  "common.tests.lib.JsonEncodingTests",
  "common.tests.lib.tableUtilsTest",
  "common.tests.lib.utf8AdditionsTests",
  "common.tests.lib.utilTests",
  "common.tests.network.NetworkProtocolTests",
  "common.tests.network.TouchDataEncodingTests",
  "common.tests.data.InputCompressionTests",
  "server.tests.ServerTests",
  "server.tests.LeaderboardTests",
  "server.tests.RoomTests",
  "server.tests.LoginTests",
  "client.tests.FileUtilsTests",
  "client.tests.ModControllerTests",
  "client.tests.QueueTests",
  "client.tests.PuzzleSetTests",
  "client.tests.PuzzleSetIteratorTests",
  "client.tests.PuzzleLibraryTests",
  "client.tests.graphics_PuzzleHierarchyDisplayTests",
  "client.tests.ServerQueueTests",
  "client.tests.SoundGroupTests",
  "client.tests.TcpClientTests",
  "client.tests.ThemeTests",
  "client.tests.StackGraphicsTests",
}

-- Check for specific test name argument
local testFilter = nil
if arg[2] == "debug" and arg[3] then
  testFilter = arg[3]
elseif arg[2] and arg[2] ~= "debug" then
  testFilter = arg[2]
end

local tests = {}
if testFilter then
  -- Filter tests to only run the specified test
  for _, testName in ipairs(allTests) do
    if string.find(testName, testFilter) then
      table.insert(tests, testName)
    end
  end
  if #tests == 0 then
    logger.error("No tests found matching filter: " .. testFilter)
    os.exit(1)
  else
    logger.info("Running " .. #tests .. " test(s) matching filter: " .. testFilter)
  end
else
  tests = allTests
end

local updateCount = 0
local testsFailed = false

function love.update(dt)
  if tests[updateCount] then
    logger.info("running test file " .. tests[updateCount])
    local success, err = true, nil
    if lldebugger then
      require(tests[updateCount])
    else
      success, err = pcall(require, tests[updateCount])
    end
    if not success then
      -- Check if the error is due to missing file
      if string.find(err, "module.*not found") then
        logger.error("Test file does not exist: " .. tests[updateCount] .. " - " .. tostring(err))
        logger.error("Make sure the test file exists at the correct path and is properly named")
      else
        logger.error("Test failed: " .. tests[updateCount] .. " - " .. tostring(err))
      end
      testsFailed = true
    end
  end
  updateCount = updateCount + 1
end

-- the drawing somehow doesn't really work because the update does not wait for the require to finish?
function love.draw()
  local width, height = love.window.getMode()
  if tests[updateCount + 1] then
    love.graphics.printf("Running " .. tests[updateCount + 1], 0, height / 2, width, "center")
  elseif updateCount > #tests then
    love.graphics.printf("All tests completed", 0, height / 2, width, "center")
    love.event.quit()
  end
end

function love.quit()
  logger.info("Tests completed in " .. love.timer.getTime() - t .. "s seconds")
  --require("jit.p").stop()
  love.filesystem.write("test.log", tostring(logger.messageBuffer))
  
  if testsFailed then
    logger.error("Tests failed!")
    os.exit(1)
  else
    logger.info("All tests passed!")
    os.exit(0)
  end
end

local love_errorhandler = love.errorhandler
function love.errorhandler(msg)
  logger.error(msg)
  testsFailed = true
  pcall(love.filesystem.write, "test-crash.log", tostring(logger.messageBuffer))
  if lldebugger then
    error(msg, 2)
  else
    if love.filesystem.exists("test-crash.log") then
      local sep = package.config:sub(1, 1)
      love.system.openURL(love.filesystem.getRealDirectory("test-crash.log") .. sep .. "test-crash.log")
    end
    return love_errorhandler(msg)
  end
end