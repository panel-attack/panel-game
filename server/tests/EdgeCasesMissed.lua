-- EVEN MORE SUBTLE EDGE CASES - Deep dive

print("\n" .. string.rep("=", 80))
print("ADDITIONAL EDGE CASES - EVEN MORE SUBTLE")
print(string.rep("=", 80) .. "\n")

print("▶ CONCURRENCY & ITERATION SAFETY\n")

print("[41] clearProposals called during proposal iteration")
print("    clearProposals modifies self.proposals while lobbyStateV2 is iterating it")
print("    Scenario: Join accepted → clearProposals() → while iterating proposals")
print("    Risk: Lua table iteration becomes undefined")
print("    Severity: MEDIUM\n")

print("[42] Room:addPlayer() called while room.players being iterated")
print("    processChallengeUpdate sends to all players while one joining")
print("    Risk: Send buffer corrupted or player skipped")
print("    Severity: MEDIUM\n")

print("[43] Proposal callback fires after player.connection closed")
print("    Player joins, connection closes, but join message still in queue")
print("    Risk: Accessing closed connection, crash")
print("    Severity: MEDIUM\n")

print("\n▶ NULL REFERENCE VULNERABILITIES\n")

print("[44] Player object becomes nil between checks")
print("    Validation passes (player exists), then player logs out")
print("    Dereference happens on nil player")
print("    Risk: Runtime nil error, server crash")
print("    Severity: HIGH\n")

print("[45] Room deleted between checks")
print("    Verify room exists, room gets closed, try to join")
print("    Risk: Accessing deleted room object")
print("    Severity: MEDIUM\n")

print("[46] leaderboard.players[userId] becomes nil")
print("    Player not in leaderboard (new player, no rating)")
print("    lobbyStateV2 tries to access rating, gets nil")
print("    Risk: JSON encode fails or nil reference")
print("    Severity: LOW\n")

print("\n▶ PROPOSAL KEY CONFLICTS\n")

print("[47] room_1_0 could conflict with game mode ID '0'")
print("    proposals[P1][P2][\"room_1_0\"] vs proposals[P1][P2][0]")
print("    Lua tables use both string and number keys")
print("    Risk: Proposal lookup fails or overwrites")
print("    Severity: MEDIUM\n")

print("[48] Slot number 0 collision")
print("    slotNumber or 0 creates key \"room_1_0\"")
print("    What if intentional slot 0 request? (should be 1-indexed)")
print("    Risk: Ambiguous semantics")
print("    Severity: LOW\n")

print("[49] Negative room numbers after restart")
print("    Server crashes with roomNumberIndex at INT_MAX")
print("    Restart with negative index, room IDs go negative")
print("    Risk: Proposal lookup with negative room fails")
print("    Severity: LOW\n")

print("\n▶ PROPOSAL LIFECYCLE RACES\n")

print("[50] Proposal expires during processing")
print("    P1 sends room invite. P2 accepts immediately.")
print("    Between checking proposal exists and processing it, TTL expires")
print("    Risk: Reference to expired proposal (if TTL implemented)")
print("    Severity: MEDIUM\n")

print("[51] Withdrawal during mutual acceptance handshake")
print("    P1 sends withdrawal, simultaneously P2 sends acceptance")
print("    Both messages in queue: [withdrawal, acceptance] or [acceptance, withdrawal]")
print("    Risk: Ambiguous final state")
print("    Severity: MEDIUM\n")

print("[52] Proposal modified after retrieved but before use")
print("    Get proposal: proposals[A][B][key] exists")
print("    Another thread sets proposals[A][B][key] = false")
print("    Use: finds false, not true")
print("    Risk: Logic error")
print("    Severity: MEDIUM\n")

print("\n▶ CLIENT-SERVER DIVERGENCE\n")

print("[53] Client sends join with stale slotNumber")
print("    Client cached slot 2 as open. Room state changed.")
print("    Client sends join room_1_2 but slot 2 no longer exists")
print("    Server rejects but client stuck thinking join pending")
print("    Risk: Player thinks they're joining but aren't")
print("    Severity: MEDIUM\n")

print("[54] lobbyStateV2 not delivered before join accepted")
print("    P2 joins. Server sends addToRoom but not updated lobbyStateV2")
print("    P3 still sees slot 2 as open in UI")
print("    Risk: P3 tries to join slot 2 (already taken)")
print("    Severity: MEDIUM\n")

print("[55] Challenge update arrives out of order with lobbyState")
print("    P2 sends: challenge update to P1")
print("    Server processes: challenge (stored), then lobbyState sent to all")
print("    P1 receives: lobbyState (shows slot request) THEN challenge details")
print("    Risk: UI gets slot request before invite details")
print("    Severity: LOW\n")

print("\n▶ DATA STRUCTURE EDGE CASES\n")

print("[56] Very long player name in proposal")
print("    Player name: 10,000 character Unicode string")
print("    Proposal table entry stores full name")
print("    JSON serialization of all proposals becomes huge")
print("    Risk: Network buffer overflow, slow serialization")
print("    Severity: LOW\n")

print("[57] Circular reference in proposal handling")
print("    proposals[A][B] = proposals[B][A] (intentional cycle)")
print("    JSON encode tries to recurse infinitely")
print("    Risk: Stack overflow, server crash")
print("    Severity: LOW (shouldn't happen naturally)\n")

