-- TeamUtils.lua
-- Utility functions for team management in multi-player modes

local TeamUtils = {}

-- Canonical team-color palette. Single source of truth — every banner / chip /
-- border consumer references this. Alpha is 1; consumers that want
-- translucency build {r,g,b,alpha} themselves at draw time.
TeamUtils.TEAM_COLORS = {
  {1,    0.55, 0.75, 1}, -- pink   (team 1)
  {0.65, 0.4,  0.95, 1}, -- purple (team 2)
  {0.45, 1,    0.45, 1}, -- green
  {1,    1,    0.45, 1}, -- yellow
  {1,    0.6,  0.2,  1}, -- orange
  {0.45, 0.7,  1,    1}, -- blue
  {0.45, 1,    1,    1}, -- cyan
  {1,    0.45, 0.45, 1}, -- red
}

local GameModes_StackInteractions
local function getStackInteractions()
  if not GameModes_StackInteractions then
    GameModes_StackInteractions = require("common.data.GameModes").StackInteractions
  end
  return GameModes_StackInteractions
end

-- "Shared team mode" = TEAM_VERSUS with at least one team containing multiple
-- players. FFA is technically TEAM_VERSUS but every team is size 1.
function TeamUtils.isSharedTeamMode(gameMode)
  if not gameMode or gameMode.stackInteraction ~= getStackInteractions().TEAM_VERSUS then
    return false
  end
  local p = gameMode.playersPerTeam
  if type(p) == "number" then return p > 1 end
  if type(p) == "table" then
    for _, n in ipairs(p) do
      if n > 1 then return true end
    end
  end
  return false
end

function TeamUtils.isFFA(gameMode)
  if not gameMode or gameMode.stackInteraction ~= getStackInteractions().TEAM_VERSUS then
    return false
  end
  return not TeamUtils.isSharedTeamMode(gameMode)
end

-- Letter label for a team (1 -> "A", 2 -> "B", ...).
function TeamUtils.teamLetter(teamIndex)
  return string.char(string.byte("A") + (teamIndex - 1))
end

-- Slot (player_number) for a player, falling back to the dense-array index when
-- the player is mid-construction or otherwise missing the slot field.
function TeamUtils.slotOf(player, fallbackIndex)
  return (player and player.playerNumber) or fallbackIndex
end

---@class Team
---@field playerIndices integer[] Array of player indices (1-based) belonging to this team
---@field id integer The team's id (1-based)
---@field teamIndex integer Alias for id, for compatibility

-- Creates teams based on player count and team configuration
-- Supports both symmetric teams (all teams same size) and asymmetric (e.g., 1v2)
---@param playerCount integer Total number of players
---@param teamCount integer Number of teams
---@param playersPerTeam integer|integer[] Players per team (single number for symmetric, array for asymmetric)
---@return Team[] teams Array of team objects
function TeamUtils.createTeams(playerCount, teamCount, playersPerTeam)
  local teams = {}
  local playerIndex = 1

  for teamId = 1, teamCount do
    local teamSize
    if type(playersPerTeam) == "table" then
      -- Asymmetric teams (e.g., {1, 2} for 1v2)
      teamSize = playersPerTeam[teamId]
    else
      -- Symmetric teams (e.g., 2 for 2v2)
      teamSize = playersPerTeam
    end

    local team = {
      playerIndices = {},
      id = teamId,
      teamIndex = teamId  -- Alias for compatibility
    }

    for i = 1, teamSize do
      table.insert(team.playerIndices, playerIndex)
      playerIndex = playerIndex + 1
    end

    teams[teamId] = team
  end

  return teams
end

