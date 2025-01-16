---@diagnostic disable: undefined-field, invisible, inject-field
local Room = require("server.Room")
local ServerTesting = require("server.tests.ServerTesting")
local GameModes = require("common.engine.GameModes")

COMPRESS_REPLAYS_ENABLED = true

local function getRoom()
  local p1 = ServerTesting.players[1]
  local p2 = ServerTesting.players[2]
  p1:updateSettings({inputMethod = "controller", level = 10})
  p2:updateSettings({inputMethod = "controller", level = 10})
  -- don't want to deal with I/O for the test
  p1.save_replays_publicly = "not at all"
  local room = Room(1, {p1, p2}, GameModes.getPreset("TWO_PLAYER_VS"))
  -- the game is being cleared from the room when it ends so catch the reference to assert against
  local gameCatcher = {
    catch = function(self, game) self.game = game end
  }
  room:connectSignal("matchEnd", gameCatcher, gameCatcher.catch)

  return room, p1, p2, gameCatcher
end

local function basicTest()
  local room, p1, p2, gameCatcher = getRoom()
  for i, player in ipairs(room.players) do
    assert(player.state == "character select")
    local firstMsg = player.connection.outgoingMessageQueue:pop()
    assert(firstMsg.messageText.type == "createRoom", "Expected create_room message")
  end
  p1:updateSettings({wants_ready = true, loaded = false, ready = false})
  p2:updateSettings({wants_ready = false, loaded = true, ready = false})
  p1:updateSettings({wants_ready = true, loaded = true, ready = false})
  p2:updateSettings({wants_ready = true, loaded = true, ready = true})
  assert(room.matchCount == 0, "Room should not have started the first match yet")
  for i, player in ipairs(room.players) do
    assert(player.state == "character select")
    local settingUpdateCount = 0
    local q = player.connection.outgoingMessageQueue
    for j = q.first, q.last do
      if q[j].messageText.type == "settingsUpdate" then
        settingUpdateCount = settingUpdateCount + 1
      end
    end
    assert(settingUpdateCount == 2, "Expected player " .. i .. " to have received 2 settings updates")
    q:clear()
  end
  p1:updateSettings({wants_ready = true, loaded = true, ready = true})
  assert(room.matchCount == 1, "Room should have started the first match")

  for i, player in ipairs(room.players) do
    assert(player.state == "playing")
    local firstMsg = player.connection.outgoingMessageQueue:pop()
    assert(firstMsg.messageText.type == "matchStart", "Expected match_start message")
  end

  for i = 1, 909 do
    room:broadcastInput("A", p1)
    room:broadcastInput("A", p2)
  end

  room:handleGameOverOutcome({outcome = 1}, p2)

  -- winner usually sends a few more inputs until they get the messages from the other play that the match is over
  room:broadcastInput("A", p1)
  room:broadcastInput("A", p1)
  room:broadcastInput("A", p1)

  room:handleGameOverOutcome({outcome = 1}, p1)
  assert(gameCatcher.game, "Expected the game catcher to catch the game")
  local replay = gameCatcher.game.replay
  assert(replay.players[1].settings.inputs == "A912")
  assert(replay.players[2].settings.inputs == "A909")
  assert(p1.state == "character select")
  assert(p2.state == "character select")
  assert(room.win_counts[1] == 1)
  assert(room.win_counts[2] == 0)
  assert(gameCatcher.game.winnerIndex == 1)
  assert(gameCatcher.game.winnerId == p1.publicPlayerID)
  assert(p1.connection.outgoingInputQueue:len() == 909)
  assert(p2.connection.outgoingInputQueue:len() == 912)

  for i, player in ipairs(room.players) do
    assert(player.state == "character select")
    local message = player.connection.outgoingMessageQueue:pop().messageText
    assert(message.type == "gameResult", "Expected player " .. i .. " to have received 1 gameResult message")
  end

  room:close()
  for i, player in ipairs({p1, p2}) do
    assert(player.state == "lobby")
    local firstMsg = player.connection.outgoingMessageQueue:pop()
    assert(firstMsg.messageText.type == "leaveRoom", "Expected leave_room message")
  end
end

-- p1 aborts after getting significantly ahead
local function abortTest1()
  local room, p1, p2, gameCatcher = getRoom()
  room:start_match()
  for i = 1, 120 do
    -- simulate inputs
    room:broadcastInput("A", p1)
  end
  p2.connection.outgoingMessageQueue:clear()
  room:handleGameAbort(p1)
  assert(room.game == nil)

  local game = gameCatcher.game
  assert(game.complete ~= true)
  local message = p2.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "gameAbort" and message.content.source == ServerTesting.players[1].name)
end

-- p1 aborts for no reason while p2 reports a win
local function abortTest2()
  local room, p1, p2, gameCatcher = getRoom()
  room:start_match()
  for i = 1, 120 do
    -- simulate inputs
    room:broadcastInput("A", p1)
    room:broadcastInput("A", p2)
  end

  p1.connection.outgoingMessageQueue:clear()
  p2.connection.outgoingMessageQueue:clear()
  room:handleGameAbort(p1)

  -- expectation is that the match did not end
  assert(room.game)
  assert(room.game.complete ~= true)
  assert(gameCatcher.game == nil)

  assert(p2.connection.outgoingMessageQueue:len() == 0)

  room:handleGameOverOutcome({outcome = 2}, p2)

  assert(room.game == nil)

  local game = gameCatcher.game
  assert(game.complete == true)

  local message = p2.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "gameResult" and message.content[1].placement == 2 and message.content[2].placement == 1)
  message = p1.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "gameResult" and message.content[1].placement == 2 and message.content[2].placement == 1)
end

-- both players abort despite no sufficiently significant difference in input count
-- I don't know if this is true but I would assume congestion and dropping of messages can be unidirectional so it seems possible that the server has the inputs but fails to get them to the player
local function abortTest3()
  local room, p1, p2, gameCatcher = getRoom()
  room:start_match()
  for i = 1, 120 do
    -- simulate inputs
    room:broadcastInput("A", p1)
    room:broadcastInput("A", p2)
  end

  p1.connection.outgoingMessageQueue:clear()
  p2.connection.outgoingMessageQueue:clear()
  room:handleGameAbort(p1)
  room:handleGameAbort(p2)

  assert(room.game == nil)

  local game = gameCatcher.game
  assert(game.complete == true)

  local message = p2.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "gameResult" and message.content[1].placement == 0 and message.content[2].placement == 0)
  message = p1.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "gameResult" and message.content[1].placement == 0 and message.content[2].placement == 0)
end

basicTest()
abortTest1()
abortTest2()
abortTest3()