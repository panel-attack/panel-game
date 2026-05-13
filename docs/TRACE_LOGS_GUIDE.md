# Trace Logs — Reading + Gathering Locally

How to find, inspect, and copy the trace files a Panel Attack client
writes to disk while playing. Use this before the server-side pull
exists — for now everything happens by hand against a player's local
machine.

See `docs/CRASH_REPLAY_PLAN.md` for the broader design. This doc is
the field guide.

---

## Where the files live

The client writes traces into love's per-user save directory. Path
depends on OS:

| OS | Save dir |
|---|---|
| macOS | `~/Library/Application Support/Panel Attack/trace_archive/` |
| Linux | `~/.local/share/love/Panel Attack/trace_archive/` |
| Windows | `%APPDATA%\LOVE\Panel Attack\trace_archive\` |

The "Panel Attack" piece is the `LOVE_IDENTITY` env var, set in
`conf.lua` (line 12). It defaults to `"Panel Attack"`. Two cases where
it's different:
- `run_tests.sh` sets `LOVE_IDENTITY="Panel Attack Tests"` — test runs
  use a separate dir so they don't stomp the dev client's saves.
- Forks / self-hosters can override `LOVE_IDENTITY` to keep their
  client's data isolated.

Quick path to your own save dir on macOS:
```sh
open "$HOME/Library/Application Support/Panel Attack/trace_archive"
```

---

## Directory layout

```
trace_archive/
  session_<loginTs>/              ← one dir per server-login lifetime
    match_<roomNumber>_<joinedTs>/  ← one dir per room-join
      _match.jsonl                  ← events outside any specific game
      game_<gameStartTs>.jsonl      ← one file per match-instance
      game_<gameStartTs>.jsonl      ← rematch in the same room
    match_<roomNumber>_<joinedTs>/  ← left + rejoined → new match dir
      _match.jsonl
      game_<gameStartTs>.jsonl
  session_<loginTs>/              ← logged out + back in → new session dir
    match_local_<ts>/               ← single-player play creates this
      _match.jsonl
      game_<ts>.jsonl
