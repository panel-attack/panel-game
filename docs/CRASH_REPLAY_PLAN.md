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

The assembler script lives at `scripts/assemble_crash_fixture.lua`.
Reads one or more JSONL trace files for the same `gameKey`, emits a
fixture JSON checked into `common/tests/fixtures/crash_replays/`.
Fixture shape is itself trivial:

```json
{
  "gameKey":     { "roomNumber": 6, "startTs": 1715630423 },
  "reason":      "match_hung",
  "schemaVer":   1,
  "traces": {
    "server":  "<JSONL bytes from server's view>",
    "8":       "<JSONL bytes from publicId 8's view>",
    "5":       "<JSONL bytes from publicId 5's view>",
    "11":      "<JSONL bytes from publicId 11's view>"
  }
}
```

The test runner (`common/tests/engine/CrashReplayRegressionTests.lua`,
already in place) iterates each trace and replays per-perspective:

```lua
local function recreate(jsonl)
  local lines = parseLines(jsonl)
  local matchStart = findFirst(lines, function(l)
    return l.dir == "recv" and l.body.type == "matchStart"
  end)
  assert(matchStart, "trace must begin with a matchStart recv")

  local replay = ReplayV3.createFromV3Data(matchStart.body.content)
  local match  = Match.createFromReplay(replay)
  match:start()

  for _, line in ipairs(lines) do
    if line.dir == "recv" and line.prefix == "I" then
      -- inject relayed input
    elseif line.dir == "recv" and line.prefix == "G" then
      match:applyGarbageEvent(line.body)
    elseif line.dir == "recv" and line.prefix == "D" then
      match:applyDeathEvent(line.body)
    elseif line.dir == "send" and line.prefix == "I" then
      -- this client's input — feed local stack
    -- ... etc ...
    end
  end
  return match
end
```

The assertion shape depends on `reason`:

- **`client_crash`** — the trace has the captured error; assert
  recreation doesn't re-fire the same error fragment.
- **`match_hung`** — assert the match reaches a terminal state within
  the recorded frame range. The Amber case fails this: recreation
  also hangs, until the arbitration bug is fixed.
- **`user_reported`** — no automatic assertion; the human author
  inspects the trace and writes a targeted assertion.

Promotion to checked-in fixture is `cp` from the gather'd directory to
`common/tests/fixtures/crash_replays/<human-readable-slug>.json`.

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
| A — Bootstrap harness | ✓ | `CrashReplayRegressionTests.lua` runner. Self-tests with programmatic in-memory fixture; sweeps `common/tests/fixtures/crash_replays/`. Stays — fixture loader will need a small update for the trace-bundle shape (mechanical). |
| B step 1 — Module + Server/Room wire | ✓ | `server/CrashReports.lua` + `Room:incidentDetected` signal. Unchanged — still the trigger funnel. |
| B step 2 — Server-side replay snapshot | ✓ (becomes derived) | `getPartialReplay(true)` writes `<incidentId>/server.json`. Stays as a *comparison view* against the server's own trace; not load-bearing for recreation. |
| B step 3 — 7-day sweeper | ✓ | Ages incidents pending→complete. Unchanged. |
| C step 1 — flagGame wire | ✓ | Client-nominated trigger. Unchanged. |
| **D — Client trace tap** | **⏸ START HERE** | Socket recv/send + input hook → JSONL writer to `trace_archive/`. Includes the recreate-from-trace validator. Until this is green, everything else is theoretical. |
| D' — Server-side trace tap | ⏸ | Mirror Phase D on the server side: tap Server's send/recv, write per-room JSONL into `<rootDir>/trace_archive/<publicId>/...`. Same writer logic — share a module. |
| E — Anomaly detectors | ⏸ | Stuck-match watchdog (catches the Amber/Bev/Koozie case) + redirect-storm detector. Small. |
| C step 2 — Trace pull wire | ⏸ | `requestTrace` / `traceFile` / `traceFileAck`. Replaces the partial `crashSliceRequest`/`crashSlice` work. The wire shape is straightforward once the files exist. |
| F — Assembler script | ⏸ | `scripts/assemble_crash_fixture.lua`. Reads per-client trace files for one gameKey, emits one fixture JSON. Small. |
| F' — Runner update | ⏸ | `CrashReplayRegressionTests.lua` learns the trace-bundle fixture shape (currently expects ReplayV3 inline). Mechanical. |

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
