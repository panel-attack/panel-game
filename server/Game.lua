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
  if self.eliminatedPlayers[idx] or self.disconnectedPlayers[idx] then
    return
  end

  self.outcomeReports[idx] = outcome

  -- cannot compare #self.outcomeReports == #self.players because # is undefined regarding gaps near 0
  -- so if we have the report for player 2 but not player 1, #self.outcomeReports may return 2 instead of 0
  -- see https://www.lua.org/manual/5.1/manual.html#2.5.5
  for i = 1, #self.players do
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

    for playerIndex, outcome in ipairs(outcomeReports) do
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
    -- Non-team game: all players must agree on the same winner
    for i, outcomeA in ipairs(outcomeReports) do
      if not isOut(i) then
        for j, outcomeB in ipairs(outcomeReports) do
          if i ~= j and not isOut(j) then
            if outcomeA ~= outcomeB then
              return nil, nil
            end
          end
        end
      end
    end

    -- everyone agrees on the outcome — take the first non-excluded report
    for i, outcome in ipairs(outcomeReports) do
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

---@param player ServerPlayer
---@return integer
function Game:getPlacement(player)
  if self.disconnectedPlayers and self.disconnectedPlayers[player.player_number] then
    return 2
  end

  if not self.winnerId then
    return 0
  else
    if self.winnerIndex == player.player_number then
      return 1
    else
      return 2
    end
  end
end

return Game