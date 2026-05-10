-- Edge case: Out-of-order slot joining

print("\n=== CRITICAL BUG: Out-of-Order Slot Joining ===\n")

print("Scenario:")
print("  P1 creates 4-player room (index 1)")
print("  P2 requests slot 2")  
print("  P3 requests slot 3")
print("  P4 requests slot 4")
print()

-- Simulate room state
local room = {
  players = {"P1"},
  openSlots_initial = {2, 3, 4}
}

print("Correct order (if accepted in sequence):")
print("  1. P2 joins slot 2:")
print("     - Validate: slot 2 in [2,3,4]? YES ✓")
print("     - Actual join: #players+1 = 2 ✓")
print("     - Room: [P1, P2, ?, ?]")
print()
print("  2. P3 joins slot 3:")
print("     - Validate: slot 3 in [3,4]? YES ✓")
print("     - Actual join: #players+1 = 3 ✓")
print("     - Room: [P1, P2, P3, ?]")
print()
print("  3. P4 joins slot 4:")
print("     - Validate: slot 4 in [4]? YES ✓")
print("     - Actual join: #players+1 = 4 ✓")
print("     - Room: [P1, P2, P3, P4] ✓ CORRECT")
print()

print("\n⚠️  WRONG ORDER (due to network timing):")
print()
print("  1. P3 tries to join slot 3 (before P2):")
print("     - Validate: slot 3 in [2,3,4]? YES ✓")
print("     - Actual join: #players+1 = 2 ❌")
print("     - Room: [P1, P3, ?, ?]")
print("     - P3 is in slot 2, not slot 3!")
print()
print("  2. P2 tries to join slot 2:")
print("     - Validate: slot 2 in [3,4]? NO ❌")
print("     - Join REJECTED!")
print("     - Room: [P1, P3, ?, ?]")
print()
print("  3. Result: P2 never joins, room has wrong player in wrong slot")
print()

print("=== Root Cause ===")
print("The code validates the REQUESTED slot is available,")
print("but then IGNORES the slot number and assigns #players+1")
print()
print("This works only if joins happen in slot order!")
print()
print("Fix: Either")
print("  A) Ignore slot number in validation (don't validate specific slot), OR")
print("  B) Respect the requested slot (insert into specific position)")
