local class = require("common.lib.class")
local Signal = require("common.lib.signal")
local GarbageQueue = require("common.engine.GarbageQueue")
local GameModes = require("common.engine.GameModes")

---@class BaseStack
---@field engineVersion string
---@field which integer identifier of the Stack within the Match
---@field is_local boolean effectively if the Stack is receiving its inputs via local input
---@field framesBehindArray integer[] Records how far behind the stack was at each match clock time
---@field framesBehind integer How far behind the stack is at the current Match clock time
---@field clock integer how many times run has been called
---@field game_over_clock integer What the clock time was when the Stack went game over
---@field do_countdown boolean if the stack is performing a countdown at the start of the match
---@field countdown_timer boolean? ephemeral timer used for tracking countdown progress at the start of the game
---@field outgoingGarbage GarbageQueue
---@field incomingGarbage GarbageQueue
---@field rollbackCopies table
---@field rollbackCopyPool Queue
---@field rollbackCount integer How many times the stack has been rolled back
---@field lastRollbackFrame integer the clock time before the Stack was last rolled back \n
---@field health integer Reaching 0 typically means game over (depends on the gameOverConditions)
--- -1 if it has not been rolled back yet (or should not run back to its pre-rollback frame)
---@field play_to_end boolean?
---@field max_runs_per_frame integer How many times run() may be called within a single Match:run; used to keep stacks synchronous in various scenarios
---@field TYPE string
---@field supportedStackOverConditions StackOverCondition[]
---@field supportedStackWinConditions StackWinCondition[]
---@field stackOverConditions table<StackOverCondition, any> Array of enumerated values signifying ways of going game over
---@field stackWinConditions table<StackWinCondition, any> Array of enumerated values signifying ways of ending the game without going game over

---@class BaseStack : Signal
local BaseStack = class(
---@param self BaseStack
function(self, args)
  assert(args.is_local ~= nil)
  assert(args.gameWinConditions)
  assert(args.gameOverConditions)
  self.engineVersion = args.engineVersion
  self.which = args.which or 1
  self.is_local = args.is_local

  for _, gameOverCondition in ipairs(args.gameOverConditions) do
    if not self:supportsGameOverCondition(gameOverCondition) then
      error(self.TYPE .. " does not support game over condition " .. gameOverCondition)
    end
  end

  for _, gameWinCondition in ipairs(args.gameWinConditions) do
    if not self:supportsGameWinCondition(gameWinCondition) then
      error(self.TYPE .. " does not support game win condition " .. gameWinCondition)
    end
  end

  self.stackOverConditions = args.gameOverConditions
  self.stackWinConditions = args.gameWinConditions

  -- basics
  self.framesBehindArray = {}
  self.framesBehind = 0
  self.clock = 0
  self.game_over_clock = -1 -- the exact clock frame the stack lost, -1 while alive
  Signal.turnIntoEmitter(self)
  self:createSignal("gameOver")
  self:createSignal("finishedRun")
  self:createSignal("rollbackPerformed")
  self:createSignal("rollbackSaved")

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

BaseStack.TYPE = "BaseStack"
BaseStack.supportedStackOverConditions = { GameModes.StackOverConditions.HEALTH }
BaseStack.supportedStackWinConditions = {}

---@param enable boolean
function BaseStack:enableCatchup(enable)
  self.play_to_end = enable
end

---@param matchClock integer
function BaseStack:updateFramesBehind(matchClock)
  local framesBehind = matchClock - self.clock
  self.framesBehindArray[matchClock] = framesBehind
  self.framesBehind = framesBehind
end

---@return integer
function BaseStack:getOldestFinishedGarbageTransitTime()
  return self.outgoingGarbage:getOldestFinishedTransitTime()
end

---@param clock integer
function BaseStack:getReadyGarbageAt(clock)
  return self.outgoingGarbage:popFinishedTransitsAt(clock)
end

function BaseStack:receiveGarbage(garbageDelivery)
  self.incomingGarbage:pushTable(garbageDelivery)
end

---@param doCountdown boolean
function BaseStack:setCountdown(doCountdown)
  self.do_countdown = doCountdown
end

---@param maxRunsPerFrame integer
function BaseStack:setMaxRunsPerFrame(maxRunsPerFrame)
  self.max_runs_per_frame = maxRunsPerFrame
end

---@return boolean
function BaseStack:behindRollback()
  if self.lastRollbackFrame > self.clock then
    return true
  end

  return false
end

---@param gameOverCondition GameOverConditions
---@return boolean
function BaseStack:supportsGameOverCondition(gameOverCondition)
  for _, enum in ipairs(self.supportedStackOverConditions) do
    if gameOverCondition == enum then
      return true
    end
  end

  return false
end

---@param gameWinCondition GameWinConditions
---@return boolean
function BaseStack:supportsGameWinCondition(gameWinCondition)
  for _, enum in ipairs(self.supportedStackWinConditions) do
    if gameWinCondition == enum then
      return true
    end
  end

  return false
end

function BaseStack:saveForRollback()
  error("did not implement saveForRollback")
end

---@param frame integer the frame to rollback to if possible
---@return boolean success if rolling back succeeded
function BaseStack:rollbackToFrame(frame)
  error("did not implement rollbackToFrame")
end

---@param frame integer the frame to rewind to if possible
---@return boolean success if rewinding succeeded
function BaseStack:rewindToFrame(frame)
  error("did not implement rewindToFrame")
end

function BaseStack:starting_state()
  error("did not implement starting_state")
end

---@return boolean
function BaseStack:game_ended()
  error("did not implement game_ended")
end

---@param runsSoFar integer how many runs the Stack already did this frame
---@return boolean
function BaseStack:shouldRun(runsSoFar)
  error("did not implement shouldRun")
end

function BaseStack:run()
  error("did not implement run")
end

function BaseStack:runGameOver()
  error("did not implement runGameOver")
end

return BaseStack