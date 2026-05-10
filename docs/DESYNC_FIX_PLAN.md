# 4-Player Desync Fix Plan

## Problem Statement

When running 3+ player games on localhost, the game desyncs within 9 seconds with an `inputCountDifference` of 321+ frames. The root cause is **input ordering corruption under high throughput**.

### Current Symptom

```
05/10/26 12:13:29.963  INFO:Koozie aborted the game
05/10/26 12:13:29.963  INFO:abort was judged as legitimate with an inputCountDifference of 321
```

### Root Cause

1. Server receives inputs as they arrive from clients (no guaranteed order)
2. Server broadcasts each input individually as soon as it's received
3. Network packets can arrive out of order on localhost (no sequencing)
4. Each client applies inputs in a different order
5. Game states diverge → desync

**Example of corruption:**

```
Server receives:
  - 12:13:21.100 Bev: RIGHT
  - 12:13:21.101 Player1: LEFT
  - 12:13:21.102 Koozie: SWAP
  - 12:13:21.103 Lala: UP

Broadcasts individually:
  - RIGHT to conn1, conn2, conn3, conn4
  - LEFT to conn1, conn2, conn3, conn4
  - SWAP to ...
  - UP to ...

Client 1 receives:          Client 2 receives:
  RIGHT, LEFT, SWAP, UP      LEFT, RIGHT, SWAP, UP
  (different order)
```

This doesn't matter for single-player. With multiplayer lockstep, **input order is deterministic state** — if it differs, so does the game.

---

## Solution: Frame-Based Input Batching

**Architecture:** Client-side prediction + server-authoritative batching

### How It Works

**Local (Client):**

```
Player presses button
  ↓
Client applies immediately to local stack (prediction)
Client sends input to server (queued, async)
Player sees action instantly (NO LAG)
  ↓
Later: Server authoritative frame arrives
  ↓
If prediction matches: continue
If prediction differs: rollback → apply server inputs → fast-forward
```

**Authoritative (Server):**

```
Every game frame (e.g., 16ms for 60fps):
  1. Collect all pending inputs for this frame from all players
  2. Sort by player number (enforces consistent order)
  3. Create atomic batch: "Frame N: [Bev=RIGHT, Player1=LEFT, Koozie=SWAP, Lala=UP]"
  4. Broadcast batch to ALL clients
```

**Broadcast Protocol Change:**

```
OLD (broken):
  I<input for Bev>←J←
  I<input for Player1>←J←
  I<input for Koozie>←J←
  I<input for Lala>←J←
  (each message sent separately, can arrive out of order)

NEW (fixed):
  I[{"frame": 100, "inputs": {"1": "RIGHT", "2": "LEFT", "3": "SWAP", "4": "UP"}}]←J←
  (single atomic message, deterministic order)
```

---

## Implementation Plan

### Phase 1: Input Buffering (Server-side)

**Goal:** Collect inputs per-frame instead of broadcasting individually

**Files to modify:**

- `server/server.lua` — main loop, where input processing happens
- `server/Room.lua` — input distribution to game

**Changes:**

1. Add `inputBuffer` to `Game` class: `{ [frameNumber] = { [playerNumber] = inputData } }`
2. In game loop, instead of broadcasting each input immediately:
   - Store input in buffer keyed by frame number
   - On each server tick, check if all players have submitted input for frame N
   - If yes: broadcast entire batch, clear buffer for that frame

### Phase 2: Atomic Input Broadcast

**Goal:** Send all inputs for a frame in one message

**Files to modify:**

- `server/Connection.lua` — input sending
- `common/network/NetworkProtocol.lua` — add frame batch message type
- `client/network/NetClient.lua` — receiving side

**Changes:**

1. Define new message type: `frameBatch` or `syncedInputs`
   ```lua
   {
     type: "frameBatch",
     frame: 100,
     inputs: {
       [1] = "RIGHT",
       [2] = "LEFT",
       [3] = "SWAP",
       [4] = "UP"
     }
   }
   ```
2. Server broadcasts one message per frame containing all player inputs
3. Client applies entire batch atomically

### Phase 3: Client-Side Validation

**Goal:** Detect when prediction diverges from authority

**Files to modify:**

- `client/ClientMatch.lua` — match state tracking
- `common/engine/Game.lua` — game simulation

**Changes:**

1. Track `predictedFrame` (local, ahead of server)
2. Track `authorityFrame` (what server says happened)
3. When authority frame arrives:
   - Compare: `localGameState[authorityFrame]` vs `serverGameState[authorityFrame]`
   - If mismatch: rollback to authorityFrame, replay from authority, fast-forward
4. Log divergences for debugging

### Phase 4: Testing & Validation

**Checkpoints:**

1. 2-player game still works (sanity check)
2. 3-player game reaches game-end without desync
3. 4-player game reaches game-end without desync
4. Verify no client input lag (actions are immediate)

---

## Key Design Decisions

### Why Frame-Based?

- Deterministic: same inputs in same order = same state
- Simple to reason about
- Standard in competitive puzzle games
- No client-side lag (prediction happens immediately)

### Why per-frame and not per-tick?

- Game engine likely already operates frame-by-frame at 60fps
- Server can batch inputs on each frame it processes
- Aligns with client's prediction model

### Input Ordering Strategy

- Sort by **player number** (not arrival time)
- This ensures consistent order across all clients
- Server is single-threaded, so order is deterministic

### Rollback Strategy

- Keep last N frames of game state (e.g., last 5)
- On divergence, rollback to authority frame
- Re-apply authority inputs
- Fast-forward to present
- If divergence persists, likely a bug in game engine (not network)

---

## Implementation Sequence

1. **Trace current input flow** → understand where inputs go after server receives them
2. **Add frame numbering** to inputs (server assigns frame number on receipt)
3. **Implement input buffer** in `Game` (collect per-frame)
4. **Modify broadcast protocol** to send batches instead of individual messages
5. **Update client receiver** to handle batch format
6. **Add diagnostics** to detect divergence
7. **Implement rollback** if needed
8. **Test with 4 players** → should reach game end without desync

---

## Fallback / Debugging

If frame-based batching doesn't fully solve it:

1. Add frame-by-frame input logging (log both server and client perspective)
2. Compare replays from different clients
3. Check if game engine itself is non-deterministic (e.g., random number seeding)
4. Verify all clients are running same game version

---

## Success Criteria

✅ 4-player game completes without desync
✅ No observable input lag
✅ Logs show all clients received same frame batches
✅ 2-player and 3-player games still work
