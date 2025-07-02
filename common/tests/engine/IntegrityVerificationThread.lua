require("love.math")
require("love.timer")
require("client.src.globals")
require("common.lib.mathExtensions")
local util = require("common.lib.util")
util.addToCPath("./common/lib/??")
local tableUtils = require("common.lib.tableUtils")
local fileUtils = require("client.src.FileUtils")
local ReplayV3 = require("common.data.ReplayV3")
local Match = require("common.engine.Match")
local logger = require("common.lib.logger")
local f = function() end
logger.trace = f
logger.debug = f
logger.info = f

local filePaths, versionOverride = ...

---@param replay ReplayV3
---@return boolean success
---@return integer winnerIndex
---@return integer matchClock
---@return integer expectedDuration
local function verifyReplay(replay)
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

local function loadReplay(filePath, versionOverride)
  local replayTable = fileUtils.readJsonFile(filePath)
  if not replayTable then
    love.thread.getChannel("verificationResult"):push({filePath = filePath, message = "Failed to read file"})
  else
    if versionOverride then
      -- server replays did not save version number until late v047 and the internal processor assumes v046 in that case which may be wrong
      -- so we can override to correct the used engine version here
      replayTable.engineVersion = versionOverride
    end
    local replay = ReplayV3.createFromTable(replayTable, true)
    if not replay then
      love.thread.getChannel("verificationResult"):push({filePath = filePath, message = "Failed to create replay"})
    elseif not replay.metadata.incomplete then
      return replay
    end
  end
end

for i, filePath in ipairs(filePaths) do
  local replay = loadReplay(filePath, versionOverride)
  if replay then
    local verified, winnerIndex, clock, expectedDuration = verifyReplay(replay)
    love.thread.getChannel("verificationResult"):push({verified = verified,
                                              winnerIndex = winnerIndex,
                                              expectedWinnerIndex = (replay.metadata.winnerIndex or "unknown"),
                                              clock = clock,
                                              expectedDuration = expectedDuration,
                                              filePath = filePath})
  end
end