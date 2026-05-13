# Crash-Replay Capture Plan

Goal: every crash (or "this looks wrong, send help" report) becomes a
deterministic, checked-in regression test that reproduces the bug from
every involved client's perspective. Player runs into bug → server marks
the incident and remembers who was there → each player's next login
ships their slice → dev pulls everything down → local assembly produces
one multi-perspective fixture → bug can never silently return.

The replay format already captures everything the sim needs to reproduce
mid-match state deterministically (panel seed + inputs +
`crossPlayerEvents`). The pieces below wire crash capture to that
format **and** to the server-as-orchestrator pattern so we never end up
with a half-collected incident.

---

## What's already in place (the unblockers)

- **`main.lua:266-316`** — love2D error handler. On any crash during a
  match it already finalizes the in-progress replay and dumps to log.
- **`GAME.crashTrace`** — set at every coroutine fault site so the trace
  points to the actual Lua line, not love's main loop.
- **`server/Game.lua:getPartialReplay(true)`** — produces a self-contained
  `ReplayV3` (now including `crossPlayerEvents` post-B8). Server has all
  the state it needs to capture its own view independently of the
  client.
- **`NetClient:sendErrorReport`** (`client/src/network/NetClient.lua:1166`)
  — wired but currently `if false`-gated for this branch. Plumbing exists.
- **`Server:handleErrorReport`** (`server/server.lua:1226, 1368`) — receive
  side exists; saves via `FileIO.write_error_report`.
- **`Match.createFromReplay`** — already the canonical "given a replay,
  rebuild a runnable match" entry point. Test fixtures load via this.
- **`love.filesystem`** — already used for `crash.log`, `config`, replays.
  Per-user, persistent, safe to write from inside the error handler.
- **`gather_logs.sh`** — already pulls server-side logs / crash reports
  down to the dev machine. The "download the assembled map" step in the
  high-level flow is this script.

---

## The lifecycle (server-orchestrated)

Pull model. The server is the source of truth for "an incident
happened", who was involved, and who has reported in so far. Clients
report on request, not unconditionally. Two-source detection: the
server flags from its own signals (disconnect, exception, future
state-hash mismatch) AND from client-nominated flags ("I crashed in
game X — please look at this game").

```
  ┌────────────────┐    ┌────────────────┐    ┌────────────────┐
  │  A. Incident   │───▶│  B. Server     │───▶│  C. Player     │
  │  triggers      │    │  registers     │    │  next login    │
  │  (server-side: │    │  incident, 	│    │  → drains      │
  │   DC, exc,     │    │  records who   │    │  pending_      │
  │   hash diff)   │    │  was in room   │    │  crashes/ via  │
  │  OR            │    │                │    │  flagGame      │
  │  (client-side: │    │                │    │  THEN ships    │
  │   flagGame on  │    │                │    │  slice on      │
  │   next login)  │    │                │    │  request       │
  └────────────────┘    └────────────────┘    └───────┬────────┘
                                                      │
                                                      ▼
  ┌────────────────┐    ┌────────────────┐    ┌────────────────┐
  │  G. Test       │◀───│  F. Local      │◀───│  D. Server     │
  │  fixture lives │    │  assembly      │    │  records per-  │
  │  in repo;      │    │  (combine all  │    │  player slice  │
  │  drives engine │    │  slices into   │    │  against the   │
  │  per-perspective    │  one JSON      │    │  incident      │
  └────────────────┘    │  fixture)      │    └───────┬────────┘
                        └────────┬───────┘            │
                                 │                    ▼
                                 │            ┌────────────────┐
                                 │            │  E. Incident   │
                                 │            │  complete when │
                                 └────────────│  all expected  │
                                              │  slices in     │
                                              │  → gather_logs │
                                              └────────────────┘
```

**Why server-orchestrated?** A multiplayer crash usually only throws
visibly on ONE client, but the others have load-bearing state too —
their inputs, their reception order for cross-player events, their
local replay of the same match. The current "client unconditionally
uploads what it has" model misses the non-crashing players entirely.
Server-orchestrated means even Bob, who didn't crash, gets prompted on
his next login to ship his view of room 17.

**Why client-nominated flags?** Some crashes never show up server-side
— love errors during render, UI freezes, sim-apply exceptions that
didn't take down the network connection. The client has the signal;
the server doesn't. So the client *nominates* the game ("I crashed
in game X") on its next login. The server still owns flagging — it
validates the nomination (was this client actually in that game?) and
then runs the same orchestration as any other detector.

**Why local assembly?** The server doesn't need to know about the
fixture format. It just needs to safely persist every slice, key them
to an incident, and surface "this incident is collected." The
fixture-assembly step lives next to the test code, which is where the
schema changes live anyway. Decoupling means changes to fixture format
don't ripple back to server protocol.

---

## Identifier model

An **incident** is a server-side record of "something went wrong in
room R at game G around frame F." It has:

- `incidentId` — `<unix-ts>_<roomNumber>_<rand4>`. Stable; the only
  cross-machine identifier in the system.
- `expectedReporters: [publicId]` — frozen at incident-creation time
  from the room's current player + spectator roster. Server already
  knows who they are.
- `collectedReporters: [publicId]` — grows as slices arrive.
- `status` — `"collecting"` until every expected reporter has shipped
  (or the 7-day window closes); then `"complete"`.

A **slice** is one reporter's view of an incident:

- One per `(incidentId, publicId)`.
- Same `ReplayV3` payload shape the existing wire/disk format uses,
  plus the incident-binding metadata (`incidentId`, the reporter's own
  `publicId`, their `clientMeta` and `logTail`).
- Server keeps slices under `crash_reports/<incidentId>/<publicId>.json`.

### Replication contract (the load-bearing bits)

A slice replays deterministically iff it carries every input the
engine consumed to reach the suspect frame. Concretely the `replay`
struct must include:

1. **`panelSource.seed`** — without this every replay produces a
   different panel sequence and nothing matches. Set server-side at
   match-start, broadcast to every player, so every slice already
   carries the same value. Worth pinning explicitly in the assembler:
   abort if two slices disagree on the seed, because that means
   they're from different matches.
2. **`stacks[i].inputs`** — this client's own per-frame input string
   (compressed when `COMPRESS_REPLAYS_ENABLED`). The engine's
   determinism is `(seed, inputs) → outcome`.
3. **`crossPlayerEvents.garbage` + `.deaths`** — every G/D event this
   client received from the server, in the order it received them.
   Two clients in the same match can differ here when one applied
   events the other didn't get to see (the bug class loose-sync is
   trying to lock down).
