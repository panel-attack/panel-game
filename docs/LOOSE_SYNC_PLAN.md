# Loose-Sync Multiplayer for Panel Attack

## Context

Today, Panel Attack's multiplayer is **strict lockstep**: the server refuses to advance any player's frame until every active player has submitted their input for that frame. Consequences:

- One slow connection stalls the entire match for everyone.
- Network jitter causes constant micro-stalls (every spike past the average = a freeze).
- Lockstep-tolerance today is roughly **<50ms playable, 150ms+ unplayable**.

The game's own mechanics already provide a huge cushion that lockstep wastes. From `client/src/globals.lua:4-8`:

```
GARBAGE_TRANSIT_TIME    = 45 frames  (750ms)  — sender animation
GARBAGE_TELEGRAPH_TIME  = 45 frames  (750ms)  — warning above opponent stack
GARBAGE_DELAY_LAND_TIME = 60 frames  (1000ms) — pause before landing
                          ───────────────────
total                     150 frames (2500ms)
```

That's **2.5 seconds** between "Alice's chain finalizes" and "garbage actually lands on Bob's stack" — i.e., the *mechanical* latency budget for cross-player effects. Lockstep currently throws it away by demanding frame-perfect sync that the game does not need.

## Goal

Convert the architecture to **loose sync**:

- Each client runs its own deterministic sim at full speed, never waiting for any other client.
- Server becomes a **dumb relay** — no buffering, no gating, no verification.
- Cross-player effects (garbage, death) become **discrete events** with sender-frame stamps, not implicit consequences of frame-locked simulation.
- Replays become two-track (per-player inputs) plus an event log.

Explicit non-goals: server-side verification, anti-cheat, anti-desync hardening. Trust clients fully.

## Architecture overview

Three message classes flow through the server:

1. **Input messages** (existing `I` prefix) — relayed instantly with sender's slot prefix (`I,U,V,W,X,Y,Z,Q`). Used to drive each opponent's "spectator stack" view on every other client. Cosmetic-level criticality.
2. **GarbageEvent** (new `G` prefix) — fired by a sender when their local sim resolves outgoing garbage to a remote target. Mechanical-level criticality. Adaptive landing time on receiver (see §"Adaptive telegraph").
3. **DeathEvent** (new `D` prefix) — fired by a sender when their local sim ends. Win-condition criticality. Triggers server arbitration on a 200ms window.

Server emits a **KOArbitration** message (`K` prefix) when the arbitration window closes.

The Stack simulation engine, input encoding, RNG seed handshake, pause/taunt/chat plumbing, disconnect detection, and lobby flow are all untouched.

## Wire format

All new messages reuse the existing `markedMessageForTypeAndBody` format (single-char prefix + JSON body + `←J←` terminator). Registered in `common/network/NetworkProtocol.lua`:

```
G — GarbageEvent     (client → server → others + spectators)
D — DeathEvent       (client → server → others + spectators)
K — KOArbitration    (server → all)
```

```json
// G body
{
  "sender": 1,
  "senderFrame": 1830,
  "serverWallClockMs": 1731539281234,   // stamped by server on relay
  "recipients": [2, 3],
  "garbage": [ /* serialized Garbage / ChainGarbage records */ ]
}

// D body
{ "sender": 2, "senderFrame": 2104, "reason": "topOut",
  "serverWallClockMs": 1731539281234 }

// K body (server-authored)
{ "winnerSlot": 1, "tie": false,
  "deaths": [ { "slot": 2, "serverArrivalMs": 1731539281234 } ] }
```

`serverWallClockMs` is required so receivers can estimate one-way latency and adapt telegraph timing (see §"Adaptive telegraph").

## File-by-file changes

### Server

**`server/Game.lua`**
- Delete: `bufferInput` / `inputBuffer` / `currentFrameNumber` / `canFlushNextFrame` / `flushNextFrame` / `getNextFrameInputs` / `getIdleInputForPlayer` (lines 172-244).
- Keep: `receiveInput` (`server/Game.lua:163-167`) — already appends to `self.inputs[player.player_number]` for replay; this is the only retained side effect.
- Add: `Game:recordGarbageEvent(senderPlayer, body)`, `Game:recordDeathEvent(senderPlayer, body)`. Append to new fields `self.garbageEvents[]` / `self.deathEvents[]` (each entry: `{senderSlot, senderFrame, serverArrivalMs, payload}`).
- `markPlayerDisconnected` (`server/Game.lua:303-309`) and `markPlayerEliminated` (`server/Game.lua:315-320`) keep their bodies; remove their `inputBuffer` cleanup.

