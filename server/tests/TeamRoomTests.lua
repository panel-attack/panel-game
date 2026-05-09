-- TeamRoomTests.lua
-- E2E tests for Room with 3-4 players in team modes
-- These tests will FAIL until team room logic is implemented (TDD red phase)

---@diagnostic disable: undefined-field, invisible, inject-field
local Room = require("server.Room")
local ServerTesting = require("server.tests.ServerTesting")
local GameModes = require("common.data.GameModes")
local json = require("common.lib.dkjson")
local ClientProtocol = require("common.network.ClientProtocol")
local logger = require("common.lib.logger")

COMPRESS_REPLAYS_ENABLED = true

-- Helper to get a 2v2 room with 4 players
local function get2v2Room()
  local p1 = ServerTesting.players[1]
  local p2 = ServerTesting.players[2]
  local p3 = ServerTesting.players[3]
  local p4 = ServerTesting.players[4]

  for _, p in ipairs({p1, p2, p3, p4}) do
    p:updateSettings({inputMethod = "controller", level = 10})
    p.save_replays_publicly = "not at all"
  end

  -- Create room with 4 players using 2v2 All mode
  local room = Room(1, {p1, p2, p3, p4}, GameModes.getPreset(GameModes.IDs.FOUR_PLAYER_TEAM_VS_ALL))

  -- Catch the game when it ends
  local gameCatcher = {
    catch = function(self, game) self.game = game end
  }
  room:connectSignal("matchEnd", gameCatcher, gameCatcher.catch)

  return room, p1, p2, p3, p4, gameCatcher
end

-- Helper to get a 1v2 room with 3 players
local function get1v2Room()
  local p1 = ServerTesting.players[1]  -- Solo
  local p2 = ServerTesting.players[2]  -- Team
  local p3 = ServerTesting.players[3]  -- Team

  for _, p in ipairs({p1, p2, p3}) do
    p:updateSettings({inputMethod = "controller", level = 10})
    p.save_replays_publicly = "not at all"
  end

  -- Create room with 3 players using 1v2 All mode
  local room = Room(1, {p1, p2, p3}, GameModes.getPreset(GameModes.IDs.THREE_PLAYER_VS_ALL))

  local gameCatcher = {
    catch = function(self, game) self.game = game end
  }
  room:connectSignal("matchEnd", gameCatcher, gameCatcher.catch)

  return room, p1, p2, p3, gameCatcher
end

-- Clear message queues for all players
local function clearMessages(players)
  for _, player in ipairs(players) do
    player.connection.outgoingMessageQueue:clear()
    player.connection.outgoingInputQueue:clear()
  end
end

--------------------------------------------------
-- Room creation tests
--------------------------------------------------

