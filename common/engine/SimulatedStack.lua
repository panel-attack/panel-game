local logger = require("common.lib.logger")
local Health = require("common.engine.Health")
local BaseStack = require("common.engine.BaseStack")
local class = require("common.lib.class")
local consts = require("common.engine.consts")
local AttackEngine = require("common.engine.AttackEngine")
local ReplayPlayer = require("common.data.ReplayPlayer")

---@class SimulatedStack : BaseStack
---@field attackEngine table
---@field healthEngine table

-- A simulated stack sends attacks and takes damage from a player, it "loses" if it takes too many attacks.
local SimulatedStack = class(
function(self, args)
  self.max_runs_per_frame = 1

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
  if self.attackEngine then
    self.attackEngine:run()
  end

  self.outgoingGarbage:processStagedGarbageForClock(self.clock)

  if self.do_countdown and self.countdown_timer > 0 then
    if self.healthEngine then
      self.healthEngine.clock = self.clock
    end
    if self.clock >= consts.COUNTDOWN_START then
      self.countdown_timer = self.countdown_timer - 1
    end
  else
    if self.healthEngine then
      -- perform the equivalent of queued garbage being dropped
      -- except a little quicker than on real stacks
      for i = #self.incomingGarbage.stagedGarbage, 1, -1 do
        self.healthEngine:receiveGarbage(self.clock, self.incomingGarbage:pop())
      end

      self.health = self.healthEngine:run()
      if self.health <= 0 then
        self:setGameOver()
      end
    end
  end

  self.clock = self.clock + 1

  self:emitSignal("finishedRun")
end

function SimulatedStack:setGameOver()
  self.game_over_clock = self.clock

  SoundController:playSfx(themes[config.theme].sounds.game_over)
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

function SimulatedStack:game_ended()
  if self.healthEngine then
    if self.health <= 0 and self.game_over_clock < 0 then
      self.game_over_clock = self.clock
    end
  end

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

  self.incomingGarbage:rollbackCopy(self.clock)

  if self.healthEngine then
    self.healthEngine:saveRollbackCopy()
  end

  if self.attackEngine then
    self.attackEngine:rollbackCopy(self.clock)
  end

  copy.health = self.health

  self.rollbackCopies[self.clock] = copy

  local deleteFrame = self.clock - MAX_LAG - 1
  if self.rollbackCopies[deleteFrame] then
    self.rollbackCopyPool:push(self.rollbackCopies[deleteFrame])
    self.rollbackCopies[deleteFrame] = nil
  end
end

local function internalRollbackToFrame(stack, frame)
  local copy = stack.rollbackCopies[frame]

  if copy and frame < stack.clock then
    for f = frame, stack.clock do
      if stack.rollbackCopies[f] then
        stack.rollbackCopyPool:push(stack.rollbackCopies[f])
        stack.rollbackCopies[f] = nil
      end
    end

    if stack.healthEngine then
      stack.healthEngine:rollbackToFrame(frame)
      stack.health = stack.healthEngine.framesToppedOutToLose
    else
      stack.health = copy.health
    end

    return true
  end

  return false
end

function SimulatedStack:rollbackToFrame(frame)
  if internalRollbackToFrame(self, frame) then
    self.incomingGarbage:rollbackToFrame(frame)

    if self.attackEngine then
      self.attackEngine:rollbackToFrame(frame)
    end

    self.lastRollbackFrame = self.clock
    self.clock = frame
    return true
  end

  return false
end

function SimulatedStack:rewindToFrame(frame)
  if internalRollbackToFrame(self, frame) then
    self.incomingGarbage:rewindToFrame(frame)

    if self.attackEngine then
      self.attackEngine:rewindToFrame(frame)
    end

    self.clock = frame
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

function SimulatedStack:toReplayPlayer()
  local replayPlayer = ReplayPlayer("Player " .. self.which, - self.which)

  replayPlayer:setAttackEngineSettings(self.attackEngineSettings)
  replayPlayer:setHealthSettings(self.healthSettings)

  return replayPlayer
end

---@param replayPlayer ReplayPlayer
---@param replay Replay
---@return SimulatedStack
function SimulatedStack.createFromReplayPlayer(replayPlayer, replay)
-- TODO
  return SimulatedStack({})
end

return SimulatedStack
