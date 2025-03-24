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

---@class Match
---@field stacks (Stack | SimulatedStack)[] The stacks to run as part of the match
---@field garbageTargets table<integer, table<integer, Stack>> assignments by index where each stack's garbage is directed
---@field garbageSources table<Stack, table<integer, Stack>> assignments by index where each stack's incoming garbage comes from
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
  self.startTimestamp = os.time(os.date("*t"))
  self.clock = 0
  self.ended = false
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
              if #potentialWinner:getConfirmedInputCount() < #potentialWinners[k]:getConfirmedInputCount() then
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

---@param stack BaseStack
function Match:pushGarbageTo(stack)
  -- check if anyone wants to push garbage into the stack's queue
  for _, st in ipairs(self.garbageSources[stack]) do
    local oldestTransitTime = st:getOldestFinishedGarbageTransitTime()
    if oldestTransitTime then
      if stack.clock > oldestTransitTime then
        -- recipient went past the frame it was supposed to receive the garbage -> rollback to that frame
        -- hypothetically, IF the receiving stack's garbage target was different than the sender forcing the rollback here
        --  it may be necessary to perform extra steps to ensure the recipient of the stack getting rolled back is getting correct garbage
        --  which may even include another rollback
        if not self:rollbackToFrame(stack, oldestTransitTime) then
          -- if we can't rollback, it's a desync
          self:abort()
        end
      end
      local garbageDelivery = st:getReadyGarbageAt(stack.clock)
      if garbageDelivery then
        --logger.debug("Pushing garbage delivery to incoming garbage queue: " .. table_to_string(garbageDelivery))
        stack:receiveGarbage(garbageDelivery)
      end
    end
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
          if self.stacks[senderIndex].clock + GARBAGE_DELAY_LAND_TIME <= stack.clock then
            return true
          end
        end
      end
    end

    return false
  end
end

-- attempt to rollback the specified stack to the specified frame
---@param stack BaseStack
---@param frame integer
---@return boolean success
function Match:rollbackToFrame(stack, frame)
  if stack:rollbackToFrame(frame) then
    return true
  end

  return false
end

