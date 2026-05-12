# Loose-Sync Rollout Steps

Companion to `LOOSE_SYNC_PLAN.md`. The design doc explains *what* and *why*; this file is the actionable step-by-step with concrete checklists.

## At a glance

| Step | What | Files | Difficulty | Risk | Effort |
|------|------|-------|-----------|------|--------|
| 1 | Remove client lockstep stall | PlayerStack.lua | trivial | none | 10m |
| 2 | Server relays inputs immediately | Room.lua, Game.lua, server.lua | mechanical | moderate | 1–2h |
| 3 | Disable desync aborts | Match.lua, Room.lua | trivial | low | 15m |
| 4 | Remove rollback-on-late-garbage | Match.lua | trivial | low | 15m |
| **PR1** | **Lockstep gate gone** | | | | **~3–4h** |
| 5 | Register G/D/K message types | NetworkProtocol.lua | trivial | none | 30m |
| 6 | Wire G/D send/receive plumbing | 6 files | mechanical | low | 2–3h |
| 7 | Garbage → G events | Match.lua, ClientMatch.lua, PlayerStack.lua | intertwined | **high** | 3–4h |
| 8 | Death → D events | PlayerStack.lua, ClientMatch.lua | mechanical | low | 1–2h |
| **PR2** | **Explicit cross-player events** | | | | **~6–9h** |
| 9a | KO arbitration window | Room.lua, ClientMatch.lua | mechanical | moderate | 1.5–2h |
| 9b | Adaptive telegraph timing | ClientMatch.lua | mechanical | low | 1–1.5h |
| 10 | ReplayV4 + migration | new file + 2 edits | mechanical | low | 2–3h |
| **PR3** | **Arbitration + replays** | | | | **~5–7h** |
| **Total** | | | | | **~15–20h** |

## Recommended ordering

- **Today:** Step 1 (warm-up, 10 min).
- **PR 1 (Steps 1–4):** the high-leverage chunk that delivers "no more stalls." Stop and play after this; might be Good Enough for casual.
- **PR 2 (Steps 5–8):** the architectural surgery — switches garbage and death from implicit-sim to explicit events. Step 7 is the riskiest single piece of work in the whole plan.
- **PR 3 (Steps 9–10):** polish — tie-breaking, adaptive telegraph, replay format.

---

## Step 1 — Remove the client lockstep stall

**Files:** `client/src/network/PlayerStack.lua`
**Effort:** 10 minutes · **Difficulty:** trivial · **Risk:** none

The `garbageTarget.engine.confirmedInput == 0` early-return at lines 42–49 only fires on the very first frame of the match. Pure cleanup.

- [ ] Delete `client/src/network/PlayerStack.lua` lines 42–49 (the `garbageTarget.engine.confirmedInput == 0` block)
- [ ] Run `zsh run_tests.sh` — confirm nothing breaks
- [ ] Start server + 2 clients, play a match; confirm first-frame behavior is unchanged
- [ ] Commit

---

## Step 2 — Server relays inputs immediately

**Files:** `server/Room.lua`, `server/Game.lua`, `server/server.lua`
**Effort:** 1–2 hours · **Difficulty:** mechanical · **Risk:** moderate (clock drift exposes Steps 3–4)

This is the headline change — removes the lockstep gate. After this, slow players no longer hold up the room.

- [ ] Rewrite `Room:broadcastInput` (`server/Room.lua:402-418`):
  - [ ] Inline the marshalling currently in `flushBufferedInputs` (slot-prefix per sender, broadcast to non-sender players + spectators)
  - [ ] Append input to `self.game.inputs[sender.player_number]` for the replay record
  - [ ] Remove the `self.game:bufferInput(sender, input)` call
