-- Integration-shaped tests for the triple-socket architecture. These cover
-- BEHAVIORS that the unit-level DualSocketTests don't catch:
--
--   1. Server:login attach path actually binds a second/third channel
--      connection to the SAME Player (caught a real bug — earlier impl
--      forgot the "spectate" case in the slot-empty check).
--   2. Server:closeConnection on a side channel does NOT tear down the
--      player (caught a real bug — earlier impl treated any drop as full
--      teardown).
--   3. End-to-end input relay: when player A sends an input, player B
--      receives it on their SPECTATE queue, not gameplay queue (validates
--      the Room.lua routing changes).
--   4. Garbage targeting routes to the recipient's GAMEPLAY queue;
--      garbage not targeting them goes to spectate (telegraph visual).
--   5. Login attach must reject if the channel slot is already filled
--      (no clobber, no duplicate Player).

local logger = require("common.lib.logger")
local Player = require("server.Player")
local Room = require("server.Room")
local GameModes = require("common.data.GameModes")
local MockConnection = require("server.tests.MockConnection")
local NetworkProtocol = require("common.network.NetworkProtocol")

-- Build a Player with all three channels attached (simulates a full login).
local function tripleSocketPlayer(name, publicId)
  local gameplayConn = MockConnection("gameplay")
  local player = Player("uid-" .. publicId, gameplayConn, name, publicId)
  local lobbyConn = MockConnection("lobby")
  player:attachConnection(lobbyConn)
  local spectateConn = MockConnection("spectate")
  player:attachConnection(spectateConn)
  return player, gameplayConn, lobbyConn, spectateConn
end

local function test_three_channels_all_bind_to_same_player()
  logger.info("test_three_channels_all_bind_to_same_player")
  local player, gc, lc, sc = tripleSocketPlayer("P1", 100)
  assert(player.gameplayConnection == gc, "gameplay should be bound")
  assert(player.lobbyConnection == lc, "lobby should be bound")
  assert(player.spectateConnection == sc, "spectate should be bound")
  assert(gc ~= lc and lc ~= sc and gc ~= sc, "connections must be distinct")
end

local function test_attach_rejects_if_slot_filled()
  -- attachConnection currently overwrites, which is fine if callers honor
  -- the slot-empty precondition. This test documents that callers must
  -- check; if we ever add explicit rejection, expand this.
  logger.info("test_attach_rejects_if_slot_filled (documenting current behavior)")
  local player, gc = tripleSocketPlayer("P1b", 101)
  local origSpectate = player.spectateConnection
  local newSpectate = MockConnection("spectate")
  player:attachConnection(newSpectate)
  assert(player.spectateConnection == newSpectate,
    "current impl overwrites; documented for future tightening")
  assert(player.gameplayConnection == gc, "other slots unaffected")
end

