# Trace-Replay Shape Fix Plan

> Three phases. Phase 1 fixes the immediate failure. Phase 2 closes the
> class of bug across all other reshaping sanitizers. Phase 3 makes the
> "trace == wire" invariant structural so this bug can't return.
> The user's framing: "Is there a way we could reuse exactly the same
> functions? I just don't want other things to happen like this."

## Problem

The E2E trace-replay suite fails because **server-side trace capture
records a different message shape than what real clients send on the
wire**. Replaying a captured trace then drives the server with a shape
its dispatcher doesn't recognize, the connection is dropped, and
downstream tests cascade-fail.

### Failure observed (logs/e2e.log, 20:02:24)

```
ERROR:Received an unexpected message:
  {"latencyTolerance":"normal","roomRequest":true,"openRoom":true,
   "gameMode":{...,"name":"team_vs_all",...}}
Closing connection 4 to P5_a953d7
E2E suite FAILED with 3 error(s):
  [1] server/tests/E2E/ThreePlayerFFATests.lua:100  not all clients transitioned to ROOM state
  [2] server/tests/E2E/RegressionTests.lua:188      match did not start
  [3] [E2E Harness] 1 server-side error(s) logged ... Received an unexpected message
```

Errors 1 and 2 are cascade symptoms — once connection 4 is dropped, the
3-player FFA can't reach `ROOM` and the regression match can't start.

### Root cause

`server/server.lua:1368-1380` (`Server:processMessage`):

```lua
message = json.decode(message)                          -- (1) wire shape
message = ClientMessages.sanitizeMessage(message)       -- (2) flat sanitized shape
pcall(function()
    ...
    TraceWriter.recv(pid, "J", message)                 -- (3) records (2), not (1)
end)
```

| | shape |
|---|---|
| **Wire (real client)** | `{ type: "roomRequest", content: { gameMode, latencyTolerance, openRoom } }` |
| **Sanitized (recorded)** | `{ roomRequest: true, gameMode, latencyTolerance, openRoom, seed }` |

Dispatcher at `server/ClientMessages.lua:35` routes by
`type == "roomRequest"`. Flat shape has no `type` field → falls through
to the error path on replay.