local function test2v2Room_creates()
  logger.info("test2v2Room_creates")

  local room, p1, p2, p3, p4, gameCatcher = get2v2Room()

  assert(room ~= nil, "Room should be created")
  assert(#room.players == 4, "Room should have 4 players")
end

local function test2v2Room_assignsTeams()
  logger.info("test2v2Room_assignsTeams")

  local room, p1, p2, p3, p4, gameCatcher = get2v2Room()

  assert(room.teams ~= nil, "Room should have teams")
  assert(#room.teams == 2, "Room should have 2 teams")

  -- Team 1: players 1 and 2
  assert(#room.teams[1].playerIndices == 2, "Team 1 should have 2 players")
  assert(room.teams[1].playerIndices[1] == 1, "Team 1 should have player 1")
  assert(room.teams[1].playerIndices[2] == 2, "Team 1 should have player 2")

  -- Team 2: players 3 and 4
  assert(#room.teams[2].playerIndices == 2, "Team 2 should have 2 players")
  assert(room.teams[2].playerIndices[1] == 3, "Team 2 should have player 3")
  assert(room.teams[2].playerIndices[2] == 4, "Team 2 should have player 4")
end

local function test1v2Room_assignsAsymmetricTeams()
  logger.info("test1v2Room_assignsAsymmetricTeams")

  local room, p1, p2, p3, gameCatcher = get1v2Room()

  assert(room.teams ~= nil, "Room should have teams")
  assert(#room.teams == 2, "Room should have 2 teams")

  -- Team 1: solo player
  assert(#room.teams[1].playerIndices == 1, "Team 1 (solo) should have 1 player")
  assert(room.teams[1].playerIndices[1] == 1)

  -- Team 2: 2 players
  assert(#room.teams[2].playerIndices == 2, "Team 2 should have 2 players")
end

--------------------------------------------------
-- Match start tests
--------------------------------------------------

local function test2v2Room_matchStarts()
  logger.info("test2v2Room_matchStarts")

  local room, p1, p2, p3, p4, gameCatcher = get2v2Room()

  -- Clear initial messages
  clearMessages({p1, p2, p3, p4})

  -- All players ready up
  for _, player in ipairs(room.players) do
    player:updateSettings({wants_ready = true, loaded = true, ready = true})
  end

  assert(room.matchCount == 1, "Match should have started")
  assert(room.game ~= nil, "Game should exist")

  -- All players should be in "playing" state
  for _, player in ipairs(room.players) do
    assert(player.state == "playing", "Player should be in 'playing' state")
  end
end

local function test2v2Room_allPlayersReceiveMatchStart()
  logger.info("test2v2Room_allPlayersReceiveMatchStart")

  local room, p1, p2, p3, p4, gameCatcher = get2v2Room()
  clearMessages({p1, p2, p3, p4})

  -- All players ready
  for _, player in ipairs(room.players) do
    player:updateSettings({wants_ready = true, loaded = true, ready = true})
  end

  -- All 4 players should receive matchStart message
  for i, player in ipairs({p1, p2, p3, p4}) do
    local msg = player.connection.outgoingMessageQueue:pop()
    assert(msg ~= nil, "Player " .. i .. " should receive a message")
    assert(msg.messageText.type == "matchStart", "Player " .. i .. " should receive matchStart")
  end
end

--------------------------------------------------
-- Input broadcast tests
--------------------------------------------------

local function test2v2Room_inputBroadcastToAll()
  logger.info("test2v2Room_inputBroadcastToAll")

  local room, p1, p2, p3, p4, gameCatcher = get2v2Room()

  -- Start match
  for _, player in ipairs(room.players) do
    player:updateSettings({wants_ready = true, loaded = true, ready = true})
  end
  clearMessages({p1, p2, p3, p4})

  -- P1 sends input
  room:broadcastInput("A", p1)

  -- P2, P3, P4 should all receive P1's input
  assert(p2.connection.outgoingInputQueue:len() == 1, "P2 should receive P1's input")
  assert(p3.connection.outgoingInputQueue:len() == 1, "P3 should receive P1's input")
  assert(p4.connection.outgoingInputQueue:len() == 1, "P4 should receive P1's input")

  -- P1 should NOT receive their own input
  assert(p1.connection.outgoingInputQueue:len() == 0, "P1 should NOT receive own input")
end

local function test2v2Room_inputPrefixes()
  logger.info("test2v2Room_inputPrefixes")

  local room, p1, p2, p3, p4, gameCatcher = get2v2Room()

  -- Start match
  for _, player in ipairs(room.players) do
    player:updateSettings({wants_ready = true, loaded = true, ready = true})
  end
  clearMessages({p1, p2, p3, p4})

  -- P1 (player_number 1) sends input - should use prefix "I"
  room:broadcastInput("A", p1)

  -- P2 (player_number 2) sends input - should use prefix "U"
  room:broadcastInput("B", p2)

  -- P3 (player_number 3) sends input - should use prefix "V"
  room:broadcastInput("C", p3)

  -- P4 (player_number 4) sends input - should use prefix "W"
  room:broadcastInput("D", p4)

  -- Verify prefixes by checking what other players received
  -- This depends on implementation - inputs are prefixed for identification
  -- The test verifies the infrastructure supports 4 player inputs
  local totalInputs = p1.connection.outgoingInputQueue:len()
  assert(totalInputs == 3, "P1 should have received 3 inputs (from P2, P3, P4)")
end

--------------------------------------------------
-- Game outcome tests - 2v2
--------------------------------------------------

local function test2v2Room_teamAWins()
  logger.info("test2v2Room_teamAWins")

  local room, p1, p2, p3, p4, gameCatcher = get2v2Room()

  -- Start match
  for _, player in ipairs(room.players) do
    player:updateSettings({wants_ready = true, loaded = true, ready = true})
  end
  clearMessages({p1, p2, p3, p4})

  -- Simulate some inputs
  for i = 1, 100 do
    room:broadcastInput("A", p1)
    room:broadcastInput("A", p2)
    room:broadcastInput("A", p3)
    room:broadcastInput("A", p4)
  end

  -- Team B (P3, P4) reports loss
  room:handleGameOverOutcome({outcome = 2, teamOutcome = 2}, p3)  -- P3 lost
  room:handleGameOverOutcome({outcome = 2, teamOutcome = 2}, p4)  -- P4 lost

  -- Team A (P1, P2) reports win
  room:handleGameOverOutcome({outcome = 1, teamOutcome = 1}, p1)  -- P1 won
  room:handleGameOverOutcome({outcome = 1, teamOutcome = 1}, p2)  -- P2 won

  assert(gameCatcher.game ~= nil, "Game should have ended")
  assert(gameCatcher.game.complete == true, "Game should be complete")

  -- Team A should be the winner (team index 1)
  assert(gameCatcher.game.winnerTeamIndex == 1, "Team A should be the winner")
end

local function test2v2Room_teamBWins()
  logger.info("test2v2Room_teamBWins")

  local room, p1, p2, p3, p4, gameCatcher = get2v2Room()

  -- Start match
  for _, player in ipairs(room.players) do
    player:updateSettings({wants_ready = true, loaded = true, ready = true})
  end
  clearMessages({p1, p2, p3, p4})

  -- Simulate inputs
  for i = 1, 100 do
    room:broadcastInput("A", p1)
    room:broadcastInput("A", p2)
    room:broadcastInput("A", p3)
    room:broadcastInput("A", p4)
  end

  -- Team A (P1, P2) reports loss
  room:handleGameOverOutcome({outcome = 2, teamOutcome = 2}, p1)
  room:handleGameOverOutcome({outcome = 2, teamOutcome = 2}, p2)

  -- Team B (P3, P4) reports win
  room:handleGameOverOutcome({outcome = 1, teamOutcome = 1}, p3)
  room:handleGameOverOutcome({outcome = 1, teamOutcome = 1}, p4)

  assert(gameCatcher.game.winnerTeamIndex == 2, "Team B should be the winner")
end

local function test2v2Room_partialElimination_matchContinues()
  logger.info("test2v2Room_partialElimination_matchContinues")

  local room, p1, p2, p3, p4, gameCatcher = get2v2Room()

  -- Start match
  for _, player in ipairs(room.players) do
    player:updateSettings({wants_ready = true, loaded = true, ready = true})
  end

  -- P1 dies but P2 still alive
  room:handlePlayerEliminated(p1)

  -- Match should continue
  assert(room.game ~= nil, "Game should still exist")
  assert(room.game.complete ~= true, "Game should not be complete")
end

local function test2v2Room_lastTeamMemberDies_matchEnds()
  logger.info("test2v2Room_lastTeamMemberDies_matchEnds")

  local room, p1, p2, p3, p4, gameCatcher = get2v2Room()

  -- Start match
  for _, player in ipairs(room.players) do
    player:updateSettings({wants_ready = true, loaded = true, ready = true})
  end

  -- Both Team A members die
  room:handlePlayerEliminated(p1)
  room:handlePlayerEliminated(p2)

  -- Match should end
  assert(gameCatcher.game ~= nil, "Game should have ended")
  assert(gameCatcher.game.winnerTeamIndex == 2, "Team B should win")
end

--------------------------------------------------
-- Game outcome tests - 1v2
--------------------------------------------------

local function test1v2Room_soloWins()
  logger.info("test1v2Room_soloWins")

  local room, p1, p2, p3, gameCatcher = get1v2Room()

  -- Start match
  for _, player in ipairs(room.players) do
    player:updateSettings({wants_ready = true, loaded = true, ready = true})
  end
  clearMessages({p1, p2, p3})

  -- Simulate inputs
  for i = 1, 100 do
    room:broadcastInput("A", p1)
    room:broadcastInput("A", p2)
    room:broadcastInput("A", p3)
  end

  -- Team (P2, P3) reports loss
  room:handleGameOverOutcome({outcome = 2, teamOutcome = 2}, p2)
  room:handleGameOverOutcome({outcome = 2, teamOutcome = 2}, p3)

  -- Solo (P1) reports win
  room:handleGameOverOutcome({outcome = 1, teamOutcome = 1}, p1)

  assert(gameCatcher.game.winnerTeamIndex == 1, "Solo should win")
end

local function test1v2Room_teamWins()
  logger.info("test1v2Room_teamWins")

  local room, p1, p2, p3, gameCatcher = get1v2Room()

  -- Start match
  for _, player in ipairs(room.players) do
    player:updateSettings({wants_ready = true, loaded = true, ready = true})
  end
  clearMessages({p1, p2, p3})

  -- Simulate inputs
  for i = 1, 100 do
    room:broadcastInput("A", p1)
    room:broadcastInput("A", p2)
    room:broadcastInput("A", p3)
  end

  -- Solo (P1) reports loss
  room:handleGameOverOutcome({outcome = 2, teamOutcome = 2}, p1)

  -- Team (P2, P3) reports win
  room:handleGameOverOutcome({outcome = 1, teamOutcome = 1}, p2)
  room:handleGameOverOutcome({outcome = 1, teamOutcome = 1}, p3)

  assert(gameCatcher.game.winnerTeamIndex == 2, "Team should win")
end

--------------------------------------------------
-- Win count tests
--------------------------------------------------

local function test2v2Room_winCountsUpdate()
  logger.info("test2v2Room_winCountsUpdate")

  local room, p1, p2, p3, p4, gameCatcher = get2v2Room()

  -- Start and complete a match with Team A winning
  for _, player in ipairs(room.players) do
    player:updateSettings({wants_ready = true, loaded = true, ready = true})
  end

  for i = 1, 100 do
    room:broadcastInput("A", p1)
    room:broadcastInput("A", p2)
    room:broadcastInput("A", p3)
    room:broadcastInput("A", p4)
  end

  room:handleGameOverOutcome({outcome = 2, teamOutcome = 2}, p3)
  room:handleGameOverOutcome({outcome = 2, teamOutcome = 2}, p4)
  room:handleGameOverOutcome({outcome = 1, teamOutcome = 1}, p1)
  room:handleGameOverOutcome({outcome = 1, teamOutcome = 1}, p2)

  -- Win counts should be updated for the team
  -- Both Team A members should have win count incremented
  assert(room.win_counts[1] == 1, "P1 win count should be 1")
  assert(room.win_counts[2] == 1, "P2 win count should be 1")
  assert(room.win_counts[3] == 0, "P3 win count should be 0")
  assert(room.win_counts[4] == 0, "P4 win count should be 0")
end

--------------------------------------------------
-- Game result message tests
--------------------------------------------------

local function test2v2Room_gameResultSentToAll()
  logger.info("test2v2Room_gameResultSentToAll")

  local room, p1, p2, p3, p4, gameCatcher = get2v2Room()

  -- Start match
  for _, player in ipairs(room.players) do
    player:updateSettings({wants_ready = true, loaded = true, ready = true})
  end
  clearMessages({p1, p2, p3, p4})

  -- Complete match
  for i = 1, 100 do
    room:broadcastInput("A", p1)
    room:broadcastInput("A", p2)
    room:broadcastInput("A", p3)
    room:broadcastInput("A", p4)
  end

  clearMessages({p1, p2, p3, p4})

  room:handleGameOverOutcome({outcome = 2, teamOutcome = 2}, p3)
  room:handleGameOverOutcome({outcome = 2, teamOutcome = 2}, p4)
  room:handleGameOverOutcome({outcome = 1, teamOutcome = 1}, p1)
  room:handleGameOverOutcome({outcome = 1, teamOutcome = 1}, p2)

  -- All players should receive gameResult
  for i, player in ipairs({p1, p2, p3, p4}) do
    local msg = player.connection.outgoingMessageQueue:pop()
    assert(msg ~= nil, "Player " .. i .. " should receive message")
    assert(msg.messageText.type == "gameResult", "Player " .. i .. " should receive gameResult")
  end
end

--------------------------------------------------
-- Room close tests
--------------------------------------------------

local function test2v2Room_close()
  logger.info("test2v2Room_close")

  local room, p1, p2, p3, p4, gameCatcher = get2v2Room()

  room:close()

  -- All players should be back in lobby
  for i, player in ipairs({p1, p2, p3, p4}) do
    assert(player.state == "lobby", "Player " .. i .. " should be in lobby after room close")
  end
end

--------------------------------------------------
-- Run all tests
--------------------------------------------------

-- Room creation
test2v2Room_creates()
test2v2Room_assignsTeams()
test1v2Room_assignsAsymmetricTeams()

-- Match start
test2v2Room_matchStarts()
test2v2Room_allPlayersReceiveMatchStart()

-- Input broadcast
test2v2Room_inputBroadcastToAll()
test2v2Room_inputPrefixes()

-- Game outcomes - 2v2
test2v2Room_teamAWins()
test2v2Room_teamBWins()
test2v2Room_partialElimination_matchContinues()
test2v2Room_lastTeamMemberDies_matchEnds()

-- Game outcomes - 1v2
test1v2Room_soloWins()
test1v2Room_teamWins()

-- Win counts
test2v2Room_winCountsUpdate()

-- Game result messages
test2v2Room_gameResultSentToAll()

-- Room close
test2v2Room_close()

logger.info("All TeamRoomTests passed!")
