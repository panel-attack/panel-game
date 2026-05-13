---@diagnostic disable: invisible, undefined-field
local MockPersistence = require("server.tests.MockPersistence")
local ClientProtocol = require("common.network.ClientProtocol")
local json = require("common.lib.dkjson")
local NetworkProtocol = require("common.network.NetworkProtocol")
local ServerTesting = require("server.tests.ServerTesting")
local Leaderboard = require("server.Leaderboard")
local GameModes = require("common.data.GameModes")
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

  local loginApproved = false
  local lobbyStateMessage = nil
  while bob.connection.outgoingMessageQueue:len() > 0 do
    local queuedMessage = bob.connection.outgoingMessageQueue:pop()
    local message = queuedMessage and queuedMessage.messageText
    if message and message.type == "loginResponse" and message.content and message.content.approved then
      loginApproved = true
    elseif message and message.type == "lobbyStateV2" then
      lobbyStateMessage = message
      break
    end
  end

  assert(loginApproved)
  assert(lobbyStateMessage and lobbyStateMessage.content.players)
  local bobFound = false
  for _, playerData in pairs(lobbyStateMessage.content.players) do
    if playerData and playerData.name == "Bob" then
      bobFound = true
      break
    end
  end
  assert(bobFound)
end

local function testRoomSetup()
  local server = ServerTesting.getTestServer()
  local alice = ServerTesting.login(server, ServerTesting.players[2])
  local ben = ServerTesting.login(server, ServerTesting.players[3])
  local bob = ServerTesting.login(server, ServerTesting.players[1])
  -- there are other tests to verify lobby data
  ServerTesting.clearOutgoingMessages({alice, ben, bob})

  alice.connection:receiveMessage(json.encode(ClientProtocol.updateChallengeStatus(alice.publicPlayerID, ben.publicPlayerID, GameModes.IDs.TWO_PLAYER_VS, true).messageText))
  server:update()
  assert(server.proposals[alice.publicPlayerID][ben.publicPlayerID][GameModes.IDs.TWO_PLAYER_VS] == true)
  local message = ben.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "challengeUpdate" and message.content.sender == "Alice" and message.content.receiver == "Ben")
  assert(ben.connection.outgoingMessageQueue:len() == 0)

  ben.connection:receiveMessage(json.encode(ClientProtocol.updateChallengeStatus(ben.publicPlayerID, alice.publicPlayerID, GameModes.IDs.TWO_PLAYER_VS, true).messageText))
  server:update()
  assert(server.proposals[alice.publicPlayerID] == nil or next(server.proposals[alice.publicPlayerID]) == nil)
  assert(server.proposals[ben.publicPlayerID] == nil or next(server.proposals[ben.publicPlayerID]) == nil)
  assert(server.roomNumberIndex == 2)
  local room = server.playerToRoom[alice]
  assert(room and room.roomNumber == 1)
  assert(room == server.playerToRoom[ben])
  assert(room.gameMode.name == GameModes.gameModeIdToName[GameModes.IDs.TWO_PLAYER_VS])
  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "addToRoom" and tableUtils.length(message.content.players) == 2)
  message = ben.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "addToRoom" and tableUtils.length(message.content.players) == 2)

  message = bob.connection.outgoingMessageQueue:pop().messageText.content
  assert(message.players and tableUtils.length(message.players) == 3)
  assert(message.rooms and tableUtils.length(message.rooms) == 1)
end

