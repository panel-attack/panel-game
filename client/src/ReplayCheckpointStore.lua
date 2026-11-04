local class = require("common.lib.class")
local MessagePack = require("common.lib.jprof.MessagePack")

-- Preserve shared tables (notably currentChain), sparse numeric keys, and double precision.
---@param root table
---@return string
local function encode(root)
  local tables = {}
  local ids = {}
  local function reference(value)
    if type(value) ~= "table" then
      assert(type(value) == "string" or type(value) == "number" or type(value) == "boolean", "Invalid checkpoint value")
      return value
    end
    if not ids[value] then
      ids[value] = #tables + 1
      tables[#tables + 1] = value
    end
    return {ids[value]}
  end

  reference(root)
  local nodes = {}
  local index = 1
  while index <= #tables do
    local entries = {}
    for key, value in pairs(tables[index]) do
      entries[#entries + 1] = reference(key)
      entries[#entries + 1] = reference(value)
    end
    nodes[index] = entries
    index = index + 1
  end
  return love.data.compress("string", "lz4", MessagePack.pack(nodes))
end

---@param data string
---@return table
local function decode(data)
  local nodes = MessagePack.unpack(love.data.decompress("string", "lz4", data))
  local tables = {}
  for i = 1, #nodes do
    tables[i] = {}
  end
  local function dereference(value)
    if type(value) == "table" then
      return assert(tables[value[1]], "Invalid checkpoint reference")
    end
    return value
  end
  for i, entries in ipairs(nodes) do
    for j = 1, #entries, 2 do
      tables[i][dereference(entries[j])] = dereference(entries[j + 1])
    end
  end
  return assert(tables[1], "Empty replay checkpoint")
end

local nextId = 0
local openStores = {}

---@class ReplayCheckpointStore
---@field directory string
---@field interval integer
---@field latestFrame integer
---@field cachedFrame integer?
---@field cachedCheckpoint table? At most one decoded checkpoint is retained.
---@field closed boolean
---@overload fun(interval: integer): ReplayCheckpointStore
local ReplayCheckpointStore = class(
---@param self ReplayCheckpointStore
---@param interval integer
function(self, interval)
  nextId = nextId + 1
  local id = os.time() .. "-" .. love.timer.getTime() .. "-" .. nextId
  self.directory = "replay-cache/" .. love.data.encode("string", "hex", love.data.hash("string", "sha256", id))
  self.interval = interval
  self.latestFrame = -interval
  self.closed = false
  assert(not love.filesystem.getInfo(self.directory), "Replay checkpoint directory already exists")
  assert(love.filesystem.createDirectory(self.directory), "Could not create replay checkpoint directory")
  openStores[self] = true
end)

---Writes a checkpoint without retaining the captured object graph.
---@param frame integer
---@param checkpoint table
function ReplayCheckpointStore:save(frame, checkpoint)
  assert(frame == self.latestFrame + self.interval, "Replay checkpoints must be saved in order")
  local success, message = love.filesystem.write(self.directory .. "/" .. frame, encode(checkpoint))
  assert(success, message)
  self.latestFrame = frame
end

---Loads the closest checkpoint at or before frame, retaining only this checkpoint in RAM.
---@param frame integer
---@return table
function ReplayCheckpointStore:load(frame)
  local checkpointFrame = math.min(math.floor(frame / self.interval) * self.interval, self.latestFrame)
  assert(checkpointFrame >= 0, "Replay has no initial checkpoint")
  if checkpointFrame ~= self.cachedFrame then
    self.cachedCheckpoint = nil
    local data, message = love.filesystem.read(self.directory .. "/" .. checkpointFrame)
    assert(data, message)
    self.cachedCheckpoint = decode(data)
    self.cachedFrame = checkpointFrame
  end
  return self.cachedCheckpoint
end

---Removes only files owned by this playback session.
function ReplayCheckpointStore:close()
  if self.closed then
    return
  end
  for frame = 0, self.latestFrame, self.interval do
    assert(love.filesystem.remove(self.directory .. "/" .. frame), "Could not remove replay checkpoint")
  end
  assert(love.filesystem.remove(self.directory), "Could not remove replay checkpoint directory")
  self.cachedCheckpoint = nil
  self.cachedFrame = nil
  self.closed = true
  openStores[self] = nil
end

---Also cleans up an open replay when the application exits rather than returning to the browser.
function ReplayCheckpointStore.closeAll()
  for store in pairs(openStores) do
    store:close()
  end
end

return ReplayCheckpointStore
