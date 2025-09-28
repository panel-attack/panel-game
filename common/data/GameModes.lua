local MatchRules = require("common.data.MatchRules")
local TIME_ATTACK_TIME = 120

local GameModes = {}

---@class GameMode
---@field stackInteraction StackInteractions
---@field matchRules MatchRules
---@field playerCount integer
---@field name string
--- the following properties should be strictly client side rather than universal
--- but since they're just magic strings without dependencies it's not like they ruin anything for now
---@field gameScene string
---@field style Styles
---@field richPresenceLabel string?

-- longterm we want to abandon the concept of "style" on the engine and room setup level
-- the engine only cares about levelData, style is a menu-only concept
-- there is no technical reason why someone on level 10 shouldn't be able to play against someone on Hard
-- meaning the props which scene uses which style should live on the scenes, not here
---@enum Styles
local Styles = { CHOOSE = 0, CLASSIC = 1, MODERN = 2}
---@enum StackInteractions
local StackInteractions = { NONE = 0, VERSUS = 1, SELF = 2, ATTACK_ENGINE = 3 }

---@type GameMode
local OnePlayerVsSelf = {
  style = Styles.MODERN,
  gameScene = "VsSelfGame",
  richPresenceLabel = "1p vs self", -- loc("mm_1_vs"),
  name = "vsSelf",

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteractions.SELF,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.STACKS_ACTIVE] = 0 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST} },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  }
}

---@type GameMode
local OnePlayerTimeAttack = {
  style = Styles.CHOOSE,
  gameScene = "TimeAttackGame",
  richPresenceLabel = "Time Attack", -- loc("mm_1_time"),
  name = "timeattack",

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteractions.NONE,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.STACKS_ACTIVE] = 0, [MatchRules.MatchEndConditions.TIME_LIMIT] = TIME_ATTACK_TIME * 60 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.SCORE] = MatchRules.orders.HIGHEST} },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  }
}

---@type GameMode
local OnePlayerEndless = {
  style = Styles.CHOOSE,
  gameScene = "EndlessGame",
  richPresenceLabel = "Endless", -- loc("mm_1_endless"),
  name = "endless",

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteractions.NONE,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.STACKS_ACTIVE] = 0 },
    matchWinRuleset = { {[MatchRules.MatchWinCriterias.SCORE] = MatchRules.orders.HIGHEST}, { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST} },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  }
}

---@type GameMode
local OnePlayerTraining = {
  style = Styles.MODERN,
  gameScene = "GameBase",
  richPresenceLabel = "Training", -- loc("mm_1_training"),
  name = "training",

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteractions.ATTACK_ENGINE,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.STACKS_ACTIVE] = 1 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST} },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  }
}

---@type GameMode
local OnePlayerPuzzle = {
  -- flags for battleRoom to evaluate and in some cases offer UI for
  style = Styles.MODERN,
  richPresenceLabel = "Puzzle", -- loc("mm_1_puzzle"),
  gameScene = "PuzzleGame",
  name = "puzzle",

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteractions.NONE,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.STACKS_ACTIVE] = 0 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.TIME] = MatchRules.orders.LOWEST} },
    -- these are extended based on the loaded puzzle
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    -- these are extended based on the loaded puzzle
    stackWinConditions = {},
    -- these are extended based on the loaded puzzle
    stackSetupModifications = {},
    doCountdown = false,
  }
}

---@type GameMode
local OnePlayerChallenge = {
  style = Styles.MODERN,
  gameScene = "Game1pChallenge",
  richPresenceLabel = "Challenge Mode", -- loc("mm_1_challenge_mode"),
  name = "challenge",

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteractions.VERSUS,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.STACKS_ACTIVE] = 1 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST} },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  }
}

---@type GameMode
local TwoPlayerVersus = {
  style = Styles.MODERN,
  gameScene = "GameBase",
  richPresenceLabel = "2p versus", -- loc("mm_2_vs"),
  name = "VS",

  -- already known match properties
  playerCount = 2,
  stackInteraction = StackInteractions.VERSUS,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.STACKS_ACTIVE] = 1 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST} },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true
  }
}
---@type GameMode
local TwoPlayerTimeAttack = {
  style = Styles.CHOOSE,
  gameScene = "TimeAttackGame",
  richPresenceLabel = "2p Time Attack", -- loc("mm_2_time"),
  name = "2p_timeattack",

  playerCount = 2,
  stackInteraction = StackInteractions.NONE, -- Cambia VERSUS por NONE
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.STACKS_ACTIVE] = 1, [MatchRules.MatchEndConditions.TIME_LIMIT] = TIME_ATTACK_TIME * 60},
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST }, { [MatchRules.MatchWinCriterias.SCORE] = MatchRules.orders.HIGHEST }},
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  }
}

GameModes.Styles = Styles
GameModes.StackInteractions = StackInteractions

---@type table<string, GameMode>
local privateGameModes = {}
privateGameModes.ONE_PLAYER_VS_SELF = OnePlayerVsSelf
privateGameModes.ONE_PLAYER_TIME_ATTACK = OnePlayerTimeAttack
privateGameModes.ONE_PLAYER_ENDLESS = OnePlayerEndless
privateGameModes.ONE_PLAYER_TRAINING = OnePlayerTraining
privateGameModes.ONE_PLAYER_PUZZLE = OnePlayerPuzzle
privateGameModes.ONE_PLAYER_CHALLENGE = OnePlayerChallenge
privateGameModes.TWO_PLAYER_VS = TwoPlayerVersus
privateGameModes.TWO_PLAYER_TIME_ATTACK = TwoPlayerTimeAttack

---@return GameMode
---@overload fun(mode: "ONE_PLAYER_VS_SELF"): GameMode
---@overload fun(mode: "ONE_PLAYER_TIME_ATTACK"): GameMode
---@overload fun(mode: "ONE_PLAYER_ENDLESS"): GameMode
---@overload fun(mode: "ONE_PLAYER_TRAINING"): GameMode
---@overload fun(mode: "ONE_PLAYER_PUZZLE"): GameMode
---@overload fun(mode: "ONE_PLAYER_CHALLENGE"): GameMode
---@overload fun(mode: "TWO_PLAYER_VS"): GameMode
---@overload fun(mode: "TWO_PLAYER_TIME_ATTACK"): GameMode
function GameModes.getPreset(mode)
  assert(privateGameModes[mode], "Trying to access non existing mode " .. mode)
  return deepcpy(privateGameModes[mode])
end

return GameModes
