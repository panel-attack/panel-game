local Signal = require("common.lib.signal")

-- an emitter that outlives its subscribers, like GAME.localPlayer
local function createEmitter()
  local emitter = {}
  Signal.turnIntoEmitter(emitter)
  emitter:createSignal("changed")
  return emitter
end

---@param emitter table
---@return integer
local function subscriberCount(emitter)
  collectgarbage("collect")
  collectgarbage("collect")
  local count = 0
  for _ in pairs(emitter.signalSubscriptions.changed) do
    count = count + 1
  end
  return count
end

local function onChanged(subscriber, value)
  subscriber.value = value
end

-- a subscriber goes away with its subscription when the callback does not lead back to it
local function subscriberIsReleasedTest()
  local emitter = createEmitter()
  local subscriber = {}
  emitter:connectSignal("changed", subscriber, onChanged)
  emitter:emitSignal("changed", 3)
  assert(subscriber.value == 3)
  assert(subscriberCount(emitter) == 1)

  subscriber = nil
  assert(subscriberCount(emitter) == 0, "a subscriber whose callback captures nothing should be collected")
end

-- Builds a subscriber the way scene code does: a UI element with a sibling under a shared parent. The locals end with
-- the function, but a closure keeps its upvalues.
---@param emitter table
---@param captureSibling boolean whether the callback captures the sibling or reads it from the subscriber
---@return table held the sibling, held weakly, to check the callback still reaches it
local function subscribeWithSibling(emitter, captureSibling)
  local parent = {children = {}}
  local subscriber = {parent = parent}
  local sibling = {parent = parent}
  parent.children = {subscriber, sibling}
  if captureSibling then
    emitter:connectSignal("changed", subscriber, function(self, value)
      sibling.value = value
    end)
  else
    subscriber.sibling = sibling
    emitter:connectSignal("changed", subscriber, function(self, value)
      self.sibling.value = value
    end)
  end
  return setmetatable({sibling = sibling}, {__mode = "v"})
end

-- what the subscriber needs can be stored on it instead of captured, since it is the callback's first argument
local function subscriberCarriesWhatItNeedsTest()
  local emitter = createEmitter()
  local held = subscribeWithSibling(emitter, false)
  emitter:emitSignal("changed", 5)
  assert(held.sibling.value == 5)
  assert(subscriberCount(emitter) == 0, "a callback that captures nothing should not keep its subscriber alive")
end

-- LuaJIT has no ephemerons: a callback whose upvalues lead back to its subscriber keeps it alive as long as the emitter
-- lives, however weak the key is. Signal.connectSignal documents this; the test pins the behaviour it describes.
local function capturingClosureRetainsSubscriberTest()
  local emitter = createEmitter()
  local held = subscribeWithSibling(emitter, true)
  emitter:emitSignal("changed", 7)
  assert(subscriberCount(emitter) == 1, "a closure reaching its subscriber through an upvalue keeps the subscriber alive")
  assert(held.sibling and held.sibling.value == 7)
end

subscriberIsReleasedTest()
subscriberCarriesWhatItNeedsTest()
capturingClosureRetainsSubscriberTest()