-- Build teams from a sparse list of actually-filled slot numbers. Each slot is
-- mapped to its team using the same boundaries createTeams would for a full
-- roster (slots 1..N → team 1, slots N+1..2N → team 2, etc. for symmetric
-- modes; or asymmetric ranges from a playersPerTeam table). Empty slots
-- simply don't contribute to any team.
--
-- Lets Open Team rooms start with a partial roster (e.g. 2v2 with one player
-- per team, where players sit at slots {1, 3} and slots {2, 4} are still
-- open). The default createTeams would assign indices [1,2] and [3,4]
-- regardless of fill, producing teams that point to non-existent players.
---@param filledSlots integer[] slot numbers that have a player (in any order)
---@param teamCount integer expected number of teams from the gameMode
---@param playersPerTeam integer|integer[] from the gameMode
---@return Team[] teams (some may have empty playerIndices)
function TeamUtils.createTeamsFromFilledSlots(filledSlots, teamCount, playersPerTeam)
  local teams = {}
  for teamId = 1, teamCount do
    teams[teamId] = { playerIndices = {}, id = teamId, teamIndex = teamId }
  end

  local function teamForSlot(slot)
    if type(playersPerTeam) == "number" and playersPerTeam > 0 then
      return math.floor((slot - 1) / playersPerTeam) + 1
    elseif type(playersPerTeam) == "table" then
      local acc = 0
      for idx, count in ipairs(playersPerTeam) do
        acc = acc + (tonumber(count) or 0)
        if slot <= acc then return idx end
      end
    end
    return nil
  end

  -- Sort so the resulting playerIndices are slot-ordered — keeps replay and
  -- downstream "first-on-team" lookups deterministic across runs.
  local sorted = {}
  for _, s in ipairs(filledSlots) do sorted[#sorted + 1] = s end
  table.sort(sorted)

  for _, slot in ipairs(sorted) do
    local teamId = teamForSlot(slot)
    if teamId and teams[teamId] then
      table.insert(teams[teamId].playerIndices, slot)
    end
  end
  return teams
end

-- Count teams that have at least one filled slot. Used to gate match start in
-- Open Team rooms — we won't start until every team has a body.
---@param teams Team[]
---@return integer
function TeamUtils.countTeamsWithMembers(teams)
  local count = 0
  for _, team in ipairs(teams) do
    if team.playerIndices and #team.playerIndices > 0 then
      count = count + 1
    end
  end
  return count
end

-- Returns the team that a player belongs to
---@param playerIndex integer The player's index (1-based)
---@param teams Team[] Array of teams
---@return Team|nil team The team the player belongs to, or nil if not found
function TeamUtils.getTeamForPlayer(playerIndex, teams)
  for _, team in ipairs(teams) do
    for _, idx in ipairs(team.playerIndices) do
      if idx == playerIndex then
        return team
      end
    end
  end
  return nil
end

-- Alias for getTeamForPlayer with swapped argument order (for backwards compatibility)
---@param teams Team[] Array of teams
---@param playerIndex integer The player's index (1-based)
---@return Team|nil team The team the player belongs to, or nil if not found
function TeamUtils.getPlayerTeam(teams, playerIndex)
  return TeamUtils.getTeamForPlayer(playerIndex, teams)
end

-- Pure-derivation team lookup from gameMode shape + position. Use this
-- when room.teams is not handy (waiting room, end-of-match screens,
-- ready-state gating). Returns position itself in FFA so callers can
-- treat "team index" as "player index" uniformly.
---@param gameMode table? must carry playersPerTeam (number for symmetric, table for asymmetric)
---@param playerPosition integer slot or dense stack index, depending on context
---@return integer teamIndex
function TeamUtils.getTeamIndexForPlayerPosition(gameMode, playerPosition)
  local ppt = gameMode and gameMode.playersPerTeam
  if not ppt then return playerPosition end
  if type(ppt) == "number" then
    if ppt <= 0 then return playerPosition end
    return math.floor((playerPosition - 1) / ppt) + 1
  end
  local cum = 0
  for idx, count in ipairs(ppt) do
    cum = cum + (tonumber(count) or 0)
    if playerPosition <= cum then return idx end
  end
  return playerPosition
end

-- Canonical client-side team lookup. THE one place to fix if team rendering
-- breaks. Accepts whatever you have on hand: a Match, a BattleRoom, a raw
-- gameMode, or nil. Internally prefers engine.teams (per-match authoritative
-- shape) and falls back to gameMode-derived from playersPerTeam.
---@param context table? Match, BattleRoom, or gameMode; nil treated as FFA
---@param position integer slot or stack index
---@return integer teamIndex
function TeamUtils.teamIndexFor(context, position)
  if not context then return position end
  local teams = context.engine and context.engine.teams
  if teams then
    local idx = TeamUtils.getPlayerTeamIndex(teams, position)
    if idx then return idx end
    -- engine.teams is stackIndex-keyed; if callers pass seatId (the canonical
    -- client-side position) it misses for sparse rooms — fall through to the
    -- gameMode preset derivation rather than returning position as-is.
  end
  local gameMode = context.gameMode or context.mode or context
  return TeamUtils.getTeamIndexForPlayerPosition(gameMode, position)
end

-- Same as teamIndexFor but returns nil when the context isn't a team game.
-- Callers that build team-keyed tables ("if teamIndex then ...") need to skip
-- non-team contexts rather than treating each player as their own team.
function TeamUtils.teamIndexForOrNil(context, position)
  if not context then return nil end
  local gameMode = (context.engine and context.gameMode) or context.gameMode or context.mode or context
  if not (gameMode and gameMode.playersPerTeam) then return nil end
  return TeamUtils.teamIndexFor(context, position)
end

-- Canonical "what team is this player on?" for UI rendering.
--
-- THE single client-side entry point — banner header, per-stack color, team
-- scoreboard, end-of-match labels, and lobby tile color all call this.
-- Returns nil ONLY for non-team modes (FFA, vs-self, etc.). In a team mode
-- a missing player.playerNumber is a caller bug and errors immediately —
-- no silent positional fallback. A fallback would produce the wrong team in
-- sparse-seat rooms, which is exactly the bug the refactor exists to fix.
-- Funnel seat writes through TeamUtils.assignSeatIdentity to satisfy this.
---@param context Match|BattleRoom|table|nil  Match, BattleRoom, or raw gameMode
---@param player table?                       must have .playerNumber set in team modes
---@return integer? teamIndex                 nil only when context isn't a team mode
function TeamUtils.teamIndexForPlayer(context, player)
  if not (context and player) then return nil end
  local gameMode = (context.engine and context.gameMode) or context.gameMode or context.mode or context
  if not (gameMode and gameMode.playersPerTeam) then return nil end
  if not player.playerNumber then
    error("TeamUtils.teamIndexForPlayer: player.playerNumber missing in a team mode — caller did not assignSeatIdentity")
  end
  return TeamUtils.teamIndexFor(context, player.playerNumber)
end

-- Convenience: team color for a player, with optional alpha. Returns nil
-- when the team can't be resolved (non-team mode); callers fall back to
-- their own neutral color (e.g. ClientStack.DEFAULT_TEAM_COLOR).
---@return number[]? {r,g,b,a}
function TeamUtils.teamColorForPlayer(context, player, alpha)
  local idx = TeamUtils.teamIndexForPlayer(context, player)
  if not idx then return nil end
  local c = TeamUtils.TEAM_COLORS[idx] or TeamUtils.TEAM_COLORS[1]
  return { c[1], c[2], c[3], alpha or c[4] or 1 }
end

-- Canonical "this player sits at this seat" setter. The only place that
-- writes player.seatId / playerNumber / player_number. Server uses snake_case,
-- client uses camelCase; this helper writes both so the legacy aliases stay
-- in sync with the canonical seatId field, regardless of which side calls it.
-- Every code path that learns a player's seat (addToRoom, playerJoinedRoom,
-- replay metadata, rejoin-into-new-seat, server constructor / addPlayer)
-- should funnel through here so the fields cannot drift apart.
---@param player table?
---@param seatId integer?
function TeamUtils.assignSeatIdentity(player, seatId)
  if not player or not seatId then return end
  player.seatId = seatId
  player.playerNumber = seatId
  player.player_number = seatId
