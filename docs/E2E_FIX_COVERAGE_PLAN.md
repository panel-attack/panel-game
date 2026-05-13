# Multiplayer Test Coverage Plan (handoff)

Forward-looking work to lock down the multiplayer test surface and harden
the loose-sync layer. The May 12 bug fixes are landed (see commit
`ec5dd55d` for the per-bug breakdown); this doc is what's still to build.

## What's already landed

Reference for handoff context — fixes from the May 12 session:

| ID | Fix | Files |
|---|---|---|
| B0 | `actualSlot` typo crashing every join | `server/server.lua` |
| B1 | `Match.createFromReplay` defensive guards | `common/engine/Match.lua` |
| B8 | Partial replay carries `crossPlayerEvents` + client drains historical events during catch-up | `server/Game.lua`, `client/src/ClientMatch.lua` |
| D | Sparse-roster compaction at `Room:start_match` (Open FFA) | `server/Room.lua` |
| C | Telegraph cursor self-heal on G receipt | `client/src/ClientMatch.lua` |
| B9 | Open Team 1v2 start crash + Lobby min/max for Open Team | `server/Room.lua`, `client/src/scenes/Lobby.lua` |
| B10 | Sparse `self.players` broadcasts — converted to `pairs` | `server/Room.lua`, `server/Game.lua` |
| Step 2.5 | Cursor walk consolidated into `TeamUtils.findNextLiving` | `common/data/TeamUtils.lua` (+ all 3 call sites updated; 8 unit tests added) |

**Still open from the original bug report:** B7 (team-assignment orientation
for 2v1). UI labeling issue, independent of sync work — ~half a day, can
slot in anywhere.

---

## What harness already exists

- `server/tests/E2E/Harness.lua` — spins up a real Server + N TestClients over real TCP in one luajit process. Cooperative `tick()` + `waitUntil` primitives.
- `server/tests/E2E/TestClient.lua` — speaks the real wire protocol. Already has `sendInput`, `sendJson`, `sendRoomRequest`, `sendJoinRoomRequest`, `sendReady`, `sendLeaveRoom`, `sendStackEliminated`. Inboxes for `json` / `input` / `garbage` / `death` / `ko`.
- `server/tests/E2E/ThreePlayerFFATests.lua` — first scenario (`open_ffa` reach-match-start + input relay). Pattern to follow.
- `common/tests/engine/TeamGarbageTests.lua`, `LooseSyncTests.lua` — engine-level tests that run under `run_tests.sh` (love2D, not luajit, since the engine pulls love globals via `client/src/globals.lua`).

## What harness DOES NOT have yet (the gating dependencies)

1. **Logger-error hook on `Harness`.** `harness.serverErrorCount` / `harness.serverErrors[]` — wrap `logger.error` in `Harness:start()`, restore in `Harness:stop()`. Once this exists, every existing scenario can `assert(h.serverErrorCount == 0)` as a free regression net.
2. **`TestClient:sendSpectateRequest(roomNumber)`** + JSON-router convenience for `spectateRequestGranted` payload (decode the replay struct).
3. **`TestClient:sendGarbageEvent(body)` and `:sendDeathEvent(body)`** — mirrors `:sendInput`. Wraps `_sendFrame(NetworkProtocol.clientMessageTypes.garbageEvent.prefix, json.encode(body))` (and `.deathEvent.prefix`). ~6 lines each.
4. **`LooseSyncHarness.lua`** (NEW, in `common/tests/engine/`) — love2D-side harness for engine-only scenarios. Constructs a real `Match` engine, scripted-tick driver, state-vector reader. Used by contract / matrix tests that don't need the server.
5. **State-vector reader.** Canonical struct/hash of: per-stack `incomingGarbage` queue contents, per-sender `teamGarbageState.currentTargetIndex`, per-stack `game_over_clock`, `arbitrationDeaths` (server). Same shape readable from both the E2E `Harness` (server-side) and `LooseSyncHarness` (engine-only).
6. **Clock injection.** `Room` arbitration uses `socket.gettime()` directly (`server/Room.lua:917-922`). Harness exposes an optional `clock` callable; arbitration tests pass a fake clock. Other tests use real wall-clock.

Total harness work: ~1 dev day. **Unblocks everything else.**

---

## Items, in order

### 1. Shared harness extensions (~1 day)

Build (1)-(6) from the section above. Validation: every existing
`ThreePlayerFFATests.lua` scenario keeps passing.

### 2. Contract test stubs (~half a day)

**New file:** `common/tests/engine/LooseSyncContractTests.lua` — invariants
as named test functions. Some pass green against current code; some stay
red until later items fix them.

