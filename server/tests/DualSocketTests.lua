-- Exercise the dual-socket routing on the server-side Player. Verifies
-- that JSON (J prefix) lands on the lobby connection's queue while raw
-- gameplay messages (I/G/D/K) land on the gameplay connection's queue,
-- and that the cross-channel fallback works when one channel is missing.

local logger = require("common.lib.logger")
local Player = require("server.Player")
local MockConnection = require("server.tests.MockConnection")

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

  player:send("Iabc")
  assert(gameplayConn.outgoingInputQueue:len() == 1, "I (input) should land on gameplay queue")
  assert(lobbyConn.outgoingInputQueue:len() == 0, "I (input) should NOT land on lobby queue")

  player:send("Gxyz")
  assert(gameplayConn.outgoingInputQueue:len() == 2, "G (garbage event) should also land on gameplay queue")

  player:send("Jraw-json")
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

test_player_routes_json_to_lobby_and_raw_to_gameplay()
test_json_falls_back_to_gameplay_when_lobby_missing()
test_lobby_drop_does_not_break_gameplay()
logger.info("All DualSocketTests passed!")
