local class = require("common.lib.class")
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
---@field updateLocalPlayersDerivedSettings function
---@field gameModeId GameModeID
local GameMode = class(function(self, properties)
  for key, value in pairs(properties) do
    self[key] = value
  end
end)

-- Returns a copy of the game mode data suitable for JSON serialization
-- Removes all methods/functions from the copied data
---@return table
function GameMode:getGameModeJSONData()
  local gameModeData = deepcpy(self)
  for key, value in pairs(gameModeData) do
    if type(value) == "function" then
      gameModeData[key] = nil
    end
  end
  return gameModeData
end

-- longterm we want to abandon the concept of "style" on the engine and room setup level
-- the engine only cares about levelData, style is a menu-only concept
-- there is no technical reason why someone on level 10 shouldn't be able to play against someone on Hard
-- meaning the props which scene uses which style should live on the scenes, not here
---@enum Styles
local Styles = { CHOOSE = 0, CLASSIC = 1, MODERN = 2}
---@enum StackInteractions
local StackInteractions = { NONE = 0, VERSUS = 1, SELF = 2, ATTACK_ENGINE = 3, TEAM_VERSUS = 4 }

---@type GameMode
local OnePlayerVsSelf = GameMode({
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
  },

})

---@type GameMode
local OnePlayerTimeAttack = GameMode({
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
  },

})

---@type GameMode
local OnePlayerEndless = GameMode({
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
  },

})

---@type GameMode
local OnePlayerTraining = GameMode({
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
  },

})

---@type GameMode
local OnePlayerPuzzle = GameMode({
  -- flags for battleRoom to evaluate and in some cases offer UI for
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
  },

})

---@type GameMode
local OnePlayerChallenge = GameMode({
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
  },

})

---@type GameMode
local TwoPlayerVersus = GameMode({
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
  },

})
---@type GameMode
local TwoPlayerTimeAttack = GameMode({
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
  },

})

---@type GameMode
local FourPlayerTeamVersusAll = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "2v2 Team VS (All)",
  name = "team_vs_all",

  playerCount = 4,
  teamCount = 2,
  playersPerTeam = 2,
  garbageMode = "all",
  stackInteraction = StackInteractions.TEAM_VERSUS,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.TEAMS_ACTIVE] = 1 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST } },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  },

})

---@type GameMode
local FourPlayerTeamVersusShared = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "2v2 Team VS (Shared)",
  name = "team_vs_shared",

  playerCount = 4,
  teamCount = 2,
  playersPerTeam = 2,
  garbageMode = "shared",
  stackInteraction = StackInteractions.TEAM_VERSUS,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.TEAMS_ACTIVE] = 1 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST } },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  },

})

---@type GameMode
local ThreePlayerVersusAll = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "1v2 VS (All)",
  name = "three_player_vs_all",

  playerCount = 3,
  teamCount = 2,
  playersPerTeam = {1, 2},  -- Asymmetric: 1 solo vs 2 team
  garbageMode = "all",
  stackInteraction = StackInteractions.TEAM_VERSUS,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.TEAMS_ACTIVE] = 1 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST } },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  },

})

---@type GameMode
local ThreePlayerVersusShared = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "1v2 VS (Shared)",
  name = "three_player_vs_shared",

  playerCount = 3,
  teamCount = 2,
  playersPerTeam = {1, 2},  -- Asymmetric: 1 solo vs 2 team
  garbageMode = "shared",
  stackInteraction = StackInteractions.TEAM_VERSUS,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.TEAMS_ACTIVE] = 1 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST } },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  },

})

---@type GameMode
-- Mirror of ThreePlayerVersusAll: the room creator (slot 1) lands on the
-- LEFT team, which is the team of 2. Use this when the label is "2 vs 1".
local ThreePlayerVersusAll_2v1 = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "2v1 VS (All)",
  name = "three_player_vs_all_2v1",

  playerCount = 3,
  teamCount = 2,
  playersPerTeam = {2, 1},
  garbageMode = "all",
  stackInteraction = StackInteractions.TEAM_VERSUS,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.TEAMS_ACTIVE] = 1 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST } },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  },
})