4. **`matchRules`** — engine behavior is gated by these (countdown
   on/off, win conditions, stack-over conditions). Mismatched rules
   produce non-equivalent replays.
5. **`engineVersion`** + `clientMeta.engineVersion` — surface the
   engine version that captured the slice; the runner can skip
   fixtures that targeted an older engine if panel physics moved.

`gameContext.frame` (separate from `replay`) marks where reality and
this client diverged from the server's view. The runner stops the
engine there to compare state-vectors across perspectives.

If any of (1)-(4) is missing or contradicts the same field on another
slice of the same incident, the assembler refuses to emit a fixture.
That's the guardrail against shipping an under-specified test.

A **fixture** is the result of local assembly:

- One JSON file, checked into `common/tests/fixtures/crash_replays/`.
- Holds every slice of one incident plus the server's own slice
  (server snapshots its view at incident creation).
- The test runner can re-create each client's perspective by loading
  the right slice and driving the engine through it.

---

## Wire shape

Three new JSON messages on the existing `J`-prefixed channel. Same
auth-via-login as every other lobby message.

### `J{ "crashSliceRequest": ... }` — server → client (pull)

Sent on login (or while connected if the client is already online when
the incident fires). One per outstanding incident this player is
expected to report on.

```json
{
  "crashSliceRequest": {
    "incidentId":   "1715630423_2_a3f7",
    "roomNumber":   2,
    "gameId":       17,
    "suspectFrame": 612,
    "reason":       "server_disconnect",
    "schemaVer":    1
  }
}
```

Server's hint to the client about which match the slice should come
from. `gameId` + `roomNumber` lets the client find the right entry in
its local replay buffer / `pending_crashes/` spool.

### `J{ "crashSlice": ... }` — client → server (push, in response)

```json
{
  "crashSlice": {
    "incidentId":   "1715630423_2_a3f7",
    "publicId":     "auto-filled-server-side",
    "schemaVer":    1,

    "error":        "common/engine/Match.lua:712: bad argument #1 to 'insert' (table expected, got nil)",
    "trace":        "stack traceback:\n  ./common/engine/Match.lua:712: in function 'createFromReplay'\n  ...",
    "traceHash":    "a3f7c1",

    "clientMeta": {
      "os":            "macOS",
      "engineVersion": "049",
      "branch":        "bramp/multi-player",
      "loveVersion":   "12.0"
    },

    "gameContext": {
      "roomNumber":   2,
      "gameId":       17,
      "frame":        612,
      "gameModeName": "three_player_vs_shared",
      "matchCount":   3
    },

    "replay":  { /* this client's ReplayV3, including crossPlayerEvents */ },
    "logTail": [ "...", "...", "..." ]
  }
}
```

Field rules:
- **`incidentId`** — must echo the one in the request. Server uses it
  to file the slice under the right incident.
- **`publicId`** — server fills in from the authenticated connection.
- **`error` / `trace`** — populated only when this client was the one
  that crashed. Nil/empty for non-crashing reporters who just shipped
  their view.
- **`replay`** — the full `ReplayV3` *as this client experienced it*.
  Two clients in the same match produce two different replays here:
  same panel seed and same broadcast events, but their local input
  histories and the order they applied cross-player events are
  per-client.
- **`logTail`** — last ~200 lines of `logger.messageBuffer`. Plain
  diagnostic info — useful for context but not load-bearing.

### `J{ "crashSliceAck": ... }` — server → client

```json
{ "crashSliceAck": { "incidentId": "1715630423_2_a3f7" } }
```

