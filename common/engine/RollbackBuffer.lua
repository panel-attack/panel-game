local class = require("common.lib.class")
require("table.new")

-- A specialized class that implements something like a ring buffer to facilitate the (memory) management of rollback copies
-- Precisely the goal is that components using rollback don't have to worry about pool management and deletion of stale copies
---@class RollbackBuffer
---@field size integer How many frames of rollback can be stored before the oldest is overwritten
---@field buffer table[] holds the copies
---@field frames integer[] tracks which frame number each buffer index refers to
---@field currentIndex integer The index of the next buffer entry to save to
local RollbackBuffer = class(function(ring, size)
  ring.size = size
  ring.buffer = table.new(size, 0)
  ring.frames = table.new(size, 0)
  ring.currentIndex = 1
end)

function RollbackBuffer:saveCopy(frame, copy)
  self.buffer[self.currentIndex] = copy
  self.frames[self.currentIndex] = frame

  self.currentIndex = self.currentIndex + 1

  if self.currentIndex > self.size then
    self.currentIndex = 1
  end
end

-- returns the oldest copy in the buffer or a stale one
-- returns nil if the buffer is not full yet
function RollbackBuffer:getOldest()
  return self.buffer[self.currentIndex]
end

-- rolls the buffer back to the specified frame and returns the data for the frame
-- returns nil if no data for the specified frame was found
function RollbackBuffer:rollbackToFrame(frame)
  if frame < 0 then
    error("Cannot rollback to negative frame numbers")
  elseif frame > self.frames[wrap(1, self.currentIndex - 1, self.size)] then
    -- target frame is greater than our most recent non-stale frame
    return nil
  elseif self.frames[self.currentIndex] and frame < self.frames[self.currentIndex] then
    -- self.frames[self.currentIndex] is verifiable the oldest copy we have (if we have one)
    -- so if it's greater than the request frame then the request frame is certainly too far in the past
    return nil
  end

  for i = 1, self.size do
    self.currentIndex = wrap(1, self.currentIndex - 1, self.size)
    if not self.frames[self.currentIndex] or self.frames[self.currentIndex] == -1 then
      -- we've reached an uninitialized or stale part of the buffer, that means there is no data to find further than here
      return nil
    elseif self.frames[self.currentIndex] > frame then
      -- mark the respective data as stale 
      self.frames[self.currentIndex] = -1
      -- but we keep the data because it is still allocated memory we wish to reuse
    elseif self.frames[self.currentIndex] == frame then
      local value = self.buffer[self.currentIndex]
      -- Keep the reference in the buffer so it can be rolled back to again
      -- The caller must copy data from this table, not store references to it
      -- Move currentIndex forward by one so next save goes to the right slot
      self.currentIndex = wrap(1, self.currentIndex + 1, self.size)
      return value
    elseif self.frames[self.currentIndex] < frame then
      -- we did not hit an early exit because we have copies older than the one requested
      -- but in fact we do not have the requested one
      -- e.g. when rollback goes on and off due to rubberbanding there will be gaps
      -- although realistically we always should have rollback copies whenever rollback could occur
      return nil
    end
  end
end

-- the copy stored for one specific frame, or nil if the buffer does not hold that frame
--
-- Looked up by frame rather than by position because rollbackToFrame moves currentIndex, so which
-- slot sits "before" the current one depends on whether a rollback just happened. A caller that
-- wants the frame before the one it is restoring to has to say so.
---@param frame integer
---@return table? copy
function RollbackBuffer:getCopyForFrame(frame)
  -- stale slots carry -1 in frames, so a negative lookup must never scan
  if frame < 0 then
    return nil
  end

  for i = 1, self.size do
    if self.frames[i] == frame then
      return self.buffer[i]
    end
  end

  return nil
end

---@return integer # how many usable rollback copies are stored in the buffer
function RollbackBuffer:getStoredCopyCount()
  local size = 0
  local index = self.currentIndex
  for i = 1, self.size do
    index = wrap(1, index - 1, self.size)

    if not self.frames[index] or self.frames[index] == -1 then
      return size
    end

    size = size + 1
  end

  return size
end

return RollbackBuffer