---@type GameMode
local ThreePlayerVersusShared_2v1 = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "2v1 VS (Shared)",
  name = "three_player_vs_shared_2v1",

  playerCount = 3,
  teamCount = 2,
  playersPerTeam = {2, 1},
  garbageMode = "shared",
  stackInteraction = StackInteractions.TEAM_VERSUS,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.TEAMS_ACTIVE] = 1 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST } },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  },
})

---@type GameMode
local ThreePlayerFFA = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "1v1v1 FFA",
  name = "3p_ffa",

  playerCount = 3,
  teamCount = 3,
  playersPerTeam = 1,
  garbageMode = "all",
  stackInteraction = StackInteractions.TEAM_VERSUS,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.TEAMS_ACTIVE] = 1 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST } },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  },
})

---@type GameMode
local FourPlayerFFA = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "1v1v1v1 FFA",
  name = "4p_ffa",

  playerCount = 4,
  teamCount = 4,
  playersPerTeam = 1,
  garbageMode = "all",
  stackInteraction = StackInteractions.TEAM_VERSUS,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.TEAMS_ACTIVE] = 1 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST } },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  },
})

---@type GameMode
local FivePlayerFFA = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "1v1v1v1v1 FFA",
  name = "5p_ffa",

  playerCount = 5,
  teamCount = 5,
  playersPerTeam = 1,
  garbageMode = "all",
  stackInteraction = StackInteractions.TEAM_VERSUS,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.TEAMS_ACTIVE] = 1 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST } },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  },
})

---@type GameMode
local FivePlayerTeamVs1v4All = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "1v4 VS (All)",
  name = "five_player_1v4_all",

  playerCount = 5,
  teamCount = 2,
  playersPerTeam = {1, 4},
  garbageMode = "all",
  stackInteraction = StackInteractions.TEAM_VERSUS,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.TEAMS_ACTIVE] = 1 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST } },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  },
})

---@type GameMode
local FivePlayerTeamVs1v4Shared = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "1v4 VS (Shared)",
  name = "five_player_1v4_shared",

  playerCount = 5,
  teamCount = 2,
  playersPerTeam = {1, 4},
  garbageMode = "shared",
  stackInteraction = StackInteractions.TEAM_VERSUS,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.TEAMS_ACTIVE] = 1 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST } },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  },
})

---@type GameMode
local FivePlayerTeamVs2v3All = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "2v3 VS (All)",
  name = "five_player_2v3_all",

  playerCount = 5,
  teamCount = 2,
  playersPerTeam = {2, 3},
  garbageMode = "all",
  stackInteraction = StackInteractions.TEAM_VERSUS,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.TEAMS_ACTIVE] = 1 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST } },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  },
})

---@type GameMode
local FivePlayerTeamVs2v3Shared = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "2v3 VS (Shared)",
  name = "five_player_2v3_shared",

  playerCount = 5,
  teamCount = 2,
  playersPerTeam = {2, 3},
  garbageMode = "shared",
  stackInteraction = StackInteractions.TEAM_VERSUS,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.TEAMS_ACTIVE] = 1 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST } },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  },
})

-- Reversed-orientation 5p team modes: room creator lands on the LEFT team,
-- which is the BIGGER team for "4 vs 1" and "3 vs 2".
---@type GameMode
local FivePlayerTeamVs4v1All = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "4v1 VS (All)",
  name = "five_player_4v1_all",

  playerCount = 5,
  teamCount = 2,
  playersPerTeam = {4, 1},
  garbageMode = "all",
  stackInteraction = StackInteractions.TEAM_VERSUS,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.TEAMS_ACTIVE] = 1 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST } },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  },
})

---@type GameMode
local FivePlayerTeamVs4v1Shared = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "4v1 VS (Shared)",
  name = "five_player_4v1_shared",

  playerCount = 5,
  teamCount = 2,
  playersPerTeam = {4, 1},
  garbageMode = "shared",
  stackInteraction = StackInteractions.TEAM_VERSUS,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.TEAMS_ACTIVE] = 1 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST } },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  },
})

