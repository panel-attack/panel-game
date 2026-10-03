local RollbackBuffer = require("common.engine.RollbackBuffer")

local function testNormalRollback()
  local buffer = RollbackBuffer(250)

  for i = 1, 300 do
    buffer:saveCopy(i, { i = i})
  end

  local rollbackCopy = buffer:rollbackToFrame(147)
  assert(rollbackCopy, "Should have been able to rollback 103 frames")
  assert(rollbackCopy.i == 147, "Rolled back to frame " .. rollbackCopy.i .. " instead of 147")
end

local function testStaleMarking()
  local buffer = RollbackBuffer(250)

  for i = 1, 300 do
    buffer:saveCopy(i, { i = i})
  end

  local rollbackCopy = buffer:rollbackToFrame(147)
  rollbackCopy = buffer:rollbackToFrame(150)
  assert(rollbackCopy == nil, "Rollback copies in the future should no longer be available via the accessor")
  rollbackCopy = buffer.buffer[buffer.currentIndex + 3]
  assert(rollbackCopy, "copies for stale frames should not get discarded")
  assert(rollbackCopy.i, "the copy for frame 150 should still be available here, instead it is the copy for " .. rollbackCopy.i)
end

local function testFrameTooOld()
  local buffer = RollbackBuffer(250)

  for i = 1, 300 do
    buffer:saveCopy(i, { i = i})
  end

  local rollbackCopy = buffer:rollbackToFrame(20)
  assert(rollbackCopy == nil, "Buffer should have only saved the last 250 copies")
end

local function testPostRollbackWrite()
  local buffer = RollbackBuffer(245)

  for i = 1, 500 do
    local copy = buffer:getOldest() or {}
    copy.i = i
    buffer:saveCopy(i, copy)
  end

  local rollbackCopy = buffer:rollbackToFrame(463)
  assert(rollbackCopy, "Expected to have a rollback copy for frame 463 but did not")
  assert(rollbackCopy.i == 463, "Expected to find a rollback copy with i = 463 but got i = " .. rollbackCopy.i)
  for i = rollbackCopy.i + 1, 500 do
    local copy = buffer:getOldest() or {}
    copy.i = i
    buffer:saveCopy(i, copy)
  end

  local expected = 500
  local currentIndex = buffer.currentIndex
  for i = 1, buffer.size do
    currentIndex = wrap(1, currentIndex - 1, buffer.size)
    assert(buffer.buffer[currentIndex].i == expected,
    "Expected " .. expected .. " at position " .. currentIndex
    .. " but got " .. buffer.buffer[currentIndex].i .. " instead")
    expected = expected - 1
  end
end

testNormalRollback()
testStaleMarking()
testFrameTooOld()
testPostRollbackWrite()
-- Looking a frame up has to be independent of where a rollback left currentIndex, because the one
-- caller wants the frame before the one it just rolled back to and rollbackToFrame moves the index
-- forward past the match.
local function testCopyLookupByFrame()
  local buffer = RollbackBuffer(250)

  for i = 1, 300 do
    buffer:saveCopy(i, { i = i })
  end

  assert(buffer:getCopyForFrame(147).i == 147, "the copy for frame 147 was not found by frame")
  assert(buffer:getCopyForFrame(20) == nil, "a frame that fell out of the buffer was still found")
  assert(buffer:getCopyForFrame(301) == nil, "a frame that was never saved was still found")

  local rolledBackTo = buffer:rollbackToFrame(147)
  assert(rolledBackTo.i == 147)
  assert(buffer:getCopyForFrame(146).i == 146, "the frame before the rollback target was not found")
  assert(buffer:getCopyForFrame(147).i == 147, "the rollback target itself stopped being findable")
  assert(buffer:getCopyForFrame(148) == nil, "a frame marked stale by the rollback was still found")
end

testCopyLookupByFrame()

-- stale slots are marked with -1 in frames, so asking for frame -1 (what a restore to frame 0 does
-- for its "previous frame") must not hand back whatever copy last went stale
local function testCopyLookupNeverMatchesStaleMarker()
  local buffer = RollbackBuffer(250)

  for i = 0, 10 do
    buffer:saveCopy(i, { i = i })
  end

  assert(buffer:rollbackToFrame(0).i == 0)
  assert(buffer:getCopyForFrame(-1) == nil, "a stale slot was returned for frame -1")
end

testCopyLookupNeverMatchesStaleMarker()

local function testRollbackToTheSameFrameTwice()
  local buffer = RollbackBuffer(250)

  for i = 1, 200 do
    buffer:saveCopy(i, { i = i })
  end

  local first = buffer:rollbackToFrame(150)
  assert(first and first.i == 150, "Expected a rollback copy for frame 150 but did not get one")

  for i = 151, 170 do
    local copy = buffer:getOldest() or {}
    copy.i = i
    buffer:saveCopy(i, copy)
  end

  local second = buffer:rollbackToFrame(150)
  assert(second, "Expected to be able to rollback to frame 150 a second time")
  assert(second.i == 150, "Rolled back to frame " .. second.i .. " instead of 150")
end

testRollbackToTheSameFrameTwice()

-- rewinding steps back a frame at a time so every copy it hands out has to stay available for reuse
local function testRewindKeepsItsStorage()
  local buffer = RollbackBuffer(250)

  for i = 1, 250 do
    buffer:saveCopy(i, { i = i })
  end

  for frame = 249, 200, -1 do
    local copy = buffer:rollbackToFrame(frame)
    assert(copy, "Expected a rollback copy for frame " .. frame .. " but did not get one")
    assert(copy.i == frame, "Rolled back to frame " .. copy.i .. " instead of " .. frame)
  end

  local reusable = 0
  for i = 1, buffer.size do
    if buffer.buffer[i] then
      reusable = reusable + 1
    end
  end

  assert(reusable == 250, "Expected all 250 copies to still be allocated but only " .. reusable .. " were")
end

testRewindKeepsItsStorage()
