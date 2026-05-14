# UDP Netcode Migration Plan

Goal: move latency-sensitive gameplay messages off the single TCP socket
onto UDP with custom reliability, to eliminate TCP head-of-line blocking
during a packet drop. Keep TCP for stateful/heavy messages. Roll out
without breaking existing players.

This plan is grounded in the actual code paths. Every phase names the
files and functions it modifies, the tests it adds, and the conditions
under which it can be considered done.

## Current state (factual baseline)

- One TCP socket per client. Bound on the server at
  `server/server.lua:253` via `socket.bind("*", port)`; opened on the
  client at `client/src/network/TcpClient.lua:53` via `socket.tcp()`
  with `settimeout(0)` (non-blocking).
- Single port (default 49569 per `server/server_globals.lua`).
- All messages multiplex over that one socket using a 1-char prefix
  + variable body + `←J←` terminator. Prefixes and registry live in
  `common/network/NetworkProtocol.lua` (`NETWORK_VERSION = "008"`).
- Message types and their planned transport target:

  | Prefix | Type | Today | Plan |
  |---|---|---|---|
  | `I` | player input | TCP | **UDP unreliable + redundant pack** |
  | `G` | garbage event | TCP | **UDP reliable** |
  | `D` | death event | TCP | **UDP reliable** |
  | `K` | KO arbitration | TCP | **UDP reliable** |
  | `E` | ping/pong | TCP | UDP (small, useful as link probe) |
  | `H` | version handshake | TCP | TCP (login channel) |
  | `J` | all JSON (lobby, room, chat, replay, settings, ...) | TCP | **TCP (unchanged)** |

- Receive plumbing on the client: `TcpClient:readSocket`
  (`client/src/network/TcpClient.lua:72`) reads non-blocking,
  appends to a buffer, splits via `NetworkProtocol.getMessageFromString`
  (`common/network/NetworkProtocol.lua:82`), and pushes typed messages
  to `TcpClient.receivedMessageQueue`. Then per-type drainers in
  `NetClient` pop with `pop_all_with(prefix)` and route.
- Outgoing: `TcpClient:sendMessage` (line 144) queues a string;
  `sendQueuedMessages` (line 112) writes to the socket each `updateNetwork`
  tick.

This structure is friendly to the migration: as long as we deliver a
typed message to the same drain queue, the upstream code doesn't care
whether it arrived over TCP or UDP.

## Architectural decisions

### Wire format (UDP)

Each UDP datagram carries a small fixed header followed by 1+ framed
messages. We don't reuse the TCP framing (`←J←` terminator) because UDP
is datagram-bounded — we know the length up front.

```
header (8 bytes):
  [0]    magic         0xPA          (sanity check, drop foreign datagrams)
  [1]    channel       0=unreliable, 1=reliable
  [2-3]  packet_seq    u16, per-channel, per-direction
  [4-7]  ack_bitmap    u32: bit i set = "I received packet_seq - 1 - i"
                       (32-packet window). For the unreliable channel this
                       is unused; for reliable, it's how the sender knows
                       what's been delivered.

payload:
  one or more messages, each:
    [0]    prefix        1 byte (same prefix space as NetworkProtocol)
    [1-2]  length        u16 little-endian
    [3..]  body          length bytes
```

Why u16 seq + 32-bit ack bitmap: standard quake/gaffer-on-games shape.
Half-window comparison handles wrap. 32-packet window is enough for
~500ms at 60Hz.

Magic byte gates "is this for us at all?" cheaply — the UDP socket can
receive any datagram from any source so we want a fast reject path.

### Reliability semantics per message type

- **`I` (input)**: unreliable channel. Each packet for frame N carries
  the inputs for frames `[N-2..N]` (3-frame redundant window). If a packet
  drops, the next one already contains the missing input. **Never
  retransmit on demand** — a stale input is useless once the engine
  has passed that frame. The 3-frame redundancy is the recovery.
- **`G`, `D`, `K` (events)**: reliable channel. Send → wait for ACK in
  the bitmap of an incoming packet → if not ACK'd within 50ms,
  retransmit. Cap at 8 retransmits then surface a connection-level error.
- **`E` (ping)**: unreliable, also serves as keepalive + RTT probe.

### Session model

- The client logs in over TCP as today (`client/src/network/LoginRoutine.lua`),
  receives a `udpSessionToken` and `udpPort` in the login response.
- Client opens a UDP socket, sends a `Hello{token}` datagram to
  `server_ip:udpPort`. Server pairs that datagram's source `(ip, port)`
  with the player. **No NAT punching needed** — the server has a public
  IP; the NAT hole opens on the first outbound packet from the client.
