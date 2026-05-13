-- smoothing.lua — math helpers for visually-smooth value transitions.
--
-- Two building blocks used by the view-stack catch-up pacing in
-- Stack:shouldRun:
--
--   smootherstep(t) — maps t ∈ [0,1] to a smooth eased value with zero
--     derivative AND zero second derivative at both endpoints. Used to
--     map a view-stack's input-buffer length to a target catch-up rate
--     so there are no abrupt threshold transitions ("at buffer=10 jump
--     from 1x to 2x"); instead the rate ramps smoothly across buffer
--     values.
--
--   smoothDamp(current, target, velocity, smoothTime, dt) — a critically-
--     damped spring (Unity's Mathf.SmoothDamp formula). Drives `current`
--     toward `target` over ~smoothTime seconds with no overshoot.
--     Used so the per-stack catch-up rate doesn't change abruptly when
--     the buffer length jumps — the rate visibly *eases* into a new
--     value rather than slamming, which keeps view-stack motion looking
--     natural during network blips.
--
-- Composing these (smootherstep for the target shape, smoothDamp for
-- the temporal response) gives view-stacks a smooth pacing on both axes:
-- the rate is a smooth function of buffer length, AND the rate-as-a-
-- function-of-time is smooth across buffer changes.

local M = {}

-- Smootherstep (Ken Perlin): 6t⁵ − 15t⁴ + 10t³. Clamped to [0,1] input.
-- Differs from smoothstep (3t² − 2t³) by being twice differentiable
-- at the endpoints, which removes a visible inflection when the curve
-- starts/ends animating.
---@param t number
---@return number
function M.smootherstep(t)
  t = math.max(0, math.min(1, t))
  return t * t * t * (t * (t * 6 - 15) + 10)
end

-- Default tunable: how many frames of buffer at which the catch-up rate
-- saturates to `maxRate`. Lower = more aggressive catch-up off small
-- lag; higher = gentler ramp. 29 (so buffer=1..30 maps to t=0..1) is a
-- reasonable default — view-stacks visibly speed up around the same
-- backlog threshold as the old bucket function (10-15 frames behind)
-- without the threshold being a hard step.
M.DEFAULT_RATE_SATURATION = 29

-- Map a view-stack's input-buffer length to a target catch-up rate.
-- buffer 0 → 0 (don't run; nothing to consume)
-- buffer 1 → 1 (steady state, real-time)
-- buffer DEFAULT_RATE_SATURATION+1 → maxRate (full catch-up)
-- Smooth in between via smootherstep so there's no threshold to oscillate
-- around.
---@param buffer_len integer
---@param maxRate number
---@return number rate desired ticks per Match:run cycle for this stack
function M.targetRate(buffer_len, maxRate)
  if buffer_len <= 0 then return 0 end
  local t = (buffer_len - 1) / M.DEFAULT_RATE_SATURATION
  return 1 + M.smootherstep(t) * (maxRate - 1)
end

-- Unity-style critically-damped SmoothDamp. Same coefficients as the
-- canonical Mathf.SmoothDamp / Vector3.SmoothDamp implementations:
-- a Taylor approximation of an exponential decay that's stable for any
-- positive smoothTime + dt. Doesn't overshoot.
---@param current number
---@param target number
---@param velocity number caller-owned; pass back next frame
---@param smoothTime number seconds for the value to "mostly" reach target
---@param dt number seconds since last call
---@return number newCurrent, number newVelocity
function M.smoothDamp(current, target, velocity, smoothTime, dt)
  smoothTime = math.max(0.0001, smoothTime)
  local omega = 2 / smoothTime
  local x = omega * dt
  -- Taylor-series approximation of e^(-x). Cheap enough that it doesn't
  -- matter; standard in game engines.
  local exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
  local change = current - target
  local temp = (velocity + omega * change) * dt
  local newVelocity = (velocity - omega * temp) * exp
  local newCurrent = target + (change + temp) * exp
  return newCurrent, newVelocity
end

return M
