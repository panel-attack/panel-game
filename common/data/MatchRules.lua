---@class StackSetupModifications
---@field behaviours StackBehaviours?
---@field stopTime integer?
---@field shakeTime integer?
---@field startingRow integer?
---@field startingCol integer?

---@class MatchRules
---@field doCountdown boolean
---@field matchEndConditions table<MatchEndCondition, any>
---@field matchWinRuleset table<MatchWinCriteria, PlacementOrder>[]
---@field stackOverConditions table<StackOverCondition, any>
---@field stackWinConditions table<StackWinCondition, integer>
---@field stackSetupModifications StackSetupModifications

local MatchRules = {}

---@enum  MatchEndCondition
MatchRules.MatchEndConditions = { STACKS_ACTIVE = "STACKS_ACTIVE", TIME_LIMIT = "TIME_LIMIT" }

---@enum MatchWinCriteria
MatchRules.MatchWinCriterias = { GAME_OVER_CLOCK = "GAME_OVER_CLOCK", SCORE = "SCORE", TIME = "TIME" }

---@enum PlacementOrder
MatchRules.orders = { LOWEST = "LOWEST", HIGHEST = "HIGHEST" }

---@enum StackOverCondition
MatchRules.StackOverConditions = { HEALTH = "HEALTH", SWAPS = "SWAPS", CHAIN = "CHAIN" }

---@enum StackWinCondition
-- a stack wins once every condition it has holds: MATCHABLE_GARBAGE_PANELS once every block on the board is hit,
-- GARBAGE_BUFFER_EXCEEDED once a hit needs more garbage panels than the panel source's buffer holds;
-- clear puzzles no longer use MATCHABLE_GARBAGE_PANELS, it stays for the replays recorded with it
MatchRules.StackWinConditions = {
  MATCHABLE_PANELS = "MATCHABLE_PANELS",
  MATCHABLE_GARBAGE_PANELS = "MATCHABLE_GARBAGE_PANELS",
  GARBAGE_BUFFER_EXCEEDED = "GARBAGE_BUFFER_EXCEEDED",
  SCORE = "SCORE"
}

return MatchRules