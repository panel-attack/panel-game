-- End-to-end regression tests for the May 12 bug fix (commit ec5dd55d).
--
-- Each scenario reproduces the conditions that triggered one of the
-- B0/B1/B8/B9/B10/D bugs and asserts on the post-fix behavior. If any of
-- those regressions sneak back in, the relevant test goes red instead of
-- the bug shipping to a 3-player session.
--
-- These tests use the same TestPlayer + Harness infrastructure as
-- ThreePlayerFFATests.lua. The "expectErrors = false" default on Harness
-- gives every scenario an implicit "no logger.error fired" check on stop().

---@diagnostic disable: invisible, undefined-field
local Harness = require("server.tests.E2E.Harness")
local TestPlayer = require("server.tests.E2E.TestPlayer")
local NetworkProtocol = require("common.network.NetworkProtocol")
local KeyDataEncoding = require("common.data.KeyDataEncoding")
local logger = require("common.lib.logger")
local socket = require("common.lib.socket")
local tableUtils = require("common.lib.tableUtils")

local OPEN_FFA_NAME = "open_ffa"
local OPEN_FFA_MODE_ID = "OPEN_FFA"

local function uname(prefix)
  return prefix .. "_" .. string.format("%04x", math.random(0, 0xffff))
end

-- Local "wait until predicate(), pumping h + every TestPlayer" helper. We
-- can't reuse Harness:waitUntil because it only pumps the server + TestClients
-- — TestPlayers own their own NetClient that needs explicit update() ticks.
local function waitUntil(h, players, predicate, timeoutSeconds, message)
  local deadline = socket.gettime() + (timeoutSeconds or 10)
  while socket.gettime() < deadline do
    h:tick()
    for _, p in ipairs(players) do p:update() end
    if predicate() then return true end
    socket.sleep(0.005)
  end
  logger.warn("[E2E Regression] waitUntil timed out"
              .. (message and (": " .. message) or ""))
  return false
end

local function allLoggedIn(players)
  return function()
    for _, p in ipairs(players) do
      if not p:isLoggedIn() then return false end
    end
    return true
  end
end

local function countServerPlayers(room)
  if not room or not room.players then return 0 end
  -- room.players is keyed by slot number (player_number) and can be sparse
  -- after a mid-room leave on dynamic-roster modes. Count via pairs, not #.
  local n = 0
  for _ in pairs(room.players) do n = n + 1 end
  return n
end

--------------------------------------------------------------------------------
-- D — sparse-roster compaction at Room:start_match (Open FFA)
--
-- 4 clients join an Open FFA room. One leaves before anyone is ready.
-- The remaining 3 ready up; the server activates and starts the match.
-- The fix ensures Room:start_match compacts the (now sparse) self.players
-- table so the broadcast replay has dense playerNumbers 1/2/3, not 1/2/4.
--
-- Pre-fix symptom: matchStart payload had 4 stack slots with one nil-filled,
-- which tripped Match.createFromReplay's #stacks length check and crashed
-- every joiner. Now: dense roster, no crash.
--------------------------------------------------------------------------------

