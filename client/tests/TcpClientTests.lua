local TcpClient = require("client.src.network.TcpClient")
local ClientMessages = require("common.network.ClientProtocol")
local NetworkProtocol = require("common.network.NetworkProtocol")
local socket = require("socket")

-- a listener on a free port on localhost stands in for the server, so the tests need no network
local function createLocalServer()
  local server = socket.tcp()
  assert(server:bind("127.0.0.1", 0))
  assert(server:listen(1))
  server:settimeout(5)
  local ip, port = server:getsockname()
  return server, ip, port
end

local function connectClient()
  local server, ip, port = createLocalServer()
  local tcpClient = TcpClient()
  local success = tcpClient:connectToServer(ip, port)
  assert(success)
  assert(tcpClient:isConnected())
  local serverSideSocket, err = server:accept()
  assert(serverSideSocket, err)
  serverSideSocket:settimeout(5)
  return tcpClient, server, serverSideSocket
end

local function testConnectDisconnect()
  local tcpClient, server, serverSideSocket = connectClient()
  tcpClient:resetNetwork()
  assert(not tcpClient:isConnected())
  serverSideSocket:close()
  server:close()
end

testConnectDisconnect()

local function testSendData()
  local tcpClient, server, serverSideSocket = connectClient()
  local message = NetworkProtocol.clientMessageTypes.versionCheck.prefix .. NetworkProtocol.NETWORK_VERSION
  assert(tcpClient:send(message))

  local received, err = serverSideSocket:receive(#message)
  assert(received, err)
  assert(received == message, "expected " .. message .. " but the server received " .. received)
  local messageType, messageText = NetworkProtocol.getMessageFromString(received, false)
  assert(messageType == NetworkProtocol.clientMessageTypes.versionCheck.prefix)
  assert(messageText == NetworkProtocol.NETWORK_VERSION)

  tcpClient:sendRequest(ClientMessages.logout())
  assert(tcpClient:isConnected())
  tcpClient:resetNetwork()
  assert(not tcpClient:isConnected())
  serverSideSocket:close()
  server:close()
end

testSendData()