---@type GameMode
local FivePlayerTeamVs3v2All = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "3v2 VS (All)",
  name = "five_player_3v2_all",

  playerCount = 5,
  teamCount = 2,
  playersPerTeam = {3, 2},
  garbageMode = "all",
  stackInteraction = StackInteractions.TEAM_VERSUS,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.TEAMS_ACTIVE] = 1 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST } },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  },
})

---@type GameMode
local FivePlayerTeamVs3v2Shared = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "3v2 VS (Shared)",
  name = "five_player_3v2_shared",

  playerCount = 5,
  teamCount = 2,
  playersPerTeam = {3, 2},
  garbageMode = "shared",
  stackInteraction = StackInteractions.TEAM_VERSUS,
  matchRules = {
    matchEndConditions = { [MatchRules.MatchEndConditions.TEAMS_ACTIVE] = 1 },
    matchWinRuleset = { { [MatchRules.MatchWinCriterias.GAME_OVER_CLOCK] = MatchRules.orders.HIGHEST } },
    stackOverConditions = { [MatchRules.StackOverConditions.HEALTH] = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = true,
  },
})

GameModes.Styles = Styles
GameModes.StackInteractions = StackInteractions

---@enum (key) GameModeID Used as identifier for the type of game that is being played
GameModes.IDs = {
  TWO_PLAYER_VS = "TWO_PLAYER_VS",
  ONE_PLAYER_TIME_ATTACK = "ONE_PLAYER_TIME_ATTACK",
  ONE_PLAYER_ENDLESS = "ONE_PLAYER_ENDLESS",
  ONE_PLAYER_TRAINING = "ONE_PLAYER_TRAINING",
  ONE_PLAYER_CHALLENGE = "ONE_PLAYER_CHALLENGE",
  ONE_PLAYER_VS_SELF = "ONE_PLAYER_VS_SELF",
  ONE_PLAYER_PUZZLE = "ONE_PLAYER_PUZZLE",
  TWO_PLAYER_TIME_ATTACK = "TWO_PLAYER_TIME_ATTACK",
  -- Team game modes
  FOUR_PLAYER_TEAM_VS_ALL = "FOUR_PLAYER_TEAM_VS_ALL",
  FOUR_PLAYER_TEAM_VS_SHARED = "FOUR_PLAYER_TEAM_VS_SHARED",
  THREE_PLAYER_VS_ALL = "THREE_PLAYER_VS_ALL",
  THREE_PLAYER_VS_SHARED = "THREE_PLAYER_VS_SHARED",
  THREE_PLAYER_VS_ALL_2V1 = "THREE_PLAYER_VS_ALL_2V1",
  THREE_PLAYER_VS_SHARED_2V1 = "THREE_PLAYER_VS_SHARED_2V1",
  -- Free-for-all modes
  THREE_PLAYER_FFA = "THREE_PLAYER_FFA",
  FOUR_PLAYER_FFA = "FOUR_PLAYER_FFA",
  FIVE_PLAYER_FFA = "FIVE_PLAYER_FFA",
  -- 5-player team modes
  FIVE_PLAYER_1V4_ALL = "FIVE_PLAYER_1V4_ALL",
  FIVE_PLAYER_1V4_SHARED = "FIVE_PLAYER_1V4_SHARED",
  FIVE_PLAYER_4V1_ALL = "FIVE_PLAYER_4V1_ALL",
  FIVE_PLAYER_4V1_SHARED = "FIVE_PLAYER_4V1_SHARED",
  FIVE_PLAYER_2V3_ALL = "FIVE_PLAYER_2V3_ALL",
  FIVE_PLAYER_2V3_SHARED = "FIVE_PLAYER_2V3_SHARED",
  FIVE_PLAYER_3V2_ALL = "FIVE_PLAYER_3V2_ALL",
  FIVE_PLAYER_3V2_SHARED = "FIVE_PLAYER_3V2_SHARED",
}