-- rewind is ONLY to be used for replay playback as it relies on all stacks being at the same clock time
-- and also uses slightly different data required only in a both-sides rollback scenario that would never occur for online rollback
---@param frame integer
function Match:rewindToFrame(frame)
  local failed = false
  for i, stack in ipairs(self.stacks) do
    if not stack:rewindToFrame(frame) then
      failed = true
      break
    end
  end
  if not failed then
    self.clock = frame
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
    info.stacks[i] = stack:getInfo()
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
        inputs = InputCompression.compressInputString(table.concat(stack.confirmedInput))
      }
      replay.stacks[i] = replayStack
    elseif stack.TYPE == "SimulatedStack" then
      ---@cast stack SimulatedStack
      ---@type ReplaySimulatedStack
      local replayStack = {
        stackType = 2,
        attackSettings = stack:getAttackPatternData(),
        healthSettings = stack.healthEngine:getSettings()
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
    for _, recipientIndex in ipairs(garbageFlow.recipients) do
      local recipientStack = match.stacks[recipientIndex]
      table.insert(match.garbageTargets[garbageFlow.source], recipientStack)
      table.insert(match.garbageSources[recipientStack], match.stacks[garbageFlow.source])
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

---@return boolean
function Match:hasEnded()
  if self.ended then
    return true
  end

  if self.aborted then
    self.ended = true
    return true
  end

  local aliveCount = 0
  -- dead is more like done as the stack could also have ended by fulfilling a win condition
  local deadCount = 0
  for i = 1, #self.stacks do
    if self.stacks[i]:game_ended() then
      deadCount = deadCount + 1
    else
      aliveCount = aliveCount + 1
    end
  end

  if self.rules.matchEndConditions[MatchRules.MatchEndConditions.STACKS_ACTIVE] then
    if aliveCount == self.rules.matchEndConditions[MatchRules.MatchEndConditions.STACKS_ACTIVE] then
      local gameOverClock = 0
      for i = 1, #self.stacks do
        if self.stacks[i].game_over_clock > gameOverClock then
          gameOverClock = self.stacks[i].game_over_clock
        end
      end
      self.gameOverClock = gameOverClock
      -- make sure everyone has run to the currently known game over clock
      -- because if they haven't they might still go gameover before that time
      -- > instead of >= because game over clock is set to the frame it was running when it died but increments only at the end of the frame
      -- so a stack running to gameOverClock won't have found out it's dying on the next frame
      if tableUtils.trueForAll(self.stacks, function(stack) return stack.clock and stack.clock > gameOverClock end) then
        self.ended = true
        return true
      end
    end
  end

  if deadCount == #self.stacks then
    -- everyone died, match is over!
    self.ended = true
    return true
  end

  if self.timeLimit then
    if tableUtils.trueForAll(self.stacks, function(stack) return stack.game_stopwatch and stack.game_stopwatch >= self.timeLimit end) then
      self.ended = true
      return true
    end
  end

  if self:isIrrecoverablyDesynced() then
    logger.info("Match irrecoverably desynced")
    self.ended = true
    self.aborted = true
    self.desyncError = true
    return true
  end

  return false
end

function Match:handleMatchEnd()
  self:checkAborted()

  if self.aborted then
    self.winners = {}
  else
    self.winners = self:getWinners()
  end
end

---@return boolean
function Match:isIrrecoverablyDesynced()
  for target, sourceArray in pairs(self.garbageSources) do
    for i, source in ipairs(sourceArray) do
      if source.clock + MAX_LAG < target.clock then
        return true
      end
    end
  end

  return false
end

-- a local function to avoid creating a closure every frame
local checkGameEnded = function(stack)
  return stack:game_ended()
end

local TOTAL_COUNTDOWN_LENGTH = consts.COUNTDOWN_LENGTH + consts.COUNTDOWN_START

---@return boolean hasAborted
function Match:checkAborted()
  -- the aborted flag may get set if the game is aborted through outside causes (usually network)
  -- this function checks if the match got aborted through inside causes (local player abort or local desync)
  if not self.aborted then
    if self:isIrrecoverablyDesynced() then
      -- someone got a desync error, this definitely died
      self.aborted = true
      self.winners = {}
    elseif self.rules.matchEndConditions[MatchRules.MatchEndConditions.STACKS_ACTIVE] then
      local alive = 0
      for i = 1, #self.stacks do
        if not self.stacks[i]:game_ended() then
          alive = alive + 1
        end
        -- if there is more than n alive with a stacksActive condition, this must have been aborted
        if alive > self.rules.matchEndConditions[MatchRules.MatchEndConditions.STACKS_ACTIVE] then
          self.aborted = true
          self.winners = {}
          break
        end
      end
    elseif self.rules.matchEndConditions[MatchRules.MatchEndConditions.TIME_LIMIT] then
      local timeLimit = self.timeLimit
      if self.doCountdown then
        timeLimit = timeLimit + TOTAL_COUNTDOWN_LENGTH
      end
      for i, stack in ipairs(self.stacks) do
        if not stack:game_ended() and stack.clock < timeLimit then
          self.aborted = true
          self.winners = {}
          break
        end
      end
    else
      -- if this is not last alive and no desync that means we expect EVERY stack to be game over
      if not tableUtils.trueForAll(self.stacks, checkGameEnded) then
        -- someone didn't lose so this got aborted (e.g. through a pause -> leave)
        self.aborted = true
        self.winners = {}
      end
    end
  end

  return self.aborted
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
      if stack.game_stopwatch and stack.game_stopwatch >= self.timeLimit then
        -- the stack should only run 1 frame beyond the time limit (excluding countdown)
        return false
      end
    else
      -- gameOverClock is set in Match:hasEnded when there is only 1 alive in LAST_ALIVE modes
      if self.gameOverClock and self.gameOverClock < stack.clock then
        return false
      end
    end
  end

  -- In debug mode allow non-local player 2 to fall a certain number of frames behind
  if config.debug_mode and not stack.is_local and config.debug_vsFramesBehind and config.debug_vsFramesBehind > 0 and tableUtils.indexOf(self.stacks, stack) == 2 then
    -- Only stay behind if the game isn't over for the local player (=garbageTarget) yet
    if self.garbageTargets[2][1] and self.garbageTargets[2][1].game_ended and self.garbageTargets[2][1]:game_ended() == false then
      if stack.clock + config.debug_vsFramesBehind >= self.garbageTargets[2][1].clock then
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
    stack:receiveConfirmedInput(InputCompression.decompressInputString(inputs))
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
  local index = tableUtils.indexOf(self.stacks, source)

  if not tableUtils.contains(self.garbageTargets[index], target) then
    table.insert(self.garbageTargets[index], target)
  end

  if not tableUtils.contains(self.garbageSources[target], source) then
    table.insert(self.garbageSources[target], source)
  end
end

return Match