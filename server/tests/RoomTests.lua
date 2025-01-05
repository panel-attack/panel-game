---@diagnostic disable: undefined-field, invisible, inject-field
local Room = require("server.Room")
local Player = require("server.Player")
local MockConnection = require("server.tests.MockConnection")
local MockDB = require("server.tests.MockDatabase")

COMPRESS_REPLAYS_ENABLED = true

local function getRoom()
  local p1 = Player("1", MockConnection(), "Bob", 4)
  local p2 = Player("2", MockConnection(), "Alice", 5)
  p1:updateSettings({inputMethod = "controller", level = 10})
  p2:updateSettings({inputMethod = "controller", level = 10})
  -- don't want to deal with I/O for the test
  p1.save_replays_publicly = "not at all"
  local room = Room(1, {p1, p2}, MockDB)
  -- the game is being cleared from the room when it ends so catch the reference to assert against
  local gameCatcher = {
    catch = function(self, r, game) self.game = game end
  }
  room:connectSignal("matchEnd", gameCatcher, gameCatcher.catch)

  return room, p1, p2, gameCatcher
end

local function basicTest()
  local room, p1, p2, gameCatcher = getRoom()
  for i, player in ipairs(room.players) do
    assert(player.state == "character select")
    local firstMsg = player.connection.outgoingMessageQueue:pop()
    assert(firstMsg.messageText.create_room, "Expected create_room message")
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
      if q[j].messageText.menu_state then
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
    assert(firstMsg.messageText.match_start, "Expected match_start message")
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
    local winCountCount = 0
    local characterSelectCount = 0
    local q = player.connection.outgoingMessageQueue
    for j = q.first, q.last do
      if q[j].messageText.character_select then
        characterSelectCount = characterSelectCount + 1
      elseif q[j].messageText.win_counts then
        winCountCount = winCountCount + 1
      end
    end
    assert(winCountCount == 1, "Expected player " .. i .. " to have received 1 win count update")
    assert(characterSelectCount == 1, "Expected player " .. i .. " to have received 1 character select message")
    q:clear()
  end

  room:close()
  for i, player in ipairs({p1, p2}) do
    assert(player.state == "lobby")
    local firstMsg = player.connection.outgoingMessageQueue:pop()
    assert(firstMsg.messageText.leave_room, "Expected leave_room message")
  end
end

basicTest()