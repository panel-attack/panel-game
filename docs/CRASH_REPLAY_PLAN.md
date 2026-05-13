# Crash-Replay Capture Plan

Goal: every crash (or "this looks wrong, send help" report) becomes a
deterministic, checked-in regression test. Player runs into bug → server
captures both sides → fixture promoted to test → bug can never silently
return.

The replay format already captures everything the sim needs to reproduce
mid-match state deterministically (panel seed + inputs +
`crossPlayerEvents`). The pieces below wire crash capture to that format.

---

## What's already in place (the unblockers)

- **`main.lua:266-316`** — love2D error handler. On any crash during a
  match it already finalizes the in-progress replay and dumps to log.
- **`GAME.crashTrace`** — set at every coroutine fault site so the trace
  points to the actual Lua line, not love's main loop.
- **`server/Game.lua:getPartialReplay(true)`** — produces a self-contained
  `ReplayV3` (now including `crossPlayerEvents` post-B8). Server has all
  the state it needs to capture independently of the client.
- **`NetClient:sendErrorReport`** (`client/src/network/NetClient.lua:1166`)
  — wired but currently `if false`-gated for this branch. Plumbing exists.
- **`Server:handleErrorReport`** (`server/server.lua:1226, 1368`) — receive
  side exists; saves via `FileIO.write_error_report`.
- **`Match.createFromReplay`** — already the canonical "given a replay,
  rebuild a runnable match" entry point. Test fixtures can load via this.
- **`love.filesystem`** — already used for `crash.log`, `config`, replays.
  Per-user, persistent, safe to write from inside the error handler.

---

## Wire shape

Single JSON document. Lives on disk client-side as a `.json` file under
`pending_crashes/` (in `love.filesystem`), travels the existing TCP
channel as the body of a `crashReport`-tagged JSON message, lands
server-side as a `.json` file under `crash_reports/<userId>/`.

```json
{
  "reportId":   "1715630423_a3f7c1",
  "reason":     "crash",
  "schemaVer":  1,

  "error":      "common/engine/Match.lua:712: bad argument #1 to 'insert' (table expected, got nil)",
  "trace":      "stack traceback:\n  ./common/engine/Match.lua:712: in function 'createFromReplay'\n  ...",
  "traceHash":  "a3f7c1",

  "clientMeta": {
    "os":            "macOS",
    "engineVersion": "049",
    "branch":        "bramp/multi-player",
    "loveVersion":   "12.0",
    "userId":        "auto-filled-server-side"
  },

  "gameContext": {
    "roomNumber":   2,
    "gameId":       17,
    "frame":        612,
    "gameModeName": "three_player_vs_shared",
    "matchCount":   3
  },

  "replay":  { /* ReplayV3 JSON, including crossPlayerEvents */ },

  "logTail": [
    "05/12/26 22:11:01.515 INFO:Room 2 readiness after Lala update: ...",
    "05/12/26 22:11:01.516 INFO:Starting match 1 for 2 Bevy vs Koozie vs Lala",
    "05/12/26 22:11:01.516 ERROR:Error: ./common/data/TeamUtils.lua:37: ..."
  ]
}
```

Field rules:
- **`reportId`** — `<unix-ts>_<traceHash6>`. Stable across retries so
  the server can ack idempotently and the client knows which file to
  delete. Survives a power loss + relaunch.
- **`reason`** — one of `"crash"` (love error handler), `"user_reported"`
  (F12 hotkey), `"server_disconnect"` (server-side auto-capture), or
  `"state_hash_mismatch"` (future, from the state-hash work).
- **`schemaVer`** — bump if we ever change the shape. Older fixtures
  with `schemaVer < N` get migrated on load.
- **`traceHash`** — 6-hex-char hash of the trace. Used for dedup so the
  same bug doesn't pile up.
- **`gameContext`** — `null` if the crash happened pre-match.
- **`replay`** — the full `ReplayV3` from `getPartialReplay(true)`. Has
  panelSource seed, per-stack inputs (compressed), and `crossPlayerEvents`.
  This is the only field load-bearing for replay-based regression.
- **`logTail`** — last ~200 lines of `logger.messageBuffer`. Plain
  diagnostic info — useful for context but not load-bearing.

Server-side auto-capture (the disconnect path) uses the same shape with
`reason = "server_disconnect"` and `replay` populated from
`room.game:getPartialReplay(true)`. Everything else identical.

## Transport

**Client → server.** Wraps in the existing JSON-frame protocol — the `J`
prefix used by `sendJson`. Same channel as every other lobby/room
message, authenticated by the already-active login session.

```
sender → server:    J<crashReportEnvelope>←J←
server → sender:    J<crashReportAckEnvelope>←J←
```

Envelopes:
```
crashReportEnvelope    = { "crashReport":    <payload above> }
crashReportAckEnvelope = { "crashReportAck": { "reportId": "..." } }
```

