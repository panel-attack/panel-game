-- Test case for multi-slot invite bug:
-- P1 creates room with 2 slots
-- P2 requests slot 1
-- P3 requests slot 2
-- P1 accepts P2 → P2 should join slot 1
-- P3's pending slot 2 request should still exist

-- Direct unit test of clearProposals logic
local function testClearProposalsLogic()
  print("\n=== Direct Test: clearProposals Logic ===")
  print("Scenario: P1 creates 4-player room, P2 joins slot 2, P3 joins slot 3")
  print("Expected: P3's proposal should survive after P2 joins\n")
  
  -- Simulate the proposals data structure
  -- Realistic scenario: P1 creates room, is in slot 1
  -- P2 requests slot 2, P3 requests slot 3
  local proposals = {
    P2 = {
      P1 = {
        room_1_2 = true,  -- P2 requested slot 2 from P1
      }
    },
    P3 = {
      P1 = {
        room_1_3 = true,  -- P3 requested slot 3 from P1
      }
    }
  }
  
  print("\nInitial proposals:")
  for sender, receivers in pairs(proposals) do
    for receiver, keys in pairs(receivers) do
      for key in pairs(keys) do
        print(string.format("  [%s] → [%s]: %s", sender, receiver, key))
      end
    end
  end
  
  -- Simulate clearProposals(P2)
  local function clearProposals(player)
    proposals[player] = {}
    for _, challenges in pairs(proposals) do
      if challenges[player] then
        challenges[player] = nil
      end
    end
  end
  
  print("\n→ Calling clearProposals(P2) to simulate P2 joining...")
  clearProposals("P2")
  
  print("\nProposals after clearProposals(P2):")
  for sender, receivers in pairs(proposals) do
    for receiver, keys in pairs(receivers) do
      for key in pairs(keys) do
        print(string.format("  [%s] → [%s]: %s", sender, receiver, key))
      end
    end
  end
  
  -- Check if P3's proposal is still there
  local p3_to_p1_preserved = proposals.P3 and proposals.P3.P1 and proposals.P3.P1.room_1_3
  
  if p3_to_p1_preserved then
    print("\n✓ P3's slot 2 request correctly preserved!")
    return true
  else
    print("\n✗ BUG: P3's slot 2 request was cleared!")
    return false
  end
end

return testClearProposalsLogic()