Triggers the client to clear the in-flight state for that
`incidentId`. Idempotent: a second ack for the same id is a no-op.

### `J{ "flagGame": ... }` — client → server (nomination)

Small notification sent on next login (or on the next lobby entry)
for each `pending_crashes/` entry the client has on disk. Tells the
server "I crashed in this game — please flag it for collection." The
fat replay payload does NOT travel here; it ships later via the
normal `crashSlice` response when the server asks for it.

```json
{
  "flagGame": {
    "gameKey":      { "roomNumber": 2, "gameId": 17, "startTs": 1715630399 },
    "reason":       "client_crash",
    "traceHash":    "a3f7c1",
    "traceFragment": "common/engine/Match.lua:712: bad argument #1 to 'insert'",
    "clientMeta":   { "engineVersion": "049", "os": "macOS", "loveVersion": "12.0" },
    "schemaVer":    1
  }
}
```

Field rules:
- **`gameKey`** — composite identifier. `roomNumber + gameId + startTs`
  is enough for the server to resolve to a unique past game from its
  own history, even after the room has closed.
- **`reason`** — `"client_crash"` for love-error-handler nominations;
  `"user_reported"` for the future F12 hotkey. Soft signals only —
  hard signals fire server-side.
- **`traceFragment`** — short error excerpt. Lets the server dedupe
  multiple `flagGame`s from a crash loop (same `traceHash` ⇒ already
  flagged ⇒ ignore).

### `J{ "flagGameAck": ... }` — server → client

```json
{
  "flagGameAck": {
    "gameKey":  { "roomNumber": 2, "gameId": 17, "startTs": 1715630399 },
    "accepted": true,
    "incidentId": "1715630423_2_a3f7"
  }
}
```

`accepted: true` ⇒ server has either created an incident for this
game or attached this client's flag to an existing one (idempotent).
The client can keep the `pending_crashes/` file on disk; the server
will ship a `crashSliceRequest` for it shortly.

`accepted: false` ⇒ rejected. `reason` field carries why:
- `"unknown_game"` — server has no record of this gameKey. Client
  deletes the spool file (the data is unrecoverable as a fixture
  anyway).
- `"not_participant"` — client wasn't actually in that game. Client
  deletes the spool file.
- `"bucket_full"` — server's incident bucket is at cap (see Storage
  below). Client KEEPS the file, retries on next handshake.

### What happened to the existing `error_report` path?

The old `error_report` message is superseded by `flagGame`. Same
intent (client → server: "look at this game"), cleaner shape
(structured `gameKey`, no fat `replay` payload — the replay travels
through the slice flow instead). The existing server handler can stay
during transition as an alias that funnels into the same
`Server:handleFlagGame` entry point; remove once the client side has
moved over.

---

## Transport

All five messages travel the existing `J`-prefixed JSON-frame channel
(`sendJson`). Same auth, same retry-on-resend semantics as lobby
traffic.

```
                                 (client logged in, state = "lobby")

A → server:    J<flagGame {gameKey, reason, traceHash, ...}>←J←        ┐
server → A:    J<flagGameAck {gameKey, accepted: true, incidentId}>←J← │ phase 1
                                                                       │ nomination
                                 (server: incident created + own snapshot)
                                                                       ┘

server → A:    J<crashSliceRequest {incidentId, room, game, frame}>←J← ┐
A → server:    J<crashSlice {incidentId, replay, ...}>←J←              │ phase 2
server → A:    J<crashSliceAck {incidentId}>←J←                        │ slice ship
                                                                       ┘
```

Phase 1 is the nomination handshake (a client telling the server
about a crash it observed). Phase 2 is the slice handshake (server
asking every participant — crasher AND non-crashers — for their view).

### Quiescence: only when the player is idle

**Constraint:** the server never sends `crashSliceRequest` (or solicits
`flagGame` drains) while a player is `state == "playing"` or
`"character select"`. Crash-reporting traffic is best-effort plumbing —
disturbing a player mid-match for the sake of forensic data is a UX
regression for zero gameplay benefit.

Concretely, the client drains `pending_crashes/` (sends `flagGame`)
and accepts `crashSliceRequest` only when:

- Just finished login (state has just become `"lobby"`), OR
- Returned to lobby from a match (state transitions `playing/character
  select → lobby`), OR
- Any other point at which the player is not actively engaged.

The server holds `pendingIncidentsFor(publicId)` traffic until the
client's `state` is `"lobby"`; the existing player-state machine in
`Server:processMessage` already tracks this, so the gate is a single
predicate at the dispatch site.

This makes both flag-drain and slice-ship "lobby-time housekeeping"
rather than ambient background traffic. It also naturally bounds how
many messages can pile up between a player's logins — the bucket cap
(see Storage) takes care of the rest.

### Client-side dispatch detail

`crashSliceRequest` is detected in `NetClient:processMessages` (mirror
of the existing JSON dispatch). On receive (while quiescent) the
client:

1. Looks for a matching entry in `pending_crashes/` (if I crashed) or
   in the in-memory replay buffer (if I'm still in or just left the
   match).
