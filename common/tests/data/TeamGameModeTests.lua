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
-- Structural audit: every registered team mode must have a consistent
-- (playerCount, teamCount, playersPerTeam) triple. A drifted preset
-- crashes server-side at start_match time inside TeamUtils.createTeams —
-- silently, because xpcall catches it, and the client just sees
-- "everyone clicked ready, nothing happened." This test asserts the
-- invariants up front so the next drift fails CI instead of a play test.
--------------------------------------------------

local function testEveryTeamMode_invariants()
  logger.info("testEveryTeamMode_invariants")

  local teamModes = {
    "THREE_PLAYER_VS_ALL", "THREE_PLAYER_VS_SHARED",
    "THREE_PLAYER_VS_ALL_2V1", "THREE_PLAYER_VS_SHARED_2V1",
    "FOUR_PLAYER_TEAM_VS_ALL", "FOUR_PLAYER_TEAM_VS_SHARED",
    "FOUR_PLAYER_1V3_ALL", "FOUR_PLAYER_1V3_SHARED",
    "FOUR_PLAYER_3V1_ALL", "FOUR_PLAYER_3V1_SHARED",
    "FIVE_PLAYER_1V4_ALL", "FIVE_PLAYER_1V4_SHARED",
    "FIVE_PLAYER_4V1_ALL", "FIVE_PLAYER_4V1_SHARED",
    "FIVE_PLAYER_2V3_ALL", "FIVE_PLAYER_2V3_SHARED",
    "FIVE_PLAYER_3V2_ALL", "FIVE_PLAYER_3V2_SHARED",
  }

  for _, modeId in ipairs(teamModes) do
    assert(GameModes.IDs[modeId] ~= nil, "ID missing: " .. modeId)
    local mode = GameModes.getPreset(GameModes.IDs[modeId])
    assert(mode, "preset missing for " .. modeId)
    assert(mode.name, modeId .. " has no name")
    assert(GameModes.nameToGameModeId[mode.name] == modeId,
      modeId .. " name<->id roundtrip broken (name=" .. tostring(mode.name) .. ")")
    assert(mode.garbageMode == "all" or mode.garbageMode == "shared",
      modeId .. " has invalid garbageMode: " .. tostring(mode.garbageMode))
    assert(mode.stackInteraction == GameModes.StackInteractions.TEAM_VERSUS,
      modeId .. " is not TEAM_VERSUS")
    assert(type(mode.playerCount) == "number" and mode.playerCount > 0,
      modeId .. " has bad playerCount")
    assert(type(mode.teamCount) == "number" and mode.teamCount > 0,
      modeId .. " has bad teamCount")
    assert(mode.playersPerTeam ~= nil, modeId .. " has no playersPerTeam")

    -- The invariant: roster size derivable from playersPerTeam must equal playerCount.
    -- This is what start_match relies on when it walks createTeams + builds garbageFlows
    -- + assigns stacks. Drift here is the source of B9 (Open Team 1v2 crash).
    local expectedTotal
    if type(mode.playersPerTeam) == "table" then
      assert(#mode.playersPerTeam == mode.teamCount,
        modeId .. ": asymmetric playersPerTeam length (" ..
        #mode.playersPerTeam .. ") doesn't equal teamCount (" .. mode.teamCount .. ")")
      expectedTotal = 0
      for _, n in ipairs(mode.playersPerTeam) do
        expectedTotal = expectedTotal + n
      end
    else
      expectedTotal = mode.teamCount * mode.playersPerTeam
    end
    assert(expectedTotal == mode.playerCount,
      modeId .. ": playersPerTeam totals " .. expectedTotal ..
      " but playerCount is " .. mode.playerCount)

    -- createTeams must actually succeed at this (playerCount, teamCount, playersPerTeam).
    local TeamUtils = require("common.data.TeamUtils")
    local teams = TeamUtils.createTeams(mode.playerCount, mode.teamCount, mode.playersPerTeam)
    assert(#teams == mode.teamCount, modeId .. ": createTeams produced wrong team count")
    local actualTotal = 0
    for _, team in ipairs(teams) do actualTotal = actualTotal + #team.playerIndices end
    assert(actualTotal == mode.playerCount,
      modeId .. ": createTeams allocated " .. actualTotal .. " player slots, expected " .. mode.playerCount)
  end
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

-- Structural audit across every registered team mode (catches B9-class drift).
testEveryTeamMode_invariants()

logger.info("All TeamGameModeTests passed!")