-- same as the other one, except we're specifying TWO_PLAYER_TIME_ATTACK as the game mode for the challenges
local function testRoomSetup2()
  local server = ServerTesting.getTestServer()
  local alice = ServerTesting.login(server, ServerTesting.players[2])
  local ben = ServerTesting.login(server, ServerTesting.players[3])
  local bob = ServerTesting.login(server, ServerTesting.players[1])
  -- there are other tests to verify lobby data
  ServerTesting.clearOutgoingMessages({alice, ben, bob})

  alice.connection:receiveMessage(json.encode(ClientProtocol.updateChallengeStatus(alice.publicPlayerID, ben.publicPlayerID, GameModes.IDs.TWO_PLAYER_TIME_ATTACK, true).messageText))
  server:update()
  assert(server.proposals[alice.publicPlayerID][ben.publicPlayerID][GameModes.IDs.TWO_PLAYER_TIME_ATTACK] == true)
  local message = ben.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "challengeUpdate" and message.content.sender == "Alice" and message.content.receiver == "Ben")
  assert(ben.connection.outgoingMessageQueue:len() == 0)

  ben.connection:receiveMessage(json.encode(ClientProtocol.updateChallengeStatus(ben.publicPlayerID, alice.publicPlayerID, GameModes.IDs.TWO_PLAYER_TIME_ATTACK, true).messageText))
  server:update()
  assert(server.proposals[alice.publicPlayerID] == nil or next(server.proposals[alice.publicPlayerID]) == nil)
  assert(server.proposals[ben.publicPlayerID] == nil or next(server.proposals[ben.publicPlayerID]) == nil)
  assert(server.roomNumberIndex == 2)
  local room = server.playerToRoom[alice]
  assert(room and room.roomNumber == 1)
  assert(room == server.playerToRoom[ben])
  assert(room.gameMode.name == GameModes.gameModeIdToName[GameModes.IDs.TWO_PLAYER_TIME_ATTACK])
  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "addToRoom" and tableUtils.length(message.content.players) == 2)
  message = ben.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "addToRoom" and tableUtils.length(message.content.players) == 2)

  message = bob.connection.outgoingMessageQueue:pop().messageText.content
  assert(message.players and tableUtils.length(message.players) == 3)
  assert(message.rooms and tableUtils.length(message.rooms) == 1)
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
  assert(message.type == "lobbyStateV2")
  assert(message.content.players and tableUtils.length(message.content.players) == 3)
  assert(tableUtils.length(message.content.rooms) == 1)
  local roomNumber, lobbyRoomV2 = next(message.content.rooms)
  assert(lobbyRoomV2.state == "playing" and lobbyRoomV2.roomNumber == 1)

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
  ---@type ReplayV3
  local replay = message.content.replay
  -- by convention the player challenging first ends up as player two
  -- not formally required but something the test relies on, feel free to change if it crashes here due to that
  assert(replay.stacks[2].inputs == "A1")
  assert(replay.stacks[1].inputs == "g1")

  -- everyone gets the spectator update
  local function assertNextSpectatorUpdate(connection, spectatorName)
    local found = false
    while connection.outgoingMessageQueue:len() > 0 do
      local queuedMessage = connection.outgoingMessageQueue:pop().messageText
      if queuedMessage.type == "spectatorUpdate" then
        assert(queuedMessage.content and queuedMessage.content[1] == spectatorName)
        found = true
        break
      end
    end
    assert(found)
  end

  assertNextSpectatorUpdate(alice.connection, "Bob")
  assertNextSpectatorUpdate(ben.connection, "Bob")
  assertNextSpectatorUpdate(bob.connection, "Bob")

  alice.connection:receiveMessage(json.encode(ClientProtocol.reportLocalGameResult(2).messageText))
  server:update()
  ben.connection:receiveMessage(json.encode(ClientProtocol.reportLocalGameResult(2).messageText))
  server:update()

  local function assertNextGameResult(connection)
    local found = false
    while connection.outgoingMessageQueue:len() > 0 do
      local queuedMessage = connection.outgoingMessageQueue:pop().messageText
      if queuedMessage.type == "gameResult" then
        found = true
        break
      end
    end
    assert(found)
  end

  assertNextGameResult(alice.connection)
  assertNextGameResult(ben.connection)
  assertNextGameResult(bob.connection)

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

  -- Loose-sync mid-match leave: the room is voided but stays open so the
  -- remaining player + spectators can see the void state and finish/rematch.
  -- Ben gets a synthesized death event (D-prefix, routed to outgoingInputQueue
  -- by MockConnection so it doesn't show up here). On outgoingMessageQueue:
  --   - alice + bob receive playerLeftRoom carrying the voidReason
  --   - ben receives leaveRoom back as the acknowledged-quit
  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "playerLeftRoom" and message.content.voidReason == "Ben left",
    "alice expected playerLeftRoom voidReason='Ben left', got type="
    .. tostring(message.type) .. " voidReason=" .. tostring(message.content and message.content.voidReason))
  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "playerLeftRoom" and message.content.voidReason == "Ben left",
    "bob expected playerLeftRoom voidReason='Ben left'")
  message = ben.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "leaveRoom",
    "ben expected leaveRoom, got " .. tostring(message.type))

  -- Only ben transitions back to lobby (alice + bob stay in the voided room).
  -- Ben's next message is the lobby snapshot.
  message = ben.connection.outgoingMessageQueue:pop().messageText.content
  assert(message.players and tableUtils.length(message.players) == 3,
    "ben should see 3 players in the lobby snapshot")
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

  -- Loose-sync hard-DC mid-match: voidByLeave synthesizes a death event for
  -- ben so survivors can finish, marks the room voided, and broadcasts
  -- playerLeftRoom to alice (player) and bob (spectator). The voidReason
  -- wraps the disconnect reason in parens after the leaver's "<name> left"
  -- preamble.
  local expectedVoidReason = "Ben left (Ben's connection failed)"
  local message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "playerLeftRoom" and message.content.voidReason == expectedVoidReason,
    "alice expected playerLeftRoom voidReason='" .. expectedVoidReason .. "', got type="
    .. tostring(message.type) .. " voidReason=" .. tostring(message.content and message.content.voidReason))
  message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "playerLeftRoom" and message.content.voidReason == expectedVoidReason,
    "bob expected playerLeftRoom voidReason='" .. expectedVoidReason .. "'")
  -- we closed the connection server side, so the server should no longer try
  -- to send them a message
  assert(ben.connection.outgoingMessageQueue:len() == 0)
  assert(ben.connection.loggedIn == false)
  assert(server.connectionToPlayer[ben.connection] == nil)
