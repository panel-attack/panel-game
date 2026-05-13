-- TeamUtils.lua
-- Utility functions for team management in multi-player modes

local TeamUtils = {}

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

return TeamUtils
