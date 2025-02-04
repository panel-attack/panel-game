---@diagnostic disable: duplicate-set-field

-- Put any local development changes you need in here that you don't want commited.

local function enableProfiler()
  PROF_CAPTURE = true
  -- we want to optimize in a way that our weakest platforms benefit
  -- on our weakest platform (android), jit is default disabled
  jit.off()
end

local developerTools = {}

function developerTools.processArgs(args)
  for _, value in pairs(args) do
    if value == "debug" then
      if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
        require("lldebugger").start()
        DEBUG_ENABLED = 1
      end
    elseif value == "profileFrameTimes" then
      enableProfiler()

      if not collectgarbage("isrunning") then
        collectgarbage("restart")
      end
    elseif value == "profileMemory" then
      enableProfiler()
      -- the garbage collector is a primary source of frame spikes
      -- thus one goal of profiling is to identify where memory is allocated
      -- because the less memory is allocated, the less the garbage collector runs 
      -- the final goal would be to achieve near 0 memory allocation during games
      -- this would allow us to simply turn off the GC during matches and only collect afterwards
      PROFILE_MEMORY = true
      collectgarbage("stop")
    elseif value == "updaterTest" then
      -- drop the updater directory of the updater in for debugging purposes
      GAME_UPDATER_STATES = { idle = 0, checkingForUpdates = 1, downloading = 2}
      GAME_UPDATER = require("updater.gameUpdater")
    else
      for match in string.gmatch(value, "user%-id=(.*)") do
        CUSTOM_USER_ID = match
      end
      for match in string.gmatch(value, "username=(.*)") do
        CUSTOM_USERNAME = match
      end
    end
  end
end

local realId
local realName

function developerTools.wrapConfig()
  local read = readConfigFile
  local write = write_conf_file

  readConfigFile = function(c)
    ---@type UserConfig
    c = read(c)
    realName = c.name
    c.name = CUSTOM_USERNAME or realName
  end

  write_conf_file = function()
    if config.name == CUSTOM_USERNAME then
      config.name = realName
    end
    write()
  end
end

function developerTools.wrapPersistence()
  local save = require("client.src.save")

  local readId = save.read_user_id_file
  save.read_user_id_file = function(serverIP)
    realId = readId(serverIP)
    return CUSTOM_USER_ID or realId
  end

  local writeId = save.write_user_id_file
  save.write_user_id_file = function(userID, serverIP)
    if userID == CUSTOM_USER_ID then
      userID = realId
    end
    writeId(userID, serverIP)
  end
end

developerTools.processArgs(arg)
developerTools.wrapConfig()
developerTools.wrapPersistence()

return developerTools