- Until the server has paired the UDP socket with the player, ALL
  messages continue to flow over TCP. The UDP migration is a per-player
  capability that activates once pairing is confirmed.
- Keepalive: client sends an empty UDP packet (or piggy-backs on input)
  every 1s. If the server hasn't seen UDP from the player in 5s, server
  marks UDP as down for that player and falls back to TCP for the
  UDP-class messages. Recoverable on next successful UDP packet.

### Backward compatibility

- TCP send paths remain in place throughout this plan. Every
  UDP-migrated message stays sendable over TCP via a runtime flag.
- Old clients (no UDP) hit the same TCP code paths they hit today. Server
  detects "no UDP pairing" → sends everything over TCP. **Zero
  regression for unupgraded clients.**
- `NETWORK_VERSION` bumps to `"009"` only when we're ready to require UDP
  (Phase 6). Phases 1-5 stay on `"008"` so mixed-version play works.

## Phase plan

Each phase is independently shippable. After each phase, gameplay over
TCP continues to work; the only thing that changes is which messages
ride which transport.

### Phase 0 — Spec lock

**Outputs:**
- This document, reviewed and signed off.
- `docs/UDP_WIRE_FORMAT.md` formalizing the header/payload layout and
  the sequence/ACK algorithm with concrete pseudocode.

**Done when:** the wire format is committed and we agree on the
session/handshake flow before any production code is touched.

### Phase 1 — `UdpReliable` reliability layer (isolated, testable)

**New files:**
- `common/network/UdpReliable.lua` — pure-Lua state machine. No socket
  I/O inside this module; it operates on opaque byte strings.
- `common/network/tests/UdpReliableTests.lua` — registered in
  `serverTestRunner.lua` so it runs under `run_server_tests.sh` (headless,
  no port bound, no real time).

**API surface:**
```lua
local UdpReliable = require("common.network.UdpReliable")
local r = UdpReliable.new({ now_fn = ..., max_in_flight = 32 })

-- Outbound:
r:sendUnreliable(payload)           -- returns a packet bytestring to ship
r:sendReliable(payload)             -- ditto; tracks until ACKed
r:tick(now)                         -- returns 0+ packet bytestrings (retransmits)

-- Inbound:
local messages, ackInfo = r:receive(packetBytes)
-- messages: array of decoded payloads (or {} on duplicate/invalid)
-- ackInfo: bitmap reflecting what we've received, attached to next outbound
```

**Tests cover:**
- Deterministic clock (`now_fn` injected). No real timer.
- Seq wraparound (push 70k packets, assert order/ack still works).
- Drop scenarios: drop packets 5 + 10 + 17, assert reliable retransmits, assert unreliable doesn't.
- Reorder: deliver `[1,3,2,5,4,6]`, assert receiver yields in order with no duplication.
- ACK feedback: sender sees ACK bitmap, stops retransmitting; missing ACK keeps it queued.
- Bounded retransmit attempts (8 max).
- Bad input: random bytes, truncated header, wrong magic — `receive` returns no messages and doesn't crash.

**Done when:** test suite passes 100% with `run_server_tests.sh`. Zero
production code touched outside the new files.

### Phase 2 — Server UDP listener (plumbing only, no routing)

**Files modified:**
- `server/server.lua:244-273` (`Server:start` / `Server:stop`): bind a UDP
  socket on the same port as TCP (luasocket supports this on most
  platforms). Hold the handle on `Server.udpSocket`.
- `server/server.lua` main loop (find the `select` or polling pattern;
  likely around the same area as `Server:start`): add UDP socket to the
  read set, on incoming datagram log `(src_ip, src_port, len, first_byte)`
  and drop.

**Tests:**
- `server/tests/UdpListenerTests.lua`: with `MockSocket`, assert
  `Server:start` opens both TCP and UDP and `Server:stop` closes both.
  Smoke test: feed a known datagram, assert it shows up in the log
  hook without crashing.

**Done when:** server starts, listens on UDP, drops every datagram with
a log line. **No gameplay change.** Real TIME_WAIT / port-bind retry
behavior verified by running `run_server.sh` and confirming both
sockets bind cleanly.

### Phase 3 — Client UDP socket + handshake

**Files modified:**
- `client/src/network/TcpClient.lua`: rename internally to keep TCP
  responsibilities, but it stays a TCP-only class. No change to its
  public surface yet.
- New file `client/src/network/UdpClient.lua` (sibling to `TcpClient`,
  similar shape). Owns the UDP socket, a `UdpReliable` instance, and an
  inbox queue compatible with `TcpClient.receivedMessageQueue` so
  downstream code can drain it uniformly.
