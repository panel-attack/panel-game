local NetClient = require("client.src.network.NetClient")
local TcpClient = require("client.src.network.TcpClient")
local Player = require("client.src.Player")
local NetworkProtocol = require("common.network.NetworkProtocol")

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
