# Multi-Player Design Spec (Team Modes)

## Overview

This document outlines the design for team-based multiplayer modes in Panel Attack.

**Architecture Goal:** Support **NvM teams** (scalable, not hardcoded to 2v2).

**Initial Modes:**
- **2v2 All** - 4 players, 2 teams, garbage hits all enemies
- **2v2 Shared** - 4 players, 2 teams, team garbage queue with round-robin distribution
- **1v2 All** - 3 players, solo vs team, garbage hits all enemies
- **1v2 Shared** - 3 players, solo vs team, team garbage queue with round-robin

**Future Possibilities (architecture should support):**
- 3v3, 4v4, etc.
- 2v2v2 (3+ teams)
- 1v1v1v1 (free-for-all with no teams)

---

## Data Model

### Team Structure

```lua
---@class Team
---@field id integer          -- Team index (1, 2, ...)
---@field playerIndices integer[]  -- Indices into match.stacks (e.g., {1, 2})

-- Example: 2v2
teams = {
  { id = 1, playerIndices = {1, 2} },  -- Team A
  { id = 2, playerIndices = {3, 4} },  -- Team B
}

-- Example: 1v2
teams = {
  { id = 1, playerIndices = {1} },     -- Solo
  { id = 2, playerIndices = {2, 3} },  -- Team
}

-- Example: 3v3
teams = {
  { id = 1, playerIndices = {1, 2, 3} },
  { id = 2, playerIndices = {4, 5, 6} },
}
```

### GameMode Extension

```lua
---@class GameMode
---@field playerCount integer       -- Total players (e.g., 4 for 2v2)
---@field teamCount integer         -- Number of teams (e.g., 2)
---@field playersPerTeam integer|integer[]  -- Uniform (2) or asymmetric ({1, 2})
---@field garbageMode GarbageMode   -- "all" or "shared"
```

---

## Game Rules

### Win Condition

- **Team wins** when all players on ALL opposing teams are eliminated
- Game does NOT end when one player dies - survivors continue fighting
- Scales to any number of teams/players

### When a Teammate Dies

The remaining players continue against all surviving enemies:

```
BEFORE:                      AFTER P1 DIES:
TEAM A        TEAM B         TEAM A        TEAM B
┌─────┐       ┌─────┐        ┌─────┐       ┌─────┐
│ P1  │       │ P3  │        │  X  │       │ P3  │
└─────┘       └─────┘        └─────┘       └─────┘

┌─────┐       ┌─────┐        ┌─────┐       ┌─────┐
│ P2  │       │ P4  │        │ P2  │◄─────►│ P4  │
└─────┘       └─────┘        └─────┘       └─────┘

                             P2 now fights both P3 and P4
```

### 1v2 Balance

- **No advantage** for the solo player
- Solo has standard health and garbage damage
- This is intended as a challenge mode

### Win Condition Logic (Scalable)

```lua
function isMatchOver(teams)
  local teamsAlive = 0

  for _, team in ipairs(teams) do
    if isTeamAlive(team) then
      teamsAlive = teamsAlive + 1
    end
  end

  -- Match ends when only 1 team remains (or 0 for draws)
  return teamsAlive <= 1
end

function isTeamAlive(team)
  for _, playerIndex in ipairs(team.playerIndices) do
    if isAlive(playerIndex) then
      return true  -- At least one player alive
    end
  end
  return false
end

function getWinningTeam(teams)
  for _, team in ipairs(teams) do
    if isTeamAlive(team) then
      return team
    end
  end
  return nil  -- Draw (all eliminated simultaneously)
end
```

---

## Garbage Distribution

### "All" Mode

Each player's combo sends garbage to **ALL living enemies** (any player not on their team):

```
TEAM A              TEAM B
┌─────┐             ┌─────┐
│ P1  │ ──────────► │ P3  │  (P1 combo hits BOTH P3 and P4)
│     │ ──┐         │     │
└─────┘   │         └─────┘
          │
          │         ┌─────┐
          └───────► │ P4  │
                    └─────┘
```

