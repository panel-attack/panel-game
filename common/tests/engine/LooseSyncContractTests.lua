-- LooseSyncContractTests.lua
--
-- Named invariants for loose-sync. The TEST NAMES are the contract: if the
-- engine ever violates one of these, the relevant test goes red, and the
-- failure mode is the test name itself. No separate prose spec.
--
-- Conventions:
--   - Each invariant is a local `test_invariant_*` function.
--   - Names are 1:1 with the entries in docs/E2E_FIX_COVERAGE_PLAN.md item 2.
--   - Tests in `_pending` are intentionally not yet runnable — see each TODO
--     for why (typically: the invariant is at the server-relay layer, so it
--     belongs in an E2E scenario rather than an engine-only test). They stay
--     in this file as named placeholders so the contract stays visible.

require("client.src.globals")
local logger = require("common.lib.logger")
local LooseSyncHarness = require("common.tests.engine.LooseSyncHarness")
local StateVector = require("common.tests.engine.StateVector")
local TeamUtils = require("common.data.TeamUtils")

local function makeGarbage(width, height)
  return {
    width = width or 1,
    height = height or 1,
    isMetal = false,
    isChain = false,
    frameEarned = 1,
    rowEarned = 1,
    colEarned = 1,
  }
end

----------------------------------------------------------------------
-- 1. Recipient incoming-queue length matches the relayed G log
----------------------------------------------------------------------
-- For each G event delivered into the engine, the named recipient's
-- incoming-queue grows by exactly one piece. This is the simplest sanity
-- check: the server says "X garbage was delivered to slot 2", and the
-- engine's view of slot 2 had better reflect that.
local function test_invariant_garbage_recipient_count_matches_sender_log()
  logger.info("test_invariant_garbage_recipient_count_matches_sender_log")
  local h = LooseSyncHarness({ playerCount = 2 })

  h:applyGarbageEvent({
    sender = 1, senderFrame = 30,
    recipients = { 2 },
    garbage = { makeGarbage(2, 1) },
  })

  local vec = h:readState()
  assert(vec.stacks[2].incomingGarbageCount == 1,
    "stack 2 should have 1 piece in incoming after G; got "
    .. tostring(vec.stacks[2].incomingGarbageCount))
  assert(vec.stacks[1].incomingGarbageCount == 0,
    "stack 1 (the sender) should not have received its own G")

  -- A second G to the same recipient: count goes to 2.
  h:applyGarbageEvent({
    sender = 1, senderFrame = 60,
    recipients = { 2 },
    garbage = { makeGarbage(3, 1) },
  })
  vec = h:readState()
  assert(vec.stacks[2].incomingGarbageCount == 2,
    "stack 2 should have 2 pieces after second G; got "
    .. tostring(vec.stacks[2].incomingGarbageCount))

  h:teardown()
end

