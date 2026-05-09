-- TeamMatchTests.lua
-- Integration tests for Match class with team-based win conditions
-- These tests will FAIL until team match logic is implemented (TDD red phase)

local logger = require("common.lib.logger")
local Match = require("common.engine.Match")
local GameModes = require("common.data.GameModes")
local LevelPresets = require("common.data.LevelPresets")
local GeneratorSource = require("common.engine.GeneratorSource")
local TeamUtils = require("common.data.TeamUtils")

-- Helper to create a team match with N stacks
local function createTeamMatch(playerCount, teamCount, playersPerTeam, garbageMode)
  garbageMode = garbageMode or "all"

  -- Create a mock game mode for team play
  local matchRules = {
    matchEndConditions = { TEAMS_ACTIVE = 1 },
    matchWinRuleset = { { GAME_OVER_CLOCK = "HIGHEST" } },
    stackOverConditions = { HEALTH = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = false,  -- Skip countdown for tests
  }

  local match = Match(GeneratorSource(12345, true), matchRules)

  -- Create stacks for each player
  local levelData = LevelPresets.getModern(10)
  levelData.maxHealth = 1  -- Low health so we can easily kill stacks

  for i = 1, playerCount do
    local stack = match:createStackWithSettings(levelData, false, "controller")
    stack:setMaxRunsPerFrame(1)
    stack:receiveConfirmedInput(string.rep("A", 10000))  -- Feed idle inputs
  end

  -- Set up teams
  local teams = TeamUtils.createTeams(playerCount, teamCount, playersPerTeam)
  match:setTeams(teams)
  match:setGarbageMode(garbageMode)

  -- Configure garbage targets based on team mode
  match:setupTeamGarbageTargets()

  match:start()

  return match, teams
end

-- Helper to kill a stack (simulate game over)
local function killStack(stack)
  stack.health = 0
  -- Trigger the game_ended state
  stack:setGameOver()
end

-- Helper to run match for N frames
local function runFrames(match, count)
  for i = 1, count do
    match:run()
  end
end

--------------------------------------------------
-- 2v2 Match End Condition Tests
--------------------------------------------------

local function testMatchEnds_whenOneTeamEliminated_2v2()
  logger.info("testMatchEnds_whenOneTeamEliminated_2v2")

  local match, teams = createTeamMatch(4, 2, 2)

  -- Verify match hasn't ended yet
  assert(match:hasEnded() == false, "Match should not have ended yet")

  -- Kill both players on Team B (players 3 and 4)
  killStack(match.stacks[3])
  killStack(match.stacks[4])

  runFrames(match, 1)

  -- Match should end
  assert(match:hasEnded() == true, "Match should end when one team is eliminated")

  -- Team A should win
  local winningTeam = match:getWinningTeam()
  assert(winningTeam == teams[1], "Team A should be the winner")
end

local function testMatchContinues_whenOnePlayerDies_2v2()
  logger.info("testMatchContinues_whenOnePlayerDies_2v2")

  local match, teams = createTeamMatch(4, 2, 2)

  -- Kill only player 1 (Team A still has player 2)
  killStack(match.stacks[1])

  runFrames(match, 1)

  -- Match should continue
  assert(match:hasEnded() == false, "Match should continue - Team A still has player 2")
end

local function testMatchEnds_whenLastTeamMemberDies_2v2()
  logger.info("testMatchEnds_whenLastTeamMemberDies_2v2")

  local match, teams = createTeamMatch(4, 2, 2)

  -- Kill player 1
  killStack(match.stacks[1])
  runFrames(match, 1)
  assert(match:hasEnded() == false, "Match should continue after P1 dies")

  -- Kill player 2 (last member of Team A)
  killStack(match.stacks[2])
  runFrames(match, 1)

  -- Now match should end - Team A is eliminated
  assert(match:hasEnded() == true, "Match should end when Team A is eliminated")

  -- Team B should win
  local winningTeam = match:getWinningTeam()
  assert(winningTeam == teams[2], "Team B should be the winner")
end

--------------------------------------------------
-- 1v2 Match End Condition Tests
--------------------------------------------------

local function testMatchEnds_whenSoloEliminated_1v2()
  logger.info("testMatchEnds_whenSoloEliminated_1v2")

  local match, teams = createTeamMatch(3, 2, {1, 2})  -- 1v2 asymmetric

  -- Kill solo player (player 1)
  killStack(match.stacks[1])
  runFrames(match, 1)

  -- Match should end
  assert(match:hasEnded() == true, "Match should end when solo is eliminated")

  -- Team (players 2 and 3) should win
  local winningTeam = match:getWinningTeam()
  assert(winningTeam == teams[2], "Team should win when solo is eliminated")
end

local function testMatchEnds_whenTeamEliminated_1v2()
  logger.info("testMatchEnds_whenTeamEliminated_1v2")

  local match, teams = createTeamMatch(3, 2, {1, 2})  -- 1v2 asymmetric

  -- Kill both team members (players 2 and 3)
  killStack(match.stacks[2])
  killStack(match.stacks[3])
  runFrames(match, 1)

  -- Match should end
  assert(match:hasEnded() == true, "Match should end when team is eliminated")

  -- Solo should win
  local winningTeam = match:getWinningTeam()
  assert(winningTeam == teams[1], "Solo should win when team is eliminated")
end

local function testMatchContinues_whenOneTeamMemberDies_1v2()
  logger.info("testMatchContinues_whenOneTeamMemberDies_1v2")

  local match, teams = createTeamMatch(3, 2, {1, 2})  -- 1v2 asymmetric

  -- Kill one team member (player 2)
  killStack(match.stacks[2])
  runFrames(match, 1)

  -- Match should continue - player 3 still alive on team
  assert(match:hasEnded() == false, "Match should continue - team still has player 3")
end

--------------------------------------------------
-- 3v3 Match End Condition Tests (scalability)
--------------------------------------------------

local function testMatchEnds_3v3()
  logger.info("testMatchEnds_3v3")

  local match, teams = createTeamMatch(6, 2, 3)

  -- Kill all of Team B (players 4, 5, 6)
  killStack(match.stacks[4])
  killStack(match.stacks[5])
  killStack(match.stacks[6])
  runFrames(match, 1)

  assert(match:hasEnded() == true, "Match should end when Team B is eliminated")
  assert(match:getWinningTeam() == teams[1], "Team A should win")
end

local function testMatchContinues_3v3_partialDeath()
  logger.info("testMatchContinues_3v3_partialDeath")

  local match, teams = createTeamMatch(6, 2, 3)

  -- Kill 2 of 3 Team A members
  killStack(match.stacks[1])
  killStack(match.stacks[2])
  runFrames(match, 1)

  -- Match should continue - player 3 still alive
  assert(match:hasEnded() == false, "Match should continue with 1 player alive on Team A")
end

--------------------------------------------------
-- Draw condition tests
--------------------------------------------------

local function testMatchEnds_draw()
  logger.info("testMatchEnds_draw")

  local match, teams = createTeamMatch(4, 2, 2)

  -- Kill all players simultaneously
  killStack(match.stacks[1])
  killStack(match.stacks[2])
  killStack(match.stacks[3])
  killStack(match.stacks[4])
  runFrames(match, 1)

  -- Match should end
  assert(match:hasEnded() == true, "Match should end when all players die")

  -- No winner (draw)
  local winningTeam = match:getWinningTeam()
  assert(winningTeam == nil, "Should be a draw when all teams eliminated simultaneously")
end

--------------------------------------------------
-- teams field tests
--------------------------------------------------

local function testMatch_hasTeamsField()
  logger.info("testMatch_hasTeamsField")

  local match, teams = createTeamMatch(4, 2, 2)

  assert(match.teams ~= nil, "Match should have teams field")
  assert(#match.teams == 2, "Match should have 2 teams")
end

local function testMatch_setTeams()
  logger.info("testMatch_setTeams")

  local match, teams = createTeamMatch(4, 2, 2)

  -- Teams should be set correctly
  assert(match.teams[1].playerIndices[1] == 1)
  assert(match.teams[1].playerIndices[2] == 2)
  assert(match.teams[2].playerIndices[1] == 3)
  assert(match.teams[2].playerIndices[2] == 4)
end

--------------------------------------------------
-- getWinners returns all winning team members
--------------------------------------------------

local function testGetWinners_returnsTeamMembers()
  logger.info("testGetWinners_returnsTeamMembers")

  local match, teams = createTeamMatch(4, 2, 2)

  -- Kill Team B
  killStack(match.stacks[3])
  killStack(match.stacks[4])
  runFrames(match, 1)

  local winners = match:getWinners()

  -- Should return both Team A members (even if one died during match)
  -- Or just living members depending on implementation
  assert(winners ~= nil, "Should return winners")
  assert(#winners >= 1, "Should have at least 1 winner")

  -- All winners should be from Team A (indices 1 or 2)
  for _, winner in ipairs(winners) do
    local found = false
    for _, stack in ipairs(match.stacks) do
      if stack == winner then
        local stackIndex = _
        assert(stackIndex == 1 or stackIndex == 2, "Winners should be from Team A")
        found = true
        break
      end
    end
  end
end

--------------------------------------------------
-- Run all tests
--------------------------------------------------

-- 2v2 tests
testMatchEnds_whenOneTeamEliminated_2v2()
testMatchContinues_whenOnePlayerDies_2v2()
testMatchEnds_whenLastTeamMemberDies_2v2()

-- 1v2 tests
testMatchEnds_whenSoloEliminated_1v2()
testMatchEnds_whenTeamEliminated_1v2()
testMatchContinues_whenOneTeamMemberDies_1v2()

-- 3v3 tests (scalability)
testMatchEnds_3v3()
testMatchContinues_3v3_partialDeath()

-- Draw tests
testMatchEnds_draw()

-- Team field tests
testMatch_hasTeamsField()
testMatch_setTeams()
testGetWinners_returnsTeamMembers()

logger.info("All TeamMatchTests passed!")
