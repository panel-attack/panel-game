local class = require("common.lib.class")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local GameModes = require("common.engine.GameModes")
local Replay = require("common.data.Replay")
local SimulatedStack = require("common.engine.SimulatedStack")
local Stack = require("common.engine.Stack")
require("common.engine.checkMatches")
local consts = require("common.engine.consts")

---@class Match
---@field stacks table<integer, Stack> The stacks to run as part of the match
---@field garbageTargets table<integer, table<integer, Stack>> assignments by index where each stack's garbage is directed
---@field garbageSources table<Stack, table<integer, Stack>> assignments by index where each stack's incoming garbage comes from
---@field engineVersion string
---@field doCountdown boolean if a countdown is performed at the start of the match
---@field stackInteraction integer how the stacks in the match interact with each other
---@field winConditions integer[] enumerated conditions to determine a winner between multiple stacks
---@field gameOverConditions integer[] enumerated conditions for Stacks to go game over
---@field timeLimit integer? if the game automatically ends after a certain time
---@field puzzle table
---@field seed integer The seed to be used for PRNG
---@field startTimestamp integer
---@field createTime number
---@field timeSpentRunning number
---@field maxTimeSpentRunning number
---@field clock integer
---@field ended boolean

-- A match is a particular instance of the game, for example 1 time attack round, or 1 vs match
---@class Match
---@overload fun(stacks: Stack[], doCountdown: boolean, stackInteraction: StackInteractions, winConditions: MatchWinConditions[], gameOverCondition: GameOverConditions[], optionalArgs: table?): Match
local Match = class(
function(self, stacks, doCountdown, stackInteraction, winConditions, gameOverConditions, optionalArgs)
  self.stacks = stacks
  self.garbageTargets = {}
  self.garbageSources = {}
  self.engineVersion = consts.ENGINE_VERSION

  assert(doCountdown ~= nil)
  assert(stackInteraction)
  assert(winConditions)
  assert(gameOverConditions)
  self.doCountdown = doCountdown
  self.stackInteraction = stackInteraction
  self.winConditions = winConditions
  self.gameOverConditions = gameOverConditions
  if tableUtils.contains(gameOverConditions, GameModes.GameOverConditions.TIME_OUT) then
    assert(optionalArgs.timeLimit)
    self.timeLimit = optionalArgs.timeLimit
  end
  if optionalArgs then
    -- debatable if these couldn't be player settings instead
    self.puzzle = optionalArgs.puzzle
  end

  self.timeSpentRunning = 0
  self.maxTimeSpentRunning = 0
  self.createTime = love.timer.getTime()
  self.seed = math.random(1,9999999)
  self.startTimestamp = os.time(os.date("*t"))
  self.clock = 0
  self.ended = false
end
)

