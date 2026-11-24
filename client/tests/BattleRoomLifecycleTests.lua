local Player = require("client.src.Player")
local GameModes = require("common.data.GameModes")
local NetClient = require("client.src.network.NetClient")
local Signal = require("common.lib.signal")
local NotificationCenter = require("client.src.ui.NotificationCenter")
local ServerTesting = require("server.tests.ServerTesting")
local NetworkProtocol = require("common.network.NetworkProtocol")
local json = require("common.lib.dkjson")
local ClientProtocol = require("common.network.ClientProtocol")
local ServerMessages = require("client.src.network.ServerMessages")
local ServerProtocol = require("common.network.ServerProtocol")
local Response = require("client.src.network.Response")
local input = require("client.src.inputManager")
local ClientMatch = require("client.src.ClientMatch")
require("client.src.BattleRoom")

-- The tables whose own fields the tests replace or the code under test changes
local function touchedTables()
  local netClient = GAME.netClient
  return {netClient, netClient.tcpClient, GAME.navigationStack, GAME, ClientMatch}
end

-- A copy of every table's own fields, so they can be put back exactly
local function snapshot(tables)
  local copies = {}
  for i, t in ipairs(tables) do
    local copy = {}
    for key, value in next, t do
      copy[key] = value
    end
    copies[i] = copy
  end
  return copies
end

