-- TeamGameModeTests.lua
-- Tests for team-based game mode configurations
-- These tests will FAIL until team game modes are implemented (TDD red phase)

local logger = require("common.lib.logger")
local GameModes = require("common.data.GameModes")

--------------------------------------------------
-- 2v2 All Mode tests
--------------------------------------------------

local function testGameMode_2v2All_exists()
  logger.info("testGameMode_2v2All_exists")

  -- Should be able to load the preset without error
  local mode = GameModes.getPreset(GameModes.IDs.FOUR_PLAYER_TEAM_VS_ALL)
  assert(mode ~= nil, "2v2 All game mode should exist")
end

local function testGameMode_2v2All_playerCount()
  logger.info("testGameMode_2v2All_playerCount")

  local mode = GameModes.getPreset(GameModes.IDs.FOUR_PLAYER_TEAM_VS_ALL)
  assert(mode.playerCount == 4, "2v2 All should have playerCount of 4")
end

local function testGameMode_2v2All_teamCount()
  logger.info("testGameMode_2v2All_teamCount")

  local mode = GameModes.getPreset(GameModes.IDs.FOUR_PLAYER_TEAM_VS_ALL)
  assert(mode.teamCount == 2, "2v2 All should have teamCount of 2")
end

local function testGameMode_2v2All_playersPerTeam()
  logger.info("testGameMode_2v2All_playersPerTeam")

  local mode = GameModes.getPreset(GameModes.IDs.FOUR_PLAYER_TEAM_VS_ALL)
  assert(mode.playersPerTeam == 2, "2v2 All should have playersPerTeam of 2")
end

local function testGameMode_2v2All_garbageMode()
  logger.info("testGameMode_2v2All_garbageMode")

  local mode = GameModes.getPreset(GameModes.IDs.FOUR_PLAYER_TEAM_VS_ALL)
  assert(mode.garbageMode == "all", "2v2 All should have garbageMode 'all'")
end

local function testGameMode_2v2All_stackInteraction()
  logger.info("testGameMode_2v2All_stackInteraction")

  local mode = GameModes.getPreset(GameModes.IDs.FOUR_PLAYER_TEAM_VS_ALL)
  assert(mode.stackInteraction == GameModes.StackInteractions.TEAM_VERSUS,
    "2v2 All should have TEAM_VERSUS stack interaction")
end

--------------------------------------------------
-- 2v2 Shared Mode tests
--------------------------------------------------

local function testGameMode_2v2Shared_exists()
  logger.info("testGameMode_2v2Shared_exists")

  local mode = GameModes.getPreset(GameModes.IDs.FOUR_PLAYER_TEAM_VS_SHARED)
  assert(mode ~= nil, "2v2 Shared game mode should exist")
end

local function testGameMode_2v2Shared_garbageMode()
  logger.info("testGameMode_2v2Shared_garbageMode")

  local mode = GameModes.getPreset(GameModes.IDs.FOUR_PLAYER_TEAM_VS_SHARED)
  assert(mode.garbageMode == "shared", "2v2 Shared should have garbageMode 'shared'")
end

local function testGameMode_2v2Shared_playerCount()
  logger.info("testGameMode_2v2Shared_playerCount")

  local mode = GameModes.getPreset(GameModes.IDs.FOUR_PLAYER_TEAM_VS_SHARED)
  assert(mode.playerCount == 4, "2v2 Shared should have playerCount of 4")
end

--------------------------------------------------
-- 1v2 All Mode tests
--------------------------------------------------

local function testGameMode_1v2All_exists()
  logger.info("testGameMode_1v2All_exists")

  local mode = GameModes.getPreset(GameModes.IDs.THREE_PLAYER_VS_ALL)
  assert(mode ~= nil, "1v2 All game mode should exist")
end

local function testGameMode_1v2All_playerCount()
  logger.info("testGameMode_1v2All_playerCount")

  local mode = GameModes.getPreset(GameModes.IDs.THREE_PLAYER_VS_ALL)
  assert(mode.playerCount == 3, "1v2 All should have playerCount of 3")
end

local function testGameMode_1v2All_teamCount()
  logger.info("testGameMode_1v2All_teamCount")

  local mode = GameModes.getPreset(GameModes.IDs.THREE_PLAYER_VS_ALL)
  assert(mode.teamCount == 2, "1v2 All should have teamCount of 2")
end

local function testGameMode_1v2All_asymmetricTeams()
  logger.info("testGameMode_1v2All_asymmetricTeams")

  local mode = GameModes.getPreset(GameModes.IDs.THREE_PLAYER_VS_ALL)

  -- playersPerTeam should be a table {1, 2} for asymmetric teams
  assert(type(mode.playersPerTeam) == "table", "1v2 should have table for playersPerTeam")
  assert(mode.playersPerTeam[1] == 1, "First team should have 1 player (solo)")
  assert(mode.playersPerTeam[2] == 2, "Second team should have 2 players")
end

local function testGameMode_1v2All_garbageMode()
  logger.info("testGameMode_1v2All_garbageMode")

  local mode = GameModes.getPreset(GameModes.IDs.THREE_PLAYER_VS_ALL)
  assert(mode.garbageMode == "all", "1v2 All should have garbageMode 'all'")
end

--------------------------------------------------
-- 1v2 Shared Mode tests
--------------------------------------------------

