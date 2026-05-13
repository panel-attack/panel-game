# Multiplayer Testing Issues — May 12, 2026

Testing session with 3 players (Bramp, Bowser, chaos952) on relaxed latency settings.
Engine version: 049.

## Status — fixes landed this session

- **B0 ✅** server.lua:921 — `actualSlot` typo (every join threw, every player). Fixed: use `player.player_number`. (`server/server.lua`)
- **B1 ✅** Match.createFromReplay — added defensive guards so a malformed `garbageFlows` no longer hard-crashes; warns and continues. (`common/engine/Match.lua:708`)
- **B8 ✅** Spectator/rejoiner desync — **real protocol-level bug**:
  - `Game:getPartialReplay` was stripping out the loose-sync event log (`crossPlayerEvents.garbage` / `.deaths`). Mid-match spectators got inputs only — no history of the G/D events that actually drove garbage deliveries and deaths. Their view permanently diverged from reality (receivers had less garbage than they should; dead senders never stopped running because no D event ever set `game_over_clock`).
  - No client code ever consumed `crossPlayerEvents`. The event log roundtripped through JSON but was never replayed.
  - **Fix:** `server/Game.lua` now populates `crossPlayerEvents` in partial replays. `client/src/ClientMatch.lua` queues historical events on construct and drains them in `ClientMatch:run` as the catch-up sim reaches each event's `senderFrame`. Same defer (60-frame threshold) added to `applyGarbageEvent`/`applyDeathEvent` so live events arriving during catch-up don't land too early either. In-sync live play behavior is unchanged (network lag is well under 60 frames).
  - This is almost certainly the real B2 (spectator frozen) and a contributor to B6 (FFA never ends with a dead remote).
- **D ✅** Sparse roster (Open FFA pre-match leave) — `Room:start_match` now compacts `self.players` (dense 1..N) and renumbers `player.player_number` for dynamic-roster modes. Without this, `ipairs(room.players)` halted at the first nil slot, so the replay shipped one stack instead of three, and input prefixes for high slots decoded on the client to non-existent stacks and got silently dropped. Fixed-roster rooms keep slot semantics (team-color assignment) and can't reach `start_match` sparse anyway.
- **C ✅** Telegraph cursor self-heal — `_applyGarbageEventNow` now re-anchors the per-sender round-robin cursor to the recipient the server actually targeted (shared mode). Each client previously advanced the cursor based on its local liveness view; at death boundaries that made `refreshSharedModeTelegraphTargets` draw a different next-target arrow on each screen. The G event is the canonical "who got hit," so we use it to align.
- **Step 2.5 ✅** Cursor logic consolidated — the "walk an enemy list, skip dead, pick next-living + advance cursor" rule was implemented three times (engine `Match.lua:319`, server `Room.lua _redirectIfDead`, client `ClientMatch.lua _applyGarbageEventNow`). Drift between those three sites is exactly what caused bug C. Extracted to `common/data/TeamUtils.lua:findNextLiving(enemyIndices, startIndex, aliveFn)`. All three call sites now use the same predicate. Backed by 8 new unit tests in `TeamUtilsTests.lua` covering: all-alive, dead-from-start, wraps-over-dead, all-dead, empty-list, out-of-range-start, alternates-between-two, and 2v1-solo-survivor.
- **B10 ✅** Mid-game silent breakage from sparse `self.players` — **direct match for the "everyone freezes / no garbage / timer frozen" report**:
  - When a player leaves mid-match, `_removeFromPlayersAndAnnounce` nils out their slot to preserve slot-based team semantics. Every server-side broadcast loop used `ipairs(self.players)` which halts at the first nil — so any surviving player whose slot was past the hole **silently stopped receiving inputs, garbage events, death events, KO arbitration, and JSON broadcasts**. Their view-stacks froze, no garbage flowed, timer events stopped — exactly the reported symptom.
  - Affected paths converted to `pairs(self.players)`: `Room:broadcastInput`, `Room:broadcastGarbageEvent`, `Room:broadcastDeathEvent`, `Room`'s KO arbitration broadcast, `Room:broadcastJson` (the load-bearing fan-out used by settings/playerLeftRoom/ranked/taunt/pause/etc), the synth-death-on-disconnect broadcast, and `Room:prepare_character_select`.
  - Also fixed `Game:receiveOutcomeReport`'s diagnostic log and `Game:finalizeReplay`'s replay anonymization loop — both walked `ipairs(self.players)` and would have lied / under-anonymized when a leaver's slot was nil.