- [ ] Delete `Room:flushBufferedInputs` entirely (`server/Room.lua:421-455`)
- [ ] Delete the `flushBufferedInputsForAllRooms()` call at `server/server.lua:891`
- [ ] Delete the `flushBufferedInputsForAllRooms` function definition (`server/server.lua:1044-1051`)
- [ ] Delete the lockstep buffer machinery in `server/Game.lua:172-244`:
  - [ ] `bufferInput`
  - [ ] `canFlushNextFrame`
  - [ ] `getIdleInputForPlayer`
  - [ ] `getNextFrameInputs`
  - [ ] `flushNextFrame`
- [ ] Remove `self.inputBuffer = {}` and `self.currentFrameNumber` from the `Game` constructor
- [ ] Remove `self.inputBuffer[player.player_number] = nil` from `markPlayerDisconnected` (`server/Game.lua:303-309`)
- [ ] Remove `self.inputBuffer[player.player_number] = nil` from `markPlayerEliminated` (`server/Game.lua:315-320`)
- [ ] Update `server/tests/ServerTests.lua` and `server/tests/ServerTesting.lua` — remove any references to deleted functions
- [ ] Run `zsh run_server.sh` — server tests pass on startup
- [ ] Manual test: 2 clients, normal latency — confirm match still plays
- [ ] Manual test: apply 200–400ms artificial delay on one client via `TcpClient:activateDelayedProcessing()` — confirm game continues without stalling, opponent's board view catches up after the lag spike
- [ ] Commit

---

## Step 3 — Disable desync aborts

**Files:** `common/engine/Match.lua`, `server/Room.lua`, optionally `server/server.lua`
**Effort:** 15 minutes · **Difficulty:** trivial · **Risk:** low

With Step 2 in place, clock divergence between players is expected. The safety brakes designed for lockstep need to be off so they don't fire spuriously.

- [ ] In `Match:isIrrecoverablyDesynced` (`common/engine/Match.lua:706-719`): downgrade the `source.clock + MAX_LAG < target.clock` branch — change `return true` to `logger.warn(...)` and continue
- [ ] In `Room:handleGameAbort` (`server/Room.lua:~595`): remove the `inputCountDifference > self.abortInputGapThreshold` check (keep any other abort logic untouched)
- [ ] Optional: delete `Server:resolveAbortInputGapThreshold` (`server/server.lua:59-83`)
- [ ] Optional: remove the `latencyTolerance` / `abortInputGapThreshold` propagation in room request (`server/server.lua:1102-1127`) — or leave it accepting the field as a no-op for back-compat
- [ ] Run server tests
- [ ] Manual test: push artificial delay to 500–1500ms — confirm no abort fires, match continues
- [ ] Commit (or batch into a single Step 2–4 commit)

---

## Step 4 — Remove rollback-on-late-garbage

**Files:** `common/engine/Match.lua`
**Effort:** 15 minutes · **Difficulty:** trivial · **Risk:** low

The remaining lockstep-era safeguard. With Step 3 in place, it can't fire usefully and is just a footgun.

- [ ] In `Match:pushGarbageTo` (`common/engine/Match.lua:389-398`): delete the `if stack.stopWatch > oldestTransitTime then ... rollbackToStopWatch ...` block including the `desyncError = true; self:abort()` fallback
- [ ] Keep the `stack:receiveGarbage(garbageDelivery)` call on the line below (~line 403)
- [ ] Note: the `Stack:saveForRollback` / `Stack:rollbackToFrame` machinery itself stays — still used for opponent-stack catch-up
- [ ] Run tests
- [ ] Manual test: play a match with one slow client, confirm garbage still delivers correctly (the implicit-sim path absorbs reasonable drift via the existing MAX_LAG buffer of ~320 frames)
- [ ] Commit

### ★ PR 1 ships here ★

Self-consistent intermediate state: no more stalls, no more lag-induced aborts. Garbage and death still ride the implicit-sim path; they work as long as clocks stay inside the rollback buffer (~5 seconds of drift tolerance).

---

## Step 5 — Register G/D/K message types

**Files:** `common/network/NetworkProtocol.lua`
**Effort:** 30 minutes · **Difficulty:** trivial · **Risk:** none

