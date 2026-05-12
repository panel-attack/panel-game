-- LooseSyncServerTests.lua
--
-- TDD tests for server-side loose-sync behavior: input relay, G/D event
-- relay, replay log recording, and KO arbitration. Each test states the
-- expected behavior; if the impl doesn't match, the impl is wrong.

---@diagnostic disable: undefined-field, invisible, inject-field
local Room = require("server.Room")
local ServerTesting = require("server.tests.ServerTesting")
local GameModes = require("common.data.GameModes")
local NetworkProtocol = require("common.network.NetworkProtocol")
local socket = require("common.lib.socket")
local json = require("common.lib.dkjson")
local logger = require("common.lib.logger")

COMPRESS_REPLAYS_ENABLED = true

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function resetPlayers(players)
  for _, p in ipairs(players) do
    p.state = "lobby"
    p.player_number = nil
    p.wantsReady = false
    p.ready = false
    p.loaded = false
    if p.connection then
      p.connection.outgoingMessageQueue:clear()
      p.connection.outgoingInputQueue:clear()
      p.connection.incomingMessageQueue:clear()
      p.connection.incomingInputQueue:clear()
      if p.connection.incomingGarbageQueue then p.connection.incomingGarbageQueue:clear() end
      if p.connection.incomingDeathQueue then p.connection.incomingDeathQueue:clear() end
    end
  end
end

-- Get a 2-player VS room with a match in progress.
local function get2pMatchInProgress()
  local p1 = ServerTesting.players[1]
  local p2 = ServerTesting.players[2]
  resetPlayers({ p1, p2 })

  local room = Room(1, { p1, p2 }, GameModes.getPreset(GameModes.IDs.TWO_PLAYER_VS))
  -- Drive players to ready state to trigger start_match
  p1:updateSettings({ wants_ready = true, loaded = true, ready = false })
  p2:updateSettings({ wants_ready = true, loaded = true, ready = true })
  p1:updateSettings({ wants_ready = true, loaded = true, ready = true })

  assert(room.game, "test setup: room should have an active game after both players ready")
  -- Clear startup messages so each test starts from a clean queue.
  for _, p in ipairs({ p1, p2 }) do
    p.connection.outgoingMessageQueue:clear()
    p.connection.outgoingInputQueue:clear()
  end
  return room, p1, p2
end

-- Count messages in a queue by prefix
local function countByPrefix(queue, prefix)
  local count = 0
  for i = queue.first, queue.last do
    local msg = queue[i]
    if type(msg) == "string" and msg:sub(1, 1) == prefix then
      count = count + 1
    end
  end
  return count
end

-- Monkey-patch socket.gettime for deterministic timing in arbitration tests.
local function withMockSocketGetTime(secondsStarting, advanceFn)
  local realGetTime = socket.gettime
  local now = secondsStarting
  socket.gettime = function() return now end
  return function(advanceSec)
    now = now + advanceSec
  end, function()
    socket.gettime = realGetTime
  end
end

----------------------------------------------------------------------
-- Test 12: Server broadcastInput relays to other players immediately
----------------------------------------------------------------------
-- Expected: P1's input is relayed to P2's outgoing queue right away. No
-- lockstep buffer; no flush call needed.

