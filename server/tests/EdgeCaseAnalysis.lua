-- Edge case scenarios for multi-slot invite system

print("\n=== Edge Case Analysis for Multi-Slot Invite System ===\n")

local scenarios = {
  {
    name = "1. Player leaves room before accepting slot request",
    description = "P1 creates room, P2 requests slot 2, P2 leaves lobby. P2's proposal should be cleared.",
    status = "NEEDS CHECK",
    issue = "When P2 disconnects, does clearProposals(P2) get called? Check Connection:close()"
  },
  {
    name = "2. Player requests same slot twice",
    description = "P2 requests slot 2, then requests slot 2 again. Should be idempotent.",
    status = "LIKELY OK",
    issue = "updateChallenge() just overwrites, so duplicate requests are safe"
  },
  {
    name = "3. Multiple players request same slot",
    description = "P2 requests slot 2, P3 requests slot 2. Both proposals stored. What happens if P1 accepts one?",
    status = "UNKNOWN",
    issue = "Server checks if slot is open, so only first mutual acceptance triggers join. Other should get rejected when slot no longer open."
  },
  {
    name = "4. Request withdrawal race condition",
    description = "P2 requests slot 2, then immediately withdraws. P1 tries to accept simultaneously.",
    status = "UNKNOWN",
    issue = "Race between withdrawal message and acceptance message in server queue"
  },
  {
    name = "5. Stale lobby state on client",
    description = "Client shows slot 2 open but server already gave it to someone else. Client tries to request.",
    status = "PROBABLY HANDLED",
    issue = "Server validates slot is open before joining, so should reject. Client cleanup on next lobbyStateV2 should remove the proposal."
  },
  {
    name = "6. Player joins room, then same player tries to join different slot",
    description = "P2 joins slot 2, then P2 tries to request slot 3 in same room.",
    status = "SHOULD FAIL",
    issue = "If P2 is already in room, should reject. Check processChallengeUpdate sender/receiver state checks."
  },
  {
    name = "7. Room gets full between request and acceptance",
    description = "P2 requests slot 2, P3 requests slot 3, P4 requests slot 4. Room has 4 slots. Multiple join simultaneously.",
    status = "NEEDS CHECK",
    issue = "addPlayer() will fail when room full, but do we properly reject the join request?"
  },
  {
    name = "8. Player requests slot N but joins slot N+1",
    description = "Slot structure: player count doesn't match slot numbers (team scenarios?)",
    status = "UNKNOWN",
    issue = "Server always adds to 'next available position' (#players+1), not requested slot. Is this intended?"
  },
  {
    name = "9. Proposal expires (player offline too long)",
    description = "P2 sends join request but never responds. Proposal sits in server.proposals forever.",
    status = "NO CLEANUP",
    issue = "No TTL on proposals. Server proposals table grows indefinitely with stale entries."
  },
  {
    name = "10. Player joins room, another player's incoming proposal still references old room",
    description = "P2 joins room 1, then room 1 fills up. P2 gets kicked. P2's stale incoming proposals for room 1 should be cleared.",
    status = "PARTIALLY OK",
    issue = "isInviteObsoleteForJoinedPlayer checks if target in same room, but not if room became full/empty."
  },
}

for _, scenario in ipairs(scenarios) do
  print(string.format("[%s] %s", scenario.status, scenario.name))
  print(string.format("  Desc: %s", scenario.description))
  print(string.format("  Issue: %s\n", scenario.issue))
end

print("\n=== Priority Issues ===\n")
print("🔴 CRITICAL:")
print("  - Edge case #7: Race condition when room fills up")
print("  - Edge case #1: Proposals not cleared on disconnect")
print("  - Edge case #9: Stale proposals never cleaned up\n")

print("🟡 MEDIUM:")
print("  - Edge case #4: Request withdrawal race condition")
print("  - Edge case #8: Slot number semantics (requested vs actual)")
print("  - Edge case #3: Multiple requests for same slot\n")

print("🟢 LOW:")
print("  - Edge case #2: Duplicate requests (probably OK)")
print("  - Edge case #5: Stale lobby state (probably handled)")
print("  - Edge case #6: Player already in room tries to join different slot")