2. Builds a `crashSlice` payload.
3. Persists the in-flight slice to `pending_slices/<incidentId>.json`
   so a power loss between request and ack doesn't lose data.
4. `NetClient:sendJson({ crashSlice = payload })`.
5. On `crashSliceAck`: delete the `pending_slices/` file AND the
   original `pending_crashes/` entry (if any) — both phases of the
   two-phase spool are now ack'd.
6. On reconnect / next login: re-send any `pending_slices/` files
   whose `incidentId` the server still asks about.

**Why no network upload at crash time:** the socket is unreliable
inside the error path. Spool to disk, ship on the next quiescent
handshake.

**Why no compression of the envelope:** the replay's input stream
already uses `InputCompression.compressInputTable` when
`COMPRESS_REPLAYS_ENABLED` is true. The heavy bytes are
pre-compressed; the wrapper JSON is small.

---

## Storage

### Server-side: the incident registry

```
<repo>/crash_reports/
    pending_incidents/
        1715630423_2_a3f7.json         ← registry entry, status=collecting
    complete_incidents/
        1715620111_5_b8e2.json         ← status=complete (or 7-day-aged)
    1715630423_2_a3f7/                 ← slice dir per incident
        server.json                    ← server's own view at trigger time
        4.json                         ← reporter publicId=4's slice
        5.json                         ← reporter publicId=5's slice
        8.json                         ← reporter publicId=8's slice
```

- **`pending_incidents/<incidentId>.json`** — the registry. Created on
  trigger; mutated as slices arrive (`collectedReporters` grows); moved
  to `complete_incidents/` when `collectedReporters == expectedReporters`
  or the 7-day window closes.
- **`<incidentId>/server.json`** — captured eagerly at incident
  creation. Server already has `getPartialReplay(true)`; freeze the
  bytes now so a subsequent match doesn't overwrite the state we
  cared about.
- **`<incidentId>/<publicId>.json`** — one per reporter as they ship.
  Server fills `publicId` and `userId` from the authenticated
  connection; the client never sends them itself.
- **Global bucket cap** — at most **100 active incidents** across
  `pending_incidents/` + `complete_incidents/` combined. When the
  bucket is full, new `flagGame` requests get `accepted: false,
  reason: "bucket_full"` and server-side detectors log a warning and
  drop the trigger. The cap is the single defense against runaway
  detectors, hostile flag spam, and "we forgot to pull for two
  months." Self-healing: next `gather_logs.sh` run empties the bucket
  and capacity returns.
- **Per-slice size cap** — 2 MB. A single huge replay can't gobble
  disk; oversized slices get rejected at receive time with a logged
  warning. Belt-and-suspenders, not load-bearing.