end

-- Build a teamIndex -> {players} map from a roster. Replaces ad-hoc loops in
-- TeamBannerHeader / PortraitGame / GameBase / ClientMatch that each iterated
-- players and called the team-index helper themselves — every divergence in
-- those copies is a chance for a new drift bug. Use this instead.
---@param context Match|BattleRoom|table|nil
---@param players table[]  ipairs-iterable list of player objects
---@return table<integer, table[]> rosters teamIndex -> array of players
function TeamUtils.buildTeamRosters(context, players)
  local rosters = {}
  for _, p in ipairs(players) do
    local idx = TeamUtils.teamIndexForPlayer(context, p)
    if idx then
      rosters[idx] = rosters[idx] or {}
      rosters[idx][#rosters[idx] + 1] = p
    end
  end
  return rosters
end

-- Returns the team index that a player belongs to
---@param teams Team[] Array of teams
---@param playerIndex integer The player's index (1-based)
---@return integer|nil teamIndex The team index, or nil if not found
function TeamUtils.getPlayerTeamIndex(teams, playerIndex)
  local team = TeamUtils.getTeamForPlayer(playerIndex, teams)
  if team then
    return team.id
  end
  return nil
end

-- Checks if two players are on the same team
---@param teams Team[] Array of teams
---@param playerIndex1 integer First player's index
---@param playerIndex2 integer Second player's index
---@return boolean areTeammates True if players are on the same team
function TeamUtils.areTeammates(teams, playerIndex1, playerIndex2)
  local team1 = TeamUtils.getPlayerTeamIndex(teams, playerIndex1)
  local team2 = TeamUtils.getPlayerTeamIndex(teams, playerIndex2)
  return team1 ~= nil and team1 == team2
end

-- Checks if a team has any active (alive) players
---@param team Team The team to check
---@param stacks BaseStack[] Array of stacks indexed by player index
---@return boolean isAlive True if at least one player on the team is active
function TeamUtils.isTeamAlive(team, stacks)
  for _, playerIndex in ipairs(team.playerIndices) do
    local stack = stacks[playerIndex]
    if stack and not stack:game_ended() then
      return true
    end
  end
  return false
end

-- Alias for isTeamAlive
function TeamUtils.teamHasActivePlayers(team, stacks)
  return TeamUtils.isTeamAlive(team, stacks)
end

-- Returns all enemy player indices for a given player
---@param teams Team[] Array of teams
---@param playerIndex integer The player's index
---@return integer[] enemies Array of enemy player indices
function TeamUtils.getEnemyPlayerIndices(teams, playerIndex)
  local enemies = {}
  local playerTeam = TeamUtils.getTeamForPlayer(playerIndex, teams)

  if not playerTeam then
    return enemies
  end

  for _, team in ipairs(teams) do
    if team.id ~= playerTeam.id then
      for _, idx in ipairs(team.playerIndices) do
        table.insert(enemies, idx)
      end
    end
  end

  return enemies
end

-- Returns living enemy player indices for a given player
---@param playerIndex integer The player's index
---@param teams Team[] Array of teams
---@param stacks BaseStack[] Array of stacks
---@return integer[] livingEnemies Array of living enemy player indices
function TeamUtils.getLivingEnemies(playerIndex, teams, stacks)
  local livingEnemies = {}
  local playerTeam = TeamUtils.getTeamForPlayer(playerIndex, teams)

  if not playerTeam then
    return livingEnemies
  end

  for _, team in ipairs(teams) do
    if team.id ~= playerTeam.id then
      for _, idx in ipairs(team.playerIndices) do
        local stack = stacks[idx]
        if stack and not stack:game_ended() then
          table.insert(livingEnemies, idx)
        end
      end
    end
  end

  return livingEnemies
end

-- Returns all teammate player indices for a given player (excluding self)
---@param teams Team[] Array of teams
---@param playerIndex integer The player's index
---@return integer[] teammates Array of teammate player indices
function TeamUtils.getTeammatePlayerIndices(teams, playerIndex)
  local teammates = {}
  local team = TeamUtils.getTeamForPlayer(playerIndex, teams)

  if not team then
    return teammates
  end

  for _, idx in ipairs(team.playerIndices) do
    if idx ~= playerIndex then
      table.insert(teammates, idx)
    end
  end

  return teammates
end

-- Counts how many teams have active players
---@param teams Team[] Array of teams
---@param stacks BaseStack[] Array of stacks
---@return integer activeTeamCount Number of teams with at least one active player
function TeamUtils.getTeamsAliveCount(teams, stacks)
  local count = 0
  for _, team in ipairs(teams) do
    if TeamUtils.isTeamAlive(team, stacks) then
      count = count + 1
    end
  end
  return count
end

-- Alias for getTeamsAliveCount
function TeamUtils.countActiveTeams(teams, stacks)
  return TeamUtils.getTeamsAliveCount(teams, stacks)
end

-- Returns the winning team (the only active team remaining)
---@param teams Team[] Array of teams
---@param stacks BaseStack[] Array of stacks
---@return Team|nil winningTeam The winning team, or nil if no winner yet or draw
function TeamUtils.getWinningTeam(teams, stacks)
  local activeTeams = {}
  for _, team in ipairs(teams) do
    if TeamUtils.isTeamAlive(team, stacks) then
      table.insert(activeTeams, team)
    end
  end

  if #activeTeams == 1 then
    return activeTeams[1]
  end

  return nil
end

-- Returns all active enemy stacks for a player
---@param teams Team[] Array of teams
---@param playerIndex integer The player's index
---@param stacks BaseStack[] Array of stacks
---@return BaseStack[] activeEnemies Array of active enemy stacks
function TeamUtils.getActiveEnemyStacks(teams, playerIndex, stacks)
  local activeEnemies = {}
  local enemyIndices = TeamUtils.getLivingEnemies(playerIndex, teams, stacks)

  for _, enemyIndex in ipairs(enemyIndices) do
    local stack = stacks[enemyIndex]
    if stack then
      table.insert(activeEnemies, stack)
    end
  end

  return activeEnemies
end

---Round-robin walk: starting at `startIndex` in `enemyIndices`, find the
---first slot for which `aliveFn(slot)` returns truthy, then keep walking
---to find the next-living slot after the picked one. Returns three values:
---  * pickedIndex — position in enemyIndices of the first living at/after
---    startIndex (nil if none living anywhere in the list).
---  * pickedSlot — enemyIndices[pickedIndex] (nil if none).
---  * nextLivingIndex — position in enemyIndices of the first living
---    strictly after pickedIndex, wrapping. Nil if no other living exists
---    (only one survivor — caller should leave its cursor as-is).
---
---Centralized so Match.lua's distributeGarbageToTargets cursor advance,
---server/Room.lua's _redirectIfDead walk-forward, and the client's
---cursor self-heal on G receipt all use the same predicate. Drift between
---those three sites was the root cause of bug C (telegraph divergence at
---death boundaries).
---@param enemyIndices integer[] enemy slot indices (per-sender, from setupTeamGarbageTargets)
---@param startIndex integer 1-based position in enemyIndices to start from (wraps)
---@param aliveFn fun(slot: integer): boolean predicate — true if the slot is still alive/eligible
---@return integer? pickedIndex
---@return integer? pickedSlot
---@return integer? nextLivingIndex
function TeamUtils.findNextLiving(enemyIndices, startIndex, aliveFn)
  local n = #enemyIndices
  if n == 0 then return nil, nil, nil end

  -- Clamp startIndex into [1, n] in case the caller's cursor walked
  -- out-of-bounds via past advancement.
  if startIndex < 1 or startIndex > n then
    startIndex = ((startIndex - 1) % n) + 1
    if startIndex < 1 then startIndex = startIndex + n end
  end

  local pickedIndex, pickedSlot
  local i = startIndex
  for _ = 1, n do
    local slot = enemyIndices[i]
    if slot and aliveFn(slot) then
      pickedIndex = i
      pickedSlot = slot
      break
    end
    i = (i % n) + 1
  end

  if not pickedIndex then
    return nil, nil, nil
  end

  -- Walk one full lap to find the next living after pickedIndex.
  local nextLivingIndex
  local j = pickedIndex
  for _ = 1, n do
    j = (j % n) + 1
    if j == pickedIndex then
      -- Walked the whole list and only pickedIndex is alive — leave nil so
      -- callers can choose to keep the cursor where it was.
      break
    end
    local slot = enemyIndices[j]
    if slot and aliveFn(slot) then
      nextLivingIndex = j
      break
    end
  end

  return pickedIndex, pickedSlot, nextLivingIndex
end

-- Seat / stack mapping helpers.
--
-- Two slot concepts, split deliberately:
--   seatId      preset team-coordinate slot (1..maxPlayers). Stable across
--               the player's lifetime in the room. Lobby UI, openSeats, team
--               assignment, held-slot reservation all speak seatId.
--   stackIndex  dense engine label (1..N where N = filled seats). Per-match
--               only. Engine, replay stacks, input relay, eliminatedPlayers
--               and friends speak stackIndex.
--
-- Player shape:
--   player.seatId     stable, set on join
--   player.stackIndex per-match, set by assignStackIndices

-- Enumerate seat-coordinate space; stable across compaction.
---@param players table<integer, table>  seatId-keyed (may be sparse)
---@param maxPlayers integer
---@param heldSeatIds integer[]? seatIds reserved for rejoiners
---@return integer[]
function TeamUtils.openSeats(players, maxPlayers, heldSeatIds)
  local held = {}
  if heldSeatIds then
    for _, s in ipairs(heldSeatIds) do held[s] = true end
  end
  local slots = {}
  for i = 1, maxPlayers do
    if not players[i] and not held[i] then
      slots[#slots + 1] = i
    end
  end
  return slots
end

-- Assign stack indices to occupied seats. Walks seats in ascending order;
-- mutates each player's stackIndex and player_number (legacy callsites read
-- player_number; during a match it is the stackIndex). Does not renumber the
-- players table's keys.
---@param players table<integer, table>  seatId-keyed
---@return table<integer, integer> seatToStack  seatId -> stackIndex
---@return integer[] stackToSeat                 stackIndex -> seatId
---@return table[] densePlayers                  players in stackIndex order
function TeamUtils.assignStackIndices(players)
  local seats = {}
  for seatId, p in pairs(players) do
    if p then seats[#seats + 1] = seatId end
  end
  table.sort(seats)

  local seatToStack = {}
  local stackToSeat = {}
  local densePlayers = {}
  for stackIdx, seatId in ipairs(seats) do
    local player = players[seatId]
    seatToStack[seatId] = stackIdx
    stackToSeat[stackIdx] = seatId
    densePlayers[stackIdx] = player
    player.stackIndex = stackIdx
    player.player_number = stackIdx
  end
  return seatToStack, stackToSeat, densePlayers
end

-- Inverse of assignStackIndices. Restores player_number to seatId.
---@param players table<integer, table>  seatId-keyed
function TeamUtils.clearStackIndices(players)
  for seatId, p in pairs(players) do
    if p then
      p.stackIndex = nil
      p.player_number = p.seatId or seatId
    end
  end
end

-- Translate seatId-based teams[] into stackIndex-based teams[] for engine.
---@param teams Team[]
---@param seatToStack table<integer, integer>
---@return Team[]
function TeamUtils.remapTeamsBySeatToStack(teams, seatToStack)
  local remapped = {}
  for _, team in ipairs(teams) do
    local stackIndices = {}
    for _, seatId in ipairs(team.playerIndices) do
      local stackIdx = seatToStack[seatId]
      if stackIdx then stackIndices[#stackIndices + 1] = stackIdx end
    end
    remapped[team.id] = {
      id = team.id,
      teamIndex = team.teamIndex,
      playerIndices = stackIndices,
    }
  end
  return remapped
end

-- Which teams still have a living member. FFA (teams == nil) treats each
-- seat as its own team; team key in that case is the seatId.
---@param players table<integer, table>  seatId-keyed
---@param teams Team[]?  stackIndex-based (engine view)
---@param isAlive fun(seatId: integer, player: table): boolean
---@return integer[] teamKeys
---@return integer[] representatives  one seatId per living team
function TeamUtils.livingTeams(players, teams, isAlive)
  local teamKeys = {}
  local reps = {}
  local seen = {}
  local seats = {}
  for seatId, p in pairs(players) do
    if p then seats[#seats + 1] = seatId end
  end
  table.sort(seats)
  for _, seatId in ipairs(seats) do
    local player = players[seatId]
    if isAlive(seatId, player) then
      local key
      if teams then
        local stackIdx = player.stackIndex or seatId
        key = TeamUtils.getPlayerTeamIndex(teams, stackIdx)
      else
        key = seatId
      end
      if key and not seen[key] then
        seen[key] = true
        teamKeys[#teamKeys + 1] = key
        reps[#reps + 1] = seatId
      end
    end
  end
  return teamKeys, reps
end

return TeamUtils
