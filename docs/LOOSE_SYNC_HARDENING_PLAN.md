# Loose-Sync Hardening Plan (v2)

The loose-sync layer (garbage relay, death events, round-robin cursor)
spans `Match.lua` (engine), `Room.lua` (server), and `ClientMatch.lua`
(client). The contract between them is implicit. B8 and C were both
silent divergence bugs from contracts that lived only in commit messages.

## What this plan addresses (after three-reviewer pass)

Two real bug classes, two different fixes:

- **Content bugs** — right event delivered, wrong logic applied (B8 missing
  in catch-up; C cursor diverged at death boundaries). TCP-ordered delivery
  doesn't help; the wrongly-applied event would just be wrongly re-applied.
  Fix: **prevention** via consolidated logic + behavior tests + state hashes.
- **Delivery bugs** — event dropped or duplicated. None observed in the
  current codebase, but plausible at scale. Fix: **recovery** via seqnums
  and gap-replay.

The original plan had this backwards — led with delivery (seqnums) when
the actual bugs were content. Reordered: lock current behavior first, fix
the content side, defer delivery infrastructure until a real loss is
measured.

---

## Step 1 — Define the contract as failing test stubs

Write the invariants we want as named test functions, asserting on the
post-conditions, before changing any production code. Where the current
behavior already meets the invariant, mark it pending and unblock it as
we go. Where it doesn't, it stays red until the relevant step fixes it.

**New file:** `common/tests/engine/LooseSyncContractTests.lua`

Each invariant is one test with a docstring. Sample names:

- `test_invariant_garbage_recipient_count_matches_sender_log` — for every
  G event the server relayed, every recipient's incoming queue has it.
- `test_invariant_dead_sender_inputs_dropped` — after a D event for slot
  N, no further inputs from slot N appear in any client's view-stack.
- `test_invariant_cursor_aligned_across_clients_after_G` — after applying
  a G with recipients=[X], every client's `teamGarbageState[sender]`
  cursor advances past X to the same position.
- `test_invariant_spectator_state_equals_active_player_after_catchup` —
  spectator joining at frame F arrives at the same `incomingGarbage`
  state as a player who was there from frame 0.
- `test_invariant_no_silent_input_drop_after_mid_match_leave` — after a
  player leaves, every survivor (regardless of slot) keeps receiving
  every relayed event. (B10 regression test.)
- `test_invariant_round_robin_skips_dead_enemies` — sender with mixed
  living/dead enemies only delivers to living.

These are the contract. The test stubs come BEFORE the implementation
fixes so we know what we're enforcing.

**Effort:** half a day to enumerate + scaffold. They start red where the
behavior doesn't exist yet (e.g. state-hash check) and green where it
already does.

---

## Step 2 — Build the engine-state-vector harness + matrix

The skeptical reviewer was right that the harness is the cost, not the
scenarios. Build it once, reuse for every contract test.

**Harness shape** (new file: `common/tests/engine/LooseSyncHarness.lua`):

- `LooseSyncHarness.scenario({ players = N, mode = "..." })` — constructs
  a real engine, optionally a real server `Room`, drives inputs through
  scripted ticks, exposes a state-vector reader.
- `harness:tick(frames)` — advances all stacks N frames.
- `harness:sendGarbage(senderSlot, blocks)` — synthesizes outgoing garbage
  from a sender (server-relayed path, exercises the same code as live).
- `harness:killStack(slot, atFrame)` — synthesizes a D event for that slot.
- `harness:spectatorJoin(atFrame)` — adds a spectator mid-match,
  returns the spectator's reconstructed match for state-vector compare.
- `harness:stateVector()` — returns canonical hash/struct of:
  - `incomingGarbage[stack]` queue lengths and contents.
  - `teamGarbageState[sender].currentTargetIndex` per sender.
  - `game_over_clock` per stack.
  - `arbitrationDeaths` (server side).

**Test patterns** (mirrors existing `TeamGarbageTests.lua` and
`LooseSyncTests.lua` style, runs under `run_tests.sh` because the engine
pulls LÖVE globals via `client/src/globals.lua`):