---@type table<GameModeID, GameMode>
local privateGameModes = {}
privateGameModes[GameModes.IDs.ONE_PLAYER_VS_SELF] = OnePlayerVsSelf
privateGameModes[GameModes.IDs.ONE_PLAYER_TIME_ATTACK] = OnePlayerTimeAttack
privateGameModes[GameModes.IDs.ONE_PLAYER_ENDLESS] = OnePlayerEndless
privateGameModes[GameModes.IDs.ONE_PLAYER_TRAINING] = OnePlayerTraining
privateGameModes[GameModes.IDs.ONE_PLAYER_PUZZLE] = OnePlayerPuzzle
privateGameModes[GameModes.IDs.ONE_PLAYER_CHALLENGE] = OnePlayerChallenge
privateGameModes[GameModes.IDs.TWO_PLAYER_VS] = TwoPlayerVersus
privateGameModes[GameModes.IDs.TWO_PLAYER_TIME_ATTACK] = TwoPlayerTimeAttack
privateGameModes[GameModes.IDs.FOUR_PLAYER_TEAM_VS_ALL] = FourPlayerTeamVersusAll
privateGameModes[GameModes.IDs.FOUR_PLAYER_TEAM_VS_SHARED] = FourPlayerTeamVersusShared
privateGameModes[GameModes.IDs.THREE_PLAYER_VS_ALL] = ThreePlayerVersusAll
privateGameModes[GameModes.IDs.THREE_PLAYER_VS_SHARED] = ThreePlayerVersusShared
privateGameModes[GameModes.IDs.THREE_PLAYER_VS_ALL_2V1] = ThreePlayerVersusAll_2v1
privateGameModes[GameModes.IDs.THREE_PLAYER_VS_SHARED_2V1] = ThreePlayerVersusShared_2v1
privateGameModes[GameModes.IDs.THREE_PLAYER_FFA] = ThreePlayerFFA
privateGameModes[GameModes.IDs.FOUR_PLAYER_FFA] = FourPlayerFFA
privateGameModes[GameModes.IDs.FIVE_PLAYER_FFA] = FivePlayerFFA
privateGameModes[GameModes.IDs.FIVE_PLAYER_1V4_ALL] = FivePlayerTeamVs1v4All
privateGameModes[GameModes.IDs.FIVE_PLAYER_1V4_SHARED] = FivePlayerTeamVs1v4Shared
privateGameModes[GameModes.IDs.FIVE_PLAYER_4V1_ALL] = FivePlayerTeamVs4v1All
privateGameModes[GameModes.IDs.FIVE_PLAYER_4V1_SHARED] = FivePlayerTeamVs4v1Shared
privateGameModes[GameModes.IDs.FIVE_PLAYER_2V3_ALL] = FivePlayerTeamVs2v3All
privateGameModes[GameModes.IDs.FIVE_PLAYER_2V3_SHARED] = FivePlayerTeamVs2v3Shared
privateGameModes[GameModes.IDs.FIVE_PLAYER_3V2_ALL] = FivePlayerTeamVs3v2All
privateGameModes[GameModes.IDs.FIVE_PLAYER_3V2_SHARED] = FivePlayerTeamVs3v2Shared

---@param mode GameModeID
---@return GameMode
function GameModes.getPreset(mode)
  assert(privateGameModes[mode], "Trying to access non existing mode " .. mode)
  return deepcpy(privateGameModes[mode])
end

-- Creates a GameMode from server message data by loading the preset and applying overrides
---@param gameModeData table The game mode data from the server message
---@return GameMode
function GameModes.createFromServerData(gameModeData)
  local preset = nil
  for _, gameMode in pairs(privateGameModes) do
    if gameMode.name == gameModeData.name then
      preset = gameMode
      break
    end
  end

  assert(preset, "Unknown game mode name: " .. tostring(gameModeData.name))

  local result = deepcpy(preset)

  for key, value in pairs(gameModeData) do
    result[key] = value
  end

  return result
