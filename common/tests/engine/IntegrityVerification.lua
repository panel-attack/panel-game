-- a bulk processor for replays 
-- all  replays that do not finish correctly with the current engine are copied into a separate directory

local util = require("common.lib.util")
local fileUtils = require("client.src.FileUtils")
local tableUtils = require("common.lib.tableUtils")
local verification = require("common.tests.engine.IntegrityVerificationSingle")

local verifier = { faulty = {}, processed = 0, framesProcessed = 0}

function verifier.overrideEngineVersion(version)
  verifier.versionOverride = version
end

---@param threadCount integer
function verifier.initializeThreads(threadCount)
  verifier.pathsPerThread = {}
  verifier.threads = {}
  verifier.threadCount = threadCount
  for i = 1, verifier.threadCount do
    verifier.threads[i] = love.thread.newThread("common/tests/engine/IntegrityVerificationThread.lua")
    verifier.pathsPerThread[i] = {}
  end
end

---@return boolean # if any messages were processed
function verifier.pollMessages()
  local polledAny = false
  local message = love.thread.getChannel("verificationResult"):pop()
  while message do
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
    message = love.thread.getChannel("verificationResult"):pop()
  end

  return polledAny
end

-- naive strategy: give each thread the same count of replays
-- on the tail end some threads will be faster than the others but with enough replays it should average out and take a negligible amount of extra time
---@param replayPath string the directory containing all replays to be processed, traversed recursively
---@param startIndex integer? the index to assign the next filePath to, defaults to 1
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

---@param replayPath string the directory containing all replays to be processed, traversed recursively
---@param threadCount integer? default 3 <br>
--- higher thread counts observe strongly diminishing returns on speed, probably because the CPU starts to get cache misses with too many threads <br>
--- reference values for my machine, assume 1 thread = 100% speed <br>
--- 2 threads = ~175% speed <br>
--- 3 threads = ~235% speed <br>
--- 4 threads = ~215% speed <br>
--- 5 threads = ~250% speed <br>
--- 8 threads = ~270% speed <br>
--- this likely varies with load, the assumption is that more than 3 threads start to overtax CPU cache and the more threads the more cache misses you'll get <br>
--- my CPU has 8MB L2 cache and 32MB L3 cache for reference
function verifier.asyncBulkVerifyReplays(replayPath, threadCount)
  verifier.initializeThreads(threadCount or 3)
  verifier.populatePerThreadFileLists(replayPath)
  for i = 1, verifier.threadCount do
    verifier.threads[i]:start(verifier.pathsPerThread[i], verifier.versionOverride)
  end
end

local function threadIsRunning(t)
  return t:isRunning()
end

---@return boolean
function verifier.hasFinished()
  return not tableUtils.trueForAny(verifier.threads, threadIsRunning)
end

function verifier.cancelBulkVerification()
  love.thread.getChannel("stop"):push("stop")
  while not verifier.hasFinished() do
  end
  -- make sure to poll any remaining results
  verifier.pollMessages()
end

--- verifies a single replay; does not delete the file regardless of result
---@param filePath string
---@param versionOverride string?
function verifier.verifyReplay(filePath, versionOverride)
  local jsonTable = fileUtils.readJsonFile(filePath)
  if not jsonTable then
    verifier.faulty[#verifier.faulty + 1] = { path = filePath, reason = "Failed to read json" }
    return
  end

  local replay = verification.loadReplay(jsonTable, versionOverride)
  if not replay then
    verifier.faulty[#verifier.faulty + 1] = { path = filePath, reason = "Failed to load replay" }
    return
  end

  local verified, winnerIndex, clock, expectedDuration = verification.verifyReplay(replay)
  if not verified then
    verifier.faulty[#verifier.faulty+1] = {
      path = filePath,
      reason = "Replay stopped running at " .. clock .. " with winner " .. winnerIndex
          ..   " but should have stopped at " .. expectedDuration .. " with winner " .. (replay.metadata.winnerIndex or "Unknown")
    }
  end
end

return verifier