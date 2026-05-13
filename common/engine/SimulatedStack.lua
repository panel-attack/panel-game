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
    self:recordDeath()
  end

  self.stopWatch = self.stopWatch + 1
end

function SimulatedStack:recordDeath()
  if self.game_over_clock > 0 then
    return
  end
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

function SimulatedStack:saveForRollback()
  local copy

  if self.rollbackCopyPool:len() > 0 then
    copy = self.rollbackCopyPool:pop()
  else
    copy = {}
  end

  self.incomingGarbage:saveForRollback(self.stopWatch)

  if self.healthEngine then
    self.healthEngine:saveRollbackCopy()
  end

  if self.attackEngine then
    self.attackEngine:saveForRollback(self.stopWatch)
  end

  copy.health = self.health
  copy.stopWatch = self.stopWatch
  copy.game_over_clock = self.game_over_clock

  self.rollbackCopies[self.clock] = copy

  local deleteFrame = self.clock - MAX_LAG - 1
  if self.rollbackCopies[deleteFrame] then
    self.rollbackCopyPool:push(self.rollbackCopies[deleteFrame])
    self.rollbackCopies[deleteFrame] = nil
  end
end

local function internalRollbackToFrame(stack, clock)
  local copy = stack.rollbackCopies[clock]

  if copy and clock < stack.clock then
    for f = clock, stack.clock do
      if stack.rollbackCopies[f] then
        stack.rollbackCopyPool:push(stack.rollbackCopies[f])
        stack.rollbackCopies[f] = nil
      end
    end

    if stack.healthEngine then
      stack.healthEngine:rollbackToFrame(clock)
      stack.health = stack.healthEngine.framesToppedOutToLose
    else
      stack.health = copy.health
    end

    stack.stopWatch = copy.stopWatch
    stack.game_over_clock = copy.game_over_clock

    return true
  end

  return false
end

function SimulatedStack:rollbackToFrame(clock)
  if internalRollbackToFrame(self, clock) then
    self.incomingGarbage:rollbackToFrame(self.stopWatch)

    if self.attackEngine then
      self.attackEngine:rollbackToFrame(self.stopWatch)
    end

    self.lastRollbackFrame = self.clock
    self.clock = clock
    return true
  end

  return false
end

function SimulatedStack:rewindToFrame(clock)
  if internalRollbackToFrame(self, clock) then
    self.incomingGarbage:rewindToFrame(self.stopWatch)

    if self.attackEngine then
      self.attackEngine:rewindToFrame(self.stopWatch)
    end

    -- we did roll back but we want to stay here
    self.lastRollbackFrame = clock
    self.clock = clock
    return true
  end

  return false
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