Names + post-conditions:
- `test_invariant_garbage_recipient_count_matches_sender_log` — every relayed G has its recipient's incoming-queue length match.
- `test_invariant_dead_sender_inputs_dropped` — after D for slot N, no further inputs from slot N appear in any view-stack.
- `test_invariant_cursor_aligned_across_clients_after_G` — every client's `teamGarbageState[sender].currentTargetIndex` advances to the same position after a G with `recipients=[X]`.
- `test_invariant_spectator_state_equals_active_player_after_catchup` — spectator joining at frame F arrives at the same `incomingGarbage` + `game_over_clock` state as a player who was there from frame 0.
- `test_invariant_no_silent_input_drop_after_mid_match_leave` (B10 regression) — after a player leaves, every survivor regardless of slot keeps receiving every relayed event.
- `test_invariant_round_robin_skips_dead_enemies` — sender with mixed living/dead enemies only delivers to living. (Backed by `TeamUtils.findNextLiving`'s 8 unit tests at the function level — this is the end-to-end variant.)

These tests **are** the contract. No separate prose doc — naming carries the spec.

### 3. Regression scenarios for landed fixes (~half a day on top of #1)

Wire each May-12 fix to a focused regression test:

- **B0** — assertion `harness.serverErrorCount == 0` baked into every existing scenario via `Harness:stop()`. Free with item (1).
- **D** — `test_open_ffa_compacts_after_pre_match_leave`. 4 clients join, 1 leaves pre-match, remaining 3 ready up, assert `matchStart.replay.stacks` has length 3 and playerNumbers are 1/2/3 (not 1/2/4). Server-side `room.players[1..3]` are the correct publicIds.
- **B8 half 1** — `test_spectator_replay_includes_cross_player_events`. Drive a G event from BotA, then `BotD:sendSpectateRequest(roomNumber)`, assert `BotD.lastSpectateGranted.replay.crossPlayerEvents.garbage` has the entry.
- **B10** — `test_mid_match_leave_keeps_high_slot_receiving`. 3-player FFA, BotB (slot 2) leaves mid-match, assert BotC (slot 3) keeps receiving inputs and G/D events from BotA.
- **B9** — `test_open_team_1v2_starts_with_three_players`. 3 clients join an Open 1v2 room, all ready, `matchStart` fires once and no `'for' limit must be a number` in `harness.serverErrors`.

### 4. Engine matrix tests (~1 day with harness done)

In `common/tests/engine/LooseSyncMatrixTests.lua` (love2D side, uses `LooseSyncHarness`):

| Mode | Scenario |
|---|---|
| 2p VS | Baseline state-vector roundtrip |
| 3p FFA shared | Round-robin alternates living enemies (no death) |
| 3p FFA shared | Sender hits already-dead → server redirects, cursor aligns |
| 4p 2v2 shared | Teammate dead → keep sending to living enemy |
| 4p 1v3 all | Solo's garbage hits all 3 |
| Any team mode | Mid-match leave → survivors keep receiving |
| 3p FFA | Simultaneous deaths in arbitration window — needs clock injection |

Replaces / subsumes the B1/B8-half-2/C unit-test slots from the original
plan — those are individual rows of this matrix.

### 5. Periodic state hashes (~1 day)

Once #1–#4 land and behavior is locked in. Server-broadcast `H` event
every N frames; clients hash their `incomingGarbage` / `teamGarbageState` /
`game_over_clock` and emit back. Server compares; mismatch → log loudly.

Catches *content* divergence (the actual bug class we've seen — B8, C)
that the contract tests catch only at test-time. This is the production
detection equivalent.

Design note: state hashes are strictly stronger than seqnums for the bug
class we've actually observed — seqnums catch dropped events, hashes
catch dropped *and* wrongly-applied events. We've never measured a
delivery loss, so detect first, recover later.

### 6. B7 — Team-assignment orientation (~half a day, independent)

UI labeling issue. Investigate whether the lobby "2 vs 1" / "1 vs 2"
labels map to `playersPerTeam={2,1}` / `={1,2}` correctly, and whether
the room-creator (slot 1) lands on the expected side. Likely just a
label swap or a team-color render mirror. Independent of every other
item — slot in anywhere.

---

## Deferred

**Seqnums + gap-replay.** Only build after observing real delivery loss
in logs. State hashes (item 5) will tell us whether delivery is the
problem — until then this is solving a problem we haven't measured.

Open questions to resolve before building, when the time comes:
- Bounding `eventLog` memory growth (cap by frame count or LRU).
- `requestEventReplay` reliability (timeout / retry / idempotency — if
  the replay-of-the-replay itself drops, you've just renamed the
  silent-desync state).
- What `seq` means across the burst of K events from one arbitration
  decision (share one seq, or one each).
- Replay-file forward compat (does `crossPlayerEvents` get `seq` on
  disk, and how do older clients load it).
- Observability: log every replay request so we know if the path is
  firing in production at all.

---

## Pointers for the next person

- **commit `ec5dd55d`** — full per-bug breakdown of the May 12 fixes with file/line refs. Useful background when writing regression tests for items 3 and 4.
- **`server/tests/E2E/ThreePlayerFFATests.lua`** — the existing scenario to copy-paste-and-modify for items 3 and 4's server-side tests.
- **`common/tests/TeamUtilsTests.lua`** — the 8 `findNextLiving` tests at the bottom are the pattern for invariant tests that don't need a harness.
- **CLAUDE.md** in repo root — local-dev setup (LÖVE 12, luarocks, port 49569 for dev / 49580 for e2e). `zsh run_server.sh` / `zsh run_client.sh` / `zsh run_tests.sh` / `zsh run_e2e_tests.sh`.

## Total budget

~4 dev days through item 5. Add ~half a day for B7. Add 1-2 days if/when
Step 4 (seqnums) becomes necessary.
