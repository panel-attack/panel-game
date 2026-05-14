# Dual-Socket Refactor — Working Plan

Split the single TCP socket into two independent TCP sockets:

- **GameplayTcpClient / port 49569** → carries latency-sensitive traffic:
  `I` (input), `G` (garbage event), `D` (death event), `K` (KO arbitration),
  `E` (ping), `H` (version handshake).
- **LobbyTcpClient / port 49570** → carries chatty/stateful traffic:
  `J` (all JSON: lobby, room, chat, replays, settings, etc.) + its own `H` + `E`.

Each socket is fully independent. Each does its own version handshake and
login. Server tracks `player.gameplayConnection` and `player.lobbyConnection`
separately. Either socket can fail independently:
- Gameplay drop → full session disconnect.
- Lobby drop → silent reconnect, no user-visible impact.

**No shared base class, no flag for "single-socket mode", no pairing token.**
Two distinct files with copy-pasted bodies and distinct class names so any
code-reader knows immediately which one they're looking at.

## Commits (the checklist)

### Commit 1 — Foundation files, no behavior change
- [x] Create `client/src/network/GameplayTcpClient.lua` (copy of TcpClient, class renamed)
- [ ] Create `client/src/network/LobbyTcpClient.lua` (copy of TcpClient, class renamed)
- [ ] Add `LOBBY_PORT = 49570` to `server/server_globals.lua`
- [ ] Verify everything still loads / current tests pass

The two new files exist but nothing instantiates them yet. Old `TcpClient.lua`
stays untouched. **Server and client behave identically to today.**

### Commit 2 — Server binds 2nd port, accepts on both
- [ ] `Server:start` (`server/server.lua:244`) binds a second listener:
      `self.lobbyListenSocket = socket.bind("*", LOBBY_PORT)`
- [ ] `Server:stop` closes both listeners
- [ ] `Server:acceptNewConnections` accepts from BOTH listeners
- [ ] Each accepted `Connection` gets a `self.channel` field ("gameplay" or "lobby")
- [ ] `Server:updateConnections` reads from both (already select-based; just
      need to include both listener sockets in the read set if needed and
      include all connection sockets regardless of channel)

After this commit: server listens on both ports, accepts connections,
tags each as gameplay or lobby. **Client hasn't changed yet, so only
gameplay connections actually get established.** Lobby listener just sits
there empty.

### Commit 3 — Player tracks both connections; outbound routing by prefix
- [ ] `Player.lua`: replace `self.connection` with:
  - `self.gameplayConnection` (set when a gameplay-channel connection logs in as this player)
  - `self.lobbyConnection` (set when a lobby-channel connection logs in as this player)
- [ ] `Player:sendJson(message)` → routes to `self.lobbyConnection`
- [ ] `Player:send(rawMessage)` → inspects first byte (the prefix):
  - `J` → `self.lobbyConnection`
  - else → `self.gameplayConnection`
- [ ] Update all places in `server.lua`, `Room.lua`, `Game.lua` that read
      `player.connection` → audit each: which channel does it want?
- [ ] When either connection drops:
  - gameplay drop → full disconnect (close both, remove from rooms, etc.)
  - lobby drop → mark `self.lobbyConnection = nil`, log it. Player can
    keep playing; can attempt reconnect on lobby separately.

After this commit: server can route outbound traffic to the correct
socket per player. **No client-side change yet, so the lobby connection
is always nil. Everything still flows through `gameplayConnection`** —
which means `Player:sendJson` will need a temporary fallback: if
`lobbyConnection == nil`, send via `gameplayConnection`. This fallback is
removed in Commit 5.

### Commit 4 — Client instantiates both clients, both login independently
- [ ] `NetClient.lua`:
  - Replace `self.tcpClient = TcpClient()` with:
    - `self.gameplayClient = GameplayTcpClient()`
    - `self.lobbyClient = LobbyTcpClient()`
- [ ] `LoginRoutine.lua`:
  - Connect gameplay client to `(ip, SERVER_PORT)`, send version handshake + login
  - Connect lobby client to `(ip, LOBBY_PORT)`, send version handshake + login
  - Both must succeed before login is considered complete
  - Failure of EITHER means abort; close both
- [ ] Server's login handler:
  - Connection on gameplay channel logs in → look up Player by privateUserId,
    bind as `player.gameplayConnection`
  - Connection on lobby channel logs in → look up Player by privateUserId,
    bind as `player.lobbyConnection`
- [ ] Backward compat note: old clients only know one port. Server must
      tolerate this initially (player with only gameplayConnection set,
      lobbyConnection nil, still works via the fallback from Commit 3).
      Mark the new client as version `"009"` if we need to disambiguate;
      otherwise rely on the "old client never connects to lobby port" fact.