**Scalable logic (pseudocode):**
```lua
function getGarbageRecipients(senderIndex, teams)
  local senderTeam = getTeamForPlayer(senderIndex, teams)
  local recipients = {}

  for _, team in ipairs(teams) do
    if team.id ~= senderTeam.id then
      for _, playerIndex in ipairs(team.playerIndices) do
        if isAlive(playerIndex) then
          recipients[#recipients + 1] = playerIndex
        end
      end
    end
  end

  return recipients  -- All living enemies
end
```

### "Shared" Mode (Round-Robin)

Team garbage goes into a shared queue, distributed to one enemy at a time, alternating:

```
P1 combo #1 (5 garbage) ──► P3 gets all 5
P1 combo #2 (3 garbage) ──► P4 gets all 3
P2 combo #1 (4 garbage) ──► P3 gets all 4
P2 combo #2 (2 garbage) ──► P4 gets all 2
```

- Full combo goes to ONE enemy (no splitting)
- Target alternates each combo (round-robin through all living enemies)
- Creates spiky pressure on individuals rather than constant low pressure on all

**Scalable logic (pseudocode):**
```lua
---@class TeamGarbageState
---@field targetIndex integer  -- Current position in round-robin (per team)

-- Each team tracks its own round-robin position
teamGarbageState = {
  [1] = { targetIndex = 0 },  -- Team 1's targeting state
  [2] = { targetIndex = 0 },  -- Team 2's targeting state
}

function getNextTarget(senderTeamId, teams)
  local state = teamGarbageState[senderTeamId]
  local enemies = getLivingEnemies(senderTeamId, teams)

  if #enemies == 0 then return nil end

  -- Round-robin through enemies
  state.targetIndex = (state.targetIndex % #enemies) + 1
  return enemies[state.targetIndex]
end

function getLivingEnemies(teamId, teams)
  local enemies = {}
  for _, team in ipairs(teams) do
    if team.id ~= teamId then
      for _, playerIndex in ipairs(team.playerIndices) do
        if isAlive(playerIndex) then
          enemies[#enemies + 1] = playerIndex
        end
      end
    end
  end
  return enemies
end
```

---

## Matchmaking Flow

### Two-Step Process

1. **Invite Teammate** - Player invites another player to form a team
2. **Challenge** - Team challenges another team (or solo player for 1v2)

```
┌─────────────────────┐     ┌─────────────────────┐
│  You invite P2      │     │  Your team (You+P2) │
│  P2 accepts         │ ──► │  challenges P3+P4   │
│  Now you're a team  │     │  They accept        │
└─────────────────────┘     └─────────────────────┘
                                      │
                                      ▼
                                 Match starts
```

### 1v2 Matchmaking

- Team of 2 challenges a solo player, OR
- Solo player challenges a team of 2

---

## UI Layout

### Core Principle

**Local player is ALWAYS full size on the left side** - same as current 1v1.

Other players (teammates and enemies) are displayed smaller on the right.

### 2v2 View (from P1's perspective)

```
┌─────────────────────────────────────────────────────┐
│                                    ┌─────┐ P2 (teammate)
│   ┌───────────────┐                └─────┘
│   │               │                ┌─────┐ P3 (enemy)
│   │  YOU (P1)     │                └─────┘
│   │  FULL SIZE    │                ┌─────┐ P4 (enemy)
│   │               │                └─────┘
│   └───────────────┘
└─────────────────────────────────────────────────────┘
```

### 1v2 View (from Solo's perspective)

```
┌─────────────────────────────────────────────────────┐
│                                    ┌─────┐ P2 (enemy)
│   ┌───────────────┐                └─────┘
│   │               │
│   │  YOU (SOLO)   │                ┌─────┐ P3 (enemy)
│   │  FULL SIZE    │                └─────┘
│   │               │
│   └───────────────┘
└─────────────────────────────────────────────────────┘
```

### 1v2 View (from Team member's perspective)

```
┌─────────────────────────────────────────────────────┐
│                                    ┌─────┐ P1 (enemy/solo)
│   ┌───────────────┐                └─────┘
│   │               │
│   │  YOU (P2)     │                ┌─────┐ P3 (teammate)
│   │  FULL SIZE    │                └─────┘
│   │               │
│   └───────────────┘
└─────────────────────────────────────────────────────┘
```

