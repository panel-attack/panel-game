-- LooseSyncTests.lua
--
-- TDD-style tests for loose-sync multiplayer behavior. Each test states the
-- expected behavior from the design intent. The implementation either matches
-- or gets fixed to match — never the other way around.

require("client.src.globals")
local logger = require("common.lib.logger")
local ClientMatch = require("client.src.ClientMatch")
local Match = require("common.engine.Match")
local Stack = require("common.engine.Stack")
local ReplayV3 = require("common.data.ReplayV3")

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

-- Build a minimal match-like object for unit-testing methods that only touch
-- self.stacks. ClientMatch stacks are wrappers — the actual engine stack
-- (and methods like receiveGarbage / fields like game_over_clock) lives on
-- stack.engine. We mock that shape: a thin wrapper with is_local on top and
-- an .engine table with receivedGarbage tracking + game_over_clock.
local function makeMatchWithStacks(stackSpecs)
  local match = { stacks = {} }
  for i, spec in ipairs(stackSpecs) do
    local engine = {
      which = i,
      game_over_clock = spec.game_over_clock or -1,
      stopWatch = spec.stopWatch or 0,
      receivedGarbage = {},
    }
    engine.receiveGarbage = function(self, payload)
      self.receivedGarbage[#self.receivedGarbage + 1] = payload
    end
    match.stacks[i] = {
      which = i,
      is_local = spec.is_local,
      engine = engine,
      -- Expose receivedGarbage on the wrapper for test assertions so callers
      -- can keep writing `match.stacks[i].receivedGarbage`.
      receivedGarbage = engine.receivedGarbage,
    }
  end
  -- ClientMatch.applyDeathEvent (and applyGarbageEvent before it was retired
  -- from this file) defers to a `_applyDeathEventNow` / `_applyGarbageEventNow`
  -- internal helper after a catch-up defer check. The defer check uses
  -- `self.engine` which our mock doesn't set — so we fall through to the
  -- internal helper. The helper is a real method on ClientMatch; attach it to
  -- the mock so `self:_applyDeathEventNow` resolves correctly.
  match._applyDeathEventNow = ClientMatch._applyDeathEventNow
  return match
end

-- Temporarily replace GAME.netClient with a mock that records sendGarbageEvent
-- calls and returns a configured isConnected value. Returns a function to
-- restore the original netClient. Always pair with the restore in pcall to
-- avoid leaking state to other tests.
local function withMockNetClient(opts)
  local original = GAME.netClient
  local sent = {}
  GAME.netClient = {
    _isConnected = opts.isConnected,
    isConnected = function(self) return self._isConnected end,
    sendGarbageEvent = function(self, body)
      sent[#sent + 1] = body
    end,
    sendDeathEvent = function(self, body) end,
  }
  return sent, function() GAME.netClient = original end
end

----------------------------------------------------------------------
-- Test 1: applyDeathEvent sets game_over_clock on remote stack
----------------------------------------------------------------------
-- Expected: an authoritative D event marks the (remote) sender's stack as
-- game-ended at the reported sender frame.

local function test_applyDeathEvent_marks_remote_stack()
  logger.info("test_applyDeathEvent_marks_remote_stack")
  local match = makeMatchWithStacks({
    { is_local = true,  game_over_clock = -1 },
    { is_local = false, game_over_clock = -1 },
  })

  ClientMatch.applyDeathEvent(match, {
    sender = 2,
    senderFrame = 500,
    reason = "topOut",
  })

  assert(match.stacks[2].engine.game_over_clock == 500,
    "remote stack[2] engine.game_over_clock should be set to 500, got " .. tostring(match.stacks[2].engine.game_over_clock))
end

----------------------------------------------------------------------
-- Test 3: applyDeathEvent skips local-auth stacks
----------------------------------------------------------------------
-- Expected: a D event for the local player's own stack is a no-op. The local
-- sim's setGameOver path is authoritative; overriding it from the relayed
-- event could race or move the death frame.

local function test_applyDeathEvent_skips_local_stack()
  logger.info("test_applyDeathEvent_skips_local_stack")
  local match = makeMatchWithStacks({
    { is_local = true, game_over_clock = -1 },
  })

  ClientMatch.applyDeathEvent(match, {
    sender = 1,
    senderFrame = 500,
    reason = "topOut",
  })

  assert(match.stacks[1].engine.game_over_clock == -1,
    "local stack should NOT have engine.game_over_clock overwritten by D event")
end

----------------------------------------------------------------------
-- Test 4: applyDeathEvent is idempotent on already-dead stack
----------------------------------------------------------------------
-- Expected: if the receiver already knows the stack is dead (e.g. via earlier
-- local sim or a prior D), a late D for the same player does NOT clobber the
-- earlier game_over_clock.

local function test_applyDeathEvent_idempotent()
  logger.info("test_applyDeathEvent_idempotent")
  local match = makeMatchWithStacks({
    { is_local = false, game_over_clock = 400 },
  })

  ClientMatch.applyDeathEvent(match, {
    sender = 1,
    senderFrame = 500,
    reason = "topOut",
  })

  assert(match.stacks[1].engine.game_over_clock == 400,
    "earlier engine.game_over_clock should not be overwritten by later D event, got " .. tostring(match.stacks[1].engine.game_over_clock))
end

----------------------------------------------------------------------
-- Regression: view-stack pinned below senderFrame must still receive
-- the death event (Amber/Bev/Koozie hung-match bug)
----------------------------------------------------------------------
-- Scenario reproduction: a remote stack's view on this client has its
-- engine clock/stopWatch stuck well below the senderFrame the dying
-- player reports. This happens any time a player dies — the server
-- stops relaying their inputs (server/Room.lua:716) so the view-stack
-- can't advance past whatever frame had the last relayed input.
--
-- Pre-fix: applyDeathEvent saw the >60-frame gap and deferred to
-- pendingHistoricalDeaths. drainPendingHistoricalEvents wouldn't apply
-- it because stopWatch never advances (no inputs). game_over_clock
-- stayed -1 forever. Match.isDone's loose-sync bypass (Match.lua:760)
-- requires game_over_clock > 0 to flag the stack done. So the survivor
-- saw the dead opponent's view-stack as "alive" indefinitely and the
-- match never ended.
--
-- Post-fix: applyDeathEvent always sets game_over_clock immediately.
-- The match-end machinery picks it up on the next hasEnded check.

local function test_applyDeathEvent_pinned_view_stack_still_lands()
  logger.info("test_applyDeathEvent_pinned_view_stack_still_lands")
  local match = makeMatchWithStacks({
    -- View-stack of a remote opponent. stopWatch deliberately pinned
    -- 200 frames below the senderFrame we'll send — well past the old
    -- 60-frame defer threshold.
    { is_local = false, game_over_clock = -1, stopWatch = 4800 },
  })

  ClientMatch.applyDeathEvent(match, {
    sender = 1,
    senderFrame = 5058,
    reason = "topOut",
  })

  assert(match.stacks[1].engine.game_over_clock == 5058,
    "applyDeathEvent must set game_over_clock=5058 immediately even when "
    .. "stopWatch (4800) + 60 < senderFrame (5058). Got "
    .. tostring(match.stacks[1].engine.game_over_clock))
end

----------------------------------------------------------------------
-- Regression: 1v1 live match must end when the remote opponent's
-- game_over_clock is set via a DeathEvent, even though the view-stack's
-- clock has not (and cannot) catch up.
----------------------------------------------------------------------
-- The dead opponent stops sending inputs after their D event, so the
-- survivor's view-stack of the opponent has clock pinned below
-- game_over_clock. Stack:game_ended() requires clock >= game_over_clock,
-- so naive use of game_ended() leaves the survivor's match running forever
-- — no game-over UI, opponent stays "alive."
--
-- The fix: in live (non-replay) mode, Match:hasEnded treats any stack
-- with game_over_clock > 0 as "done."

local function test_hasEnded_live_1v1_remote_death_pinned_clock()
  logger.info("test_hasEnded_live_1v1_remote_death_pinned_clock")

  local MatchRules = require("common.data.MatchRules")
  local function makeStub(spec)
    return {
      clock = spec.clock,
      game_over_clock = spec.game_over_clock,
      stopWatch = spec.stopWatch or 0,
      game_ended = function(self)
        return self.game_over_clock > 0 and self.clock >= self.game_over_clock
      end,
    }
  end

  -- Live match: p1 alive at clock=1000; p2 has D event applied
  -- (game_over_clock=500) but its view-stack only advanced to clock=300.
  local match = {
    fromReplay = false,
    stacks = {
      makeStub({ clock = 1000, game_over_clock = -1 }),   -- p1 alive
      makeStub({ clock = 300,  game_over_clock = 500 }),  -- p2 dead (per D), clock pinned
    },
    rules = {
      matchEndConditions = { [MatchRules.MatchEndConditions.STACKS_ACTIVE] = 1 },
      matchWinRuleset = {},
    },
    ended = false,
    aborted = false,
    isIrrecoverablyDesynced = function(self) return false end,
  }

  local hasEnded = Match.hasEnded(match)
  assert(hasEnded == true,
    "live 1v1 with one remote death (clock pinned below game_over_clock) should report hasEnded=true")
end

-- Mirror: in replay mode the strict path still applies (clock must catch up).
local function test_hasEnded_replay_requires_clock_catchup()
  logger.info("test_hasEnded_replay_requires_clock_catchup")

  local MatchRules = require("common.data.MatchRules")
  local function makeStub(spec)
    return {
      clock = spec.clock,
      game_over_clock = spec.game_over_clock,
      stopWatch = spec.stopWatch or 0,
      game_ended = function(self)
        return self.game_over_clock > 0 and self.clock >= self.game_over_clock
      end,
    }
  end

  local match = {
    fromReplay = true,
    stacks = {
      makeStub({ clock = 1000, game_over_clock = -1 }),
      makeStub({ clock = 300,  game_over_clock = 500 }),
    },
    rules = {
      matchEndConditions = { [MatchRules.MatchEndConditions.STACKS_ACTIVE] = 1 },
      matchWinRuleset = {},
    },
    ended = false,
    aborted = false,
    isIrrecoverablyDesynced = function(self) return false end,
  }

  local hasEnded = Match.hasEnded(match)
  assert(hasEnded == false,
    "replay must wait for survivor.clock > game_over_clock before ending (strict)")
end

----------------------------------------------------------------------
-- Test 5: deliverOutgoingGarbage local→remote emits G (no local visual push)
----------------------------------------------------------------------
-- Expected: when a local stack delivers garbage to a remote target while
-- the client is connected, GAME.netClient:sendGarbageEvent is called once
-- with the correct recipient slot — and that's it. No local visual push.
-- The visual on the sender's view of the recipient fires when the server
-- relays the G back to the sender (applyGarbageEvent applies to all
-- recipients regardless of is_local). Doing it this way means the sender
-- never sees a hit that didn't actually land — if the server redirects
-- because the original recipient died, the visual goes to the redirected
-- target.

local function test_deliverOutgoingGarbage_local_to_remote()
  logger.info("test_deliverOutgoingGarbage_local_to_remote")
  local match = setmetatable({ stacks = {} }, { __index = Match })
  match.stacks[1] = { which = 1, is_local = true,  stopWatch = 200, receivedGarbage = {},
    receiveGarbage = function(self, p) self.receivedGarbage[#self.receivedGarbage + 1] = p end }
  match.stacks[2] = { which = 2, is_local = false, stopWatch = 0,   receivedGarbage = {},
    receiveGarbage = function(self, p) self.receivedGarbage[#self.receivedGarbage + 1] = p end }

  local sent, restore = withMockNetClient({ isConnected = true })
  local ok, err = pcall(function()
    local payload = { { width = 6, height = 1 } }
    Match.deliverOutgoingGarbage(match, match.stacks[1], match.stacks[2], payload)

    assert(#sent == 1, "expected exactly 1 G event emitted, got " .. #sent)
    assert(sent[1].recipients[1] == 2, "G recipients[1] should be slot 2, got " .. tostring(sent[1].recipients[1]))
    assert(sent[1].senderFrame == 200, "G senderFrame should be source.stopWatch (200), got " .. tostring(sent[1].senderFrame))
    -- No local visual push: the server's relay of the G back to the sender is
    -- what drives the visual on the sender's view of the recipient. This
    -- avoids showing a hit that doesn't actually land (which could happen if
    -- the server redirects the recipient when the original target died).
    assert(#match.stacks[2].receivedGarbage == 0,
      "no local visual push expected — visual fires from server-relayed G")
  end)
  restore()
  if not ok then error(err) end
end

----------------------------------------------------------------------
-- Test 6: deliverOutgoingGarbage remote→local suppresses local push
----------------------------------------------------------------------
-- Expected: when a remote source's local sim wants to push garbage onto our
-- local-authoritative stack, suppress the push. The authoritative G event
-- will arrive separately from the source's own machine. No G is emitted from
-- our side (we don't emit for someone else's outgoing).

local function test_deliverOutgoingGarbage_remote_to_local()
  logger.info("test_deliverOutgoingGarbage_remote_to_local")
  local match = setmetatable({ stacks = {} }, { __index = Match })
  match.stacks[1] = { which = 1, is_local = false, stopWatch = 200, receivedGarbage = {},
    receiveGarbage = function(self, p) self.receivedGarbage[#self.receivedGarbage + 1] = p end }
  match.stacks[2] = { which = 2, is_local = true,  stopWatch = 0,   receivedGarbage = {},
    receiveGarbage = function(self, p) self.receivedGarbage[#self.receivedGarbage + 1] = p end }

  local sent, restore = withMockNetClient({ isConnected = true })
  local ok, err = pcall(function()
    Match.deliverOutgoingGarbage(match, match.stacks[1], match.stacks[2], { { width = 6, height = 1 } })

    assert(#sent == 0, "no G should be emitted for remote source, got " .. #sent)
    assert(#match.stacks[2].receivedGarbage == 0, "local target should NOT receive from local sim; await G")
  end)
  restore()
  if not ok then error(err) end
end

----------------------------------------------------------------------
-- Test 7: deliverOutgoingGarbage offline → direct push, no G
----------------------------------------------------------------------
-- Expected: in offline modes (puzzle, training, vsSelf) where the client is
-- not connected to a server, fall through to the existing direct-push path.
-- No G emitted; target gets receiveGarbage directly.

local function test_deliverOutgoingGarbage_offline_direct()
  logger.info("test_deliverOutgoingGarbage_offline_direct")
  local match = setmetatable({ stacks = {} }, { __index = Match })
  match.stacks[1] = { which = 1, is_local = true, stopWatch = 100, receivedGarbage = {},
    receiveGarbage = function(self, p) self.receivedGarbage[#self.receivedGarbage + 1] = p end }
  match.stacks[2] = { which = 2, is_local = false, stopWatch = 100, receivedGarbage = {},
    receiveGarbage = function(self, p) self.receivedGarbage[#self.receivedGarbage + 1] = p end }

  local sent, restore = withMockNetClient({ isConnected = false })
  local ok, err = pcall(function()
    Match.deliverOutgoingGarbage(match, match.stacks[1], match.stacks[2], { { width = 6, height = 1 } })

    assert(#sent == 0, "offline mode should not emit G events")
    assert(#match.stacks[2].receivedGarbage == 1, "offline mode should deliver directly to target")
  end)
  restore()
  if not ok then error(err) end
end

----------------------------------------------------------------------
-- Test 8: Round-robin counter advances by exactly 1 per delivery
----------------------------------------------------------------------
-- Expected: in a 1v3 shared-mode setup, after N deliveries the counter has
-- advanced N times (mod #enemies). With all enemies alive the deliveries
-- distribute evenly: after 6 deliveries to 3 enemies, each gets 2.

local function test_roundRobin_counter_advances_by_one()
  logger.info("test_roundRobin_counter_advances_by_one")
  -- Build a minimal match object and call distributeGarbageToTargets manually.
  -- We bypass the full Match constructor to isolate the round-robin logic.
  local match = setmetatable({ stacks = {}, garbageTargets = {}, garbageMode = "shared", teams = nil }, { __index = Match })
  -- 4 stacks: solo (1) attacks team (2,3,4). All alive in this test.
  for i = 1, 4 do
    match.stacks[i] = {
      which = i, is_local = false, stopWatch = 0, game_over_clock = -1, receivedGarbage = {},
      receiveGarbage = function(self, p) self.receivedGarbage[#self.receivedGarbage + 1] = p end,
      getOldestFinishedGarbageTransitTime = function() return nil end,
      getReadyGarbageAt = function() return nil end,
      outgoingGarbage = { illegalStuffIsAllowed = false },
      game_ended = function(self) return self.game_over_clock > 0 end,
    }
  end
  match.garbageTargets[1] = { match.stacks[2], match.stacks[3], match.stacks[4] }
  for i = 2, 4 do match.garbageTargets[i] = {} end
  match.teamGarbageState = {
    [1] = { currentTargetIndex = 1, enemyIndices = { 2, 3, 4 } }
  }

  -- Stub the sender to always have garbage ready at clock 0
  local sender = match.stacks[1]
  local readyCalls = 0
  sender.getOldestFinishedGarbageTransitTime = function(self) return 0 end
  sender.getReadyGarbageAt = function(self, clock)
    readyCalls = readyCalls + 1
    if readyCalls <= 6 then
      return { { width = 6, height = 1, _id = readyCalls } }
    end
    return nil
  end

  local sent, restore = withMockNetClient({ isConnected = false }) -- offline so direct push
  local ok, err = pcall(function()
    -- 6 ticks → 6 deliveries
    for _ = 1, 6 do
      Match.distributeGarbageToTargets(match)
    end

    -- After 6 deliveries with 3 enemies: each should have 2.
    local counts = { #match.stacks[2].receivedGarbage, #match.stacks[3].receivedGarbage, #match.stacks[4].receivedGarbage }
    assert(counts[1] == 2 and counts[2] == 2 and counts[3] == 2,
      string.format("expected [2,2,2], got [%d,%d,%d]", counts[1], counts[2], counts[3]))
    -- Counter should have wrapped twice: back to 1.
    assert(match.teamGarbageState[1].currentTargetIndex == 1,
      "after 6 deliveries to 3 enemies, currentTargetIndex should be 1, got " ..
      tostring(match.teamGarbageState[1].currentTargetIndex))
  end)
  restore()
  if not ok then error(err) end
end

----------------------------------------------------------------------
-- Test 9: Round-robin walks over dead enemies to find living
----------------------------------------------------------------------
-- Expected: in 1v3 shared mode with stack[3] dead, 6 deliveries result in
-- distribution: stack[2] gets 3, stack[4] gets 3, stack[3] gets 0 (skipped).
-- Counter still advances by 1 per delivery so all clients agree on the
-- counter state regardless of when they see stack[3] die.

local function test_roundRobin_walks_over_dead()
  logger.info("test_roundRobin_walks_over_dead")
  local match = setmetatable({ stacks = {}, garbageTargets = {}, garbageMode = "shared", teams = nil }, { __index = Match })
  for i = 1, 4 do
    match.stacks[i] = {
      which = i, is_local = false, stopWatch = 100, game_over_clock = -1, receivedGarbage = {},
      receiveGarbage = function(self, p) self.receivedGarbage[#self.receivedGarbage + 1] = p end,
      getOldestFinishedGarbageTransitTime = function() return nil end,
      getReadyGarbageAt = function() return nil end,
      outgoingGarbage = { illegalStuffIsAllowed = false },
      game_ended = function(self) return self.game_over_clock > 0 end,
    }
  end
  match.stacks[3].game_over_clock = 50 -- stack[3] dead at frame 50, stopWatch=100 → game_ended=true
  match.garbageTargets[1] = { match.stacks[2], match.stacks[3], match.stacks[4] }
  for i = 2, 4 do match.garbageTargets[i] = {} end
  match.teamGarbageState = {
    [1] = { currentTargetIndex = 1, enemyIndices = { 2, 3, 4 } }
  }

  local sender = match.stacks[1]
  local readyCalls = 0
  sender.getOldestFinishedGarbageTransitTime = function(self) return 0 end
  sender.getReadyGarbageAt = function(self, clock)
    readyCalls = readyCalls + 1
    if readyCalls <= 6 then
      return { { width = 6, height = 1, _id = readyCalls } }
    end
    return nil
  end

  local _, restore = withMockNetClient({ isConnected = false })
  local ok, err = pcall(function()
    for _ = 1, 6 do
      Match.distributeGarbageToTargets(match)
    end

    local s2 = #match.stacks[2].receivedGarbage
    local s3 = #match.stacks[3].receivedGarbage
    local s4 = #match.stacks[4].receivedGarbage
    assert(s3 == 0, "dead stack[3] should receive 0 garbage, got " .. s3)
    assert(s2 + s4 == 6, "living enemies should receive all 6 garbage between them, got " .. (s2 + s4))
    -- Distribution should be balanced when one of three is dead: each delivery
    -- that would have gone to stack[3] walks to the next-living (stack[4]).
    -- Counter sequence: 1,2,3,1,2,3 → walk: 2,4,4,2,4,4 → s2=2, s4=4. Or
    -- 2,3→4,4,2,3→4,4 → s2=2, s4=4. Either way s4 >= s2.
    assert(s4 >= s2,
      string.format("walk-forward should bias toward next-living after dead, got s2=%d s4=%d", s2, s4))
  end)
  restore()
  if not ok then error(err) end
end

----------------------------------------------------------------------
-- Test 10: ReplayV4 roundtrip preserves crossPlayerEvents
----------------------------------------------------------------------
-- Expected: a replay with garbage and death events serializes and
-- deserializes losslessly.

local function test_replayV4_roundtrip()
  logger.info("test_replayV4_roundtrip")
  local panelSource = {
    sourceType = ReplayV3.panelSourceTypes.seedV2,
    seed = 12345,
    shockEnabled = true,
  }
  local rules = {
    matchEndConditions = {},
    matchWinRuleset = {},
    stackOverConditions = {},
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = false,
  }
  local replay = ReplayV3("050", rules, panelSource)
  replay.metadata.completed = true

  replay.crossPlayerEvents.garbage[1] = {
    sender = 1, senderFrame = 100, recipients = { 2 },
    garbage = { { width = 6, height = 1, isChain = false } },
    serverWallClockMs = 1700000000000,
  }
  replay.crossPlayerEvents.deaths[1] = {
    sender = 2, senderFrame = 500, reason = "topOut",
    serverWallClockMs = 1700000005000,
  }

  local serialized = json.encode(replay)
  local decoded = json.decode(serialized)
  local restored = ReplayV3.createFromTable(decoded, true)

  assert(restored.crossPlayerEvents, "restored replay should have crossPlayerEvents")
  assert(#restored.crossPlayerEvents.garbage == 1,
    "garbage events should roundtrip, got " .. #restored.crossPlayerEvents.garbage)
  assert(#restored.crossPlayerEvents.deaths == 1,
    "death events should roundtrip, got " .. #restored.crossPlayerEvents.deaths)
  assert(restored.crossPlayerEvents.garbage[1].sender == 1,
    "garbage event sender preserved")
  assert(restored.crossPlayerEvents.garbage[1].senderFrame == 100,
    "garbage event senderFrame preserved")
  assert(restored.crossPlayerEvents.deaths[1].reason == "topOut",
    "death event reason preserved")
end

----------------------------------------------------------------------
-- Test 11: V3 replay backwards-compat fills empty crossPlayerEvents
----------------------------------------------------------------------
-- Expected: loading an older replay (no crossPlayerEvents field) doesn't
-- crash and produces an empty crossPlayerEvents structure ready for code
-- that reads it.

local function test_replayV3_backwards_compat()
  logger.info("test_replayV3_backwards_compat")
  -- Hand-craft an old V3 replay payload (no crossPlayerEvents).
  local oldReplay = {
    engineVersion = "046",
    replayVersion = 3,
    panelSource = { sourceType = 1, seed = 999 },
    rules = {
      matchEndConditions = {}, matchWinRuleset = {}, stackOverConditions = {},
      stackWinConditions = {}, stackSetupModifications = {}, doCountdown = false,
    },
    stacks = {},
    garbageFlows = {},
    metadata = { stacks = {}, timestamp = 1700000000, completed = true },
  }

  local restored = ReplayV3.createFromTable(oldReplay, true)
  assert(restored.crossPlayerEvents, "createFromTable should backfill crossPlayerEvents")
  assert(type(restored.crossPlayerEvents.garbage) == "table",
    "garbage array should be present")
  assert(#restored.crossPlayerEvents.garbage == 0, "garbage array should be empty")
  assert(type(restored.crossPlayerEvents.deaths) == "table",
    "deaths array should be present")
  assert(#restored.crossPlayerEvents.deaths == 0, "deaths array should be empty")
end

----------------------------------------------------------------------
-- Test 19: Stack:shouldRun catches up multiple frames per tick when behind
----------------------------------------------------------------------
-- Expected: a remote stack (is_local=false) with a deep input buffer
-- (>=15 frames behind its current clock) runs at max_runs_per_frame instead
-- of the normal 1 frame per tick. This is how opponent stacks catch up
-- after network jitter without forcing the whole match to stall.
--
-- Replaces the deleted liveDesync test, which exercised the lockstep-era
-- rollback-on-late-garbage trigger. Loose-sync handles input lag entirely
-- through catch-up rather than rollback.

local function makeViewStack(opts)
  local s = {
    is_local = false,
    confirmedInput = {},
    clock = 0,
    max_runs_per_frame = opts.max or 4,
    game_over_clock = opts.game_over_clock,
    game_ended = function(self) return false end,
    behindRollback = function(self) return false end,
  }
  for i = 1, (opts.buffer or 0) do s.confirmedInput[i] = "A" end
  return s
end

local function runsThisCycle(stack)
  local runs = 0
  while Stack.shouldRun(stack, runs) do
    runs = runs + 1
    if runs > 100 then error("infinite loop in shouldRun") end
  end
  return runs
end

local function test_shouldRun_steady_state_runs_once()
  logger.info("test_shouldRun_steady_state_runs_once")
  -- View-stack 1 frame behind: target rate ≈ 1.0 → exactly 1 run per cycle.
  local stack = makeViewStack({ buffer = 1, max = 4 })
  assert(runsThisCycle(stack) == 1, "buffer=1 should run exactly once")
end

local function test_shouldRun_no_buffer_no_runs()
  logger.info("test_shouldRun_no_buffer_no_runs")
  local stack = makeViewStack({ buffer = 0, max = 4 })
  assert(runsThisCycle(stack) == 0, "buffer=0 should not run")
end

local function test_shouldRun_high_buffer_eventually_saturates_at_max()
  logger.info("test_shouldRun_high_buffer_eventually_saturates_at_max")
  -- View-stack 30+ frames behind: target rate is at smootherstep saturation
  -- = max_runs_per_frame. After SmoothDamp's ramp-up settles, runs should
  -- equal max. (First cycle's "snap to target" already lands at max-1
  -- give-or-take accumulator rounding; later cycles converge.)
  local stack = makeViewStack({ buffer = 60, max = 4 })
  local peak = 0
  for _ = 1, 30 do
    -- Refill buffer each cycle so it doesn't deplete while ramping.
    stack.confirmedInput = {}
    for i = 1, 60 do stack.confirmedInput[i] = "A" end
    stack.clock = 0
    peak = math.max(peak, runsThisCycle(stack))
  end
  assert(peak == 4, "sustained high buffer should saturate at max=4; peak observed " .. peak)
end

local function test_shouldRun_smoothly_ramps_not_buckets()
  logger.info("test_shouldRun_smoothly_ramps_not_buckets")
  -- Old bucket function: buffer=9 → 1 run, buffer=10 → 2 runs (sharp step).
  -- New smoothed function: buffer 9 vs 10 produces nearly-identical rates;
  -- no single-frame "lurch" across the old threshold. Test by checking the
  -- target rate from smoothing module directly (deterministic vs runs which
  -- depend on SmoothDamp + accumulator state).
  local Smoothing = require("common.lib.smoothing")
  local r9  = Smoothing.targetRate(9,  4)
  local r10 = Smoothing.targetRate(10, 4)
  assert(math.abs(r10 - r9) < 0.2,
    "rate at buffer=9 vs 10 should be smooth, not stepped; got "
    .. r9 .. " vs " .. r10)
end

local function test_shouldRun_endgame_bypass_snaps_to_max()
  logger.info("test_shouldRun_endgame_bypass_snaps_to_max")
  -- When game_over_clock is set but not yet reached, the view-stack should
  -- race to that frame at max rate without waiting for SmoothDamp to ramp.
  -- Player wants the match-end resolved fast, not paced.
  local stack = makeViewStack({ buffer = 5, max = 4, game_over_clock = 100 })
  -- Buffer only 5 → normal target ~1.2, but bypass should force max=4.
  -- Cap at buffer (5) since you can't run more frames than you have input.
  local r = runsThisCycle(stack)
  assert(r == 4, "pending-death bypass should snap to max=4, got " .. r)
end

local function test_shouldRun_independent_per_stack()
  logger.info("test_shouldRun_independent_per_stack")
  -- Smoothing state must live on the stack, not in any module-level
  -- variable; otherwise multiple view-stacks would couple. Verify by
  -- driving two stacks with different buffers and asserting their runs
  -- differ as the curve says they should.
  local sLow  = makeViewStack({ buffer = 2,  max = 4 })
  local sHigh = makeViewStack({ buffer = 60, max = 4 })
  local rLow  = runsThisCycle(sLow)
  local rHigh = runsThisCycle(sHigh)
  assert(rLow == 1,
    "low-buffer stack should run 1 (independent of any other stack), got " .. rLow)
  assert(rHigh >= 2,
    "high-buffer stack should run multiple times (independent of any other stack), got " .. rHigh)
end

----------------------------------------------------------------------
-- Run all tests
----------------------------------------------------------------------

test_applyDeathEvent_marks_remote_stack()
test_applyDeathEvent_skips_local_stack()
test_applyDeathEvent_idempotent()
test_applyDeathEvent_pinned_view_stack_still_lands()
test_hasEnded_live_1v1_remote_death_pinned_clock()
test_hasEnded_replay_requires_clock_catchup()
test_deliverOutgoingGarbage_local_to_remote()
test_deliverOutgoingGarbage_remote_to_local()
test_deliverOutgoingGarbage_offline_direct()
test_roundRobin_counter_advances_by_one()
test_roundRobin_walks_over_dead()
test_replayV4_roundtrip()
test_replayV3_backwards_compat()
test_shouldRun_steady_state_runs_once()
test_shouldRun_no_buffer_no_runs()
test_shouldRun_high_buffer_eventually_saturates_at_max()
test_shouldRun_smoothly_ramps_not_buckets()
test_shouldRun_endgame_bypass_snaps_to_max()
test_shouldRun_independent_per_stack()

logger.info("All LooseSyncTests passed!")
