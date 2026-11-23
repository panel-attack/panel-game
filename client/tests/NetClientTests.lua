local NetClient = require("client.src.network.NetClient")
local TcpClient = require("client.src.network.TcpClient")
local Player = require("client.src.Player")
local NetworkProtocol = require("common.network.NetworkProtocol")
local ClientProtocol = require("common.network.ClientProtocol")
local ServerMessages = require("client.src.network.ServerMessages")
local ServerProtocol = require("common.network.ServerProtocol")
local GameModes = require("common.data.GameModes")
local ReplayV3 = require("common.data.ReplayV3")
local json = require("common.lib.dkjson")
require("client.src.BattleRoom")

-- A connected socket that delivers whatever is put in incoming on the next read and records what is sent
local function fakeSocket()
  local socket = {incoming = "", sent = {}}
  function socket:receive()
    local data = self.incoming
    self.incoming = ""
    return nil, "timeout", data
  end
  function socket:send(message)
    self.sent[#self.sent + 1] = message
    return #message
  end
  function socket:getpeername()
    return "127.0.0.1", 49569
  end
  function socket:close() end
  return socket
end

-- A net client logged into the fake socket that last heard from the server longer ago than the deadline allows
---@return NetClient
---@return table socket
local function onlineClientLastHeardFromBeforeTheDeadline()
  local netClient = NetClient()
  local socket = fakeSocket()
  netClient.tcpClient.socket = socket
  netClient.tcpClient.lastReceiveTime = love.timer.getTime() - TcpClient.SERVER_SILENCE_LIMIT - 1
  netClient:setState(NetClient.STATES.ONLINE)
  return netClient, socket
end

-- Runs test with a stand-in local player, so a disconnect can't drop the real local player's subscriptions
---@param test fun()
local function withStandInLocalPlayer(test)
  local localPlayer = GAME.localPlayer
  GAME.localPlayer = Player("StandIn", -1, true)
  local ok, err = pcall(test)
  GAME.localPlayer = localPlayer
  assert(ok, err)
end

local function testASilentServerDisconnectsTheClient()
  withStandInLocalPlayer(function()
    local netClient = onlineClientLastHeardFromBeforeTheDeadline()
    local disconnects = {}
    netClient:connectSignal("clientDisconnected", disconnects, function(_, voluntary)
      disconnects[#disconnects + 1] = voluntary
    end)

    netClient:update()

    assert(#disconnects == 1, "a server silent past the deadline should disconnect the client once, but it disconnected " .. #disconnects .. " times")
    assert(disconnects[1] == false, "losing a silent server should count as an unintended disconnect")
    assert(netClient.state == NetClient.STATES.OFFLINE, "the client should be offline after the server went silent")
  end)
end

testASilentServerDisconnectsTheClient()

local function testServerPingsKeepTheClientConnected()
  withStandInLocalPlayer(function()
    local netClient, socket = onlineClientLastHeardFromBeforeTheDeadline()
    local disconnects = 0
    netClient:connectSignal("clientDisconnected", netClient, function()
      disconnects = disconnects + 1
    end)

    socket.incoming = NetworkProtocol.serverMessageTypes.ping.prefix
    netClient:update()

    assert(disconnects == 0, "a client receiving the server's pings should stay connected")
    assert(netClient.state == NetClient.STATES.ONLINE, "a client receiving the server's pings should stay online")
    assert(socket.sent[1] == NetworkProtocol.clientMessageTypes.acknowledgedPing.prefix, "the client should answer the ping")
  end)
end

testServerPingsKeepTheClientConnected()

-- A net client logged into the fake socket in the given state that heard from the server just now
---@param state NetClientStates
---@return NetClient
---@return table socket
local function connectedClientIn(state)
  local netClient = NetClient()
  local socket = fakeSocket()
  netClient.tcpClient.socket = socket
  netClient.tcpClient.lastReceiveTime = love.timer.getTime()
  netClient:setState(state)
  return netClient, socket
end

-- Runs test with netClient standing in for the game's, because message listeners read the game's net client
---@param netClient NetClient
---@param test fun()
local function asTheGamesNetClient(netClient, test)
  local gameNetClient = GAME.netClient
  GAME.netClient = netClient
  local ok, err = pcall(test)
  GAME.netClient = gameNetClient
  assert(ok, err)
end

local function serverMessage(message)
  return NetworkProtocol.markedMessageForTypeAndBody(NetworkProtocol.serverMessageTypes.jsonMessage.prefix, json.encode(message))
end

local function pingUpdateFromServer(content)
  return serverMessage({sender = "server", type = "pingUpdate", content = content})
end

local function testLateMatchStartDoesNotStartAMatchInTheRoomWeLeft()
  local netClient, socket = connectedClientIn(NetClient.STATES.ROOM)
  asTheGamesNetClient(netClient, function()
    local mode = GameModes.getPreset(GameModes.IDs.TWO_PLAYER_VS)
    local room = BattleRoom(mode)
    room.roomNumber = 1
    netClient.room = room
    function room:startMatch()
      error("A late matchStart tried to start a match in the room we already shut down")
    end

    room:shutdown()
    assert(netClient.room == room and netClient.state == NetClient.STATES.ROOM,
      "the client should still be waiting for the server's leaveRoom confirmation")

    local replay = ReplayV3(ENGINE_VERSION, mode.matchRules, {sourceType = 3, seed = 1, shockEnabled = true})
    socket.incoming = serverMessage(ServerProtocol.startMatch(room.roomNumber, replay).messageText)
    netClient:update()

    assert(netClient.state == NetClient.STATES.ROOM, "the client should still be waiting for the confirmation, not in a match")
    assert(netClient.tcpClient.receivedMessageQueue:top() == nil, "the late matchStart should not remain queued")
    socket.incoming = serverMessage(ServerProtocol.leaveRoom(room.roomNumber, "").messageText)
    netClient:update()
    assert(netClient.state == NetClient.STATES.ONLINE and netClient.room == nil, "the confirmation should return the client to the lobby")
  end)
end

testLateMatchStartDoesNotStartAMatchInTheRoomWeLeft()

local function testOldMatchStartDoesNotStartAMatchInTheNextRoom()
  local netClient, socket = connectedClientIn(NetClient.STATES.ROOM)
  asTheGamesNetClient(netClient, function()
    local mode = GameModes.getPreset(GameModes.IDs.TWO_PLAYER_VS)
    local oldRoom = BattleRoom(mode)
    oldRoom.roomNumber = 1
    netClient.room = oldRoom
    oldRoom:shutdown()
    socket.incoming = serverMessage(ServerProtocol.leaveRoom(oldRoom.roomNumber, "").messageText)
    netClient:update()
    assert(netClient.state == NetClient.STATES.ONLINE, "the confirmation should return the client to the lobby")

    local replay = ReplayV3(ENGINE_VERSION, mode.matchRules, {sourceType = 3, seed = 1, shockEnabled = true})
    socket.incoming = serverMessage(ServerProtocol.startMatch(oldRoom.roomNumber, replay).messageText)
    netClient:update()
    local queued = netClient.tcpClient.receivedMessageQueue:top()
    assert(queued and queued.match_start, "the old match start should be waiting in the lobby queue")

    local newRoom = BattleRoom(mode)
    newRoom.roomNumber = 2
    netClient.room = newRoom
    netClient:setState(NetClient.STATES.ROOM)
    local starts = 0
    function newRoom:startMatch()
      starts = starts + 1
      return {supportsPause = false}
    end

    netClient:update()
    assert(starts == 0 and netClient.state == NetClient.STATES.ROOM, "room 1's match start must not start a match in room 2")
    assert(netClient.tcpClient.receivedMessageQueue:top() == nil, "the old match start should be discarded")

    socket.incoming = serverMessage(ServerProtocol.startMatch(newRoom.roomNumber, replay).messageText)
    netClient:update()
    assert(starts == 1 and netClient.state == NetClient.STATES.INGAME, "room 2's own match start should still be processed")
  end)
end

testOldMatchStartDoesNotStartAMatchInTheNextRoom()

local function testSpectateGrantIdentifiesTheRoomForMatchStarts()
  local grant = ServerMessages.sanitizeMessage({
    sender = "server",
    type = "spectateRequestGranted",
    content = {roomNumber = 3, players = {}},
  })
  assert(grant.roomNumber == 3, "the spectator needs the room number to accept match starts for that room")
end

testSpectateGrantIdentifiesTheRoomForMatchStarts()

local function testTheLoginSaysItUnderstandsPingUpdates()
  local login = ClientProtocol.requestLogin("1", "Bob", 10, "controller", "pacci").messageText
  assert(login.understandsPingUpdates == true, "the client should tell the server it understands ping updates")
end

testTheLoginSaysItUnderstandsPingUpdates()

local function testAPingUpdateHoldsTheCurrentAndAveragePingOfEveryone()
  withStandInLocalPlayer(function()
    local netClient, socket = connectedClientIn(NetClient.STATES.ONLINE)

    socket.incoming = pingUpdateFromServer({
      players = {{publicId = 11, current = 48, jitter = 6, average = 50}, {publicId = 12, current = 90, jitter = 4, average = 85}},
    })
    asTheGamesNetClient(netClient, function()
      netClient:update()
    end)

    local own = netClient:pingOf(11)
    assert(own and own.current == 48 and own.jitter == 6 and own.average == 50, "the client should keep player 11's ping")
    local other = netClient:pingOf(12)
    assert(other and other.current == 90 and other.average == 85, "the client should keep player 12's ping")
  end)
end

testAPingUpdateHoldsTheCurrentAndAveragePingOfEveryone()

local function testPingUpdatesAreHeardInRoomsAndMatches()
  withStandInLocalPlayer(function()
    for _, state in ipairs({NetClient.STATES.ROOM, NetClient.STATES.INGAME}) do
      local netClient, socket = connectedClientIn(state)

      socket.incoming = pingUpdateFromServer({players = {{publicId = 11, current = 30, jitter = 2, average = 30}}})
      asTheGamesNetClient(netClient, function()
        netClient:update()
      end)

      assert(netClient:pingOf(11).current == 30, "a ping update should be heard in state " .. state)
    end
  end)
end

testPingUpdatesAreHeardInRoomsAndMatches()

local function testPingsAreForgottenOffline()
  withStandInLocalPlayer(function()
    local netClient, socket = connectedClientIn(NetClient.STATES.ONLINE)
    socket.incoming = pingUpdateFromServer({players = {{publicId = 11, current = 48, jitter = 6, average = 48}}})
    asTheGamesNetClient(netClient, function()
      netClient:update()
    end)

    netClient:setState(NetClient.STATES.OFFLINE)

    assert(netClient:pingOf(11) == nil, "an offline client should not show a stale ping")
  end)
end

testPingsAreForgottenOffline()

local function testAPlayerTheLatestUpdateLeftOutHasNoPing()
  withStandInLocalPlayer(function()
    local netClient, socket = connectedClientIn(NetClient.STATES.ONLINE)
    for _, players in ipairs({{{publicId = 7, current = 48, jitter = 6, average = 48}}, {}}) do
      socket.incoming = pingUpdateFromServer({players = players})
      asTheGamesNetClient(netClient, function()
        netClient:update()
      end)
    end

    assert(netClient:pingOf(7) == nil, "player 7 left the latest update, so their old ping no longer counts")
  end)
end

testAPlayerTheLatestUpdateLeftOutHasNoPing()

local function testAPingUpdateWithoutAPlayerListLeavesNoPings()
  withStandInLocalPlayer(function()
    for _, content in ipairs({{}, "garbled"}) do
      local netClient, socket = connectedClientIn(NetClient.STATES.ONLINE)

      socket.incoming = pingUpdateFromServer(content)
      asTheGamesNetClient(netClient, function()
        netClient:update()
      end)

      assert(netClient:pingOf(11) == nil, "an update without a player list should leave no pings")
    end
  end)
end

testAPingUpdateWithoutAPlayerListLeavesNoPings()

local function testAPlayerEntryMissingANumberIsDropped()
  withStandInLocalPlayer(function()
    local netClient, socket = connectedClientIn(NetClient.STATES.ONLINE)

    socket.incoming = pingUpdateFromServer({
      players = {{publicId = 11, current = 48}, {publicId = 12, current = 90, jitter = 4, average = 85}},
    })
    asTheGamesNetClient(netClient, function()
      netClient:update()
    end)

    assert(netClient:pingOf(11) == nil, "player 11's entry has no average or jitter, so it should be dropped")
    assert(netClient:pingOf(12).average == 85, "player 12's complete entry should still count")
  end)
end

testAPlayerEntryMissingANumberIsDropped()

local function testPingOfAnUnmeasuredPlayerIsNil()
  local netClient = NetClient()

  assert(netClient:pingOf(7) == nil, "a player nobody measured has no ping")
end

testPingOfAnUnmeasuredPlayerIsNil()