end


local function testLobbyDataComposition()
  local server = ServerTesting.getTestServer()
  local leaderboard = Leaderboard(GameModes.getPreset(GameModes.IDs.TWO_PLAYER_VS), MockPersistence)
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
  assert(message.type == "lobbyStateV2")
  message = message.content
  ---@cast message LobbyStateV2
  assert(message.players and tableUtils.length(message.players) == 5)
  assert(message.rooms and tableUtils.length(message.rooms) == 1)
  for id, player in pairs(message.players) do
    assert(id == player.publicId)
    assert((player.state == "lobby" and (player.name == "Alice" or player.name == "Berta") and tonumber(player.ratings.TWO_PLAYER_VS))
        or (player.state == "character select" and (player.name == "Ben" or player.name == "Jerry"))
        or (player.state == "spectating" and player.name == "Bob"))
  end

  local roomNumber, lobbyRoom = next(message.rooms)
  assert(lobbyRoom.roomNumber == roomNumber)
  assert(#lobbyRoom.players == 2 and #lobbyRoom.spectators == 1)
  -- in the new lobby data spectators are not invisible anymore!
  assert(message.players[lobbyRoom.spectators[1]].name == "Bob")
  assert(lobbyRoom.gameModeId == GameModes.IDs.TWO_PLAYER_VS)
end

local function testSinglePlayer()
  local server = ServerTesting.getTestServer()
  local bob = ServerTesting.login(server, ServerTesting.players[1])
  local alice = ServerTesting.login(server, ServerTesting.players[2])

  ServerTesting.clearOutgoingMessages({bob, alice})

  bob.connection:receiveMessage(json.encode(ClientProtocol.sendRoomRequest(GameModes.getPreset(GameModes.IDs.ONE_PLAYER_VS_SELF)).messageText))
  server:update()
  assert(server.playerToRoom[bob])
  local message = bob.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "addToRoom")

  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "lobbyStateV2")
  assert(tableUtils.length(message.content.rooms) == 1)

  alice.connection:receiveMessage(json.encode(ClientProtocol.requestSpectate("Alice", server.playerToRoom[bob].roomNumber).messageText))
  server:update()

  assert(server.spectatorToRoom[alice] == server.playerToRoom[bob])
  local function assertHasMessage(connection, expectedType, predicate)
    local found = false
    while connection.outgoingMessageQueue:len() > 0 do
      local queuedMessage = connection.outgoingMessageQueue:pop().messageText
      if queuedMessage.type == expectedType and (not predicate or predicate(queuedMessage)) then
        found = true
        break
      end
    end
    assert(found)
  end

  assertHasMessage(bob.connection, "spectatorUpdate")
  assertHasMessage(alice.connection, "spectateRequestGranted", function(msg)
    assert(msg.content.replay == nil)
    -- Compare gameMode.name only — room.gameMode is mutated with transport-layer
    -- fields (latencyTolerance, connectionTimeoutSeconds, sendRetryLimit) that
    -- the bare preset doesn't carry, so deep_content_equal would fail. The
    -- behavior we actually care about is that the spectated room's mode matches.
    -- gameMode.name carries the canonical mode identifier (e.g. "vsSelf"),
    -- which gameModeIdToName maps the IDs constant to.
    return msg.content.gameMode.name == GameModes.gameModeIdToName[GameModes.IDs.ONE_PLAYER_VS_SELF]
  end)
  assertHasMessage(alice.connection, "spectatorUpdate")

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
  assert(message.type == "lobbyStateV2")

  alice.connection:receiveMessage(json.encode(ClientProtocol.requestSpectate("Alice", server.playerToRoom[bob].roomNumber).messageText))
  server:update()

  assertHasMessage(bob.connection, "spectatorUpdate")
  assertHasMessage(alice.connection, "spectateRequestGranted", function(msg)
    return msg.content.replay ~= nil
  end)
  assertHasMessage(alice.connection, "spectatorUpdate")

  bob.connection:receiveMessage(json.encode(ClientProtocol.sendMatchAbort(server.playerToRoom[bob].roomNumber).messageText))
  server:update()

  message = alice.connection.outgoingMessageQueue:pop().messageText
  assert(message.type == "gameAbort")
