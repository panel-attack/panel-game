--[[
the purpose of this file is to make the verification process easily accessible to both a thread but also a main process debugging process
that is because sometimes verification will flag results that most certainly look like false positives
e.g.
"Replay stopped running at 2129 with winner 2 but should have stopped at 2129 with winner 2"
in that case it makes more sense to first look why the verification flagged it to either
a) fix the verification process
or
b) figure out what to look for and improve the output of the verification so that it does not look like a false positive

this is a separate file because of the restrictions on value types that can be passed into threads on start up:
https://love2d.org/wiki/Variant
so we can't pass functions or a table with functions but with it being a file the thread can just require it
]]

require("client.src.globals")
require("common.lib.mathExtensions")
local tableUtils = require("common.lib.tableUtils")
local ReplayV3 = require("common.data.ReplayV3")
local Match = require("common.engine.Match")

local singleVerification = {}

---@param replay ReplayV3
---@return boolean success
---@return integer winnerIndex
---@return integer matchClock
---@return integer expectedDuration
function singleVerification.verifyReplay(replay)
  local match = Match.createFromReplay(replay)
  -- probably a lot faster without rollback
  match:setAlwaysSaveRollbacks(false)
  match:start()
  for _, stack in ipairs(match.stacks) do
    -- we can get different input counts, make sure we don't overshoot game over if one player had more inputs than the other
    stack:setMaxRunsPerFrame(1)
  end

  local expectedDuration = replay.metadata.duration
  if not expectedDuration then
    -- if duration did not save somehow, get it from the decompressed inputs
    -- the input counts may differ between players as when losing locally, the opponent keeps playing until simulating your loss
    --  so pick the lowest input count
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

  -- to populate match.winners
  match:handleMatchEnd()

  -- this might be overkill with rollback already being disabled but the clock 0 rollback still always happens
  -- which means the internal memory buffer for panels is used up after ~300 replays and then we need to create tables all the time, putting more strain on the GC
  -- so putting them back each time means less GC traffic for bulk operations, likely causing a speed increase
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

---@param jsonTable table
---@param versionOverride string?
---@return ReplayV3?
function singleVerification.loadReplay(jsonTable, versionOverride)
  if jsonTable then
    if versionOverride then
      -- server replays did not save version number until late v047 and the internal processor assumes v046 in that case which may be wrong
      -- so we can override to correct the used engine version here
      jsonTable.engineVersion = versionOverride
    end
    local replay = ReplayV3.createFromTable(jsonTable, true)
    if replay and not replay.metadata.incomplete then
      return replay
    end
  end
end

return singleVerification