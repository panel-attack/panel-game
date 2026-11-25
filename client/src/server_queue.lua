local NetworkProtocol = require("common.network.NetworkProtocol")
local logger = require("common.lib.logger")
local class = require("common.lib.class")

-- Tracks a queue data structure.
-- Values are tracked via incrementing ID keys, when something is nilled it is tracked as an "empty"
---@class ServerQueue
---@field data table
---@field first integer
---@field last integer
---@field empties integer
ServerQueue =
  class(
  function(self)
    self:clear()
  end
)

function ServerQueue.clear(self)
  self.data = {}
  self.first = 0
  self.last = -1
  self.empties = 0
end

function ServerQueue.to_string(self)
  return "QUEUE: " .. dump(self)
end

function ServerQueue.to_short_string(self)
  local returnString = ""

  if self.first <= self.last then
    local still_empty = true
    for i = self.first, self.last do
      local msg = self.data[i]
      if msg ~= nil then
        for type, data in pairs(msg) do
          returnString = returnString .. type .. " "
        end
      end
    end
  end

  return returnString
end


-- push a server message in queue
function ServerQueue.push(self, msg)
  if not msg[NetworkProtocol.serverMessageTypes.opponentInput.prefix] and not msg[NetworkProtocol.serverMessageTypes.secondOpponentInput.prefix] then
    logger.debug("message received:\n" .. table_to_string(msg))
  end
  local last = self.last + 1
  self.last = last
  self.data[last] = msg
end

-- pop oldest server message in queue
function ServerQueue.pop(self)
  local first = self.first
  local ret = nil

  for i = self.first, self.last do
    ret = self.data[first]
    self.data[first] = nil
    first = first + 1
    if ret then
      break
    end
  end

  self.first = first
  self:check_empty()

  return ret
end

-- pop first element found with a message containing any specified keys...
function ServerQueue.pop_next_with(self, ...)
  if self.first > self.last then
    return
  end

  local still_empty = true
  for i = self.first, self.last do
    local msg = self.data[i]
    if msg ~= nil then
      still_empty = false
      for j = 1, select("#", ...) do
        if msg[select(j, ...)] ~= nil then
          --print("POP "..select(j, ...))
          self:remove(i)
          return msg
        end
      end
    elseif still_empty then
      self.first = self.first + 1
      self.empties = self.empties - 1
    end
  end
end

-- The first message after index that is still in the queue, as its index and the message
---@param queue ServerQueue
---@param index integer
---@return integer?
---@return table?
local function nextMessage(queue, index)
  while index < queue.last do
    index = index + 1
    local message = queue.data[index]
    if message ~= nil then
      return index, message
    end
  end
end

-- Moves the messages down over the holes remove left, keeping their order
function ServerQueue:closeHoles()
  local target = self.first
  for index = self.first, self.last do
    local message = self.data[index]
    if message ~= nil then
      self.data[index] = nil
      self.data[target] = message
      target = target + 1
    end
  end
  self.last = target - 1
  self.empties = 0
end

-- Iterates the messages from oldest to newest as index, message. The current message may be taken out with remove.
-- The holes earlier walks left are closed first, so a message kept at the head doesn't make every walk step over them.
---@return fun(queue: ServerQueue, index: integer): integer?, table?
---@return ServerQueue
---@return integer
function ServerQueue:getMessageIterator()
  if self.empties > 0 then
    self:closeHoles()
  end
  return nextMessage, self, self.first - 1
end

function ServerQueue.remove(self, index)
  if self.data[index] then
    self.data[index] = nil
    self.empties = self.empties + 1
    self:check_empty()
    return true
  end
  return false
end

function ServerQueue.top(self)
  return self.data[self.first]
end

function ServerQueue.size(self)
  if self.last < self.first then
    return 0
  end
  return self.last - self.first - self.empties + 1
end

function ServerQueue.check_empty(self)
  if self:size() == 0 then
    self.first = 0
    self.last = -1
    self.empties = 0
  end
end
