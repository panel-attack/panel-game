---@diagnostic disable: invisible, undefined-field, inject-field
local Server = require("server.server")
local MockPersistence = require("server.tests.MockPersistence")
local ClientProtocol = require("common.network.ClientProtocol")
local MockConnection = require("server.tests.MockConnection")
local Player = require("server.Player")
local json = require("common.lib.dkjson")

local ServerTesting = {}

ServerTesting.players = {
  Player("1", MockConnection(), "Bob", 4),
  Player("2", MockConnection(), "Alice", 5),
  Player("3", MockConnection(), "Ben", 8),
  Player("4", MockConnection(), "Jerry", 24),
  Player("5", MockConnection(), "Berta", 38),
  Player("6", MockConnection(), "Raccoon", 83),
}

ServerTesting.players[1].rating = 1500
ServerTesting.players[1].placementsDone = false
ServerTesting.players[2].rating = 1732
ServerTesting.players[2].placementsDone = true
ServerTesting.players[3].rating = 1458
ServerTesting.players[3].placementsDone = true
ServerTesting.players[4].rating = 1300
ServerTesting.players[4].placementsDone = false
ServerTesting.players[5].rating = 1222
ServerTesting.players[5].placementsDone = true
ServerTesting.players[6].rating = 432
ServerTesting.players[6].placementsDone = true

local playerData = {}
for i, player in ipairs(ServerTesting.players) do
  player:updateSettings({inputMethod = "controller", level = 10})
  player.connection.loggedIn = false
  playerData[player.userId] = player.name
end

local defaultRating = 1500
ServerTesting.leaderboardData = {}

local rowHeader = {"user_id", "user_name", "rating", "placement_done", "placement_rating"}
function ServerTesting.addToLeaderboard(lb, player)
  local dataRow = {player.userId, player.name}

  if not player.placementsDone then
    dataRow[3] = defaultRating
    dataRow[4] = tostring(false)
    dataRow[5] = player.rating
    lb.loadedPlacementMatches.incomplete[player.userId] = {}
  else
    dataRow[3] = player.rating
    dataRow[4] = tostring(true)
  end

  lb:importData({rowHeader, dataRow})
end

function ServerTesting.getTestServer()
  local testServer = Server(false, MockPersistence)
  testServer:initializePlayerData("", playerData)

  -- let's just wrap and overwrite the functions that directly access the database for now
  testServer.logIP = function(player, ipAddress) end
  testServer.getMessages = function(player) return {} end
  testServer.getUnseenBans = function(player) return {} end
  testServer.markBanAsSeen = function(banId) end
  testServer.markMessageAsSeen = function(messageId) end
  testServer.getBanByIP = function(ip) end
  testServer.insertBan = function(ip, reason, completionTime) end

  -- we don't want to call anything that has anything to do with real sockets
  -- messages just get injected into the MockConnection queues
  testServer.update = function(self)
    self:processMessages()
    self:broadCastLobbyIfChanged()
    self.lastProcessTime = os.time()
  end

  return testServer
end

---@param server Server
---@param player ServerPlayer
---@return ServerPlayer # the new player object generated on the server; use instead of the param player going forward
function ServerTesting.login(server, player)
  if not player.connection.socket then
    player.connection:restore()
  end
  player.connection.loggedIn = false
  server:addConnection(player.connection)
  player.connection:receiveMessage(json.encode(ClientProtocol.requestLogin(player.userId, player.name, 10, "controller", "pacci", nil, nil, nil, nil, true, "with my name").messageText))
  server:update()
  player.connection.outgoingMessageQueue:clear()
  return server.connectionToPlayer[player.connection]
end

function ServerTesting.clearOutgoingMessages(p)
  for _, player in pairs(p) do
    player.connection.outgoingMessageQueue:clear()
    player.connection.outgoingInputQueue:clear()
  end
end

function ServerTesting.setupRoom(server, player1, player2, alreadyLoggedIn)
  if not alreadyLoggedIn then
    player1 = ServerTesting.login(server, player1)
    player2 = ServerTesting.login(server, player2)
    ServerTesting.clearOutgoingMessages({player1, player2})
  end
  player1.connection:receiveMessage(json.encode(ClientProtocol.challengePlayer(player1.name, player2.name).messageText))
  server:update()
  player2.connection:receiveMessage(json.encode(ClientProtocol.challengePlayer(player2.name, player1.name).messageText))
  server:update()
  ServerTesting.clearOutgoingMessages({player1, player2})

  return server.playerToRoom[player1]
end

local readyMessage = json.encode({menu_state = {wants_ready = true, loaded = true, ready = true}})

function ServerTesting.startGame(server, room)
  for i, player in ipairs(room.players) do
    player.connection:receiveMessage(readyMessage)
  end
  server:update()
  ServerTesting.clearOutgoingMessages(room.players)
  ServerTesting.clearOutgoingMessages(room.spectators)
end

function ServerTesting.addSpectator(server, room, spectator)
  spectator.connection:receiveMessage(json.encode(ClientProtocol.requestSpectate(spectator.name, room.roomNumber).messageText))
  server:update()
  ServerTesting.clearOutgoingMessages({spectator})
end

return ServerTesting