local class = require("common.lib.class")
local GameModes = require("common.data.GameModes")
local logger = require("common.lib.logger")
local StackBehaviours = require("common.data.StackBehaviours")
local InputCompression = require("common.data.InputCompression")
local ReplayV3 = require("common.data.ReplayV3")
local LevelPresets    = require("common.data.LevelPresets")
local TeamUtils = require("common.data.TeamUtils")
---@class ServerGame
---@field id integer?
---@field seed integer
---@field players ServerPlayer[]
---@field replay ReplayV3
---@field winnerId integer?
---@field winnerIndex integer?
---@field winnerTeamIndex integer?
---@field teams Team[]?
---@field ranked boolean
---@field package inputs string[][]
---@field package outcomeReports integer[]
---@field package disconnectedPlayers table<integer, boolean>
---@field package eliminatedPlayers table<integer, integer> player_number -> game_over_clock frame
---@field complete boolean
---@field creationTime integer
local Game = class(
---@param players ServerPlayer[]
---@param id integer?
function(self, players, id)
  self.seed = math.random(1, 9999999)
  self.players = players
  -- Invariant: by the time Game is constructed, room.players has been
  -- compacted dense (see Room:start_match). Indices 1..N here line up with
  -- player.player_number. Mid-match leavers nil-out their slot but never
  -- shift surviving slots, so this mapping holds for the entire match.
  for i, p in ipairs(players) do
    assert(p.player_number == i,
      "Game: players[" .. i .. "].player_number = " .. tostring(p.player_number)
      .. " — expected " .. i .. ". Compaction skipped or mis-sequenced.")
  end
  self.inputs = {}
  for i = 1, #players do
    self.inputs[i] = {}
  end
  self.id = id
  self.outcomeReports = {}
  self.disconnectedPlayers = {}
  self.eliminatedPlayers = {}
  ---@type table[] loose-sync GarbageEvent payloads, in arrival order
  self.garbageEvents = {}
  ---@type table[] loose-sync DeathEvent payloads, in arrival order
  self.deathEvents = {}
  self.complete = false
  self.creationTime = os.time()
end)