After this commit: new clients open both sockets. Server has both
connections per player. **Still no message routing on the client side —
all outbound still goes through gameplayClient.**

### Commit 5 — Wire routing: J → lobby, everything else → gameplay
- [ ] `NetClient.lua` call sites: route by intent
  - `sendInput` → `gameplayClient`
  - `sendRequest` (JSON) → `lobbyClient`
  - `send(rawMessage)` → route by prefix (first byte: `J` → lobby, else gameplay)
  - `dropOldInputMessages` → `gameplayClient` (already prefix-specific)
  - Drain `processInputMessages` / `processGarbageEvents` / `processDeathEvents` /
    `processKOArbitrations` from `gameplayClient.receivedMessageQueue`
  - Drain JSON message processing from `lobbyClient.receivedMessageQueue`
  - `:update(dt)` calls: both clients need their `updateNetwork(dt)` and
    `processIncomingMessages` called each tick
- [ ] Server side: REMOVE the fallback in `Player:sendJson`. If
      `lobbyConnection == nil`, treat as a disconnected channel: queue
      messages until reconnect, or drop with a warning.

After this commit: traffic is actually split. Lobby spam can't cause
HoL on inputs. **Behavior change: this is the actual delivery of the
fix.**

### Commit 6 — Update tests
- [ ] `MockConnection` / `MockPersistence` / test harness updates so
      tests can simulate both channels per player.
- [ ] Add a dual-socket smoke test that:
  - Stands up the server (mock)
  - Has 2 mock clients each open both connections
  - Verifies J flows over lobby, I flows over gameplay
- [ ] Run full `run_server_tests.sh`; fix any breakage.

### Commit 7 (optional) — Delete TcpClient.lua
- [ ] If nothing still requires it, remove the original `TcpClient.lua`.

## Routing table (canonical)

Use this when in doubt about which client/connection a message belongs to.

| Prefix | Direction | Channel | Notes |
|---|---|---|---|
| `H` (version) | both | both | each socket does its own version handshake on connect |
| `E` (ping/ack) | both | both | each socket has its own keepalive |
| `J` (JSON) | both | **lobby** | login, lobby state, room state, chat, replays, settings |
| `I` (input) | both | **gameplay** | sender's encoded input + server's relay |
| `G` (garbage event) | both | **gameplay** | loose-sync garbage relay |
| `D` (death event) | both | **gameplay** | loose-sync death relay |
| `K` (KO arbitration) | server→client | **gameplay** | server-authored result |

## Invariants we must preserve

- **Gameplay handlers tolerate missing state.** A gameplay message
  referencing an unknown player/room/match must DROP silently, not error.
  Already true today (`ClientMatch:receiveInput` checks `if not stack`,
  etc.). Document and audit during Commit 3 / 5.
- **Login is atomic across both sockets.** Either both authenticate or
  neither: surface a single login result. If gameplay logs in but lobby
  fails, abort everything.
- **Gameplay drop = full disconnect.** Both sockets close.
- **Lobby drop = silent.** Player keeps playing; can reconnect lobby
  independently. No room/match changes from a lobby-only drop.

## Files touched (inventory)

New:
- `client/src/network/GameplayTcpClient.lua`
- `client/src/network/LobbyTcpClient.lua`

Modified:
- `server/server_globals.lua` — add `LOBBY_PORT`
- `server/server.lua` — bind second listener, accept on both, channel tag
- `server/Connection.lua` — add `channel` field
- `server/Player.lua` — split connection field, prefix-based routing
- `server/Room.lua` — audit `player.connection` references (read-only audit; most use `player:sendJson`/`player:send` which route automatically once Player.lua is updated)
- `server/Game.lua` — same audit as Room
- `client/src/network/NetClient.lua` — two clients, prefix routing
- `client/src/network/LoginRoutine.lua` — login on both sockets

Possibly modified (test infra):
- Test mocks for Connection / Player
- `server/tests/` test files that construct a Player

Deprecated / to delete:
- `client/src/network/TcpClient.lua` — only after all consumers migrated

## Current status

- [x] Plan written (this file)
- [x] Commit 1 — foundation files (GameplayTcpClient, LobbyTcpClient, LOBBY_PORT)
- [x] Commit 2 — server binds 2nd listener, accepts on both, channel-tagged
- [x] Commit 3 — Player gameplay/lobby connections + outbound routing by prefix
- [ ] Commit 4 — NetClient dual instantiate + LoginRoutine connects both
- [ ] Commit 5 — actual message routing wire-up (J → lobby, others → gameplay)
- [ ] Commit 6 — update tests

I update this file as I complete each commit. If I deviate, the deviation
gets recorded here first.
