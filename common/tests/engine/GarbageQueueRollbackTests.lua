local GarbageQueue = require("common.engine.GarbageQueue")

-- the growing chain is the one piece of garbage in the queue that is still mutable
-- so a restore has to take a copy of it rather than adopt the one held in the rollback copy
local function testRestoreDoesNotAdoptTheStoredChain()
  local queue = GarbageQueue()
  local copy = {}

  queue:addChainLink(10, 1, 1)
  queue:addChainLink(20, 1, 2)
  assert(queue.currentChain.height == 2, "Expected a chain of height 2 but got " .. queue.currentChain.height)

  queue:saveIntoRollbackCopy(copy)
  queue:addChainLink(40, 1, 3)
  assert(queue.currentChain.height == 3, "Expected a chain of height 3 but got " .. queue.currentChain.height)

  queue:restoreFromRollbackCopy(copy, 30, false)
  assert(queue.currentChain.height == 2, "Expected the restore to give back a chain of height 2 but got " .. queue.currentChain.height)

  queue:addChainLink(50, 1, 4)
  assert(copy.currentChain.height == 2,
    "Expected the rollback copy to still hold a chain of height 2 but got " .. copy.currentChain.height)
end

testRestoreDoesNotAdoptTheStoredChain()
