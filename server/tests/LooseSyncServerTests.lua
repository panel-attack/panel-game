-- LooseSyncServerTests.lua
--
-- TDD tests for server-side loose-sync behavior: input relay, G/D event
-- relay, replay log recording, and KO arbitration. Each test states the
-- expected behavior; if the impl doesn't match, the impl is wrong.

---@diagnostic disable: undefined-field, invisible, inject-field
-- Load ServerTesting *first* so its module-level singleton players claim the
-- low MockConnection indices (1-6) before our makePlayer calls bump the
-- counter. Otherwise testLogin in ServerTests.lua, which asserts that Bob's
-- connection.index == 1, would see a much higher value depending on test
-- ordering.
require("server.tests.ServerTesting")

local Room = require("server.Room")
local Player = require("server.Player")
local MockConnection = require("server.tests.MockConnection")
local GameModes = require("common.data.GameModes")
local NetworkProtocol = require("common.network.NetworkProtocol")
local socket = require("common.lib.socket")
local json = require("common.lib.dkjson")
local logger = require("common.lib.logger")

COMPRESS_REPLAYS_ENABLED = true

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

-- Make a fresh Player wrapping a fresh MockConnection. Each test gets its own
-- players so module-level singletons (like ServerTesting.players) can't leak
-- state between this file and the rest of the server test suite. In
-- production every connection is a fresh socket, so this mirrors reality.
local function makePlayer(userId, name, publicId)
  local p = Player(userId, MockConnection(), name, publicId)
  p:updateSettings({ inputMethod = "controller", level = 10 })
  p.save_replays_publicly = "not at all"
  p.rating = 1500
  p.placementsDone = true
  return p
end

