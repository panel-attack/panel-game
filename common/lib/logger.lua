local os = require("os")
local RingBuffer = require("common.lib.RingBuffer")
local socket
if love then
  -- love comes with luasocket
---@diagnostic disable-next-line: different-requires
  socket = require("socket")
else
---@diagnostic disable-next-line: different-requires
  socket = require("common.lib.socket")
end

local logger = {
  messageBuffer = RingBuffer(2048),
  logFile = nil
}

if love then
  local sourceDir = love.filesystem.getSourceBaseDirectory()
  local logPath = sourceDir .. "/logs/client.log"
  logger.logFile = io.open(logPath, "w")
end

---@enum LogLevel
logger.levels = {
  TRACE = 0, -- Log something that is very detailed verbose debug logging
  DEBUG = 1, -- Log something that is only useful when debugging
  INFO = 2, -- Log something that is useful in most normal conditions
  WARN = 3, -- Log something that could be a problem
  ERROR = 4 -- Log something that definitely is a problem
}

---@type LogLevel
logger.logLevel = logger.levels.DEBUG

---@param level LogLevel use logger.levels. to access presets
function logger.setLogLevel(level)
  logger.logLevel = level
end

-- See comments above about when you should use each logging level
function logger.trace(msg)
  if logger.logLevel <= logger.levels.TRACE then
    direct_log("TRACE", msg);
  end
end

-- See comments above about when you should use each logging level
function logger.debug(msg)
  if logger.logLevel <= logger.levels.DEBUG then
    direct_log("DEBUG", msg);
  end
end

-- See comments above about when you should use each logging level
function logger.info(msg)
  if logger.logLevel <= logger.levels.INFO then
    direct_log(" INFO", msg);
  end
end

-- See comments above about when you should use each logging level
function logger.warn(msg)
  if logger.logLevel <= logger.levels.WARN then
    direct_log(" WARN", msg);
  end
end

-- See comments above about when you should use each logging level
function logger.error(msg)
  if logger.logLevel <= logger.levels.ERROR then
    direct_log("ERROR", msg);
  end
end

function direct_log(prefix, msg)
  local socket_millis = math.floor(socket.gettime()%1 * 1000)

  -- Lua date format strings reference: https://www.lua.org/pil/22.1.html
  -- %x - Date
  -- %X - Time
  local message = string.format("%s.%03d %s:%s", os.date("%x %X"), socket_millis, prefix, msg)
  print(message)
  logger.messageBuffer:push(message)
  if not SERVER_MODE then
    if logger.logFile then
      logger.logFile:write(message .. "\n")
      logger.logFile:flush()
    end
    if prefix == "ERROR" or prefix == " WARN" then
      love.filesystem.append("warnings.txt", message .. "\n")
    end
  end
end

return logger
