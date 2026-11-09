local class = require("common.lib.class")
local RingBuffer = require("common.lib.RingBuffer")

-- How many samples the recent average covers, one per server ping
local RECENT_SAMPLES = 10

-- Tracks round trip samples of one connection: the latest, an average of the recent ones, and how much they jitter
-- Jitter follows TCP's round trip variation (RFC 6298), so one slow sample nudges it instead of replacing it
---@class PingStats
---@field latest number? the round trip measured last, in milliseconds, nil before the first sample
---@field recent RingBuffer the last RECENT_SAMPLES round trips in milliseconds
---@field smoothed number? smoothed round trip in milliseconds that jitter is measured from, nil before the first sample
---@field variation number smoothed difference between samples and the smoothed round trip, in milliseconds
---@overload fun(): PingStats
local PingStats = class(function(self)
  self.latest = nil
  self.recent = RingBuffer(RECENT_SAMPLES)
  self.smoothed = nil
  self.variation = 0
end)

PingStats.RECENT_SAMPLES = RECENT_SAMPLES
-- How far each sample moves the smoothed round trip
PingStats.SMOOTHING = 1 / 8
-- How far each sample moves the jitter
PingStats.JITTER_SMOOTHING = 1 / 4

-- Records a round trip: the first one seeds the smoothed round trip, later ones move it and the jitter towards them
---@param milliseconds number a round trip sample
function PingStats:addSample(milliseconds)
  if self.smoothed == nil then
    self.smoothed = milliseconds
  else
    self.variation = self.variation + PingStats.JITTER_SMOOTHING * (math.abs(self.smoothed - milliseconds) - self.variation)
    self.smoothed = self.smoothed + PingStats.SMOOTHING * (milliseconds - self.smoothed)
  end
  self.latest = milliseconds
  self.recent:push(milliseconds)
end

---@return integer? # the round trip measured last in whole milliseconds, nil before the first sample
function PingStats:current()
  if self.latest then
    return math.round(self.latest)
  end
end

---@return integer? # the average of the last RECENT_SAMPLES round trips in whole milliseconds, nil before the first sample
function PingStats:recentAverage()
  local samples = self.recent.content
  if #samples > 0 then
    local total = 0
    for _, milliseconds in ipairs(samples) do
      total = total + milliseconds
    end
    return math.round(total / #samples)
  end
end

---@return integer? # how much the round trip varies, in whole milliseconds, nil before the first sample
function PingStats:jitter()
  if self.smoothed then
    return math.round(self.variation)
  end
end

---@alias PingNumbers { current: integer, average: integer, jitter: integer }
---@alias PingSummary { publicId: PublicPlayerID, current: integer, average: integer, jitter: integer }

---@return PingNumbers? # the numbers a ping update carries for this connection, nil before the first sample
function PingStats:summary()
  if self.latest then
    return {current = self:current(), average = self:recentAverage(), jitter = self:jitter()}
  end
end

return PingStats
