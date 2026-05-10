-- Comprehensive edge case analysis for multi-slot invite system

print("\n" .. string.rep("=", 70))
print("EDGE CASE ANALYSIS: Multi-Slot Invite System")
print(string.rep("=", 70) .. "\n")

local function test_case(num, name, scenario, risk_level)
  print(string.format("[%d] %s [%s]", num, name, risk_level))
  print("    " .. scenario .. "\n")
end

print("▶ RACE CONDITIONS & TIMING\n")

test_case(1, "Concurrent mutual acceptance",
  "P1 and P2 both send acceptance simultaneously for same room+slot.",
  "MEDIUM")

test_case(2, "Withdrawal during handshake",
  "P2 sends withdraw while P1's acceptance is in flight.",
  "MEDIUM")

test_case(3, "Join after disconnect",
  "P2 disconnects but join message still in queue when P2 leaves.",
  "LOW")

test_case(4, "Room fills during join validation",
  "Join starts validation (room has space), but fills before addPlayer() executes.",
  "MEDIUM")

print("\n▶ STATE CONSISTENCY ISSUES\n")

test_case(5, "Stale slot request references",
  "Client lobby shows slot open, but server already assigned it. Client tries to request.",
  "LOW")

test_case(6, "Proposal expires silently",
  "Player offline 48 hours, proposal still in server.proposals table.",
  "MEDIUM")

test_case(7, "Mismatched player/proposal lifecycle",
  "Player joins room A, proposal still references room A. Player leaves, joins room B.",
  "LOW")

test_case(8, "Team assignment race condition",
  "Room fills out-of-order, teams calculated before all joins complete.",
  "HIGH")

print("\n▶ MULTI-ROOM EDGE CASES\n")

test_case(9, "Player in room + pending invite for another room",
  "P1 in room 1, receives invite to room 2. Tries to accept room 2 (already in room 1).",
  "LOW")

test_case(10, "Cross-room proposal confusion",
  "P1 creates rooms 1 and 2 (same slot numbers). Gets confused proposals.",
  "LOW")

test_case(11, "Room deleted while invite pending",
  "Room 1 closed/deleted. P2's proposal still exists. Server crashes trying to access room.",
  "MEDIUM")

print("\n▶ MULTI-PLAYER SCENARIOS\n")

test_case(12, "Everyone requests same slot",
  "P2, P3, P4 all request slot 2. Only one can join. Others' proposals should update.",
  "LOW")

test_case(13, "Cascade rejection (room fills mid-batch)",
  "5 players request. Room accepts first 3. Other 2 requests should be rejected/withdrawn.",
  "MEDIUM")

test_case(14, "Spectator trying to join as player",
  "P5 spectating room 1, tries to accept join invite. Both spectator + player in room?",
  "MEDIUM")

print("\n▶ NETWORK ISSUES\n")

test_case(15, "Duplicate message delivery",
  "P2 requests slot 2. Message delivered twice (network retry).",
  "LOW")

test_case(16, "Out-of-order message delivery",
  "P2 sends: request slot 2, then withdraw. Messages arrive: withdraw, then request.",
  "HIGH")

test_case(17, "Message loss & no timeout",
  "P1 sends invite. P2 accepts. P1 never receives acceptance ACK. Stuck in 'waiting'.",
  "MEDIUM")

print("\n▶ UI/CLIENT ISSUES\n")

test_case(18, "Stale UI after join",
  "P2 joins, but P3's client doesn't update immediately. UI shows join button (should be gone).",
  "LOW")

test_case(19, "Button mashing requests",
  "P2 spams 'Join Slot 2' button 10 times in 1 second.",
  "LOW")

test_case(20, "Disconnect mid-handshake",
  "P2 starts accept, disconnects before confirmation sent.",
  "LOW")

print("\n▶ GAME LOGIC ISSUES\n")

test_case(21, "Team imbalance from late joins",
  "2v2 room: P1+P2 vs P3+P4. P2 joins slot 2 (team A), P3 joins slot 1 (wrong team!).",
  "HIGH")

test_case(22, "Game starts before all joins complete",
  "Room starts game after 2/4 players, then P3/P4 try to join.",
  "MEDIUM")

test_case(23, "Match end before join processed",
  "Match completes before P4's join accepted. P4 gets added to already-finished match.",
  "MEDIUM")

print("\n▶ PERSISTENCE ISSUES\n")

test_case(24, "Proposals survive server restart",
  "Server crashes with stale proposals. On restart, old proposals still there.",
  "MEDIUM")

test_case(25, "Cross-session player confusion",
  "Player disconnects, new session as different public ID, old proposals reference old ID.",
  "LOW")

print("\n" .. string.rep("=", 70))
print("PRIORITY FIXES")
print(string.rep("=", 70) .. "\n")

print("🔴 CRITICAL (Game Breaking):")
print("  8.  Team assignment race - teams calculated during out-of-order joins")
print("  16. Out-of-order messages - request/withdraw race condition")
print("  21. Team imbalance - wrong player in wrong team slot\n")

print("🟡 HIGH (Affects Gameplay):")
print("  4.  Room fills during join validation")
print("  13. Cascade rejection - multiple rejections not communicated")
print("  22. Game starts before all joins complete\n")

print("🟠 MEDIUM (Data Integrity):")
print("  1.  Concurrent mutual acceptance")
print("  2.  Withdrawal during handshake")
print("  6.  Proposal expires silently")
print("  11. Room deleted while invite pending")
print("  14. Spectator trying to join as player")
print("  17. Message loss & no timeout")
print("  23. Match end before join processed")
print("  24. Proposals survive server restart\n")

print("🟢 LOW (Edge Case):")
print("  3, 5, 7, 9, 10, 12, 15, 18, 19, 20, 25\n")

print("\n" .. string.rep("=", 70))
print("RECOMMENDED NEXT FIXES (In Order)")
print(string.rep("=", 70) .. "\n")

print("1. 🔴 Add TTL to proposals (expire after 5 min inactivity)")
print("   - Prevents #6 and #24\n")

print("2. 🔴 Add idempotency key to join requests")
print("   - Prevents duplicate joins from #15\n")

print("3. 🟡 Add validation: don't join if game started")
print("   - Prevents #22\n")

print("4. 🟠 Add ACK for join completion")
print("   - Prevents #17 (silent failure)\n")

print("5. 🟠 Add room.state check in handleJoinRoom")
print("   - Prevents joining lobby-only or closed rooms\n")
