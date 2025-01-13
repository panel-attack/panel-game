---@diagnostic disable: invisible, undefined-field
local MockPersistence = require("server.tests.MockPersistence")
local ClientProtocol = require("common.network.ClientProtocol")
local json = require("common.lib.dkjson")
local NetworkProtocol = require("common.network.NetworkProtocol")
local ServerTesting = require("server.tests.ServerTesting")
local Leaderboard = require("server.Leaderboard")
local GameModes = require("common.engine.GameModes")
local tableUtils = require("common.lib.tableUtils")

local function testLogin()
  local server = ServerTesting.getTestServer()

  local bob = ServerTesting.players[1]
  server:addConnection(bob.connection)
  server:update()

  bob.connection:receiveMessage(json.encode(ClientProtocol.requestLogin(bob.userId, bob.name, 10, "controller", "pacci", nil, nil, nil, nil, true, "with my name").messageText))
  server:update()

  assert(server.connectionNumberIndex == 2)
  local p = server.connectionToPlayer[bob.connection]
  assert(p)
  assert(server.nameToConnectionIndex["Bob"] == 1)
  assert(server.nameToPlayer["Bob"] == p)
  local message = bob.connection.outgoingMessageQueue:pop()
  assert(message and message.messageText.type == "loginResponse" and message.messageText.content.approved)
  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message and message.type == "lobbyState" and message.content.unpaired and message.content.unpaired[1] == "Bob")
end

