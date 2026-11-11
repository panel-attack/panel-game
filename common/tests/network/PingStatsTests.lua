local PingStats = require("common.network.PingStats")

local function testTheFirstSampleIsTheCurrentPing()
  local stats = PingStats()
  assert(stats:current() == nil, "there should be no ping before any sample")

  stats:addSample(80)

  assert(stats:current() == 80, "the first sample should be the current ping, got " .. tostring(stats:current()))
  assert(stats:jitter() == 0, "one sample has no jitter, got " .. tostring(stats:jitter()))
end

testTheFirstSampleIsTheCurrentPing()

local function testJitterMovesAQuarterOfTheWayToEachSamplesDifference()
  local stats = PingStats()
  stats:addSample(80)

  stats:addSample(160)

  assert(stats:jitter() == 20, "jitter should move a quarter of the way to the 80 ms difference, got " .. tostring(stats:jitter()))
end

testJitterMovesAQuarterOfTheWayToEachSamplesDifference()

local function testTheRecentAverageCatchesUpWithinItsWindowAfterTheConnectionSlowsDown()
  local stats = PingStats()
  for _ = 1, 60 do
    stats:addSample(10)
  end

  for _ = 1, PingStats.RECENT_SAMPLES do
    stats:addSample(1500)
  end

  assert(stats:recentAverage() == 1500, "a window of only 1500 ms samples should average 1500 ms, got " .. tostring(stats:recentAverage()))
end

testTheRecentAverageCatchesUpWithinItsWindowAfterTheConnectionSlowsDown()

local function testTheRecentAverageAveragesTheSamplesInItsWindow()
  local stats = PingStats()
  stats:addSample(40)
  stats:addSample(61)

  assert(stats:recentAverage() == 51, "the average of 40 and 61 should round to 51, got " .. tostring(stats:recentAverage()))
end

testTheRecentAverageAveragesTheSamplesInItsWindow()

local function testTheCurrentPingIsTheLatestSample()
  local stats = PingStats()
  stats:addSample(10)

  stats:addSample(1500)

  assert(stats:current() == 1500, "the current ping should be the round trip just measured, got " .. tostring(stats:current()))
end

testTheCurrentPingIsTheLatestSample()