The `crashReport` field is detected in `Server:processMessage` (same
spot as the existing `error_report` dispatch), routed to a new
`handleCrashReport` method on the server, parsed via a new
`ClientMessages.sanitizeCrashReport`.

**Why JSON over the regular socket, not a side channel:**
- We already have an auth'd connection at login time. Reusing it is free.
- TCP gives us reliable delivery + retry-on-resend.
- No new infra (no S3, no separate HTTP service) for this branch.

**Why no compression of the envelope itself:** the replay's input
stream already uses `InputCompression.compressInputTable` when
`COMPRESS_REPLAYS_ENABLED` is true — the heavy part is pre-compressed.
The wrapper JSON is small. If a single payload ever exceeds the connection
queue size, we'll add Deflate, but skip for now.

## Storage

### Client-side spool — `love.filesystem`

```
<love save dir>/pending_crashes/
    1715630423_a3f7c1.json
    1715631002_d22e93.json
```

- `love.filesystem.write` is used inside `main.lua`'s error handler.
- Survives process death (it's `love.filesystem.getSaveDirectory()`).
- Per-user (one save dir per OS user).
- Cap at 50 files. If we'd write the 51st, FIFO drop the oldest. A
  loop-crashing client doesn't fill the user's disk.
- Cleared on successful upload + ack.

### Server-side reports — repo-relative

```
<repo>/crash_reports/
    <publicId>/
        1715630423_a3f7c1.json     ← from client
        1715631002_d22e93.json
    server_side/
        <publicId>_1715630500_disconnect.json
        <publicId>_1715631100_disconnect.json
```

- Directory created on first write. Added to `.gitignore` alongside `logs/`.
- Keyed by **publicPlayerID** (stable across rejoins, server already knows it).
- Per-user dedup: skip write if a file with the same `traceHash` already
  exists in that user's directory.
- Per-user rate limit: max 20 reports per UTC day. Beyond that, accept
  the message + ack but skip the file write (don't punish the client
  with retries that'll never succeed).
- LRU cap per user: keep the most recent 100 reports per user; trim
  oldest beyond that.
- `server_side/` is independent: one snapshot per mid-match disconnect,
  no dedup (each is a real distinct event). Same LRU cap.

### Test fixtures — checked in

```
<repo>/common/tests/fixtures/crash_replays/
    open_team_1v2_createteams_crash.json
    spectator_join_mid_match_b8.json
    sparse_self_players_b10.json
```

- Same JSON shape as the captured reports.
- Filename is a human-readable bug slug (we picked, not the auto-named
  `<ts>_<hash>` from the capture).
- Loaded by `CrashReplayRegressionTests.lua` (item 5 below).
- One-line promotion: `cp crash_reports/<publicId>/<file> common/tests/fixtures/crash_replays/<slug>.json`.

### Correlation between client and server reports

When a client report arrives, the server can find its own counterpart by:
1. `crashReport.clientMeta.userId` (filled in server-side at receive time)
   → match `publicId` directory.
2. `crashReport.gameContext.gameId` (if present) and timestamp within
   ~10s window → find the matching `server_side/<publicId>_*.json`.
3. Diff the two replays at `gameContext.frame` — that's where reality
   and the client's view started disagreeing.

Optional: at the moment a correlated pair is detected, write a
`crash_reports/<publicId>/<ts>_correlated.json` that points to both
files. Saves diffing time later.

---

## The pipeline (5 pieces)

### 1. Client-side spool to disk at crash time

**File:** `main.lua` (extend the existing error handler at line 266).

When an error fires during a match:
1. Build a payload struct in-process (no network, no async):
   ```
   {
     reportId  = ts .. "_" .. traceHash,
     reason    = "crash",
     error     = sanitizedMessage,
     trace     = sanitizedTrace,
     clientMeta = {
       os           = love.system.getOS(),
       engineVersion = ENGINE_VERSION,
       branch       = "bramp/multi-player",
     },
     gameContext = match and {
       roomNumber = GAME.battleRoom.roomNumber,
       gameId     = match.replay.metadata.gameId,
       frame      = match.engine.clock,
     } or nil,
     replay      = match and match.replay or nil,
     logTail     = last_n_lines(logger.messageBuffer, 200),
   }
   ```
2. `love.filesystem.write("pending_crashes/" .. reportId .. ".json", json.encode(payload))`.
3. Continue with the existing crash flow — `crash.log`, error screen, etc.

**Important:** no network calls in the error path. The socket may be in
an indeterminate state; the goal is "get it to disk safely, ship later."

### 2. Client-side drain at login

**File:** `client/src/network/LoginRoutine.lua` (or right after
`loginSuccess` lands in `NetClient.lua`).

After successful login:
1. `local files = love.filesystem.getDirectoryItems("pending_crashes")`.
2. For each file:
   - Read + decode JSON.
   - Send via `NetClient:sendJson({ crashReport = payload })`.
   - Wait for `crashReportAck { reportId }` with timeout (say 5s).
   - On ack: `love.filesystem.remove("pending_crashes/" .. file)`.
   - On timeout: leave the file, next login retries.
3. Rate-limit: drain at most 5 per session so a player with a stuck
   crash loop doesn't spam every login.

### 3. Server-side receive + dedup

**File:** `server/server.lua` — new dispatch on `message.crashReport`
in `processMessage` (mirror the existing `message.error_report` path).

On receive:
1. Validate the payload via a new `ClientMessages.sanitizeCrashReport`.
2. Compute `traceHash = hash(payload.trace)`. Skip write if we already
   have a file with that hash in `crash_reports/<userId>/`.
3. Write `crash_reports/<userId>/<ts>_<traceHash>.json`. New directory,
   add to `.gitignore` alongside `logs/`.
4. Send `crashReportAck { reportId = payload.reportId }`.
5. Per-user rate-limit (e.g. 20 reports/day) to prevent disk-fill from
   a stuck client.

### 4. Server-side auto-capture on mid-match disconnect

This is the big multiplier: even if the client's machine dies hard and
never logs back in, we still get the server's view.

**File:** `server/Room.lua` — hook in `Room:voidByLeave` right after
`markPlayerEliminated` for the synth-death path (around the existing
synth-death block).

```lua
if not self.game.eliminatedPlayers[leaver.player_number] then
  -- ... existing synth-death ...

  -- Side-of-the-truth: capture the server's view of this match so we
  -- can correlate when the client's report eventually shows up.
  local snapshot = {
    reportId   = os.time() .. "_disconnect",
    reason     = "server_disconnect",
    userId     = leaver.userId,
    publicId   = leaver.publicPlayerID,
    roomNumber = self.roomNumber,
    deathFrame = deathFrame,
    replay     = self.game:getPartialReplay(true),
  }
  FileIO.write_crash_report(snapshot)
end
```

**Correlation:** when the client's report lands later, match by
`userId + (gameId or close-by ts)`. Diffing client-replay vs server-replay
at the death frame is the desync-root-cause-finder.

### 5. Test fixtures + regression loader

**Directory:** `common/tests/fixtures/crash_replays/`. Checked in.

**File:** `common/tests/engine/CrashReplayRegressionTests.lua` — new file,
runs under `zsh run_tests.sh` (needs love2D for the engine).

```lua
for _, fixture in ipairs(love.filesystem.getDirectoryItems("common/tests/fixtures/crash_replays")) do
  local payload = json.decode(love.filesystem.read("common/tests/fixtures/crash_replays/" .. fixture))
  local match = Match.createFromReplay(payload.replay)
  -- Run to completion (or to the recorded frame); assert no error.
  local ok, err = pcall(function()
    while not match:hasEnded() do
      match:run()
    end
  end)
  assert(ok, "crash fixture " .. fixture .. " still reproduces: " .. tostring(err))
end
```

**Promoting a captured crash:**
```sh
cp crash_reports/<userId>/<ts>_<hash>.json common/tests/fixtures/crash_replays/<descriptive_name>.json
```
That's it. The fixture is now a permanent regression test. CI fails the
day someone reintroduces the bug.

---

## Optional, free-once-the-pipeline-exists

- **Manual "report this match" hotkey.** Add a debug-only binding (e.g.
  F12) that builds the same payload with `reason = "user_reported"` and
  writes it to `pending_crashes/`. Same upload path. Covers silent
  freezes / B5-class bugs that don't throw.

- **State-hash auto-capture.** When the loose-sync hardening plan's
  Step 5 (periodic state hashes) lands, mismatches feed the same
  pipeline with `reason = "state_hash_mismatch"`. Now you have
  multi-perspective capture of *silent* desync, not just crashes.

---

## What this plan deliberately does NOT do

- **No server-side crash capture for SERVER crashes.** A server that
  dies can't save its own state. If we want this, add a periodic
  state-checkpoint writer separately — out of scope.
- **No telemetry beyond crash events.** Not a metrics pipeline, not an
  analytics system. Just "this thing broke, here's the repro."
- **No client-side network upload at crash time.** Spool to disk, ship
  on next login. The socket is unreliable in the error path.
- **No anonymization.** Game's display names are already public-by-design.

---

After the pipeline lands, every captured crash is a one-line `cp` to
make a permanent regression test. The B8 fix incidentally completed the
last missing piece by making `getPartialReplay` self-contained — without
it, captured mid-match crashes wouldn't reproduce.

---

## Where this slots into the bigger plan

`E2E_FIX_COVERAGE_PLAN.md` lays out the test-infrastructure work. This
plan is independent of items 1–4 there (harness extensions, contract
stubs, regression scenarios, matrix tests) but feeds them — every crash
captured here can become a fixture in item 3's regression scenarios or
item 4's matrix tests.

Suggested ordering: this plan can run in parallel with
`E2E_FIX_COVERAGE_PLAN.md` items 1–2. Once both pipelines exist, they
compose: state-hash mismatch (`E2E_FIX_COVERAGE_PLAN.md` item 5) →
auto-capture (this plan) → checked-in fixture → CI catches re-regression.