-- returns the players that won the match in a table
-- returns a single winner if there was a clear winner
-- returns multiple winners if there was a tie (or the game mode had no win conditions)
-- returns an empty table if there was no winner due to the game not finishing / getting aborted
-- the function caches the result of the first call so it should only be called when the match has ended
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
    for i = 1, #self.winConditions do
      local metCondition = {}
      local winCon = self.winConditions[i]
      for j = 1, #potentialWinners do
        local potentialWinner = potentialWinners[j]
        -- now we check for this stack whether they meet the current winCondition
        if winCon == GameModes.WinConditions.LAST_ALIVE then
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
        elseif winCon == GameModes.WinConditions.SCORE then
          local hasHighestScore = true
          for k = 1, #potentialWinners do
            if k ~= j then
              -- only if someone else has a higher score than me do I lose
              -- makes sure to cover score ties
              if potentialWinner.engine.score < potentialWinners[k].engine.score then
                hasHighestScore = false
                break
              end
            end
          end
          if hasHighestScore then
            table.insert(metCondition, potentialWinner)
          end
        elseif winCon == GameModes.WinConditions.TIME then
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
        elseif winCon == GameModes.WinConditions.NO_MATCHABLE_PANELS then
        elseif winCon == GameModes.WinConditions.NO_MATCHABLE_GARBAGE then
          -- both of these are positive game-ending conditions on the stack level
          -- should rethink these when looking at puzzle vs (if ever)
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
  --     assert(#stack.input_buffer == 0, "Local games should always simulate all inputs")
  --   end
  -- end

  local endTime = love.timer.getTime()
  local timeDifference = endTime - startTime
  self.timeSpentRunning = self.timeSpentRunning + timeDifference
  self.maxTimeSpentRunning = math.max(self.maxTimeSpentRunning, timeDifference)

  return runs
end

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
        logger.debug("Pushing garbage delivery to incoming garbage queue: " .. table_to_string(garbageDelivery))
        stack:receiveGarbage(garbageDelivery)
      end
    end
  end
end

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
-- return true if successful
-- return false if not
function Match:rollbackToFrame(stack, frame)
  if stack:rollbackToFrame(frame) then
    return true
  end

  return false
end

-- rewind is ONLY to be used for replay playback as it relies on all stacks being at the same clock time
-- and also uses slightly different data required only in a both-sides rollback scenario that would never occur for online rollback
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
  local allowAdjacentColorsOnStartingBoard = tableUtils.trueForAll(self.stacks, function(stack) return stack.allowAdjacentColors end)
  local shockEnabled = (self.stackInteraction ~= GameModes.StackInteractions.NONE)

  for i, stack in ipairs(self.stacks) do
    stack:setCountdown(self.doCountdown)
    if stack.TYPE == "Stack" then
      stack:setAllowAdjacentColorsOnStartingBoard(allowAdjacentColorsOnStartingBoard)
      stack:enableShockPanels(shockEnabled)
      stack.seed = self.seed
    end
    self.garbageTargets[i] = {}
    self.garbageSources[stack] = {}
  end

  if self.stackInteraction == GameModes.StackInteractions.SELF then
    for i, stack in ipairs(self.stacks) do
      table.insert(self.garbageTargets[i], stack)
      table.insert(self.garbageSources[stack], stack)
    end
  elseif self.stackInteraction == GameModes.StackInteractions.VERSUS then
    for i = 1, #self.stacks do
      for j = 1, #self.stacks do
        if i ~= j then
          -- needs to be reworked for more than 2P in a single game
          table.insert(self.garbageTargets[i], self.stacks[j])
          table.insert(self.garbageSources[self.stacks[j]], self.stacks[i])
        end
      end
    end
  elseif self.stackInteraction == GameModes.StackInteractions.ATTACK_ENGINE then
    for i, stack1 in ipairs(self.stacks) do
      for j, stack2 in ipairs(self.stacks) do
        if i ~= j then
          -- needs to be reworked for more than 2P in a single game
          if stack1.TYPE == "Stack" and stack2.TYPE == "SimulatedStack" then
            table.insert(self.garbageTargets[j], self.stacks[i])
            table.insert(self.garbageSources[self.stacks[i]], self.stacks[j])
          end
        end
      end
    end
  end

  for i, stack in ipairs(self.stacks) do
    if false then
      -- puzzles are currently set directly on the player's stack
    else
      stack:starting_state()
      -- always need clock 0 as a base for rollback
      stack:saveForRollback()
    end
  end
end

---@param seed integer?
function Match:setSeed(seed)
  if seed then
    self.seed = seed
  end
end

---@return Replay
function Match:createNewReplay()
  local replay = Replay(self.engineVersion, self.seed, self, self.puzzle)

  for i, stack in ipairs(self.stacks) do
    if self.stackInteraction == GameModes.StackInteractions.ATTACK_ENGINE then
      -- only add the non-attack engines as the settings remain on the player
      if stack.TYPE == "Stack" then
        replay:updatePlayer(i, stack:toReplayPlayer())
      end
    else
      replay:updatePlayer(i, stack:toReplayPlayer())
    end
  end

  return replay
end

---@param replay Replay
---@return Match
function Match.createFromReplay(replay)
  local optionalArgs = {
    timeLimit = replay.gameMode.timeLimit,
    puzzle = replay.gameMode.puzzle,
  }

  local stacks = {}

  for i = 1, #replay.players do
    if replay.players[i].human then
      stacks[i] = Stack.createFromReplayPlayer(replay.players[i], replay)
    else
      stacks[i] = SimulatedStack.createFromReplayPlayer(replay.players[i], replay)
    end
  end

  local match = Match(
    stacks,
    replay.gameMode.doCountdown,
    replay.gameMode.stackInteraction,
    replay.gameMode.winConditions,
    replay.gameMode.gameOverConditions,
    optionalArgs
  )

  match:setSeed(replay.seed)
  match.engineVersion = replay.engineVersion
  match:setAlwaysSaveRollbacks(replay.completed)

  return match
end

function Match:abort()
  self.ended = true
  self.aborted = true
  self:handleMatchEnd()
end

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

  if tableUtils.contains(self.winConditions, GameModes.WinConditions.LAST_ALIVE) then
    if aliveCount == 1 then
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
    if tableUtils.trueForAll(self.stacks, function(stack) return stack.game_stopwatch and stack.game_stopwatch >= self.timeLimit * 60 end) then
      self.ended = true
      return true
    end
  end

  if self:isIrrecoverablyDesynced() then
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

function Match:checkAborted()
  -- the aborted flag may get set if the game is aborted through outside causes (usually network)
  -- this function checks if the match got aborted through inside causes (local player abort or local desync)
  if not self.aborted then
    if self:isIrrecoverablyDesynced() then
      -- someone got a desync error, this definitely died
      self.aborted = true
      self.winners = {}
    elseif tableUtils.contains(self.winConditions, GameModes.WinConditions.LAST_ALIVE) then
      local alive = 0
      for i = 1, #self.stacks do
        if not self.stacks[i]:game_ended() then
          alive = alive + 1
        end
        -- if there is more than 1 alive with a last alive win condition, this must have been aborted
        if alive > 1 then
          self.aborted = true
          self.winners = {}
          break
        end
      end
    elseif tableUtils.contains(self.gameOverConditions, GameModes.GameOverConditions.TIME_OUT) then
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
function Match:shouldRun(stack, runsSoFar)
  -- check the match specific conditions in match
  if not stack:game_ended() then
    if self.timeLimit then
      if stack.game_stopwatch and stack.game_stopwatch >= self.timeLimit * 60 then
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
  if config.debug_mode and not stack.is_local and config.debug_vsFramesBehind and config.debug_vsFramesBehind > 0 and stack.which == 2 then
    -- Only stay behind if the game isn't over for the local player (=garbageTarget) yet
    if stack.garbageTarget and stack.garbageTarget.game_ended and stack.garbageTarget:game_ended() == false then
      if stack.clock + config.debug_vsFramesBehind >= stack.garbageTarget.clock then
        return false
      end
    end
  end

  -- and then the stack specific conditions in stack
  return stack:shouldRun(runsSoFar)
end

function Match:setCountdown(doCountdown)
  self.doCountdown = doCountdown
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

return Match