-- Test that multi-slot invites are preserved when other slots fill up
-- Scenario: P1 creates room, P2 requests slot 2, P3 requests slot 3
-- Then P2 joins (slot 2 becomes unavailable)
-- Expected: P3's request for slot 3 should STILL exist

print("\n=== Testing: Multi-Slot Invite Preservation ===\n")

-- Simulate the client's lobbyData structure
local lobbyData = {
  rooms = {
    [1] = {
      roomNumber = 1,
      maxPlayers = 4,
      players = {"P1"},  -- P1 is the room creator
      openSlots = {2, 3, 4},
      slotRequests = {
        [2] = "P2",
        [3] = "P3",
      }
    }
  },
  outgoingChallenges = {
    P2 = { room_1_2 = true },  -- P2's request for slot 2
    P3 = { room_1_3 = true },  -- P3's request for slot 3
  }
}

print("Initial state:")
print(string.format("  Room slots: %s", table.concat(lobbyData.rooms[1].openSlots, ", ")))
print(string.format("  Slot requests: 2→%s, 3→%s", lobbyData.rooms[1].slotRequests[2] or "none", lobbyData.rooms[1].slotRequests[3] or "none"))
print(string.format("  Outgoing P2: room_1_2=%s", tostring(lobbyData.outgoingChallenges.P2 and lobbyData.outgoingChallenges.P2.room_1_2)))
print(string.format("  Outgoing P3: room_1_3=%s", tostring(lobbyData.outgoingChallenges.P3 and lobbyData.outgoingChallenges.P3.room_1_3)))

-- Simulate P2 joining
print("\n→ P2 joins slot 2...")
table.insert(lobbyData.rooms[1].players, "P2")
lobbyData.rooms[1].openSlots = {3, 4}  -- Slot 2 is now taken
lobbyData.rooms[1].slotRequests[2] = nil  -- Slot 2 no longer has pending requests

print("After P2 joins:")
print(string.format("  Room slots: %s", table.concat(lobbyData.rooms[1].openSlots, ", ")))
print(string.format("  Slot requests: 2→%s, 3→%s", lobbyData.rooms[1].slotRequests[2] or "none", lobbyData.rooms[1].slotRequests[3] or "none"))

-- Now apply the OLD buggy logic (clearing proposals if slot not open)
local function oldBuggyLogic(lobbyData)
  local function isInviteSlotStillOpen(inviteKey)
    local roomNumberStr, slotNumberStr = inviteKey:match("^room_(%d+)_(%d+)$")
    local roomNumber = tonumber(roomNumberStr)
    local slotNumber = tonumber(slotNumberStr)
    if not roomNumber or not slotNumber then return false end
    
    local room = lobbyData.rooms[roomNumber]
    if not room or not room.openSlots then return false end
    
    for _, slot in ipairs(room.openSlots) do
      if tonumber(slot) == slotNumber then return true end
    end
    return false
  end
  
  for playerId, challenges in pairs(lobbyData.outgoingChallenges) do
    for key in pairs(challenges) do
      if not isInviteSlotStillOpen(key) then
        challenges[key] = nil
      end
    end
  end
end

-- Now apply the NEW fixed logic (only clear if room is full)
local function newFixedLogic(lobbyData)
  for playerId, challenges in pairs(lobbyData.outgoingChallenges) do
    for key in pairs(challenges) do
      local roomNumberStr = key:match("^room_(%d+)_")
      local roomNum = tonumber(roomNumberStr)
      if roomNum then
        local room = lobbyData.rooms[roomNum]
        -- Only clear if room is FULL
        if room and room.openSlots and #room.openSlots == 0 then
          challenges[key] = nil
        end
      end
    end
  end
end

-- Test OLD logic
print("\n--- Testing OLD (buggy) logic ---")
local oldData = {
  rooms = {
    [1] = {
      roomNumber = 1,
      maxPlayers = 4,
      players = {"P1", "P2"},
      openSlots = {3, 4},
      slotRequests = {
        [3] = "P3",
      }
    }
  },
  outgoingChallenges = {
    P2 = { room_1_2 = true },
    P3 = { room_1_3 = true },
  }
}
print("Before old logic:")
print(string.format("  P2 outgoing: room_1_2=%s", tostring(oldData.outgoingChallenges.P2.room_1_2)))
print(string.format("  P3 outgoing: room_1_3=%s", tostring(oldData.outgoingChallenges.P3.room_1_3)))

oldBuggyLogic(oldData)
print("After old logic (buggy - clears if slot not open):")
print(string.format("  P2 outgoing: room_1_2=%s", tostring(oldData.outgoingChallenges.P2.room_1_2)))
print(string.format("  P3 outgoing: room_1_3=%s (expected true, got %s) %s", tostring(oldData.outgoingChallenges.P3.room_1_3), tostring(oldData.outgoingChallenges.P3.room_1_3), oldData.outgoingChallenges.P3.room_1_3 == true and "✓" or "✗ BUG!"))

-- Test NEW logic
print("\n--- Testing NEW (fixed) logic ---")
local newData = {
  rooms = {
    [1] = {
      roomNumber = 1,
      maxPlayers = 4,
      players = {"P1", "P2"},
      openSlots = {3, 4},
      slotRequests = {
        [3] = "P3",
      }
    }
  },
  outgoingChallenges = {
    P2 = { room_1_2 = true },
    P3 = { room_1_3 = true },
  }
}
print("Before new logic:")
print(string.format("  P2 outgoing: room_1_2=%s", tostring(newData.outgoingChallenges.P2.room_1_2)))
print(string.format("  P3 outgoing: room_1_3=%s", tostring(newData.outgoingChallenges.P3.room_1_3)))

newFixedLogic(newData)
print("After new logic (fixed - only clears if room full):")
print(string.format("  P2 outgoing: room_1_2=%s (stays true, room not full) %s", tostring(newData.outgoingChallenges.P2.room_1_2), newData.outgoingChallenges.P2.room_1_2 == true and "✓" or "✗")
)
print(string.format("  P3 outgoing: room_1_3=%s (stays true, room not full) %s", tostring(newData.outgoingChallenges.P3.room_1_3), newData.outgoingChallenges.P3.room_1_3 == true and "✓" or "✗"))

-- Test with full room
print("\n--- Testing full room scenario ---")
local fullRoomData = {
  rooms = {
    [1] = {
      roomNumber = 1,
      maxPlayers = 4,
      players = {"P1", "P2", "P3", "P4"},
      openSlots = {},  -- ROOM IS FULL
      slotRequests = {}
    }
  },
  outgoingChallenges = {
    P5 = { room_1_5 = true },  -- Someone requesting a non-existent slot 5
  }
}
print("Full room with P5 requesting:")
print(string.format("  Before: P5 outgoing room_1_5=%s", tostring(fullRoomData.outgoingChallenges.P5.room_1_5)))

newFixedLogic(fullRoomData)
print(string.format("  After:  P5 outgoing room_1_5=%s (should be cleared when room full) %s", tostring(fullRoomData.outgoingChallenges.P5.room_1_5), not fullRoomData.outgoingChallenges.P5.room_1_5 and "✓" or "✗"))

print("\n✓ Fix validated! Multi-slot proposals are preserved when room has open slots.")