- **B9 ✅** Open Team 1v2 / 2v1 / Open team modes — "everyone clicked start and nothing happened":
  - Server log showed `Starting match 1 ... ERROR: TeamUtils.lua:37 'for' limit must be a number`. Root cause: `Room:start_match` was blindly overriding `gameMode.teamCount = playerCount` for any dynamic-roster mode (Lobby marked Open Team rooms as `minPlayers=2`, `maxPlayers=playerCount`). For Open 1v2 with 3 players, that turned `createTeams(3, 2, {1,2})` into `createTeams(3, 3, {1,2})` — `playersPerTeam[3]` is nil and the inner loop's `for i = 1, teamSize` blew up because `teamSize` is nil.
  - **Fix 1 (server, `Room.lua start_match`):** only override `teamCount` for FFA-like modes (`playersPerTeam == 1`). Team modes keep their preset `teamCount`.
  - **Fix 2 (server, `Room.lua start_match`):** added a "team total doesn't match roster" guard that refuses to start_match when `playersPerTeam` says we need exactly N and roster is anything else. Was silently crashing into the catch; now logs `cannot start match — team configuration needs exactly N players, room has M` and bails cleanly.
  - **Fix 3 (client, `Lobby.lua getRoomModeWithRosterBounds`):** Open Team rooms now set `minPlayers = maxPlayers = playerCount` instead of `minPlayers = 2`. "Open" still means publicly joinable, but team-mode rosters are fixed — the match can only start when the full team structure is filled.

## Original asks — final status

Mapping the bugs from the top of this doc to what's actually fixed now:

| Original report | Status | Notes |
|---|---|---|
| Match.createFromReplay crash | ✅ B1 | Defensive guards; in practice the root cause was the B0/B8/B9 cascade — once those land it never triggers anyway, but the guards stay so future shape bugs surface as warnings instead of crashes. |
| Garbage distribution broken | ✅ B8/B9 | Cross-player event log now reaches every client; matches actually start, so distribution can run. The round-robin code itself was correct (passes existing TeamGarbageTests). |
| Player sync/freezing during matches | ✅ B8 + B10 | Two cumulative root causes: (1) spectators/rejoiners missed historical G/D events (B8). (2) **After any mid-match leave, broadcast loops halted at the leaver's nil'd slot, silently cutting off every surviving player past it from all relayed traffic** (B10). With both fixed, view-stacks track live opponents and surviving players keep receiving the full event stream. |
| Team assignment backwards (2v1 reversed) | ⚠️ B7 open | Independent of the start/sync fixes. Needs UI investigation — likely either the lobby's "2 vs 1" / "1 vs 2" labels are swapped vs the `playersPerTeam={2,1}` orientation, or the team-color render side draws team 1 / team 2 in the wrong slot positions. Worth a focused 30-min look once the empirical fixes above are confirmed. |
| Cannot rejoin after leaving room | ✅ B0 | Root cause was the `actualSlot` throw — joins half-completed, second join request rejected as "already in room" or hit a partial state. With B0 fixed, the join is clean. |
| Spectator mode display not syncing | ✅ B8 | Same root cause as "player sync/freezing" — spectators never got the historical G/D events. |
| **Open Team 1v2 — everyone clicked start, nothing happened** | ✅ B9 | Server was crashing inside `TeamUtils.createTeams` because dynamic-roster override clobbered `teamCount` for team modes. Fixed today (this session). |

So the remaining open item from the original report is **B7** (team-assignment orientation). Everything else has either a landed fix or a strong root-cause hypothesis with the fix in place.