-- Get a fresh 2-player VS room with a match in progress.
local function get2pMatchInProgress()
  local p1 = makePlayer("ls-1", "LSBob", 1001)
  local p2 = makePlayer("ls-2", "LSAlice", 1002)

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

  -- Relayed to BOTH players, including the sender. The sender needs the
  -- echo so the visual on their view of the recipient only fires after the
  -- server has confirmed (and possibly redirected) the delivery — see
  -- Room:broadcastGarbageEvent's "single source of truth" design.
  local p2GCount = countByPrefix(p2.connection.outgoingInputQueue, "G")
  assert(p2GCount == 1, "P2 should receive 1 G, got " .. p2GCount)
  local p1GCount = countByPrefix(p1.connection.outgoingInputQueue, "G")
  assert(p1GCount == 1, "P1 should also receive their own G (server-confirmed visual), got " .. p1GCount)

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
  local p1 = makePlayer("ls-2v2-1", "LSP1", 2001)
  local p2 = makePlayer("ls-2v2-2", "LSP2", 2002)
  local p3 = makePlayer("ls-2v2-3", "LSP3", 2003)
  local p4 = makePlayer("ls-2v2-4", "LSP4", 2004)

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
-- Test: KO arbitration fires for sequential deaths in separate windows
----------------------------------------------------------------------
-- Regression for the sticky-flag bug from the Amber/Bev/Koozie hung match
-- (and bug #10 generally). Pre-fix: arbitrationEmitted set on the first
-- death's window and never reset, so any subsequent death's window opened
-- but tickArbitration silently returned early at the "already emitted"
-- guard. The match never got its server-authoritative end signal even
-- though every other team was eliminated.

local function test_arbitration_sequentialDeaths_each_window_fires()
  logger.info("test_arbitration_sequentialDeaths_each_window_fires")
  local p1 = makePlayer("ls-seq-1", "LSseq1", 2101)
  local p2 = makePlayer("ls-seq-2", "LSseq2", 2102)
  local p3 = makePlayer("ls-seq-3", "LSseq3", 2103)
  local p4 = makePlayer("ls-seq-4", "LSseq4", 2104)

  local advance, restore = withMockSocketGetTime(5000.0)
  local ok, err = pcall(function()
    local room = Room(1, { p1, p2, p3, p4 }, GameModes.getPreset(GameModes.IDs.FOUR_PLAYER_TEAM_VS_ALL))
    for _, p in ipairs({ p1, p2, p3, p4 }) do
      p:updateSettings({ wants_ready = true, loaded = true, ready = true })
    end
    assert(room.game, "team match should have started")

    for _, p in ipairs({ p1, p2, p3, p4 }) do
      p.connection.outgoingMessageQueue:clear()
      p.connection.outgoingInputQueue:clear()
    end

    -- First death: p1 (team 1) at T=5000.0s. Arbitration window 200ms.
    room:broadcastDeathEvent(p1, json.encode({ senderFrame = 500, reason = "topOut" }))
    advance(0.25) -- past the 200ms window
    room:tickArbitration(math.floor(socket.gettime() * 1000))
    assert(room.arbitrationEmitted, "first arbitration should fire (team 1 has p2 alive)")

    -- One K should be in each player's queue.
    local p3KCountFirst = countByPrefix(p3.connection.outgoingInputQueue, "K")
    assert(p3KCountFirst == 1, "p3 should have 1 K after first death, got " .. p3KCountFirst)

    -- Second death: p2 (also team 1) at T=5005s — 5 seconds later, well past
    -- the first arbitration's window. With team 1 wiped, team 2 should win.
    advance(5.0)
    room:broadcastDeathEvent(p2, json.encode({ senderFrame = 1500, reason = "topOut" }))
    advance(0.25)
    room:tickArbitration(math.floor(socket.gettime() * 1000))

    -- POST-FIX expectation: second arbitration fires too.
    -- Pre-fix: arbitrationEmitted sticky → tickArbitration returns early →
    -- p3 still has only 1 K and the match is unresolved.
    local p3KCountSecond = countByPrefix(p3.connection.outgoingInputQueue, "K")
    assert(p3KCountSecond == 2,
      "second arbitration should fire after a separate-window death; "
      .. "p3 should have 2 K total, got " .. p3KCountSecond
      .. " (sticky-flag bug)")

    -- The 2nd K should declare team 2 (p3 or p4) as winnerSlot.
    local q = p3.connection.outgoingInputQueue
    local lastK
    for i = q.first, q.last do
      local m = q[i]
      if type(m) == "string" and m:sub(1, 1) == "K" then
        local body = m:sub(2)
        local endMarker = body:find("←J←")
        if endMarker then body = body:sub(1, endMarker - 1) end
        lastK = json.decode(body)
      end
    end
    assert(lastK, "p3 must have received the 2nd K")
    assert(lastK.winnerSlot == 3 or lastK.winnerSlot == 4,
      "2nd K should declare team 2 (p3 or p4) as winner, got winnerSlot="
      .. tostring(lastK.winnerSlot))

    room:close()
  end)
  restore()
  if not ok then error(err) end
end

----------------------------------------------------------------------
-- Test 21: Abort marks eliminated but keeps the game alive
----------------------------------------------------------------------
-- Expected: in loose-sync, a single player aborting does NOT immediately end
-- the match — they are marked eliminated server-side and the survivor can
-- continue playing. The match only ends when the survivor also reports an
-- outcome (or aborts themselves).
--
-- This is the explicit "more forgiving to disconnects" design goal. Replaces
-- the deleted abortTest1 in RoomTests, which asserted the OLD strict
-- "abort → immediately end game" semantics.

local function test_abort_marks_eliminated_keeps_game_alive()
  logger.info("test_abort_marks_eliminated_keeps_game_alive")
  local room, p1, p2 = get2pMatchInProgress()

  -- p1 sends a handful of inputs then aborts
  for _ = 1, 30 do
    room:broadcastInput("A", p1)
  end

  room:handleGameAbort(p1)

  assert(room.game ~= nil,
    "after a single player aborts, the room.game should stay alive (more forgiving)")
  assert(room.game.complete == false,
    "game should NOT be complete with only one outcome reported")
  assert(room.game.eliminatedPlayers[1] ~= nil,
    "p1 should be marked eliminated server-side, got " .. tostring(room.game.eliminatedPlayers[1]))
  assert(room.game.eliminatedPlayers[2] == nil,
    "p2 should NOT be marked eliminated — they can continue")

  -- p2 should be free to continue sending inputs; the server keeps relaying them
  -- (the input goes to p1's queue even though p1 has left — harmless, p1 is gone)
  room:broadcastInput("A", p2)
  assert(room.game ~= nil, "game still alive after p2 input post-abort")

  -- Now p2 reports their outcome → game finally ends.
  room:handleGameOverOutcome({outcome = 2}, p2)
  assert(room.game == nil, "game should end once the survivor also reports")

  -- Players should be back at character select for the next match.
  assert(p1.state == "character select" or p1.state == "lobby",
    "p1 should be reset post-match, got " .. tostring(p1.state))
  assert(p2.state == "character select",
    "p2 should be at character select, got " .. tostring(p2.state))
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
  local p1 = makePlayer("ls-spec-1", "LSSpec1", 3001)
  local p2 = makePlayer("ls-spec-2", "LSSpec2", 3002)

  -- Create a 4-player team room with only 2 players (partial)
  local room = Room(1, { p1, p2 }, GameModes.getPreset(GameModes.IDs.FOUR_PLAYER_TEAM_VS_ALL))
  assert(not room:isFull(), "room should be partial (only 2 of 4 players)")

  local spectator = makePlayer("ls-spec-3", "LSSpec3", 3003)
  spectator.state = "lobby"

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
-- Test: mid-match voidByLeave emits incidentDetected → CrashReports flagged
----------------------------------------------------------------------
-- Verifies the wire-up from Room (signal emit in voidByLeave's synth-death
-- branch) through to CrashReports.flagGame. In production this signal is
-- subscribed by the Server in create_room; here we connect a fresh
-- CrashReports directly so the assertion is local.

local CrashReports = require("server.CrashReports")

local function test_voidByLeave_flags_crash_incident()
  logger.info("test_voidByLeave_flags_crash_incident")
  local room, p1, p2 = get2pMatchInProgress()
  local cr = CrashReports()

  room:connectSignal("incidentDetected", cr,
    function(crsub, r, reason) crsub:flagGame(r, reason) end)

  assert(cr:incidentCount() == 0, "no incidents before disconnect")

  room:voidByLeave(p1, "test_disconnect")

  assert(cr:incidentCount() == 1,
    "expected 1 incident after mid-match voidByLeave, got " .. cr:incidentCount())

  -- Inspect the registered incident.
  local incidentId
  for id in pairs(cr.incidents) do incidentId = id end
  local entry = cr:getIncident(incidentId)
  assert(entry.reason == "server_disconnect",
    "expected reason=server_disconnect, got " .. tostring(entry.reason))
  assert(entry.gameKey and entry.gameKey.roomNumber == room.roomNumber,
    "gameKey should carry the room number")
  -- Both players should be in expectedReporters (publicId 1001 + 1002).
  local seen = {}
  for _, pid in ipairs(entry.expectedReporters) do seen[pid] = true end
  assert(seen[1001] and seen[1002],
    "both player publicIds should be in expectedReporters")
end

----------------------------------------------------------------------
-- Test: signal listener failure cannot break voidByLeave
----------------------------------------------------------------------
-- The crash-collection path is auxiliary. If a listener throws, the rest
-- of voidByLeave (synth-death, playerLeftRoom broadcast, etc) must still
-- execute fully. This guards against a future buggy listener taking down
-- live matches.

local function test_voidByLeave_survives_listener_failure()
  logger.info("test_voidByLeave_survives_listener_failure")
  local room, p1, p2 = get2pMatchInProgress()

  -- Attach a listener that throws on every emit.
  room:connectSignal("incidentDetected", {},
    function() error("bad listener") end)

  -- voidByLeave must complete without re-raising.
  local ok, err = pcall(room.voidByLeave, room, p1, "test")
  assert(ok, "voidByLeave should NOT propagate listener errors: " .. tostring(err))

  -- Survivor cleanup still happened: room is voided + game.eliminatedPlayers
  -- got the synth-death for p1.
  assert(room.voided, "room should be voided after disconnect")
  assert(room.game and room.game.eliminatedPlayers[p1.player_number],
    "synth-death must still mark p1 eliminated even when listener throws")
end

----------------------------------------------------------------------
-- Test: server idle-fills inputs for eliminated players
----------------------------------------------------------------------
-- After a player is marked eliminated, server/Room.lua:broadcastInput
-- stops relaying their inputs. Without something replacing them, every
-- other client's view-stack of that player runs out of buffered inputs
-- and freezes at the last received frame ("halfway up, not moving" —
-- the Amber/Bev/Koozie symptom). tickIdleFill emits placeholder no-op
-- inputs at 60Hz for eliminated slots so view-stacks have something to
-- consume and can advance past the death frame.

local function test_idleFill_emits_placeholders_for_eliminated_player()
  logger.info("test_idleFill_emits_placeholders_for_eliminated_player")
  local room, p1, p2 = get2pMatchInProgress()

  -- Mark p2 eliminated at some frame. Bypasses the full broadcastDeathEvent
  -- path so the test stays focused on idle-fill behavior.
  room.game:markPlayerEliminated(p2, 500)

  -- Drain anything in outgoing queues so we only count idle-fill traffic.
  p1.connection.outgoingInputQueue:clear()
  p2.connection.outgoingInputQueue:clear()

  -- Simulate the server clock advancing 100ms. At 60Hz cadence that should
  -- yield approximately 6 idle-fill frames per eliminated slot.
  -- room.idleFillState is empty, so first tick at nowMs=1000 starts the
  -- schedule. Second tick at nowMs=1100 catches up the 100ms gap.
  room:tickIdleFill(1000) -- starts the schedule at nowMs=1000
  room:tickIdleFill(1100) -- 100ms later — should emit ~6 frames

  local count = countByPrefix(p1.connection.outgoingInputQueue,
                              NetworkProtocol.serverMessageTypes.input.prefix)
  assert(count >= 5 and count <= 7,
    "expected ~6 idle-fill inputs in p1's outgoingInputQueue after 100ms, got "
    .. count)
end

local function test_idleFill_skips_when_game_complete()
  logger.info("test_idleFill_skips_when_game_complete")
  local room, p1, p2 = get2pMatchInProgress()
  room.game:markPlayerEliminated(p2, 500)
  room.game.complete = true

  p1.connection.outgoingInputQueue:clear()
  room:tickIdleFill(1000)
  room:tickIdleFill(2000)

  local count = countByPrefix(p1.connection.outgoingInputQueue,
                              NetworkProtocol.serverMessageTypes.input.prefix)
  assert(count == 0,
    "no idle-fill should emit when game.complete is true, got " .. count)
end

local function test_idleFill_state_resets_on_rematch()
  logger.info("test_idleFill_state_resets_on_rematch")
  -- Set up a match-in-progress, eliminate p2, run idle-fill to the cap.
  -- Then start a fresh match in the same room. The new match should see
  -- a clean idleFillState — stale framesEmitted from match 1 must not
  -- carry forward and silently block emits in match 2.
  local room, p1, p2 = get2pMatchInProgress()
  room.game:markPlayerEliminated(p2, 500)
  room:tickIdleFill(1000)
  room:tickIdleFill(11000) -- saturate the cap
  assert(room.idleFillState[p2.player_number]
         and room.idleFillState[p2.player_number].framesEmitted >= 290,
    "precondition: idleFillState should be saturated for p2 after 10s")

  -- Drive a rematch via the canonical start_match path. Clear room.game
  -- first to mimic post-match-end state, then call start_match directly
  -- (avoids the menu-state-update dance, which depends on prior ready
  -- flags surviving the previous match's cleanup).
  room.game = nil
  room:start_match()
  assert(room.game, "rematch should have a fresh game after start_match")

  -- The fix: idleFillState reset at start_match.
  assert(next(room.idleFillState) == nil,
    "idleFillState must reset at start_match — found stale slot(s) in rematch: "
    .. tostring(next(room.idleFillState)))

  -- A fresh elimination in match 2 emits from zero, not blocked by stale cap.
  room.game:markPlayerEliminated(p2, 800)
  p1.connection.outgoingInputQueue:clear()
  room:tickIdleFill(1000)
  room:tickIdleFill(1100)
  local count = countByPrefix(p1.connection.outgoingInputQueue,
                              NetworkProtocol.serverMessageTypes.input.prefix)
  assert(count >= 5 and count <= 7,
    "rematch idle-fill should start fresh and emit ~6 frames over 100ms, got "
    .. count)
end

----------------------------------------------------------------------
-- Silent-death watchdog: rescue stuck matches when a non-eliminated
-- slot stops sending inputs without ever sending a D
----------------------------------------------------------------------
-- Belt-and-suspenders behind the client-side onGameOver immediate-notify
-- fix. If for any reason (legacy client, future regression, network
-- pathology) a slot goes silent without a D event reaching us, the
-- server synthesizes an inferred death so arbitration can proceed
-- and the match can resolve. This rescues the 3p FFA stuck-match
-- failure mode even if the client fix is bypassed.

local function test_silentDeathWatchdog_synthesizes_death_when_slot_silent()
  logger.info("test_silentDeathWatchdog_synthesizes_death_when_slot_silent")
  local room, p1, p2 = get2pMatchInProgress()

  -- p1 went silent at T=1000ms; p2 is still active at T=11500ms.
  room.lastInputMs[p1.player_number] = 1000
  room.lastInputMs[p2.player_number] = 11500

  -- Clear queues so we count only watchdog traffic.
  p2.connection.outgoingInputQueue:clear()

  -- T=12000ms — p1 has been silent for 11s, p2 for 500ms. Watchdog should
  -- synthesize an inferred D for p1 only.
  room:tickSilentDeathWatchdog(12000)

  assert(room.game.eliminatedPlayers[p1.player_number],
    "p1 should be marked eliminated after 11s of silence")
  assert(not room.game.eliminatedPlayers[p2.player_number],
    "p2 should NOT be marked eliminated — still within threshold")
  assert(#room.game.deathEvents == 1,
    "watchdog should have recorded 1 inferred D event, got " .. #room.game.deathEvents)
  assert(room.game.deathEvents[1].inferred == true,
    "synthesized death must be marked inferred=true so the replay can distinguish it")
  assert(room.game.deathEvents[1].reason == "silent",
    "synthesized death reason should be 'silent', got " .. tostring(room.game.deathEvents[1].reason))

  local dCount = countByPrefix(p2.connection.outgoingInputQueue, "D")
  assert(dCount == 1, "p2 should receive 1 D event for p1's inferred death, got " .. dCount)

  room:close()
end

local function test_silentDeathWatchdog_no_op_when_input_recent()
  logger.info("test_silentDeathWatchdog_no_op_when_input_recent")
  local room, p1, p2 = get2pMatchInProgress()

  room.lastInputMs[p1.player_number] = 1000
  room.lastInputMs[p2.player_number] = 1000

  -- Only 5s elapsed — below the 10s threshold. No synth expected.
  room:tickSilentDeathWatchdog(6000)

  assert(not room.game.eliminatedPlayers[p1.player_number],
    "p1 should NOT be marked eliminated within the silence threshold")
  assert(#room.game.deathEvents == 0,
    "watchdog must not synthesize a death within the silence threshold")

  room:close()
end

local function test_silentDeathWatchdog_skips_already_eliminated()
  logger.info("test_silentDeathWatchdog_skips_already_eliminated")
  local room, p1, p2 = get2pMatchInProgress()

  -- p1 already legitimately eliminated. p2 is active (recent input).
  room.game:markPlayerEliminated(p1, 500)
  room.lastInputMs[p1.player_number] = 1000   -- silent but already eliminated
  room.lastInputMs[p2.player_number] = 11500  -- active

  -- Even after 11s of silence, p1 must not re-trigger synthesis.
  room:tickSilentDeathWatchdog(12000)
  assert(#room.game.deathEvents == 0,
    "watchdog must not synth for already-eliminated slot, got " .. #room.game.deathEvents)

  room:close()
end

local function test_silentDeathWatchdog_emits_incidentDetected()
  logger.info("test_silentDeathWatchdog_emits_incidentDetected")
  local room, p1, p2 = get2pMatchInProgress()

  local incidents = {}
  room:connectSignal("incidentDetected", room, function(_, _room, reason)
    incidents[#incidents + 1] = reason
  end)

  room.lastInputMs[p1.player_number] = 1000
  room.lastInputMs[p2.player_number] = 11500  -- p2 active, only p1 silent

  room:tickSilentDeathWatchdog(12000)

  assert(#incidents == 1, "incidentDetected should fire once for the synthesized death, got " .. #incidents)
  assert(incidents[1] == "silent_death",
    "incident reason should be 'silent_death', got " .. tostring(incidents[1]))

  room:close()
end

local function test_silentDeathWatchdog_skips_when_game_complete()
  logger.info("test_silentDeathWatchdog_skips_when_game_complete")
  local room, p1, p2 = get2pMatchInProgress()
  room.lastInputMs[p1.player_number] = 1000
  room.lastInputMs[p2.player_number] = 1000
  room.game.complete = true

  room:tickSilentDeathWatchdog(12000)
  assert(#room.game.deathEvents == 0,
    "watchdog must not synth when game is complete, got " .. #room.game.deathEvents)

  room:close()
end

local function test_silentDeathWatchdog_lastInputMs_seeded_at_start_match()
  logger.info("test_silentDeathWatchdog_lastInputMs_seeded_at_start_match")
  -- A player who never sends any input still must have a baseline timestamp
  -- so the watchdog can compare against it. Without a seed, lastInputMs[slot]
  -- is nil and the watchdog can't fire — but a never-played slot is the most
  -- suspicious one of all (joined, loaded, then ghosted). Seed at start_match.
  local room = get2pMatchInProgress()
  assert(room.lastInputMs, "lastInputMs table should exist after start_match")
  for slot in pairs(room.players) do
    assert(room.lastInputMs[slot],
      "lastInputMs[" .. slot .. "] should be seeded at match start, got " .. tostring(room.lastInputMs[slot]))
  end
end

local function test_silentDeathWatchdog_updated_on_broadcastInput()
  logger.info("test_silentDeathWatchdog_updated_on_broadcastInput")
  local room, p1 = get2pMatchInProgress()

  assert(room.lastInputMs[p1.player_number], "precondition: lastInputMs seeded")

  -- Patch room.clock (captured at construction) to a fixed value, send an input,
  -- expect lastInputMs to land at clock × 1000ms.
  local realClock = room.clock
  room.clock = function() return 2000.0 end
  local ok, err = pcall(function()
    room:broadcastInput("A", p1)
    assert(room.lastInputMs[p1.player_number] == 2000000,
      "lastInputMs[p1] should advance to 2_000_000ms after broadcastInput at clock=2000s, got "
      .. tostring(room.lastInputMs[p1.player_number]))
  end)
  room.clock = realClock
  if not ok then error(err) end

  room:close()
end

local function test_idleFill_caps_at_max_frames()
  logger.info("test_idleFill_caps_at_max_frames")
  local room, p1, p2 = get2pMatchInProgress()
  room.game:markPlayerEliminated(p2, 500)
  p1.connection.outgoingInputQueue:clear()

  -- Advance 10 seconds of wall-clock. At 60Hz that's 600 frames, but the
  -- per-slot cap is 300 — verify the cap holds.
  room:tickIdleFill(1000)
  room:tickIdleFill(11000) -- +10s
  local count = countByPrefix(p1.connection.outgoingInputQueue,
                              NetworkProtocol.serverMessageTypes.input.prefix)
  assert(count <= 301,
    "idle-fill should cap at ~300 frames per slot, got " .. count)
  assert(count >= 290,
    "idle-fill should have approached the cap with 10s elapsed, got " .. count)
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
test_arbitration_sequentialDeaths_each_window_fires()
test_abort_marks_eliminated_keeps_game_alive()
test_partialRoom_spectators_allowed()
test_voidByLeave_flags_crash_incident()
test_voidByLeave_survives_listener_failure()
test_idleFill_emits_placeholders_for_eliminated_player()
test_idleFill_skips_when_game_complete()
test_idleFill_caps_at_max_frames()
test_idleFill_state_resets_on_rematch()
test_silentDeathWatchdog_lastInputMs_seeded_at_start_match()
test_silentDeathWatchdog_updated_on_broadcastInput()
test_silentDeathWatchdog_synthesizes_death_when_slot_silent()
test_silentDeathWatchdog_no_op_when_input_recent()
test_silentDeathWatchdog_skips_already_eliminated()
test_silentDeathWatchdog_emits_incidentDetected()
test_silentDeathWatchdog_skips_when_game_complete()

logger.info("All LooseSyncServerTests passed!")
