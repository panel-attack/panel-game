local logger = require("common.lib.logger")
local Health = require("common.engine.Health")
local BaseStack = require("common.engine.BaseStack")
local class = require("common.lib.class")
local consts = require("common.engine.consts")
local AttackEngine = require("common.engine.AttackEngine")

---@class SimulatedStack : BaseStack
---@field attackEngine AttackEngine
---@field healthEngine HealthEngine
-- A simulated stack sends attacks and takes damage from a player, it "loses" if it takes too many attacks.
local SimulatedStack = class(
function(self, args)
  self.max_runs_per_frame = 1
  self.health = 1

  if args.attackSettings then
    self:addAttackEngine(args.attackSettings)
  end
  if args.healthSettings then
    self:addHealth(args.healthSettings)
  end
end,
BaseStack)

SimulatedStack.TYPE = "SimulatedStack"

-- adds an attack engine to the simulated opponent
function SimulatedStack:addAttackEngine(attackSettings)
  self.attackEngine = AttackEngine(attackSettings, self.outgoingGarbage)

  return self.attackEngine
end

function SimulatedStack:addHealth(healthSettings)
  self.healthEngine = Health(healthSettings.framesToppedOutToLose, healthSettings.lineClearGPM, healthSettings.lineHeightToKill,
                             healthSettings.riseSpeed)
  self.health = healthSettings.framesToppedOutToLose
end

function SimulatedStack:run()
  if self.stopWatchIsRunning then
    self:runPhysics()
  elseif self.do_countdown and self.countdown_timer > 0 then
    if self.healthEngine then
      self.healthEngine.clock = self.clock
    end
    if self.clock >= consts.COUNTDOWN_START then
      self.countdown_timer = self.countdown_timer - 1
    end
    if self.countdown_timer == 0 then
      self.do_countdown = nil
      self.stopWatchIsRunning = true
    end
  else
    error("stopWatch of SimulatedStack is not running but neither is the countdown")
  end

  self.clock = self.clock + 1

  self:emitSignal("finishedRun")
end

function SimulatedStack:runPhysics()
  if self.attackEngine then
    self.attackEngine:run()
  end

  self.outgoingGarbage:processStagedGarbageForClock(self.stopWatch)

  if self.healthEngine then
    -- perform the equivalent of queued garbage being dropped
    -- except a little quicker than on real stacks
    for i = #self.incomingGarbage.stagedGarbage, 1, -1 do
      self.healthEngine:receiveGarbage(self.clock, self.incomingGarbage:pop())
    end

    self.health = self.healthEngine:run()
  end

  if self.health <= 0 then
    self:setGameOver()
  end

  self.stopWatch = self.stopWatch + 1
end

function SimulatedStack:setGameOver()
  self.game_over_clock = self.clock

  self:emitSignal("gameOver")
end

function SimulatedStack:shouldRun(runsSoFar)
  if self:game_ended() then
    return false
  end

  if self.lastRollbackFrame > self.clock then
    return true
  end

  -- a local automated stack shouldn't be falling behind
  if self.framesBehind > runsSoFar then
    return true
  end

  return runsSoFar < self.max_runs_per_frame
end

---@return integer
function SimulatedStack:getConfirmedInputCount()
  assert(false) -- Don't call this method for now, just exists for analyzer
  return 0
end

function SimulatedStack:game_ended()
  if self.game_over_clock > 0 then
    return self.clock >= self.game_over_clock
  else
    return false
  end
end

-- transfers the simulated stack state variables from source to destination (bidirectional)
---@param destination SimulatedStack|table
---@param source SimulatedStack|table
function SimulatedStack.transferStateVariables(destination, source)
  destination.clock = source.clock
  destination.health = source.health
  destination.stopWatch = source.stopWatch
  destination.game_over_clock = source.game_over_clock
  destination.countdown_timer = source.countdown_timer
  destination.do_countdown = source.do_countdown
  destination.stopWatchIsRunning = source.stopWatchIsRunning
end

-- writes the stack's state, and that of its garbage queue, health engine and attack engine, into copy
---@param copy table
function SimulatedStack:saveIntoRollbackCopy(copy)
  if copy.stackData == nil then
    copy.stackData = {}
    copy.incomingGarbageData = {}
    copy.healthEngineData = {}
    copy.attackEngineData = {}
  end

  self.incomingGarbage:saveIntoRollbackCopy(copy.incomingGarbageData)

  if self.healthEngine then
    self.healthEngine:saveIntoRollbackCopy(copy.healthEngineData)
  end

  if self.attackEngine then
    self.attackEngine:saveIntoRollbackCopy(copy.attackEngineData)
  end

  SimulatedStack.transferStateVariables(copy.stackData, self)
end

-- restores all engine state from the copy at the given frame
---@param copy table
---@param clock integer
---@param isRewind boolean
function SimulatedStack:restoreFromRollbackCopy(copy, clock, isRewind)
  local currentFrame = self.clock

  SimulatedStack.transferStateVariables(self, copy.stackData)

  if self.healthEngine then
    self.healthEngine:restoreFromRollbackCopy(copy.healthEngineData, clock, isRewind)
    self.health = self.healthEngine.framesToppedOutToLose
  end

  -- Note that garbage queue is based on game stopWatch, so we need to pass in those values which have been restored above
  self.incomingGarbage:restoreFromRollbackCopy(copy.incomingGarbageData, self.stopWatch, isRewind)

  if self.attackEngine then
    self.attackEngine:restoreFromRollbackCopy(copy.attackEngineData, self.stopWatch, isRewind)
  end

  if isRewind then
    -- we did roll back but we want to stay here
    self.lastRollbackFrame = clock
  else
    self.lastRollbackFrame = currentFrame
  end
end

function SimulatedStack:starting_state()
  if self.do_countdown then
    self.countdown_timer = consts.COUNTDOWN_LENGTH
  end
end

function SimulatedStack:getAttackPatternData()
  if self.attackEngine then
    return self.attackEngine.attackSettings
  end
end

return SimulatedStack