## What's NOT done — (a) sequence numbers + gap-replay

This is the architectural answer to "how does communication self-heal." Sketched here for the next session — too invasive to land tonight without a clear test plan.

### Design

**Server**:
- `Room.nextEventSeq` monotonic counter.
- Every server→client event (G, D, K, optionally inputs) is stamped with a per-room `seq` before broadcast.
- Persist the seq→event mapping on the room (already in `game.garbageEvents` / `deathEvents` for G/D; need a unified ordered log).
- New handler: `requestEventReplay { fromSeq }` — server responds with all events with `seq >= fromSeq` in order.

**Client**:
- `lastEventSeq` tracked per `ClientMatch` (or `NetClient`).
- On each event:
  - `seq == lastEventSeq + 1` → apply, advance.
  - `seq > lastEventSeq + 1` → gap. Buffer the event; send `requestEventReplay { fromSeq = lastEventSeq + 1 }`. Apply replayed events, then the buffered live ones.
  - `seq <= lastEventSeq` → duplicate, drop.

### What it subsumes

- B8's "include event log in partial replay" becomes "fromSeq = 0 on initial spectate." One mechanism for both initial state and gap-recovery.
- TCP reset / reconnect recovery (currently not handled — match voids on disconnect).
- Any silent event loss (e.g., a future server bug that drops an event mid-broadcast).

### What it doesn't fix on its own

- Local sim divergence due to non-deterministic prediction (round-robin cursor in shared mode, etc). C addresses the cosmetic part; a state-hash probe would be needed to detect deeper divergence.
- Inputs: per-input seqnums would bloat the wire. Either accept TCP as authoritative for inputs, OR add a per-stack "last applied input frame" hash that the server checks periodically.

### Trade-offs to decide before building

