local class = require("common.lib.class")
local ReplayCheckpointStore = require("client.src.ReplayCheckpointStore")

---@class ReplayCheckpoint
---@field clock integer
---@field gameOverClock integer?
---@field stacks table[]
---@field analytics table[]
---@field dangerMusic boolean[]

---@class ReplayPlayback
---@field match ClientMatch
---@field store ReplayCheckpointStore
---@field seekTarget integer?
---@overload fun(match: ClientMatch): ReplayPlayback
local ReplayPlayback = class(
---@param self ReplayPlayback
---@param match ClientMatch
function(self, match)
  assert(match.engine.clock == 0, "Replay seeking must be initialized before playback")
  self.match = match
  self.store = ReplayCheckpointStore(600)
  self:saveCheckpoint()
end)

---Captures synchronized engine and analytics state, without assets or rollback buffers.
function ReplayPlayback:saveCheckpoint()
  local engine = self.match.engine
  local checkpoint = {clock = engine.clock, gameOverClock = engine.gameOverClock, stacks = {}, analytics = {}, dangerMusic = {}}
  for i, stack in ipairs(self.match.stacks) do
    checkpoint.stacks[i] = {}
    stack.engine:saveIntoRollbackCopy(checkpoint.stacks[i])
    checkpoint.dangerMusic[i] = stack.danger_music
    if stack.analytic then
      local data = {used_combos = {}, reached_chains = {}}
      stack.analytic:saveIntoRollbackCopy(data)
      checkpoint.analytics[i] = data
    end
  end
  self.store:save(engine.clock, checkpoint)
end

---Runs one ordinary playback frame and checkpoints newly visited intervals.
function ReplayPlayback:run()
  self.match:run()
  local clock = self.match.engine.clock
  if clock == self.store.latestFrame + self.store.interval then
    self:saveCheckpoint()
  end
end

---Restores a checkpoint into existing stacks, reusing their allocated rollback tables.
---@param checkpoint ReplayCheckpoint
function ReplayPlayback:restoreCheckpoint(checkpoint)
  local engine = self.match.engine
  engine.clock = checkpoint.clock
  engine.gameOverClock = checkpoint.gameOverClock
  engine.ended = false
  engine.aborted = false
  engine.desyncError = nil
  engine.winners = nil
  self.match.ended = false
  self.match.winners = nil

  for i, stack in ipairs(self.match.stacks) do
    local clock = checkpoint.stacks[i].stackData.clock
    stack.danger_music = checkpoint.dangerMusic[i]
    stack.engine.rollbackBuffer:clear()
    if stack.analytic then
      stack.analytic.rollbackBuffer:clear()
      stack.analytic:restoreFromRollbackCopy(checkpoint.analytics[i], clock, true)
      -- The engine's rollback signal expects analytics to have a copy for this frame.
      stack.analytic:saveForRollback(clock)
    end
    stack.engine:restoreFromRollbackCopy(checkpoint.stacks[i], clock, true)
    stack.engine.framesBehind = checkpoint.clock - clock
    if stack.analytic then
      stack.analytic.rollbackBuffer:clear()
    end
    stack.engine:saveForRollback()
  end
end

---Uses recent snapshots when available; otherwise reconstructs a preceding window from disk.
---@param frame integer
function ReplayPlayback:rewindToFrame(frame)
  frame = math.max(0, frame)
  assert(frame <= self.match.engine.clock, "Cannot rewind into the future")
  local available = true
  for _, stack in ipairs(self.match.stacks) do
    if not stack.engine.rollbackBuffer:getCopyForFrame(frame) then
      available = false
      break
    end
  end
  if available then
    self.match:rewindToFrame(frame)
    self.match.ended = false
    self.match.winners = nil
    self.match.engine.winners = nil
    self.match.engine.gameOverClock = nil
    return
  end

  self.seekTarget = frame
  for _, stack in ipairs(self.match.stacks) do
    stack.isSeeking = true
    if stack.clearReplayEffects then
      stack:clearReplayEffects()
    end
  end
  -- Refill the existing ring as well as reaching the target, so each backward step
  -- does not require another seek when the target happens to be a checkpoint.
  local window = self.match.stacks[1].engine.rollbackBuffer.size - 1
  self:restoreCheckpoint(self.store:load(math.max(0, frame - window)))
end

---Reconstructs in bounded batches; no ClientMatch end/countdown callbacks run during seeking.
---@param budget number? maximum simulation time in seconds per update
---@return boolean finished
function ReplayPlayback:updateSeek(budget)
  if not self.seekTarget then
    return true
  end
  local engine = self.match.engine
  local deadline = love.timer.getTime() + (budget or 0.004)
  local runs = 0
  while engine.clock < self.seekTarget and runs < 240 and love.timer.getTime() < deadline do
    local previousClock = engine.clock
    assert(not engine:hasEnded(), "Replay ended before the seek target")
    engine:run()
    assert(engine.clock > previousClock, "Replay reconstruction did not advance")
    runs = runs + 1
  end
  if engine.clock < self.seekTarget then
    return false
  end

  self.seekTarget = nil
  for _, stack in ipairs(self.match.stacks) do
    stack.isSeeking = false
    if stack.clearReplayEffects then
      stack:clearReplayEffects()
      stack:updateDangerMusic()
    end
  end
  self.match:updateDangerMusic()
  return true
end

---Releases this session's temporary checkpoints.
function ReplayPlayback:close()
  self.store:close()
  for _, stack in ipairs(self.match.stacks) do
    stack.isSeeking = false
  end
end

return ReplayPlayback
