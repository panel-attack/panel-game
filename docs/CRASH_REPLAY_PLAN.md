# Crash-Replay Capture Plan

Goal: any past game becomes a recreatable test from raw logs.

Every client continuously records what it does. The server tracks
games it should hold logs for (flagged ones). When the dev pulls down
the server's collection via `gather_logs.sh`, a small script reads the
trace files and produces a runnable engine-driven test that reproduces
the exact match.

No clever capture protocol. No structured per-incident slice. The
trace IS the artifact.

> **If you're picking this up cold, start at "Implementation phases"
> below.** The first job is making the client trace tap correct — the
> single test that "logs are good" is whether a recorded local game can
> be exactly recreated from its JSONL. Pull, triggers, and anomaly
> detection are all downstream plumbing that share the same data.
> Don't build them until recreation works.

---

## What's already in place

- **`main.lua:266-316`** — love2D error handler. On any crash during a
  match it already finalizes the in-progress replay and dumps to log.
- **`server/Game.lua:getPartialReplay(true)`** — assembles a complete
  ReplayV3 server-side from in-memory inputs + crossPlayerEvents.
  Stays useful as a *comparison view* (does the trace agree with the
  server's authoritative state?), no longer the primary capture.
- **`Match.createFromReplay`** — given a replay JSON, builds a runnable
  match. The trace-replay path ends here.
- **`server/CrashReports.lua`** — already implements incident registry,
  bucket cap, self-disable, sweeper. Stays — incidents now point at
  trace files instead of holding the only capture.
- **`server/Room.lua`** — already emits `incidentDetected` from
  `voidByLeave`. Stays — trigger taxonomy is unchanged.
- **`gather_logs.sh`** — already pulls `crash_reports/` from the prod
  server. Will need a small extension to also pull `trace_archive/`.
- **love.filesystem** — per-user persistent save dir for the client-side
  trace files. Already used by everything else client-side that
  persists.

---

## The model

```
  ┌─────────────────────────────────────────────────────────────┐
  │  Every client, all the time                                  │
  │                                                              │
  │  socket recv ──┐                                             │
  │  socket send ──┼──▶ JSONL trace file ──▶ love.filesystem    │
  │  local input ──┘     (one per game)                          │
  └─────────────────────────────────────────────────────────────┘
                                  │
                                  │
   ┌──────────────────────────────┴──────────────────────────────┐
   │                                                              │
   ▼                                                              ▼
  ┌─────────────────────┐                              ┌─────────────────────┐
  │  Trigger:           │                              │  Trigger:           │
  │  - server detects   │                              │  - client flags     │
  │    anomaly          │                              │    (crash / F12)    │
  │  - manual admin     │                              │  - eventually:      │
  │  - state-hash mism. │                              │    time-based       │
  └──────────┬──────────┘                              └──────────┬──────────┘
             │                                                    │
             └────────────────────┬───────────────────────────────┘
                                  │
                                  ▼
                  ┌──────────────────────────────┐
                  │  Server:flagGame(gameKey)    │
                  │  marks the game interesting  │
                  └──────────────┬───────────────┘
                                 │
                                 ▼
                  ┌──────────────────────────────┐
                  │  Server pulls trace files    │
                  │  from each participant on    │
                  │  their next quiescent moment │
                  └──────────────┬───────────────┘
                                 │
                                 ▼
                  ┌──────────────────────────────┐
                  │  gather_logs.sh              │
                  │  pulls server-side archive   │
                  └──────────────┬───────────────┘
                                 │
                                 ▼
                  ┌──────────────────────────────┐
                  │  Local assembler script      │
                  │  trace → runnable Match      │
                  │  → checked-in fixture        │
                  └──────────────────────────────┘
```

**Why always-on client capture?** Triggers fire AFTER the bug. If the
data isn't already on disk by the time a trigger fires, it's lost.
Hung-match bugs that don't crash a client (the Amber/Bev/Koozie case)
have no way to retroactively reconstruct themselves; only an
already-running flight recorder gives us their history.

**Why raw bytes + timestamps?** Because anything else is a category
mistake waiting to happen. Every byte the client sent or received is
the ground truth of what happened over the wire. Timestamps order
events across clients. New message types ship? Already captured —
they're just bytes. No schema to keep in sync, no event taxonomy to
maintain.

---

## The trace format

JSONL, one event per line, append-only. Every line carries `ts` (wall
clock seconds, monotonic-ish), `dir` (one of `recv`, `send`, `input`,
`local`), and a `data` payload.

```jsonl
{"ts":1715630423.012,"dir":"recv","prefix":"J","body":{"type":"matchStart","content":{...seed/rules/stacks/garbageFlows...}}}
{"ts":1715630423.025,"dir":"input","raw":"A","frame":1}
{"ts":1715630423.026,"dir":"send","prefix":"I","body":"A"}
{"ts":1715630423.041,"dir":"recv","prefix":"I","body":"A","fromPlayer":2}
{"ts":1715630423.058,"dir":"send","prefix":"G","body":{"senderFrame":120,"recipients":[2,3],"garbage":[...]}}
{"ts":1715630423.077,"dir":"recv","prefix":"G","body":{"sender":1,"senderFrame":120,...}}
{"ts":1715630423.099,"dir":"local","kind":"sceneTransition","from":"CharacterSelect","to":"Game"}
{"ts":1715630423.412,"dir":"local","kind":"stackEliminated","frame":5342}
```

Rules:

- **No structured event taxonomy.** Lines categorize themselves via
  `dir`. The body of `recv` / `send` is the wire payload as-decoded
  (JSON body decoded; raw byte string for `I`/`U`/`V` input prefixes).
- **Frame numbers when available.** Match-engine frame counter
  attached when we know it (`input` events, `local.stackEliminated`,
  etc). Useful for correlating across players whose wall clocks drift.
- **No filtering.** Log everything, sort it later. The cost of logging
  too much is tiny (small text appends); the cost of filtering out
  something later turned out to matter is reproducibility loss.
- **Local-events for forensics, not recreation.** `local` entries
  (scene transitions, local stack-elimination, connection state
  changes) help diagnose but aren't needed for engine replay — the
  matchStart payload + the recv/send streams have everything the
  Match engine needs.

The replay-from-trace recipe:

1. Find the first `recv` line with `body.type == "matchStart"`.
2. Build a Match via `Match.createFromReplay(matchStartBody)`.
3. Walk forward. For each `recv` carrying a cross-player event (G, D,
   K) call `ClientMatch:applyGarbageEvent` / `applyDeathEvent` / etc.
   For each `send` of an input, feed it to this client's stack at the
   recorded frame.
4. Stop at end of file, or at a specific frame for partial-replay
   assertions.

That's the whole recreation contract. Engine determinism does the
rest.

---

## Directory layout

Client-side, under `love.filesystem.getSaveDirectory()`:

```
trace_archive/
  session_<loginTs>/
    match_<roomNumber>_<joinedTs>/         ← new dir on each room join
      game_<gameStartTs>.jsonl             ← one per match-instance
      game_<gameStartTs>.jsonl             ← rematch within same room
    match_<roomNumber>_<joinedTs>/         ← left + rejoined same room
      game_<gameStartTs>.jsonl
```

- A **session** is from successful login to logout/disconnect. Path:
  `session_<loginTs>/`.
- A **match** is one room-join lifetime. Leaving + rejoining the same
  room creates a new `match_<roomNumber>_<joinedTs>/` directory; the
  later `joinedTs` distinguishes them.
- A **game** is one match-instance (one "go" of the game) within the
  match. Multiple games per match are common (best-of-N, rematches).

Repeated info across files is fine — each file is self-contained, so
the assembler doesn't have to stitch.

Server-side, under repo's `trace_archive/`:

```
trace_archive/
  <publicId>/
    session_<loginTs>/
      match_<room>_<joinedTs>/
        game_<gameStartTs>.jsonl
```

Same shape as the client side, namespaced by `publicId`. The server
maintains its own server-perspective trace too, written by the same
machinery but tapping the Server's send/recv pipes — useful as the
authoritative cross-check.

`gather_logs.sh` pulls `trace_archive/` next to `logs/` and
`crash_reports/`.

---

## Retention

Client-side: simple FIFO age cap. Default 7 days; cleared on next
session start. If the server failed to pull a trace within that
window, it's lost — accepted tradeoff for not having to coordinate
"freeze" state with the client.

If we ever need longer retention for a specific gameKey, that's an
additive flag: server tells client "hold trace for game X" on
flagGameAck, client moves it to a keep-forever subdir. Skip for v1.

Server-side: `crash_reports/` bucket cap (already implemented at 100
incidents) governs the registry, but the trace archive is separate and
uncapped within reasonable bounds (server-side traces are not
unbounded because production traffic is bounded). Add an LRU cap
later if it ever matters.

---

## Triggers

Three sources, all funnel through `Server:flagGame(gameKey, reason)` —
the existing entry point already implemented in
`server/CrashReports.lua`.

**Server-detected (server sees it directly):**
- **Mid-match disconnect.** Already wired via `Room:voidByLeave`
  emitting `incidentDetected`.
- **Server-side exception during room handling.** Wrap room dispatch
  in pcall; on error, flag the affected game.
- **Stuck-match watchdog.** Per-second check: if a room's game has
  `livingTeams ≤ 1` and isn't complete for >30 seconds, flag with
  reason `"match_hung"`. This is what would have caught Amber's case.
- **State-hash mismatch (future).** When the loose-sync periodic-hash
  work (`E2E_FIX_COVERAGE_PLAN.md` item 5) lands, mismatches feed the
  same hook.

**Client-nominated (server learns via `flagGame` message):**
- **Client crash.** love error handler writes a "I crashed" marker
  into its `trace_archive/.../game_X.jsonl` and queues a `flagGame`
  for next quiescent send. Already-implemented `flagGame` wire shape
  carries this nomination.
- **User-reported (future F12 hotkey).** Same path, `reason =
  "user_reported"`. Covers "this looked weird" cases that didn't
  throw.

**Time-based (future):** an idle sweeper that flags games whose
duration exceeds an expected upper bound for their game mode.

---

## Server pull

Once `flagGame(gameKey)` accepts, the server needs traces from every
involved client. The wire path:

```
                                 (client logged in, state = "lobby")

server → A:    J{requestTrace, gameKey, sessionPathHint?}
A → server:    J{traceFile, gameKey, lines: "<JSONL bytes>", final}
server → A:    J{traceFileAck, gameKey}
```

Notes:

- **`requestTrace`** carries the `gameKey`. Client looks up the
  matching `game_<gameStartTs>.jsonl` in its `trace_archive/`. If
  multiple matches (same room, same start) — shouldn't happen but
  guard against it — pick the latest by mtime.
- **`traceFile`** ships the file contents as JSONL bytes. For large
  files (rare — traces are small text), chunk via a `final: false`
  flag so the protocol stays a simple sequence rather than introducing
  a separate streaming path.
- **Quiescence:** the rule from the original plan stands —
  `requestTrace` only sent when the player is `lobby` or `spectating`.
  Pull never disturbs an active match.
- **Idempotency:** `traceFileAck` is a no-op on a second receipt; the
  server stores by `(publicId, gameKey)` so a re-send overwrites
  cleanly.

The `crashSlice` / `crashSliceRequest` messages from the earlier plan
revision **are superseded by `traceFile` / `requestTrace`**. The
shape is similar but the payload is just bytes — no structured
ReplayV3 inside. Keep `flagGame` as-is for the nomination side.

---

## Server-side safety

Capture is auxiliary plumbing. If any of it breaks, the server keeps
running games and accepting connections. Every code path on the
server side of this plan must:

1. **Run inside a `pcall`.** All four server entry points —
   `flagGame()`, `handleFlagGame()`, `handleTraceFile()`, the trace
   tap itself — wrap their body in pcall. On error: log, count toward
   the self-disable threshold, return false.
2. **Never modify game state from the collection path.** Trace tap
   reads bytes as they pass through send/recv buffers; it does not
   reorder, drop, or rewrite them.
3. **Soft-fail on disk errors.** A failed write to the trace archive
   is a logged warning, not a thrown exception.
4. **Bound work per call.** No collection path may iterate over all
   active rooms; every operation is scoped to one connection / one
   gameKey.
5. **Refuse to crash on malformed input.** The wire-shape validators
   (sanitizeFlagGame, etc.) type-check + size-bound every field before
   it reaches storage code.
6. **Self-disable on repeated failures.** If the collector errors
   more than 5 times in a 60-second window, log loudly and disable
   for the rest of the process lifetime.

The principle: **collection is best-effort observability, not part of
the gameplay contract.** It works silently or fails silently — never
noisily, never destructively.

---

## Recreation: from trace to runnable test

The assembler is `tools/server_trace_to_fixture.lua`. It reads N
server-side JSONL traces (one per player) from `trace_archive/`,
extracts the matchStart payload, fills in per-stack inputs from each
player's `recv I` lines, aggregates `recv D` and `recv G` events into
`crossPlayerEvents`, and emits a fixture JSON to
`common/tests/fixtures/crash_replays/<name>.json` in the envelope the
existing `CrashReplayRegressionTests.lua` already understands.

**Engine-only.** The recreator does NOT replay through TCP / a real
Server / `TestClient`. We tried — `tools/server_trace_to_bundle.lua` +
the E2E `TraceReplayTests` sweep — and bounced off a wall: the server's
recv tap stores already-decoded J bodies whose shape diverges from what
`TestClient:_replaySendEvent` reproduces on the wire (specifically the
`{type, content}` envelope vs the legacy `{roomRequest=true, ...}`
shape). Reproducing the client-side sanitizer in test code would
double the surface area without buying anything for engine-level bugs.
`Match.createFromReplay` already knows the inputs + crossPlayerEvents
shape; that's all most bugs need.

### One-shot recipe

```sh
# 1. Identify the traces for the bad game. Each player has one
#    session_<loginTs>.jsonl per login lifetime; all participants in
#    the same game share an mtime cluster (server taps flush on the
#    same tick). Most-recent-first:
ls -t trace_archive/*/session_*.jsonl | head -8

# 2. Confirm the cluster you're picking belongs to the SAME game —
#    grep for matching matchStart roomNumbers and stack metadata.
#    Quick check:
for f in trace_archive/{5,7,8,11}/session_<ts>.jsonl; do
  echo "=== $f ==="
  grep -m1 '"matchStart"' "$f" | grep -oE '"name":"[^"]+","publicId":[0-9]+' | head -4
done

# 3. Build the fixture. The fixture name becomes its filename.
#    Order doesn't matter; the script reads metadata.stacks for the
#    publicId→slot mapping.
luajit tools/server_trace_to_fixture.lua wrong_draw_2026_05_13 \
  trace_archive/5/session_1778717170.jsonl  \
  trace_archive/7/session_1778717165.jsonl  \
  trace_archive/8/session_1778717186.jsonl  \
  trace_archive/11/session_1778717182.jsonl
# → common/tests/fixtures/crash_replays/wrong_draw_2026_05_13.json
# → stderr prints per-player: input bytes, D count, G count

# 4. Run the generic sweep first — confirms the engine can ingest
#    your fixture without crashing.
zsh run_tests.sh CrashReplayRegression

# 5. Write or extend a per-incident test (one .lua per incident) under
#    common/tests/engine/. Pattern: copy WrongDrawRegressionTest.lua,
#    swap the FIXTURE_PATH constant + the assertion to whatever the
#    bug specifically asserts. Wire it into testLauncher.lua next to
#    the existing CrashReplayRegressionTests entry.

# 6. Run just the new test until red→green, then run the whole suite.
zsh run_tests.sh WrongDrawRegression       # focused
zsh run_tests.sh                           # full suite, before commit
```

The fixture is checked in to the repo (~170 KB for a 2-minute 4-player
game; the bulk is the input chars). A future regression re-fires the
test the same way.

**Regenerating an existing fixture.** The script refuses to overwrite,
so delete first:

```sh
rm common/tests/fixtures/crash_replays/<name>.json
luajit tools/server_trace_to_fixture.lua <name> trace_archive/...
```

**Pulling traces from prod.** When the bug came from a player on the
production server, `gather_logs.sh` pulls the server's `trace_archive/`
to your local repo before you assemble:

```sh
zsh gather_logs.sh
luajit tools/server_trace_to_fixture.lua <name> trace_archive/<pid>/session_<ts>.jsonl ...
```

### Fixture envelope

```json
{
  "incidentId":   "wrong_draw_2026_05_13",
  "schemaVer":    1,
  "reason":       "from_server_trace",
  "suspectFrame": 8131,
  "perspectives": {
    "5":  { "publicId": 5,  "replay": { ...ReplayV3... }, "gameContext": {...}, "error": "" },
    "7":  { "publicId": 7,  "replay": { ...same... }, ... },
    "8":  { "publicId": 8,  "replay": { ...same... }, ... },
    "11": { "publicId": 11, "replay": { ...same... }, ... }
  }
}
```

Each perspective shares the canonical replay (we already merged the
cross-player events server-side; there's no per-perspective divergence
to preserve here). The replay carries:

- `panelSource`, `rules`, `garbageFlows`, `engineVersion`, `metadata`
  — verbatim from the matchStart the server broadcast.
- `stacks[i].inputs` — concatenated `recv I` body bytes from
  publicId→stackIndex's trace.
- `crossPlayerEvents.deaths` — every `recv D`, sender stamped from
  the trace's publicId.
- `crossPlayerEvents.garbage` — every `recv G`, sender stamped.

### Two assertion shapes

**Sanity sweep** (`CrashReplayRegressionTests.assertFixtureClean`):
runs every perspective's replay through `Match.createFromReplay` +
`match:run()` until `isLocallyEnded()` or the suspect frame, asserts
the engine doesn't crash. Catches "the engine itself broke" but not
outcome bugs.

**Focused per-incident test** — the bug-specific assertion. For the
wrong-draw case, that's `common/tests/engine/WrongDrawRegressionTest.lua`:
it loads the fixture, restores the team setup (`Match.createFromReplay`
doesn't carry teams), applies the recorded deaths to the stacks via
`Stack:recordDeath(senderFrame)`, and asserts `Match:getWinners()`
returns the surviving team — not all four stacks (a "draw").

Pattern for new incidents: copy that file, swap the fixture path and
the assertion. The fixture stays generic; the bug-specific knowledge
lives in the test.

### Caveats found in practice

- **Touch-input traces under-report inputs.** The 2026-05-13 fixture
  shows Koozie sent ~1064 input chars but her engine clock at death
  was 3414. Probably a `send_controls` early-return when the engine
  is buffer-ahead, but it means a stack may run out of inputs before
  reaching its recorded death frame. For getWinners-style tests we
  bypass the engine and stamp `game_over_clock` directly from
  `crossPlayerEvents.deaths`; for tests that need the engine to walk
  forward, we'd need to either pad inputs or set
  `match.fromReplay = false` so the loose-sync bypass treats
  `game_over_clock > 0` as "done" without requiring clock catch-up.
- **`Match.createFromReplay` does NOT consume `crossPlayerEvents`.**
  Only `ClientMatch.createFromReplay` preloads
  `pendingHistoricalDeaths`/`Garbage`. Tests that want engine-driven
  catch-up must either go through ClientMatch or apply the events
  manually.
- **`Match.createFromReplay` does NOT set up teams.** Without
  `match:setTeams(...)` the TEAMS_ACTIVE end-condition never fires
  for team modes. Test setup must call `TeamUtils.createTeams(...)`
  + `match:setTeams(...)`.
- **The trace alone may not reproduce a UI bug.** The 2026-05-13
  wrong-draw incident reproduced through the trace at the engine
  level (`Match:getWinners()` returned the right team), but the live
  UI still showed "DRAW". The bug was in
  `GameBase.buildTeamResultText`'s comparison between Player objects
  and engine Stack objects — only triggered by certain runtime
  shapes that the engine-only fixture doesn't surface. We added
  `[wrong-draw-trace]` `logger.info` lines in `setupGameOver` to
  capture the actual `winners` shape on the next live occurrence; if
  a similar UI-level bug shows up, do the same — instrument the call
  site, ask the user to repro, then read `logs/client.log`.

---

## TDD workflow: every captured trace is a red test waiting

```
  Bug fires in production
       │
       ▼
  Client logs everything to trace_archive/game_X.jsonl
       │
       ▼
  Trigger flags X (server-detected, client-flagged, or manual)
       │
       ▼
  Server pulls trace from each participant + server's own
       │
       ▼
  gather_logs.sh                                ←── pull
       │
       ▼
  assemble_crash_fixture.lua                    ←── one JSON
       │
       ▼
  zsh run_tests.sh                              ←── RED
       │
       ▼
  Fix the bug in production code
       │
       ▼
  zsh run_tests.sh                              ←── GREEN
       │
       ▼
  git commit fix + fixture                       ←── one commit
```

Key properties:

- **The trace IS the spec.** Tests are captured from reality, not
  authored by hand. The captured error or hang condition IS the
  assertion.
- **Fix + fixture land together.** Both touch the same PR. The
  fixture stays in the repo permanently; a future regression
  re-fails immediately.
- **No "I'll write tests later."** The trace lands before the debug
  session begins. You start every debug session with a red test.
- **Silently-green new fixture ⇒ trace is missing data.** Fix the
  capture, not the test.

---

## Implementation phases

### Start here

The single most important piece is the **client trace tap (Phase D)**.
Without it, nothing downstream has anything useful to operate on. The
trigger and pull machinery already partially exists, but it's plumbing
that moves the data — the data quality is what determines whether any
of it works.

**The validation criterion for "logs are correct":** record a local
game (any mode, any outcome), then read the JSONL back through a small
recreate-from-trace helper, drive a fresh `Match` through every event,
and assert the recreated state matches the live one. If recreation
drifts, the trace is missing data — extend the tap, repeat. Don't
move past this gate.

This validation loop is what proves "logs first." Once exact local
recreation passes, the same files work over any pull path — local
disk, server pull, dev download. The downstream pieces become
mechanical.

### The four taps Phase D needs

Each is a small, isolated hook. Get all four right, validate, move on.

1. **Inbound bytes.** Wherever `TcpClient` / `NetClient` pulls a
   complete framed message off the socket. One JSONL line per frame
   received. Decoded JSON for `J`-prefix, raw byte body for input/event
   prefixes (`I`, `U`, `V`, `G`, `D`, `K`, `E`).
2. **Outbound bytes.** Every `sendJson` and every `_sendFrame` call.
   Same shape as inbound, opposite direction.
3. **Local input.** The point where a love key/touch event becomes
   the game input char passed into the engine — before it's
   compressed for the wire. Captures user intent independent of
   network involvement.
4. **Lifecycle markers (cheap, optional but recommended).** Scene
   transitions, match start/end, local stack-elimination, connection
   state changes. Helps the assembler segment files into per-game
   without re-parsing every matchStart payload.

### Where to write

`love.filesystem.getSaveDirectory() .. "/trace_archive/"`, layout per
the [Directory layout](#directory-layout) section. JSONL, one event
per line, append-only, buffered (~1s or 64 events), pcall-wrapped at
every public entry. Per CLAUDE.md, the client save dir is per-user
and persistent — this is safe to write to from any client path,
including the love error handler.

### Phase table (full)

Items marked ✓ are already done under the previous plan revision and
stay relevant in this model.

| Phase | Status | What it does |
|---|---|---|
| A — Bootstrap harness | ✓ | `CrashReplayRegressionTests.lua` runner. Self-tests with programmatic in-memory fixture; sweeps `common/tests/fixtures/crash_replays/`. The inline-ReplayV3 envelope it already accepted is what `tools/server_trace_to_fixture.lua` emits — no loader update needed. |
| B step 1 — Module + Server/Room wire | ✓ | `server/CrashReports.lua` + `Room:incidentDetected` signal. Unchanged — still the trigger funnel. |
| B step 2 — Server-side replay snapshot | ✓ (becomes derived) | `getPartialReplay(true)` writes `<incidentId>/server.json`. Stays as a *comparison view* against the server's own trace; not load-bearing for recreation. |
| B step 3 — 7-day sweeper | ✓ | Ages incidents pending→complete. Unchanged. |
| C step 1 — flagGame wire | ✓ | Client-nominated trigger. Unchanged. |
| D — Client trace tap | ✓ | `client/src/network/TraceWriter.lua` taps recv/send/input + lifecycle markers. Writes to `love.filesystem` save dir. Live in production. |
| D' — Server-side trace tap | ✓ | `server/TraceWriter.lua` taps the server's recv/send. Writes per-publicId session files to `trace_archive/<publicId>/session_<loginTs>.jsonl`. The fixtures we build today come from these files. |
| E — Anomaly detectors | ⏸ | Stuck-match watchdog (catches the Amber/Bev/Koozie case) + redirect-storm detector. Small. |
| C step 2 — Trace pull wire | ⏸ | `requestTrace` / `traceFile` / `traceFileAck`. Replaces the partial `crashSliceRequest`/`crashSlice` work. The wire shape is straightforward once the files exist. |
| F — Assembler script | ✓ | `tools/server_trace_to_fixture.lua`. Reads N server-side traces, emits one fixture JSON in the existing inline-ReplayV3 envelope. Engine-only — does NOT replay through TCP/Server (we tried; bundle approach abandoned, see "Recreation" section above). |
| F' — Runner update | ✓ (no change needed) | The existing inline-ReplayV3 envelope works as-is; the assembler emits into it. Per-incident assertions live in dedicated test files (e.g. `WrongDrawRegressionTest.lua`) — the generic sweep stays narrow ("did the engine survive"). |

### Suggested order

1. **D** — client trace tap + validator. Don't pass go until local
   recreation works.
2. **D'** — server-side trace tap. Same machinery, server-side. Now
   we have both sides of every wire.
3. **E** — stuck-match watchdog. Now real bugs auto-flag, real games
   land in the registry.
4. **C step 2** — trace pull wire. Flagged traces flow to the server.
5. **F + F'** — assembler + runner update. End-to-end: capture →
   flag → pull → assemble → red test → fix → green.

Each of these is a separate small commit. None of them is interesting
work past D + D' until the previous one is green.

---

## What this plan deliberately does NOT do

- **No server-side capture for SERVER crashes.** A server that dies
  can't save its own state. Out of scope.
- **No render-time or frame-rate telemetry.** Just inputs, network
  I/O, and lifecycle events. Not a metrics pipeline.
- **No client-side network upload at crash time.** Trace is on disk
  before any network involvement; shipping happens on the next
  quiescent moment.
- **No anonymization.** Display names are already public-by-design.
- **No structured event taxonomy.** Lines categorize themselves via
  `dir`. No central enum to keep in sync.
- **No multi-perspective StateVector cross-check at fixture-run time.**
  The traces themselves can be diffed offline by humans if needed;
  in-engine assertions stay per-perspective.

---

## Where this slots into the bigger plan

`E2E_FIX_COVERAGE_PLAN.md` lays out the test-infrastructure work
(harness extensions, contract stubs, regression scenarios, matrix
tests). This plan depends on its item 1 (clock injection) for any
arbitration-window assertions; otherwise it's independent.

State-hash detection (item 5 of the E2E plan) is the highest-leverage
future trigger — it would catch silent desync that nothing here
detects. Until state hashes land, "did the match end when it should
have" is the most reliable anomaly signal.

After this plan lands, every captured trace is a one-script assemble
+ one-line `cp` to make a permanent regression test. The B8 fix
incidentally completed the last piece of pre-trace work — every
slice of crossPlayerEvents now flows through `recv` in the trace.