```

Key points:
- **`session_<loginTs>/`** — anchored at successful login. Wraps the
  whole online lifetime. Single-player play that never logged in
  auto-creates a `session_<now>/` dir.
- **`match_<room>_<joinedTs>/`** — anchored at room-join. Multiple
  games per match are normal (best-of-N, rematches). Leaving + rejoining
  the same room makes a NEW match dir (newer `joinedTs`).
- **`_match.jsonl`** — captures everything at room-scope outside a
  specific game: addToRoom, settingsUpdate, player joins, spectator
  joins, playerLeftRoom, ready-up traffic. Also captures `gameBegin` /
  `gameEnded` connection markers pointing at the per-game files.
- **`game_<gameStartTs>.jsonl`** — captures everything inside one game:
  inputs, garbage events, death events, KO arbitration, replay events.

---

## What's in each line

Every line is a complete JSON object. One event per line, append-only.
Lines categorize themselves via `dir`:

```jsonl
{"ts":1715630423.012,"dir":"recv","prefix":"J","body":{"type":"matchStart","content":{...}}}
{"ts":1715630423.025,"dir":"input","raw":"A","frame":1,"stack":1}
{"ts":1715630423.026,"dir":"send","prefix":"I","body":"A"}
{"ts":1715630423.041,"dir":"recv","prefix":"I","body":{"playerNumber":2,"input":"A"}}
{"ts":1715630423.058,"dir":"send","prefix":"G","body":{"senderFrame":120,"recipients":[2],"garbage":[...]}}
{"ts":1715630423.077,"dir":"recv","prefix":"G","body":{"sender":1,"senderFrame":120,...}}
{"ts":1715630423.099,"dir":"local","kind":"gameBegin","gameStartTs":1715630423,"gameFile":"game_1715630423.jsonl"}
{"ts":1715630425.412,"dir":"local","kind":"gameEnded"}
```

Field reference:
- **`ts`** — wall-clock seconds, monotonic-ish. Use for ordering across
  files; don't trust as absolute time (clock skew between clients is
  expected).
- **`dir`** — one of:
  - `recv` — server → this client
  - `send` — this client → server
  - `input` — local engine input char (controller poll → engine)
  - `local` — lifecycle / forensic marker; not on the wire
- **`prefix`** — single-char wire prefix for `recv`/`send`. See
  `common/network/NetworkProtocol.lua` for the table:
  - `J` JSON message (lobby, matchStart, addToRoom, etc.)
  - `I` Player input. For `recv` the body is `{playerNumber, input}`;
    for `send` it's the raw input chars this client sent.
  - `G` Garbage event (loose-sync)
  - `D` Death event (loose-sync)
  - `K` KO arbitration
  - `E` Ping (mostly silenced; only ack-sends trace)
  - `H` Version check
- **`body`** — for J/G/D/K: decoded JSON table. For I: see above.
- **`raw`** + **`frame`** + **`stack`** — only on `dir:"input"`. raw is
  the engine input char, frame is the stack's clock when received,
  stack is the 1-based stack index.
- **`kind`** — only on `dir:"local"`. Currently emitted kinds:
  - `gameBegin` — at the start of a game; points at the per-game file
  - `gameEnded` — at endGame; appears in `_match.jsonl` after the game
    file is closed

Pings (`E` prefix server → client) are NOT captured — they're high
frequency, empty body, and replay-irrelevant. The ack-send IS captured
(one line per heartbeat ack), which gives connectivity timing for free.

---

## Inspecting traces

Quick eyeball: `cat` or `less` works.
```sh
less ~/Library/Application\ Support/Panel\ Attack/trace_archive/session_*/match_*/game_*.jsonl
```

Pretty-print one event:
```sh
head -1 game_*.jsonl | jq
```

Filter by `dir`:
```sh
jq -c 'select(.dir == "send")' game_*.jsonl
jq -c 'select(.dir == "recv" and .prefix == "G")' game_*.jsonl
jq -c 'select(.dir == "input")' game_*.jsonl
```

Count events per type:
```sh
jq -r '.dir' game_*.jsonl | sort | uniq -c
```

Walk the match-level timeline (which games happened in this match):
```sh
jq -c 'select(.dir == "local")' _match.jsonl
```

---

## Gathering from a player (manual, pre-tooling)

When a real bug fires and you need a player's traces:

### 1. Get the player to identify the relevant `match_<room>_<joinedTs>/` dir
- They know roughly when the bug happened. Match dir names carry the
  room number and join timestamp.
- If they can't tell which one, ask for the whole `session_<loginTs>/`
  that contains the bad match.

### 2. Have them tar it up
```sh
# macOS — adjust path for the right session
cd "$HOME/Library/Application Support/Panel Attack/trace_archive"
tar czf ~/panel-trace.tgz session_<loginTs>/match_<room>_<joinedTs>
```

The whole match dir (`_match.jsonl` plus all `game_*.jsonl` inside it)
is what we want. Don't send just one game file — the match file has
the player/spectator changes that the assembler needs.

### 3. Ship to dev
However they prefer — email, signal, scp, git LFS, etc. Traces are
text, generally small (a few KB per minute of play).

### 4. Extract + drop into the fixture dir
```sh
mkdir -p common/tests/fixtures/trace_replays/<bug-slug>
tar xzf panel-trace.tgz -C common/tests/fixtures/trace_replays/<bug-slug>/ --strip-components=2
```

Once the multi-perspective gather tooling lands, this manual flow goes
away. For now this is how we get test inputs into the repo.

---

## What a complete bug report looks like

For a multiplayer bug, you typically need traces from **every player +
spectator** who was in the room. The plan model is:

> 3 clients in a match → 3 trace files for the same gameKey → assemble
> into one fixture → replay each through a TestClient against a local
> Server in tests.

So if a 3-player match goes wrong:
- Ask all 3 players (and any spectator) to find the match dir
- Match dirs have the same `<roomNumber>_<joinedTs>` across players
  (they joined the same room at the same time, approximately)
- Bundle each player's match dir under their `publicId` for the
  fixture

Bundle layout that's coming once the assembler exists:
```
common/tests/fixtures/trace_replays/<bug-slug>/
  4/match_17_1715630400/_match.jsonl
  4/match_17_1715630400/game_1715630423.jsonl
  5/match_17_1715630400/_match.jsonl
  5/match_17_1715630400/game_1715630423.jsonl
  8/match_17_1715630400/_match.jsonl
  8/match_17_1715630400/game_1715630423.jsonl
  server/match_17_1715630400/...  (once server-side trace tap lands)
```

(The directory keys are `publicId` for now; might add player names in
parens for readability.)

---

## Privacy notes

- Display names are public-by-design in Panel Attack — no PII risk
  there.
- Trace files do NOT contain config / character / keybinding data —
  just the JSON sent/received and the engine inputs.
- `clientMeta` (engineVersion, OS, branch, loveVersion) is captured at
  match scope — useful for repro, not personal.
- IPs are NOT in client traces (they're a server-side concept).
- If a fixture goes into the repo, it goes there forever. Don't drop
  in a trace from a real online game without thinking about whether
  the room had real players whose play patterns you'd be archiving.
  For real-bug fixtures this is fine; for "just testing" use locally-
  generated traces from your own play.

---

## Quick reference: things that ARE captured / things that AREN'T

### Captured
- Every server-relayed message this client receives (J, I, G, D, K, H)
- Every wire send this client makes (J, I, G, D, H, E ack)
- Every local engine input this client produced (per-frame, with stack
  index)
- Lifecycle markers: gameBegin / gameEnded
- The matchStart payload (either tapped from the wire for multiplayer
  or synthesized at game start for single-player)

### Not captured (intentionally)
- Server-sent pings (E prefix) — too noisy
- Frame-rate / render-time telemetry
- Other clients' inputs from THEIR keystrokes (we only see their
  relayed I-frames after the server stamps them)
- Local sound / music state
- Crash stack traces — those go through love's existing error handler
  and `reports/` dir, not the trace archive

### Not captured (yet, but should be)
- Scene transitions as explicit lifecycle markers (currently they
  pass through as J messages and land via the network tap)
- Server-side authoritative trace — the dev needs to ALSO grab the
  server's view for cross-perspective work. Phase D' work.

---

## What to do with a trace once you have it

For now: read it, understand what happened, manually craft a TestClient
that replicates the relevant sends against the E2E Harness. The
forthcoming `TestClient:replayTrace(jsonl)` will automate this — once
that lands, dropping a trace into the fixture dir IS the test.