local function testGameMode_1v2Shared_exists()
  logger.info("testGameMode_1v2Shared_exists")

  local mode = GameModes.getPreset(GameModes.IDs.THREE_PLAYER_VS_SHARED)
  assert(mode ~= nil, "1v2 Shared game mode should exist")
end

local function testGameMode_1v2Shared_garbageMode()
  logger.info("testGameMode_1v2Shared_garbageMode")

  local mode = GameModes.getPreset(GameModes.IDs.THREE_PLAYER_VS_SHARED)
  assert(mode.garbageMode == "shared", "1v2 Shared should have garbageMode 'shared'")
end

--------------------------------------------------
-- StackInteractions enum tests
--------------------------------------------------

local function testStackInteractions_teamVersusExists()
  logger.info("testStackInteractions_teamVersusExists")

  assert(GameModes.StackInteractions.TEAM_VERSUS ~= nil,
    "TEAM_VERSUS stack interaction should exist")
  assert(type(GameModes.StackInteractions.TEAM_VERSUS) == "number",
    "TEAM_VERSUS should be a number")
end

local function testStackInteractions_teamVersusUnique()
  logger.info("testStackInteractions_teamVersusUnique")

  -- TEAM_VERSUS should be different from existing interactions
  assert(GameModes.StackInteractions.TEAM_VERSUS ~= GameModes.StackInteractions.NONE)
  assert(GameModes.StackInteractions.TEAM_VERSUS ~= GameModes.StackInteractions.VERSUS)
  assert(GameModes.StackInteractions.TEAM_VERSUS ~= GameModes.StackInteractions.SELF)
  assert(GameModes.StackInteractions.TEAM_VERSUS ~= GameModes.StackInteractions.ATTACK_ENGINE)
end

--------------------------------------------------
-- Match rules tests
--------------------------------------------------

local function testGameMode_2v2_matchEndCondition()
  logger.info("testGameMode_2v2_matchEndCondition")

  local mode = GameModes.getPreset(GameModes.IDs.FOUR_PLAYER_TEAM_VS_ALL)

  -- Should use TEAMS_ACTIVE instead of STACKS_ACTIVE
  local MatchRules = require("common.data.MatchRules")
  assert(mode.matchRules.matchEndConditions[MatchRules.MatchEndConditions.TEAMS_ACTIVE] == 1,
    "2v2 should end when 1 team is active (other eliminated)")
end

local function testGameMode_2v2_doCountdown()
  logger.info("testGameMode_2v2_doCountdown")

  local mode = GameModes.getPreset(GameModes.IDs.FOUR_PLAYER_TEAM_VS_ALL)
  assert(mode.matchRules.doCountdown == true, "2v2 should have countdown")
end

--------------------------------------------------
-- GameMode name/ID mapping tests
--------------------------------------------------

local function testGameModeIdMapping_2v2All()
  logger.info("testGameModeIdMapping_2v2All")

  assert(GameModes.IDs.FOUR_PLAYER_TEAM_VS_ALL ~= nil, "FOUR_PLAYER_TEAM_VS_ALL ID should exist")
  assert(GameModes.gameModeIdToName.FOUR_PLAYER_TEAM_VS_ALL ~= nil,
    "Should have name mapping for 2v2 All")
end

local function testGameModeIdMapping_2v2Shared()
  logger.info("testGameModeIdMapping_2v2Shared")

  assert(GameModes.IDs.FOUR_PLAYER_TEAM_VS_SHARED ~= nil, "FOUR_PLAYER_TEAM_VS_SHARED ID should exist")
end

local function testGameModeIdMapping_1v2All()
  logger.info("testGameModeIdMapping_1v2All")

  assert(GameModes.IDs.THREE_PLAYER_VS_ALL ~= nil, "THREE_PLAYER_VS_ALL ID should exist")
end

local function testGameModeIdMapping_1v2Shared()
  logger.info("testGameModeIdMapping_1v2Shared")

  assert(GameModes.IDs.THREE_PLAYER_VS_SHARED ~= nil, "THREE_PLAYER_VS_SHARED ID should exist")
end

--------------------------------------------------
-- Run all tests
--------------------------------------------------

-- StackInteractions
testStackInteractions_teamVersusExists()
testStackInteractions_teamVersusUnique()

-- 2v2 All
testGameMode_2v2All_exists()
testGameMode_2v2All_playerCount()
testGameMode_2v2All_teamCount()
testGameMode_2v2All_playersPerTeam()
testGameMode_2v2All_garbageMode()
testGameMode_2v2All_stackInteraction()
testGameMode_2v2_matchEndCondition()
testGameMode_2v2_doCountdown()

-- 2v2 Shared
testGameMode_2v2Shared_exists()
testGameMode_2v2Shared_garbageMode()
testGameMode_2v2Shared_playerCount()

-- 1v2 All
testGameMode_1v2All_exists()
testGameMode_1v2All_playerCount()
testGameMode_1v2All_teamCount()
testGameMode_1v2All_asymmetricTeams()
testGameMode_1v2All_garbageMode()

-- 1v2 Shared
testGameMode_1v2Shared_exists()
testGameMode_1v2Shared_garbageMode()

-- ID mappings
testGameModeIdMapping_2v2All()
testGameModeIdMapping_2v2Shared()
testGameModeIdMapping_1v2All()
testGameModeIdMapping_1v2Shared()

logger.info("All TeamGameModeTests passed!")
