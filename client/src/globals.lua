local consts = require("common.engine.consts")
score_mode = consts.SCOREMODE_TA

GARBAGE_TRANSIT_TIME = 45 -- the amount of time the garbage attack animation plays before getting to the telegraph
GARBAGE_TELEGRAPH_TIME = 45 -- the amount of time the garbage stays in the telegraph after getting there from the attack animation
GARBAGE_DELAY_LAND_TIME = 60 -- this is the amount of time after garbage leaves the telegraph before it can land on the opponent
						  -- a higher value allows less rollback to happen and makes lag have less of an impact on the game
						  -- technically this was 0 in classic games, but we are using this value to make rollback less noticable and match PA history
local defaultDesyncTolerance = 230
local configuredDesyncTolerance = config and tonumber(config.max_lag_frames)
if configuredDesyncTolerance and configuredDesyncTolerance >= 1 then
  MAX_LAG = math.floor(configuredDesyncTolerance)
else
  MAX_LAG = defaultDesyncTolerance + GARBAGE_TELEGRAPH_TIME + GARBAGE_TRANSIT_TIME -- maximum amount of lag before net games abort
end
NAME_LENGTH_LIMIT = 16

-- Loose-sync feature flags. Toggle off to fall back to the old implicit-sim
-- garbage delivery path for debugging / A-B comparison.
LOOSE_SYNC_GARBAGE = true

-- Loose-sync adaptive telegraph: minimum frames between G arrival on the
-- receiver and the resulting garbage actually landing on their board. Floor
-- for the adaptive landing-offset math in ClientMatch:applyGarbageEvent so the
-- receiver always sees a visible telegraph window even under terrible latency.
MIN_REACTION_FRAMES = 45

themes = {} -- initialized in theme.lua

THEME_DIRECTORY_PATH = "themes/"