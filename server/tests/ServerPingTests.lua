---@diagnostic disable: invisible
local ServerTesting = require("server.tests.ServerTesting")
local NetworkProtocol = require("common.network.NetworkProtocol")

-- the ping updates sent to the player, which go out already encoded
local function pingUpdatesFor(player)
  local updates = {}
  local q = player.connection.outgoingInputQueue
  while q:len() > 0 do
    local _, body = NetworkProtocol.getMessageFromString(q:pop(), false)
    local message = json.decode(body)
    if message.type == "pingUpdate" then
      updates[#updates + 1] = message
    end
  end
  return updates
end

local function testRoundTripsOnAPlayersConnectionAreTheirPing()
  local server = ServerTesting.getTestServer()
  local bob = ServerTesting.login(server, ServerTesting.players[1])

  bob.connection.pingStats:addSample(80)

  assert(bob.pingStats:current() == 80, "the round trip should be bob's ping, got " .. tostring(bob.pingStats:current()))
end

testRoundTripsOnAPlayersConnectionAreTheirPing()

-- the pings in a ping update, keyed by public id
local function pingsIn(update)
  local pings = {}
  for _, player in ipairs(update.content.players) do
    pings[player.publicId] = player
  end
  return pings
end

local function testPlayersInAMatchHearNoPingUpdates()
  local server = ServerTesting.getTestServer()
  local alice = ServerTesting.login(server, ServerTesting.players[2], true)
  local ben = ServerTesting.login(server, ServerTesting.players[3], true)
  local room = ServerTesting.setupRoom(server, alice, ben, true)
  ServerTesting.startGame(server, room)
  alice.connection.pingStats:addSample(40)

  server:broadcastPings()

  assert(alice.state == "playing", "the match should have started, alice is " .. alice.state)
  assert(#pingUpdatesFor(alice) == 0, "nothing in a match shows pings, so a player in one should not be sent them")
end

testPlayersInAMatchHearNoPingUpdates()

local function testPlayersWhoUnderstandPingUpdatesHearTheCurrentAndAveragePingOfEveryoneOnline()
  local server = ServerTesting.getTestServer()
  local alice = ServerTesting.login(server, ServerTesting.players[2], true)
  local ben = ServerTesting.login(server, ServerTesting.players[3], true)
  local room = ServerTesting.setupRoom(server, alice, ben, true)
  local bob = ServerTesting.login(server, ServerTesting.players[1], true)
  ServerTesting.addSpectator(server, room, bob)
  local carl = ServerTesting.login(server, ServerTesting.players[4])
  alice.connection.pingStats:addSample(40)
  ben.connection.pingStats:addSample(600)
  bob.connection.pingStats:addSample(70)
  carl.connection.pingStats:addSample(90)

  server:broadcastPings()

  local update = pingUpdatesFor(alice)[1]
  assert(update, "alice's client understands ping updates, so she should get them")
  local pings = pingsIn(update)
  assert(pings[alice.publicPlayerID].current == 40 and pings[alice.publicPlayerID].jitter == 0, "alice should hear her own ping")
  local benPing = pings[ben.publicPlayerID]
  assert(benPing.current == 600 and benPing.average == 600, "alice should hear her opponent's current and average ping")
  assert(pings[bob.publicPlayerID].current == 70, "alice should hear the spectator's ping")
  assert(pings[carl.publicPlayerID].current == 90, "alice should hear the ping of a lobby player whose client does not understand ping updates")
  local spectatorPings = pingsIn(pingUpdatesFor(bob)[1])
  assert(spectatorPings[ben.publicPlayerID].current == 600, "a spectator should hear the same pings")
end

testPlayersWhoUnderstandPingUpdatesHearTheCurrentAndAveragePingOfEveryoneOnline()

local function testAPlayerWithoutASampleIsLeftOut()
  local server = ServerTesting.getTestServer()
  local alice = ServerTesting.login(server, ServerTesting.players[2], true)
  local bob = ServerTesting.login(server, ServerTesting.players[1])
  alice.connection.pingStats:addSample(40)

  server:broadcastPings()

  assert(pingsIn(pingUpdatesFor(alice)[1])[bob.publicPlayerID] == nil, "bob has not been measured yet, so there is nothing to tell")
end

testAPlayerWithoutASampleIsLeftOut()

local function testPlayersWhoseClientsDoNotUnderstandPingUpdatesHearNothing()
  local server = ServerTesting.getTestServer()
  local bob = ServerTesting.login(server, ServerTesting.players[1])
  bob.connection.pingStats:addSample(40)

  server:broadcastPings()

  assert(#pingUpdatesFor(bob) == 0, "a client that did not say it understands ping updates would never take one out of its queue")
end

testPlayersWhoseClientsDoNotUnderstandPingUpdatesHearNothing()

local function testThePingUpdatesAverageFollowsTheRecentRoundTrips()
  local server = ServerTesting.getTestServer()
  local alice = ServerTesting.login(server, ServerTesting.players[2], true)
  for _ = 1, 60 do
    alice.connection.pingStats:addSample(10)
  end
  for _ = 1, 10 do
    alice.connection.pingStats:addSample(1500)
  end

  server:broadcastPings()

  local own = pingsIn(pingUpdatesFor(alice)[1])[alice.publicPlayerID]
  assert(own.average == 1500, "20 seconds of 1500 ms round trips should average 1500 ms, got " .. tostring(own.average))
end

testThePingUpdatesAverageFollowsTheRecentRoundTrips()