local function testRoomSetup()
  local server = ServerTesting.getTestServer()
  local alice = ServerTesting.login(server, ServerTesting.players[2])
  local ben = ServerTesting.login(server, ServerTesting.players[3])
  local bob = ServerTesting.login(server, ServerTesting.players[1])
  -- there are other tests to verify lobby data
  ServerTesting.clearOutgoingMessages({alice, ben, bob})

  alice.connection:receiveMessage(json.encode(ClientProtocol.challengePlayer("Alice", "Ben").messageText))
  server:update()
  assert(server.proposals[alice][ben][alice])
  assert(server.proposals[ben][alice][alice])
  local message = ben.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "challenge" and message.content.sender == "Alice" and message.content.receiver == "Ben")
  assert(ben.connection.outgoingMessageQueue:len() == 0)

  ben.connection:receiveMessage(json.encode(ClientProtocol.challengePlayer("Ben", "Alice").messageText))
  server:update()
  assert(server.proposals[alice] == nil)
  assert(server.proposals[ben] == nil)
  assert(server.roomNumberIndex == 2)
  local room = server.playerToRoom[alice]
  assert(room and room.roomNumber == 1)
  assert(room == server.playerToRoom[ben])
  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "createRoom" and tableUtils.length(message.content.players) == 2)
  message = ben.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "createRoom" and tableUtils.length(message.content.players) == 2)

  message = bob.connection.outgoingMessageQueue:pop().messageText.content
  assert(message.unpaired and #message.unpaired == 1)
  assert(message.spectatable and #message.spectatable == 1)
end

local readyMessage = json.encode({menu_state = {wants_ready = true, loaded = true, ready = true}})

local function testGameplay()
  local server = ServerTesting.getTestServer()
  local alice = ServerTesting.login(server, ServerTesting.players[2])
  local ben = ServerTesting.login(server, ServerTesting.players[3])
  local bob = ServerTesting.login(server, ServerTesting.players[1])
  ServerTesting.setupRoom(server, alice, ben, true)
  ServerTesting.clearOutgoingMessages({alice, ben, bob})

  alice.connection:receiveMessage(readyMessage)
  server:update()
  local message = ben.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "settingsUpdate")
  ben.connection:receiveMessage(readyMessage)
  server:update()
  -- we only want to assert sparsely here because RoomTests take care of detailed asserts
  -- primarily we want to make sure that messages coming in via the connections are correctly routed to the Room
  -- and messages that should be sent as the result of room events back to the players
  -- so just do a cursory check if ONE of the expected things changed is enough to verify the message (probably) ended up where it should
  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "lobbyState")
  assert(message.content.unpaired and #message.content.unpaired == 1)
  assert(#message.content.spectatable == 1 and message.content.spectatable[1].state == "playing" and message.content.spectatable[1].roomNumber == 1)
  local matchStart = alice.connection.outgoingMessageQueue:pop().messageText
  assert(matchStart.type == "matchStart")
  matchStart = ben.connection.outgoingMessageQueue:pop().messageText
  assert(matchStart.type == "matchStart")

  alice.connection:receiveInput("A")
  ben.connection:receiveInput("g")
  server:update()
  local _, input = NetworkProtocol.getMessageFromString(alice.connection.outgoingInputQueue:pop(), true)
  assert(input and input == "g")
  _, input = NetworkProtocol.getMessageFromString(ben.connection.outgoingInputQueue:pop(), true)
  assert(input and input == "A")

  bob.connection:receiveMessage(json.encode(ClientProtocol.requestSpectate("Bob", 1).messageText))
  server:update()

  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "spectateRequestGranted")
  assert(message.content.replay)
  ---@type Replay
  local replay = message.content.replay
  -- by convention the player challenging first ends up as player two
  -- not formally required but something the test relies on, feel free to change if it crashes here due to that
  assert(replay.players[2].settings.inputs == "A1")
  assert(replay.players[1].settings.inputs == "g1")

  -- everyone gets the spectator update
  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "spectatorUpdate" and message.content and message.content[1] == "Bob")
  message = ben.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "spectatorUpdate" and message.content and message.content[1] == "Bob")
  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "spectatorUpdate" and message.content and message.content[1] == "Bob")

  alice.connection:receiveMessage(json.encode(ClientProtocol.reportLocalGameResult(2).messageText))
  server:update()
  ben.connection:receiveMessage(json.encode(ClientProtocol.reportLocalGameResult(2).messageText))
  server:update()

  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "gameResult")
  message = ben.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "gameResult")
  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "gameResult")

  -- with some bad luck we'll also get a ranked status update which the server sends way too many of
  alice.connection:receiveMessage(readyMessage)
  -- need to update one time extra to clear out the menu state message
  server:update()
  -- clear the menu state, kinda don't care
  ServerTesting.clearOutgoingMessages({alice, ben, bob})
  ben.connection:receiveMessage(readyMessage)
  server:update()

  -- we checked before that players get the message but not yet for spectators
  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "matchStart")

  -- surely this will work properly the second time as well for everyone else
  ServerTesting.clearOutgoingMessages({alice, ben, bob})

  ben.connection:receiveMessage(json.encode(ClientProtocol.leaveRoom().messageText))
  server:update()

  -- the others get informed about the room closing
  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "leaveRoom" and message.content.reason == "Ben left")
  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "leaveRoom" and message.content.reason == "Ben left")
  -- this was an active quit so ben should get the leave back as well
  message = ben.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "leaveRoom" and message.content.reason == "Ben left")

  -- everyone is back to lobby
  message = alice.connection.outgoingMessageQueue:pop().messageText.content
  assert(message.unpaired and #message.unpaired == 3 and #message.spectatable == 0)
  message = bob.connection.outgoingMessageQueue:pop().messageText.content
  assert(message.unpaired and #message.unpaired == 3 and #message.spectatable == 0)
  message = ben.connection.outgoingMessageQueue:pop().messageText.content
  assert(message.unpaired and #message.unpaired == 3 and #message.spectatable == 0)
end

local function testDisconnect()
  local server = ServerTesting.getTestServer()
  local bob = ServerTesting.login(server, ServerTesting.players[1])
  local alice = ServerTesting.login(server, ServerTesting.players[2])
  local ben = ServerTesting.login(server, ServerTesting.players[3])
  ServerTesting.setupRoom(server, alice, ben, true)
  ServerTesting.addSpectator(server, server.playerToRoom[alice], bob)
  ServerTesting.startGame(server, server.playerToRoom[alice])

  server:closeConnection(ben.connection, "Ben's connection failed")

  local message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "leaveRoom" and message.content.reason == "Ben's connection failed")
  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "leaveRoom" and message.content.reason == "Ben's connection failed")
  -- we closed the connection server side which under normal circumstances only happens in case of a disconnect
  -- so the server should no longer try to send them a message
  assert(ben.connection.outgoingMessageQueue:len() == 0)
  assert(ben.connection.loggedIn == false)
  assert(server.connectionToPlayer[ben.connection] == nil)

  server:update()

  -- the people that got kicked out get the new lobby state
  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "lobbyState" and message.content.unpaired and #message.content.unpaired == 2)
  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "lobbyState" and message.content.unpaired and #message.content.unpaired == 2)
end


local function testLobbyDataComposition()
  local server = ServerTesting.getTestServer()
  local leaderboard = Leaderboard(GameModes.getPreset("TWO_PLAYER_VS"), MockPersistence)
  for i, player in ipairs(ServerTesting.players) do
    ServerTesting.addToLeaderboard(leaderboard, player)
  end
  server.leaderboard = leaderboard

  local bob = ServerTesting.login(server, ServerTesting.players[1])
  local alice = ServerTesting.login(server, ServerTesting.players[2])
  local ben = ServerTesting.login(server, ServerTesting.players[3])
  local jerry = ServerTesting.login(server, ServerTesting.players[4])

  local room = ServerTesting.setupRoom(server, ben, jerry, true)
  ServerTesting.addSpectator(server, room, bob)
  ServerTesting.clearOutgoingMessages(ServerTesting.players)

  local berta = ServerTesting.login(server, ServerTesting.players[5])

  -- now everyone besides berta and alice are in the room and berta had her messages cleared after login including lobby
  -- so check what alice can see

  local message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "lobbyState")
  message = message.content
  assert(message.unpaired and #message.unpaired == 2)
  assert(message.players)
  assert(message.spectatable and #message.spectatable == 1)
  for _, unpaired in ipairs(message.unpaired) do
    assert(unpaired == "Alice" or unpaired == "Berta")
    -- alice and berta both have a rating
    assert(message.players[unpaired] and tonumber(message.players[unpaired].rating))
  end

  -- Jerry does not have a rating yet
  assert(message.players[message.spectatable[1].a] and not message.players[message.spectatable[1].a].rating)
  -- but Ben does
  assert(message.players[message.spectatable[1].b] and tonumber(message.players[message.spectatable[1].b].rating))

  -- bob as a spectator is invisible rip
  assert(not message.players["Bob"])
end

local function testSinglePlayer()
  local server = ServerTesting.getTestServer()
  local bob = ServerTesting.login(server, ServerTesting.players[1])
  local alice = ServerTesting.login(server, ServerTesting.players[2])

  ServerTesting.clearOutgoingMessages({bob, alice})

  bob.connection:receiveMessage(json.encode(ClientProtocol.sendRoomRequest(GameModes.getPreset("ONE_PLAYER_VS_SELF")).messageText))
  server:update()
  assert(server.playerToRoom[bob])
  local message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "createRoom")

  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "lobbyState")
  assert(#message.content.spectatable == 1)

  alice.connection:receiveMessage(json.encode(ClientProtocol.requestSpectate("Alice", server.playerToRoom[bob].roomNumber).messageText))
  server:update()

  assert(server.spectatorToRoom[alice] == server.playerToRoom[bob])
  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "spectatorUpdate")
  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "spectateRequestGranted" and message.content.replay == nil)
  assert(deep_content_equal(message.content.gameMode, GameModes.getPreset("ONE_PLAYER_VS_SELF")))
  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "spectatorUpdate")

  bob.connection:receiveMessage(readyMessage)
  server:update()

  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "matchStart")
  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "matchStart")

  alice.connection:receiveMessage(json.encode(ClientProtocol.leaveRoom().messageText))
  server:update()

  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "spectatorUpdate")
  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "leaveRoom")
  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "lobbyState")

  alice.connection:receiveMessage(json.encode(ClientProtocol.requestSpectate("Alice", server.playerToRoom[bob].roomNumber).messageText))
  server:update()

  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "spectatorUpdate")
  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "spectateRequestGranted" and message.content.replay ~= nil)
  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "spectatorUpdate")

  bob.connection:receiveMessage(json.encode(ClientProtocol.sendMatchAbort(server.playerToRoom[bob].roomNumber).messageText))
  server:update()

  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "gameAbort")
end

testLogin()
testRoomSetup()
testGameplay()
testDisconnect()
testLobbyDataComposition()
testSinglePlayer()