Metadata only — registers new wire prefixes so subsequent protocol work is unblocked.

- [ ] In `common/network/NetworkProtocol.lua`:
  - [ ] Add `G` to `clientMessageTypes` (client → server: GarbageEvent)
  - [ ] Add `G` to `serverMessageTypes` (server → client: GarbageEvent relay) with `verbose = true` for log readability
  - [ ] Add `D` to `clientMessageTypes` (client → server: DeathEvent)
  - [ ] Add `D` to `serverMessageTypes` (server → client: DeathEvent relay)
  - [ ] Add `K` to `serverMessageTypes` (server → client only: KOArbitration)
- [ ] Verify `serverPrefixToMessageType` and `clientPrefixToMessageType` populate the new entries (these tables are built by iteration — should happen automatically)
- [ ] Add coverage in `tests/NetworkProtocolTests.lua` for G/D/K prefix round-trip via `markedMessageForTypeAndBody`
- [ ] Run `zsh run_tests.sh`
- [ ] Commit

---

## Step 6 — Wire G/D send/receive plumbing

**Files:** `common/network/ClientProtocol.lua`, `common/network/ServerProtocol.lua`, `client/src/network/NetClient.lua`, `server/server.lua` (or `server/Connection.lua`), `server/Room.lua`, `server/Game.lua`, `client/src/ClientMatch.lua`
**Effort:** 2–3 hours · **Difficulty:** mechanical · **Risk:** low

End-to-end scaffold for the new event types. Nothing in gameplay generates them yet — they're dead code until Step 7.

- [ ] In `common/network/ClientProtocol.lua`:
  - [ ] Add `ClientProtocol.sendGarbageEvent(body)` using `markedMessageForTypeAndBody` with `G` prefix
  - [ ] Add `ClientProtocol.sendDeathEvent(body)` using `markedMessageForTypeAndBody` with `D` prefix
- [ ] In `common/network/ServerProtocol.lua`:
  - [ ] Add `ServerProtocol.koArbitration(arbitration)` using `markedMessageForTypeAndBody` with `K` prefix
- [ ] In `client/src/network/NetClient.lua`:
  - [ ] Add `NetClient:sendGarbageEvent(body)` mirroring `sendInput`
  - [ ] Add `NetClient:sendDeathEvent(body)` mirroring `sendInput`
  - [ ] Add `NetClient:processGarbageEvents()` mirroring `processInputMessages` — pop `G`, forward to `ClientMatch:applyGarbageEvent`
  - [ ] Add `NetClient:processDeathEvents()` — pop `D`, forward to `ClientMatch:applyDeathEvent`
  - [ ] Handle inbound `K` messages — forward to `ClientMatch:applyKOArbitration`
  - [ ] Call all three process methods from the update tick alongside `processInputMessages`
- [ ] Server-side dispatch (likely in `server/Connection.lua` or `server/server.lua` `processMessage`):
  - [ ] Add `G` route → `Room:broadcastGarbageEvent`
  - [ ] Add `D` route → `Room:broadcastDeathEvent`
- [ ] In `server/Room.lua`:
  - [ ] Add `Room:broadcastGarbageEvent(sender, body)`:
    - [ ] Stamp `serverWallClockMs` on the body
    - [ ] Call `self.game:recordGarbageEvent(sender, body)`
    - [ ] Relay to every other player + every spectator
  - [ ] Add `Room:broadcastDeathEvent(sender, body)`:
    - [ ] Stamp `serverWallClockMs`
    - [ ] Call `self.game:recordDeathEvent(sender, body)`
    - [ ] Relay to others + spectators
    - [ ] (KO arbitration trigger deferred to Step 9a)
- [ ] In `server/Game.lua`:
  - [ ] Add `self.garbageEvents = {}` and `self.deathEvents = {}` to constructor
  - [ ] Add `Game:recordGarbageEvent(senderPlayer, body)` — append `{senderSlot, senderFrame, serverArrivalMs, payload}`
  - [ ] Add `Game:recordDeathEvent(senderPlayer, body)` — same
