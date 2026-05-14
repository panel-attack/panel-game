# Investigation — wrong-draw UI in 2v2 team match (2026-05-13)

## Symptom

A 2v2 `team_vs_shared` match where one team was clearly eliminated
(both members dead, frames 3414 + 7531) and the other team had a
survivor (Lala — never sent a death event) ended with the UI showing
"DRAW".

Captured trace: `trace_archive/{5,7,8,11}/session_<latest>.jsonl`
(roomNumber=8, ts cluster ending 1778717336).

## What the trace tells us

The **server** got it right. From any of the four player traces:

```
K body: deaths=[{slot:4, senderFrame:7531}], tie:false, winnerSlot:1
J body: type=gameResult, teamWins=[1,0],
        content=[{publicId:7, placement:1, winCount:1},
                 {publicId:11, placement:2, winCount:1},
                 {publicId:5, placement:2, winCount:0},
                 {publicId:8, placement:2, winCount:0}]
```

So the server's `gameResult` cleanly named team {1,2} (Lala+Bevy) the
winners. The bug is downstream — between the client receiving that
message and the game-over UI rendering "DRAW".

## What the engine-replay test shows

`common/tests/engine/WrongDrawRegressionTest.lua` rebuilds the same
match state via `Match.createFromReplay(replay)` from the trace, applies
the recorded deaths, and calls `Match:getWinners()`. Result: returns
`[Lala]`. Correct.

The Phase-3 test in the same file goes further: builds a real
`ClientMatch.createFromReplay`, drains historical events, calls
`ClientMatch:getWinners()` then `GameBase.buildTeamResultText`. Result:
`"Team A wins"`. Also correct.

**So the trace alone does NOT reproduce the bug** when fed through the
engine path. Something about the LIVE timing — message-arrival order,
which tick `serverConfirmedEnd` lands relative to engine catch-up — is
different from anything the trace deterministically replays.

## Tooling produced for this investigation

- `tools/server_trace_to_fixture.lua` — server traces → engine-only
  fixture JSON (this is what `WrongDrawRegressionTest` consumes).
  **Working.**
- `tools/server_trace_to_bundle.lua` — server traces → wire-replay
  bundle for `TraceReplayTests` (drives the captured wire events back
  through a real `Server` via `TestClient`s). Bundle generates; E2E
  drove room creation + joins + match-start; not confirmed it reaches
  `gameResult` because the per-event `h:tick()` makes ~19k events take
  many minutes — let it finish to learn whether the bug reproduces
  through the full wire path.
- `server/server.lua:1370` — moved J trace tap to BEFORE
  `sanitizeMessage` so future captures store the raw wire shape (older
  captures still need the assembler-side translation).
- `client/src/scenes/GameBase.lua` — `buildTeamResultText` exported,
  comparison hardened to handle Player / PlayerStack / engine Stack
  winner shapes interchangeably (defensive — does not directly cause
  this bug). `[wrong-draw-trace]` `logger.info` lines wrap the call
  site so the next live "DRAW" prints `winners` shape into
  `logs/client.log`.

## The most likely root cause (untested)

`client/src/ClientMatch.lua:1287`:

```lua
function ClientMatch:getWinners()
  if not self.winners and self.engine:isLocallyEnded() then
    ...
    self.winners = winners
  end
  return self.winners or {}
end
```

`self.engine:isLocallyEnded()` is a recomputed predicate
(`self.ended or evaluateEndConditions().ended`). The engine never sets
`self.ended = true` — `Match:handleMatchEnd` only sets
`self.winners`, not `self.ended`. So the gate depends entirely on
`evaluateEndConditions()` returning `ended=true` on the first call.

That's racy in two ways:
1. If `setupGameOver` runs before all historical death events have been
   applied to the engine, `evaluateEndConditions()` may return
   `ended=false` and the cache never gets populated → `getWinners()`
   returns `{}` forever → `buildTeamResultText` returns "DRAW".
2. If `serverConfirmedEnd` triggers `engine:handleMatchEnd` (which
   computes `engine.winners`) but the engine clock isn't yet past
   `gameOverClock`, `engine.winners` is still cached — but
   `ClientMatch:getWinners`'s gate ignores that cached signal in favor
   of the racy `isLocallyEnded` recheck.

## Proposed fix (next step)

Two small changes. Either alone might be enough; together they close
the gap.

**`Match:handleMatchEnd`** — set `self.ended = true` after caching
winners. Once we've computed the verdict, the match IS finalized; no
more end-condition flapping. `evaluateEndConditions` already short-
circuits on `self.ended`.

**`ClientMatch:getWinners`** — use `self.engine.winners ~= nil` as the
"verdict cached" gate, fall back to `isLocallyEnded` only when
`engine.winners` hasn't been set yet. Don't cache an empty result —
that's how a too-early call locks the wrong answer in.

After applying the fix, ask the user to re-run a 2v2 match and
confirm. If it still shows DRAW, the `[wrong-draw-trace]` logs in
`setupGameOver` will show exactly what was given to
`buildTeamResultText`.

## Open follow-ups

- Pre-existing failure `LooseSyncTests` at `client/src/ClientMatch.lua:1485`
  (`attempt to call method 'recordDeath' (a nil value)`). The mock in
  that test pre-dates the rename in commit `fa967634`. Drive-by fix.
- `tools/server_trace_to_bundle.lua` E2E run is too slow to iterate on
  (~19k per-event ticks). Batch ticks per N events, or skip per-frame
  inputs and replay only the J/G/D events. Optional — only matters if
  we end up needing the bundle path.
