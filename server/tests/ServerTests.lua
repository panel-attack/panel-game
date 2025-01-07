---@diagnostic disable: invisible, undefined-field
local Server = require("server.server")
local database = require("server.PADatabase")
local MockPersistence = require("server.tests.MockPersistence")
local ClientProtocol = require("common.network.ClientProtocol")
local MockConnection = require("server.tests.MockConnection")
local Player = require("server.Player")
local json = require("common.lib.dkjson")
local NetworkProtocol = require("common.network.NetworkProtocol")

-- as these integration tests are rather complex there is usually first a test testing a certain step
-- when the test paths a shortcut function is defined that effectively implements the step as a whole without the asserts for further tests

local players = {
  Player("1", MockConnection(), "Bob", 4),
  Player("2", MockConnection(), "Alice", 5),
  Player("3", MockConnection(), "Ben", 8),
  Player("4", MockConnection(), "Jerry", 24),
  Player("5", MockConnection(), "Berta", 38),
  Player("6", MockConnection(), "Raccoon", 83),
}

local playerData = {}
for i, player in ipairs(players) do
  player.connection.loggedIn = false
  playerData[player.userId] = player.name
end

local function getTestServer()
  local testServer = Server(database, MockPersistence)
  testServer:initializePlayerData("", playerData)

  -- we don't want to call anything that has anything to do with real sockets
  -- messages just get injected into the MockConnection queues
  testServer.update = function(self)
    self:processMessages()
    self:broadCastLobbyIfChanged()
    self.lastProcessTime = os.time()
  end

  return testServer
end

local function testLogin()
  local server = getTestServer()

  local bob = players[1]
  server:addConnection(bob.connection)
  server:update()

  bob.connection:receiveMessage(json.encode(ClientProtocol.requestLogin(bob.userId, bob.name, 10, "controller", "pacci", nil, nil, nil, nil, true, "with my name").messageText))
  server:update()

  assert(server.connectionNumberIndex == 2)
  local p = server.connectionToPlayer[bob.connection]
  assert(p)
  assert(server.nameToConnectionIndex["Bob"] == 1)
  assert(server.nameToPlayer["Bob"] == p)
  local loginApproval = bob.connection.outgoingMessageQueue:pop()
  assert(loginApproval and loginApproval.messageText.login_successful)
  local lobbyState = bob.connection.outgoingMessageQueue:pop()
  assert(lobbyState and lobbyState.messageText.unpaired and lobbyState.messageText.unpaired[1] == "Bob")
end

testLogin()

local function login(server, player)
  player.connection.loggedIn = false
  server:addConnection(player.connection)
  player.connection:receiveMessage(json.encode(ClientProtocol.requestLogin(player.userId, player.name, 10, "controller", "pacci", nil, nil, nil, nil, true, "with my name").messageText))
  server:update()
  player.connection.outgoingMessageQueue:clear()
end

local function clearOutgoingMessages(p)
  for _, player in pairs(p) do
    player.connection.outgoingMessageQueue:clear()
    player.connection.outgoingInputQueue:clear()
  end
end

