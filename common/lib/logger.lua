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
  messageBuffer = RingBuffer(2048)
}

logger.TRACE = 0 -- Log something that is very detailed verbose debug logging
logger.DEBUG = 1 -- Log something that is only useful when debugging
logger.INFO = 2 -- Log something that is useful in most normal conditions
logger.WARN = 3 -- Log something that could be a problem
logger.ERROR = 4 -- Log something that definitely is a problem

local LOG_LEVEL = logger.DEBUG

function logger.setLogLevel(level)
  LOG_LEVEL = level
end

-- See comments above about when you should use each logging level
function logger.trace(msg)
  if LOG_LEVEL <= logger.TRACE then
    direct_log("TRACE", msg);
  end
end

-- See comments above about when you should use each logging level
function logger.debug(msg)
  if LOG_LEVEL <= logger.DEBUG then
    direct_log("DEBUG", msg);
  end
end

-- See comments above about when you should use each logging level
function logger.info(msg)
  if LOG_LEVEL <= logger.INFO then
    direct_log(" INFO", msg);
  end
end

-- See comments above about when you should use each logging level
function logger.warn(msg)
  if LOG_LEVEL <= logger.WARN then
    direct_log(" WARN", msg);
  end
end

-- See comments above about when you should use each logging level
function logger.error(msg)
  if LOG_LEVEL <= logger.ERROR then
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
    -- the space in the string below is on purpose
    if prefix == "ERROR" or prefix == " WARN" then
      love.filesystem.append("warnings.txt", message .. "\n")
    end
  end
end

return logger