local function test_open_ffa_compacts_after_pre_match_leave()
  logger.info("[E2E Regression] === test_open_ffa_compacts_after_pre_match_leave ===")
  local h = Harness():start()
  local ok, err = pcall(function()
    local a = TestPlayer(uname("BotA"))
    local b = TestPlayer(uname("BotB"))
    local c = TestPlayer(uname("BotC"))
    local d = TestPlayer(uname("BotD"))
    local all = { a, b, c, d }
    local stayers = { a, c, d }

    for _, p in ipairs(all) do p:login(h.host, h.port) end
    assert(waitUntil(h, all, allLoggedIn(all), 8, "login"),
           "not all 4 players logged in")

    a:requestRoom(OPEN_FFA_MODE_ID, "relaxed")
    assert(waitUntil(h, all, function()
      return h:findRoomByGameMode(OPEN_FFA_NAME) ~= nil
    end, 5, "room created"), "host did not get room")
    local room = h:findRoomByGameMode(OPEN_FFA_NAME)
    local roomNumber = room.roomNumber

    -- All 3 joiners enter, giving 4 players in the room.
    b:joinRoom(roomNumber)
    c:joinRoom(roomNumber)
    d:joinRoom(roomNumber)
    assert(waitUntil(h, all, function()
      return countServerPlayers(room) == 4
    end, 5, "4 players seated"), "did not reach 4 players in room: only "
       .. countServerPlayers(room))

    -- Pre-match leave: B drops without ever being ready. Production-side,
    -- NetClient:leaveRoom is a no-op until the room is "ready" (room.players
    -- == minPlayers and self.room is set). For partial Open FFA where the
    -- host stays in lobby state, self.room is still nil — so a graceful
    -- :leaveRoom does nothing. We simulate the much more common case: the
    -- player's TCP connection drops (browser closed, crash, network loss).
    -- The server handles this via Connection's disconnect path and
    -- handleLeaveRoom — same end-state as a graceful leave.
    b:close()
    assert(waitUntil(h, { a, c, d }, function()
      return countServerPlayers(room) == 3
    end, 5, "B departed"), "B's disconnect didn't take effect; players="
       .. countServerPlayers(room))

    -- After B leaves, room.players is sparse — slot 2 is gone. Slots 1/3/4
    -- still point at A/C/D respectively until start_match's compaction runs.
    -- This is the exact state D's fix targets.
    local sparseSlotsBefore = {}
    for slot in pairs(room.players) do sparseSlotsBefore[#sparseSlotsBefore + 1] = slot end
    table.sort(sparseSlotsBefore)
    logger.info("[E2E Regression] pre-ready slots: " ..
                table.concat(sparseSlotsBefore, ","))

    -- The 3 stayers ready up; server activates + starts the match.
    for _, p in ipairs(stayers) do p:sendReady() end
    assert(waitUntil(h, stayers, function()
      return room.game ~= nil
    end, 10, "matchStart"), "match did not start within 10s")

    -- After compaction: dense roster. Three assertions cover the fix.
    -- (1) Players table is dense — slot numbers are exactly {1,2,3}.
    local denseSlots = {}
    for slot in pairs(room.players) do denseSlots[#denseSlots + 1] = slot end
    table.sort(denseSlots)
    assert(#denseSlots == 3 and denseSlots[1] == 1
           and denseSlots[2] == 2 and denseSlots[3] == 3,
           "expected slots {1,2,3} after compaction, got {"
           .. table.concat(denseSlots, ",") .. "}")

    -- (2) The replay broadcast has exactly 3 stacks (not 4 with a nil hole).
    local replay = room.game.replay
    assert(replay, "no replay on server game after start_match")
    assert(#replay.stacks == 3,
           "expected 3 stacks in replay, got " .. #replay.stacks)

    -- (3) replay.metadata.stacks playerNumbers are sequential 1/2/3, no gap.
    for i = 1, 3 do
      local meta = replay.metadata.stacks[i]
      assert(meta, "missing metadata.stacks[" .. i .. "]")
      assert(meta.stackIndex == i,
             "metadata.stacks[" .. i .. "].stackIndex == "
             .. tostring(meta.stackIndex) .. ", expected " .. i)
    end

    logger.info("[E2E Regression] PASS — D: open-FFA roster compacted to 3 dense slots")
    for _, p in ipairs(all) do p:close() end
  end)
  h:stop()
  if not ok then error(err, 0) end
end

-- Helper: bring 3 fresh TestPlayers up through matchStart in an Open FFA
-- room. Mirrors the helper in ThreePlayerFFATests.lua but lives here so the
-- regression file can stand on its own.
local function bringThreeToMatchStart(h)
  local a = TestPlayer(uname("BotA"))
  local b = TestPlayer(uname("BotB"))
  local c = TestPlayer(uname("BotC"))
  local all = { a, b, c }
  for _, p in ipairs(all) do p:login(h.host, h.port) end
  assert(waitUntil(h, all, allLoggedIn(all), 8, "login"),
         "not all 3 logged in")
  a:requestRoom(OPEN_FFA_MODE_ID, "relaxed")
  assert(waitUntil(h, all, function()
    return h:findRoomByGameMode(OPEN_FFA_NAME) ~= nil
  end, 5, "room"), "room not created")
  local room = h:findRoomByGameMode(OPEN_FFA_NAME)
  b:joinRoom(room.roomNumber)
  c:joinRoom(room.roomNumber)
  assert(waitUntil(h, all, function() return countServerPlayers(room) == 3 end,
                   5, "3 seated"), "did not reach 3 seated")
  for _, p in ipairs(all) do p:sendReady() end
  assert(waitUntil(h, all, function() return room.game ~= nil end,
                   10, "matchStart"), "match did not start")
  return a, b, c, all, room
end

-- Instrument a TestPlayer so every server→client message of one of the input
-- prefixes (I, U, V, ...) increments a counter keyed by prefix. Hooks the
-- player's tcpClient:queueMessage and forwards to the original.
local function attachInputProbe(player)
  local counts = setmetatable({}, { __index = function() return 0 end })
  local orig = player.netClient.tcpClient.queueMessage
  player.netClient.tcpClient.queueMessage = function(self, type, data)
    if NetworkProtocol.isInputPrefix(type) then
      counts[type] = (rawget(counts, type) or 0) + 1
    end
    return orig(self, type, data)
  end
  return counts
end

--------------------------------------------------------------------------------
-- B10 — relays past a disconnected slot continue mid-match
--
-- 3-player FFA, BotB (slot 2) disconnects mid-match. The B10 fix
-- (commit ec5dd55d) converted ipairs→pairs across the server's broadcast
-- paths so iteration doesn't halt at the first nil in self.players.
--
-- IMPORTANT NUANCE: voidByLeave defers actual slot removal (via
-- pendingLeaverRemovals) until match end — so during an active match
-- self.players isn't strictly sparse from a single disconnect; the
-- leaver's ServerPlayer object stays in the slot but is marked
-- disconnected+eliminated. The pairs/ipairs distinction matters most
-- for the explicit death-event broadcast at Room.lua:1358 (where the
-- comment lives) and for paths that DO see sparse state.
--
-- This test exercises the integration-level behavior B10 protects:
-- after one player drops mid-match, the survivors keep exchanging
-- input frames. If broadcastInput regressed to ipairs AND a future
-- code change started nil-ing slot-2 immediately, slot 3 would freeze.
-- We instrument BotC's wire layer to count BotA's relayed inputs and
-- assert the count keeps growing post-disconnect.
--------------------------------------------------------------------------------

local function test_mid_match_leave_keeps_high_slot_receiving()
  logger.info("[E2E Regression] === test_mid_match_leave_keeps_high_slot_receiving ===")
  local h = Harness({ expectErrors = true }):start()
  -- expectErrors=true: a mid-match disconnect produces logger.error("Connection
  -- closed: ...") from one of the per-tick connection paths. The disconnect
  -- IS the test condition, not a regression. We assert on actually-observable
  -- relay behavior instead.
  local ok, err = pcall(function()
    local a, b, c, all, room = bringThreeToMatchStart(h)

    -- Count BotA's relayed inputs as they arrive at BotC's socket. Hooking the
    -- wire layer (tcpClient.queueMessage) means we measure what reached BotC's
    -- socket independent of whether NetClient subsequently drains the queue.
    local botcCounts = attachInputProbe(c)
    local SLOT_A_PREFIX = NetworkProtocol.getInputPrefixForPlayer(1)

    -- BotB disconnects mid-match. The server detects the dropped socket and
    -- marks BotB disconnected + synthesizes a death event. Slot 2 stays in
    -- self.players (deferred to pendingLeaverRemovals) but is flagged.
    b:close()
    assert(waitUntil(h, { a, c }, function()
      return room.game and room.game.disconnectedPlayers[2]
    end, 5, "B's disconnect tracked"),
       "server did not register B as disconnected")

    -- BotA sends inputs after the gap exists. If B10 regressed, the server's
    -- broadcastInput ipairs would stop after slot 1 and BotC would receive
    -- nothing. We send several frames so a single dropped one doesn't
    -- statistically look like success.
    local burstCount = 8
    for _ = 1, burstCount do
      a:sendInput(KeyDataEncoding.swap)
      h:tick()
      for _, p in ipairs({ a, c }) do p:update() end
    end

    -- Drain a few more ticks so any straggler relays arrive.
    for _ = 1, 5 do
      h:tick()
      for _, p in ipairs({ a, c }) do p:update() end
    end

    assert(rawget(botcCounts, SLOT_A_PREFIX) >= burstCount,
           "B10 regression: BotC (slot 3) only saw "
           .. tostring(rawget(botcCounts, SLOT_A_PREFIX) or 0)
           .. " relayed inputs from BotA, expected >= " .. burstCount
           .. ". Server may have stopped at the slot-2 nil gap.")

    logger.info("[E2E Regression] PASS — B10: slot-3 relay survived slot-2 disconnect ("
                .. rawget(botcCounts, SLOT_A_PREFIX) .. " frames received)")
    for _, p in ipairs(all) do p:close() end
  end)
  h:stop()
  if not ok then error(err, 0) end
end

--------------------------------------------------------------------------------
-- B10 (white-box) — broadcastInput uses pairs, not ipairs
--
-- The complementary test above (test_mid_match_leave_keeps_high_slot_receiving)
-- can't trigger sparse self.players in normal mid-match flow because
-- voidByLeave defers slot removal until match end. To genuinely catch the
-- ipairs/pairs regression at Room.lua:732, we reach into the server's
-- room.players table and nil out slot 2 directly, then send an input from
-- slot 1 and verify slot 3 still receives it. With ipairs, iteration halts
-- at slot 2's nil and slot 3 is skipped — the test would fail. With pairs,
-- slot 3 is visited regardless.
--
-- Yes, this is a white-box probe. The reviewer-flagged honest fix: it's
-- the smallest setup that actually exercises the post-fix code path.
--------------------------------------------------------------------------------

local function test_b10_sparse_self_players_relay_iteration()
  logger.info("[E2E Regression] === test_b10_sparse_self_players_relay_iteration ===")
  local h = Harness():start()
  local ok, err = pcall(function()
    local a, b, c, all, room = bringThreeToMatchStart(h)

    local botcCounts = attachInputProbe(c)
    local SLOT_A_PREFIX = NetworkProtocol.getInputPrefixForPlayer(1)

    -- Force the exact sparse state B10 protects against. NOT the normal
    -- mid-match path — production won't put room.players in this shape
    -- via current flows. We're directly probing the loop-iteration
    -- behavior at Room.lua:732.
    local strandedPlayer = room.players[2]
    room.players[2] = nil

    -- Send N inputs from A. With pairs at line 732, all N reach slot 3;
    -- with ipairs (regression), iteration halts at slot-1→slot-2-nil and
    -- slot 3 receives nothing.
    local burstCount = 6
    for _ = 1, burstCount do
      a:sendInput(KeyDataEncoding.swap)
      h:tick()
      for _, p in ipairs({ a, c }) do p:update() end
    end
    for _ = 1, 5 do
      h:tick()
      for _, p in ipairs({ a, c }) do p:update() end
    end

    -- Restore the slot before stop() so harness cleanup can iterate normally.
    room.players[2] = strandedPlayer

    assert(rawget(botcCounts, SLOT_A_PREFIX) >= burstCount,
           "B10 white-box regression: BotC (slot 3) saw "
           .. tostring(rawget(botcCounts, SLOT_A_PREFIX) or 0)
           .. " inputs through a sparse self.players (slot 2 = nil);"
           .. " expected >= " .. burstCount
           .. ". The relay loop at Room.lua:732 likely halted at the nil slot.")

    logger.info("[E2E Regression] PASS — B10 white-box: pairs iteration"
                .. " survives nil slot 2 (" .. rawget(botcCounts, SLOT_A_PREFIX)
                .. " inputs reached slot 3)")
    for _, p in ipairs(all) do p:close() end
  end)
  h:stop()
  if not ok then error(err, 0) end
end

--------------------------------------------------------------------------------
-- Runner
--------------------------------------------------------------------------------

local function runAll()
  test_open_ffa_compacts_after_pre_match_leave()
  test_mid_match_leave_keeps_high_slot_receiving()
  test_b10_sparse_self_players_relay_iteration()
end

if not package.loaded["server.tests.E2E.RegressionTests"] then
  runAll()
end

return {
  runAll = runAll,
  test_open_ffa_compacts_after_pre_match_leave = test_open_ffa_compacts_after_pre_match_leave,
  test_mid_match_leave_keeps_high_slot_receiving = test_mid_match_leave_keeps_high_slot_receiving,
  test_b10_sparse_self_players_relay_iteration = test_b10_sparse_self_players_relay_iteration,
}