---@param room Room
---@return ServerGame game
function Game.createFromRoomState(room)
  local game = Game(room.players)
  -- Honor a roomRequest-supplied seed for reproducible scenarios (e2e tests,
  -- "play the same opening every run" debugging). Falls back to the random
  -- seed Game's constructor already picked when no override was supplied.
  if room.gameMode and room.gameMode.seedOverride then
    game.seed = room.gameMode.seedOverride
  end

  local roomIsRanked, reasons = room:rating_adjustment_approved()
  game.ranked = roomIsRanked
  game.teams = room.teams

  local replayPanelSource = {
    sourceType = 3,
    seed = game.seed,
    shockEnabled = room.gameMode.stackInteraction ~= GameModes.StackInteractions.NONE,
  }

  local replay = ReplayV3(ENGINE_VERSION, room.gameMode.matchRules, replayPanelSource)
  replay:setStage(room.stageId)
  replay:setRanked(game.ranked)
  replay.metadata.gameModeName = room.gameMode.name
  -- Compacted team shape for THIS match. Server rebuilds playersPerTeam at
  -- start_match to reflect the actual roster split; clients use this rather
  -- than the original preset so engine.teams matches server-side teams.
  replay.metadata.playersPerTeam = room.gameMode.playersPerTeam
  replay.metadata.teamCount = room.gameMode.teamCount

  for i, player in ipairs(room.players) do
    ---@type ReplayStack
    local stack = {
      inputMethod = player.inputMethod,
      inputs = "",
      levelData = player.levelData or LevelPresets.getModern(player.level),
      stackType = 1,
      stackBehaviours = StackBehaviours.getDefault(),
    }

    replay.stacks[i] = stack

    ---@type StackMetadata
    local metadata = {
      stackIndex = i,
      characterId = player.character,
      panelId = player.panels_dir,
      name = player.name,
      publicId = player.publicPlayerID,
      wins = room.win_counts[i],
    }

    if stack.levelData.frameConstants.GARBAGE_HOVER then
      metadata.level = player.level
    else
      -- TODO: https://github.com/panel-attack/panel-game/issues/602
      -- Use this pattern when we are in this area again and testing server
      -- local presetInfo = LevelPresets.getStyleAndPreset(levelData)
      metadata.difficulty = player.level
    end

    replay.metadata.stacks[i] = metadata
  end

  if room.gameMode.stackInteraction == GameModes.StackInteractions.SELF then
    for i, _ in ipairs(replay.stacks) do
      replay.garbageFlows[#replay.garbageFlows+1] = {
        source = i,
        recipients = { i }
      }
    end
  elseif room.gameMode.stackInteraction == GameModes.StackInteractions.ATTACK_ENGINE then
    logger.error("Attack engine game modes are not implemented yet")
  elseif room.gameMode.stackInteraction == GameModes.StackInteractions.VERSUS then
    for i = 1, #replay.stacks do
      local recipients = {}
      for j = 1, #replay.stacks do
        if i ~= j then
          recipients[#recipients+1] = j
        end
      end
      replay.garbageFlows[#replay.garbageFlows+1] = {
        source = i,
        recipients = recipients,
      }
    end
  elseif room.gameMode.stackInteraction == GameModes.StackInteractions.TEAM_VERSUS then
    -- Team versus: each player sends garbage to enemies only (not teammates)
    if room.teams then
      for i = 1, #replay.stacks do
        local enemyIndices = TeamUtils.getEnemyPlayerIndices(room.teams, i)
        replay.garbageFlows[#replay.garbageFlows+1] = {
          source = i,
          recipients = enemyIndices,
        }
      end
    else
      -- Fallback to regular VERSUS if no teams configured
      for i = 1, #replay.stacks do
        local recipients = {}
        for j = 1, #replay.stacks do
          if i ~= j then
            recipients[#recipients+1] = j
          end
        end
        replay.garbageFlows[#replay.garbageFlows+1] = {
          source = i,
          recipients = recipients,
        }
      end
    end
  end

  game.replay = replay

  return game
end

---@param player ServerPlayer
---@param input string
function Game:receiveInput(player, input)
  if not self.complete then
    self.inputs[player.player_number][#self.inputs[player.player_number] + 1] = input
  end
end

---Append a loose-sync GarbageEvent body to the replay log.
---The body has already been stamped with sender + serverWallClockMs by the room.
---@param player ServerPlayer
---@param body table parsed JSON event body
function Game:recordGarbageEvent(player, body)
  if not self.complete then
    self.garbageEvents[#self.garbageEvents + 1] = body
  end
end

---Append a loose-sync DeathEvent body to the replay log.
---@param player ServerPlayer
---@param body table parsed JSON event body
function Game:recordDeathEvent(player, body)
  if not self.complete then
    self.deathEvents[#self.deathEvents + 1] = body
  end
end

---@param compressInputs boolean
---@return ReplayV3?
function Game:getPartialReplay(compressInputs)
  if not self.replay then
    return nil
  else
    for i, stack in ipairs(self.replay.stacks) do
      if stack.stackType == 1 then
        ---@cast stack ReplayStack
        if compressInputs then
          stack.inputs = InputCompression.compressInputTable(self.inputs[i])
        else
          stack.inputs = table.concat(self.inputs[i])
        end
      end
    end
    -- Include the loose-sync authoritative event log so a spectator or rejoiner
    -- can reconstruct historical garbage + death deliveries during catch-up.
    -- Without this, the only state they have is each stack's input stream;
    -- applyGarbageEvent / applyDeathEvent never fire for pre-join events,
    -- recipients end up with less garbage than they should, and dead senders
    -- run past their game_over_clock instead of stopping when the sim reaches
    -- the historical death frame.
    if self.replay.crossPlayerEvents then
      self.replay.crossPlayerEvents.garbage = self.garbageEvents
      self.replay.crossPlayerEvents.deaths = self.deathEvents
    end
    return self.replay
  end
end

function Game:receiveOutcomeReport(player, outcome)
  local idx = player.player_number

  -- Only living players get a vote. A dead stack has already lost — its
  -- vote can't decide who won (most importantly, can't unilaterally declare
  -- a tie). Discard at the door. The arbitration path in Room:tickArbitration
  -- is the authoritative match-end for any case the server already knows
  -- (livingTeams <= 1); this filter is a belt-and-suspenders for the vote
  -- path so a stale "I think it's a tie" can't slip in and poison things.
  -- Do NOT early-return — we still need to run the all-reported-in check
  -- below. When every player aborts in sequence, each report is discarded
  -- but the last-reporter's call is the only thing that ever triggers the
  -- resolution; early-returning here would leave the game in a zombie state.
  if not (self.eliminatedPlayers[idx] or self.disconnectedPlayers[idx]) then
    self.outcomeReports[idx] = outcome
  end

  -- pairs not ipairs: self.players is sparse after mid-match leave.
  for i in pairs(self.players) do
    if not self.disconnectedPlayers[i]
        and not self.eliminatedPlayers[i]
        and self.outcomeReports[i] == nil then
      return
    end
  end

  local result, winnerTeamIndex = Game.getOutcome(self.outcomeReports, self.teams, self.disconnectedPlayers, self.eliminatedPlayers)
  if not result then
    --if clients disagree, the server needs to decide the outcome, perhaps by watching a replay it had created during the game.
    --for now though...
    local reportSummary = {}
    -- pairs not ipairs: by the time clients disagree on outcome, a mid-match
    -- leaver may have nil'd their slot in self.players, and ipairs would halt
    -- there — making the diagnostic log lie about which players were involved.
    for slot, p in pairs(self.players) do
      reportSummary[#reportSummary + 1] = string.format("slot%d:%s=%s", slot, tostring(p.name), tostring(self.outcomeReports[slot]))
    end
    logger.warn("clients disagree on game outcome (" .. table.concat(reportSummary, ", ") .. "). Server declares a tie.")
    result = 0
    self.aborted = true
  else
    if result ~= 0 then
      self.winnerIndex = result
      self.winnerId = self.players[result].publicPlayerID
      self.winnerTeamIndex = winnerTeamIndex
    end
    self.aborted = false
  end

  self.complete = true
  self:finalizeReplay(result)
end

---@param player ServerPlayer
function Game:markPlayerDisconnected(player)
  self.disconnectedPlayers[player.player_number] = true
  if self.outcomeReports[player.player_number] == nil then
    self.outcomeReports[player.player_number] = false
  end
end

---Mark a player as eliminated (their stack reached game over).
---Idempotent — safe to call multiple times (rollback re-fires possible).
---@param player ServerPlayer
---@param frame integer? game_over_clock when the stack died
function Game:markPlayerEliminated(player, frame)
  if not self.eliminatedPlayers[player.player_number] then
    self.eliminatedPlayers[player.player_number] = frame or 0
  end
end

---@param outcomeReports integer[]
---@param teams Team[]?
---@param disconnectedPlayers table<integer, boolean>?
---@param eliminatedPlayers table<integer, integer>?
---@return integer? winnerIndex the winner of the game (player index), 0 if tie, nil if the players disagreed on the outcome
---@return integer? winnerTeamIndex the winning team index (only for team games)
function Game.getOutcome(outcomeReports, teams, disconnectedPlayers, eliminatedPlayers)
  local function isOut(idx)
    return (disconnectedPlayers and disconnectedPlayers[idx])
        or (eliminatedPlayers and eliminatedPlayers[idx])
  end

  if teams then
    -- Team game: validate team-based outcomes
    -- outcome = 1 means "my team won", outcome = 2 means "my team lost", outcome = 0 means "I don't claim victory"
    -- (a single 0 is NOT a tie veto — a real tie only happens when no team reports outcome == 1)
    local teamOutcomes = {}

    -- pairs, not ipairs: receiveOutcomeReport drops the entries for
    -- eliminated/disconnected players, leaving outcomeReports sparse. ipairs
    -- would terminate at the first gap and silently skip later players'
    -- reports, breaking 3+p where one player died early.
    for playerIndex, outcome in pairs(outcomeReports) do
      if not isOut(playerIndex) then
        local teamIndex = TeamUtils.getPlayerTeamIndex(teams, playerIndex)
        if teamIndex then
          if not teamOutcomes[teamIndex] then
            teamOutcomes[teamIndex] = outcome
          elseif teamOutcomes[teamIndex] ~= outcome then
            -- Teammates disagree
            return nil, nil
          end
        end
      end
    end

    -- Find the winning team. A team reporting `outcome == 0` is a "no claim",
    -- not a tie veto — keep scanning. Multiple teams claiming victory is the
    -- only consensus failure.
    local winningTeam = nil
    for teamIndex, outcome in pairs(teamOutcomes) do
      if outcome == 1 then
        if winningTeam then
          -- Multiple teams claim victory
          return nil, nil
        end
        winningTeam = teamIndex
      end
    end

    if winningTeam then
      -- Return first player of winning team as the winner
      local team = teams[winningTeam]
      return team.playerIndices[1], winningTeam
    end

    return 0, nil  -- No team claimed victory → tie
  else
    -- Non-team game: all players must agree on the same winner.
    -- pairs, not ipairs: outcomeReports is sparse when an eliminated player's
    -- report was discarded — see comment in the team branch above.
    for i, outcomeA in pairs(outcomeReports) do
      if not isOut(i) then
        for j, outcomeB in pairs(outcomeReports) do
          if i ~= j and not isOut(j) then
            if outcomeA ~= outcomeB then
              return nil, nil
            end
          end
        end
      end
    end

    -- everyone agrees on the outcome — take the first non-excluded report
    for i, outcome in pairs(outcomeReports) do
      if not isOut(i) then
        return outcome, nil
      end
    end
    return 0, nil  -- everyone excluded → tie
  end
end

---@param result integer?
function Game:finalizeReplay(result)
  self.replay:setOutcome(result)

  for i, stack in ipairs(self.replay.stacks) do
    if stack.stackType == 1 then
      ---@cast stack ReplayStack
      if COMPRESS_REPLAYS_ENABLED then
        stack.inputs = InputCompression.compressInputTable(self.inputs[i])
      else
        stack.inputs = table.concat(self.inputs[i])
      end
    end
  end

  -- Loose-sync V4: persist the authoritative cross-player event log so
  -- playback can apply the exact garbage + death events that happened
  -- during the live match.
  if self.replay.crossPlayerEvents then
    self.replay.crossPlayerEvents.garbage = self.garbageEvents
    self.replay.crossPlayerEvents.deaths = self.deathEvents
  end

  -- pairs not ipairs: a mid-match leaver's slot is nil'd in self.players,
  -- and ipairs halting at the hole would skip anonymizing surviving players
  -- past it — leaking their names into the saved replay despite their setting.
  for slot, player in pairs(self.players) do
    if player.save_replays_publicly == "anonymously" then
      local playerMetadata = self.replay.metadata.stacks[slot]
      ---@cast playerMetadata StackMetadata
      playerMetadata.name = "anonymous"
      playerMetadata.publicId = - slot
      if playerMetadata.publicId == self.replay.metadata.winnerId then
        self.replay.metadata.winnerId = - slot
      end
    end
  end
end

---@param id integer
---@return integer gameId
function Game:setId(id)
  if not self.id then
    self.id = id
  end

  if self.replay then
    self.replay.metadata.gameId = self.id
  end

  return self.id
end

---Ordinal placement (1 = winner, higher = died earlier). Uses each player's
---reported senderFrame as the rank key — client clock, not server arrival time.
---Ties on same frame share placement (competition ranking: 1, 2, 2, 4).
---@param player ServerPlayer
---@param slot integer? slot override for callers where player.player_number may be nil (leavers)
---@return integer
function Game:getPlacement(player, slot)
  slot = slot or player.player_number
  if not slot then return 0 end

  -- Team mode: rank by team's last-survivor fall frame.
  if self.teams and self.teams[1] then
    local myTeam = TeamUtils.getPlayerTeamIndex(self.teams, slot)
    if not myTeam then return 0 end

    local function teamFallFrame(t)
      if t == self.winnerTeamIndex then return math.huge end
      local team = self.teams[t]
      if not team or not team.playerIndices then return 0 end
      local maxFrame = 0
      for _, memberSlot in ipairs(team.playerIndices) do
        local f = (self.eliminatedPlayers and self.eliminatedPlayers[memberSlot])
               or (self.disconnectedPlayers and self.disconnectedPlayers[memberSlot] and 0)
               or 0
        if f > maxFrame then maxFrame = f end
      end
      return maxFrame
    end

    local myFrame = teamFallFrame(myTeam)
    local higher = 0
    for otherTeam = 1, #self.teams do
      if otherTeam ~= myTeam and teamFallFrame(otherTeam) > myFrame then
        higher = higher + 1
      end
    end
    return 1 + higher
  end

  -- FFA / individual mode: winner has math.huge rank; everyone else uses fall frame.
  local function slotFallFrame(s)
    if self.winnerIndex and s == self.winnerIndex then return math.huge end
    return (self.eliminatedPlayers and self.eliminatedPlayers[s])
        or (self.disconnectedPlayers and self.disconnectedPlayers[s] and 0)
        or nil
  end

  local myFrame = slotFallFrame(slot)
  if not myFrame then return 0 end

  local rankable = {}
  if self.winnerIndex then rankable[self.winnerIndex] = true end
  for s in pairs(self.eliminatedPlayers or {}) do rankable[s] = true end
  for s in pairs(self.disconnectedPlayers or {}) do rankable[s] = true end

  local higher = 0
  for s in pairs(rankable) do
    if s ~= slot then
      local f = slotFallFrame(s)
      if f and f > myFrame then higher = higher + 1 end
    end
  end
  return 1 + higher
end

return Game