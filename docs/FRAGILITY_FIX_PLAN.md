# Fragility Fix Plan — Architecture, Validated

Four architectural smells, post-validator adjustments. Each item lists the
claim, the architectural fix, and what's been corrected against my initial
draft.

(A fifth item — generic ack/seq/retry layer for critical sends — was
removed after deeper look at `TcpClient`: the existing outbound queue
already handles partial writes / send retries, and the server-side
silent-death watchdog covers the rare "socket dies mid-critical-send"
case. The bug we just fixed wasn't a socket reliability problem.)

---

## #1 — `Match:hasEnded` foot-gun (split into pure evaluator + cached state)

**Claim status:** REAL. hasEnded mutates `self.ended`, `self.gameOverClock`,
`self.aborted`, `self.desyncError` across 7 return points. Three of those
are hidden state writes the original draft missed.

**Architectural fix (validator-adjusted).**
- New pure function `Match:evaluateEndConditions()` returns
  `{ended, gameOverClock, reason}`. NO mutations. Read-only over self.stacks,
  self.rules, self.teams, self.fromReplay.
- The post-finalize cache `self.ended` stays — abort, handleMatchEnd, and
  server Game all rely on it. Rename intent in docs: `self.ended` means
  "we have finalized" (only `handleMatchEnd` and `abort` set it true).
- Pull `gameOverClock` cache out into a normal stash that handlers write
  when they consume the evaluator result.
- Pull desync detection out of hasEnded into `Match:checkDesync()` that
  callers run explicitly when they want to check (currently fires on every
  hasEnded read — wasteful and surprising).
- Public `Match:localEndDetected()` — boolean view of the evaluator's `ended`
  field. Used by display code. Does not mutate.
- Delete `Match:hasEnded()` as public API. Replace every call site:
  - `ClientMatch:shouldFinalize` (lines 379, 381) → uses
    `evaluateEndConditions().ended` directly for offline/replay.
  - `ClientMatch:run` line 1261 (winners computation) → uses
    `self.ended or evaluateEndConditions().ended`.
  - `BattleRoom.lua:445` → audit and replace.
  - Tests → use the same replacements; we want tests verifying the new
    surface, not preserving the old one.

---

## #2 — Pause: remove engine-level early-return only

**Claim status:** OVERSTATED. Pause is already mostly scene-level. The
`isPaused` flag is the coordination point: NetClient subscribes to
`pauseChanged` for protocol; render readers consult `match.isPaused`;
`supportsPause` lives on the Match because match composition determines it.
Tearing the flag off is wrong.

**Architectural fix (validator-adjusted).**
- Keep `isPaused` flag, `togglePause`, `pauseChanged` signal, `supportsPause`
  — all coordination machinery stays.
- Remove the `if self.isPaused then runGameOver(); return end` at the top
  of `ClientMatch:run`. The engine just runs when called.
- Scene-level callers (GameBase, PuzzleGame, ReplayGame, PortraitGame)
  already gate `match:run()` with their own pause checks — verified at
  GameBase.lua:361, ReplayGame.lua:59, PuzzleGame.lua:214. The engine-level
  check is redundant.
- Result: pause stops being something the engine consults. It stays
  something the engine *announces* and scenes consume.

---

## #4 — Single Clock abstraction with split monotonic/wall surfaces

**Claim status:** REAL. Confirmed: `os.time` (28 sites), `socket.gettime`
(15 sites), `room.clock` (15 sites in Room.lua alone), `time = os.time`
aliasing in 3 files.

**Architectural fix (validator-adjusted).**
- `common/lib/Clock.lua` exposes TWO methods, not one:
  - `Clock:monotonicMs()` — backed by `socket.gettime` with a forward-only
    guard (caches last value, never returns less). For arbitration windows,
    watchdog deadlines, anything that compares-times-to-check-elapsed.
  - `Clock:wallSeconds()` — backed by `os.time`. For replay timestamps,
    ban-expiry comparisons, anything user-facing or persisted.
- Server constructs one Clock instance. Rooms read `room.clock.monotonicMs`
  for their existing `self.clock()` calls (semantically all monotonic).
- Client: `GAME.clock` exposes the same.
- Migration:
  - Replace `socket.gettime` everywhere with `Clock:monotonicMs()` (in
    seconds form where current code expects seconds).
  - Replace bare `os.time` for game-logic-elapsed-time with
    `Clock:wallSeconds()`. Leave `os.time` calls for timezone math
    (`timezones.lua:32` — needs the `os.time(table)` signature) and for DB
    ban-expiry comparisons (must match what's already stored).
- Tests: `withMockSocketGetTime` helper becomes `withMockClock` — patches
  the Clock instance, not socket directly. Existing `room.clock = ...`
  patches survive because room.clock is still a function reference.

---

## #5 — Rename `renderIndex` → `layoutSlot`; strip from cross-client artifacts

**Claim status:** OVERSTATED. `player_number` + `publicId` already serve as
the cross-client identity. The real smell is that `renderIndex` has been
conflated with both layout coordinate AND cross-client identity (encoded in
replays + traces).

**Architectural fix (validator-adjusted).**
- Rename `renderIndex` → `layoutSlot` everywhere on the client. Name
  communicates it's a local layout coordinate (1=big-left, 2..N=small-right).
- Stop emitting `renderIndex` in cross-client trace markers — use
  `player_number` + `publicId` instead. `slotMap` marker payload changes
  shape: `{player_number, publicId, layoutSlot}` where layoutSlot is
  explicitly labeled "this client's perspective."
- Replay metadata: keep `layoutSlot` (was `renderIndex`) but rename the
  field. Replays preserve the recording client's perspective for playback
  layout fidelity — that's a legitimate use of the local coordinate.
- ClientStack portrait-asset selection (`drawPortrait(renderIndex, ...)`)
  keeps using layoutSlot — portrait variant is a local UX choice.
- Pure spectators already fall through to player_number ordering
  (ClientMatch.lua:636-641); no change needed there.

---

## Plan of attack

1. **#1 (hasEnded split)** — biggest surface change in Match. Do while
   context is fresh.
2. **#2 (engine-level pause early-return removal)** — one-line scope.
3. **#4 (Clock module + migrate call sites)** — mechanical mass migration.
4. **#5 (layoutSlot rename + trace marker cleanup)** — independent of all
   others.

Each item lands as one commit with tests. Server tests + client tests must
stay green at every step.