end

local function testCannotSpectateWhileInRoom()
  local server = ServerTesting.getTestServer()
  local bob = ServerTesting.login(server, ServerTesting.players[1])

  ServerTesting.clearOutgoingMessages({bob})

  bob.connection:receiveMessage(json.encode(ClientProtocol.sendRoomRequest(GameModes.getPreset(GameModes.IDs.ONE_PLAYER_VS_SELF)).messageText))
  server:update()

  local room = server.playerToRoom[bob]
  assert(room)
  ServerTesting.clearOutgoingMessages({bob})

  bob.connection:receiveMessage(json.encode(ClientProtocol.requestSpectate("Bob", room.roomNumber).messageText))
  server:update()

  assert(server.playerToRoom[bob] == room)
  assert(server.spectatorToRoom[bob] == nil)
  assert(#room.spectators == 0)

  while bob.connection.outgoingMessageQueue:len() > 0 do
    local message = bob.connection.outgoingMessageQueue:pop().messageText
    assert(message.type ~= "spectateRequestGranted")
  end
end

local function testJoinPartialRoomSetsCharacterSelectState()
  local server = ServerTesting.getTestServer()
  local alice = ServerTesting.login(server, ServerTesting.players[2])
  local ben = ServerTesting.login(server, ServerTesting.players[3])

  alice.state = "lobby"
  ben.state = "lobby"

  ServerTesting.clearOutgoingMessages({alice, ben})

  alice.connection:receiveMessage(json.encode(ClientProtocol.sendRoomRequest(GameModes.getPreset(GameModes.IDs.THREE_PLAYER_VS_ALL)).messageText))
  server:update()

  local room = server.playerToRoom[alice]
  assert(room)
  assert(alice.state == "character select")

  ServerTesting.clearOutgoingMessages({alice, ben})

  alice.connection:receiveMessage(json.encode(ClientProtocol.updateChallengeStatus(alice.publicPlayerID, ben.publicPlayerID, GameModes.IDs.THREE_PLAYER_VS_ALL, true, room.roomNumber, 2).messageText))
  server:update()

  ben.connection:receiveMessage(json.encode(ClientProtocol.updateChallengeStatus(ben.publicPlayerID, alice.publicPlayerID, GameModes.IDs.THREE_PLAYER_VS_ALL, true, room.roomNumber, 2).messageText))
  server:update()

  assert(server.playerToRoom[ben] == room)
  assert(ben.state == "character select")

  local lobbyStateMessage
  while alice.connection.outgoingMessageQueue:len() > 0 do
    local message = alice.connection.outgoingMessageQueue:pop().messageText
    if message and message.type == "lobbyStateV2" then
      lobbyStateMessage = message
    end
  end

  assert(lobbyStateMessage and lobbyStateMessage.content and lobbyStateMessage.content.players)
  local benLobbyEntry = lobbyStateMessage.content.players[ben.publicPlayerID]
  assert(benLobbyEntry and benLobbyEntry.state == "character select")
end

local function testTeamRoomRequestCreatesPartialRoom()
  local server = ServerTesting.getTestServer()
  local alice = ServerTesting.login(server, ServerTesting.players[2])
  local bob = ServerTesting.login(server, ServerTesting.players[1])

  ServerTesting.clearOutgoingMessages({alice, bob})

  alice.connection:receiveMessage(json.encode(ClientProtocol.sendRoomRequest(GameModes.getPreset(GameModes.IDs.THREE_PLAYER_VS_ALL)).messageText))
  server:update()

  local room = server.playerToRoom[alice]
  assert(room, "Expected a room to be created for team room request")
  assert(server.playerToRoom[alice] == room)
  assert(alice.state == "character select")
  assert(room.gameModeId == GameModes.IDs.THREE_PLAYER_VS_ALL)
  assert(room.gameMode and room.gameMode.name == GameModes.gameModeIdToName[GameModes.IDs.THREE_PLAYER_VS_ALL])
  assert(room.maxPlayers == 3)
  assert(#room.players == 1)
  assert(room.players[1] == alice)
  assert(room:isFull() == false)

  local foundRoomAck = false
  while alice.connection.outgoingMessageQueue:len() > 0 do
    local msg = alice.connection.outgoingMessageQueue:pop().messageText
    if msg and (msg.type == "addToRoom" or msg.type == "createRoom") then
      foundRoomAck = true
      break
    end
  end
  assert(foundRoomAck, "Expected room acknowledgement message for creator")

  local lobbyStateMessage = nil
  while bob.connection.outgoingMessageQueue:len() > 0 do
    local msg = bob.connection.outgoingMessageQueue:pop().messageText
    if msg and msg.type == "lobbyStateV2" then
      lobbyStateMessage = msg
      break
    end
  end

  assert(lobbyStateMessage and lobbyStateMessage.content and lobbyStateMessage.content.rooms)
  assert(tableUtils.length(lobbyStateMessage.content.rooms) == 1)
  local _, lobbyRoom = next(lobbyStateMessage.content.rooms)
  assert(lobbyRoom.roomNumber == room.roomNumber)
  assert(lobbyRoom.gameModeId == GameModes.IDs.THREE_PLAYER_VS_ALL)
  assert(lobbyRoom.maxPlayers == 3)
  assert(#lobbyRoom.players == 1)
  assert(lobbyRoom.players[1] == alice.publicPlayerID)
  assert(#lobbyRoom.openSlots == 2)
  assert(lobbyRoom.openSlots[1] == 2 and lobbyRoom.openSlots[2] == 3)
end

local function testTeamRoomRequestAcceptsFallbackGameModeShape()
  local server = ServerTesting.getTestServer()
  local alice = ServerTesting.login(server, ServerTesting.players[2])
  local bob = ServerTesting.login(server, ServerTesting.players[1])

  ServerTesting.clearOutgoingMessages({alice, bob})

  alice.connection:receiveMessage(json.encode({
    recipient = "server",
    type = "roomRequest",
    gameMode = GameModes.IDs.THREE_PLAYER_VS_ALL,
  }))
  server:update()

  local room = server.playerToRoom[alice]
  assert(room, "Expected a room to be created from fallback roomRequest shape")
  assert(room.gameModeId == GameModes.IDs.THREE_PLAYER_VS_ALL)
  assert(room.maxPlayers == 3)
  assert(alice.state == "character select")

  local lobbyStateMessage = nil
  while bob.connection.outgoingMessageQueue:len() > 0 do
    local msg = bob.connection.outgoingMessageQueue:pop().messageText
    if msg and msg.type == "lobbyStateV2" then
      lobbyStateMessage = msg
      break
    end
  end

  assert(lobbyStateMessage and lobbyStateMessage.content and lobbyStateMessage.content.rooms)
  assert(tableUtils.length(lobbyStateMessage.content.rooms) == 1)
  local _, lobbyRoom = next(lobbyStateMessage.content.rooms)
  assert(lobbyRoom.gameModeId == GameModes.IDs.THREE_PLAYER_VS_ALL)
  assert(lobbyRoom.maxPlayers == 3)
  assert(lobbyRoom.openSlots[1] == 2 and lobbyRoom.openSlots[2] == 3)
end

local function testJoinRoomRequestUsesSanitizedJoinMessage()
  local server = ServerTesting.getTestServer()
  local alice = ServerTesting.login(server, ServerTesting.players[2])
  local bob = ServerTesting.login(server, ServerTesting.players[1])

  ServerTesting.clearOutgoingMessages({alice, bob})

  alice.connection:receiveMessage(json.encode(ClientProtocol.sendRoomRequest(GameModes.getPreset(GameModes.IDs.THREE_PLAYER_VS_ALL)).messageText))
  server:update()

  local room = server.playerToRoom[alice]
  assert(room, "Expected a room to exist before sending a joinRoomRequest")

  ServerTesting.clearOutgoingMessages({alice, bob})

  bob.connection:receiveMessage(json.encode(ClientProtocol.requestJoinRoom(room.roomNumber, 2).messageText))
  server:update()

  assert(server.playerToRoom[bob] == room)
  assert(bob.state == "character select")
  assert(#room.players == 2)

  local joinAck = nil
  while bob.connection.outgoingMessageQueue:len() > 0 do
    local msg = bob.connection.outgoingMessageQueue:pop().messageText
    if msg and msg.type == "addToRoom" then
      joinAck = msg
      break
    end
  end

  assert(joinAck and joinAck.content and joinAck.content.roomNumber == room.roomNumber)
end

testLogin()
testRoomSetup()
testRoomSetup2()
testGameplay()
testDisconnect()
testLobbyDataComposition()
testSinglePlayer()
testCannotSpectateWhileInRoom()
testJoinPartialRoomSetsCharacterSelectState()
testTeamRoomRequestCreatesPartialRoom()
testTeamRoomRequestAcceptsFallbackGameModeShape()
testJoinRoomRequestUsesSanitizedJoinMessage()