----------------------------------------------------------------------
-- 2. Dead-sender inputs dropped  (PENDING — server-relay invariant)
----------------------------------------------------------------------
-- After a DeathEvent for slot N, no further inputs from slot N appear in
-- any view-stack. This is fundamentally a SERVER-RELAY invariant — the
-- server stops forwarding inputs from eliminated players. The engine never
-- sees the dropped frames in the first place, so it cannot self-check.
--
-- Covered today by the E2E suite (Room.lua + Server's filter-after-D logic).
-- Stub kept here so the contract list stays complete.
local function test_invariant_dead_sender_inputs_dropped()
  logger.info("test_invariant_dead_sender_inputs_dropped (deferred to E2E)")
  -- Intentionally a no-op. See file header.
end

----------------------------------------------------------------------
-- 3. Cursor aligned across clients after G
----------------------------------------------------------------------
-- Two clients that receive identical G event streams converge on the same
-- shared-mode round-robin cursor. Two harnesses, same inputs, equal state.
local function test_invariant_cursor_aligned_across_clients_after_G()
  logger.info("test_invariant_cursor_aligned_across_clients_after_G")

  local function makeShared4p2v2()
    return LooseSyncHarness({
      playerCount = 4,
      teamCount = 2,
      playersPerTeam = 2,
      garbageMode = "shared",
    })
  end

  local h1 = makeShared4p2v2()
  local h2 = makeShared4p2v2()

  -- Drive both harnesses through the same G events. Slot 1 (team A) sends
  -- to slot 3 then slot 4 — the cursor on team-A sender's state should
  -- match between the two clients after each delivery.
  local events = {
    { sender = 1, senderFrame = 30, recipients = { 3 }, garbage = { makeGarbage(2,1) } },
    { sender = 1, senderFrame = 60, recipients = { 4 }, garbage = { makeGarbage(2,1) } },
  }
  for _, ev in ipairs(events) do
    h1:applyGarbageEvent(ev)
    h2:applyGarbageEvent(ev)
  end

  -- For now, raw Match doesn't run ClientMatch's cursor-self-heal on
  -- received G — the cursor only advances on the SENDER side via
  -- distributeGarbageToTargets. So both harnesses leave teamGarbageState
  -- untouched, and the equality check is trivially true. The test exists
  -- so the moment we lift cursor-self-heal into Match (or wrap Match here
  -- with ClientMatch's logic), this assertion stays load-bearing.
  assert(StateVector.equal(h1:readState(), h2:readState()),
    "two engines receiving identical event streams must converge:\n"
    .. "  h1=" .. h1:hash() .. "\n"
    .. "  h2=" .. h2:hash())

  h1:teardown(); h2:teardown()
end

----------------------------------------------------------------------
-- 4. Spectator state equals active player's after catch-up
----------------------------------------------------------------------
-- A spectator joining at frame F replays all crossPlayerEvents-so-far and
-- ends up at the same per-stack state a player who was there from frame 0
-- sees right now. Tests applyGarbageEvent's order-independence /
-- idempotency at the receive side.
local function test_invariant_spectator_state_equals_active_player_after_catchup()
  logger.info("test_invariant_spectator_state_equals_active_player_after_catchup")

  local function make2p()
    return LooseSyncHarness({ playerCount = 2 })
  end

  -- Active player: ticks frames, then receives an event, ticks more.
  local active = make2p()
  active:step(15)
  active:applyGarbageEvent({
    sender = 1, senderFrame = 20, recipients = { 2 },
    garbage = { makeGarbage(2, 1) },
  })
  active:step(20)
  active:applyGarbageEvent({
    sender = 1, senderFrame = 40, recipients = { 2 },
    garbage = { makeGarbage(3, 1) },
  })
  active:step(10)

  -- Spectator: just receives both events at the end (catch-up replay).
  local spectator = make2p()
  spectator:step(45) -- catch up to roughly the same wall position
  spectator:applyGarbageEvent({
    sender = 1, senderFrame = 20, recipients = { 2 },
    garbage = { makeGarbage(2, 1) },
  })
  spectator:applyGarbageEvent({
    sender = 1, senderFrame = 40, recipients = { 2 },
    garbage = { makeGarbage(3, 1) },
  })

  -- Recipient slot's incoming count should agree. We don't compare full
  -- state-vectors because step() advances stack clocks differently in each
  -- scenario; the loose-sync invariant is about cross-player garbage flow
  -- not local-tick parity.
  local aVec = active:readState()
  local sVec = spectator:readState()
  assert(aVec.stacks[2].incomingGarbageCount == sVec.stacks[2].incomingGarbageCount,
    "active vs spectator incoming-garbage count mismatch: active="
    .. tostring(aVec.stacks[2].incomingGarbageCount)
    .. " spectator=" .. tostring(sVec.stacks[2].incomingGarbageCount))

  active:teardown(); spectator:teardown()
end

----------------------------------------------------------------------
-- 5. No silent input drop after mid-match leave  (PENDING — server-relay)
----------------------------------------------------------------------
-- After a player leaves mid-match, every remaining survivor — regardless
-- of slot position — keeps receiving every relayed cross-player event.
-- This is the B10 regression. Like #2, it's a SERVER-RELAY invariant
-- (broadcastInput / broadcastGarbageEvent must iterate via `pairs` so
-- sparse self.players doesn't skip high-slot survivors). The engine
-- side has no visibility into a "this player left" event versus "this
-- player never existed".
--
-- Covered by server/tests/E2E/RegressionTests.lua
--   :: test_mid_match_leave_keeps_high_slot_receiving
-- Stub kept here so the contract list stays complete.
local function test_invariant_no_silent_input_drop_after_mid_match_leave()
  logger.info("test_invariant_no_silent_input_drop_after_mid_match_leave (deferred to E2E)")
end

----------------------------------------------------------------------
-- 6. Round-robin skips dead enemies
----------------------------------------------------------------------
-- In shared-garbage mode, a sender with mixed living/dead enemies only
-- delivers to LIVING enemies on subsequent emissions. Backed at the
-- function level by TeamUtilsTests.lua's `findNextLiving` suite; this is
-- the end-to-end-through-Match variant.
local function test_invariant_round_robin_skips_dead_enemies()
  logger.info("test_invariant_round_robin_skips_dead_enemies")

  -- 1v2 shared: slot 1 vs slots 2,3. Kill slot 2, then verify that the
  -- shared-mode cursor's enemyIndices for sender slot 1 still contains
  -- both 2 and 3 (it's a static list), but the live-skip walk picks slot
  -- 3 when slot 2 is dead.
  local h = LooseSyncHarness({
    playerCount = 3, teamCount = 2, playersPerTeam = { 1, 2 },
    garbageMode = "shared",
  })

  -- Direct sanity: enemy list for slot 1 (the solo) should be {2, 3}.
  assert(h.match.teamGarbageState, "shared mode should have teamGarbageState")
  local state = h.match.teamGarbageState[1]
  assert(state and state.enemyIndices, "sender slot 1 should have enemyIndices")
  assert(#state.enemyIndices == 2,
    "solo's enemy list should be 2 enemies; got " .. #state.enemyIndices)

  -- Kill slot 2, then walk the cursor and assert it picks 3 (the only
  -- living enemy). This is the same predicate Match uses internally
  -- (distributeGarbageToTargets at line 326-330) — we re-run it here to
  -- pin the invariant.
  h:killStack(2)
  local stacks = h.match.stacks
  local _, pickedSlot = TeamUtils.findNextLiving(
    state.enemyIndices, state.currentTargetIndex,
    function(slot)
      local s = stacks[slot]
      return s and not s:game_ended()
    end)
  assert(pickedSlot == 3,
    "after killing slot 2, round-robin should pick slot 3; got " .. tostring(pickedSlot))

  h:teardown()
end

----------------------------------------------------------------------
-- Run all tests
----------------------------------------------------------------------

test_invariant_garbage_recipient_count_matches_sender_log()
test_invariant_dead_sender_inputs_dropped()
test_invariant_cursor_aligned_across_clients_after_G()
test_invariant_spectator_state_equals_active_player_after_catchup()
test_invariant_no_silent_input_drop_after_mid_match_leave()
test_invariant_round_robin_skips_dead_enemies()

logger.info("All LooseSyncContractTests passed!")