### Visual Team Indicators

- **Border color**: Team A = Blue, Team B = Red
- **Team labels**: "TEAM A" / "TEAM B" headers
- **Defeated state**: Dead player's stack fades out, shows "DEFEATED"

---

## UI Mockups

Interactive HTML mockups available at:

📄 **[docs/ui-mockup.html](ui-mockup.html)**

Open in browser to view:
- Current 1v1 layout (reference)
- 2v2 layouts
- 1v2 layout
- After-death state

---

## Summary Table

### Initial Modes

| Mode | Players | Garbage | Win Condition | Solo Advantage |
|------|---------|---------|---------------|----------------|
| 2v2 All | 4 (2v2) | All enemies | Last team | N/A |
| 2v2 Shared | 4 (2v2) | Round-robin | Last team | N/A |
| 1v2 All | 3 (1v2) | All enemies | Last team/player | None |
| 1v2 Shared | 3 (1v2) | Round-robin | Last team/player | None |

### Scalable Architecture

| Aspect | Design |
|--------|--------|
| **Teams** | Array of Team objects, each with `playerIndices[]` |
| **Team sizes** | Variable - supports 1, 2, 3, ... N players per team |
| **Team count** | Variable - supports 2, 3, ... N teams |
| **Win condition** | Last team with any living player wins |
| **Garbage targeting** | Iterates all enemy teams/players dynamically |

---

## Implementation Notes

### Key Files to Modify

| File | Changes |
|------|---------|
| `/common/data/GameModes.lua` | Add `teamCount`, `playersPerTeam`, `garbageMode` fields |
| `/common/data/MatchRules.lua` | Add `TEAMS_ACTIVE` match end condition |
| `/common/engine/Match.lua` | Add `teams` field, scalable win condition logic |
| `/server/Room.lua` | Team assignment, track teams array |
| `/server/Game.lua` | Garbage flow setup using teams |
| `/common/network/NetworkProtocol.lua` | Additional input prefixes for 3+ players |
| `/client/src/ClientMatch.lua` | Scalable layout for N players |

### Network Protocol

For N players, need N input message types. Current:
- `I` = Player 1 input
- `U` = Player 2 input

Extend with:
- `V` = Player 3 input
- `W` = Player 4 input
- (Continue as needed for larger matches)

---

## Test Plan (TDD)

Tests are written FIRST, before implementation. Run with `love ./testLauncher.lua [TestName]`.

### 1. Unit Tests: `common/tests/TeamUtilsTests.lua`

Test the core team utility functions:

```
testCreateTeams_2v2()
  - Create teams for 4 players, 2 teams of 2
  - Assert: teams[1].playerIndices = {1, 2}
  - Assert: teams[2].playerIndices = {3, 4}

testCreateTeams_1v2()
  - Create teams for 3 players, asymmetric {1, 2}
  - Assert: teams[1].playerIndices = {1}
  - Assert: teams[2].playerIndices = {2, 3}

testGetTeamForPlayer()
  - Given teams, find which team a player belongs to
  - Assert: getTeamForPlayer(1, teams) == teams[1]
  - Assert: getTeamForPlayer(3, teams) == teams[2]

testIsTeamAlive_allAlive()
  - Team with all players alive
  - Assert: isTeamAlive(team) == true

testIsTeamAlive_someAlive()
  - Team with 1 of 2 players alive
  - Assert: isTeamAlive(team) == true

testIsTeamAlive_nonAlive()
  - Team with no players alive
  - Assert: isTeamAlive(team) == false

testGetLivingEnemies()
  - Given teams and dead players, get living enemies
  - Assert: returns only living players from other teams

testGetLivingEnemies_afterDeath()
  - After one enemy dies, list updates
  - Assert: dead player not in list
```

### 2. Integration Tests: `common/tests/engine/TeamMatchTests.lua`

Test Match class with team-based win conditions:

