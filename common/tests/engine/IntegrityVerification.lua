-- a bulk processor for replays 
-- all  replays that do not finish correctly with the current engine are copied into a separate directory

local fileUtils = require("client.src.FileUtils")
local ReplayV3 = require("common.data.ReplayV3")
local Match = require("common.engine.Match")
local tableUtils = require("common.lib.tableUtils")
local system = require("client.src.system")
local utf8 = require("common.lib.utf8Additions")

local verifier = { faulty = {}, processed = 0, framesProcessed = 0}

function verifier.overrideEngineVersion(version)
  verifier.versionOverride = version
end

function verifier.bulkVerifyReplays(replayPath, outputPath)
  local items = love.filesystem.getDirectoryItems(replayPath)
  for i, item in ipairs(items) do
    local filePath = replayPath .. "/" .. item
    local fileInfo = love.filesystem.getInfo(filePath)
    if fileInfo.type == "directory" then
      verifier.bulkVerifyReplays(filePath, outputPath)
    elseif fileInfo.type == "file" then
      local replayTable = fileUtils.readJsonFile(filePath)
      -- server replays do not save version number and the internal processor assumes v046 in that case which may be wrong
      -- so we can override to correct the used engine version here
      if verifier.versionOverride then
        replayTable.engineVersion = verifier.versionOverride
      end
      if replayTable then
        local replay = ReplayV3.createFromTable(replayTable, true)
        if not replay then
          -- not sure, probably error or use a separate dir in the output path?
          error("Failed to create replay from file " .. filePath)
        else
          -- we can only really make statements about replays that finished running
          if not replay.metadata.incomplete then
            local verified, winnerIndex, clock, expectedDuration = verifier.verifyReplay(replay)
            if not verified then
              verifier.faulty[#verifier.faulty+1] = {
                path = item,
                reason = "Replay stopped running at " .. clock .. " with winner " .. winnerIndex
                    ..   " but should have stopped at " .. expectedDuration .. " with winner " .. (replay.metadata.winnerIndex or "unknown")
              }
              fileUtils.writeJson(outputPath, item, replayTable)
            end

            -- verification can run for a very long time so removing files prevents us from checking dupes if running in parts
            love.filesystem.remove(filePath)

            verifier.processed = verifier.processed + 1
            verifier.framesProcessed = verifier.framesProcessed + clock
            coroutine.yield()
          end
        end
      end
    end
  end
end

---@param replay ReplayV3
---@return boolean success
---@return integer winnerIndex
---@return integer matchClock
---@return integer expectedDuration
function verifier.verifyReplay(replay)
  local match = Match.createFromReplay(replay)
  -- probably a lot faster without rollback
  match:setAlwaysSaveRollbacks(false)
  match:start()

  local expectedDuration = replay.metadata.duration
  if not expectedDuration then
    -- if duration did not save somehow, get it from the decompressed inputs
    -- in local replays the input counts may differ so pick the lowest input count as when losing locally, the opponent keeps playing until simulating your loss
    for _, stack in ipairs(match.stacks) do
      if stack.TYPE == "Stack" then
        ---@cast stack Stack
        if expectedDuration then
          expectedDuration = math.min(expectedDuration, #stack.confirmedInput)
        else
          expectedDuration = #stack.confirmedInput
        end
      end
    end
  end
  ---@cast expectedDuration integer

  -- the extra clock safeguards against getting stuck if for some reason the match fails to advance to the end
  local clock = 0
  while not match:hasEnded() and clock < expectedDuration * 2 do
    clock = clock + 1
    match:run()
  end

  match:handleMatchEnd()

  for _, stack in ipairs(match.stacks) do
    if stack.TYPE == "Stack" then
      ---@cast stack Stack
      stack:deinit()
    end
  end

  -- winners is always a table with at least 1 player (2 in case of a tie)
  -- it being empty signifies the match never finished
  if match.winners == nil then
    return false, 0, match.clock, expectedDuration
  end

  if not match.gameOverClock or (match.gameOverClock + 1 < expectedDuration) then
    return false, tableUtils.indexOf(match.stacks, match.winners[1]), match.clock, expectedDuration
  end

  if replay.metadata.winnerIndex and replay.metadata.winnerIndex ~= tableUtils.indexOf(match.stacks, match.winners[1]) then
    return false, tableUtils.indexOf(match.stacks, match.winners[1]), match.clock, expectedDuration
  end

  -- is there another check necessary?

  return true, tableUtils.indexOf(match.stacks, match.winners[1]), match.clock, expectedDuration
end

return verifier