- [ ] In `client/src/ClientMatch.lua`: add stub methods that just log
  - [ ] `ClientMatch:applyGarbageEvent(body)` — log only
  - [ ] `ClientMatch:applyDeathEvent(body)` — log only
  - [ ] `ClientMatch:applyKOArbitration(body)` — log only
- [ ] Add coverage in `server/tests/ServerTests.lua` for G/D relay (sender → server → other clients + spectators)
- [ ] Manual: from dev console, fire a `G` event from client A, confirm it appears in client B's logs
- [ ] Commit

---

## Step 7 — Garbage → G events

**Files:** `common/engine/Match.lua`, `client/src/PlayerStack.lua` (or `ClientStack.lua`), `client/src/ClientMatch.lua`
**Effort:** 3–4 hours · **Difficulty:** intertwined · **Risk:** HIGH

The riskiest single piece of work. Flips the garbage-delivery path from "both clients derive it from synchronized sim" to "sender's client emits an authoritative event."

- [ ] Add `Stack:enqueueRemoteGarbage(garbage, landingFrame)` to `client/src/PlayerStack.lua` (or `ClientStack.lua` if more appropriate):
  - [ ] Inserts directly into `incomingGarbage.garbageInTransit[landingFrame]`
  - [ ] If a bucket already exists at that frame, append to it
  - [ ] Bypass the `outgoingGarbage` / transit-staging machinery entirely
- [ ] Add a feature flag (`LOOSE_SYNC_GARBAGE = true` in `client/src/globals.lua` or a new constants file) so the old path can be re-enabled for A/B testing
- [ ] In `Match:distributeGarbageToTargets` (`common/engine/Match.lua:301-376`):
  - [ ] For each target, check `target.is_local`
  - [ ] If remote: emit `G` event via `GAME.netClient:sendGarbageEvent({sender, senderFrame, recipients, garbage})` and **skip** the `target:receiveGarbage(garbageCopy)` call
  - [ ] If local (vsSelf, puzzle, training, AI): keep the existing `target:receiveGarbage(garbageCopy)` call
  - [ ] Preserve round-robin/shared garbage-mode logic for local-only multi-target cases
- [ ] In `Match:pushGarbageTo` (`common/engine/Match.lua:378-408`): same remote/local split
- [ ] Fill in `ClientMatch:applyGarbageEvent(body)`:
  - [ ] For each recipient slot in `body.recipients`, locate the stack
  - [ ] Compute landing frame: `self.stacks[recipient].clock + GARBAGE_DELAY_LAND_TIME` (60 frames — adaptive timing comes in Step 9b)
  - [ ] Call `stack:enqueueRemoteGarbage(body.garbage, landingFrame)`
- [ ] Test local-only modes first (no `G` events should fire):
  - [ ] vsSelf
  - [ ] Puzzle
  - [ ] Training mode
- [ ] Test 2-player versus — confirm G events emit, opponent's garbage telegraph appears, garbage lands
- [ ] Test chains-trigger-chains interactions (garbage clearing → counter-attack)
- [ ] Test team modes:
  - [ ] 2v2 (shared and all garbage modes)
  - [ ] 1v3 and 3v1
- [ ] Verify spectator view still shows garbage correctly (spectators receive the G relay too)
- [ ] Commit

---

## Step 8 — Death → D events

**Files:** `client/src/network/PlayerStack.lua`, `client/src/ClientMatch.lua`, optionally `common/network/ClientProtocol.lua`
**Effort:** 1–2 hours · **Difficulty:** mechanical · **Risk:** low

- [ ] In `client/src/network/PlayerStack.lua:32-40` `notifyServerStackEliminated`:
  - [ ] Replace `GAME.netClient:sendStackEliminated(self.engine.game_over_clock)` with `GAME.netClient:sendDeathEvent({sender = self.which, senderFrame = self.engine.game_over_clock, reason = "topOut"})`
  - [ ] Keep the deferred-send logic (from commit `6fc81f57`) — protects against rollback-past-death leaking a false elimination
  - [ ] Keep the `_pendingEliminationClock` clear (from same commit)