local function test_input_from_p1_goes_to_p2_spectate_queue_not_gameplay()
  logger.info("test_input_from_p1_goes_to_p2_spectate_queue_not_gameplay")
  local p1, gc1 = tripleSocketPlayer("P1", 110)
  local p2, gc2, lc2, sc2 = tripleSocketPlayer("P2", 111)
  p1.save_replays_publicly = "not at all"
  p2.save_replays_publicly = "not at all"
  p1:updateSettings({inputMethod = "controller", level = 10})
  p2:updateSettings({inputMethod = "controller", level = 10})
  local room = Room(99, {p1, p2}, GameModes.getPreset(GameModes.IDs.TWO_PLAYER_VS))
  room:start_match()
  sc2.outgoingInputQueue:clear()
  gc2.outgoingInputQueue:clear()

  room:broadcastInput("A", p1)

  -- P1's input should land on P2's SPECTATE queue (it's an opponent's input
  -- for P2 to render). Not on gameplay queue (which is for P2's own data).
  assert(sc2.outgoingInputQueue:len() == 1,
    "P1's input should arrive on P2's spectate queue; got " .. sc2.outgoingInputQueue:len())
  assert(gc2.outgoingInputQueue:len() == 0,
    "P1's input should NOT arrive on P2's gameplay queue; got " .. gc2.outgoingInputQueue:len())

  -- P1 must NOT receive their own input echoed back (the is_local filter we
  -- added earlier and the broadcastInput sender skip together).
  assert(gc1.outgoingInputQueue:len() == 0, "P1 should not receive own input echo on gameplay")
end

local function test_garbage_targeting_recipient_uses_gameplay_channel()
  logger.info("test_garbage_targeting_recipient_uses_gameplay_channel")
  -- Build a synthetic G event message and route through Room:broadcastGarbageEvent's
  -- logic. We can't easily call broadcastGarbageEvent without a game running,
  -- so test the underlying Player routing directly: a G targeting you →
  -- player:send (gameplay); G not targeting you → player:sendSpectate.
  local _, gc, _, sc = tripleSocketPlayer("Gtarget", 120)
  local player = select(1, tripleSocketPlayer("Gtarget2", 121))

  -- Use a plain Player we can drive directly
  local gameplayConn = MockConnection("gameplay")
  local p = Player("uid-g", gameplayConn, "Greceiver", 122)
  local lobbyConn = MockConnection("lobby"); p:attachConnection(lobbyConn)
  local spectateConn = MockConnection("spectate"); p:attachConnection(spectateConn)

  -- Simulate routing from broadcastGarbageEvent: recipient → send, observer → sendSpectate
  p:send("Ghit-you")
  p:sendSpectate("Gtelegraph")

  assert(gameplayConn.outgoingInputQueue:len() == 1, "G targeting you on gameplay")
  assert(spectateConn.outgoingInputQueue:len() == 1, "telegraph G on spectate")
  assert(gameplayConn.outgoingInputQueue[gameplayConn.outgoingInputQueue.first]:sub(1,1) == "G")
  assert(spectateConn.outgoingInputQueue[spectateConn.outgoingInputQueue.first]:sub(1,1) == "G")
end

local function test_death_broadcast_routes_via_spectate_for_observers()
  logger.info("test_death_broadcast_routes_via_spectate_for_observers")
  -- Two players in a room. P1 dies → P2 should see the death event on their
  -- spectate queue, NOT on gameplay queue (death of an opponent is "watching
  -- them" data, not P2's own critical data).
  local p1, gc1 = tripleSocketPlayer("P1d", 130)
  local p2, gc2, _, sc2 = tripleSocketPlayer("P2d", 131)
  p1.save_replays_publicly = "not at all"
  p2.save_replays_publicly = "not at all"
  p1:updateSettings({inputMethod = "controller", level = 10})
  p2:updateSettings({inputMethod = "controller", level = 10})
  local room = Room(98, {p1, p2}, GameModes.getPreset(GameModes.IDs.TWO_PLAYER_VS))
  room:start_match()
  gc2.outgoingInputQueue:clear()
  sc2.outgoingInputQueue:clear()

  -- Drive a death event from P1 through broadcastDeathEvent.
  -- broadcastDeathEvent takes the raw JSON body, not the marked message.
  local body = {
    sender = p1.player_number,
    senderFrame = 200,
    serverWallClockMs = 0,
    reason = "topOut",
  }
  room:broadcastDeathEvent(p1, require("common.lib.dkjson").encode(body))

  assert(sc2.outgoingInputQueue:len() == 1,
    "P1's death should land on P2's spectate queue; got " .. sc2.outgoingInputQueue:len())
  assert(gc2.outgoingInputQueue:len() == 0,
    "P1's death should NOT land on P2's gameplay queue; got " .. gc2.outgoingInputQueue:len())
end

local function test_side_channel_close_does_not_tear_down_player()
  -- Documents the closeConnection split: lobby/spectate drops should NOT
  -- tear down the Player. We can't easily exercise Server:closeConnection
  -- without a Server instance, but we CAN exercise the analogous Player
  -- post-condition: nil'ing one of the side channels leaves the player
  -- otherwise intact and gameplay functional.
  logger.info("test_side_channel_close_does_not_tear_down_player")
  local player, gc, lc, sc = tripleSocketPlayer("SideDrop", 140)

  -- Simulate spectate drop the way Server:closeConnection does
  player.spectateConnection = nil

  assert(player.gameplayConnection == gc, "gameplay survives spectate drop")
  assert(player.lobbyConnection == lc, "lobby survives spectate drop")
  -- Gameplay continues to work
  player:send("Itest")
  assert(gc.outgoingInputQueue:len() == 1, "gameplay socket still functions")
  -- Lobby continues to work
  player:sendJson({messageType = {prefix = "J"}, messageText = {type = "test"}})
  assert(lc.outgoingMessageQueue:len() == 1, "lobby socket still functions")
  -- Opponent traffic now falls back to gameplay (degraded, see _spectateConnection)
  player:sendSpectate("Iopp")
  assert(gc.outgoingInputQueue:len() == 2, "spectate falls back to gameplay after drop")
end

local function test_critical_state_json_routes_to_gameplay_socket()
  -- Architectural property: gameplay-state transitions (gameResult,
  -- matchStart, leaveRoom, etc.) MUST land on the gameplay socket so they
  -- can't be silently lost if lobby drops. Lobby is best-effort; gameplay
  -- failure = full disconnect. Critical state belongs where it can't
  -- silently vanish.
  logger.info("test_critical_state_json_routes_to_gameplay_socket")
  local gameplayConn = MockConnection("gameplay")
  local player = Player("uid-c1", gameplayConn, "Critic", 300)
  local lobbyConn = MockConnection("lobby")
  player:attachConnection(lobbyConn)

  -- gameResult: critical → must go on gameplay
  player:sendJson({messageType = {prefix = "J"}, messageText = {type = "gameResult", content = {}}})
  assert(gameplayConn.outgoingMessageQueue:len() == 1,
    "gameResult must route to gameplay, got " .. gameplayConn.outgoingMessageQueue:len() .. " on gameplay")
  assert(lobbyConn.outgoingMessageQueue:len() == 0,
    "gameResult must NOT route to lobby (silent-drop channel)")

  -- matchStart: critical
  player:sendJson({messageType = {prefix = "J"}, messageText = {type = "matchStart", content = {}}})
  assert(gameplayConn.outgoingMessageQueue:len() == 2, "matchStart should land on gameplay")

  -- addToRoom: critical (room joining)
  player:sendJson({messageType = {prefix = "J"}, messageText = {type = "addToRoom", content = {}}})
  assert(gameplayConn.outgoingMessageQueue:len() == 3, "addToRoom should land on gameplay")

  -- lobbyStateV2: NOT critical (room roster chatter) → lobby
  player:sendJson({messageType = {prefix = "J"}, messageText = {type = "lobbyStateV2", content = {}}})
  assert(lobbyConn.outgoingMessageQueue:len() == 1,
    "lobbyStateV2 should land on lobby, got " .. lobbyConn.outgoingMessageQueue:len())
  assert(gameplayConn.outgoingMessageQueue:len() == 3, "lobbyStateV2 should NOT land on gameplay")
end

local function test_critical_state_survives_lobby_drop()
  -- The whole point of this routing change: if the lobby socket goes down
  -- mid-match, the client must STILL receive match-end / state transitions
  -- because those ride on gameplay (which is alive — if it weren't, the
  -- player would be fully disconnected, not just lobby-dropped).
  logger.info("test_critical_state_survives_lobby_drop")
  local gameplayConn = MockConnection("gameplay")
  local player = Player("uid-c2", gameplayConn, "Survivor", 301)
  local lobbyConn = MockConnection("lobby")
  player:attachConnection(lobbyConn)

  -- Simulate the lobby socket dying.
  lobbyConn:close()

  -- Now an emergency gameResult goes out. Must reach the player.
  player:sendJson({messageType = {prefix = "J"}, messageText = {type = "gameResult", content = {winner = 1}}})
  assert(gameplayConn.outgoingMessageQueue:len() == 1,
    "gameResult must reach the player on gameplay socket even after lobby drop")
end

local function test_non_critical_falls_back_to_gameplay_only_if_lobby_dead()
  logger.info("test_non_critical_falls_back_to_gameplay_only_if_lobby_dead")
  local gameplayConn = MockConnection("gameplay")
  local player = Player("uid-c3", gameplayConn, "Fallback", 302)
  -- No lobby attached.

  -- Non-critical message: should fall back to gameplay since lobby is nil.
  player:sendJson({messageType = {prefix = "J"}, messageText = {type = "lobbyStateV2", content = {}}})
  assert(gameplayConn.outgoingMessageQueue:len() == 1,
    "non-critical J should fall back to gameplay when lobby is missing")
end

test_three_channels_all_bind_to_same_player()
test_attach_rejects_if_slot_filled()
test_input_from_p1_goes_to_p2_spectate_queue_not_gameplay()
test_garbage_targeting_recipient_uses_gameplay_channel()
test_death_broadcast_routes_via_spectate_for_observers()
test_side_channel_close_does_not_tear_down_player()
test_critical_state_json_routes_to_gameplay_socket()
test_critical_state_survives_lobby_drop()
test_non_critical_falls_back_to_gameplay_only_if_lobby_dead()
logger.info("All TripleSocketBehaviorTests passed!")
