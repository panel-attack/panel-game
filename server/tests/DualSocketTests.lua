-- Exercise the dual-socket routing on the server-side Player. Verifies
-- that JSON (J prefix) lands on the lobby connection's queue while raw
-- gameplay messages (I/G/D/K) land on the gameplay connection's queue,
-- and that the cross-channel fallback works when one channel is missing.

local logger = require("common.lib.logger")
local Player = require("server.Player")
local MockConnection = require("server.tests.MockConnection")
local NetworkProtocol = require("common.network.NetworkProtocol")

-- v009 framing: tests need real wire frames so Player:send's prefix lookup
-- finds the prefix at byte 5 (rather than byte-1 fallback we keep for
-- defensive un-framed inputs).
local function frame(prefix, body)
  return NetworkProtocol.markedMessageForTypeAndBody(prefix, body or "")
end

local function newPlayer(channel)
  -- Player constructor binds to the channel of the connection it gets;
  -- a single-channel Player is the "rollout" state before the second
  -- socket has authenticated.
  local conn = MockConnection(channel)
  return Player("test-uid-" .. conn.index, conn, "TestPlayer" .. conn.index, conn.index), conn
end

local function test_player_routes_json_to_lobby_and_raw_to_gameplay()
  logger.info("test_player_routes_json_to_lobby_and_raw_to_gameplay")

  local gameplayConn = MockConnection("gameplay")
  local player = Player("test-dual-1", gameplayConn, "DualPlayer", 100)
  assert(player.gameplayConnection == gameplayConn, "gameplay slot should bind on construction")
  assert(player.lobbyConnection == nil, "lobby slot should be nil before attach")

  local lobbyConn = MockConnection("lobby")
  player:attachConnection(lobbyConn)
  assert(player.lobbyConnection == lobbyConn, "lobby slot should bind via attachConnection")
  assert(player.gameplayConnection == gameplayConn, "gameplay slot should remain bound")

  player:sendJson({messageType = {prefix = "J"}, messageText = {hello = "world"}})
  assert(lobbyConn.outgoingMessageQueue:len() == 1, "JSON should land on lobby queue, got " .. lobbyConn.outgoingMessageQueue:len())
  assert(gameplayConn.outgoingMessageQueue:len() == 0, "JSON should NOT land on gameplay queue")

  player:send(frame("I", "abc"))
  assert(gameplayConn.outgoingInputQueue:len() == 1, "I (input) should land on gameplay queue")
  assert(lobbyConn.outgoingInputQueue:len() == 0, "I (input) should NOT land on lobby queue")

  player:send(frame("G", "xyz"))
  assert(gameplayConn.outgoingInputQueue:len() == 2, "G (garbage event) should also land on gameplay queue")

  player:send(frame("J", "raw-json"))
  assert(lobbyConn.outgoingInputQueue:len() == 1, "raw J message should land on lobby queue via prefix routing")
end

local function test_json_falls_back_to_gameplay_when_lobby_missing()
  logger.info("test_json_falls_back_to_gameplay_when_lobby_missing")

  local gameplayConn = MockConnection("gameplay")
  local player = Player("test-dual-2", gameplayConn, "FallbackPlayer", 101)

  -- No lobby attached. JSON should fall back to gameplay so single-socket
  -- (old client) flows continue to work.
  player:sendJson({messageType = {prefix = "J"}, messageText = {fallback = true}})
  assert(gameplayConn.outgoingMessageQueue:len() == 1,
    "JSON should fall back to gameplay when lobbyConnection is nil, got " .. gameplayConn.outgoingMessageQueue:len())
end

