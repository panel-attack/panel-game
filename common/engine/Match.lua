local class = require("common.lib.class")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local GameModes = require("common.data.GameModes")
local SimulatedStack = require("common.engine.SimulatedStack")
local Stack = require("common.engine.Stack")
require("common.engine.checkMatches")
local consts = require("common.engine.consts")
local GeneratorSource = require("common.engine.GeneratorSource")
local PuzzleSource    = require("common.engine.PuzzleSource")
local LegacyPanelSource = require("common.compatibility.LegacyPanelSource")
local InputCompression = require("common.data.InputCompression")
local ReplayV3 = require("common.data.ReplayV3")
local MatchRules = require("common.data.MatchRules")
local TeamUtils = require("common.data.TeamUtils")

---@class Match
---@field stacks (Stack | SimulatedStack)[] The stacks to run as part of the match
---@field garbageTargets table<integer, table<integer, Stack>> assignments by index where each stack's garbage is directed
---@field garbageSources table<Stack, table<integer, Stack>> assignments by index where each stack's incoming garbage comes from
---@field teams Team[]? Array of teams for team-based game modes
---@field garbageMode string? Garbage distribution mode: "all" (hits all enemies) or "shared" (round-robin)
---@field teamGarbageState table<integer, table>? Round-robin state for shared garbage mode, indexed by team
---@field engineVersion string
---@field rules MatchRules
---@field doCountdown boolean if a countdown is performed at the start of the match; mirror of rules.doCountdown for easier access
---@field panelSource (PanelSource | LegacyPanelSource | PuzzleSource | GeneratorSource)
---@field timeLimit integer? if the game automatically ends after a certain time
---@field puzzle table
---@field startTimestamp integer
---@field createTime number
---@field timeSpentRunning number
---@field maxTimeSpentRunning number
---@field clock integer
---@field ended boolean
---@field gameOverClock integer?
---@field aborted boolean the game stopped in the middle because of crash, desync, game leave, online player left, etc.
---@field desyncError boolean? the match stopped because the other stack became too out of sync
---@field debug MatchDebugConfig internal debug configuration that defaults to non-debug values

---@class MatchDebugConfig
---@field vsFramesBehind integer

-- A match is a particular instance of the game, for example 1 time attack round, or 1 vs match
---@class Match
---@overload fun(panelSource: PanelSource, matchRules: MatchRules): Match
local Match = class(
---@param self Match
---@param matchRules MatchRules
---@param panelSource PanelSource
function(self, panelSource, matchRules)
  self.stacks = {}
  self.garbageTargets = {}
  self.garbageSources = {}
  self.engineVersion = consts.ENGINE_VERSION

  assert(matchRules)
  assert(panelSource)
  self.panelSource = panelSource
  self.rules = matchRules
  self.doCountdown = self.rules.doCountdown

  if self.rules.matchEndConditions[MatchRules.MatchEndConditions.TIME_LIMIT] then
    self.timeLimit = self.rules.matchEndConditions[MatchRules.MatchEndConditions.TIME_LIMIT]
  end

  self.timeSpentRunning = 0
  self.maxTimeSpentRunning = 0
  self.createTime = love.timer.getTime()
  ---@diagnostic disable-next-line: param-type-mismatch
  self.startTimestamp = os.time(os.date("*t"))
  self.clock = 0
  self.ended = false
  self.aborted = false

  -- Initialize internal debug configuration with non-debug defaults
  self.debug = {
    vsFramesBehind = 0
  }
end
)

Match.TYPE = "Match"

-- returns the players that won the match in a table
-- returns a single winner if there was a clear winner
-- returns multiple winners if there was a tie (or the game mode had no win conditions)
-- returns an empty table if there was no winner due to the game not finishing / getting aborted
-- the function caches the result of the first call so it should only be called when the match has ended
---@return BaseStack[]
function Match:getWinners()
  -- return a cached result if the function was already called before
  if self.winners then
    return self.winners
  end

  -- game over is handled on the stack level and results in stack:game_ended() = true
  -- win conditions are in ORDER, meaning if stack A met win condition 1 and stack B met win condition 2, stack A wins
  -- while if both stacks meet win condition 1 and stack B meets win condition 2, stack B wins

  local winners = {}
  if #self.stacks == 1 then
    -- with only a single stack, they always win I guess
    winners[1] = self.stacks[1]
  else
    -- the winner is determined through process of elimination
    -- for each win condition in sequence, all stacks not meeting that win condition are purged from potentialWinners
    -- this happens until there is only 1 winner left or until there are no win conditions left to check which may result in a tie
    local potentialWinners = shallowcpy(self.stacks)
    for i = 1, #self.rules.matchWinRuleset do
      local metCondition = {}
      local winCon, order = next(self.rules.matchWinRuleset[i])
      for j = 1, #potentialWinners do
        local potentialWinner = potentialWinners[j]
        -- now we check for this stack whether they meet the current winCondition
        if winCon == MatchRules.MatchWinCriterias.GAME_OVER_CLOCK then
          local hasHighestGameOverClock = true
          if potentialWinner.game_over_clock > 0 then
            for k = 1, #potentialWinners do
              if k ~= j then
                if potentialWinners[k].game_over_clock < 0 then
                  hasHighestGameOverClock = false
                elseif potentialWinner.game_over_clock < potentialWinners[k].game_over_clock then
                  hasHighestGameOverClock = false
                  break
                end
              end
            end
          else
            -- negative game over clock means the player never actually died
          end
          if hasHighestGameOverClock then
            table.insert(metCondition, potentialWinner)
          end
        elseif winCon == MatchRules.MatchWinCriterias.SCORE then
          local hasHighestScore = true
          for k = 1, #potentialWinners do
            if k ~= j then
              -- only if someone else has a higher score than me do I lose
              -- makes sure to cover score ties
              if potentialWinner.score < potentialWinners[k].score then
                hasHighestScore = false
                break
              end
            end
          end
          if hasHighestScore then
            table.insert(metCondition, potentialWinner)
          end
        elseif winCon == MatchRules.MatchWinCriterias.TIME then
          -- this currently assumes less time is better which would be correct for endless max score or challenge
          -- probably need an alternative for a survival vs against an attack engine where more time wins
          local hasLowestTime = true
          for k = 1, #potentialWinners do
            if k ~= j then
              if potentialWinner:getConfirmedInputCount() < potentialWinners[k]:getConfirmedInputCount() then
                hasLowestTime = false
                break
              end
            end
          end
          if hasLowestTime then
            table.insert(metCondition, potentialWinner)
          end
        end
      end

      if #metCondition == 1 then
        potentialWinners = metCondition
        -- only one winner, we're done
        break
      elseif #metCondition > 1 then
        -- there is a tie in a condition, move on to the next one with only the ones still eligible
        potentialWinners = metCondition
      elseif #metCondition == 0 then
        -- none met the condition, keep going with the current set of potential winners
        -- and see if another winCondition may break the tie
      end
    end
    winners = potentialWinners
  end

  self.winners = winners

  return winners