end

---@type table<GameModeID, string>
GameModes.gameModeIdToName = {
  TWO_PLAYER_VS = "VS",
  ONE_PLAYER_TIME_ATTACK = "timeattack",
  ONE_PLAYER_ENDLESS = "endless",
  ONE_PLAYER_TRAINING = "training",
  ONE_PLAYER_CHALLENGE = "challenge",
  ONE_PLAYER_VS_SELF = "vsSelf",
  ONE_PLAYER_PUZZLE = "puzzle",
  TWO_PLAYER_TIME_ATTACK = "2p_timeattack",
  FOUR_PLAYER_TEAM_VS_ALL = "team_vs_all",
  FOUR_PLAYER_TEAM_VS_SHARED = "team_vs_shared",
  THREE_PLAYER_VS_ALL = "three_player_vs_all",
  THREE_PLAYER_VS_SHARED = "three_player_vs_shared",
  THREE_PLAYER_VS_ALL_2V1 = "three_player_vs_all_2v1",
  THREE_PLAYER_VS_SHARED_2V1 = "three_player_vs_shared_2v1",
  THREE_PLAYER_FFA = "3p_ffa",
  FOUR_PLAYER_FFA = "4p_ffa",
  FIVE_PLAYER_FFA = "5p_ffa",
  FIVE_PLAYER_1V4_ALL = "five_player_1v4_all",
  FIVE_PLAYER_1V4_SHARED = "five_player_1v4_shared",
  FIVE_PLAYER_4V1_ALL = "five_player_4v1_all",
  FIVE_PLAYER_4V1_SHARED = "five_player_4v1_shared",
  FIVE_PLAYER_2V3_ALL = "five_player_2v3_all",
  FIVE_PLAYER_2V3_SHARED = "five_player_2v3_shared",
  FIVE_PLAYER_3V2_ALL = "five_player_3v2_all",
  FIVE_PLAYER_3V2_SHARED = "five_player_3v2_shared",
}

---@type table<string, GameModeID>
GameModes.nameToGameModeId = {
  VS = "TWO_PLAYER_VS",
  timeattack = "ONE_PLAYER_TIME_ATTACK",
  endless = "ONE_PLAYER_ENDLESS",
  training = "ONE_PLAYER_TRAINING",
  challenge = "ONE_PLAYER_CHALLENGE",
  vsSelf = "ONE_PLAYER_VS_SELF",
  puzzle = "ONE_PLAYER_PUZZLE",
  ["2p_timeattack"] = "TWO_PLAYER_TIME_ATTACK",
  team_vs_all = "FOUR_PLAYER_TEAM_VS_ALL",
  team_vs_shared = "FOUR_PLAYER_TEAM_VS_SHARED",
  three_player_vs_all = "THREE_PLAYER_VS_ALL",
  three_player_vs_shared = "THREE_PLAYER_VS_SHARED",
  three_player_vs_all_2v1 = "THREE_PLAYER_VS_ALL_2V1",
  three_player_vs_shared_2v1 = "THREE_PLAYER_VS_SHARED_2V1",
  ["3p_ffa"] = "THREE_PLAYER_FFA",
  ["4p_ffa"] = "FOUR_PLAYER_FFA",
  ["5p_ffa"] = "FIVE_PLAYER_FFA",
  five_player_1v4_all = "FIVE_PLAYER_1V4_ALL",
  five_player_1v4_shared = "FIVE_PLAYER_1V4_SHARED",
  five_player_4v1_all = "FIVE_PLAYER_4V1_ALL",
  five_player_4v1_shared = "FIVE_PLAYER_4V1_SHARED",
  five_player_2v3_all = "FIVE_PLAYER_2V3_ALL",
  five_player_2v3_shared = "FIVE_PLAYER_2V3_SHARED",
  five_player_3v2_all = "FIVE_PLAYER_3V2_ALL",
  five_player_3v2_shared = "FIVE_PLAYER_3V2_SHARED",
}

return GameModes
