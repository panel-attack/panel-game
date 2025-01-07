---@diagnostic disable: invisible, undefined-field
local Server = require("server.server")
local database = require("server.PADatabase")
local MockPersistence = require("server.tests.MockPersistence")
local ClientProtocol = require("common.network.ClientProtocol")
local MockConnection = require("server.tests.MockConnection")
local Player = require("server.Player")
local json = require("common.lib.dkjson")

local function getTestServer()
  local testServer = Server(database, MockPersistence)

  -- we don't want to call anything that has anything to do with real sockets
  -- messages just get injected into the MockConnection queues
  testServer.update = function(self)
    self:processMessages()
    self:broadCastLobbyIfChanged()
    self.lastProcessTime = os.time()
  end

  return testServer
end

local players = {
  Player("1", MockConnection(), "Bob", 4),
  Player("2", MockConnection(), "Alice", 5),
  Player("3", MockConnection(), "Ben", 8),
  Player("4", MockConnection(), "Jerry", 24),
  Player("5", MockConnection(), "Berta", 38),
  Player("6", MockConnection(), "Raccoon", 83),
}

local function testLogin()
  local server = getTestServer()
  local playerData = {}
  for i, player in ipairs(players) do
    player.connection.loggedIn = false
    playerData[player.userId] = player.name
  end
  server:initializePlayerData("", playerData)

  local bob = players[1]
  server:addConnection(bob.connection)
  server:update()

  bob.connection:receiveMessage(json.encode(ClientProtocol.requestLogin(bob.userId, bob.name, 10, "controller", "pacci", nil, nil, nil, nil, true, "with my name").messageText))
  server:update()

  assert(server.connectionNumberIndex == 2)
  local p = server.connectionToPlayer[bob.connection]
  assert(p)
  assert(server.nameToConnectionIndex["Bob"] == bob.connection)
  assert(server.nameToPlayer["Bob"] == p)
  local lobbyState = bob.connection.outgoingMessageQueue:pop()
  assert(lobbyState and lobbyState.unpaired and lobbyState.unpaired[1] == "Bob")
end

testLogin()