- `client/src/network/LoginRoutine.lua`: parse `udpPort` and
  `udpSessionToken` fields from the login response (if present). After
  login succeeds, open `UdpClient`, send `Hello{token}` datagram.
- `common/network/ServerProtocol.lua`: add `udpPort` and
  `udpSessionToken` to the login-success message builder. Optional
  fields (old clients ignore them).
- `server/server.lua` login handler (in the `Server:` methods around
  the login path): generate a session token (16 random bytes, hex
  encoded), include in login response, pair UDP source `(ip, port)` to
  the player on receipt of `Hello{token}`.
- `client/src/network/NetClient.lua`: a `udpReady` flag on the room.
  Set true once pairing handshake completes. Drives transport choice in
  later phases.

**Tests:**
- `client/tests/UdpHandshakeTests.lua` (or extend an existing test that
  exercises login): mock the UDP socket pair, assert client sends
  `Hello{token}` and `udpReady` flips true after a corresponding
  server-side pair message.

**Done when:** A real client + real server connect, pair UDP, and
`udpReady` is true client-side. **Nothing actually rides UDP yet.** If
UDP pairing fails (token mismatch, firewall), `udpReady` stays false
and play continues over TCP unchanged.

### Phase 4 — Migrate `I` (input) to UDP

This is the highest-volume message type and the one most affected by
HoL. Moving it should produce the biggest perceived improvement.

**Files modified:**
- `client/src/network/PlayerStack.lua:65` (`send_controls`): currently
  calls `GAME.netClient:sendInput(to_send)`. Change `sendInput` to
  prefer UDP when `udpReady`:
  - UDP path: pack last 3 frames into a payload, hand to `UdpClient`
    via `sendUnreliable`.
  - TCP fallback (when `udpReady` is false): existing
    `TcpClient:sendMessage`.
- `server/server.lua` input forwarding (search for where `I` messages
  get relayed to other players in the room): identical fallback logic
  per recipient. Recipient with `udpReady` true gets it on UDP; others
  get TCP as today.
- `client/src/network/NetClient.lua` `processInputMessages` (line 663):
  drain UDP inbox in addition to TCP queue. Deduplicate by
  `(playerNumber, inputFrame)`. Since each UDP input packet carries 3
  frames, expect duplicates as the normal case — dedup is essential.

**New globals/flags:**
- `server/server_globals.lua`: `UDP_INPUTS_ENABLED = false` (default
  off). Server-side master switch. We can turn it on per room or
  globally for staged rollout.

**Tests:**
- Add to `server/tests/LooseSyncServerTests.lua` (or a new
  `UdpInputRelayTests.lua`): 3-player room, mixed UDP/TCP capability.
  Sender on UDP, recipient A on UDP, recipient B on TCP. Assert all 3
  receive the relayed input.