| Mode | Scenario |
|---|---|
| 2p VS | Baseline |
| 3p FFA shared | Round-robin alternates living enemies |
| 3p FFA shared | Sender hits already-dead → server redirects, cursor aligns |
| 4p 2v2 shared | Cursor on one teammate's dead → keep sending to living |
| 4p 1v3 all | Solo's garbage hits all 3 |
| 3p FFA | Spectator joining mid-match has same state vector as active player |
| Any team mode | Mid-match leave → surviving players keep getting events |
| 3p FFA | Simultaneous deaths inside arbitration window → server picks consistent winner |

**The mocked-clock concern is real.** `socket.gettime()` in `Room.lua:917-922`
drives arbitration. The harness exposes a `clock = nil` injection point;
arbitration tests pass a fake clock. Other tests use real wall-clock.

**Effort:** 2–3 dev days as the skeptical reviewer flagged. Don't budget
"30 min per test once harness exists" — most of the work is `stateVector()`,
clock injection, and the spectator-join machinery.

---

## Step 2.5 — Extract the cursor rule into one function

Round-robin "walk an enemy list, skip dead, find next-living from a
starting index" is implemented three times:

- `common/engine/Match.lua:319` (engine: pick-and-advance in `distributeGarbageToTargets`)
- `server/Room.lua:751` (server: `_redirectIfDead` walk)
- `client/src/ClientMatch.lua:1218` (client: cursor self-heal in `_applyGarbageEventNow`)

Bug C lived exactly here — three places drifting independently. Extract
to `common/data/TeamUtils.lua:findNextLiving(enemyIndices, startIndex, aliveFn)`
and call from all three sites. Returns `(pickedIndex, pickedSlot, nextLivingIndex)`.

This is **not** a `LooseSyncState` class — just one pure function. The
storage stays where it is.

**Effort:** half a dev day. Locked in by the Step 1 contract test
`test_invariant_round_robin_skips_dead_enemies`.

---

## Step 3 — Periodic state hashes (content validation)

The architectural reviewer's catch: seqnums catch delivery loss, but the
actual bugs we've had are content divergence. State hashes catch BOTH.

**Server side:** every N frames (e.g. every 60), each client emits a
compact hash of its `incomingGarbage` heights per stack + each stack's
`game_over_clock` + each sender's `teamGarbageState.currentTargetIndex`.
Server compares them. Mismatch → log loudly, optionally trigger resync
via Step 4 once that lands.

**Client side:** compute hash, send periodically via `H` event message.

**What it catches (that seqnums don't):**
- C-class bugs where the right event was sent but cursors diverged.
- B8-class bugs where the spectator's reconstructed state doesn't match
  the active player's.
- Any future content divergence.

**Effort:** 1 dev day. New `H` message type, server-side comparator,
client-side hash builder. The hash itself is cheap (~16 fields per
stack) — runs every second of match time.

---

## Step 4 — Seqnums + gap-replay (DEFERRED)

The original Step 1, demoted. Build only if we observe actual delivery
loss in logs (state-hash mismatches with no corresponding logic bug).
Until then, this is solving a problem we don't have.

When/if we build it, the open questions to resolve first:
- Bounding `eventLog` memory growth (cap by frame count or LRU).
- `requestEventReplay` itself reliable (timeout/retry/idempotency).
- What `seq` means across burst K events (each death is its own seq).
- Replay-file forward compat (`crossPlayerEvents` entries get a `seq`?).
- Observability: log every replay request so we know if it fires.

**Effort:** 1–2 dev days when we get there. Not now.

---

## What this plan deliberately does NOT do

- Big-bang refactor to `LooseSyncState` class. Storage genuinely spans
  three address spaces; only logic (Step 2.5) is consolidatable.
- Replace the 60-frame defer threshold. Once Step 3 detects divergence,
  the threshold matters less — and most live bugs were "we never had
  the event" not "we had it at the wrong frame."
- Input-stream seqnums. Hot path, TCP-ordered.
- A prose contract doc. Step 1's named tests ARE the contract.

---

## Execution order (revised)

1. **Step 1 — Contract test stubs.** Half day. Locks the spec.
2. **Step 2.5 — Cursor extraction.** Half day. Smallest concrete win;
   the cursor invariant test from Step 1 covers it.
3. **Step 2 — Engine-state-vector harness + matrix.** 2–3 days. Most of
   the contract tests need this to actually run.
4. **Step 3 — Periodic state hashes.** 1 day. Catches the bug class
   that triggered this plan.
5. **Step 4 — Seqnums + gap-replay.** Only if delivery loss is observed.

Total before Step 4: ~4–5 dev days.