print("[58] Table with metatable in proposals")
print("    Proposal somehow gets metatable attached")
print("    JSON encoder or Lua iteration behaves unexpectedly")
print("    Risk: Unpredictable behavior")
print("    Severity: LOW\n")

print("\n▶ TIMING & ORDERING\n")

print("[59] Two simultaneous mutual acceptances")
print("    P1↔P2 slot 2: P1 sends accept, P2 sends accept simultaneously")
print("    Server receives both. Processes both = 2 joins?")
print("    Risk: P1 and P2 both try to join")
print("    Severity: MEDIUM\n")

print("[60] Accept received before request stored")
print("    P1 sends challenge update (stores proposal)")
print("    P2 sends challenge update back (tries to accept)")
print("    Messages arrive: [accept, store] instead of [store, accept]")
print("    Risk: Accept fails because proposal not yet stored")
print("    Severity: MEDIUM\n")

print("[61] Three-way race: join, withdrawal, new request")
print("    P2 has proposal for slot 2")
print("    Simultaneously: [join accepted, withdrawal sent, new request]")
print("    Three messages in different orders")
print("    Risk: Undefined final state")
print("    Severity: MEDIUM\n")

print("\n▶ MALICIOUS INPUT\n")

print("[62] Extremely large slot number")
print("    Client sends slotNumber = 999999")
print("    Server creates key room_1_999999")
print("    Risk: Proposals table bloat, memory attack")
print("    Severity: MEDIUM\n")

print("[63] Negative or fractional slot number")
print("    Client sends slotNumber = -1 or 1.5")
print("    Server creates key room_1_-1 or room_1_1.5")
print("    Risk: Unexpected behavior, potential DOS")
print("    Severity: MEDIUM\n")

print("[64] Non-player public ID in acceptance")
print("    P2 sends 'I accept on behalf of P999'")
print("    Server tries to join non-existent P999")
print("    Risk: Nil dereference, crash")
print("    Severity: MEDIUM\n")

print("[65] Null/empty public ID")
print("    Proposal with public ID = \"\" or nil")
print("    Table lookup fails or matches everything")
print("    Risk: Wrong player affected")
print("    Severity: HIGH\n")

print("\n" .. string.rep("=", 80))
print("RISK ASSESSMENT - NEWLY DISCOVERED")
print(string.rep("=", 80) .. "\n")

print("🔴 CRITICAL (New):")
print("  #44: Player becomes nil between checks (crash)")
print("  #65: Empty public ID (state corruption)\n")

print("🟡 HIGH (New):")
print("  #41: Table iteration safety during clearProposals")
print("  #42: Room.players iteration during addPlayer")
print("  #47: Proposal key conflicts (room_1_0 vs 0)")
print("  #52: Proposal modified after retrieved")
print("  #59: Simultaneous mutual acceptances (double join)")
print("  #60: Accept before request stored (logic error)")
print("  #62: DOS via large slot numbers\n")

print("🟠 MEDIUM (New):")
print("  #43: Connection closed during join processing")
print("  #45: Room deleted between checks")
print("  #50: Proposal expires during processing")
print("  #51: Withdrawal during handshake")
print("  #53: Client uses stale slot number")
print("  #54: Missing lobbyStateV2 update")
print("  #61: Three-way race condition")
print("  #63: Negative/fractional slot number")
print("  #64: Non-existent player ID acceptance\n")

print("🟢 LOW (New):")
print("  #46, #48, #49, #55, #56, #57, #58\n")

print(string.rep("=", 80))
print("IMMEDIATE RISK FROM CURRENT CODE")
print(string.rep("=", 80) .. "\n")

print("⚠️  HIGH PROBABILITY (could happen in normal play):")
print("  • #41: clearProposals during lobbyStateV2 iteration (table corruption)")
print("    → REAL RISK: concurrent table modification\n")

print("  • #43: Connection closed while join in progress")
print("    → REAL RISK: could crash when trying to sendJson\n")

print("  • #59: Simultaneous mutual acceptances")
print("    → REAL RISK: race condition in handleJoinRoom\n")

print("⚠️  MEDIUM PROBABILITY (edge case but possible):")
print("  • #44: Player becomes nil")
print("    → REAL RISK: if disconnect happens between checks\n")

print("  • #60: Accept before request stored")
print("    → REAL RISK: network reordering (rare but TCP safe)\n")

print("⚠️  LOW PROBABILITY (requires malicious input):")
print("  • #62-65: DOS and injection attacks")
print("    → REAL RISK: if not validating input types\n")

print("\n" .. string.rep("=", 80))
print("MOST CRITICAL NEW DISCOVERIES")
print(string.rep("=", 80) .. "\n")

print("TOP 3 to fix next:\n")

print("1. 🔴 #44: Validate player exists before dereference")
print("   Where: handleJoinRoom(), processChallengeUpdate()")
print("   Fix: Re-check player.publicPlayerID exists in publicIdToPlayer before using\n")

print("2. 🔴 #41: Snapshot proposals table before iterating")
print("   Where: Server:lobbyStateV2()")
print("   Fix: Create shallow copy of proposals, iterate copy not original\n")

print("3. 🔴 #59: Lock mutual acceptances to prevent double-join")
print("   Where: Server:processChallengeUpdate() handshake section")
print("   Fix: Mark proposal as 'processing' to prevent concurrent joins\n")