-- Puts every table's own fields back the way the snapshot found them, removing the ones it didn't have
local function restore(tables, copies)
  for i, t in ipairs(tables) do
    local copy = copies[i]
    local added = {}
    for key in next, t do
      if copy[key] == nil then
        added[#added + 1] = key
      end
    end
    for _, key in ipairs(added) do
      rawset(t, key, nil)
    end
    for key, value in next, copy do
      rawset(t, key, value)
    end
  end
end

local stateBeforeTheTests = snapshot(touchedTables())

-- A json message as the server puts it on the wire
---@param messageText table
---@return string
local function markedJson(messageText)
  return NetworkProtocol.markedMessageForTypeAndBody(NetworkProtocol.serverMessageTypes.jsonMessage.prefix, json.encode(messageText))
end

-- A connected socket that delivers whatever is put in incoming on the next read
local function fakeSocket()
  local socket = {incoming = ""}
  function socket:receive()
    local data = self.incoming
    self.incoming = ""
    return nil, "timeout", data
  end
  function socket:getpeername()
    return "127.0.0.1", 49569
  end
  function socket:close() end
  return socket
end

-- Runs test as if the net client were connected to a fake socket, recording the requests it sends instead of sending them
-- and the scenes it pops to instead of popping, with the transition each pop would have played.
-- It also shows notifications on a fresh notification center. Everything it replaces is put back afterwards, even if the test fails.
---@param test fun(sent: table[], poppedTo: string[], transitions: table[])
local function whileOnline(test)
  local tables = touchedTables()
  local copies = snapshot(tables)
  local sent, poppedTo, transitions = {}, {}, {}
  GAME.notificationCenter = NotificationCenter({})
  GAME.netClient.isConnected = function() return true end
  GAME.netClient.tcpClient.socket = fakeSocket()
  GAME.netClient.tcpClient.lastReceiveTime = love.timer.getTime()
  GAME.netClient.tcpClient.sendRequest = function(_, request)
    sent[#sent + 1] = request.messageText
    if request.responseTypes and #request.responseTypes > 0 then
      return Response(request.responseTypes)
    end
  end
  GAME.navigationStack.popToName = function(_, name, transition, callback)
    poppedTo[#poppedTo + 1] = name
    transitions[#poppedTo] = transition
  end

  local ok, err = pcall(test, sent, poppedTo, transitions)

  restore(tables, copies)
  assert(ok, err)
end

---@param sent table[]
---@return integer
local function leaveRequests(sent)
  local count = 0
  for _, message in ipairs(sent) do
    if type(message) == "table" and message.leave_room then
      count = count + 1
    end
  end
  return count
end

-- An online room the net client has joined, the way NetClient sets one up from the server's create_room
---@return BattleRoom
local function joinRoom()
  local room = BattleRoom(GameModes.getPreset(GameModes.IDs.TWO_PLAYER_VS))
  assert(room.online, "the room should consider itself online")
  local localPlayer = Player("LocalPlayer", 1, true)
  localPlayer.playerNumber = 1
  room:addPlayer(localPlayer)
  local remotePlayer = Player("RemotePlayer", 2, false)
  remotePlayer.playerNumber = 2
  room:addPlayer(remotePlayer)
  GAME.netClient:registerPlayerUpdates(room)
  GAME.battleRoom = room
  GAME.netClient.room = room
  GAME.netClient:setState(NetClient.STATES.ROOM)
  return room
end

---@param reason string? why the server closed the room, sent only when a player in it left
local function receiveLeaveRoom(reason)
  local socket = GAME.netClient.tcpClient.socket --[[@as table]]
  socket.incoming = markedJson(ServerProtocol.leaveRoom(1, reason).messageText)
  GAME.netClient:update()
end

local function testLeavingARoomSendsOneLeaveRoom()
  whileOnline(function(sent, poppedTo)
    local room = joinRoom()

    room:shutdown()
    room:shutdown()

    assert(leaveRequests(sent) == 1, "shutting a room down twice should leave it once, but sent " .. leaveRequests(sent))
    assert(GAME.battleRoom == nil, "the room should no longer be the game's battle room")
  end)
end

testLeavingARoomSendsOneLeaveRoom()

local function testServerConfirmingTheLeaveDoesNotShutTheRoomDownAgain()
  whileOnline(function(sent, poppedTo)
    local room = joinRoom()
    room:shutdown()

    receiveLeaveRoom()

    assert(leaveRequests(sent) == 1, "the server's confirmation should not be answered with another leave, but sent " .. leaveRequests(sent))
    assert(#poppedTo == 0, "the client already left the room's scene, but the confirmation popped to " .. tostring(poppedTo[1]))
    assert(GAME.netClient.room == nil, "the confirmation should clear the net client's room")
    assert(GAME.netClient.state == NetClient.STATES.ONLINE, "the confirmation should put the net client back in the lobby")
  end)
end

testServerConfirmingTheLeaveDoesNotShutTheRoomDownAgain()

local function testServerClosingTheRoomShutsItDown()
  whileOnline(function(sent, poppedTo)
    local room = joinRoom()

    receiveLeaveRoom()

    assert(room.hasShutdown, "the server closing the room should shut it down")
    assert(leaveRequests(sent) == 0, "a room the server closed should not be left again, but sent " .. leaveRequests(sent))
    assert(#poppedTo == 1 and poppedTo[1] == "Lobby", "the server closing the room should return to the lobby")
    assert(GAME.battleRoom == nil, "the closed room should no longer be the game's battle room")
  end)
end

testServerClosingTheRoomShutsItDown()

local function testAPlayerLeavingShowsWhyInANotification()
  whileOnline(function(sent, poppedTo)
    joinRoom()

    receiveLeaveRoom("RemotePlayer left")

    local notifications = GAME.notificationCenter.notifications
    assert(#notifications == 1, "the server saying why the room closed should show one notification, but showed " .. #notifications)
    assert(notifications[1].label.text == "RemotePlayer left",
           "the notification should give the server's reason, but said " .. notifications[1].label.text)
    assert(notifications[1].label.translate == false, "the server's reason is not a localization key")
  end)
end

testAPlayerLeavingShowsWhyInANotification()

-- A match in progress, standing in for the ClientMatch the room would have going
local function matchInProgress()
  local match = {aborted = false}
  function match:disconnectSignal() end
  function match:abort()
    self.aborted = true
  end
  function match:deinit() end
  return match
end

local function testAPlayerLeavingMidMatchGoesStraightToTheLobby()
  whileOnline(function(sent, poppedTo, transitions)
    local room = joinRoom()
    local match = matchInProgress()
    room.match = match

    receiveLeaveRoom("RemotePlayer left")

    assert(match.aborted, "the match should be aborted when the room closes during it")
    assert(#poppedTo == 1 and poppedTo[1] == "Lobby", "the room closing should return to the lobby")
    assert(transitions[1] == nil, "the reason is shown in a notification, so returning to the lobby should not wait on a message screen")
    assert(#GAME.notificationCenter.notifications == 1, "the reason should be shown in a notification")
  end)
end

testAPlayerLeavingMidMatchGoesStraightToTheLobby()

local function testTheServerClosingTheRoomWithoutAReasonShowsNoNotification()
  whileOnline(function()
    joinRoom()

    receiveLeaveRoom("")

    assert(#GAME.notificationCenter.notifications == 0, "a room closed without a reason should show no notification")
  end)
end

testTheServerClosingTheRoomWithoutAReasonShowsNoNotification()

---@param player Player
---@return integer
local function settingsCallbacks(player)
  local callbacks = player.signalSubscriptions.characterIdChanged[player]
  return callbacks and #callbacks or 0
end

local function testRoomsDoNotPileUpSettingsCallbacks()
  whileOnline(function()
    local player = Player("LocalPlayer", 1, true)
    for i = 1, 3 do
      local room = BattleRoom(GameModes.getPreset(GameModes.IDs.TWO_PLAYER_VS))
      room:addPlayer(player)
      GAME.netClient:registerPlayerUpdates(room)
      assert(settingsCallbacks(player) == 1, "room " .. i .. " should leave one settings callback, found " .. settingsCallbacks(player))
      room:shutdown()
      assert(settingsCallbacks(player) == 0, "room " .. i .. " should take its settings callback with it, found " .. settingsCallbacks(player))
    end
  end)
end

testRoomsDoNotPileUpSettingsCallbacks()

local function testAnOldRoomLeavesTheNewOneAlone()
  whileOnline(function(sent, poppedTo)
    local oldRoom = joinRoom()
    oldRoom:shutdown()
    receiveLeaveRoom()
    local newRoom = joinRoom()

    oldRoom:shutdown()
    assert(GAME.battleRoom == newRoom, "shutting the old room down again should not clear the new room")

    -- what NetClient:disconnect does to the rooms, without closing the test game's connection or touching its local player
    GAME.netClient.room = nil
    GAME.netClient:emitSignal("clientDisconnected", false)
    assert(newRoom.hasShutdown, "losing the connection should shut the current room down")
    assert(#poppedTo == 1, "only the current room should react to losing the connection, but " .. #poppedTo .. " did")
  end)
end

testAnOldRoomLeavesTheNewOneAlone()

-- Puts what the server sent to serverPlayer on the client's socket, its json messages ahead of its inputs.
-- The mock connection keeps the two apart, so a test that needs them in the server's order delivers after every server step.
---@param socket table
---@param serverPlayer ServerPlayer
local function deliverToClient(socket, serverPlayer)
  local messages, inputs = ServerTesting.takeSentMessages(serverPlayer)
  for _, message in ipairs(messages) do
    socket.incoming = socket.incoming .. markedJson(message)
  end
  socket.incoming = socket.incoming .. table.concat(inputs)
end

-- Hands the requests the client sent since the last call to the server as coming from serverPlayer
---@param sent table[]
---@param server Server
---@param serverPlayer ServerPlayer
local function deliverToServer(sent, server, serverPlayer)
  for i = 1, #sent do
    ServerTesting.receiveMessage(serverPlayer, sent[i])
    sent[i] = nil
  end
  server:update()
end

-- Sends the server what a client sends for player, with wantsReady as given
---@param server Server
---@param serverPlayer ServerPlayer
---@param player Player the client's player standing for serverPlayer
---@param wantsReady boolean
local function sendSettings(server, serverPlayer, player, wantsReady)
  local menuState = ServerMessages.toServerMenuState(player)
  menuState.wants_ready = wantsReady
  menuState.loaded = true
  menuState.ready = wantsReady
  ServerTesting.receiveMessage(serverPlayer, ClientProtocol.sendPlayerSettings(menuState).messageText)
  server:update()
end

-- A player with the character, stage and panels the config picks
---@param name string
---@param publicId integer
---@param isLocal boolean
---@return Player
local function playerWithConfigMods(name, publicId, isLocal)
  local player = Player(name, publicId, isLocal)
  player:setCharacter(config.character)
  player:setStage(config.stage)
  player:setPanels(config.panels)
  return player
end

---@class OnlineRoomTest
---@field server Server
---@field alice ServerPlayer
---@field ben ServerPlayer
---@field socket table the client's socket
---@field pushed Scene[] the scenes the client pushed
---@field room BattleRoom
---@field localPlayer Player Alice on her client
---@field remotePlayer Player Ben on Alice's client

-- A server with Alice and Ben in a room, and Alice's client in the matching room on the fake socket.
-- The client's scene pushes are recorded instead of made.
---@return OnlineRoomTest
local function aliceInARoomWithBen()
  local t = {}
  t.server = ServerTesting.getTestServer()
  t.alice = ServerTesting.login(t.server, ServerTesting.players[2])
  t.ben = ServerTesting.login(t.server, ServerTesting.players[3])
  ServerTesting.setupRoom(t.server, t.alice, t.ben, true)

  t.socket = GAME.netClient.tcpClient.socket
  t.pushed = {}
  GAME.navigationStack.push = function(_, scene, transition)
    t.pushed[#t.pushed + 1] = scene
  end

  t.room = BattleRoom(GameModes.getPreset(GameModes.IDs.TWO_PLAYER_VS))
  t.localPlayer = playerWithConfigMods("Alice", t.alice.publicPlayerID, true)
  t.localPlayer.playerNumber = t.alice.player_number
  t.room:addPlayer(t.localPlayer)
  t.remotePlayer = playerWithConfigMods("Ben", t.ben.publicPlayerID, false)
  t.remotePlayer.playerNumber = t.ben.player_number
  t.room:addPlayer(t.remotePlayer)
  GAME.netClient:registerPlayerUpdates(t.room)
  GAME.battleRoom = t.room
  GAME.netClient.room = t.room
  GAME.netClient:setState(NetClient.STATES.ROOM)
  t.localPlayer:restrictInputs(input.inputConfigurations[1])
  return t
end

-- Lets go of what aliceInARoomWithBen claimed that the test game outlives
---@param t OnlineRoomTest
---@param matches ClientMatch[] the matches the test started
local function releaseAliceInARoomWithBen(t, matches)
  t.localPlayer:unrestrictInputs()
  for _, match in pairs(matches) do
    match:deinit()
  end
end

-- Readies Ben, then Alice, which makes the server start a match
---@param t OnlineRoomTest
local function bothReadyUp(t)
  sendSettings(t.server, t.ben, t.remotePlayer, true)
  sendSettings(t.server, t.alice, t.localPlayer, true)
end

-- Ben is ready and Alice readies up and leaves at once.
-- The server starts the match on Alice's ready before it hears she left, so a match_start for the room she left
-- is on its way to her client ahead of the confirmation of her leave.
local function testAMatchStartForARoomTheClientLeftStartsNoMatch()
  whileOnline(function(sent)
    local t = aliceInARoomWithBen()
    bothReadyUp(t)
    -- Alice leaves before her client heard of the match start
    t.room:shutdown()

    -- the match start arrives first, the confirmation of the leave a frame later
    deliverToClient(t.socket, t.alice)
    GAME.netClient:update()
    deliverToServer(sent, t.server, t.alice)
    deliverToClient(t.socket, t.alice)
    GAME.netClient:update()

    local startedMatch = t.room.match
    releaseAliceInARoomWithBen(t, {startedMatch})
    assert(#t.pushed == 0, "a match start for a room the client left should push no scene, but pushed " .. #t.pushed)
    assert(startedMatch == nil, "a match start for a room the client left should start no match")
    assert(GAME.netClient.state == NetClient.STATES.ONLINE,
           "the client should be back in the lobby, but is in state " .. GAME.netClient.state)
  end)
end

testAMatchStartForARoomTheClientLeftStartsNoMatch()

-- Both clients desync and abort. Ben's abort reaches the server first, so the server tells Alice about it after her
-- client already went back to character select on its own abort.
local function testAnAbortThatCrossedOursLeavesTheNextMatchAlone()
  whileOnline(function(sent)
    local t = aliceInARoomWithBen()
    bothReadyUp(t)
    deliverToClient(t.socket, t.alice)
    GAME.netClient:update()
    local firstMatch = t.room.match
    -- the server only takes an abort for a desync when one player sent far more inputs than the other
    for _ = 1, 101 do
      ServerTesting.receiveInput(t.ben, "A")
    end
    t.server:update()
    ServerTesting.clearOutgoingMessages({t.alice})

    firstMatch:abort()
    ServerTesting.receiveMessage(t.ben, ClientProtocol.sendMatchAbort().messageText)
    t.server:update()
    deliverToServer(sent, t.server, t.alice)
    deliverToClient(t.socket, t.alice)
    GAME.netClient:update()

    bothReadyUp(t)
    deliverToClient(t.socket, t.alice)
    GAME.netClient:update()
    local secondMatch = t.room.match
    GAME.netClient:update()

    local aborted = secondMatch and secondMatch.engine.aborted
    releaseAliceInARoomWithBen(t, {firstMatch, secondMatch})
    assert(secondMatch and secondMatch ~= firstMatch, "the players readying up again should start a new match")
    assert(not aborted, "the abort of the first match should not abort the second one")
  end)
end

testAnAbortThatCrossedOursLeavesTheNextMatchAlone()

-- Ben aborts a match on a desync; Alice's client hears of it mid-match
local function testAMatchTheServerAbortedReturnsTheRoomToCharacterSelect()
  whileOnline(function(sent)
    local t = aliceInARoomWithBen()
    bothReadyUp(t)
    deliverToClient(t.socket, t.alice)
    GAME.netClient:update()
    local match = t.room.match
    for _ = 1, 101 do
      ServerTesting.receiveInput(t.ben, "A")
    end
    t.server:update()
    ServerTesting.clearOutgoingMessages({t.alice})

    ServerTesting.receiveMessage(t.ben, ClientProtocol.sendMatchAbort().messageText)
    t.server:update()
    deliverToClient(t.socket, t.alice)
    GAME.netClient:update()

    local roomState, roomMatch = t.room.state, t.room.match
    releaseAliceInARoomWithBen(t, {match})
    assert(roomState == BattleRoom.states.Setup, "the room should be back in character select after the abort")
    assert(roomMatch == nil, "the room should let go of the aborted match")
  end)
end

testAMatchTheServerAbortedReturnsTheRoomToCharacterSelect()

-- Ends match the way a game over does, without playing it to one
---@param match ClientMatch
local function endTheMatch(match)
  match.engine.ended = true
  match:handleMatchEnd()
end

-- Alice's client sees the match end and is on the game over screen when Ben's abort on a desync reaches it
local function testAnAbortAfterTheMatchEndedLetsTheNextMatchStart()
  whileOnline(function(sent)
    local t = aliceInARoomWithBen()
    bothReadyUp(t)
    deliverToClient(t.socket, t.alice)
    GAME.netClient:update()
    local firstMatch = t.room.match
    for _ = 1, 101 do
      ServerTesting.receiveInput(t.ben, "A")
    end
    t.server:update()
    ServerTesting.clearOutgoingMessages({t.alice})

    endTheMatch(firstMatch)
    ServerTesting.receiveMessage(t.ben, ClientProtocol.sendMatchAbort().messageText)
    t.server:update()
    deliverToServer(sent, t.server, t.alice)
    deliverToClient(t.socket, t.alice)
    GAME.netClient:update()
    local stateAfterTheAbort = GAME.netClient.state

    bothReadyUp(t)
    deliverToClient(t.socket, t.alice)
    local updated, err = pcall(GAME.netClient.update, GAME.netClient)
    local secondMatch = t.room.match

    releaseAliceInARoomWithBen(t, {firstMatch, secondMatch})
    assert(stateAfterTheAbort == NetClient.STATES.ROOM,
           "the abort should return the client to character select, but it is in state " .. stateAfterTheAbort)
    assert(updated, "the next match start should not crash the client: " .. tostring(err))
    assert(secondMatch and secondMatch ~= firstMatch, "the players readying up again should start a new match")
  end)
end

testAnAbortAfterTheMatchEndedLetsTheNextMatchStart()

-- Ben's last input of the first match, the result, the start of the next match and Ben's first input in it
-- reach Alice's client in one frame, as they do after a long frame
local function testMessagesArrivingTogetherAreHandledInTheOrderTheyArrived()
  whileOnline(function()
    -- what each match was handed, as it was handed, since a match that ended lets go of its stacks' inputs
    local received = {}
    local receiveInput = ClientMatch.receiveInput
    ClientMatch.receiveInput = function(match, prefix, data)
      received[match] = (received[match] or "") .. data
      receiveInput(match, prefix, data)
    end
    local t = aliceInARoomWithBen()
    bothReadyUp(t)
    deliverToClient(t.socket, t.alice)
    GAME.netClient:update()
    local firstMatch = t.room.match

    ServerTesting.receiveInput(t.ben, "A")
    t.server:update()
    deliverToClient(t.socket, t.alice)
    for _, player in ipairs({t.alice, t.ben}) do
      ServerTesting.receiveMessage(player, ClientProtocol.reportLocalGameResult(1).messageText)
    end
    t.server:update()
    deliverToClient(t.socket, t.alice)
    bothReadyUp(t)
    deliverToClient(t.socket, t.alice)
    ServerTesting.receiveInput(t.ben, "B")
    t.server:update()
    deliverToClient(t.socket, t.alice)
    GAME.netClient:update()

    local secondMatch = t.room.match
    local state = GAME.netClient.state
    releaseAliceInARoomWithBen(t, {firstMatch, secondMatch})
    assert(secondMatch and secondMatch ~= firstMatch, "the match start should start the second match")
    assert(received[firstMatch] == "A",
           "the first match should get only Ben's input sent during it, but got " .. tostring(received[firstMatch]))
    assert(received[secondMatch] == "B",
           "the second match should get only Ben's input sent during it, but got " .. tostring(received[secondMatch]))
    assert(state == NetClient.STATES.INGAME, "the client should be in the second match, but is in state " .. state)
  end)
end

testMessagesArrivingTogetherAreHandledInTheOrderTheyArrived()

---@class SpectatorTest
---@field server Server
---@field alice ServerPlayer
---@field ben ServerPlayer
---@field bob ServerPlayer
---@field serverRoom Room
---@field socket table Bob's client's socket
---@field pushed Scene[] the scenes Bob's client pushed
---@field players Player[] Alice and Ben as the client sees them, standing in for their clients' settings

-- A server with Alice and Ben in character select, and Bob's client spectating them on the fake socket.
-- The client's scene pushes are recorded instead of made.
---@param sent table[] the requests the client sent
---@return SpectatorTest
local function bobSpectatingAliceAndBen(sent)
  local t = {}
  t.server = ServerTesting.getTestServer()
  t.alice = ServerTesting.login(t.server, ServerTesting.players[2])
  t.ben = ServerTesting.login(t.server, ServerTesting.players[3])
  t.bob = ServerTesting.login(t.server, ServerTesting.players[1])
  t.serverRoom = ServerTesting.setupRoom(t.server, t.alice, t.ben, true)
  t.players = {playerWithConfigMods("Alice", t.alice.publicPlayerID, false), playerWithConfigMods("Ben", t.ben.publicPlayerID, false)}
  sendSettings(t.server, t.alice, t.players[1], false)
  sendSettings(t.server, t.ben, t.players[2], false)
  ServerTesting.clearOutgoingMessages({t.alice, t.ben, t.bob})

  t.socket = GAME.netClient.tcpClient.socket
  t.pushed = {}
  GAME.navigationStack.push = function(_, scene, transition)
    t.pushed[#t.pushed + 1] = scene
  end
  GAME.netClient:setState(NetClient.STATES.ONLINE)

  GAME.netClient:requestSpectate(t.serverRoom.roomNumber)
  -- the response waits a frame before it first looks for its message
  GAME.netClient:update()
  deliverToServer(sent, t.server, t.bob)
  deliverToClient(t.socket, t.bob)
  GAME.netClient:update()
  return t
end

-- Readies Alice and Ben, which makes the server start a match
---@param t SpectatorTest
local function spectatedPlayersReadyUp(t)
  sendSettings(t.server, t.ben, t.players[2], true)
  sendSettings(t.server, t.alice, t.players[1], true)
end

local function testASpectatorsRoomKnowsItsNumber()
  whileOnline(function(sent)
    local t = bobSpectatingAliceAndBen(sent)

    local room = GAME.netClient.room
    local roomNumber = room and room.roomNumber
    if room then
      room:shutdown()
    end
    assert(room, "the spectate request should put the client in the room")
    assert(roomNumber == t.serverRoom.roomNumber,
           "the spectator's room should have the server's room number, but has " .. tostring(roomNumber))
  end)
end

testASpectatorsRoomKnowsItsNumber()

-- Bob stops watching a match, the way the game screen's escape does, as Alice and Ben finish it.
-- Their result and the start of their next match reach his client in one frame, ahead of the confirmation of his leave.
local function testASpectatorWhoLeftGetsNoMatchFromTheNextMatchStart()
  whileOnline(function(sent)
    local t = bobSpectatingAliceAndBen(sent)
    local room = GAME.netClient.room
    spectatedPlayersReadyUp(t)
    deliverToClient(t.socket, t.bob)
    GAME.netClient:update()
    local watchedMatch = room.match
    assert(watchedMatch, "the spectator should watch the match the players started")

    watchedMatch:disconnectSignal("matchEnded", room)
    watchedMatch:abort()
    room:shutdown()
    for _, player in ipairs({t.alice, t.ben}) do
      ServerTesting.receiveMessage(player, ClientProtocol.reportLocalGameResult(1).messageText)
    end
    t.server:update()
    deliverToClient(t.socket, t.bob)
    spectatedPlayersReadyUp(t)
    deliverToClient(t.socket, t.bob)
    local pushedBefore = #t.pushed
    local updated, err = pcall(GAME.netClient.update, GAME.netClient)

    local nextMatch = room.match
    if nextMatch then
      nextMatch:deinit()
    end
    assert(updated, "the next match start should not crash the client: " .. tostring(err))
    assert(nextMatch == nil, "a match start for a room the spectator left should start no match")
    assert(#t.pushed == pushedBefore, "a match start for a room the spectator left should push no scene")
  end)
end

testASpectatorWhoLeftGetsNoMatchFromTheNextMatchStart()

-- Bob's client is behind on the match he watches when the result and the start of the next match reach it.
-- The match he was behind on ending later, as a catch-up the next match covered can run it to its end, leaves the next match alone.
local function testASpectatorsOldMatchEndingLeavesTheNextMatchAlone()
  whileOnline(function(sent)
    local t = bobSpectatingAliceAndBen(sent)
    local room = GAME.netClient.room
    spectatedPlayersReadyUp(t)
    deliverToClient(t.socket, t.bob)
    GAME.netClient:update()
    local watchedMatch = room.match

    for _, player in ipairs({t.alice, t.ben}) do
      ServerTesting.receiveMessage(player, ClientProtocol.reportLocalGameResult(1).messageText)
    end
    t.server:update()
    deliverToClient(t.socket, t.bob)
    spectatedPlayersReadyUp(t)
    deliverToClient(t.socket, t.bob)
    GAME.netClient:update()
    local nextMatch = room.match
    endTheMatch(watchedMatch)
    local matchAfterTheOldOneEnded = room.match

    room:shutdown()
    for _, match in ipairs({watchedMatch, nextMatch}) do
      match:deinit()
    end
    assert(nextMatch and nextMatch ~= watchedMatch, "the match start should start the next match")
    assert(matchAfterTheOldOneEnded == nextMatch, "the old match ending should leave the room on the next match")
  end)
end

testASpectatorsOldMatchEndingLeavesTheNextMatchAlone()

local function testDisconnectingAMissingCallbackKeepsTheOthers()
  local emitter = {}
  Signal.turnIntoEmitter(emitter)
  emitter:createSignal("changed")
  local subscriber = {}
  local function kept() end
  local function neverConnected() end
  emitter:connectSignal("changed", subscriber, kept)

  emitter:disconnectSignal("changed", subscriber, neverConnected)

  assert(emitter.signalSubscriptions.changed[subscriber][1] == kept,
         "disconnecting a callback that was never connected should keep the connected one")
end

testDisconnectingAMissingCallbackKeepsTheOthers()

-- The tests above stand in for the connection, the server and the navigation stack. Nothing of that may outlive them:
-- the next test file runs in the same game.
local function testEverythingTheTestsTouchedIsBack()
  local tables = touchedTables()
  for i, t in ipairs(tables) do
    local before = stateBeforeTheTests[i]
    for key, value in next, t do
      assert(before[key] == value, "field " .. tostring(key) .. " of touched table " .. i .. " was left changed")
    end
    for key, value in next, before do
      assert(rawget(t, key) == value, "field " .. tostring(key) .. " of touched table " .. i .. " was left changed")
    end
  end
  assert(GAME.netClient.isConnected == NetClient.isConnected, "the net client should use its own isConnected again")
end

testEverythingTheTestsTouchedIsBack()
