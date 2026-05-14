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

-- 1v3: room creator (slot 1) on the LEFT alone vs team of 3 on the right.
---@type GameMode
local FourPlayer1v3All = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "1v3 VS (All)",
  name = "four_player_1v3_all",

  playerCount = 4,
  teamCount = 2,
  playersPerTeam = {1, 3},
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
local FourPlayer1v3Shared = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "1v3 VS (Shared)",
  name = "four_player_1v3_shared",

  playerCount = 4,
  teamCount = 2,
  playersPerTeam = {1, 3},
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

-- 3v1: room creator (slot 1) on the LEFT as part of the team of 3 vs solo on the right.
---@type GameMode
local FourPlayer3v1All = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "3v1 VS (All)",
  name = "four_player_3v1_all",

  playerCount = 4,
  teamCount = 2,
  playersPerTeam = {3, 1},
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
local FourPlayer3v1Shared = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "3v1 VS (Shared)",
  name = "four_player_3v1_shared",

  playerCount = 4,
  teamCount = 2,
  playersPerTeam = {3, 1},
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
local ThreePlayerFFAShared = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "1v1v1 FFA (Shared)",
  name = "3p_ffa_shared",

  playerCount = 3,
  teamCount = 3,
  playersPerTeam = 1,
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
local FourPlayerFFAShared = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "1v1v1v1 FFA (Shared)",
  name = "4p_ffa_shared",

  playerCount = 4,
  teamCount = 4,
  playersPerTeam = 1,
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
local FivePlayerFFAShared = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "1v1v1v1v1 FFA (Shared)",
  name = "5p_ffa_shared",

  playerCount = 5,
  teamCount = 5,
  playersPerTeam = 1,
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
local SixPlayerFFA = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "1v1v1v1v1v1 FFA",
  name = "6p_ffa",

  playerCount = 6,
  teamCount = 6,
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
local SixPlayerFFAShared = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "1v1v1v1v1v1 FFA (Shared)",
  name = "6p_ffa_shared",

  playerCount = 6,
  teamCount = 6,
  playersPerTeam = 1,
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
local SevenPlayerFFA = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "1v1v1v1v1v1v1 FFA",
  name = "7p_ffa",

  playerCount = 7,
  teamCount = 7,
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
local SevenPlayerFFAShared = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "1v1v1v1v1v1v1 FFA (Shared)",
  name = "7p_ffa_shared",

  playerCount = 7,
  teamCount = 7,
  playersPerTeam = 1,
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
-- Open FFA: dynamic roster, public drop-in. The room accepts 2-7 players and a
-- match starts when at least minPlayers are present + everyone is ready. New
-- joiners between matches drop straight into the next round; mid-match joiners
-- spectate until the current match ends, then promote up to maxPlayers.
-- playerCount/teamCount are left nil here and filled in at match start from
-- the actual roster.
local OpenFFA = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "Open FFA",
  name = "open_ffa",

  minPlayers = 2,
  maxPlayers = 7,
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
local OpenFFAShared = GameMode({
  gameScene = "GameBase",
  richPresenceLabel = "Open FFA (Shared)",
  name = "open_ffa_shared",

  minPlayers = 2,
  maxPlayers = 7,
  playersPerTeam = 1,
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

-- 6-player team modes. The engine (TeamUtils.createTeams, Room, Match) is
-- size-agnostic, so adding these only needs the GameMode definitions and
-- their IDs/name wirings below — no other code changes required.
local function sixPlayerTeamMode(name, richLabel, playersPerTeam, garbageMode)
  return GameMode({
    gameScene = "GameBase",
    richPresenceLabel = richLabel,
    name = name,
    playerCount = 6,
    teamCount = 2,
    playersPerTeam = playersPerTeam,
    garbageMode = garbageMode,
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
end
local SixPlayerTeamVs3v3All     = sixPlayerTeamMode("six_player_3v3_all",     "3v3 VS (All)",     {3, 3}, "all")
local SixPlayerTeamVs3v3Shared  = sixPlayerTeamMode("six_player_3v3_shared",  "3v3 VS (Shared)",  {3, 3}, "shared")
local SixPlayerTeamVs2v4All     = sixPlayerTeamMode("six_player_2v4_all",     "2v4 VS (All)",     {2, 4}, "all")
local SixPlayerTeamVs2v4Shared  = sixPlayerTeamMode("six_player_2v4_shared",  "2v4 VS (Shared)",  {2, 4}, "shared")
local SixPlayerTeamVs4v2All     = sixPlayerTeamMode("six_player_4v2_all",     "4v2 VS (All)",     {4, 2}, "all")
local SixPlayerTeamVs4v2Shared  = sixPlayerTeamMode("six_player_4v2_shared",  "4v2 VS (Shared)",  {4, 2}, "shared")
local SixPlayerTeamVs1v5All     = sixPlayerTeamMode("six_player_1v5_all",     "1v5 VS (All)",     {1, 5}, "all")
local SixPlayerTeamVs1v5Shared  = sixPlayerTeamMode("six_player_1v5_shared",  "1v5 VS (Shared)",  {1, 5}, "shared")
local SixPlayerTeamVs5v1All     = sixPlayerTeamMode("six_player_5v1_all",     "5v1 VS (All)",     {5, 1}, "all")
local SixPlayerTeamVs5v1Shared  = sixPlayerTeamMode("six_player_5v1_shared",  "5v1 VS (Shared)",  {5, 1}, "shared")

-- 7-player team modes. Same factory pattern as 6p — bumping playerCount and
-- swapping playersPerTeam is enough; engine handles arbitrary sizes.
local function sevenPlayerTeamMode(name, richLabel, playersPerTeam, garbageMode)
  return GameMode({
    gameScene = "GameBase",
    richPresenceLabel = richLabel,
    name = name,
    playerCount = 7,
    teamCount = 2,
    playersPerTeam = playersPerTeam,
    garbageMode = garbageMode,
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
end
local SevenPlayerTeamVs3v4All     = sevenPlayerTeamMode("seven_player_3v4_all",     "3v4 VS (All)",     {3, 4}, "all")
local SevenPlayerTeamVs3v4Shared  = sevenPlayerTeamMode("seven_player_3v4_shared",  "3v4 VS (Shared)",  {3, 4}, "shared")
local SevenPlayerTeamVs4v3All     = sevenPlayerTeamMode("seven_player_4v3_all",     "4v3 VS (All)",     {4, 3}, "all")
local SevenPlayerTeamVs4v3Shared  = sevenPlayerTeamMode("seven_player_4v3_shared",  "4v3 VS (Shared)",  {4, 3}, "shared")
local SevenPlayerTeamVs2v5All     = sevenPlayerTeamMode("seven_player_2v5_all",     "2v5 VS (All)",     {2, 5}, "all")
local SevenPlayerTeamVs2v5Shared  = sevenPlayerTeamMode("seven_player_2v5_shared",  "2v5 VS (Shared)",  {2, 5}, "shared")
local SevenPlayerTeamVs5v2All     = sevenPlayerTeamMode("seven_player_5v2_all",     "5v2 VS (All)",     {5, 2}, "all")
local SevenPlayerTeamVs5v2Shared  = sevenPlayerTeamMode("seven_player_5v2_shared",  "5v2 VS (Shared)",  {5, 2}, "shared")
local SevenPlayerTeamVs1v6All     = sevenPlayerTeamMode("seven_player_1v6_all",     "1v6 VS (All)",     {1, 6}, "all")
local SevenPlayerTeamVs1v6Shared  = sevenPlayerTeamMode("seven_player_1v6_shared",  "1v6 VS (Shared)",  {1, 6}, "shared")
local SevenPlayerTeamVs6v1All     = sevenPlayerTeamMode("seven_player_6v1_all",     "6v1 VS (All)",     {6, 1}, "all")
local SevenPlayerTeamVs6v1Shared  = sevenPlayerTeamMode("seven_player_6v1_shared",  "6v1 VS (Shared)",  {6, 1}, "shared")

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
  FOUR_PLAYER_1V3_ALL = "FOUR_PLAYER_1V3_ALL",
  FOUR_PLAYER_1V3_SHARED = "FOUR_PLAYER_1V3_SHARED",
  FOUR_PLAYER_3V1_ALL = "FOUR_PLAYER_3V1_ALL",
  FOUR_PLAYER_3V1_SHARED = "FOUR_PLAYER_3V1_SHARED",
  THREE_PLAYER_VS_ALL = "THREE_PLAYER_VS_ALL",
  THREE_PLAYER_VS_SHARED = "THREE_PLAYER_VS_SHARED",
  THREE_PLAYER_VS_ALL_2V1 = "THREE_PLAYER_VS_ALL_2V1",
  THREE_PLAYER_VS_SHARED_2V1 = "THREE_PLAYER_VS_SHARED_2V1",
  -- Free-for-all modes
  THREE_PLAYER_FFA = "THREE_PLAYER_FFA",
  THREE_PLAYER_FFA_SHARED = "THREE_PLAYER_FFA_SHARED",
  FOUR_PLAYER_FFA = "FOUR_PLAYER_FFA",
  FOUR_PLAYER_FFA_SHARED = "FOUR_PLAYER_FFA_SHARED",
  FIVE_PLAYER_FFA = "FIVE_PLAYER_FFA",
  FIVE_PLAYER_FFA_SHARED = "FIVE_PLAYER_FFA_SHARED",
  SIX_PLAYER_FFA = "SIX_PLAYER_FFA",
  SIX_PLAYER_FFA_SHARED = "SIX_PLAYER_FFA_SHARED",
  SEVEN_PLAYER_FFA = "SEVEN_PLAYER_FFA",
  SEVEN_PLAYER_FFA_SHARED = "SEVEN_PLAYER_FFA_SHARED",
  OPEN_FFA = "OPEN_FFA",
  OPEN_FFA_SHARED = "OPEN_FFA_SHARED",
  -- 5-player team modes
  FIVE_PLAYER_1V4_ALL = "FIVE_PLAYER_1V4_ALL",
  FIVE_PLAYER_1V4_SHARED = "FIVE_PLAYER_1V4_SHARED",
  FIVE_PLAYER_4V1_ALL = "FIVE_PLAYER_4V1_ALL",
  FIVE_PLAYER_4V1_SHARED = "FIVE_PLAYER_4V1_SHARED",
  FIVE_PLAYER_2V3_ALL = "FIVE_PLAYER_2V3_ALL",
  FIVE_PLAYER_2V3_SHARED = "FIVE_PLAYER_2V3_SHARED",
  FIVE_PLAYER_3V2_ALL = "FIVE_PLAYER_3V2_ALL",
  FIVE_PLAYER_3V2_SHARED = "FIVE_PLAYER_3V2_SHARED",
  -- 6-player team modes
  SIX_PLAYER_3V3_ALL = "SIX_PLAYER_3V3_ALL",
  SIX_PLAYER_3V3_SHARED = "SIX_PLAYER_3V3_SHARED",
  SIX_PLAYER_2V4_ALL = "SIX_PLAYER_2V4_ALL",
  SIX_PLAYER_2V4_SHARED = "SIX_PLAYER_2V4_SHARED",
  SIX_PLAYER_4V2_ALL = "SIX_PLAYER_4V2_ALL",
  SIX_PLAYER_4V2_SHARED = "SIX_PLAYER_4V2_SHARED",
  SIX_PLAYER_1V5_ALL = "SIX_PLAYER_1V5_ALL",
  SIX_PLAYER_1V5_SHARED = "SIX_PLAYER_1V5_SHARED",
  SIX_PLAYER_5V1_ALL = "SIX_PLAYER_5V1_ALL",
  SIX_PLAYER_5V1_SHARED = "SIX_PLAYER_5V1_SHARED",
  -- 7-player team modes
  SEVEN_PLAYER_3V4_ALL = "SEVEN_PLAYER_3V4_ALL",
  SEVEN_PLAYER_3V4_SHARED = "SEVEN_PLAYER_3V4_SHARED",
  SEVEN_PLAYER_4V3_ALL = "SEVEN_PLAYER_4V3_ALL",
  SEVEN_PLAYER_4V3_SHARED = "SEVEN_PLAYER_4V3_SHARED",
  SEVEN_PLAYER_2V5_ALL = "SEVEN_PLAYER_2V5_ALL",
  SEVEN_PLAYER_2V5_SHARED = "SEVEN_PLAYER_2V5_SHARED",
  SEVEN_PLAYER_5V2_ALL = "SEVEN_PLAYER_5V2_ALL",
  SEVEN_PLAYER_5V2_SHARED = "SEVEN_PLAYER_5V2_SHARED",
  SEVEN_PLAYER_1V6_ALL = "SEVEN_PLAYER_1V6_ALL",
  SEVEN_PLAYER_1V6_SHARED = "SEVEN_PLAYER_1V6_SHARED",
  SEVEN_PLAYER_6V1_ALL = "SEVEN_PLAYER_6V1_ALL",
  SEVEN_PLAYER_6V1_SHARED = "SEVEN_PLAYER_6V1_SHARED",
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
privateGameModes[GameModes.IDs.FOUR_PLAYER_1V3_ALL] = FourPlayer1v3All
privateGameModes[GameModes.IDs.FOUR_PLAYER_1V3_SHARED] = FourPlayer1v3Shared
privateGameModes[GameModes.IDs.FOUR_PLAYER_3V1_ALL] = FourPlayer3v1All
privateGameModes[GameModes.IDs.FOUR_PLAYER_3V1_SHARED] = FourPlayer3v1Shared
privateGameModes[GameModes.IDs.THREE_PLAYER_VS_ALL] = ThreePlayerVersusAll
privateGameModes[GameModes.IDs.THREE_PLAYER_VS_SHARED] = ThreePlayerVersusShared
privateGameModes[GameModes.IDs.THREE_PLAYER_VS_ALL_2V1] = ThreePlayerVersusAll_2v1
privateGameModes[GameModes.IDs.THREE_PLAYER_VS_SHARED_2V1] = ThreePlayerVersusShared_2v1
privateGameModes[GameModes.IDs.THREE_PLAYER_FFA] = ThreePlayerFFA
privateGameModes[GameModes.IDs.THREE_PLAYER_FFA_SHARED] = ThreePlayerFFAShared
privateGameModes[GameModes.IDs.FOUR_PLAYER_FFA] = FourPlayerFFA
privateGameModes[GameModes.IDs.FOUR_PLAYER_FFA_SHARED] = FourPlayerFFAShared
privateGameModes[GameModes.IDs.FIVE_PLAYER_FFA] = FivePlayerFFA
privateGameModes[GameModes.IDs.FIVE_PLAYER_FFA_SHARED] = FivePlayerFFAShared
privateGameModes[GameModes.IDs.SIX_PLAYER_FFA] = SixPlayerFFA
privateGameModes[GameModes.IDs.SIX_PLAYER_FFA_SHARED] = SixPlayerFFAShared
privateGameModes[GameModes.IDs.SEVEN_PLAYER_FFA] = SevenPlayerFFA
privateGameModes[GameModes.IDs.SEVEN_PLAYER_FFA_SHARED] = SevenPlayerFFAShared
privateGameModes[GameModes.IDs.FIVE_PLAYER_1V4_ALL] = FivePlayerTeamVs1v4All
privateGameModes[GameModes.IDs.FIVE_PLAYER_1V4_SHARED] = FivePlayerTeamVs1v4Shared
privateGameModes[GameModes.IDs.FIVE_PLAYER_4V1_ALL] = FivePlayerTeamVs4v1All
privateGameModes[GameModes.IDs.FIVE_PLAYER_4V1_SHARED] = FivePlayerTeamVs4v1Shared
privateGameModes[GameModes.IDs.FIVE_PLAYER_2V3_ALL] = FivePlayerTeamVs2v3All
privateGameModes[GameModes.IDs.FIVE_PLAYER_2V3_SHARED] = FivePlayerTeamVs2v3Shared
privateGameModes[GameModes.IDs.FIVE_PLAYER_3V2_ALL] = FivePlayerTeamVs3v2All
privateGameModes[GameModes.IDs.FIVE_PLAYER_3V2_SHARED] = FivePlayerTeamVs3v2Shared
privateGameModes[GameModes.IDs.SIX_PLAYER_3V3_ALL] = SixPlayerTeamVs3v3All
privateGameModes[GameModes.IDs.SIX_PLAYER_3V3_SHARED] = SixPlayerTeamVs3v3Shared
privateGameModes[GameModes.IDs.SIX_PLAYER_2V4_ALL] = SixPlayerTeamVs2v4All
privateGameModes[GameModes.IDs.SIX_PLAYER_2V4_SHARED] = SixPlayerTeamVs2v4Shared
privateGameModes[GameModes.IDs.SIX_PLAYER_4V2_ALL] = SixPlayerTeamVs4v2All
privateGameModes[GameModes.IDs.SIX_PLAYER_4V2_SHARED] = SixPlayerTeamVs4v2Shared
privateGameModes[GameModes.IDs.SIX_PLAYER_1V5_ALL] = SixPlayerTeamVs1v5All
privateGameModes[GameModes.IDs.SIX_PLAYER_1V5_SHARED] = SixPlayerTeamVs1v5Shared
privateGameModes[GameModes.IDs.SIX_PLAYER_5V1_ALL] = SixPlayerTeamVs5v1All
privateGameModes[GameModes.IDs.SIX_PLAYER_5V1_SHARED] = SixPlayerTeamVs5v1Shared
privateGameModes[GameModes.IDs.SEVEN_PLAYER_3V4_ALL] = SevenPlayerTeamVs3v4All
privateGameModes[GameModes.IDs.SEVEN_PLAYER_3V4_SHARED] = SevenPlayerTeamVs3v4Shared
privateGameModes[GameModes.IDs.SEVEN_PLAYER_4V3_ALL] = SevenPlayerTeamVs4v3All
privateGameModes[GameModes.IDs.SEVEN_PLAYER_4V3_SHARED] = SevenPlayerTeamVs4v3Shared
privateGameModes[GameModes.IDs.SEVEN_PLAYER_2V5_ALL] = SevenPlayerTeamVs2v5All
privateGameModes[GameModes.IDs.SEVEN_PLAYER_2V5_SHARED] = SevenPlayerTeamVs2v5Shared
privateGameModes[GameModes.IDs.SEVEN_PLAYER_5V2_ALL] = SevenPlayerTeamVs5v2All
privateGameModes[GameModes.IDs.SEVEN_PLAYER_5V2_SHARED] = SevenPlayerTeamVs5v2Shared
privateGameModes[GameModes.IDs.SEVEN_PLAYER_1V6_ALL] = SevenPlayerTeamVs1v6All
privateGameModes[GameModes.IDs.SEVEN_PLAYER_1V6_SHARED] = SevenPlayerTeamVs1v6Shared
privateGameModes[GameModes.IDs.SEVEN_PLAYER_6V1_ALL] = SevenPlayerTeamVs6v1All
privateGameModes[GameModes.IDs.SEVEN_PLAYER_6V1_SHARED] = SevenPlayerTeamVs6v1Shared
privateGameModes[GameModes.IDs.OPEN_FFA] = OpenFFA
privateGameModes[GameModes.IDs.OPEN_FFA_SHARED] = OpenFFAShared

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
  FOUR_PLAYER_1V3_ALL = "four_player_1v3_all",
  FOUR_PLAYER_1V3_SHARED = "four_player_1v3_shared",
  FOUR_PLAYER_3V1_ALL = "four_player_3v1_all",
  FOUR_PLAYER_3V1_SHARED = "four_player_3v1_shared",
  THREE_PLAYER_VS_ALL = "three_player_vs_all",
  THREE_PLAYER_VS_SHARED = "three_player_vs_shared",
  THREE_PLAYER_VS_ALL_2V1 = "three_player_vs_all_2v1",
  THREE_PLAYER_VS_SHARED_2V1 = "three_player_vs_shared_2v1",
  THREE_PLAYER_FFA = "3p_ffa",
  THREE_PLAYER_FFA_SHARED = "3p_ffa_shared",
  FOUR_PLAYER_FFA = "4p_ffa",
  FOUR_PLAYER_FFA_SHARED = "4p_ffa_shared",
  FIVE_PLAYER_FFA = "5p_ffa",
  FIVE_PLAYER_FFA_SHARED = "5p_ffa_shared",
  SIX_PLAYER_FFA = "6p_ffa",
  SIX_PLAYER_FFA_SHARED = "6p_ffa_shared",
  SEVEN_PLAYER_FFA = "7p_ffa",
  SEVEN_PLAYER_FFA_SHARED = "7p_ffa_shared",
  FIVE_PLAYER_1V4_ALL = "five_player_1v4_all",
  FIVE_PLAYER_1V4_SHARED = "five_player_1v4_shared",
  FIVE_PLAYER_4V1_ALL = "five_player_4v1_all",
  FIVE_PLAYER_4V1_SHARED = "five_player_4v1_shared",
  FIVE_PLAYER_2V3_ALL = "five_player_2v3_all",
  FIVE_PLAYER_2V3_SHARED = "five_player_2v3_shared",
  FIVE_PLAYER_3V2_ALL = "five_player_3v2_all",
  FIVE_PLAYER_3V2_SHARED = "five_player_3v2_shared",
  SIX_PLAYER_3V3_ALL = "six_player_3v3_all",
  SIX_PLAYER_3V3_SHARED = "six_player_3v3_shared",
  SIX_PLAYER_2V4_ALL = "six_player_2v4_all",
  SIX_PLAYER_2V4_SHARED = "six_player_2v4_shared",
  SIX_PLAYER_4V2_ALL = "six_player_4v2_all",
  SIX_PLAYER_4V2_SHARED = "six_player_4v2_shared",
  SIX_PLAYER_1V5_ALL = "six_player_1v5_all",
  SIX_PLAYER_1V5_SHARED = "six_player_1v5_shared",
  SIX_PLAYER_5V1_ALL = "six_player_5v1_all",
  SIX_PLAYER_5V1_SHARED = "six_player_5v1_shared",
  SEVEN_PLAYER_3V4_ALL = "seven_player_3v4_all",
  SEVEN_PLAYER_3V4_SHARED = "seven_player_3v4_shared",
  SEVEN_PLAYER_4V3_ALL = "seven_player_4v3_all",
  SEVEN_PLAYER_4V3_SHARED = "seven_player_4v3_shared",
  SEVEN_PLAYER_2V5_ALL = "seven_player_2v5_all",
  SEVEN_PLAYER_2V5_SHARED = "seven_player_2v5_shared",
  SEVEN_PLAYER_5V2_ALL = "seven_player_5v2_all",
  SEVEN_PLAYER_5V2_SHARED = "seven_player_5v2_shared",
  SEVEN_PLAYER_1V6_ALL = "seven_player_1v6_all",
  SEVEN_PLAYER_1V6_SHARED = "seven_player_1v6_shared",
  SEVEN_PLAYER_6V1_ALL = "seven_player_6v1_all",
  SEVEN_PLAYER_6V1_SHARED = "seven_player_6v1_shared",
  OPEN_FFA = "open_ffa",
  OPEN_FFA_SHARED = "open_ffa_shared",
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
  four_player_1v3_all = "FOUR_PLAYER_1V3_ALL",
  four_player_1v3_shared = "FOUR_PLAYER_1V3_SHARED",
  four_player_3v1_all = "FOUR_PLAYER_3V1_ALL",
  four_player_3v1_shared = "FOUR_PLAYER_3V1_SHARED",
  three_player_vs_all = "THREE_PLAYER_VS_ALL",
  three_player_vs_shared = "THREE_PLAYER_VS_SHARED",
  three_player_vs_all_2v1 = "THREE_PLAYER_VS_ALL_2V1",
  three_player_vs_shared_2v1 = "THREE_PLAYER_VS_SHARED_2V1",
  ["3p_ffa"] = "THREE_PLAYER_FFA",
  ["3p_ffa_shared"] = "THREE_PLAYER_FFA_SHARED",
  ["4p_ffa"] = "FOUR_PLAYER_FFA",
  ["4p_ffa_shared"] = "FOUR_PLAYER_FFA_SHARED",
  ["5p_ffa"] = "FIVE_PLAYER_FFA",
  ["5p_ffa_shared"] = "FIVE_PLAYER_FFA_SHARED",
  ["6p_ffa"] = "SIX_PLAYER_FFA",
  ["6p_ffa_shared"] = "SIX_PLAYER_FFA_SHARED",
  ["7p_ffa"] = "SEVEN_PLAYER_FFA",
  ["7p_ffa_shared"] = "SEVEN_PLAYER_FFA_SHARED",
  five_player_1v4_all = "FIVE_PLAYER_1V4_ALL",
  five_player_1v4_shared = "FIVE_PLAYER_1V4_SHARED",
  five_player_4v1_all = "FIVE_PLAYER_4V1_ALL",
  five_player_4v1_shared = "FIVE_PLAYER_4V1_SHARED",
  five_player_2v3_all = "FIVE_PLAYER_2V3_ALL",
  five_player_2v3_shared = "FIVE_PLAYER_2V3_SHARED",
  five_player_3v2_all = "FIVE_PLAYER_3V2_ALL",
  five_player_3v2_shared = "FIVE_PLAYER_3V2_SHARED",
  six_player_3v3_all = "SIX_PLAYER_3V3_ALL",
  six_player_3v3_shared = "SIX_PLAYER_3V3_SHARED",
  six_player_2v4_all = "SIX_PLAYER_2V4_ALL",
  six_player_2v4_shared = "SIX_PLAYER_2V4_SHARED",
  six_player_4v2_all = "SIX_PLAYER_4V2_ALL",
  six_player_4v2_shared = "SIX_PLAYER_4V2_SHARED",
  six_player_1v5_all = "SIX_PLAYER_1V5_ALL",
  six_player_1v5_shared = "SIX_PLAYER_1V5_SHARED",
  six_player_5v1_all = "SIX_PLAYER_5V1_ALL",
  six_player_5v1_shared = "SIX_PLAYER_5V1_SHARED",
  seven_player_3v4_all = "SEVEN_PLAYER_3V4_ALL",
  seven_player_3v4_shared = "SEVEN_PLAYER_3V4_SHARED",
  seven_player_4v3_all = "SEVEN_PLAYER_4V3_ALL",
  seven_player_4v3_shared = "SEVEN_PLAYER_4V3_SHARED",
  seven_player_2v5_all = "SEVEN_PLAYER_2V5_ALL",
  seven_player_2v5_shared = "SEVEN_PLAYER_2V5_SHARED",
  seven_player_5v2_all = "SEVEN_PLAYER_5V2_ALL",
  seven_player_5v2_shared = "SEVEN_PLAYER_5V2_SHARED",
  seven_player_1v6_all = "SEVEN_PLAYER_1V6_ALL",
  seven_player_1v6_shared = "SEVEN_PLAYER_1V6_SHARED",
  seven_player_6v1_all = "SEVEN_PLAYER_6V1_ALL",
  seven_player_6v1_shared = "SEVEN_PLAYER_6V1_SHARED",
  open_ffa = "OPEN_FFA",
  open_ffa_shared = "OPEN_FFA_SHARED",
}

return GameModes
