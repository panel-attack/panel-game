local tableUtils = require("common.lib.tableUtils")

local engineConstants = {}

-- The values in this file are constants (except in this file perhaps) and are expected never to change during the game, not to be confused with globals!

engineConstants.ENGINE_VERSIONS = {}
engineConstants.ENGINE_VERSIONS.PRE_TELEGRAPH = "045"
engineConstants.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE = "046"
engineConstants.ENGINE_VERSIONS.TOUCH_COMPATIBLE = "047"
engineConstants.ENGINE_VERSIONS.LEVELDATA = "048"
engineConstants.ENGINE_VERSIONS.WIGGLE_PUNISH = "049"

engineConstants.ENGINE_VERSION = engineConstants.ENGINE_VERSIONS.WIGGLE_PUNISH -- The current engine version
engineConstants.VERSION_MIN_VIEW = engineConstants.ENGINE_VERSIONS.LEVELDATA -- The lowest version number that can be watched

engineConstants.COUNTDOWN_CURSOR_SPEED = 4 --one move every this many frames
engineConstants.COUNTDOWN_START = 8
engineConstants.COUNTDOWN_LENGTH = 180 --3 seconds at 60 fps

engineConstants.SCOREMODE_TA    = 1
engineConstants.SCOREMODE_PDP64 = 2 -- currently not used

-- Yes, 2 is slower than 1 and 50..99 are the same.
engineConstants.SPEED_TO_RISE_TIME = tableUtils.map(
   {942, 983, 838, 790, 755, 695, 649, 604, 570, 515,
    474, 444, 394, 370, 347, 325, 306, 289, 271, 256,
    240, 227, 213, 201, 189, 178, 169, 158, 148, 138,
    129, 120, 112, 105,  99,  92,  86,  82,  77,  73,
     69,  66,  62,  59,  56,  54,  52,  50,  48,  47,
     47,  47,  47,  47,  47,  47,  47,  47,  47,  47,
     47,  47,  47,  47,  47,  47,  47,  47,  47,  47,
     47,  47,  47,  47,  47,  47,  47,  47,  47,  47,
     47,  47,  47,  47,  47,  47,  47,  47,  47,  47,
     47,  47,  47,  47,  47,  47,  47,  47,  47},
     function(x) return x/16 end)

-- Stage clear seems to use a variant of vs mode's speed system,
-- except that the amount of time between increases is not constant.
-- on stage 1, the increases occur at increments of:
-- 20, 15, 15, 15, 10, 10, 10

return engineConstants