```
testMatchEnds_whenOneTeamEliminated_2v2()
  - Create 2v2 match with teams
  - Eliminate both players on Team B
  - Assert: match:hasEnded() == true
  - Assert: match:getWinningTeam() == Team A

testMatchContinues_whenOnePlayerDies_2v2()
  - Create 2v2 match
  - Eliminate P1 (Team A)
  - Assert: match:hasEnded() == false (P2 still alive)

testMatchEnds_whenSoloEliminated_1v2()
  - Create 1v2 match (solo vs team)
  - Eliminate solo player
  - Assert: match:hasEnded() == true
  - Assert: match:getWinningTeam() == Team (not solo)

testMatchEnds_whenTeamEliminated_1v2()
  - Create 1v2 match
  - Eliminate both team players
  - Assert: match:hasEnded() == true
  - Assert: match:getWinningTeam() == Solo
```

### 3. Integration Tests: `common/tests/engine/TeamGarbageTests.lua`

Test garbage distribution in team modes:

```
testGarbageAllMode_hitsAllEnemies()
  - Create 2v2 match with "All" garbage mode
  - P1 sends garbage
  - Assert: P3 receives garbage
  - Assert: P4 receives garbage
  - Assert: P2 (teammate) does NOT receive garbage

testGarbageAllMode_skipsDeadEnemies()
  - P3 is dead
  - P1 sends garbage
  - Assert: only P4 receives garbage

testGarbageSharedMode_roundRobin()
  - Create 2v2 match with "Shared" garbage mode
  - P1 sends combo #1
  - Assert: P3 receives (first in round-robin)
  - P1 sends combo #2
  - Assert: P4 receives (next in round-robin)
  - P2 sends combo #1
  - Assert: P3 receives (continues round-robin)

testGarbageSharedMode_skipsDeadInRotation()
  - P3 dies
  - Next combo should go to P4
  - Assert: round-robin continues with living enemies only

testGarbageSharedMode_fullComboToOneTarget()
  - Send 5-block combo
  - Assert: all 5 blocks go to ONE enemy (not split)
```

### 4. E2E Tests: `server/tests/TeamRoomTests.lua`

Test full room lifecycle with 3-4 players:

```
test2v2Room_basicFlow()
  - Create room with 4 players, 2v2 mode
  - All players ready up
  - Assert: match starts
  - Simulate inputs from all 4 players
  - P3 and P4 report loss (Team B eliminated)
  - P1 and P2 report win
  - Assert: Team A wins
  - Assert: win counts updated correctly

test2v2Room_partialElimination()
  - Create 2v2 room, start match
  - P1 dies (reports loss)
  - Assert: match continues (P2 still alive)
  - P2 dies (reports loss)
  - Assert: match ends, Team B wins

test1v2Room_soloWins()
  - Create 1v2 room (solo vs team)
  - Solo eliminates both team members
  - Assert: solo wins

test1v2Room_teamWins()
  - Create 1v2 room
  - Team eliminates solo
  - Assert: team wins

testRoom_inputBroadcast_4players()
  - P1 sends input
  - Assert: P2, P3, P4 all receive P1's input
  - Assert: correct message prefix used (I, U, V, W)

testRoom_teamAssignment()
  - Create room with 4 players for 2v2
  - Assert: room.teams[1] = {P1, P2}
  - Assert: room.teams[2] = {P3, P4}
```

### 5. GameMode Tests: `common/tests/data/TeamGameModeTests.lua`

Test new game mode configurations:

```
testGameMode_2v2All_properties()
  - Load 2v2 All preset
  - Assert: playerCount == 4
  - Assert: teamCount == 2
  - Assert: playersPerTeam == 2
  - Assert: garbageMode == "all"

testGameMode_2v2Shared_properties()
  - Load 2v2 Shared preset
  - Assert: garbageMode == "shared"

testGameMode_1v2_asymmetricTeams()
  - Load 1v2 preset
  - Assert: playerCount == 3
  - Assert: playersPerTeam == {1, 2}
```

### Test Execution Order

1. `TeamUtilsTests.lua` - Unit tests (no dependencies)
2. `TeamGameModeTests.lua` - GameMode config tests
3. `TeamMatchTests.lua` - Match integration tests
4. `TeamGarbageTests.lua` - Garbage integration tests
5. `TeamRoomTests.lua` - E2E server tests

All tests will FAIL initially (TDD red phase). Then implement to make them pass (green phase).