- [ ] Fill in `ClientMatch:applyDeathEvent(body)`:
  - [ ] Locate the corresponding remote stack via `body.sender` (slot index)
  - [ ] Mark it `game_ended` at `body.senderFrame`
- [ ] Optional: deprecate `ClientProtocol.sendStackEliminated` (`common/network/ClientProtocol.lua:201-206`) — either stub it as a no-op or delete entirely
- [ ] Manual: 2-player match, force one player to top out — confirm `D` event in logs and the other client recognizes the death
- [ ] Commit

### ★ PR 2 ships here ★

Garbage and death now ride dedicated event types instead of falling out of synchronized simulation. The game is genuinely loose-sync — no shared frame counter assumed anywhere in gameplay-critical paths.

---

## Step 9a — KO arbitration window

**Files:** `server/Room.lua` (or new `server/KOArbitrator.lua`), `client/src/ClientMatch.lua`
**Effort:** 1.5–2 hours · **Difficulty:** mechanical · **Risk:** moderate

Simultaneous KOs need an authoritative tie-breaker.

- [ ] Add arbitration state in `server/Room.lua`:
  - [ ] `self.arbitrationDeaths = {}` — list of death events received this window
  - [ ] `self.arbitrationWindowEndsAt = nil` — wall-clock ms
  - [ ] `local ARBITRATION_WINDOW_MS = 200`
- [ ] Modify `Room:broadcastDeathEvent` (from Step 6) to also:
  - [ ] Push the death event into `self.arbitrationDeaths`
  - [ ] If `arbitrationWindowEndsAt == nil`, set it to `now_ms + ARBITRATION_WINDOW_MS`
- [ ] Add `Room:tickArbitration(now_ms)` — called every server tick:
  - [ ] If `arbitrationWindowEndsAt ~= nil and now_ms >= arbitrationWindowEndsAt`, close the window
  - [ ] Decide outcome:
    - [ ] Exactly one death → that player loses, others win (`{winnerSlot, tie = false}`)
    - [ ] Multiple deaths on opposing teams → declare draw (`{tie = true}`)
    - [ ] Multiple deaths same team, opposing team has survivor → opposing team wins
  - [ ] Emit `K` message via `ServerProtocol.koArbitration` to all players + spectators
  - [ ] Reset arbitration state
- [ ] Wire `Room:tickArbitration` into the server's main tick loop
- [ ] Fill in `ClientMatch:applyKOArbitration(body)`:
  - [ ] Set authoritative match outcome from the `K` body
  - [ ] Override any locally-derived outcome
  - [ ] Trigger end-of-match UI (winner screen or draw screen)
- [ ] Manual: force two players to top out within 100ms (e.g., both eat killing garbage at the same time) — confirm draw screen on both clients
- [ ] Manual: solo KO (only one death) — confirm normal win screen
- [ ] Manual: 2v2 team match, both opponents die — confirm correct team win
- [ ] Commit

---

## Step 9b — Adaptive telegraph timing

**Files:** `client/src/network/NetClient.lua` (or new `client/src/network/LatencyEstimator.lua`), `client/src/ClientMatch.lua`, `client/src/globals.lua`
**Effort:** 1–1.5 hours · **Difficulty:** mechanical · **Risk:** low

Makes total perceived chain→landing time roughly constant across network conditions.

- [ ] Add latency estimator to `NetClient.lua` (or a small helper module):
  - [ ] Maintain EWMA of `(local_now_ms - serverWallClockMs)` updated on every G/D arrival
  - [ ] EWMA alpha: start with 0.2; can tune later
  - [ ] Expose `NetClient:estimatedOneWayLatencyMs()` and `NetClient:estimatedOneWayLatencyFrames()`
  - [ ] Seed estimate with a sane default (~50ms) until first measurement
