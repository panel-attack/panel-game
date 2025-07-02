-- a bulk processor for replays 
-- all  replays that do not finish correctly with the current engine are copied into a separate directory

local util = require("common.lib.util")
local tableUtils = require("common.lib.tableUtils")

local verifier = { faulty = {}, processed = 0, framesProcessed = 0}

function verifier.overrideEngineVersion(version)
  verifier.versionOverride = version
end

function verifier.initializeThreads(threadCount)
  verifier.pathsPerThread = {}
  verifier.threads = {}
  verifier.threadCount = threadCount
  for i = 1, verifier.threadCount do
    verifier.threads[i] = love.thread.newThread("common/tests/engine/IntegrityVerificationThread.lua")
    verifier.pathsPerThread[i] = {}
  end
end

function verifier.pollMessages()
  local polledAny = false
  for i = 1, verifier.threadCount do
    local message = love.thread.getChannel("verificationResult"):pop()
    if message then
      polledAny = true
      verifier.processed = verifier.processed + 1
      if message.verified == nil then
        verifier.faulty[#verifier.faulty+1] = { path = message.filePath, reason = message.message }
      else
        verifier.framesProcessed = verifier.framesProcessed + message.clock
        if message.verified == false then
          verifier.faulty[#verifier.faulty+1] = {
            path = message.filePath,
            reason = "Replay stopped running at " .. message.clock .. " with winner " .. message.winnerIndex
                ..   " but should have stopped at " .. message.expectedDuration .. " with winner " .. message.expectedWinnerIndex
          }
        else
          -- verification can run for a very long time so removing verified files prevents us from checking dupes if running in parts     
          love.filesystem.remove(message.filePath)
        end
      end
    end
  end

  return polledAny
end

-- naive strategy: give each thread the same count of replays
-- on the tail end some threads will be faster than the others but with enough replays it should average out and take a negligible amount of extra time
function verifier.populatePerThreadFileLists(replayPath, startIndex)
  local j = startIndex or 1
  local items = love.filesystem.getDirectoryItems(replayPath)
  for i, item in ipairs(items) do
    local filePath = replayPath .. "/" .. item
    local fileInfo = love.filesystem.getInfo(filePath)
    if fileInfo.type == "directory" then
      j = verifier.populatePerThreadFileLists(filePath, j)
    elseif fileInfo.type == "file" then
      verifier.pathsPerThread[j][#verifier.pathsPerThread[j] + 1] = filePath
      j = wrap(1, j + 1, verifier.threadCount)
    end
  end
  return j
end

function verifier.asyncBulkVerifyReplays(replayPath, threadCount)
  verifier.initializeThreads(threadCount)
  verifier.populatePerThreadFileLists(replayPath)
  for i = 1, verifier.threadCount do
    verifier.threads[i]:start(verifier.pathsPerThread[i], verifier.versionOverride)
  end
end

local function threadIsRunning(t)
  return t:isRunning()
end

function verifier.hasFinished()
  return not tableUtils.trueForAny(verifier.threads, threadIsRunning)
end

-- ---@param replay ReplayV3
-- ---@return boolean success
-- ---@return integer winnerIndex
-- ---@return integer matchClock
-- ---@return integer expectedDuration
-- function verifier.verifyReplay(replay)
--   local match = Match.createFromReplay(replay)
--   -- probably a lot faster without rollback
--   match:setAlwaysSaveRollbacks(false)
--   match:start()

--   local expectedDuration = replay.metadata.duration
--   if not expectedDuration then
--     -- if duration did not save somehow, get it from the decompressed inputs
--     -- in local replays the input counts may differ so pick the lowest input count as when losing locally, the opponent keeps playing until simulating your loss
--     for _, stack in ipairs(match.stacks) do
--       if stack.TYPE == "Stack" then
--         ---@cast stack Stack
--         if expectedDuration then
--           expectedDuration = math.min(expectedDuration, #stack.confirmedInput)
--         else
--           expectedDuration = #stack.confirmedInput
--         end
--       end
--     end
--   end
--   ---@cast expectedDuration integer

--   -- the extra clock safeguards against getting stuck if for some reason the match fails to advance to the end
--   local clock = 0
--   while not match:hasEnded() and clock < expectedDuration * 2 do
--     clock = clock + 1
--     match:run()
--   end

--   match:handleMatchEnd()

--   for _, stack in ipairs(match.stacks) do
--     if stack.TYPE == "Stack" then
--       ---@cast stack Stack
--       stack:deinit()
--     end
--   end

--   -- winners is always a table with at least 1 player (2 in case of a tie)
--   -- it being empty signifies the match never finished
--   if match.winners == nil then
--     return false, 0, match.clock, expectedDuration
--   end

--   if not match.gameOverClock or (match.gameOverClock + 1 < expectedDuration) then
--     return false, tableUtils.indexOf(match.stacks, match.winners[1]), match.clock, expectedDuration
--   end

--   if replay.metadata.winnerIndex and replay.metadata.winnerIndex ~= tableUtils.indexOf(match.stacks, match.winners[1]) then
--     return false, tableUtils.indexOf(match.stacks, match.winners[1]), match.clock, expectedDuration
--   end

--   -- is there another check necessary?

--   return true, tableUtils.indexOf(match.stacks, match.winners[1]), match.clock, expectedDuration
-- end

return verifier