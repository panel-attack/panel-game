# Pre-existing Test Failures — Audit & Plan

After the loose-sync rewrite (commits `ec00e0f5` → `5dd2d318`), the test suite
shows 5 failures. None of them are *new* regressions from loose-sync. This
doc captures the audit and the disposition of each.

## Decision summary

| Test | Cause | Action | Replacement plan |
|---|---|---|---|
| `StackRollbackReplayTests:liveDesync1` | Asserts `rollbackCount == 5`; the trigger (rollback-on-late-garbage in `Match:pushGarbageTo`) was intentionally removed in Step 4. | **DELETE** | Optional follow-up: write a catch-up test for `Stack:shouldRun` running multiple frames per tick under input lag. Not loose-sync-specific. |
| `RoomTests:basicTest` line 30 | Asserts `firstMsg.messageText.type == "createRoom"` after `Room()` constructor. But `createRoom` is emitted by `Server:create_room`, not by `Room()` directly. Pre-existing test-setup bug. | **FIX** (remove the createRoom assert; keep the rest of the test) | None — concern is incidental; the test's real value (gameplay flow, win counts, replay generation) is preserved. |
| `TeamRoomTests:testPartialRoom_noSpectators` | Asserts spectators *cannot* join partial rooms. Commit `b2bda5cf` intentionally inverted this behavior — spectators *can* now join partial rooms. | **DELETE** | Add a positive test `testPartialRoom_spectatorsAllowed` in `TeamRoomTests.lua` verifying the new behavior. |
| `ServerTests:testSinglePlayer` line 354 | `assertHasMessage`'s predicate uses `deep_content_equal` on `gameMode`. Fails because the room's gameMode is mutated with transport-layer fields (`latencyTolerance`, `connectionTimeoutSeconds`, `sendRetryLimit`) that the preset doesn't have. | **FIX** (compare `gameModeId` field only) | None — the test's real concern (spectate request returns correct game mode) is preserved by the narrower check. |
| `client.tests.TcpClientTests` | Calls `tcpClient:connectToServer(SERVER_IP, 49569)`. Fails because no real server is running during the test run. The file's own header documents this requirement. | **LEAVE** (integration test by design) | Optional: gate behind `PA_RUN_INTEGRATION_TESTS=1` env var so it's skipped by default. Or document in CI setup that a server must be started first. |

## What loose-sync coverage replaces

For each deleted/touched test, what concern was being checked, and how
loose-sync's new test files (LooseSyncTests.lua, LooseSyncServerTests.lua)
relate to it:

**liveDesync1 — rollback under input lag.**
Not covered by the new tests. Loose-sync removed the rollback-on-late-garbage
trigger because in the new model the receiver doesn't gate on the sender's
clock. Stack-level catch-up (`Stack:shouldRun` running multiple frames per
tick when buffer_len ≥ 15) is still in the code and still works; no new test
asserts the exact behavior. If we want it: add a small test that pushes
many frames into a stack's `confirmedInput` and verifies the catch-up loop
runs.

**basicTest createRoom assert — message routing on Room creation.**
Not covered by the new tests. The new server-side tests
(`LooseSyncServerTests`) all assume a match is already in progress. The
"Room construction sequence" itself isn't tested anywhere because Room
is constructed directly by tests rather than going through
`Server:create_room`. Not a loose-sync concern.

**testPartialRoom_noSpectators — partial room spectator policy.**
Replacement: a positive test asserting spectators *can* join partial rooms.

**testSinglePlayer gameMode predicate — spectate request returns correct mode.**
Concern is preserved by the narrower fix. The new tests don't cover
spectate request flows.

**TcpClientTests — TcpClient ↔ real server integration.**
Not covered by the new tests (they mock the transport). This is the only
true transport-layer integration coverage. Leave as-is.