- **Participant validation** — when a `flagGame` arrives, the server
  confirms the nominating client was actually in that `gameKey`'s
  participant list. Reject otherwise. This is data-sanity (don't
  collect data from people who weren't there), not a security control.
- **`.gitignore`** — `crash_reports/` is in `.gitignore` alongside
  `logs/`. The directory tree is created on first write.

### Client-side: the spool

```
<love save dir>/pending_crashes/
    1715630423_a3f7c1.json             ← my own crash, awaiting trigger
<love save dir>/pending_slices/
    1715630423_2_a3f7.json             ← my slice awaiting ack
```

- **`pending_crashes/`** — written by `main.lua`'s error handler when
  THIS client crashes. Used as the source data when a future
  `crashSliceRequest` for this incident arrives. Survives process
  death (it's `love.filesystem.getSaveDirectory()`). FIFO-capped at 50
  files.
- **`pending_slices/`** — written when the client has built a slice
  but hasn't yet seen an ack. One file per outstanding
  `(incidentId)`. FIFO-capped at 20.
- Cleared on `crashSliceAck`.

### Dev-side: the pull

`gather_logs.sh` already handles this. After adding a `crash_reports/`
clause it pulls down `complete_incidents/` plus all per-incident slice
directories. No new tooling needed.

### Test fixtures — checked in

```
<repo>/common/tests/fixtures/crash_replays/
    open_team_1v2_createteams_crash.json
    spectator_join_mid_match_b8.json
    sparse_self_players_b10.json
```

- Output of local assembly (see "Assembly" below).
- One file per incident.
- Holds every slice in one JSON document so the test runner doesn't
  need a directory walk.
- Filename is a human-readable bug slug (we pick it, not the
  `<ts>_<room>_<rand>` from the registry).

---

## Server-side safety: the crash-collector must not crash the server

Crash-collection is auxiliary plumbing. If it breaks, the server should
keep running games and accepting connections; it should NEVER take the
process down or interrupt a live match. Every code path on the server
side of this plan must:

1. **Run inside a `pcall`.** All four server entry points —
   `flagGame()`, `handleFlagGame()`, `handleCrashSlice()`, the
   eager-snapshot inside `flagGame()` that calls
   `getPartialReplay(true)` — wrap their body in `pcall`. On error:
   log the trace, return `false, "internal_error"` to the client (if a
   client is waiting on an ack), continue serving normal traffic.

2. **Never modify game state from the collection path.** Snapshot
   functions read; they do not mutate `room.game`, `match.replay`,
   `room.players`, or anything else load-bearing. If a snapshot needs
   a defensive deep-copy, do it. A bug in the collector should not
   corrupt the running match.

3. **Soft-fail on disk errors.** `love.filesystem.write` (or its
   server-side equivalent) failure when writing `<incidentId>/server.json`
   or `<publicId>.json` logs a warning and skips. The incident registry
   entry can still be written; the missing slice is recorded as a
   gap. We'd rather have an incomplete fixture than a dead server.

4. **Bound work per call.** No collection path may iterate over
   all-known-games or all-players. Every operation is scoped to one
   `incidentId` or one `gameKey`. A buggy detector that fires every
   tick costs O(1) per tick, not O(N).

5. **Refuse to crash on malformed input.** `ClientMessages.sanitizeFlagGame`
   and `sanitizeCrashSlice` validate types and bound sizes before any
   payload reaches the storage code. Unknown fields are dropped, not
   propagated; numeric fields outside expected ranges are rejected.

6. **Self-disable on repeated failures.** If `flagGame()` errors more
   than 5 times in a 60-second window, the server logs loudly and
   disables crash collection for the rest of the process lifetime
   (sets a `crashCollectionDisabled` flag). The dev sees the warning
   on next `gather_logs.sh` and can investigate. Prevents a corrupt-state
   loop from filling logs forever.

The principle: **collection is best-effort observability, not part of
the gameplay contract.** It either works silently or fails silently —
never noisily.

---

## The pipeline (6 pieces)

### 1. Incident triggers

All paths funnel through a single hook: `Server:flagGame(gameKey,
reason)`. Called by several detectors, server-side AND client-side:

**Server-side detectors (the server sees it directly):**
- **Mid-match disconnect.** `Room:voidByLeave` — same hook the
  existing synth-death lives at (around `server/Room.lua:1346`).
- **Server-side exception during room handling.** Wrap the room
  dispatch in a pcall (already partially there); on error, flag the
  affected game.
- **State-hash mismatch (future).** When the loose-sync periodic-hash
  work lands (E2E plan item 5), a mismatch fires the same path.

**Client-nominated (the server only learns via `flagGame`):**
- **Client crash.** love error handler wrote
  `pending_crashes/<gameKey>.json` during the crash; on next
  quiescent moment the client sends `flagGame`. Server validates
  and routes to `Server:flagGame`.
- **User-reported (future F12 hotkey).** Same path, `reason =
  "user_reported"`. Covers silent freezes / "this looked weird"
  bugs that never throw.

`Server:flagGame(gameKey, reason)`:

1. Look up the game from history (room.completedGames or
   activeGame). If unknown gameKey → return `false, "unknown_game"`.
2. Bucket cap check. If full → return `false, "bucket_full"`.
3. Dedup by `gameKey + traceHash` for client-nominated flags so a
   crash-looping client doesn't multiply the incident.
4. Mint `incidentId = <unix-ts>_<roomNumber>_<rand4>`.
5. Snapshot the server's own view eagerly via
   `room.game:getPartialReplay(true)` → write
   `<incidentId>/server.json`. The server's view doesn't wait for any
   other actor.
6. Freeze `expectedReporters` from the game's participant+spectator
   roster at this moment.
7. Write `pending_incidents/<incidentId>.json`.
8. Return `true, incidentId`.

Idempotent: a second flag for the same `(gameKey, traceHash)` returns
the existing incidentId without re-snapshotting.

### 2. Server tracks which reporters are still expected

The registry entry's `collectedReporters` set is the truth. The server
exposes:

- `Server:pendingIncidentsFor(publicId)` — returns the list of
  `incidentId`s where `publicId ∈ expectedReporters` and
  `publicId ∉ collectedReporters`.
- Used on login (next step) and any time the player reconnects.

### 3. Client-side quiescent handshake (two phases)

**Files:** `client/src/network/LoginRoutine.lua` for the post-login
entry point; the lobby-return path inside `NetClient.lua` for the
match-end re-entry. Both call the same drainer.

**Quiescence gate:** the drainer only runs when
`GAME.battleRoom == nil` and the client's `state == "lobby"` — i.e.
the player is not in character select, not in a match, not
spectating. If a `crashSliceRequest` arrives while non-quiescent,
the client queues it in memory and drains on next lobby entry.

**Phase 1 — nominate (client → server).** Drain pending crashes the
server doesn't know about:

1. List `pending_crashes/` directory.
2. For each file:
   - Read minimal nomination fields (`gameKey`, `reason`, `traceHash`,
     `traceFragment`, `clientMeta`).
   - Send `flagGame { ... }`.
   - Wait for `flagGameAck`:
     - `accepted: true` → keep file; server will request the full
       slice in Phase 2.
     - `accepted: false, reason: "unknown_game"` or `"not_participant"`
       → delete file (no fixture possible).
     - `accepted: false, reason: "bucket_full"` → keep file, retry next
       quiescence.
3. Cap drains at 5 per quiescence cycle so a player with a deep crash
   pile doesn't block lobby UX for minutes. Remaining files drain on
   the next lobby visit.

**Phase 2 — ship slice (server → client → server).** On every
`crashSliceRequest` received while quiescent:

1. Resolve the request's `roomNumber + gameId` to a local data source:
   - First: `pending_crashes/` entry matching that gameKey (rich crash
     data — same file as the Phase 1 nomination).
   - Then: in-memory replay buffer (if I'm a non-crashing reporter who
     just left the match).
   - Then: on-disk replay history.
   - If none: ship an empty slice (`replay = nil`). The server records
     "this reporter had nothing" rather than waiting forever.
2. Build a `crashSlice` payload.
3. Persist `pending_slices/<incidentId>.json` (so a power loss between
   request and ack doesn't lose data).
4. Ship via `NetClient:sendJson({ crashSlice = payload })`.
5. On `crashSliceAck`: delete the `pending_slices/` entry AND the
   matching `pending_crashes/` file (both phases of the two-phase spool
   are now ack'd).

Phase 1 + Phase 2 may interleave in a single quiescent cycle: the
server can ship a `crashSliceRequest` as soon as its own incident
snapshot is on disk, which is mid-Phase-1.

### 4. Server-side ingestion

**File:** `server/server.lua` — new dispatch on `message.crashSlice`
and `message.flagGame` in `processMessage` (mirror the existing
`error_report` path).

`handleFlagGame(payload, sender)` — runs inside a top-level pcall (see
Server-side safety above). On receive:

1. Validate via `ClientMessages.sanitizeFlagGame` — type checks +
   max-size bounds on every field.
2. Resolve `payload.gameKey` against the game history. If unknown
   → ack with `accepted: false, reason: "unknown_game"`.
3. Confirm the authenticated `sender.publicPlayerID` is in the game's
   participant + spectator roster. If not → ack with
   `accepted: false, reason: "not_participant"`.
4. Call `Server:flagGame(gameKey, payload.reason, payload.traceHash)`.
   The hook handles dedup, the bucket cap, and the eager server-side
   snapshot.
5. Ack with `accepted: true, incidentId = <result>`, or
   `accepted: false, reason: "bucket_full"` if the cap rejected it.

`handleCrashSlice(payload, sender)` — also inside a pcall. On receive:

1. Validate via `ClientMessages.sanitizeCrashSlice` — type checks +
   the 2 MB per-slice byte cap. Oversize → reject + log warning.
2. Confirm `incidentId` exists in `pending_incidents/` AND the
   authenticated `publicId` is in its `expectedReporters`. Reject
   otherwise (silently — could be a stale slice from a closed-out
   incident).
3. Skip-write if `<incidentId>/<publicId>.json` already exists
   (idempotent ack).
4. Write `<incidentId>/<publicId>.json`. On `love.filesystem.write`
   failure: log warning, send `crashSliceAck` anyway (the client
   shouldn't keep retrying for a disk problem).
5. Add `publicId` to the registry's `collectedReporters`.
6. If every expected reporter has now shipped: move the registry
   entry from `pending_incidents/` to `complete_incidents/` and set
   `status = "complete"`.
7. Send `crashSliceAck { incidentId }`.

A daily-ish sweeper (piggyback on the existing
`Server:sweepIdleRooms` cadence) closes out incidents older than 7
days regardless of completion, with `status = "timed_out"`. The
sweeper is itself wrapped in `pcall` — a corrupt registry entry
should not crash subsequent sweeps.

### 5. Dev-side: pull + local assembly

**Step 1 — pull.** `gather_logs.sh` already handles this; extend it
to also pull `crash_reports/`.

**Step 2 — assemble.** New script `scripts/assemble_crash_fixture.sh`
or `assemble_crash_fixture.lua` (run via `luajit` or `love`):

```sh
./scripts/assemble_crash_fixture.sh \
    crash_reports/1715630423_2_a3f7 \
    common/tests/fixtures/crash_replays/open_team_1v2_createteams_crash.json
```

The assembler:

1. Reads the registry entry to confirm the incident is `complete` (or
   `timed_out`, with a `--force` flag).
2. Reads every `<publicId>.json` and `server.json` under the incident
   dir.
3. Emits a single fixture JSON of the shape below.
4. Validates that every slice has the same `roomNumber` + `gameId`
   and that no slice is unparseable. Aborts on inconsistency rather
   than silently shipping a half-broken fixture.

### 6. Fixture shape (the assembly output)

```json
{
  "incidentId":   "1715630423_2_a3f7",
  "schemaVer":    1,
  "reason":       "server_disconnect",
  "suspectFrame": 612,

  "perspectives": {
    "server":  { /* slice */ },
    "4":       { /* slice for publicId=4 */ },
    "5":       { /* slice for publicId=5 */ },
    "8":       { /* slice for publicId=8 */ }
  }
}
```

- `perspectives.server` is always present (server snapshot is eager).
- Each numeric key is a `publicId`. Slices are the same shape sent on
  the wire, minus the wire envelope.
- One fixture = one incident = N perspectives. The test runner
  iterates perspectives and re-creates each client's view
  independently.

---

## Turning a fixture into a runnable test

### TDD workflow: every captured crash is a red test waiting for a fix

The promotion step is **writing the failing test**. The pipeline
naturally produces TDD-shaped artifacts:

```
  Crash in production           ←──── the bug
       │
       ▼
  Slices land server-side
       │
       ▼
  gather_logs.sh                ←──── pull
       │
       ▼
  assemble_crash_fixture.sh     ←──── one JSON in common/tests/fixtures/crash_replays/
       │
       ▼
  zsh run_tests.sh              ←──── RED: fixture reproduces the captured error
       │
       ▼
  Fix the bug in production     ←──── implementation
       │
       ▼
  zsh run_tests.sh              ←──── GREEN: fixture no longer reproduces
       │
       ▼
  git commit fix + fixture      ←──── one commit, both the test and the fix
```

Specific properties of this workflow:

- **The fixture IS the spec.** You don't write the test by hand — you
  capture it from reality. The captured `slice.error` + `slice.trace`
  + `gameContext.frame` ARE the assertion (the error fragment is
  matched in `assertCrashFixed`).
- **The fix and the fixture land together.** PR contains the
  production-code change AND the new fixture JSON. The fixture stays
  in the repo permanently, so a future regression re-fails immediately.
- **No "I'll write tests later."** The capture step happens before
  you debug the issue. You start the debugging session with a red
  test already in hand.
- **Fixture-first invariants.** Even before the fix exists, the
  fixture going red tells you you've captured enough state to
  reproduce. If it's silently green (the crash doesn't reproduce on
  replay), the slice is under-specified — go fix the capture step,
  don't start debugging on a flaky basis.

The runner loop (`runAll` below) iterates every fixture in
`common/tests/fixtures/crash_replays/` and runs each as a discrete
test. CI runs this. A new fixture going red on `main` after a merge =
real regression of a previously-fixed bug.

### Deserialize

```lua
local json     = require("common.lib.dkjson")
local ReplayV3 = require("common.data.ReplayV3")

local function loadFixture(filename)
  local raw = love.filesystem.read("common/tests/fixtures/crash_replays/" .. filename)
  local fixture = json.decode(raw)

  for key, slice in pairs(fixture.perspectives) do
    slice.replay = ReplayV3.createFromV3Data(slice.replay)
  end
  return fixture
end
```

### Drive each perspective

```lua
-- Replays one perspective from the fixture. Returns the match so the
-- caller can read state vectors. stopAtFrame defaults to the slice's
-- gameContext.frame so we don't run past the crash boundary.
local function runPerspective(slice, stopAtFrameOverride)
  local match = Match.createFromReplay(slice.replay)
  match:start()

  local stopAt = stopAtFrameOverride
              or (slice.gameContext and slice.gameContext.frame)
              or (60 * 60 * 30)

  local MAX_FRAMES = 60 * 60 * 30
  local frame = 0
  while not match:hasEnded() do
    match:run()
    frame = frame + 1
    if frame >= stopAt then break end
    if frame > MAX_FRAMES then
      error("replay didn't terminate within " .. MAX_FRAMES .. " frames")
    end
  end
  return match
end
```

### Assert per-perspective, then cross-perspective

```lua
local function assertFixtureClean(fixture)
  local states = {}

  for key, slice in pairs(fixture.perspectives) do
    -- 1. Each perspective replays without exploding. If this slice
    --    was the crash-origin (has slice.error), assert the captured
    --    error fragment is NOT raised again.
    local ok, err = pcall(runPerspective, slice)
    if slice.error and slice.error ~= "" then
      local frag = slice.error:match("[^:]+:%s*(.+)$") or slice.error
      assert(not (not ok and tostring(err):find(frag, 1, true)),
        "perspective " .. key .. " still reproduces the captured crash: "
        .. tostring(err))
    else
      assert(ok,
        "perspective " .. key .. " failed during replay: " .. tostring(err))
    end

    -- 2. Capture state-vector at the suspect frame for cross-perspective check.
    local match = runPerspective(slice, fixture.suspectFrame)
    states[key] = StateVector.fromMatch(match)
  end

  -- 3. Every perspective should agree with the server's view at the
  --    suspect frame. Disagreement is the desync we wanted the
  --    fixture to lock in.
  local serverState = states.server
  for key, state in pairs(states) do
    if key ~= "server" then
      assert(StateVector.equal(serverState, state),
        "perspective " .. key .. " diverges from server at frame "
        .. fixture.suspectFrame .. ":\n"
        .. "  server: " .. StateVector.hash(serverState) .. "\n"
        .. "  " .. key .. ": " .. StateVector.hash(state))
    end
  end
end
```

`StateVector.fromMatch` / `.equal` / `.hash` are the helpers from
`common/tests/engine/StateVector.lua` (already built — see
E2E_FIX_COVERAGE_PLAN.md item 1's harness work).

**The loop:**

```lua
local function runAll()
  local files = love.filesystem.getDirectoryItems("common/tests/fixtures/crash_replays")
  for _, file in ipairs(files) do
    if file:match("%.json$") then
      logger.info("running crash fixture: " .. file)
      local fixture = loadFixture(file)
      assertFixtureClean(fixture)
    end
  end
end
```

### What this catches and what it doesn't

**Catches:**
- Engine logic bugs reproducible from `(panelSource seed + inputs +
  crossPlayerEvents)` — the bulk of B1/B8/B9/B10-class bugs.
- Per-client state divergence at known frames — the
  cross-perspective assert flags any client whose view stops matching
  the server's at the suspect frame.
- Anything that throws an exception during sim run — even bugs the
  original capture wasn't about, if the replay happens to exercise
  that path.

**Doesn't catch:**
- **Client-only UI bugs.** Sim state may be fine; the crash was in
  scene/render code. The replay is replayable but the failure mode
  wasn't in the engine. These need a `ClientMatch` test instead —
  same fixture, different runner.
- **Engine-version skew.** A fixture captured on engine `049` won't
  reproduce identically on `050` if the bump changed panel physics.
  Mitigation: pin each fixture's `clientMeta.engineVersion`; the
  runner skips with a warning if the live engine version differs. Or,
  more honestly, bump fixtures when you bump engine.
- **Real-time effects.** Anything that depends on `socket.gettime()`
  / wall clock (most of arbitration). The captured replay only
  contains game-frame-driven state — wall-clock dependencies need
  the clock injection from `E2E_FIX_COVERAGE_PLAN.md` item 1
  (already in place via `Server.clock` / `Room.clock`).

### Bootstrap: prove the TDD round-trip works with a known-fixed bug

Before trusting the pipeline on novel crashes, prove it can go red AND
green for a bug whose fix is already understood. This is the dry run.

Pick a recently-fixed bug — B9 (Open Team 1v2 crash) or B10 (sparse
self.players broadcast) are good candidates because their fixes are
small and isolated.

1. **Build a fixture by hand** matching the captured shape (skip the
   server-orchestrated capture; just author the JSON directly). The
   fixture should contain enough state to reproduce the crash
   pre-fix.
2. **Run the test → expect green** (bug is fixed; replay no longer
   crashes). Confirms the assertion runs without firing.
3. **Revert the production fix** (`git revert` or manually undo the
   change in `server/Room.lua` etc.). Run the test → **expect red**
   with the captured error fragment in the failure message. Confirms
   the test can ACTUALLY detect the regression.
4. **Re-apply the fix.** Run the test → green again. Confirms the
   green wasn't a false positive.

If the round-trip works for a known bug, the harness is reliable for
unknown ones. The test will go red for the next un-fixed crash, then
green when the fix lands — that's the TDD contract from then on.

If step 3 stays green (test doesn't fail after reverting the fix),
the fixture is under-specified. The captured slices don't include
enough state to reproduce the bug — usually because a load-bearing
field is missing from the replay or `gameContext.frame` is too late.
Fix the capture step before adding more fixtures.

---

## Optional, free-once-the-pipeline-exists

- **Manual "report this match" hotkey.** Add a debug-only binding
  (e.g. F12) that posts an `error_report` with `reason =
  "user_reported"` and no trace. The server creates an incident with
  the room's full roster as `expectedReporters` just like a
  disconnect would. Covers silent freezes / B5-class bugs that don't
  throw.

- **State-hash auto-capture.** When the loose-sync hardening plan's
  Step 5 (periodic state hashes) lands, mismatches feed the same
  incident-creation path with `reason = "state_hash_mismatch"`. Now
  you have multi-perspective capture of *silent* desync, not just
  crashes.

- **Server-side incident dashboard.** `pending_incidents/` is a flat
  directory of one-line JSON entries — a 10-line shell script can
  summarize "5 incidents collecting, 12 complete, 1 timed out." Run
  on the box during gather_logs runs.

---

## What this plan deliberately does NOT do

- **No server-side crash capture for SERVER crashes.** A server that
  dies can't save its own state. If we want this, add a periodic
  state-checkpoint writer separately — out of scope.
- **No telemetry beyond crash events.** Not a metrics pipeline, not
  an analytics system. Just "this thing broke, here's the repro."
- **No client-side network upload at crash time.** Spool to disk,
  ship on the next handshake.
- **No anonymization.** Game's display names are already
  public-by-design.
- **No server-side fixture assembly.** The server stores raw slices;
  the dev box does the assembly via the local script. Keeps schema
  changes co-located with the test code.

---

## Where this slots into the bigger plan

`E2E_FIX_COVERAGE_PLAN.md` lays out the test-infrastructure work. This
plan depends on its item 1 (clock injection + StateVector) for the
cross-perspective assert; otherwise it's independent. Once both
pipelines exist, they compose: state-hash mismatch
(`E2E_FIX_COVERAGE_PLAN.md` item 5) → incident creation (this plan) →
all reporters ship slices → local assembly → checked-in fixture → CI
catches re-regression.

After the pipeline lands, every captured incident is a one-script
assemble + one-line `cp` to make a permanent regression test. The B8
fix incidentally completed the last missing piece by making
`getPartialReplay` self-contained — without it, captured mid-match
crashes wouldn't reproduce.