1. **Memory** — keeping every G/D event indefinitely on the server is fine for typical match length but unbounded in theory. Cap or drop after match end.
2. **Per-room vs per-client seq** — per-room is simpler (one counter, all clients see same seq stream). Per-client allows differential filtering (sender doesn't need to receive its own G echo) but adds complexity.
3. **Gap-detection latency** — clients only detect gaps when the NEXT event arrives. If a connection is silent, no detection. A periodic heartbeat from the server would close that, but adds wire chatter.
4. **Auto-trigger vs manual** — for the next test session, a `/resync` debug hotkey that sends `requestEventReplay { fromSeq = 0 }` is enough to validate the mechanism. Auto-trigger on gap-detect can come next.

## What we found in the logs

- `logs/server.log` (May 12 session) shows the **`actualSlot` crash on every join** — Amber, Koozie, Lala all tripped it. The exception fires AFTER `addToRoom` has been sent and `playerToRoom` has been set, so the join itself succeeds but the connection's error path is noisy. **Likely root cause of the "Cannot rejoin" report** and a strong candidate for the cascading spectator crash.
- The `Match.createFromReplay` stack trace in the original report is **not in the logs we have** (current `logs/client.log` is from May 10). The replay broadcast in this session (3-player 7p_ffa_shared) has dense, well-formed `garbageFlows`. The createFromReplay crash either (a) happened on a now-overwritten client log, or (b) was actually a downstream artifact of B0. The new defensive guard means we won't hard-crash on malformed flows again either way.
- Server log lines 92, 227 etc. show `actualSlot` errors but the room state proceeds normally — Koozie and Lala both successfully joined room 1 despite the throw.

## Things still to verify empirically (re-run the test session)

After B0/B1 land, re-run a 3-player FFA session and check whether the following persist. If any do, they need separate fixes:

- **B2 Spectator frozen** — Server-side fan-out is wired correctly: `Room:broadcastGarbageEvent` (line 797-805), `Room:broadcastDeathEvent` (line 864), and `Room:broadcastInput` (line 670) all loop `self.spectators`. If spectator boards still freeze, the issue is on the client (e.g. `enableCatchup` for spectator stacks, or `applyGarbageEvent` no-oping for a missing recipient).
- **B4 Round-robin distribution** — The new per-sender / advance-over-living code at `Match.lua:300-375` passes the existing `TeamGarbageTests` and `LooseSyncTests`. The "no one receiving garbage" report may have been an artifact of B0 (clients half-joined). Re-test with B0 fixed; if still broken, instrument with the existing `G emit` / `G apply` logger lines.
- **B5 Paralysis / timer frozen** — Strongly suspected to be the same as B4 (no garbage relay → no events → view-stacks freeze waiting). Re-test post-B0.
- **B3 Cannot rejoin** — Probably resolved by B0 fix. Verify by leaving + rejoining in fixed-roster + open-FFA flows.
- **B6 hasEnded for pure FFA** — Still worth auditing: `Match.lua:790-808` fixes team-end via `isDone()`, but the pure-FFA path (no `TEAMS_ACTIVE` rule) uses the alive-count loop above. Confirm a 4p FFA actually terminates when the third-to-last player dies.
- **B7 Team backwards** — Independent of B0; needs its own investigation in `TeamUtils.createTeams` vs lobby UI team-color selection. Skip until others stabilize.

---

## Original triage (kept for reference)

## P0 — Crashers / "see nothing" (fix first)

These are the user-facing "did not load / black screen / dropped connection"
class. They block all other testing and most have multi-bug cascades.

### B1. `Match.createFromReplay` crash — `table.insert` got nil
**Where:** `common/engine/Match.lua:712-713`
**Error:** `bad argument #1 to 'insert' (table expected, got nil)`
**Trips on:** starting a match, joining a match, spectating
**Stack:** `Match.createFromReplay → ClientMatch.createFromReplay → BattleRoom.startMatch`

Two candidate causes; both must be guarded:

1. `match.garbageTargets[garbageFlow.source]` is `nil`. The preceding loop
   (`Match.lua:693-706`) only sets up `garbageTargets[i]` for `i in ipairs(replay.stacks)`.
   `ipairs` halts at the first `nil`, so a sparse `replay.stacks` (open-FFA roster
   where a slot was vacated) leaves later indices uninitialized.
2. `match.garbageSources[recipientStack]` is `nil` because
   `recipientStack = match.stacks[recipientIndex]` is `nil`. Triggers when
   `replay.garbageFlows` references a recipient index without a corresponding stack.

**Server side:** `server/Game.lua:111,126` builds `garbageFlows` with `for i = 1, #replay.stacks`.
`#` on a sparse array is undefined in Lua — and Open FFA + pre-match leave is
exactly the case where `replay.stacks` can be sparse (see `Room.lua:380-398` for
the dynamic-roster compaction caveat).

**Fix sketch:** (a) Have the server compact stacks/flows into a dense array before
broadcast. (b) Defensive bail in `Match.createFromReplay` — skip flows whose source
or recipient stack is `nil`, log loudly. (c) Add an integration test that round-trips
a 3-of-5 open-FFA replay through createFromReplay.

### B2. Spectator boards frozen ("the view part borked")
**Symptom:** spectator joins; remote boards don't render updates.
**Likely cause:** loose-sync delivers garbage via `G` events relayed by the server
(`server/Room.lua:737 broadcastGarbageEvent`). The relay loops `self.players` and
fans out, but the spectator-fanout path needs verification — `Room.lua:435` iterates
`self.spectators` in some broadcast paths but `broadcastGarbageEvent` may not.
**Also suspect:** the spectator's local engine has no `is_local` stack, so
`Match:deliverOutgoingGarbage` (line 450) early-returns on every remote source,
and the only thing that drives visuals is incoming `G` events. If `G` events are
not reaching spectators, nothing renders.
**Audit:** confirm `Room:broadcastGarbageEvent` and the input/D/K event broadcasters
all reach `self.spectators` (search `:broadcastJson` callers and verify).

### B3. Cannot rejoin after leaving room (cascades into B1 crash)
**Symptom:** leave → rejoin fails → spectate attempt → B1 crash.
**Where:** fixed-roster rooms reserve the slot for the leaver (`server/Room.lua:1226-1231`),
but rejoin handshake may not pick the reservation back up. Open-FFA does NOT reserve.
**Audit:** trace `handleJoinRoom` in `server/server.lua` against `reservedSlots`;
verify the same `publicId` lands in their held slot.

---

## P1 — Gameplay regressions (likely all one bug)

Bramp's hunch ("I think I fucked with the checks before I pushed") points at the
round-robin / hasEnded rewrites landed in commits `2ab84c08`, `422e97d3`, `eeaa2dd0`
("ffa: round-robin garbage variants"). These three look like one cluster:

### B4. Garbage distribution broken in round-robin / team modes
**Where:** `common/engine/Match.lua:300-375` (`distributeGarbageToTargets`).
**Regression:** prior code advanced the round-robin counter **unconditionally** so
every client agreed on rotation state. New code advances over **living** enemies
only, picked from each machine's local live-view (`Match.lua:340-348`). This
re-introduces the determinism gap the old comment was protecting against — at a
death boundary, sender and receiver clients can disagree which enemy is next, and
the authoritative `G` event from the sender's machine may target a recipient the
receivers think is already dead.
**Action:** revert to "advance unconditionally; walk forward over dead for selection
only" OR move rotation entirely server-side (server already does dead-target
redirect at `Room.lua:683-727 _redirectIfDead` — let the server own the cursor too).