local function test_broadcastInput_relays_immediately()
  logger.info("test_broadcastInput_relays_immediately")
  local room, p1, p2 = get2pMatchInProgress()

  room:broadcastInput("A", p1)

  -- P2 should have received exactly 1 input-prefix message.
  local p2InputCount = countByPrefix(p2.connection.outgoingInputQueue, "I")
  assert(p2InputCount == 1, "P2 should have 1 'I' input from P1, got " .. p2InputCount)
  -- P1 should NOT have an echo back of their own input.
  local p1InputCount = countByPrefix(p1.connection.outgoingInputQueue, "I")
  assert(p1InputCount == 0, "P1 should not echo their own input, got " .. p1InputCount)
  -- The input should be recorded in the replay log too.
  assert(#room.game.inputs[1] == 1, "P1's input should be in replay log, got " .. #room.game.inputs[1])

  room:close()
end

----------------------------------------------------------------------
-- Test 13: Server broadcastGarbageEvent stamps + records + relays
----------------------------------------------------------------------
-- Expected: G arrives from P1 → server stamps serverWallClockMs, appends to
-- game.garbageEvents, relays to P2 with a "G" prefix. P1 doesn't get an echo.

local function test_broadcastGarbageEvent_relay()
  logger.info("test_broadcastGarbageEvent_relay")
  local room, p1, p2 = get2pMatchInProgress()

  local body = json.encode({ senderFrame = 500, recipients = { 2 }, garbage = { { width = 6, height = 1 } } })
  room:broadcastGarbageEvent(p1, body)

  -- Recorded
  assert(#room.game.garbageEvents == 1, "1 G event should be recorded, got " .. #room.game.garbageEvents)
  local recorded = room.game.garbageEvents[1]
  assert(recorded.sender == 1, "recorded sender should be slot 1, got " .. tostring(recorded.sender))
  assert(type(recorded.serverWallClockMs) == "number", "serverWallClockMs should be stamped")
  assert(recorded.senderFrame == 500, "senderFrame preserved")

  -- Relayed to P2, not P1
  local p2GCount = countByPrefix(p2.connection.outgoingInputQueue, "G")
  assert(p2GCount == 1, "P2 should receive 1 G, got " .. p2GCount)
  local p1GCount = countByPrefix(p1.connection.outgoingInputQueue, "G")
  assert(p1GCount == 0, "P1 should not receive G echo of their own, got " .. p1GCount)

  room:close()
end

----------------------------------------------------------------------
-- Test 14: Server broadcastDeathEvent marks eliminated + starts arbitration
----------------------------------------------------------------------
-- Expected: D event from P1 →
--   (a) game.eliminatedPlayers[1] = senderFrame
--   (b) game.deathEvents has 1 entry
--   (c) arbitrationDeaths has 1 entry
--   (d) arbitrationWindowEndsAtMs is set in the future
--   (e) P2 receives a "D" prefix message
--   (f) P1 does not receive an echo

local function test_broadcastDeathEvent_eliminate_and_arbitrate()
  logger.info("test_broadcastDeathEvent_eliminate_and_arbitrate")
  local room, p1, p2 = get2pMatchInProgress()

  local body = json.encode({ senderFrame = 1000, reason = "topOut" })
  room:broadcastDeathEvent(p1, body)

  assert(room.game.eliminatedPlayers[1] == 1000,
    "P1 should be marked eliminated at frame 1000, got " .. tostring(room.game.eliminatedPlayers[1]))
  assert(#room.game.deathEvents == 1, "1 D event should be recorded")
  assert(#room.arbitrationDeaths == 1, "arbitration should have 1 death captured")
  assert(room.arbitrationWindowEndsAtMs and room.arbitrationWindowEndsAtMs > 0,
    "arbitration window end-time should be set")

  local p2DCount = countByPrefix(p2.connection.outgoingInputQueue, "D")
  assert(p2DCount == 1, "P2 should receive 1 D, got " .. p2DCount)
  local p1DCount = countByPrefix(p1.connection.outgoingInputQueue, "D")
  assert(p1DCount == 0, "P1 should not echo D")

  room:close()
end

----------------------------------------------------------------------
-- Test 15: KO arbitration single death → K with surviving winner
----------------------------------------------------------------------
-- Expected: P1 dies, window closes after 200ms, server emits K with
-- winnerSlot = 2 and tie = false. Both players receive K. arbitrationEmitted
-- is set so further ticks don't re-emit.

local function test_arbitration_singleDeath_emits_winner()
  logger.info("test_arbitration_singleDeath_emits_winner")
  local advance, restore = withMockSocketGetTime(1000.0)
  local ok, err = pcall(function()
    local room, p1, p2 = get2pMatchInProgress()

    -- Bake current mock time into the D event
    room:broadcastDeathEvent(p1, json.encode({ senderFrame = 500, reason = "topOut" }))

    -- Window opened at T=1000.0s, ends at T=1000.2s.
    -- Tick at T=1000.1s → should NOT emit yet.
    advance(0.1)
    room:tickArbitration(math.floor(socket.gettime() * 1000))
    assert(not room.arbitrationEmitted, "K should not be emitted before window closes")

    -- Tick at T=1000.25s → window closed, should emit K.
    advance(0.15)
    room:tickArbitration(math.floor(socket.gettime() * 1000))
    assert(room.arbitrationEmitted, "K should be emitted after window expiry")

    local p2KCount = countByPrefix(p2.connection.outgoingInputQueue, "K")
    assert(p2KCount == 1, "P2 should receive 1 K, got " .. p2KCount)
    local p1KCount = countByPrefix(p1.connection.outgoingInputQueue, "K")
    assert(p1KCount == 1, "P1 should also receive K (broadcast to all), got " .. p1KCount)

    -- A second tick should not re-emit.
    advance(0.1)
    room:tickArbitration(math.floor(socket.gettime() * 1000))
    p2KCount = countByPrefix(p2.connection.outgoingInputQueue, "K")
    assert(p2KCount == 1, "K should not be re-emitted, got " .. p2KCount)

    room:close()
  end)
  restore()
  if not ok then error(err) end
end

----------------------------------------------------------------------
-- Test 16: KO arbitration simultaneous double-death → K with tie
----------------------------------------------------------------------
-- Expected: P1 dies at T=0, P2 dies at T=50ms (within 200ms window). After
-- window closes, K has tie=true, winnerSlot=nil, deaths has 2 entries.

local function test_arbitration_doubleDeath_tie()
  logger.info("test_arbitration_doubleDeath_tie")
  local advance, restore = withMockSocketGetTime(2000.0)
  local ok, err = pcall(function()
    local room, p1, p2 = get2pMatchInProgress()

    room:broadcastDeathEvent(p1, json.encode({ senderFrame = 500, reason = "topOut" }))
    advance(0.05)
    room:broadcastDeathEvent(p2, json.encode({ senderFrame = 510, reason = "topOut" }))

    -- Both deaths within the window. Tick after window expiry.
    advance(0.3)
    room:tickArbitration(math.floor(socket.gettime() * 1000))
    assert(room.arbitrationEmitted, "K should be emitted")

    -- Decode the K message sent to P1 (or P2)
    local kMsg = nil
    local q = p1.connection.outgoingInputQueue
    for i = q.first, q.last do
      local m = q[i]
      if type(m) == "string" and m:sub(1, 1) == "K" then
        -- strip prefix and ←J← suffix
        local body = m:sub(2)
        local endMarker = body:find("←J←")
        if endMarker then body = body:sub(1, endMarker - 1) end
        kMsg = json.decode(body)
        break
      end
    end
    assert(kMsg, "P1 should have received a K message")
    assert(kMsg.tie == true,
      "double-death within window should produce tie=true, got " .. tostring(kMsg.tie))
    assert(kMsg.winnerSlot == nil, "tie should have nil winnerSlot")

    room:close()
  end)
  restore()
  if not ok then error(err) end
end

----------------------------------------------------------------------
-- Test 17: KO arbitration window extends with new death
----------------------------------------------------------------------
-- Expected: P1 dies at T=0 (window ends T=200ms). P2 dies at T=150ms (window
-- extends to T=350ms). Tick at T=250ms must NOT emit K (still within
-- extended window). Tick at T=400ms emits K.

local function test_arbitration_window_extends()
  logger.info("test_arbitration_window_extends")
  local advance, restore = withMockSocketGetTime(3000.0)
  local ok, err = pcall(function()
    local room, p1, p2 = get2pMatchInProgress()

    -- D1 at T=0 → window ends at T=200ms
    room:broadcastDeathEvent(p1, json.encode({ senderFrame = 500, reason = "topOut" }))
    -- D2 at T=150ms → window extends to T=350ms
    advance(0.15)
    room:broadcastDeathEvent(p2, json.encode({ senderFrame = 510, reason = "topOut" }))

    -- Tick at T=250ms → window not yet closed (extended to T=350ms)
    advance(0.10)
    room:tickArbitration(math.floor(socket.gettime() * 1000))
    assert(not room.arbitrationEmitted,
      "K should NOT be emitted yet — D2 extended the window past current time")

    -- Tick at T=400ms → window now closed
    advance(0.15)
    room:tickArbitration(math.floor(socket.gettime() * 1000))
    assert(room.arbitrationEmitted, "K should be emitted after extended window closes")

    room:close()
  end)
  restore()
  if not ok then error(err) end
end

----------------------------------------------------------------------
-- Test 18: KO arbitration in 2v2 — both same-team die → other team wins
----------------------------------------------------------------------
-- Expected: in 2v2, if both members of one team die within the window and
-- the other team still has survivors, the K declares the survivors win.
-- (winnerSlot = first surviving slot in the winning team, tie = false.)

local function test_arbitration_2v2_team_wipe()
  logger.info("test_arbitration_2v2_team_wipe")
  -- Use players 3-6 to mirror TeamRoomTests convention
  local p1, p2, p3, p4 = ServerTesting.players[3], ServerTesting.players[4],
                         ServerTesting.players[5], ServerTesting.players[6]
  resetPlayers({ p1, p2, p3, p4 })

  local advance, restore = withMockSocketGetTime(4000.0)
  local ok, err = pcall(function()
    local room = Room(1, { p1, p2, p3, p4 }, GameModes.getPreset(GameModes.IDs.FOUR_PLAYER_TEAM_VS_ALL))
    -- Drive ready for all 4
    for _, p in ipairs({ p1, p2, p3, p4 }) do
      p:updateSettings({ wants_ready = true, loaded = true, ready = true })
    end
    assert(room.game, "team match should have started")
    assert(room.teams and #room.teams == 2, "team match should have 2 teams, got " .. (room.teams and #room.teams or 0))

    -- Clear startup messages
    for _, p in ipairs({ p1, p2, p3, p4 }) do
      p.connection.outgoingMessageQueue:clear()
      p.connection.outgoingInputQueue:clear()
    end

    -- Both team-1 members die within window
    room:broadcastDeathEvent(p1, json.encode({ senderFrame = 500, reason = "topOut" }))
    advance(0.05)
    room:broadcastDeathEvent(p2, json.encode({ senderFrame = 510, reason = "topOut" }))

    advance(0.3)
    room:tickArbitration(math.floor(socket.gettime() * 1000))
    assert(room.arbitrationEmitted, "K should be emitted after window")

    -- Decode K
    local kMsg = nil
    local q = p3.connection.outgoingInputQueue
    for i = q.first, q.last do
      local m = q[i]
      if type(m) == "string" and m:sub(1, 1) == "K" then
        local body = m:sub(2)
        local endMarker = body:find("←J←")
        if endMarker then body = body:sub(1, endMarker - 1) end
        kMsg = json.decode(body)
        break
      end
    end
    assert(kMsg, "P3 should have received K")
    assert(kMsg.tie == false, "team-wipe should not be tie, got " .. tostring(kMsg.tie))
    assert(kMsg.winnerSlot == 3 or kMsg.winnerSlot == 4,
      "winnerSlot should be from surviving team (3 or 4), got " .. tostring(kMsg.winnerSlot))

    room:close()
  end)
  restore()
  if not ok then error(err) end
end

----------------------------------------------------------------------
-- Test 19: Spectators CAN join partial rooms
----------------------------------------------------------------------
-- Expected: in a partial (not-yet-full) team room, room:add_spectator
-- succeeds. Spectator's state becomes "spectating" and room.spectators is
-- updated.
--
-- Replaces the deleted testPartialRoom_noSpectators in TeamRoomTests, which
-- asserted the opposite. Commit b2bda5cf inverted the behavior to let
-- spectators watch waiting rooms before they fill.

local function test_partialRoom_spectators_allowed()
  logger.info("test_partialRoom_spectators_allowed")
  -- Use players 3-4 for the partial room (matching TeamRoomTests convention)
  -- so we don't clash with the 2-player tests above that use 1-2.
  local p1 = ServerTesting.players[3]
  local p2 = ServerTesting.players[4]
  resetPlayers({ p1, p2 })

  -- Create a 4-player team room with only 2 players (partial)
  local room = Room(1, { p1, p2 }, GameModes.getPreset(GameModes.IDs.FOUR_PLAYER_TEAM_VS_ALL))
  assert(not room:isFull(), "room should be partial (only 2 of 4 players)")

  local spectator = ServerTesting.players[1]
  spectator.state = "lobby"
  spectator.connection.outgoingMessageQueue:clear()

  local success = room:add_spectator(spectator)
  assert(success == true,
    "spectators should be allowed to join partial rooms, got success=" .. tostring(success))
  assert(#room.spectators == 1,
    "room should have 1 spectator after add_spectator, got " .. #room.spectators)
  assert(spectator.state == "spectating",
    "spectator state should be 'spectating', got " .. tostring(spectator.state))

  room:close()
end

----------------------------------------------------------------------
-- Run all tests
----------------------------------------------------------------------

test_broadcastInput_relays_immediately()
test_broadcastGarbageEvent_relay()
test_broadcastDeathEvent_eliminate_and_arbitrate()
test_arbitration_singleDeath_emits_winner()
test_arbitration_doubleDeath_tie()
test_arbitration_window_extends()
test_arbitration_2v2_team_wipe()
test_partialRoom_spectators_allowed()

logger.info("All LooseSyncServerTests passed!")
