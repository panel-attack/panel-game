local class = require("common.lib.class")
local Signal = require("common.lib.signal")
local GarbageQueue = require("common.engine.GarbageQueue")
local RollbackBuffer = require("common.engine.RollbackBuffer")
local MatchRules = require("common.data.MatchRules")

---@class BaseStack : CanRollback
---@field engineVersion string
---@field which integer identifier of the Stack within the Match
---@field is_local boolean effectively if the Stack is receiving its inputs via local input
---@field framesBehindArray integer[] Records how far behind the stack was at each match clock time
---@field framesBehind integer How far behind the stack is at the current Match clock time
---@field clock integer how many times run has been called; this is equivalent to how many inputs have been processed;<br>This is the chief timer to measure synchronicity and the driver of rollback and inputs
---@field stopWatch integer how many times the game physics have run; unlike a clock and just like a stopWatch this frame timer only runs when the simulation is running
---@field stopWatchIsRunning boolean if the stack is running the game physics during runs
---@field game_over_clock integer What the clock time was when the Stack went game over
---@field do_countdown boolean if the stack is currently performing a countdown / will perform a countdown at the start of the match;<br> this is state, the value will change at the end of countdown
---@field countdown_timer boolean? ephemeral timer used for tracking countdown progress at the start of the game
---@field outgoingGarbage GarbageQueue
---@field incomingGarbage GarbageQueue
---@field rollbackBuffer RollbackBuffer A specialized class to manage memory for rollback data
---@field rollbackCount integer How many times the stack has been rolled back
---@field lastRollbackFrame integer the clock time before the Stack was last rolled back \n
--- -1 if it has not been rolled back yet (or should not run back to its pre-rollback frame)
---@field health integer Reaching 0 typically means game over (depends on the stackOverConditions)
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
  assert(args.stackWinConditions)
  assert(args.stackOverConditions)
  self.engineVersion = args.engineVersion
  self.which = args.which or 1
  self.is_local = args.is_local

  for stackOverCondition, _ in ipairs(args.stackOverConditions) do
    if not self:supportsGameOverCondition(stackOverCondition) then
      error(self.TYPE .. " does not support stack over condition " .. stackOverCondition)
    end
  end

  for stackWinCondition, _ in ipairs(args.stackWinConditions) do
    if not self:supportsGameWinCondition(stackWinCondition) then
      error(self.TYPE .. " does not support stack win condition " .. stackWinCondition)
    end
  end

  self.stackOverConditions = args.stackOverConditions
  self.stackWinConditions = args.stackWinConditions

  -- basics
  self.framesBehindArray = {}
  self.framesBehind = 0
  self.clock = 0
  self.stopWatch = 0
  self.stopWatchIsRunning = true
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
  self.rollbackBuffer = RollbackBuffer(MAX_LAG + 1)
  self.rollbackCount = 0
  self.lastRollbackFrame = -1 -- the last frame we had to rollback from
end)

BaseStack.TYPE = "BaseStack"
BaseStack.supportedStackOverConditions = { MatchRules.StackOverConditions.HEALTH }
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
  self.stopWatchIsRunning = not self.do_countdown
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

-- Saves state in backups in case its needed for rollback
-- NOTE: the clock time is the save state for simulating right BEFORE that clock time is simulated
function BaseStack:saveForRollback()
  local copy = self.rollbackBuffer:getOldest()
  if copy == nil then
    copy = {}
  end

  self:saveIntoRollbackCopy(copy)

  self.rollbackBuffer:saveCopy(self.clock, copy)
end

-- Restores the state saved for the clock frame from the rollback buffer
---@param clock integer the clock frame to rollback/rewind to if possible
---@param isRewind boolean whether this is a rewind operation
---@return boolean success if rolling back succeeded
function BaseStack:rollbackRewindToFrame(clock, isRewind)
  local copy = self.rollbackBuffer:rollbackToFrame(clock)
  if not copy then
    return false
  end

  self:restoreFromRollbackCopy(copy, clock, isRewind)

  return true
end

-- Writes the stack's state into copy
---@param copy table the table to save state into
function BaseStack:saveIntoRollbackCopy(copy)
  error("did not implement saveIntoRollbackCopy")
end

-- Restores the stack's state from copy
---@param copy table the table to restore state from
---@param clock integer the frame being restored to
---@param isRewind boolean whether this is a rewind operation
function BaseStack:restoreFromRollbackCopy(copy, clock, isRewind)
  error("did not implement restoreFromRollbackCopy")
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