local function testRoomSetup()
  local server = getTestServer()
  local alice = players[2]
  local ben = players[3]
  local bob = players[1]
  login(server, alice)
  login(server, ben)
  login(server, bob)
  clearOutgoingMessages(players)

  -- the server creates new player objects so we need to reassign
  alice = server.connectionToPlayer[alice.connection]
  ben = server.connectionToPlayer[ben.connection]
  bob = server.connectionToPlayer[bob.connection]

  alice.connection:receiveMessage(json.encode(ClientProtocol.challengePlayer("Alice", "Ben").messageText))
  server:update()
  assert(server.proposals[alice][ben][alice])
  assert(server.proposals[ben][alice][alice])
  local message = ben.connection.outgoingMessageQueue:pop().messageText
  assert(message.game_request and message.game_request.sender == "Alice" and message.game_request.receiver == "Ben")
  assert(ben.connection.outgoingMessageQueue:len() == 0)

  ben.connection:receiveMessage(json.encode(ClientProtocol.challengePlayer("Ben", "Alice").messageText))
  server:update()
  assert(server.proposals[alice] == nil)
  assert(server.proposals[ben] == nil)
  assert(server.roomNumberIndex == 2)
  local room = server.playerToRoom[alice]
  assert(room and room.roomNumber == 1)
  assert(room == server.playerToRoom[ben])
  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.unpaired and #message.unpaired == 1)
  assert(message.spectatable and #message.spectatable == 1)
end

testRoomSetup()

local function setupRoom(server, player1, player2)
  login(server, player1)
  login(server, player2)
  local p = {player1, player2}
  clearOutgoingMessages(p)
  player1.connection:receiveMessage(json.encode(ClientProtocol.challengePlayer(player1.name, player2.name).messageText))
  server:update()
  player2.connection:receiveMessage(json.encode(ClientProtocol.challengePlayer(player2.name, player1.name).messageText))
  server:update()
  clearOutgoingMessages(p)

  return server
end

local readyMessage = json.encode({menu_state = {wants_ready = true, loaded = true, ready = true}})

local function testGameplay()
  local server = getTestServer()
  local bob = players[1]
  login(server, bob)
  local alice = players[2]
  local ben = players[3]
  setupRoom(server, alice, ben)
  clearOutgoingMessages({bob})

  -- the server creates new player objects so we need to reassign
  alice = server.connectionToPlayer[alice.connection]
  ben = server.connectionToPlayer[ben.connection]
  bob = server.connectionToPlayer[bob.connection]

  alice.connection:receiveMessage(readyMessage)
  server:update()
  local menuState = ben.connection.outgoingMessageQueue:pop().messageText
  assert(menuState.menu_state)
  ben.connection:receiveMessage(readyMessage)
  server:update()
  -- we only want to assert sparsely here because RoomTests take care of detailed asserts
  -- primarily we want to make sure that messages coming in via the connections are correctly routed to the Room
  -- and messages that should be sent as the result of room events back to the players
  -- so just do a cursory check if ONE of the expected things changed is enough to verify the message (probably) ended up where it should
  local lobbyState = bob.connection.outgoingMessageQueue:pop().messageText
  assert(lobbyState.unpaired and #lobbyState.unpaired == 1)
  assert(#lobbyState.spectatable == 1 and lobbyState.spectatable[1].state == "playing" and lobbyState.spectatable[1].roomNumber == 1)
  local matchStart = alice.connection.outgoingMessageQueue:pop().messageText
  assert(matchStart.match_start)
  matchStart = ben.connection.outgoingMessageQueue:pop().messageText
  assert(matchStart.match_start)

  alice.connection:receiveInput("A")
  ben.connection:receiveInput("g")
  server:update()
  local _, input = NetworkProtocol.getMessageFromString(alice.connection.outgoingInputQueue:pop(), true)
  assert(input and input == "g")
  _, input = NetworkProtocol.getMessageFromString(ben.connection.outgoingInputQueue:pop(), true)
  assert(input and input == "A")

  bob.connection:receiveMessage(json.encode(ClientProtocol.requestSpectate("Bob", 1).messageText))
  server:update()

  local message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.spectate_request_granted)
  assert(message.replay_of_match_so_far)
  ---@type Replay
  local replay = message.replay_of_match_so_far
  -- by convention the player challenging first ends up as player two
  -- not formally required but something the test relies on, feel free to change if it crashes here due to that
  assert(replay.players[2].settings.inputs == "A1")
  assert(replay.players[1].settings.inputs == "g1")

  -- everyone gets the spectator update
  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.spectators and message.spectators[1] == "Bob")
  message = ben.connection.outgoingMessageQueue:pop().messageText
  assert(message.spectators and message.spectators[1] == "Bob")
  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.spectators and message.spectators[1] == "Bob")

  alice.connection:receiveMessage(json.encode(ClientProtocol.reportLocalGameResult(2).messageText))
  server:update()
  ben.connection:receiveMessage(json.encode(ClientProtocol.reportLocalGameResult(2).messageText))
  server:update()

  -- first we get win counts and then character select
  -- explicitly check not because win_counts comes separately but may also come with character_select I think
  -- realistically there is no need for these to be separate messages
  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.win_counts and not message.character_select)
  message = ben.connection.outgoingMessageQueue:pop().messageText
  assert(message.win_counts and not message.character_select)
  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.win_counts and not message.character_select)

  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.character_select)
  message = ben.connection.outgoingMessageQueue:pop().messageText
  assert(message.character_select)
  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.character_select)

  -- with some bad luck we'll also get a ranked status update which the server sends way too many of
  alice.connection:receiveMessage(readyMessage)
  -- need to update one time extra to clear out the menu state message
  server:update()
  -- clear the menu state, kinda don't care
  clearOutgoingMessages({alice, ben, bob})
  ben.connection:receiveMessage(readyMessage)
  server:update()

  -- we checked before that players get the message but not yet for spectators
  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.match_start)

  -- surely this will work properly the second time as well for everyone else
  clearOutgoingMessages({alice, ben, bob})

  ben.connection:receiveMessage(json.encode(ClientProtocol.leaveRoom().messageText))
  server:update()

  -- the others get informed about the room closing
  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.leave_room)
  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.leave_room)
  -- this was an active quit so ben should get the leave back as well
  message = ben.connection.outgoingMessageQueue:pop().messageText
  assert(message.leave_room)

  -- everyone is back to lobby
  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.unpaired and #message.unpaired == 3 and #message.spectatable == 0)
  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.unpaired and #message.unpaired == 3 and #message.spectatable == 0)
  message = ben.connection.outgoingMessageQueue:pop().messageText
  assert(message.unpaired and #message.unpaired == 3 and #message.spectatable == 0)
end

testGameplay()

local function startGame(server, room)
  for i, player in ipairs(room.players) do
    player.connection:receiveMessage(readyMessage)
  end
  server:update()
  clearOutgoingMessages(room.players)
  clearOutgoingMessages(room.spectators)
end

local function addSpectator(server, room, spectator)
  spectator.connection:receiveMessage(json.encode(ClientProtocol.requestSpectate(spectator.name, room.roomNumber).messageText))
  server:update()
  clearOutgoingMessages({spectator})
end

local function testDisconnect()
  local server = getTestServer()
  local bob = players[1]
  login(server, bob)
  local alice = players[2]
  local ben = players[3]
  setupRoom(server, alice, ben)
  -- the server creates new player objects so we need to reassign
  alice = server.connectionToPlayer[alice.connection]
  ben = server.connectionToPlayer[ben.connection]
  bob = server.connectionToPlayer[bob.connection]
  addSpectator(server, server.playerToRoom[alice], bob)
  startGame(server, server.playerToRoom[alice])

  server:closeConnection(ben.connection)

  local message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.leave_room)
  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.leave_room)
  -- we closed the connection server side which under normal circumstances only happens in case of a disconnect
  -- so the server should no longer try to send them a message
  assert(ben.connection.outgoingMessageQueue:len() == 0)
  assert(ben.connection.loggedIn == false)
  assert(server.connectionToPlayer[ben.connection] == nil)

  server:update()

  -- the people that got kicked out get the new lobby state
  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.unpaired and #message.unpaired == 2)
  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.unpaired and #message.unpaired == 2)
end

testDisconnect()