### B5. "Other players paralyzed, timer frozen, no garbage to me"
**Symptom:** mid-FFA, only the reporter could play; others appeared frozen.
**Hypothesis:** input relay stalled — could be:
- Server stopped relaying after a partial death (`Room:broadcastInput` or related),
- Client's local engine got pinned waiting on a `G/D` event that never arrived,
- `hasEnded` short-circuited too early for some clients (team-end logic at
  `Match.lua:790-808` recently changed — see B6).
**Action:** correlate `logs/server.log` (look for `Room:broadcastInput` warnings — see
commit `e4ac75b8` which adds diagnostics) with the affected player's session.

### B6. Team match end-condition rewrite — verify FFA still ends
**Where:** `Match.lua:790-808` — `countActiveTeams` was replaced with an inline
isDone() loop for live loose-sync. The patch fixes "remote stack pinned before
game_over_clock," but the per-stack `isDone` path is the live-only one; pure-FFA
modes without `matchEndConditions[TEAMS_ACTIVE]` fall through to the alive-count
path. Verify both reach a terminal state when the last living player dies in
a 4p FFA with no teams.

### B7. Team assignment backwards (2v1 grouped reversed)
**Where:** `common/data/TeamUtils.lua:createTeams` assigns sequentially —
`createTeams(3, 2, {1,2})` produces team1={1}, team2={2,3}. If the host intends
"I'm the solo, you two on the other team" but lands in slot 1, the server puts
them on team1 (solo). What the lobby UI shows vs what the engine assigns may
disagree.
**Action:** in the room joining flow, the joiner's slot (`Room.lua:251-275`) is
"requested-or-first-free." If the lobby UI lets you pick a *team color* but the
slot assignment ignores team intent, players land on the "wrong" team relative
to what they picked. Trace from the join-room invite → slot resolution → team
build. Likely fix is either (a) honor team intent in slot selection, or (b)
swap the team display so what the user sees matches what the server built.

---

## P2 — Audit checklist (flows to walk before next test session)

Bramp's broader concern: silent failures we don't notice until a test session.
Walk each of these locally (server log + client log open, look for warnings),
and add one regression test for any that's currently uncovered.