end

function Match:debugRollbackAndCaptureState(clockGoal)
  local P1 = self.stacks[1]
  local P2 = self.stacks[2]

  if P1.clock <= clockGoal then
    return
  end

  self.savedStackP1 = P1.rollbackCopies[P1.clock]
  if P2 then
    self.savedStackP2 = P2.rollbackCopies[P2.clock]
  end

  local rollbackResult = P1:rollbackToFrame(clockGoal)
  assert(rollbackResult)
  if P2 and P2.clock > clockGoal then
    rollbackResult = P2:rollbackToFrame(clockGoal)
    assert(rollbackResult)
  end
end

function Match:debugAssertDivergence(stack, savedStack)

  for k,v in pairs(savedStack) do
    if type(v) ~= "table" then
      local v2 = stack[k]
      if v ~= v2 then
        error("Stacks have diverged")
      end
    end
  end

  local savedStackString = Stack.divergenceString(savedStack)
  local localStackString = Stack.divergenceString(stack)

  if savedStackString ~= localStackString then
    error("Stacks have diverged")
  end
end

function Match:debugCheckDivergence()
  if not self.savedStackP1 or self.savedStackP1.clock ~= self.stacks[1].clock then
    return
  end
  self:debugAssertDivergence(self.stacks[1], self.savedStackP1)
  self.savedStackP1 = nil

  if not self.savedStackP2 or self.savedStackP2.clock ~= self.stacks[2].clock then
    return
  end

  self:debugAssertDivergence(self.stacks[2], self.savedStackP2)
  self.savedStackP2 = nil
end