Introduced in commit `0aa88f66` ("crash-replay: Phase D' — server-side
trace tap").

### Why this isn't a one-off

Five **other** sanitizers in `server/ClientMessages.lua` also reshape
their input. Today, only `roomRequest` is replayed in tests — but the
same trap is set for every one of them:

| Sanitizer | Wire shape | Sanitized output | Reshape |
|---|---|---|---|
| `sanitizeMenuState:76` | `{menu_state: {...}}` | `{playerSettings: {...}}` | top-level key renamed |
| `sanitizeLoginRequest:108` | `{login_request, user_id, ...}` flat | calls `sanitizeMenuState` → `{playerSettings, login_request, ...}` | keys nested under `playerSettings` |
| `sanitizeLeaderboardRequest:198` | `{leaderboard_request, leaderboardType}` | `{leaderboard_request, gameModeId}` | key renamed |
| `sanitizeMatchAbort:317` | `{type:"matchAbort", recipientId, content}` | `{roomNumber, matchAbort:true}` | `type` dropped, `recipientId`→`roomNumber` |
| `sanitizePauseToggle:327` | `{type:"pauseToggle", recipientId, content}` | `{roomNumber, paused, type:"pauseToggle"}` | `content`→`paused`, `recipientId`→`roomNumber` |

Phase 1 fixes capture for all six (the tap moves above sanitization).
Phase 2 retires each sanitizer's legacy/fallback inputs. Phase 3 makes
the invariant load-bearing in CI.

## Architecture goal

```
                  ┌─ live socket ─┐
                  │               ▼
  raw JSON bytes ─► processMessage ─► decode ─► RECORD ─► sanitize ─► route
                  ▲                                          
                  │                                          
                  └────── TestClient.sendJson(body) ◄──── replay reads RECORD
```

Recording sits between `decode` and `sanitize` so captured bodies are
byte-equivalent to what a real client put on the wire.

---

## Phase 1 — Minimal symptom fix

Five small steps, each touching one file. Unblocks E2E.

### Step 1.1 — Move the J-recv tap above sanitization

**File:** `server/server.lua:1368-1380`

```lua
-- Before
message = json.decode(message)
message = ClientMessages.sanitizeMessage(message)
pcall(function() ... TraceWriter.recv(pid, "J", message) end)

-- After
message = json.decode(message)
pcall(function() ... TraceWriter.recv(pid, "J", message) end)
message = ClientMessages.sanitizeMessage(message)
```

One reorder. Verified safe by feasibility review: no code between
`json.decode` and `sanitizeMessage` mutates `message`, and downstream
branches read fields preserved in both shapes.

### Step 1.2 — Delete dual-shape support in `sanitizeRoomRequest`

**File:** `server/ClientMessages.lua:246-305`

After Step 1.1 no caller produces the flat shape. Strip:
- Lines 259-264 — `if not gameMode then ... roomRequest.gameMode ...`
- Lines 267-269 — `if not gameMode and roomRequest.content and roomRequest.content.name then ...`
- Line 276 — `latencyTolerance = roomRequest.latencyTolerance`
- Line 286 — `if seed == nil then seed = roomRequest.seed end`
- Line 294 — `elseif roomRequest.openRoom == true then`

End state: reads only from `roomRequest.content`. One shape in.

### Step 1.3 — Drop the legacy-shape test and audit fixtures

- **`server/tests/ServerTests.lua:533-568`** (`testTeamRoomRequestAcceptsFallbackGameModeShape`)
  — exists specifically to lock in the contract that Step 1.2 retires.
  **Delete it.** There's a parallel wire-shape test at L570 that already
  covers the supported path; no coverage lost.
- **`common/tests/fixtures/trace_replays/`** — feasibility grep
  confirmed all current `_match.jsonl` files are already wire shape.
  Keep the grep step as defense:
  ```sh
  grep -rE '"roomRequest":true|"playerSettings":\{|"paused":true' \
       common/tests/fixtures/trace_replays/
  ```
  Any hits → delete the offending fixture.
- **`stuck_match_2026_05_13`** — not on disk; ephemeral. No action.

### Step 1.4 — Lock the J-recv invariant with a test

**File:** `server/tests/ServerTests.lua` (NOT `TraceWriterTests.lua` —
this needs `Server:processMessage` and the existing `MockPersistence` /
`MockConnection` harness).

Add one test:
1. Feed `Server:processMessage` a known wrapped J message (e.g. a
   `roomRequest`).
2. Read back the JSONL trace file via `TraceWriter.currentPath(pid)`.
3. Assert the captured body has `type == "roomRequest"` and a `content`
   sub-object — wire shape, not sanitized.

Reuse the `readJsonLines` helper from `TraceWriterTests.lua:31` (move
or duplicate).

If anyone re-introduces a sanitize-before-tap reorder, this fails fast.

### Step 1.5 — Confirm send-side symmetry (no change)

**File:** `server/Player.lua:175-188`

`Player:sendJson` taps `TraceWriter.send(pid, "J", message.messageText)`.
`messageText` is the wire-shape table built by `ClientProtocol.*` /
`ServerMessages.*`. Already correct. Add a one-line comment cross-
referencing the recv-side symmetry so a future reader can't break it.

---

## Phase 2 — Class-wide audit of reshaping sanitizers

The same Step-1.2-style cleanup applied to each reshaping sanitizer.
This is the "and what about the others?" pass — without it, every type
listed in the table above remains a latent replay landmine.

### Step 2.1 — `sanitizeMenuState` / `sanitizeLoginRequest`

**File:** `server/ClientMessages.lua:76-118`

Decide: either
- **(a)** keep the `playerSettings` wrap and update every consumer to
  read from `message.playerSettings.X` (audit `server/server.lua`,
  `server/Player.lua`, `server/Room.lua`), or
- **(b)** flatten the sanitizer to preserve the wire keys (`menu_state`,
  flat `login_request` fields) and adjust consumers.

Recommended: **(b)**. The wire shape is the contract. Track consumers
via `grep -rn "playerSettings\b"` and rewrite reads to match.

### Step 2.2 — `sanitizeLeaderboardRequest`

**File:** `server/ClientMessages.lua:198-207`

Rename internal key back to `leaderboardType` (or carry both). Audit
consumer in `server/Leaderboard*.lua` — single producer-consumer pair,
small surface.

### Step 2.3 — `sanitizeMatchAbort` / `sanitizePauseToggle`

**File:** `server/ClientMessages.lua:317-336`

Stop renaming `recipientId` → `roomNumber` and `content` → `paused`.
Consumers: `server/Room.lua`, `server/server.lua` abort/pause branches.
Small.

### Step 2.4 — Delete legacy fallbacks in every sanitizer that has them

Same pattern as Step 1.2 across the board: after Phase 1 + Phase 2, no
caller produces the legacy shape, so the fallback branches are dead.

### Step 2.5 — Audit fixtures for ALL reshaped sanitizer signatures

Extend the Step 1.3 grep to catch all five reshaping types — not just
`roomRequest`:

```sh
grep -rE '"playerSettings":\{|"paused":true|"roomNumber":[0-9]+,"matchAbort":true|"gameModeId":[0-9]+,"leaderboard_request":true' \
     common/tests/fixtures/trace_replays/
```

Any hits → delete/regenerate.

---

## Phase 3 — Structural guarantee ("reuse the same functions")

Phase 1 + 2 fix every known case. Phase 3 prevents the *next* case.

### Step 3.1 — Rename `sanitize*` → `parse*`, enforce shape-preserving

The `sanitize*` name licenses arbitrary reshaping. Rename to `parse*`
and add a comment block at `server/ClientMessages.lua:1` stating the
contract:

> `parse*(wireMessage)` returns a table whose top-level keys are a
> subset (or copy) of `wireMessage`'s top-level keys. Renaming keys is
> forbidden. Adding internal flags (`roomRequest = true`) is allowed.
> Nesting/wrapping is forbidden.

This is a comment-and-rename, not a runtime check. But it makes future
PRs reviewable: any new `parse*` that violates the contract gets caught
in review.

### Step 3.2 — Property test in `ServerTests.lua`

For every message-producing function in `common/network/ClientProtocol`:
1. Call the producer to get `messageText` (the wire-shape table).
2. Feed it through `ClientMessages.sanitizeMessage` (post-rename,
   `parseMessage`).
3. Assert top-level keys of the output are a subset of top-level keys
   of the input.

```lua
for _, producer in ipairs(allClientProtocolProducers) do
  local wire = producer(...).messageText
  local parsed = ClientMessages.parseMessage(wire)
  for k in pairs(parsed) do
    assert(wire[k] ~= nil or isAllowedInternalFlag(k),
           "parse* introduced new top-level key: " .. k)
  end
end
```

This is the load-bearing CI guard. After this lands, the bug class is
extinct.

### Step 3.3 — TraceDiff round-trip test

**File:** `server/tests/TraceDiffTests.lua`

Add one test that:
1. Runs a fixed scenario end-to-end (host creates room, joiner joins).
2. Reads both client-side TraceWriter output and server-side
   TraceWriter output for the same J events.
3. Asserts `TraceDiff.compare` returns zero `body_diffs`.

Since commit `0aa88f66` introduced server-side TraceWriter capture, every
cross-perspective diff has produced false positives on `body_diffs`
(client recorded wire, server recorded sanitized). This test asserts the
two sides now record at the same layer — and locks it in.

---

## Out of scope

- Cosmetic `"Unexpected input received from … in state character select"`
  warnings in `server.log` — different code path, benign.
- Stuck-match watchdog flow (`_stuckMatchFlagged`) — unrelated.
- I / G / D recv taps (`server/server.lua:1293, 1312, 1331`) — already
  record raw `q[i]` (pre-sanitization). No change.
- K (kickback) / E (echo/ping) prefixes — recorded as raw bytes,
  no transform path. No change.
- Eliminating `ClientMessages.sanitizeMessage` entirely. The transform
  abstraction layer arguably has negative value now (it desynchronizes
  record/replay), but removing it requires every server-side consumer to
  read raw wire keys directly — much larger blast radius. Defer.

---

## Risk

| Phase | Lines touched | Risk |
|---|---|---|
| Phase 1 | ~10 lines + 1 deletion + 1 new test | Very low |
| Phase 2 | ~5 sanitizers + their consumers | Medium — touches `Room.lua`, `Leaderboard*.lua`, server hot paths |
| Phase 3 | rename + 1 property test + 1 diff test | Low (code-wise); high information value |

Phase 1 is safe to merge alone. Phase 2 should be its own PR per
sanitizer (or one batched PR with per-sanitizer commits) so any
regressions bisect cleanly. Phase 3 is independent of 2; can land before
or after.

---

## Validation

After each phase, run `zsh run_server_tests.sh`:

**Phase 1:**
- `TraceReplayTests` — round-trip a captured trace, no "Received an
  unexpected message" errors.
- `RegressionTests::test_open_team_1v2_starts_with_three_players` — passes.
- `ThreePlayerFFATests` — passes.
- New Step 1.4 assertion — passes.

**Phase 2:**
- All `ServerTests` continue to pass after each sanitizer's
  reshape-removal. Any consumer breakage should surface here.
- Grep from Step 2.5 returns zero hits across the fixture tree.

**Phase 3:**
- Property test from Step 3.2 — passes for every `ClientProtocol`
  producer.
- TraceDiff round-trip from Step 3.3 — zero `body_diffs`.
