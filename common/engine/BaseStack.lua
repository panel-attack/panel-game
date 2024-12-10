local class = require("common.lib.class")
local Signal = require("common.lib.signal")

local BaseStack = class(
function(self, args)

  -- basics
  self.framesBehindArray = {}
  self.framesBehind = 0
  self.clock = 0
  self.game_over_clock = -1 -- the exact clock frame the stack lost, -1 while alive
  Signal.turnIntoEmitter(self)
  self:createSignal("dangerMusicChanged")

  -- the stack pushes the garbage it produces into this queue
  self.outgoingGarbage = GarbageQueue()
  -- after completing the inTransit delay garbage sits in this queue ready to be popped as soon as the stack allows it
  self.incomingGarbage = GarbageQueue()

  -- rollback
  -- TODO: Replace with use of the RollbackBuffer
  self.rollbackCopies = {}
  self.rollbackCopyPool = Queue()
  self.rollbackCount = 0
  self.lastRollbackFrame = -1 -- the last frame we had to rollback from
end)

function BaseStack:receiveGarbage(frameToReceive, garbageArray)
  error("did not implement receiveGarbage")
end

function BaseStack:saveForRollback()
  error("did not implement saveForRollback")
end

function BaseStack:rollbackToFrame(frame)
  error("did not implement rollbackToFrame")
end

function BaseStack:rewindToFrame(frame)
  error("did not implement rewindToFrame")
end

function BaseStack:starting_state()
  error("did not implement starting_state")
end

function BaseStack:game_ended()
  error("did not implement game_ended")
end

function BaseStack:shouldRun()
  error("did not implement shouldRun")
end

function BaseStack:run()
  error("did not implement run")
end

function BaseStack:runGameOver()
  error("did not implement runGameOver")
end

return BaseStack