**`server/Room.lua`**
- `Room:broadcastInput` (lines 402-418): change from "buffer-then-flush" to "broadcast immediately." Append the input to `self.game.inputs[sender.player_number]` for replay, stamp it with sender's slot prefix, send a marked message to every other player + spectator. Inline the marshalling that was in `flushBufferedInputs`.
- Delete: `Room:flushBufferedInputs` (lines 421-455).
- Add: `Room:broadcastGarbageEvent(sender, body)`, `Room:broadcastDeathEvent(sender, body)`. Stamp `serverWallClockMs` on the body, record on `self.game`, relay to non-sender players + spectators. For `D`, also trigger KO arbitration (see §"Simultaneous KO rule").
- Delete `abortInputGapThreshold` plumbing (`server/Room.lua:35, 74, 595`). Replace the gap branch in `handleGameAbort` with unconditional disconnect-on-abort.

**`server/server.lua`**
- Remove the `flushBufferedInputsForAllRooms` tick call (`server/server.lua:891`) and the function itself (`1044-1051`). No per-tick relay work.
- `processMessage`: add `G` and `D` dispatch → `Room:broadcastGarbageEvent` / `Room:broadcastDeathEvent`.
- Delete `resolveAbortInputGapThreshold` and `latencyTolerance` / `abortInputGapThreshold` propagation (lines 59-83, 1102-1127). Accept the field for back-compat but no-op it.

**`server/tests/ServerTests.lua` / `server/tests/ServerTesting.lua`**
- Drop `flushBufferedInputsForAllRooms` from the test loop and `abortInputGapThreshold` assertions (lines 599, 610).
- New tests: input relay is immediate; `G`/`D` relay to peers + spectators; two `D`s arriving inside arbitration window → `K` tie.

### Common (protocol)

**`common/network/NetworkProtocol.lua`**
- Register `G`, `D`, `K` (their prefixes + `verbose=true` on `G` for log readability). Add to `serverPrefixToMessageType` (all three) and `clientPrefixToMessageType` (`G`, `D`).

**`common/network/ClientProtocol.lua`**
- Add `ClientProtocol.sendGarbageEvent(body)` and `ClientProtocol.sendDeathEvent(body)`. Use `markedMessageForTypeAndBody`, not the generic `J` JSON envelope.

**`common/network/ServerProtocol.lua`**
- Add `ServerProtocol.koArbitration(arbitration)`.

### Client

**`client/src/network/PlayerStack.lua`**
- Delete lines 42-49 — the `garbageTarget.confirmedInput == 0` lockstep stall. The local stack must never block on remote state.
- Keep `send_controls` from `buffer_len` line down. Keep `sendInput`.
- Rename / repurpose `notifyServerStackEliminated`: dispatch a `D` event via `GAME.netClient:sendDeathEvent(...)`. Drop the `sendStackEliminated` JSON path in `common/network/ClientProtocol.lua:201-206` (or stub it).

**`client/src/network/NetClient.lua`**
- Add `sendGarbageEvent`, `sendDeathEvent` mirroring `sendInput`.
- Add `processGarbageEvents`, `processDeathEvents` siblings to `processInputMessages` (lines 560-582). Pop `G`/`D` from `receivedMessageQueue` → forward to `ClientMatch:applyGarbageEvent` / `applyDeathEvent`.

**`client/src/ClientMatch.lua`**
- `receiveInput` (lines 936-942) unchanged — still feeds opponent stacks' `confirmedInput`. Opponent stacks already catch up via `Stack:shouldRun` (`common/engine/Stack.lua:736-749`) — no changes needed there.
- Add `ClientMatch:applyGarbageEvent(body)`: estimate one-way latency from `body.serverWallClockMs`, compute landing offset (see §"Adaptive telegraph"), call `stack:enqueueRemoteGarbage(body.garbage, landingFrame)` on each recipient stack.
- Add `ClientMatch:applyDeathEvent(body)`: mark the corresponding remote stack as game-ended at the reported frame.
- Add `K` handler: resolves draw/winner.

