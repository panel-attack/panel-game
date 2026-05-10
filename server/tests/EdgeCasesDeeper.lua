-- Additional edge cases discovered through deeper analysis

print("\n" .. string.rep("=", 70))
print("ADDITIONAL EDGE CASES - DEEPER ANALYSIS")
print(string.rep("=", 70) .. "\n")

print("▶ WITHDRAWAL & STATE REVERSION\n")

print("[26] Withdraw after mutual acceptance but before join")
print("    P1 accepts P2, mutual acceptance triggered join.")
print("    P2 tries to withdraw simultaneously.")
print("    Risk: Join in progress, withdraw message arrives")
print("    Severity: MEDIUM\n")

print("[27] Proposal in both directions simultaneously")
print("    P1 requests slot 2, P2 also requests slot 2 (mutual)")
print("    P1 accepts P2, P2 accepts P1 (who joins?)")
print("    Risk: Ambiguous who joins")
print("    Severity: MEDIUM\n")

print("[28] Withdrawal of already-joined player's proposals")
print("    P1 joins room, then withdrawal message for P1 arrives")
print("    Should clear proposals but P1 is already joined")
print("    Risk: Stale state")
print("    Severity: LOW\n")

print("\n▶ STATE MACHINE VIOLATIONS\n")

print("[29] Player transitions lobby→character_select without room")
print("    P1 in lobby, hits 'Ready' before joining room")
print("    Can still try to join from character select state")
print("    Risk: Unclear if allowed (currently allowed)")
print("    Severity: LOW\n")

print("[30] Multiple rooms reference same player as owner")
print("    P1 creates room 1. Crash/restore. P1 creates room 2.")
print("    Both rooms think P1 is owner. Server crash if room 1 tries to access P1.")
print("    Risk: Undefined behavior")
print("    Severity: MEDIUM\n")

print("[31] Player leaves room but proposals linger")
print("    P2 joins room 1. Others still trying to accept/reject P2's proposals.")
print("    P2 is no longer listening (in character select).")
print("    Risk: Notifications to deaf player")
print("    Severity: LOW\n")

print("\n▶ DATABASE/PERSISTENCE EDGE CASES\n")

print("[32] Leaderboard rating lookup for non-existent player")
print("    Proposal references player who was deleted from leaderboard")
print("    Server tries to send lobbyStateV2 with rating for ghost player")
print("    Risk: Nil reference or missing key")
print("    Severity: LOW\n")

print("[33] Replays saved with wrong player indices")
print("    Out-of-order joins assigned wrong player_number")
print("    Replay played back assigns wrong teams")
print("    Risk: Replays show wrong outcome")
print("    Severity: HIGH (data integrity)\n")

print("[34] Settings desync in character select")
print("    P1 sets ready, P2 joins (P2 in character select)")
print("    P1's settings already sent, P2's not sent yet")
print("    Game starts with P2 not ready")
print("    Risk: Player not loaded")
print("    Severity: MEDIUM\n")

print("\n▶ TEAM LOGIC EDGE CASES\n")

print("[35] Team assignment with unbalanced joins")
print("    4-player game: P1+P2 vs P3+P4 (2v2)")
print("    Join order: P1, P3, P2, P4")
print("    player_numbers: [1, 2, 3, 4]")
print("    teams calculated when room full: correct (1+2 vs 3+4)")
print("    Risk: Actually OK due to teams calculated on full")
print("    Severity: LOW ✓\n")

print("[36] Team assignment for 1v2 with three joins")
print("    3-player: P1 solo vs P2+P3 team")
print("    Join order: P2, P1, P3 OR P1, P2, P3 (affects team calc)")
print("    Risk: team assignment depends on join order")
print("    Severity: HIGH (game logic)\n")

print("[37] Incomplete team in 4-player game")
print("    4-player: 2v2 expected. But 3 players joined, game never started.")
print("    P4 disconnects. Room stuck with 3 players.")
print("    Risk: Orphaned room consuming resources")
print("    Severity: MEDIUM\n")

print("\n▶ PROPOSAL LIFECYCLE EDGE CASES\n")

print("[38] Proposal for player in wrong state")
print("    P2 in character select, receives invite")
print("    P2 can't join from character select (state check)")
print("    But proposal stored. When does it clear?")
print("    Risk: Stale proposals pile up")
print("    Severity: MEDIUM\n")

print("[39] P2 leaves and rejoins, gets old proposal")
print("    P2 receives invite, leaves lobby, rejoins")
print("    New session, new public ID, but server still has old proposal")
print("    Risk: Old proposal becomes orphan")
print("    Severity: LOW\n")

print("[40] Proposal outlives room")
print("    Room 1 deleted (empty). Proposal for room 1 still exists.")
print("    P2 tries to join room 1. Server returns 'room not found'.")
print("    Proposal still stored (cleanup never runs)")
print("    Risk: Orphaned proposals accumulate")
print("    Severity: MEDIUM\n")

print("\n" .. string.rep("=", 70))
print("RISK ASSESSMENT")
print(string.rep("=", 70) .. "\n")

print("🔴 CRITICAL (Game Breaking):")
print("  #33: Replays saved with wrong player indices (data corruption)")
print("  #36: Team assignment for 1v2 depends on join order (unfair)\n")

print("🟡 HIGH (Affects Gameplay):")
print("  #30: Multiple rooms reference same player owner (crash risk)")
print("  #37: Incomplete team in 4-player game (orphaned rooms)\n")

print("🟠 MEDIUM (Data Integrity/User Experience):")
print("  #26: Withdraw during handshake (race condition)")
print("  #27: Simultaneous mutual proposals (ambiguous)")
print("  #32: Leaderboard rating lookup fails (crash risk)")
print("  #34: Settings desync in character select")
print("  #38: Proposal for player in wrong state (accumulates)")
print("  #40: Proposals outlive room (accumulates)\n")

print("🟢 LOW (Edge Case / Minor):")
print("  #28, #29, #31, #35, #39\n")

print("\n" .. string.rep("=", 70))
print("MOST IMPACTFUL NEXT FIX")
print(string.rep("=", 70) .. "\n")

print("ADD PROPOSAL CLEANUP TASK:")
print("  - Runs every 5 minutes")
print("  - Deletes proposals where:")
print("    • Room no longer exists")
print("    • Player no longer logged in")
print("    • Proposal older than 30 minutes")
print("  - This fixes #6, #24, #38, #40 at once\n")

print("ADD TEAM VALIDATION FOR 1v2 MODE:")
print("  - Don't calculate teams until room full")
print("  - When full, validate player_numbers map to correct teams")
print("  - This fixes #36\n")

print("REPLAY VALIDATION ON SAVE:")
print("  - Assert player_number == array index")
print("  - Catch any out-of-order join issues")
print("  - This prevents #33\n")
