local ModLoader = require("client.src.mods.ModLoader")

-- Returns a stand-in mod that counts how often it was loaded.
---@param id string
local function createCountingMod(id)
  local mod = { id = id, fullyLoaded = false, loadCount = 0 }
  function mod:load()
    self.loadCount = self.loadCount + 1
    self.fullyLoaded = true
  end
  return mod
end

local function testRequestingAQueuedModAgainLoadsItOnce()
  local mod = createCountingMod("queuedTwice")

  ModLoader.load(mod)
  ModLoader.load(mod)
  ModLoader.wait()

  assert(mod.loadCount == 1, "a mod requested twice before it loaded should load once, but loaded " .. mod.loadCount .. " times")
end

testRequestingAQueuedModAgainLoadsItOnce()

local function testRequestingACancelledModAgainStillLoadsIt()
  local mod = createCountingMod("cancelledThenRequested")

  ModLoader.load(mod)
  -- what ModLoader.cancelLoad does for a mod that waits in the queue behind another
  ModLoader.cancellationList[mod] = true
  ModLoader.load(mod)
  ModLoader.wait()

  assert(mod.loadCount == 1, "a cancelled mod that is requested again should load once, but loaded " .. mod.loadCount .. " times")
  assert(ModLoader.cancellationList[mod] == nil, "requesting the mod again should take it off the cancellation list")
end

testRequestingACancelledModAgainStillLoadsIt()