**`client/src/PlayerStack.lua` / `client/src/ClientStack.lua`**
- Add `Stack:enqueueRemoteGarbage(garbage, landingFrame)` — additive method that bypasses `outgoingGarbage`/transit machinery and inserts directly into `incomingGarbage.garbageInTransit[landingFrame]` (appending to that frame's bucket if already populated).

**`common/engine/Match.lua`**
- `distributeGarbageToTargets` (lines 301-376) / `pushGarbageTo` (lines 378-408): split local-target path from remote-target path. For **remote** targets, instead of `target:receiveGarbage(garbageCopy)`, emit a `G` event via `NetClient:sendGarbageEvent(...)`. For **local-only** targets (vsSelf, puzzle, training), keep the direct push.
- Remove the `rollbackToStopWatch` branch at `Match.lua:389-398` — rollback-on-late-garbage is a lockstep-era safeguard that no longer fires (remote garbage now arrives via `G` events, which are slotted in *from now*, never in the past).
- `isIrrecoverablyDesynced` (lines 706-719): downgrade the `source.clock + MAX_LAG < target.clock` check from "abort" to "metric" (or delete entirely). With loose sync, clock divergence across players is the steady state.
- `shouldSaveRollback` (lines 411-429): simplify to "always save rollback for any stack with remote inputs." Rollback buffer (`MAX_LAG` deep) remains, used only for catch-up smoothing on opponent stacks.

**`client/src/globals.lua`**
- No constant changes. `MAX_LAG` still sizes rollback buffers; we remove its use as an *abort* trigger, not the value itself.

### Replays

**`common/data/ReplayV3.lua` → new `ReplayV4.lua`**
- Bump `REPLAY_VERSION`. Add top-level:
  - `crossPlayerEvents.garbage[]` — `{senderSlot, senderFrame, recipients[], garbage}`
  - `crossPlayerEvents.deaths[]` — `{senderSlot, senderFrame, reason}`
- `ReplayStack.inputs[]` still carries each player's input track; per-player frame counter is implicit in array position.
- Server-side replay finalization (`Game:finalizeReplay`) already accumulates `self.inputs[i]` from `receiveInput`; add accumulation of `self.garbageEvents` / `self.deathEvents`.
- Playback (`Match.createFromReplay`, `common/engine/Match.lua:553+`): consume cross-player events directly rather than re-deriving them from simultaneous Match simulation. The recorded event carries the outcome, so playback becomes simpler, not more complex.
- Keep `ReplayV3.createFromReplay` for old replay compatibility; new matches write V4.

## Simultaneous KO rule

**Decision: 200ms server arbitration window, ties → draw.**

When the server receives a `D` event, it starts (or extends) a 200ms arbitration window for that match. Inside the window:

- Exactly one `D` arrives → that player loses, others win.
- Multiple `D`s, opposing teams → declare a draw (`K` with `tie:true`).
- Multiple `D`s, same team, but one team has a survivor → survivors win.

Window closes → server emits a single `K` arbitration message. Clients honor `K` authoritatively for end-of-match UI.

Justification: arrival order is what was already implicitly happening in lockstep, but at 200ms granularity. "Draw on dead-heat" preserves player agency in close finishes and avoids one-sided outcomes determined by network jitter alone.

## Adaptive telegraph timing

This is the most interesting receiver-side trick. The naive design says: on `G` arrival, drop garbage in at `receiver.clock + 150` frames. This works but throws away tempo information: a player on a fast connection responding to a slow connection waits the full 150 frames, even though the sender's chain already happened 1+ second ago.

**Adaptive design:** receivers estimate one-way latency from `body.serverWallClockMs` (server stamps on relay) vs receiver's local wall-clock-on-receive. Maintain a running offset estimate (EWMA over recent G events). Compute:

```
estimated_latency_frames = (now_ms - serverWallClockMs - clock_offset) * 60 / 1000
ideal_total_telegraph    = 150                                  -- the budget
remaining_budget         = ideal_total_telegraph - estimated_latency_frames
landing_offset           = max(MIN_REACTION_FRAMES, remaining_budget)
landing_frame            = receiver.clock + landing_offset
```

Where `MIN_REACTION_FRAMES` is a floor (proposal: **45 frames / 750ms**, matching the original telegraph time alone — guarantees the receiver always sees a telegraph window before garbage lands).

Effect:
- Low latency (~50ms) → landing offset ≈ 147 frames (nearly identical to today)
- Moderate latency (~500ms) → landing offset ≈ 120 frames (mild compression)
- High latency (~2s) → landing offset ≈ 30→45 (compressed, floored at MIN_REACTION_FRAMES)
- Pathological latency (>2.5s) → floored, sender experiences extra apparent lag

The total perceived time from "sender triggered chain" to "garbage lands on opponent" stays roughly constant across network conditions — latency is transparent to gameplay tempo up to the floor.

**Adaptive recovery:** the EWMA-based estimate updates with every new event. Future events use the freshest estimate; in-flight events stay where they are (no rollback). So if the network improves, subsequent garbage benefits from a longer telegraph; if it degrades, subsequent garbage gets compressed (down to the floor).

## What stays unchanged (explicit list)

- `common/engine/Stack.lua` simulation engine (deterministic, already correct)
- Input encoding (`KeyDataEncoding`, `TouchDataEncoding`)
- Pre-match handshake including RNG seed (`server/Game.lua:37, 64`; already load-bearing)
- Disconnect detection, watchdog, `closeConnection`
- Lobby, room setup, settings, taunt, chat, pause, abort plumbing
- Local-only modes: vsSelf, puzzle, training, time attack
- `MAX_LAG` value (only its use as abort trigger is removed)

## Risks / accepted compromises

**Riskiest single piece of work:** refactoring `Match:distributeGarbageToTargets` / `pushGarbageTo` to split local-vs-remote target paths (`common/engine/Match.lua:301-408`). Today, the rollback-on-late-garbage branch (lines 389-398) is intertwined with garbage delivery and only fires in the lockstep-implicit-sim world. Cutting cleanly requires the local-target path to remain functional for vsSelf/puzzle/training. **Mitigation:** uniform `enqueueRemoteGarbage` pathway used for both local and remote targets (with `landingFrame` computed differently), rather than conditional branching at the call site.

**Accepted compromises:**
- Per-player wall clocks drift independently. Replay duration logged per-stack, not globally.
- Sender attack animation begins on receiver when `G` arrives (with adaptive landing offset). Slightly different feel from lockstep but acceptable.
- A laggy player's `G` can arrive "from the past" (sender finalized at sender-frame N, receiver is way ahead). Slotted in from "now + landing_offset," not retroactively. Both sides see locally-consistent timing.
- A player who disconnects mid-chain loses any unbroadcast `G`. Their loss; opponent benefits.
- No server-side verification. Cheating is possible. Explicitly accepted.

**Deliberately deferred:**
- Reconnect/resume mid-match (today disconnect = match over; stays).
- Spectator catch-up policy refinement (existing input firehose path should still work; needs a smoke test).
- Telemetry: log `G` arrival latencies on both sides to validate `MIN_REACTION_FRAMES` empirically and tune the 200ms KO arbitration window.

## Critical files to modify

- `server/Game.lua`
- `server/Room.lua`
- `server/server.lua`
- `common/network/NetworkProtocol.lua`
- `common/network/ClientProtocol.lua`
- `common/network/ServerProtocol.lua`
- `common/engine/Match.lua`
- `client/src/ClientMatch.lua`
- `client/src/network/PlayerStack.lua`
- `client/src/network/NetClient.lua`
- `client/src/PlayerStack.lua` / `client/src/ClientStack.lua`
- `common/data/ReplayV3.lua` → new `ReplayV4.lua`

## Verification

**Unit / integration:**
- `zsh run_server.sh` — runs server test suite on startup, including the new `G`/`D` relay and `K` arbitration tests in `server/tests/ServerTests.lua`.
- `zsh run_tests.sh` — runs client-side tests via love (`NetworkProtocolTests` etc.), should verify the new prefix registrations and message round-trips.

**Manual end-to-end:**
1. Start local server: `zsh run_server.sh` (verify it logs all server tests passing).
2. Start two clients: `zsh run_client.sh` × 2.
3. Both clients connect to localhost, start a versus match.
4. **Baseline test:** play a normal match — confirm garbage delivery, chain interactions, win/loss UI all work as before.
5. **Latency test:** introduce artificial latency on one client using `TcpClient:activateDelayedProcessing()` (`client/src/network/TcpClient.lua:196`) with a 200-500ms delay. Confirm:
   - Local player's own stack remains fully responsive (no stutter).
   - Opponent's board view runs slightly behind but doesn't freeze.
   - Garbage from the laggy player lands with a compressed telegraph (visible adaptive timing).
   - No match-wide stalls.
6. **Severe latency test:** push delay to 1500ms. Confirm garbage still lands within `MIN_REACTION_FRAMES` floor; match continues; no desync abort fires.
7. **Simultaneous KO test:** force both players to top out within ~100ms of each other (use spam-garbage or manual coordination). Confirm `K` arbitration message arrives, both clients show "Draw" UI.
8. **Replay test:** save a replay from step 4 and replay it. Confirm V4 format loads, garbage events play back at the right moments, both perspectives are visually correct.
9. **Disconnect test:** mid-match, kill one client. Confirm: surviving client continues without stalling; surviving player wins; replay is finalized correctly with the disconnected player's final state.

**Logs to watch:** `tail -f logs/server.log` for `G`/`D`/`K` message flow; `tail -f logs/client.log` for `applyGarbageEvent`/`applyDeathEvent` and adaptive latency estimates.
