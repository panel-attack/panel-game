-- TeamUtilsTests.lua
-- Unit tests for team utility functions
-- These tests will FAIL until TeamUtils is implemented (TDD red phase)

local logger = require("common.lib.logger")

-- Will be implemented in common/data/TeamUtils.lua
local TeamUtils = require("common.data.TeamUtils")

-- Helper to create mock stacks with alive/dead state
local function createMockStacks(count, deadIndices)
  deadIndices = deadIndices or {}
  local stacks = {}
  for i = 1, count do
    local isDead = false
    for _, deadIndex in ipairs(deadIndices) do
      if deadIndex == i then
        isDead = true
        break
      end
    end
    stacks[i] = {
      game_ended = function() return isDead end
    }
  end
  return stacks
end

--------------------------------------------------
-- createTeams tests
--------------------------------------------------

local function testCreateTeams_2v2()
  logger.info("testCreateTeams_2v2")

  -- 4 players, 2 teams of 2
  local teams = TeamUtils.createTeams(4, 2, 2)

  assert(#teams == 2, "Should create 2 teams")
  assert(teams[1].id == 1, "Team 1 should have id 1")
  assert(teams[2].id == 2, "Team 2 should have id 2")

  -- Team 1: players 1 and 2
  assert(#teams[1].playerIndices == 2, "Team 1 should have 2 players")
  assert(teams[1].playerIndices[1] == 1, "Team 1 should have player 1")
  assert(teams[1].playerIndices[2] == 2, "Team 1 should have player 2")

  -- Team 2: players 3 and 4
  assert(#teams[2].playerIndices == 2, "Team 2 should have 2 players")
  assert(teams[2].playerIndices[1] == 3, "Team 2 should have player 3")
  assert(teams[2].playerIndices[2] == 4, "Team 2 should have player 4")
end

local function testCreateTeams_1v2()
  logger.info("testCreateTeams_1v2")

  -- 3 players, asymmetric teams: {1, 2}
  local teams = TeamUtils.createTeams(3, 2, {1, 2})

  assert(#teams == 2, "Should create 2 teams")

  -- Team 1: solo player (player 1)
  assert(#teams[1].playerIndices == 1, "Team 1 should have 1 player")
  assert(teams[1].playerIndices[1] == 1, "Team 1 should have player 1")

  -- Team 2: players 2 and 3
  assert(#teams[2].playerIndices == 2, "Team 2 should have 2 players")
  assert(teams[2].playerIndices[1] == 2, "Team 2 should have player 2")
  assert(teams[2].playerIndices[2] == 3, "Team 2 should have player 3")
end

local function testCreateTeams_3v3()
  logger.info("testCreateTeams_3v3")

  -- 6 players, 2 teams of 3
  local teams = TeamUtils.createTeams(6, 2, 3)

  assert(#teams == 2, "Should create 2 teams")
  assert(#teams[1].playerIndices == 3, "Team 1 should have 3 players")
  assert(#teams[2].playerIndices == 3, "Team 2 should have 3 players")

  assert(teams[1].playerIndices[1] == 1)
  assert(teams[1].playerIndices[2] == 2)
  assert(teams[1].playerIndices[3] == 3)

  assert(teams[2].playerIndices[1] == 4)
  assert(teams[2].playerIndices[2] == 5)
  assert(teams[2].playerIndices[3] == 6)
end

--------------------------------------------------
-- getTeamForPlayer tests
--------------------------------------------------

local function testGetTeamForPlayer()
  logger.info("testGetTeamForPlayer")

  local teams = TeamUtils.createTeams(4, 2, 2)

  -- Player 1 should be on Team 1
  local team1 = TeamUtils.getTeamForPlayer(1, teams)
  assert(team1 == teams[1], "Player 1 should be on Team 1")

  -- Player 2 should be on Team 1
  local team2 = TeamUtils.getTeamForPlayer(2, teams)
  assert(team2 == teams[1], "Player 2 should be on Team 1")

  -- Player 3 should be on Team 2
  local team3 = TeamUtils.getTeamForPlayer(3, teams)
  assert(team3 == teams[2], "Player 3 should be on Team 2")

  -- Player 4 should be on Team 2
  local team4 = TeamUtils.getTeamForPlayer(4, teams)
  assert(team4 == teams[2], "Player 4 should be on Team 2")
end

local function testGetTeamForPlayer_invalidPlayer()
  logger.info("testGetTeamForPlayer_invalidPlayer")

  local teams = TeamUtils.createTeams(4, 2, 2)

  -- Player 5 doesn't exist
  local team = TeamUtils.getTeamForPlayer(5, teams)
  assert(team == nil, "Should return nil for invalid player")
end

--------------------------------------------------
-- isTeamAlive tests
--------------------------------------------------

local function testIsTeamAlive_allAlive()
  logger.info("testIsTeamAlive_allAlive")

  local teams = TeamUtils.createTeams(4, 2, 2)
  local stacks = createMockStacks(4, {})  -- No dead players

  local alive = TeamUtils.isTeamAlive(teams[1], stacks)
  assert(alive == true, "Team with all players alive should be alive")
end

local function testIsTeamAlive_someAlive()
  logger.info("testIsTeamAlive_someAlive")

  local teams = TeamUtils.createTeams(4, 2, 2)
  local stacks = createMockStacks(4, {1})  -- Player 1 is dead

  local alive = TeamUtils.isTeamAlive(teams[1], stacks)
  assert(alive == true, "Team with at least 1 player alive should be alive")
end

local function testIsTeamAlive_noneAlive()
  logger.info("testIsTeamAlive_noneAlive")

  local teams = TeamUtils.createTeams(4, 2, 2)
  local stacks = createMockStacks(4, {1, 2})  -- Players 1 and 2 are dead

  local alive = TeamUtils.isTeamAlive(teams[1], stacks)
  assert(alive == false, "Team with no players alive should be dead")
end

--------------------------------------------------
-- getLivingEnemies tests
--------------------------------------------------

local function testGetLivingEnemies_allAlive()
  logger.info("testGetLivingEnemies_allAlive")

  local teams = TeamUtils.createTeams(4, 2, 2)
  local stacks = createMockStacks(4, {})  -- No dead players

  -- Get enemies for player 1 (on Team 1)
  local enemies = TeamUtils.getLivingEnemies(1, teams, stacks)

  assert(#enemies == 2, "Should have 2 living enemies")
  assert(enemies[1] == 3, "First enemy should be player 3")
  assert(enemies[2] == 4, "Second enemy should be player 4")
end

local function testGetLivingEnemies_someDead()
  logger.info("testGetLivingEnemies_someDead")

  local teams = TeamUtils.createTeams(4, 2, 2)
  local stacks = createMockStacks(4, {3})  -- Player 3 is dead

  -- Get enemies for player 1
  local enemies = TeamUtils.getLivingEnemies(1, teams, stacks)

  assert(#enemies == 1, "Should have 1 living enemy")
  assert(enemies[1] == 4, "Only living enemy should be player 4")
end

local function testGetLivingEnemies_allDead()
  logger.info("testGetLivingEnemies_allDead")

  local teams = TeamUtils.createTeams(4, 2, 2)
  local stacks = createMockStacks(4, {3, 4})  -- Players 3 and 4 are dead

  -- Get enemies for player 1
  local enemies = TeamUtils.getLivingEnemies(1, teams, stacks)

  assert(#enemies == 0, "Should have 0 living enemies")
end

local function testGetLivingEnemies_excludesTeammates()
  logger.info("testGetLivingEnemies_excludesTeammates")

  local teams = TeamUtils.createTeams(4, 2, 2)
  local stacks = createMockStacks(4, {})

  -- Get enemies for player 1
  local enemies = TeamUtils.getLivingEnemies(1, teams, stacks)

  -- Should not include player 2 (teammate)
  for _, enemyIndex in ipairs(enemies) do
    assert(enemyIndex ~= 2, "Teammate should not be in enemy list")
  end
end

--------------------------------------------------
-- getTeamsAliveCount tests
--------------------------------------------------

local function testGetTeamsAliveCount_allAlive()
  logger.info("testGetTeamsAliveCount_allAlive")

  local teams = TeamUtils.createTeams(4, 2, 2)
  local stacks = createMockStacks(4, {})

  local count = TeamUtils.getTeamsAliveCount(teams, stacks)
  assert(count == 2, "Both teams should be alive")
end

local function testGetTeamsAliveCount_oneTeamDead()
  logger.info("testGetTeamsAliveCount_oneTeamDead")

  local teams = TeamUtils.createTeams(4, 2, 2)
  local stacks = createMockStacks(4, {3, 4})  -- Team 2 is dead

  local count = TeamUtils.getTeamsAliveCount(teams, stacks)
  assert(count == 1, "Only one team should be alive")
end

local function testGetTeamsAliveCount_allDead()
  logger.info("testGetTeamsAliveCount_allDead")

  local teams = TeamUtils.createTeams(4, 2, 2)
  local stacks = createMockStacks(4, {1, 2, 3, 4})  -- All dead

  local count = TeamUtils.getTeamsAliveCount(teams, stacks)
  assert(count == 0, "No teams should be alive")
end

--------------------------------------------------
-- getWinningTeam tests
--------------------------------------------------

local function testGetWinningTeam_team1Wins()
  logger.info("testGetWinningTeam_team1Wins")

  local teams = TeamUtils.createTeams(4, 2, 2)
  local stacks = createMockStacks(4, {3, 4})  -- Team 2 is dead

  local winner = TeamUtils.getWinningTeam(teams, stacks)
  assert(winner == teams[1], "Team 1 should be the winner")
end

local function testGetWinningTeam_team2Wins()
  logger.info("testGetWinningTeam_team2Wins")

  local teams = TeamUtils.createTeams(4, 2, 2)
  local stacks = createMockStacks(4, {1, 2})  -- Team 1 is dead

  local winner = TeamUtils.getWinningTeam(teams, stacks)
  assert(winner == teams[2], "Team 2 should be the winner")
end

local function testGetWinningTeam_noWinnerYet()
  logger.info("testGetWinningTeam_noWinnerYet")

  local teams = TeamUtils.createTeams(4, 2, 2)
  local stacks = createMockStacks(4, {1})  -- Only player 1 is dead

  local winner = TeamUtils.getWinningTeam(teams, stacks)
  assert(winner == nil, "No winner yet - both teams have living players")
end

local function testGetWinningTeam_draw()
  logger.info("testGetWinningTeam_draw")

  local teams = TeamUtils.createTeams(4, 2, 2)
  local stacks = createMockStacks(4, {1, 2, 3, 4})  -- All dead simultaneously

  local winner = TeamUtils.getWinningTeam(teams, stacks)
  assert(winner == nil, "No winner in case of draw")
end

--------------------------------------------------
-- Run all tests
--------------------------------------------------

testCreateTeams_2v2()
testCreateTeams_1v2()
testCreateTeams_3v3()

testGetTeamForPlayer()
testGetTeamForPlayer_invalidPlayer()

testIsTeamAlive_allAlive()
testIsTeamAlive_someAlive()
testIsTeamAlive_noneAlive()

testGetLivingEnemies_allAlive()
testGetLivingEnemies_someDead()
testGetLivingEnemies_allDead()
testGetLivingEnemies_excludesTeammates()

testGetTeamsAliveCount_allAlive()
testGetTeamsAliveCount_oneTeamDead()
testGetTeamsAliveCount_allDead()

testGetWinningTeam_team1Wins()
testGetWinningTeam_team2Wins()
testGetWinningTeam_noWinnerYet()
testGetWinningTeam_draw()

logger.info("All TeamUtilsTests passed!")