- [ ] Add `MIN_REACTION_FRAMES = 45` constant in `client/src/globals.lua`
- [ ] In `ClientMatch:applyGarbageEvent(body)` — replace the naive landing computation from Step 7:
  ```
  local estimated_latency_frames = GAME.netClient:estimatedOneWayLatencyFrames()
  local total_telegraph_budget   = GARBAGE_TRANSIT_TIME + GARBAGE_TELEGRAPH_TIME + GARBAGE_DELAY_LAND_TIME  -- 150
  local remaining_budget         = total_telegraph_budget - estimated_latency_frames
  local landing_offset           = math.max(MIN_REACTION_FRAMES, remaining_budget)
  local landing_frame            = stack.clock + landing_offset
  ```
- [ ] Add a debug log line on every `applyGarbageEvent`: `estimated_latency`, `landing_offset`, `landing_frame`
- [ ] Manual: latency sweep — apply 50/200/500/1000/2000ms delay; confirm landing offsets are roughly 147/120/90/30/45 (floored at MIN_REACTION_FRAMES)
- [ ] Commit

---

## Step 10 — ReplayV4 + migration

**Files:** new `common/data/ReplayV4.lua`, `common/engine/Match.lua` (`createFromReplay`), `server/Game.lua` (`finalizeReplay`)
**Effort:** 2–3 hours · **Difficulty:** mechanical · **Risk:** low

- [ ] Create `common/data/ReplayV4.lua` cloning the `ReplayV3` shape
- [ ] Bump `REPLAY_VERSION` to `4`
- [ ] Add new top-level fields:
  - [ ] `crossPlayerEvents.garbage[]` — entries: `{senderSlot, senderFrame, recipients, garbage}`
  - [ ] `crossPlayerEvents.deaths[]` — entries: `{senderSlot, senderFrame, reason}`
- [ ] In `server/Game.lua:finalizeReplay` (or whatever writes the replay): include `self.garbageEvents` and `self.deathEvents`
- [ ] In `common/engine/Match.lua:createFromReplay` (~line 553+): branch on `replay.engineVersion`
  - [ ] V4 path: schedule `crossPlayerEvents.garbage[]` to call `enqueueRemoteGarbage` at each recorded sender frame
  - [ ] V4 path: schedule `crossPlayerEvents.deaths[]` to mark stacks ended at the recorded frame
  - [ ] V3 path: keep the existing derive-from-sim behavior for backward compatibility with old replays
- [ ] Add `ReplayTests` coverage:
  - [ ] V3 replay loads and plays back unchanged
  - [ ] V4 replay round-trips (save → load → replay matches original)
- [ ] Manual: save a replay from a live loose-sync match, reload it, confirm both perspectives play back correctly
- [ ] Commit

### ★ PR 3 ships here ★

Loose-sync architecture complete. Tie-breaking is authoritative, telegraph timing adapts to observed latency, replays preserve full fidelity across both perspectives.

---

## Verification reference

Throughout the rollout, the standard verification cadence:

- **`zsh run_server.sh`** — runs the server test suite on startup. Watch for failures.
- **`zsh run_tests.sh`** — runs the client/common test suite via love.
- **`tail -f logs/server.log`** — watch for G/D/K message flow, KO arbitration events.
- **`tail -f logs/client.log`** — watch for `applyGarbageEvent`/`applyDeathEvent` calls and adaptive latency estimates.
- **`TcpClient:activateDelayedProcessing()`** (in `client/src/network/TcpClient.lua`, ~line 196) — inject artificial latency for testing.

## What's intentionally not in this rollout

- Server-side verification of `G` event payloads. Trust clients.
- Reconnect/resume mid-match. Disconnect still ends the match.
- Spectator catch-up policy refinement. Existing input firehose should keep working.
- Telemetry for tuning `MIN_REACTION_FRAMES` and the 200ms arbitration window — file as follow-up tickets once real player data exists.