### Lifecycle flows
- [ ] **1v1 invite:** create → join → ready → match → end → rematch → leave
- [ ] **2v2 invite:** join into specific team slot, verify TeamUtils slot→team
- [ ] **FFA (fixed roster):** 3–4p, all ready, match start, dies in order
- [ ] **Open FFA:** drop-in / drop-out pre-match, match start with sparse roster
- [ ] **Open FFA:** join after match started (spectator queued for next match)
- [ ] **Pre-match leave + rejoin** (held slot) — fixed roster
- [ ] **Pre-match leave + rejoin** — open FFA (no reservation; should it have one?)
- [ ] **Mid-match leave** → `voidByLeave` → remaining players (B3 cascade)
- [ ] **Hard disconnect** (kill client) vs graceful leave — verify cleanup parity

### Spectator flows  (B2 area — high risk)
- [ ] Join pre-match room as pure spectator → ready toggle still works in room?
- [ ] Join mid-match as pure spectator → boards render and update?
- [ ] Join mid-match → garbage `G` events visible on spectator side?
- [ ] Join → player dies → spectator's hasEnded fires correctly?
- [ ] Player dies → uses dead-spectator UI to cycle live boards (`ClientMatch.lua:443`)
- [ ] Leave as spectator mid-match → room not torn down
- [ ] Watch a saved replay (offline) — make sure B1 fix doesn't break this

### Garbage / loose-sync flows  (B4 area)
- [ ] 1v1 vs (both modes still healthy — sanity baseline)
- [ ] 2v2 `garbageMode = "all"` — every teammate's attack hits every enemy
- [ ] 2v2 `garbageMode = "shared"` — round-robin rotation matches across clients
- [ ] FFA "shared" — per-sender cursor advances over living only (currently broken per B4)
- [ ] FFA "all" — single batched `G` event reaches all living targets (`deliverOutgoingGarbageToMultiple`)
- [ ] Simultaneous deaths — KO arbitration window holds (commit `b83f0a6d`)
- [ ] Death during in-flight garbage — server redirects via `_redirectIfDead`
- [ ] Last-attack-during-death — `G` event after sender's `D` event

### Cross-cutting silent failures to probe
- [ ] `server/Game.lua` builds `garbageFlows` with `for i = 1, #replay.stacks` — sparse
  array hazard for open-FFA after a leave. Audit all `#replay.stacks` uses.
- [ ] `tableUtils.indexOf(self.stacks, source)` can return `nil` mid-rebuild;
  several call sites log `-1` and continue rather than bailing. Are we hiding desyncs?
- [ ] `replay.metadata.stacks[i]` vs `replay.stacks[i]` index alignment when roster shrinks.
- [ ] Match `start_match` recomputes teams on every match (`Room.lua:392`). A 2v2
  → leave → 2v1 transition during a series re-keys teams; verify the client's
  `gameMode.teamCount/playersPerTeam` is updated in lockstep or the next match
  builds wrong teams.

---

## Suggested triage assignments

Split by "who can move them in parallel without stepping on each other":

| Owner-ish | Bugs | Reason |
|---|---|---|
| **Server / replay** | B1, B3, B6 | All in the `Match`/`Game`/`Room` boundary; one person should hold the createFromReplay + replay-shape contract. |
| **Loose-sync garbage** | B4, B5 | Garbage rotation + paralysis are almost certainly the same regression; treat as one investigation. |
| **Lobby / teams** | B7 | Isolated to slot↔team mapping & lobby UI; no overlap with the loose-sync work. |
| **Spectator** | B2 | Touches event broadcast fan-out; depends on B1 being fixed before it's testable. |

Suggested order: **B1 → B4 → B2 → B5 → B3 → B7 → B6**.
(B1 unblocks all testing; B4 is the most-cited gameplay regression; B2 is the
"see nothing" spectator case; B5 likely resolves once B4 lands; B7 is cosmetic-
ish until the others are stable.)

---

## Notes
- All testing used relaxed latency mode
- Bramp: "I think I fucked with the checks before I pushed" — recent commits
  `2ab84c08 patch 2.9`, `422e97d3 patch 2.7`, `eeaa2dd0 ffa: round-robin garbage variants`
  are the most likely culprits for B4/B5/B6.
- Client errors occurred on multiple platforms (Linux, macOS) — confirms server-side
  cause rather than environment.
