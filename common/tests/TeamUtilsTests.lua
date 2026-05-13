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
-- findNextLiving — round-robin walk shared across Match, Room, ClientMatch
--------------------------------------------------

-- Builds an aliveFn over a fixed dead-set (slot numbers, not positions).
local function aliveExcept(deadSet)
  local dead = {}
  for _, s in ipairs(deadSet) do dead[s] = true end
  return function(slot) return not dead[slot] end
end

local function testFindNextLiving_allAlive_picksStart_advancesByOne()
  logger.info("testFindNextLiving_allAlive_picksStart_advancesByOne")
  local enemies = { 2, 3, 4 }
  local picked, slot, nextLiving = TeamUtils.findNextLiving(enemies, 1, aliveExcept({}))
  assert(picked == 1 and slot == 2 and nextLiving == 2,
    string.format("startIndex=1: expected (1,2,2), got (%s,%s,%s)",
      tostring(picked), tostring(slot), tostring(nextLiving)))
end

local function testFindNextLiving_skipsDeadFromStart()
  logger.info("testFindNextLiving_skipsDeadFromStart")
  local enemies = { 2, 3, 4 }
  -- Slot 2 (position 1) dead; cursor starts at position 1, should walk to 2.
  local picked, slot, nextLiving = TeamUtils.findNextLiving(enemies, 1, aliveExcept({ 2 }))
  assert(picked == 2 and slot == 3, "should skip dead start and pick slot 3")
  assert(nextLiving == 3, "next-living after slot 3 should be slot 4 at position 3")
end

local function testFindNextLiving_wrapsForwardOverDead()
  logger.info("testFindNextLiving_wrapsForwardOverDead")
  local enemies = { 2, 3, 4 }
  -- Cursor at position 3 (slot 4), slot 4 dead, slot 2 dead. Should wrap to slot 3.
  local picked, slot, nextLiving = TeamUtils.findNextLiving(enemies, 3, aliveExcept({ 4, 2 }))
  assert(picked == 2 and slot == 3, "should wrap forward over both dead and pick slot 3")
  -- Only slot 3 is alive — nextLiving should be nil.
  assert(nextLiving == nil, "nextLiving should be nil when only one survivor exists")
end

local function testFindNextLiving_allDeadReturnsNil()
  logger.info("testFindNextLiving_allDeadReturnsNil")
  local enemies = { 2, 3, 4 }
  local picked, slot, nextLiving = TeamUtils.findNextLiving(enemies, 1, aliveExcept({ 2, 3, 4 }))
  assert(picked == nil and slot == nil and nextLiving == nil,
    "all dead should return three nils")
end

local function testFindNextLiving_emptyListReturnsNil()
  logger.info("testFindNextLiving_emptyListReturnsNil")
  local picked, slot, nextLiving = TeamUtils.findNextLiving({}, 1, function() return true end)
  assert(picked == nil and slot == nil and nextLiving == nil,
    "empty list should return three nils")
end

local function testFindNextLiving_startIndexOutOfRangeWraps()
  logger.info("testFindNextLiving_startIndexOutOfRangeWraps")
  local enemies = { 2, 3, 4 }
  -- startIndex=5 should wrap to position 2 (5 → (5-1) % 3 + 1 = 2).
  local picked, slot = TeamUtils.findNextLiving(enemies, 5, aliveExcept({}))
  assert(picked == 2 and slot == 3, "out-of-range startIndex should wrap into [1,n]")
end

local function testFindNextLiving_advanceAlternatesBetweenTwo()
  logger.info("testFindNextLiving_advanceAlternatesBetweenTwo")
  -- 2 living enemies: cursor walks 1 → 2 → 1 → 2.
  local enemies = { 2, 3 }
  local picked, _, nextLiving = TeamUtils.findNextLiving(enemies, 1, aliveExcept({}))
  assert(picked == 1 and nextLiving == 2, "first pick at 1, next is 2")
  picked, _, nextLiving = TeamUtils.findNextLiving(enemies, nextLiving, aliveExcept({}))
  assert(picked == 2 and nextLiving == 1, "second pick at 2, next wraps to 1")
end

local function testFindNextLiving_2v1_soloIsOnlySurvivor()
  logger.info("testFindNextLiving_2v1_soloIsOnlySurvivor")
  -- Team-of-1's enemies are slots {1, 2}; both team-of-2 members alive.
  -- Cursor walks 1 → 2 → 1 → 2. After slot 1 dies, cursor lands on slot 2
  -- and stays there (no other living target).
  local enemies = { 1, 2 }
  local picked, slot, nextLiving = TeamUtils.findNextLiving(enemies, 2, aliveExcept({ 1 }))
  assert(picked == 2 and slot == 2, "with slot 1 dead, should pick slot 2")
  assert(nextLiving == nil, "no other living => nextLiving nil; caller keeps cursor where it is")
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

testFindNextLiving_allAlive_picksStart_advancesByOne()
testFindNextLiving_skipsDeadFromStart()
testFindNextLiving_wrapsForwardOverDead()
testFindNextLiving_allDeadReturnsNil()
testFindNextLiving_emptyListReturnsNil()
testFindNextLiving_startIndexOutOfRangeWraps()
testFindNextLiving_advanceAlternatesBetweenTwo()
testFindNextLiving_2v1_soloIsOnlySurvivor()

logger.info("All TeamUtilsTests passed!")
