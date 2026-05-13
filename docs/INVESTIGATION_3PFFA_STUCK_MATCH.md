# Investigation: 3p FFA shared — stuck-match + slot/name mismatch

Bug captured live 2026-05-13. Three clients (Koozie, Bevy, Lala) played a
3-player FFA shared-garbage match. The match never broadcast a
`gameResult`; surviving players kept playing locally but their further
deaths never reached the wire; and the final visual state shows
mismatched names-to-stacks across all three perspectives.

This doc is the hand-off + diagnostic notes. If a future me (or you)
picks this up cold, start at "Hypothesis" + "What I would check next."

---

## Trace artifacts on disk

```
common/tests/fixtures/trace_replays/last-match/
  1/match_1_1778703153/_match.jsonl              ← Koozie
  1/match_1_1778703153/game_1778703156.jsonl
  2/match_1_1778702969/_match.jsonl              ← Bevy
  2/match_1_1778702969/game_1778703014.jsonl
  2/match_1_1778702969/game_1778703156.jsonl
  3/match_1_1778702999/_match.jsonl              ← Lala
  3/match_1_1778702999/game_1778703014.jsonl
  3/match_1_1778702999/game_1778703156.jsonl
```

Source dirs (preserved on the dev box):

```
~/Library/Application Support/LOVE/Panel Attack Koozie/trace_archive/
~/Library/Application Support/LOVE/Panel Attack Bevy/trace_archive/
~/Library/Application Support/LOVE/Panel Attack Lala/trace_archive/
```

Game mode: `3p_ffa_shared`. Game in question: `game_1778703156.jsonl`.

---

## What the players saw (eyewitness, from the user)

| Player's screen | Self | View 1 | View 2 |
|---|---|---|---|
| Lala | Out at **150** (self) | Koozie: half stack | Bevy: out 1:13 |
| Bevy | Out at **1:13** (self) | Lala: out 227 | Koozie: half stack with garbage |
| Koozie | Out at **227** (self) | Bevy: out 1:13 | Lala: half stack with garbage |

No win/lose/draw signal on any screen.

**The "half stack with garbage" visual is identical between**:
- Bevy's view-of-Koozie (Bevy says Koozie is alive)
- Koozie's view-of-Lala (Koozie says Lala is alive)

Same image, two different attributions. Whose stack is it actually?

---

## What the wire saw (from the traces)

Confirmed from `jq` over the three `game_1778703156.jsonl` files:

1. **Bevy died at engine frame 4402** (≈ 1:13 at 60fps). Bevy sent
   `D{senderFrame:4402, reason:"topOut"}`. Server stamped + relayed.
2. **Server arbitrated 1 death:** `K{deaths:[{slot:1, senderFrame:4402, ...}], tie:false}`. All three clients received it at ts=1778703231.
3. **From that point onward, ALL THREE CLIENT TRACES contain only
   heartbeat pings (E prefix) for the next ~505 seconds.**
   - 0 further `D` (death) sends from any client
   - 0 further `G` (garbage) sends
   - 0 input frames sent
   - No `gameEnded` lifecycle marker
   - No `leaveRoom`
   - No `gameResult` recv

So **nothing the engines did locally after Bevy's death ever reached
the wire.** Wire-level evidence and eyewitness diverge: the user says
they kept playing and topped out; the wire says everyone immediately
stopped sending after the K message.

---

## Hypothesis (ranked by suspicion)

### H1 — K message silences the send pipeline but not the engine

When ClientMatch receives the `K` arbitration message, something in the
state machine stops driving outbound traffic — possibly transitions
the room into a "showing match result" state where `PlayerStack:
send_controls` no longer runs, so neither inputs nor death events go
out. Meanwhile the engine internals keep ticking from queued
confirmedInput (or whatever is left in the buffer), so stacks eventually
top out **locally** with no wire signature.

**Why this fits:**
- All three traces silence simultaneously, exactly when K arrives.
- The eyewitness says they kept playing — consistent with engines
  continuing to tick locally.
- Their local stacks toppled out (150, 227) — consistent with the
  engines reaching natural game-over from accumulated garbage.

**What rules it in / out:** check `client/src/network/PlayerStack.lua:
send_controls`. Does it gate on some `room.match.ended` or
`stack.engine.game_over_clock`? Does it stop polling after a K? Also
check `ClientMatch:run` — does the run loop keep advancing stacks after
a K? Specifically: does it stop calling `PlayerStack:send_controls`?

### H2 — Slot-to-render mapping mismatch on partial-state clients

The "identical half-stack visual under two different names" is the
smoking gun for view-stack mis-attribution. Slot numbers vs render
indices vs player names are getting crossed somewhere.

Bevy and Koozie agree that a stack died at frame 227 — but disagree
about whose. Lala thinks her own stack died at 150 (in her own clock).
If the engines kept ticking and Lala actually died first (at her 150),
then the second death at 227 belongs to **Koozie**. Bevy is showing
Koozie's terminal state but labeling it "Lala". And Koozie's own
view-stack of Lala is showing Lala's terminal state but labeling it
"alive" (because she didn't get a D event for Lala).

**Why this fits:**
- "half stack" looks identical in Bevy's view-of-Koozie and Koozie's
  view-of-Lala — same actual stack, different labels.
- 3p+ render-index mapping is the kind of thing that has subtle slot
  vs publicId vs renderIndex bugs (the plan calls out B7 as an open
  team-assignment-orientation issue).

**What rules it in / out:** look at the matchStart payload in each
client's trace. The `replay.metadata.stacks` array carries
`stackIndex` + `renderIndex` + `name` + `publicId`. Compare across the
three clients — do they all agree on who is in slot 1/2/3? Do they
agree on render indices?

### H3 — Server-side: after a 3p FFA death, the surviving 1v1 never reaches a terminal arbitration

In `Room:tickArbitration`, after one player dies, `livingTeams=2`
(it's FFA: each player is their own team). The plan's existing
arbitration only emits when `livingTeams <= 1`. So a surviving 1v1
relies on natural game-end via outcomeReports. If both clients stopped
sending (H1), the server never sees survivor death events, never
calls `_finalizeMatch`, and the room sits there.

This is the SERVER side of why we never see a `gameResult` broadcast.
H1 explains why CLIENTS stopped sending; H3 explains why the SERVER
never recovered.

---

## What I would check next

In order of payoff for the smallest investigation:

1. **`client/src/network/PlayerStack.lua:send_controls` (around lines
   45-70)** — does it gate on a match-ended flag? Add logging or
   trace markers to find out when it stops firing.
2. **`client/src/ClientMatch.lua`** — find the K-event handler (look
   for `koArbitration` or where `K` prefix routes). Does it set some
   `self.matchOver` flag that other code keys off?
3. **`server/Room.lua:tickArbitration`** — verify the arbitration
   logic for `livingTeams > 1` cases. Does it correctly defer to the
   natural-game-end path? Does that path actually fire when the
   survivors top out (which they don't seem to, per H1)?
4. **The matchStart payload in each trace** — `jq 'select(.body.type ==
   "matchStart") | .body.content.metadata.stacks'`. Confirm slot →
   name → publicId → renderIndex mapping is consistent across the
   three clients.
5. **`client/src/ClientMatch.lua:moveStacks`** + the
   `moveForRenderIndexNPlayer` calls in ClientStack — verify 3-player
   render-index assignment. If render slot is decoupled from
   playerNumber, a mis-assignment here directly produces the visual
   mismatch in H2.

---