- Drop simulation: inject lost packets in the `MockSocket`, assert that
  redundant packing + smoother eventually delivers all inputs (zero
  missing frames in the test recipient's `confirmedInput`).

**Done when:** With flag on, a real match plays end-to-end on a
controlled test server. With flag off, behavior is identical to today.
Compare `droppedFrameCount` and feel between flag on/off as a smoke
check.

### Phase 5 — Migrate `G`, `D`, `K` to UDP-reliable

**Files modified:**
- `client/src/network/NetClient.lua` `processGarbageEvents` (line 681),
  `processDeathEvents` (line 693), `processKOArbitrations` (line 705):
  same dual-channel drain + dedupe as Phase 4.
- Server-side emitters (in `server/Game.lua` and `server/Room.lua` —
  grep for `garbageEvent.prefix` and `deathEvent.prefix`): mirror the
  capability check, send via UDP-reliable when both sides ready.
- Each message type gets its own `_ENABLED` flag in `server_globals.lua`
  for granular rollback.

**Tests:**
- Extend `LooseSyncServerTests` and the loose-sync regression suite to
  cover UDP delivery with simulated drops + reorder. The existing tests
  exercise the in-flight invariants; we just need to run them with the
  UDP transport in place.

**Done when:** All three event types deliverable over UDP-reliable in a
flag-on test match. Flag-off path is unchanged.

### Phase 6 — Force cutover (only when confident)

**Trigger criteria** (don't proceed until all true):
- Phase 4 + 5 have been on by default for ≥2 weeks of player traffic.
- No regression bugs filed against the UDP path in that window.
- Server logs show <0.5% of players falling back to TCP for UDP-class
  messages (i.e., almost everyone successfully pairs UDP).

**Files modified:**
- `common/network/NetworkProtocol.lua`: bump `NETWORK_VERSION` to
  `"009"`. Add a "version too old" message that explains the client
  needs to update.
- `server/server.lua`: reject `H008` clients with a clear error.
- Delete the TCP fallback paths for `I`/`G`/`D`/`K` (the easy part).

**Done when:** No code path can send `I`/`G`/`D`/`K` over TCP anymore.
Wire is simpler. Older versions of the client surface a clean "please
update" rather than mysterious behavior.

## Specific risks and mitigations

| Risk | Mitigation |
|---|---|
| Reliability-layer bug corrupts message order, causes desyncs that look like gameplay bugs | Phase 1's deterministic test suite is the gate. No production wiring until it's green. |
| `socket.bind` on UDP conflicts with TCP on same port on some hosts | Phase 2 verifies on real production env before any client code. If conflict, allocate a separate UDP port and ship it in the login response — the design already supports this. |
| Symmetric NAT or firewall blocks UDP entirely for some players | `udpReady` stays false, TCP fallback handles them as today. They see no improvement but no regression. Log the rate to know how big the problem is. |
| Keepalive heuristic flaps (server thinks UDP is down briefly, switches messages mid-match) | Hysteresis: only mark down after 5s of silence; only mark up after a successful round-trip. Don't switch mid-match unless absolutely necessary. |
| UDP MTU fragmentation | Garbage event sizes: audit during Phase 5 by logging body length. Cap at 1200 bytes. If we ever exceed that, split into multiple datagrams with an in-app fragment header (or stay on TCP for that message — totally acceptable). |
| Sequence wraparound bugs at u16 | Phase 1 includes an explicit wraparound test that pushes >65536 packets through the state machine. |
| Replay format depends on input timing being captured per `send_controls` call | UDP doesn't change when `send_controls` fires (still once per `ClientMatch:run` iteration). Local input is still applied to `confirmedInput` directly, same as the double-feed fix. Replays should be unaffected; add a regression test that records a match across the migration and replays it on the old code path. |
| Server CPU rises from per-datagram userspace handling | Phase 4 includes a benchmark: measure CPU at 7-player room with all inputs over UDP, compare against TCP baseline. If unacceptable, optimize (batch reads, raise socket buffer sizes) before Phase 5. |

## What's intentionally not in this plan

- **Peer-to-peer.** Stays server-relayed. P2P is a separate, larger
  question (anti-cheat, NAT traversal, ICE/STUN/TURN).
- **Encryption.** UDP packets are plaintext in this design, same as TCP
  is today. If we ever add TLS it'd be a separate effort and would apply
  to both transports.
- **Protocol redesign.** This is purely a transport change. The prior
  proposal in `docs/Proposal for a new network protocol.md` (message
  shape redesign, separation of player and game data, etc.) is
  orthogonal and can ship independently before or after.

## File inventory (what gets touched)

New files:
- `common/network/UdpReliable.lua`
- `common/network/tests/UdpReliableTests.lua`
- `client/src/network/UdpClient.lua`
- `client/src/tests/UdpHandshakeTests.lua` (or merge into existing)
- `server/tests/UdpListenerTests.lua`
- `server/tests/UdpInputRelayTests.lua`
- `docs/UDP_WIRE_FORMAT.md`

Modified files:
- `common/network/NetworkProtocol.lua` — version bump (Phase 6)
- `common/network/ServerProtocol.lua` — login response fields (Phase 3)
- `client/src/network/TcpClient.lua` — none of its API changes; internal cleanup only
- `client/src/network/NetClient.lua` — dual-channel drain in process* functions (Phases 4-5)
- `client/src/network/LoginRoutine.lua` — parse UDP session info (Phase 3)
- `client/src/network/PlayerStack.lua` — input send path (Phase 4)
- `server/server.lua` — UDP listener bind, login token, relay capability (Phases 2,3,4,5)
- `server/server_globals.lua` — feature flags
- `server/Game.lua` / `server/Room.lua` — event emit paths (Phase 5)

Tests added to `serverTestRunner.lua` registration so they run under
`run_server_tests.sh`.

## Status tracker

- [ ] Phase 0 — spec lock
- [ ] Phase 1 — `UdpReliable` + tests
- [ ] Phase 2 — server UDP listener (plumbing)
- [ ] Phase 3 — client UDP socket + handshake
- [ ] Phase 4 — migrate `I` (input)
- [ ] Phase 5 — migrate `G`/`D`/`K` events
- [ ] Phase 6 — force cutover, delete TCP fallback
