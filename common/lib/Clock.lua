-- Clock.lua
--
-- Single abstraction for "what time is it?" Two surfaces, by intent:
--
--   * monotonicMs() / monotonicSeconds()
--       Forward-only clock for arbitration windows, watchdog deadlines,
--       elapsed-time math. Backed by socket.gettime with a forward-only
--       guard so an NTP slew (which can move socket.gettime BACKWARD)
--       can't make a window appear to close prematurely or never close.
--
--   * wallSeconds()
--       Wall-clock seconds since epoch. Backed by os.time. For replay
--       timestamps, ban-expiry comparisons against persisted timestamps,
--       human-facing display. NOT comparable across NTP slews.
--
-- DO NOT mix the two. If you're computing "how long since X?" use
-- monotonic. If you're stamping "this happened on date Y" or comparing
-- against a persisted os.time() value, use wall.
--
-- Production constructs one instance: GAME.clock on the client, the
-- Server's self.clockInstance on the server. Tests construct a mock
-- via Clock.mock() that returns user-controlled values.

local socket = require("common.lib.socket")

local Clock = {}
Clock.__index = Clock

---@class Clock
---@field _monoSource fun(): number   monotonic source (returns seconds)
---@field _wallSource fun(): integer  wall-clock source (returns seconds)
---@field _lastMonoSeconds number     forward-only guard

---Construct a real clock backed by socket.gettime + os.time. Pass nothing
---in production; pass `{ mono = ..., wall = ... }` in tests.
---@param sources {mono: fun():number, wall: fun():integer}?
---@return Clock
function Clock.new(sources)
  local self = setmetatable({}, Clock)
  sources = sources or {}
  self._monoSource = sources.mono or socket.gettime
  self._wallSource = sources.wall or os.time
  self._lastMonoSeconds = self._monoSource()
  return self
end

---Construct a Clock backed by a single user-controlled value. Tests use
---this to drive both surfaces from one mock. Mutate the returned table's
---`time` field to advance.
---@return Clock, {time: number}
function Clock.mock(initialSeconds)
  local state = { time = initialSeconds or 0 }
  local clock = Clock.new({
    mono = function() return state.time end,
    wall = function() return math.floor(state.time) end,
  })
  return clock, state
end

---Monotonic seconds. Forward-only: never returns less than the prior call.
---@return number
function Clock:monotonicSeconds()
  local now = self._monoSource()
  if now < self._lastMonoSeconds then
    -- NTP slew or test clock rewound — clamp forward. Production sees this
    -- at most a few times across an NTP correction; tests that rewind on
    -- purpose should construct a fresh mock instead.
    now = self._lastMonoSeconds
  else
    self._lastMonoSeconds = now
  end
  return now
end

---Monotonic milliseconds. Forward-only.
---@return integer
function Clock:monotonicMs()
  return math.floor(self:monotonicSeconds() * 1000)
end

---Wall-clock seconds since epoch. May jump (NTP, DST, system clock change).
---Use for stamping events, comparing against persisted os.time() values,
---and human-facing display ONLY.
---@return integer
function Clock:wallSeconds()
  return self._wallSource()
end

return Clock