local function test_lobby_drop_does_not_break_gameplay()
  logger.info("test_lobby_drop_does_not_break_gameplay")

  local gameplayConn = MockConnection("gameplay")
  local player = Player("test-dual-3", gameplayConn, "DropPlayer", 102)
  local lobbyConn = MockConnection("lobby")
  player:attachConnection(lobbyConn)

  -- Simulate lobby socket loss.
  lobbyConn:close()

  -- Gameplay messages should still flow.
  player:send("Iabc")
  assert(gameplayConn.outgoingInputQueue:len() == 1, "gameplay should be unaffected by lobby drop")

  -- JSON should fall back to gameplay (because lobby.socket is now false-y).
  player:sendJson({messageType = {prefix = "J"}, messageText = {after = "drop"}})
  assert(gameplayConn.outgoingMessageQueue:len() == 1,
    "JSON should fall back to gameplay after lobby drop, got " .. gameplayConn.outgoingMessageQueue:len())
end

local function test_player_routes_spectate_traffic_to_spectate_socket()
  logger.info("test_player_routes_spectate_traffic_to_spectate_socket")

  local gameplayConn = MockConnection("gameplay")
  local player = Player("test-tri-1", gameplayConn, "TriPlayer", 200)
  local lobbyConn = MockConnection("lobby")
  player:attachConnection(lobbyConn)
  local spectateConn = MockConnection("spectate")
  player:attachConnection(spectateConn)
  assert(player.gameplayConnection == gameplayConn)
  assert(player.lobbyConnection == lobbyConn)
  assert(player.spectateConnection == spectateConn)

  -- Opponent's input relayed to this player goes via sendSpectate
  player:sendSpectate(frame("I", "opp-input"))
  assert(spectateConn.outgoingInputQueue:len() == 1, "opponent input should land on spectate")
  assert(gameplayConn.outgoingInputQueue:len() == 0, "opponent input should NOT land on gameplay")

  -- Opponent's death event
  player:sendSpectate(frame("D", "opp-death"))
  assert(spectateConn.outgoingInputQueue:len() == 2, "opponent death should land on spectate")

  -- Garbage NOT targeting this player (telegraph visual on someone else's stack)
  player:sendSpectate(frame("G", "telegraph"))
  assert(spectateConn.outgoingInputQueue:len() == 3, "telegraph G should land on spectate")

  -- Garbage actually targeting this player → uses regular send → gameplay
  player:send(frame("G", "hit-me"))
  assert(gameplayConn.outgoingInputQueue:len() == 1, "G targeting you should land on gameplay")
  assert(spectateConn.outgoingInputQueue:len() == 3, "G targeting you should NOT also land on spectate")
end

local function test_spectate_falls_back_to_gameplay_when_missing()
  logger.info("test_spectate_falls_back_to_gameplay_when_missing")

  local gameplayConn = MockConnection("gameplay")
  local player = Player("test-tri-2", gameplayConn, "FallbackPlayer", 201)

  -- No spectate attached. Opponent traffic should still flow over gameplay
  -- so the player keeps seeing opponents' boards (degraded but functional).
  player:sendSpectate(frame("I", "opp-input"))
  assert(gameplayConn.outgoingInputQueue:len() == 1,
    "spectate should fall back to gameplay when spectateConnection is nil")
end

local function test_spectate_drop_does_not_break_gameplay()
  logger.info("test_spectate_drop_does_not_break_gameplay")

  local gameplayConn = MockConnection("gameplay")
  local player = Player("test-tri-3", gameplayConn, "DropPlayer", 202)
  local spectateConn = MockConnection("spectate")
  player:attachConnection(spectateConn)

  spectateConn:close()

  -- Gameplay traffic continues
  player:send(frame("I", "your-input"))
  assert(gameplayConn.outgoingInputQueue:len() == 1, "gameplay unaffected by spectate drop")

  -- Spectate-routed traffic falls back to gameplay (degraded but delivered)
  player:sendSpectate(frame("I", "opp-input"))
  assert(gameplayConn.outgoingInputQueue:len() == 2,
    "spectate traffic falls back to gameplay after spectate drop")
end

test_player_routes_json_to_lobby_and_raw_to_gameplay()
test_json_falls_back_to_gameplay_when_lobby_missing()
test_lobby_drop_does_not_break_gameplay()
test_player_routes_spectate_traffic_to_spectate_socket()
test_spectate_falls_back_to_gameplay_when_missing()
test_spectate_drop_does_not_break_gameplay()
logger.info("All DualSocketTests passed!")