---@return integer[] runsPerStack
function Match:run()
  local startTime = love.timer.getTime()

  -- Refresh the cached gameOverClock so Match:shouldRun (per-stack-per-tick
  -- below) has a current value. Previously this was a side effect of
  -- Match:hasEnded() being called every tick from ClientMatch:run; now
  -- it's explicit. evaluateEndConditions is pure, so calling it here
  -- mutates nothing other than the self.gameOverClock cache that
  -- updateMatchEndState writes when result.gameOverClock is defined.
  self:updateMatchEndState()

  self:padRewindDataIfNeeded()

  local runs = {}

  for i, _ in ipairs(self.stacks) do
    runs[i] = 0
  end

  local runsSoFar = 0
  while tableUtils.contains(runs, runsSoFar) do
    for i, stack in ipairs(self.stacks) do
      if stack and self:shouldRun(stack, runsSoFar) then
        self:pushGarbageTo(stack)
        stack:run()

        runs[i] = runs[i] + 1
      end
    end

    self:updateClock()

    -- Distribute multi-target garbage after all stacks have run for this iteration
    self:distributeGarbageToTargets()

    -- Since the stacks can affect each other, don't save rollback until after all have run
    for i, stack in ipairs(self.stacks) do
      if runs[i] > runsSoFar then
        stack:updateFramesBehind(self.clock)
        if self:shouldSaveRollback(stack) then
          stack:saveForRollback()
        end
      end
    end

    self:debugCheckDivergence()

    runsSoFar = runsSoFar + 1
  end

  -- for i = 1, #self.players do
  --   local stack = self.players[i].stack
  --   if stack and stack.is_local not stack:game_ended() then
  --     assert(#stack.confirmedInput == stack.clock, "Local games should always simulate all inputs")
  --   end
  -- end

  local endTime = love.timer.getTime()
  local timeDifference = endTime - startTime
  self.timeSpentRunning = self.timeSpentRunning + timeDifference
  self.maxTimeSpentRunning = math.max(self.maxTimeSpentRunning, timeDifference)

  return runs
end

--- Distributes ready garbage from each sender to their targets
--- For "all" mode: sends to ALL targets at once
--- For "shared" mode: sends to the next target in the round-robin queue
---
--- Shared-mode note: round-robin state is tracked per SENDER and the
--- rotation itself only advances over LIVING enemies. Dead players are
--- skipped for both selection and advancement so the next delivery always
--- rotates to the next living opponent for that sender.
function Match:distributeGarbageToTargets()
  for senderIndex, targets in ipairs(self.garbageTargets) do
    if #targets > 1 then
      -- Multi-target: handle based on garbage mode
      local sender = self.stacks[senderIndex]
      local oldestTransitTime = sender:getOldestFinishedGarbageTransitTime()
      if oldestTransitTime and sender.stopWatch >= oldestTransitTime then
        local garbageDelivery = sender:getReadyGarbageAt(oldestTransitTime)
        if garbageDelivery then
          if self.garbageMode == "shared" then
            local teamState = self.teamGarbageState and self.teamGarbageState[senderIndex]

            if teamState and #teamState.enemyIndices > 0 then
              local stacks = self.stacks
              local _, pickedSlot, nextLivingIndex = TeamUtils.findNextLiving(
                teamState.enemyIndices,
                teamState.currentTargetIndex,
                function(slot)
                  local s = stacks[slot]
                  return s and not s:game_ended()
                end
              )

              if pickedSlot then
                -- Advance the cursor to the next-living-after-picked so
                -- rotation stays over living players only. If only the
                -- picked target is alive, leave the cursor where it is —
                -- next delivery will hit the same lone survivor.
                if nextLivingIndex then
                  teamState.currentTargetIndex = nextLivingIndex
                end

                local targetStack = stacks[pickedSlot]
                local garbageCopy = {}
                for j, g in ipairs(garbageDelivery) do
                  garbageCopy[j] = shallowcpy(g)
                end
                self:deliverOutgoingGarbage(sender, targetStack, garbageCopy)
              end
            end
          else
            -- "All" mode: collect all living targets and send a single batched event
            -- with all recipients (instead of multiple separate events).
            local livingTargets = {}
            for _, target in ipairs(targets) do
              if not target:game_ended() then
                livingTargets[#livingTargets + 1] = target
              end
            end

            if #livingTargets > 0 then
              self:deliverOutgoingGarbageToMultiple(sender, livingTargets, garbageDelivery)
            end
          end
        end
      end
    end
  end
end

---@param stack BaseStack
function Match:pushGarbageTo(stack)
  -- check if anyone wants to push garbage into the stack's queue
  for _, st in ipairs(self.garbageSources[stack]) do
    -- Skip multi-target senders (handled by distributeGarbageToTargets)
    local senderIndex = tableUtils.indexOf(self.stacks, st)
    if senderIndex and #self.garbageTargets[senderIndex] > 1 then
      -- Multi-target garbage is distributed separately, skip this sender
    else
      local oldestTransitTime = st:getOldestFinishedGarbageTransitTime()
      if oldestTransitTime and ((not st.outgoingGarbage.illegalStuffIsAllowed) or (#stack.incomingGarbage.stagedGarbage < 72)) then
        -- Replays use the receiver's clock with strict exact-match (lockstep
        -- ticking preserves the recorded delivery frame). Live loose-sync
        -- uses oldestTransitTime as the ready clock so a receiver view-stack
        -- running in catch-up mode and skipping the exact transit frame
        -- doesn't strand the garbage in the sender's outgoing queue.
        local readyClock
        if self.fromReplay then
          readyClock = stack.stopWatch
        elseif st.stopWatch >= oldestTransitTime then
          readyClock = oldestTransitTime
        end
        if readyClock then
          local garbageDelivery = st:getReadyGarbageAt(readyClock)
          if garbageDelivery then
            self:deliverOutgoingGarbage(st, stack, garbageDelivery)
          end
        end
      end
    end
  end
end

---Deliver garbage from a sender stack to a target stack, honoring the loose-sync
---routing rules:
---  * If the source is local-authoritative and the target is remote (a view of
---    another player), emit a G event so the target's own machine applies the
---    garbage authoritatively. Locally also push the garbage onto the view for
---    visual consistency on the sender's screen.
---  * If the source is remote and the target is local-authoritative, SUPPRESS
---    the local-sim push — the authoritative G event from the source's machine
---    will deliver. Without this, garbage would land twice on the local player.
---  * Otherwise (local↔local self-attack, or remote↔remote on spectator), keep
---    the existing direct push.
---@param source BaseStack
---@param target BaseStack
---@param garbageDelivery table garbage payload (array of Garbage records)
function Match:deliverOutgoingGarbage(source, target, garbageDelivery)
  local looseSyncActive = LOOSE_SYNC_GARBAGE
      and GAME and GAME.netClient and GAME.netClient:isConnected()

  if looseSyncActive then
    if source.is_local and not target.is_local then
      -- Local source → remote target: emit G to the server. Do NOT push the
      -- garbage onto the local view of the target — the server's relay of the
      -- G back to us is what triggers the visual on our view of the recipient
      -- (see ClientMatch:applyGarbageEvent), so we never show a hit the
      -- server hasn't confirmed. The server can also redirect the recipient
      -- if the original target died between our emit and the server's
      -- processing (Room:broadcastGarbageEvent handles round-robin walk-
      -- forward in that case).
      local senderIndex = tableUtils.indexOf(self.stacks, source)
      local recipientIndex = tableUtils.indexOf(self.stacks, target)
      logger.info(string.format(
        "G emit: stack[%d] -> stack[%d] frame=%d count=%d",
        senderIndex or -1, recipientIndex or -1, source.stopWatch or -1,
        garbageDelivery and #garbageDelivery or 0))
      GAME.netClient:sendGarbageEvent({
        senderFrame = source.stopWatch,
        recipients = { recipientIndex },
        garbage = garbageDelivery,
      })
      return
    elseif not source.is_local then
      -- Remote source → anything (local target OR remote target). The
      -- authoritative G from the source's own machine, relayed by the server
      -- to every client, drives ALL visuals via applyGarbageEvent:
      --   * recipient's own machine: G pushes onto the local stack.
      --   * sender's machine: G pushes onto the view of the recipient.
      --   * third-party machines (3+ player modes, spectators): G pushes onto
      --     the view of the recipient there too.
      -- Without suppressing here, the third-party-observer case would push
      -- twice on each non-self view-stack: once from the remote view-of-sender
      -- producing garbage in the local sim, and again when the server relays
      -- the G — causing 2× visual garbage on view-of-non-self-recipient.
      return
    end
  end

  -- Local↔local (vsSelf, puzzle, training, AI bots) and any case where loose
  -- sync isn't active (offline modes, replay playback): direct push, no server
  -- in the loop.
  target:receiveGarbage(garbageDelivery)
end

---Deliver garbage from a sender stack to multiple target stacks via a single batched event.
---Used by "all" mode to send one event with all recipients instead of N separate events.
---@param source BaseStack
---@param targets BaseStack[] array of target stacks
---@param garbageDelivery table garbage payload (array of Garbage records)
function Match:deliverOutgoingGarbageToMultiple(source, targets, garbageDelivery)
  local looseSyncActive = LOOSE_SYNC_GARBAGE
      and GAME and GAME.netClient and GAME.netClient:isConnected()

  if looseSyncActive and source.is_local then
    -- Local source → remote targets: emit a single G event to the server with
    -- ALL recipients listed. Server's redirect logic walks the recipient list
    -- once and handles dead-target redirects atomically per delivery.
    local recipientIndices = {}
    for _, target in ipairs(targets) do
      if not target.is_local then
        local recipientIndex = tableUtils.indexOf(self.stacks, target)
        if recipientIndex then
          recipientIndices[#recipientIndices + 1] = recipientIndex
        end
      end
    end

    if #recipientIndices > 0 then
      local senderIndex = tableUtils.indexOf(self.stacks, source)
      logger.info(string.format(
        "G emit (all): stack[%d] -> [%s] frame=%d count=%d",
        senderIndex or -1, table.concat(recipientIndices, ","),
        source.stopWatch or -1,
        garbageDelivery and #garbageDelivery or 0))
      GAME.netClient:sendGarbageEvent({
        senderFrame = source.stopWatch,
        recipients = recipientIndices,
        garbage = garbageDelivery,
      })
    end
    return
  elseif looseSyncActive and not source.is_local then
    -- Remote source: suppress local-sim push for local targets — the
    -- authoritative G from the source's machine will deliver. Same rule as
    -- the single-recipient path in deliverOutgoingGarbage.
    return
  end

  -- Local↔local or offline: deliver to each target directly (no server relay needed)
  for _, target in ipairs(targets) do
    local garbageCopy = {}
    for j, g in ipairs(garbageDelivery) do
      garbageCopy[j] = shallowcpy(g)
    end
    target:receiveGarbage(garbageCopy)
  end
end

---@param stack BaseStack
---@return boolean
function Match:shouldSaveRollback(stack)
  if self.alwaysSaveRollbacks then
    return true
  else
    -- rollback needs to happen if any sender is more than the garbage delay behind the stack
    for senderIndex, targetList in ipairs(self.garbageTargets) do
      for _, target in ipairs(targetList) do
        if target == stack then
          if self.stacks[senderIndex].stopWatch + GARBAGE_DELAY_LAND_TIME <= stack.stopWatch then
            return true
          end
        end
      end
    end

    return false
  end
end

-- attempt to rollback the specified stack to the specified stopWatch
---@param stack BaseStack
---@param stopWatch integer
---@return boolean success
function Match:rollbackToStopWatch(stack, stopWatch)
  return self:rollbackToFrame(stack, stopWatch + (stack.clock - stack.stopWatch))
end

-- attempt to rollback the specified stack to the specified frame
---@param stack BaseStack
---@param clock integer
---@return boolean success
function Match:rollbackToFrame(stack, clock)
  if stack:rollbackToFrame(clock) then
    return true
  end

  return false
end

-- rewind is ONLY to be used for replay playback as it relies on all stacks being at the same clock time
-- and also uses slightly different data required only in a both-sides rollback scenario that would never occur for online rollback
---@param clock integer
function Match:rewindToFrame(clock)
  -- Bounds check: don't allow rewinding to negative frames
  if clock < 0 then
    return
  end
  local failed = false
  for i, stack in ipairs(self.stacks) do
    if not stack:rewindToFrame(clock) then
      failed = true
      break
    end
  end
  if not failed then
    self.clock = clock
    self.ended = false
  end
end

-- updates the match clock to the clock time of the player furthest into the game
-- also triggers the danger music from time running out if a timeLimit was set
function Match:updateClock()
  for i, stack in ipairs(self.stacks) do
    if stack.clock > self.clock then
      self.clock = stack.clock
    end
  end
end

function Match:getInfo()
  local info = {}
  info.stackInteraction = self.stackInteraction
  info.timeLimit = self.timeLimit or "none"
  info.doCountdown = tostring(self.doCountdown)
  info.ended = self.ended
  info.stacks = {}
  for i, stack in ipairs(self.stacks) do
    if stack.getInfo then
      ---@cast stack Stack
      info.stacks[i] = stack:getInfo()
    end
  end

  return info
end

function Match:start()
  for _, stack in ipairs(self.stacks) do
    stack:setCountdown(self.doCountdown)
    stack:starting_state()
    -- always need clock 0 as a base for rollback
    stack:saveForRollback()
  end
end

---@return ReplayV3
function Match:createNewReplay()
  local replay = ReplayV3(self.engineVersion, self.rules, self.panelSource:toReplaySource())

  for i, stack in ipairs(self.stacks) do
    if stack.TYPE == "Stack" then
      ---@cast stack Stack
      ---@type ReplayStack
      local replayStack = {
        stackType = 1,
        levelData = stack.levelData,
        stackBehaviours = stack.behaviours,
        inputMethod = stack.inputMethod,
        inputs = InputCompression.compressInputTable(stack.confirmedInput)
      }
      replay.stacks[i] = replayStack
    elseif stack.TYPE == "SimulatedStack" then
      ---@cast stack SimulatedStack
      ---@type ReplaySimulatedStack
      local replayStack = {
        stackType = 2,
        attackSettings = stack:getAttackPatternData(),
        healthSettings = stack.healthEngine and stack.healthEngine:getSettings()
      }
      replay.stacks[i] = replayStack
    end
  end

  for senderIndex, targets in ipairs(self.garbageTargets) do
    local recipients = {}
    for _, recipient in ipairs(targets) do
      recipients[#recipients+1] = tableUtils.indexOf(self.stacks, recipient)
    end

    replay.garbageFlows[#replay.garbageFlows+1] = {
      source = senderIndex,
      recipients = recipients
    }
  end

  return replay
end

---@param replay ReplayV3
---@return Match
function Match.createFromReplay(replay)
  local panelSource
  local rps = replay.panelSource

  if rps.sourceType == ReplayV3.panelSourceTypes.seedV1 then
    panelSource = LegacyPanelSource(rps.seed, rps.shockEnabled)
    panelSource:setAllowAdjacentColorsOnStartingBoard(rps.allowAdjacentColorsOnStartingBoard)
    -- allowAdjacentColor is respectively modified on each cloned panelSource as the field can be unique per stack
  elseif rps.sourceType == ReplayV3.panelSourceTypes.puzzle then
    panelSource = PuzzleSource(rps.puzzleString, rps.panelBuffer, rps.garbagePanelBuffer)
  elseif rps.sourceType == ReplayV3.panelSourceTypes.seedV2 then
    panelSource = GeneratorSource(rps.seed, rps.shockEnabled)
  else
    error("Unknown panel source " .. tostring(rps.sourceType))
  end

  local match = Match(panelSource, replay.rules)
  -- Replays should run all stacks to their recorded death frames before
  -- declaring the match over (the test suite + replay-watching scenes rely
  -- on this). Live online play wants the loose-sync bypass in hasEnded so
  -- the survivor doesn't get stuck waiting for the dead opponent's view-
  -- stack to "catch up" — but that only applies to live matches.
  match.fromReplay = true

  for i, replayStack in ipairs(replay.stacks) do
    local stack
    if replayStack.stackType == 1 then
      ---@cast replayStack ReplayStack
      stack = match:createStackWithSettings(replayStack.levelData, false, replayStack.inputMethod, replayStack.inputs)
    elseif replayStack.stackType == 2 then
      ---@cast replayStack ReplaySimulatedStack
      stack = match:createSimulatedStackWithSettings(replayStack.attackSettings, replayStack.healthSettings)
    else
      error("Unknown stack type " .. replayStack.stackType)
    end
    match.garbageTargets[i] = {}
    match.garbageSources[stack] = {}
  end

  for _, garbageFlow in ipairs(replay.garbageFlows) do
    local senderStack = match.stacks[garbageFlow.source]
    local sourceTargets = match.garbageTargets[garbageFlow.source]
    -- Skip flows whose source has no stack (replay shape disagrees with stack
    -- count, e.g. a server bug yielded a flow pointing at a missing player).
    -- Hard-crashing the client just because one flow is malformed strands the
    -- match — log loudly and continue so the rest of the replay still loads.
    if senderStack and sourceTargets then
      for _, recipientIndex in ipairs(garbageFlow.recipients) do
        local recipientStack = match.stacks[recipientIndex]
        local recipientSources = recipientStack and match.garbageSources[recipientStack]
        if recipientStack and recipientSources then
          table.insert(sourceTargets, recipientStack)
          table.insert(recipientSources, senderStack)
          recipientStack.incomingGarbage.illegalStuffIsAllowed = senderStack.outgoingGarbage.illegalStuffIsAllowed
          recipientStack.incomingGarbage.treatMetalAsCombo = senderStack.outgoingGarbage.treatMetalAsCombo
        else
          logger.warn(string.format(
            "Match.createFromReplay: skipping garbage flow %d->%d (recipient stack missing in replay with %d stacks)",
            garbageFlow.source, recipientIndex, #match.stacks))
        end
      end
    else
      logger.warn(string.format(
        "Match.createFromReplay: skipping garbage flow from source %d (source stack missing in replay with %d stacks)",
        garbageFlow.source, #match.stacks))
    end
  end

  match:setEngineVersion(replay.engineVersion)
  match:setAlwaysSaveRollbacks(replay.metadata.completed)

  return match
end

function Match:abort()
  self.ended = true
  self.aborted = true
  self:handleMatchEnd()
end

---Pure evaluation of match-end conditions. NO mutations — safe to call
---repeatedly. Returns the gameOverClock so callers (Match:shouldRun,
---winners computation) can cache it explicitly instead of relying on
---hidden side effects.
---
---Does NOT include desync detection — that's a separate, explicit call
---via Match:checkDesync() since it both detects and recovers (sets
---aborted/desyncError).
---@return {ended: boolean, gameOverClock: integer?, reason: string?}
function Match:evaluateEndConditions()
  -- self.ended is only set true by Match:abort(); the natural-finalize path
  -- in ClientMatch:run does NOT flip the engine's self.ended (only
  -- ClientMatch.ended), so this branch effectively covers aborted matches
  -- and the inline aborted block below is redundant but harmless. Kept as
  -- the short-circuit for any future caller that wants to set self.ended
  -- on the engine to indicate finalized state.
  if self.ended then
    return { ended = true, reason = "finalized" }
  end

  if self.aborted then
    return { ended = true, reason = "aborted" }
  end

  -- Loose-sync: in a live match, a remote stack with game_over_clock set
  -- counts as "done" even if its sim clock hasn't caught up. The dead
  -- opponent stops sending inputs after their DeathEvent, so the view-stack
  -- on the survivor's machine is permanently pinned below game_over_clock —
  -- stack:game_ended() (which requires clock >= game_over_clock) stays false
  -- without this bypass, and the match never ends.
  local liveMatch = not self.fromReplay
  local function isDone(stack)
    if liveMatch and stack.game_over_clock and stack.game_over_clock > 0 then
      return true
    end
    return stack:game_ended()
  end

  local aliveCount = 0
  -- dead is more like done as the stack could also have ended by fulfilling a win condition
  local deadCount = 0
  for i = 1, #self.stacks do
    if isDone(self.stacks[i]) then
      deadCount = deadCount + 1
    else
      aliveCount = aliveCount + 1
    end
  end

  local function minGameOverClock()
    local goc = math.huge
    for _, stack in ipairs(self.stacks) do
      if stack.game_over_clock and stack.game_over_clock > 0 then
        goc = math.min(stack.game_over_clock, goc)
      end
    end
    return goc
  end

  if self.rules.matchEndConditions[MatchRules.MatchEndConditions.STACKS_ACTIVE] then
    if aliveCount <= self.rules.matchEndConditions[MatchRules.MatchEndConditions.STACKS_ACTIVE] then
      local gameOverClock = minGameOverClock()
      -- Strict (replays / offline): every stack must have run past
      -- gameOverClock so we know nobody else also died on the next frame.
      -- Live: isDone() accepts stacks with game_over_clock set without
      -- requiring clock catchup (see comment above).
      if tableUtils.trueForAll(self.stacks, function(stack)
        if isDone(stack) then return true end
        return stack.clock and stack.clock > gameOverClock
      end) then
        return { ended = true, gameOverClock = gameOverClock, reason = "stacks_active" }
      end
    end
  end

  -- Team-based end condition: match ends when only 1 team remains active.
  -- Compute team-aliveness inline using isDone() instead of delegating to
  -- TeamUtils.countActiveTeams — the TeamUtils path uses stack:game_ended()
  -- directly, which returns false in live loose-sync for a dead remote stack
  -- whose clock is pinned below its game_over_clock (the remote stops sending
  -- inputs after the DeathEvent). Without isDone() here, FFA/team matches
  -- never end when a remote player dies.
  if self.rules.matchEndConditions[MatchRules.MatchEndConditions.TEAMS_ACTIVE] and self.teams then
    local activeTeamCount = 0
    for _, team in ipairs(self.teams) do
      local teamAlive = false
      for _, playerIndex in ipairs(team.playerIndices) do
        local stack = self.stacks[playerIndex]
        if stack and not isDone(stack) then
          teamAlive = true
          break
        end
      end
      if teamAlive then activeTeamCount = activeTeamCount + 1 end
    end
    if activeTeamCount <= self.rules.matchEndConditions[MatchRules.MatchEndConditions.TEAMS_ACTIVE] then
      local gameOverClock = minGameOverClock()
      -- make sure everyone has run to the currently known game over clock
      -- dead stacks are considered "past" their game over clock (they won't run anymore)
      if tableUtils.trueForAll(self.stacks, function(stack)
        return isDone(stack) or (stack.clock and stack.clock > gameOverClock)
      end) then
        return { ended = true, gameOverClock = gameOverClock, reason = "teams_active" }
      end
    end
  end

  if deadCount == #self.stacks then
    return { ended = true, reason = "all_dead" }
  end

  if self.timeLimit then
    if tableUtils.trueForAll(self.stacks, function(stack) return stack.stopWatch and stack.stopWatch >= self.timeLimit end) then
      return { ended = true, reason = "time_limit" }
    end
  end

  return { ended = false }
end

---Display-only: has this match locally appeared to end? Read-only —
---safe to call from any code path that just wants to know "should I show
---the result UI?" Does NOT drive engine state.
---
---Authoritative finalize gating lives in ClientMatch:shouldFinalize.
---@return boolean
function Match:isLocallyEnded()
  return self.ended or self:evaluateEndConditions().ended
end

---Explicit desync check. If a desync is detected this call MUTATES
---self.aborted and self.desyncError. Used to live inside hasEnded as a
---hidden side effect of "is the match over?" — now it's an opt-in check
---that callers run when they want recovery, not on every read.
---@return boolean true if desync was newly detected this call
function Match:checkDesync()
  if self.aborted then return false end
  if self:isIrrecoverablyDesynced() then
    logger.info("Match irrecoverably desynced")
    self.aborted = true
    self.desyncError = true
    return true
  end
  return false
end

---Side-effectful wrapper around evaluateEndConditions: caches gameOverClock
---on self so Match:shouldRun (per-stack-per-tick) can use it without
---recomputing. Callers that need both the result AND the cache use this;
---callers that just want a read use evaluateEndConditions directly.
---@return {ended: boolean, gameOverClock: integer?, reason: string?}
function Match:updateMatchEndState()
  local result = self:evaluateEndConditions()
  if result.gameOverClock then
    self.gameOverClock = result.gameOverClock
  end
  return result
end

function Match:handleMatchEnd()
  if self.aborted then
    self.winners = {}
  else
    self.winners = self:getWinners()
  end
end

---@return boolean
function Match:isIrrecoverablyDesynced()
  -- Loose-sync: comparing clocks across stacks is not a meaningful health
  -- check. Each stack ticks at its own rate:
  --   * local-authoritative stack: advances at the client's love.update rate
  --   * view stack: advances as inputs arrive over the network
  -- If the two clients run at different tick rates (different machines /
  -- vsync / FPS cap), clocks diverge by hundreds of frames per minute even
  -- on localhost. That divergence is normal, not a desync. Real connection
  -- failures are handled by the server's connection watchdog; bursty input
  -- arrival is absorbed by Stack:shouldRun's catch-up branches.
  --
  -- Returning false here unconditionally so the lockstep-era abort path
  -- never fires in loose-sync matches. The function is kept as a callable
  -- stub for any remaining callers and for future telemetry to slot in.
  return false
end

-- a local function to avoid creating a closure every frame
local checkGameEnded = function(stack)
  return stack:game_ended()
end

-- returns true if the stack should run once more during the current match:run
-- returns false otherwise
---@param stack BaseStack
---@param runsSoFar integer
---@return boolean
function Match:shouldRun(stack, runsSoFar)
  -- check the match specific conditions in match
  if not stack:game_ended() then
    if self.timeLimit then
      -- timeLimit will malfunction with SimulatedStack
      if stack.stopWatch and stack.stopWatch >= self.timeLimit then
        -- the stack should only run 1 frame beyond the time limit (excluding countdown)
        return false
      end
    else
      -- Only cut off surviving stacks AFTER the match has authoritatively ended
      -- (self.ended set by handleMatchEnd → server's gameResult or aborted).
      -- Without the self.ended gate, the LOCAL evaluateEndConditions caches a
      -- gameOverClock the moment the local engine sees teams_active=1, which
      -- freezes the survivor BEFORE the server confirms — a 3p FFA stuck-match
      -- bug where the last-alive player's stack stopped ticking and the
      -- server idle-timed them out.
      if self.ended and self.gameOverClock and self.gameOverClock < stack.clock then
        return false
      end
    end
  end

  -- In debug mode allow non-local player 2 to fall a certain number of frames behind
  if not stack.is_local and self.debug.vsFramesBehind > 0 and tableUtils.indexOf(self.stacks, stack) == 2 then
    -- Only stay behind if the game isn't over for the local player (=garbageTarget) yet
    if self.garbageTargets[2][1] and self.garbageTargets[2][1]:game_ended() == false then
      if stack.clock + self.debug.vsFramesBehind >= self.garbageTargets[2][1].clock then
        return false
      end
    end
  end

  -- and then the stack specific conditions in stack
  return stack:shouldRun(runsSoFar)
end

function Match:setCountdown(doCountdown)
  self.doCountdown = doCountdown
  self.rules.doCountdown = doCountdown
end

function Match:setAlwaysSaveRollbacks(save)
  self.alwaysSaveRollbacks = save
end

---@param engineVersion string
function Match:setEngineVersion(engineVersion)
  self.engineVersion = engineVersion
  for i, stack in ipairs(self.stacks) do
    stack.engineVersion = engineVersion
  end
end


---@param levelData LevelData
---@param isLocal boolean
---@param inputMethod InputMethod
---@param inputs string?
---@return Stack
function Match:createStackWithSettings(levelData, isLocal, inputMethod, inputs)
  local args = {
    which = #self.stacks + 1,
    levelData = levelData,
    is_local = isLocal,
    stackOverConditions = self.rules.stackOverConditions,
    stackWinConditions = self.rules.stackWinConditions,
    panelSource = self.panelSource,
    inputMethod = inputMethod,
    stackSetupModifications = self.rules.stackSetupModifications or {},
    engineVersion = self.engineVersion,
  }

  local stack = Stack(args)
  self.stacks[#self.stacks+1] = stack
  self.garbageTargets[#self.stacks] = {}
  self.garbageSources[stack] = {}
  if inputs then
    stack:receiveConfirmedInput(InputCompression.decompressInputString2(inputs))
  end

  return stack
end

---@param attackSettings table
---@param healthSettings table?
---@return SimulatedStack
function Match:createSimulatedStackWithSettings(attackSettings, healthSettings)
  local args = {
    which = #self.stacks + 1,
    is_local = true,
    stackOverConditions = self.rules.stackOverConditions,
    stackWinConditions = self.rules.stackWinConditions,
    attackSettings = attackSettings,
    healthSettings = healthSettings,
    engineVersion = self.engineVersion,
  }

  local simulatedStack = SimulatedStack(args)
  self.stacks[#self.stacks+1] = simulatedStack
  self.garbageTargets[#self.stacks] = {}
  self.garbageSources[simulatedStack] = {}

  return simulatedStack
end

---@param source BaseStack
---@param target BaseStack
function Match:addTarget(source, target)
  target.incomingGarbage.illegalStuffIsAllowed = source.outgoingGarbage.illegalStuffIsAllowed
  target.incomingGarbage.treatMetalAsCombo = source.outgoingGarbage.treatMetalAsCombo

  local index = tableUtils.indexOf(self.stacks, source)

  -- Reference equality only. tableUtils.contains uses deep_content_equal which
  -- recurses through every field of the stack — and stacks hold circular refs
  -- to other stacks via garbageTarget/garbageTargets, so deep equality blows
  -- the call stack as soon as a target list has 2+ entries (common in FFA).
  local targets = self.garbageTargets[index]
  local alreadyTarget = false
  for i = 1, #targets do
    if targets[i] == target then
      alreadyTarget = true
      break
    end
  end
  if not alreadyTarget then
    table.insert(targets, target)
  end

  local sources = self.garbageSources[target]
  local alreadySource = false
  for i = 1, #sources do
    if sources[i] == source then
      alreadySource = true
      break
    end
  end
  if not alreadySource then
    table.insert(sources, source)
  end
end

--- this function exists to allow repeated playback and rewind
--- by default taking data out of the rollback buffer removes it because users of that data might take it verbatim and change it later
--- that means when rewinding and then running forward again, there is a gap in rollback data at the frame where the rewind stopped
--- keeping all rewind data would be very inefficient as we'd be copying a ton of panel data every frame, often when it is not necessary
--- so instead only detect when we start running forward again
function Match:padRewindDataIfNeeded()
  if self.alwaysSaveRollbacks then
    for i, stack in ipairs(self.stacks) do
      if stack.clock == stack.lastRollbackFrame then
        stack:saveForRollback()
      end
    end
  end
end

-- Team-related methods

--- Sets the teams for this match
---@param teams Team[]
function Match:setTeams(teams)
  self.teams = teams
end

--- Sets the garbage distribution mode
---@param mode string "all" or "shared"
function Match:setGarbageMode(mode)
  self.garbageMode = mode
end

--- Sets up garbage targets based on team configuration and garbage mode
--- Must be called after setTeams and setGarbageMode, and after stacks are created
function Match:setupTeamGarbageTargets()
  if not self.teams then
    return
  end

  -- Initialize garbage targets for each stack
  for i = 1, #self.stacks do
    self.garbageTargets[i] = {}
    self.garbageSources[self.stacks[i]] = {}
  end

  -- Catch silent-zero-emit (garbageTargets stays empty for unknown modes).
  if self.garbageMode ~= "all" and self.garbageMode ~= "shared" then
    logger.warn(string.format(
      "Match:setupTeamGarbageTargets: unrecognized garbageMode '%s' — no garbage will flow this match (expected 'all' or 'shared')",
      tostring(self.garbageMode)))
  end

  if self.garbageMode == "all" then
    -- "All" mode: each player sends garbage to ALL enemies
    for i, stack in ipairs(self.stacks) do
      local enemyIndices = TeamUtils.getEnemyPlayerIndices(self.teams, i)
      for _, enemyIndex in ipairs(enemyIndices) do
        local enemyStack = self.stacks[enemyIndex]
        if enemyStack then
          self:addTarget(stack, enemyStack)
        end
      end
    end
  elseif self.garbageMode == "shared" then
    -- "Shared" mode: round-robin TARGETING. Senders with multiple enemies pick one
    -- enemy per attack instead of hitting all of them. Rotation is tracked per
    -- sender, so each player cycles independently through their living enemies.
    --
    -- Note: this only changes targeting, not output rate. Team members each retain
    -- their full per-player attack rate. For symmetric 2v2 that produces a balanced
    -- game (both teams have multi-target senders); for asymmetric 1v2 the solo will
    -- effectively deal 1× per tick while taking 2× from the team, since team members
    -- only have one enemy and bypass distributeGarbageToTargets entirely.
    self.teamGarbageState = {}
    for i = 1, #self.stacks do
      local enemyIndices = TeamUtils.getEnemyPlayerIndices(self.teams, i)
      self.teamGarbageState[i] = {
        currentTargetIndex = 1,
        enemyIndices = enemyIndices
      }
    end

    -- Set up the same target list as "all" mode here; the actual single-target
    -- selection happens at delivery time in Match:distributeGarbageToTargets.
    for i, stack in ipairs(self.stacks) do
      local enemyIndices = TeamUtils.getEnemyPlayerIndices(self.teams, i)
      for _, enemyIndex in ipairs(enemyIndices) do
        local enemyStack = self.stacks[enemyIndex]
        if enemyStack then
          self:addTarget(stack, enemyStack)
        end
      end
    end
  end
end

--- Returns the winning team (if any)
--- Returns nil if no winner yet, or if it's a draw
---@return Team|nil
function Match:getWinningTeam()
  if not self.teams then
    return nil
  end
  -- Use the same isDone() semantics as hasEnded: in live loose-sync, a dead
  -- remote stack has its game_over_clock set but stack.clock is pinned below
  -- it (the remote stopped sending inputs after the DeathEvent). Calling
  -- TeamUtils.getWinningTeam directly uses stack:game_ended() which stays
  -- false in that pinned state — so the dead remote team looks alive,
  -- multiple teams count as active, and the function returns nil (no
  -- winner). This breaks the survivor's "did my team win" report to the
  -- server (NetClient sends localGameResult=2/loss instead of 1/win).
  local liveMatch = not self.fromReplay
  local activeTeams = {}
  for _, team in ipairs(self.teams) do
    local teamAlive = false
    for _, playerIndex in ipairs(team.playerIndices) do
      local stack = self.stacks[playerIndex]
      if stack then
        local done = (liveMatch and stack.game_over_clock and stack.game_over_clock > 0)
          or stack:game_ended()
        if not done then
          teamAlive = true
          break
        end
      end
    end
    if teamAlive then
      activeTeams[#activeTeams + 1] = team
    end
  end
  if #activeTeams == 1 then
    return activeTeams[1]
  end
  return nil
end

return Match