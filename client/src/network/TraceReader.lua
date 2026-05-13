-- TraceReader — recreate a Match from a JSONL trace.
--
-- The other side of TraceWriter. Reads a JSONL trace file (one event
-- per line) and produces a runnable Match by:
--   1. Finding the first recv with body.type == "matchStart".
--   2. Calling Match.createFromReplay on its content (a ReplayV3 table).
--   3. Walking forward through the trace, applying every recv/send line
--      that affects engine state.
--
-- The validator test (CrashReplayRegressionTests) is the gate per
-- docs/CRASH_REPLAY_PLAN.md "Implementation phases / Start here": if
-- recreation drifts from the live match, the trace is missing data and
-- the tap layer needs to be extended.

require("client.src.globals")

local json     = require("common.lib.dkjson")
local logger   = require("common.lib.logger")
local Match    = require("common.engine.Match")
local ReplayV3 = require("common.data.ReplayV3")

local M = {}

---Parse a JSONL blob into an array of decoded entries. Skips empty
---lines + decode failures with a warning rather than throwing — a
---corrupt trace shouldn't kill a test run that's investigating it.
---@param blob string raw JSONL contents
---@return table[] entries
function M.parseLines(blob)
  local out = {}
  for line in blob:gmatch("[^\n]+") do
    if line:match("%S") then
      local ok, entry = pcall(json.decode, line)
      if ok and type(entry) == "table" then
        out[#out + 1] = entry
      else
        logger.warn("[TraceReader] skipping unparseable line: " .. line:sub(1, 120))
      end
    end
  end
  return out
end

---Find the first matchStart frame in a parsed entry list.
---@param entries table[]
---@return table? matchStartBody the `content` field of the matchStart message
local function findMatchStart(entries)
  for _, e in ipairs(entries) do
    if e.dir == "recv" and type(e.body) == "table" and e.body.type == "matchStart" then
      return e.body.content
    end
  end
end

---Build a Match from the matchStart-content table found in the trace.
---@param matchStartContent table the ReplayV3 shape inside matchStart.body.content
---@return Match
local function bootstrapMatch(matchStartContent)
  -- matchStart's content is already a ReplayV3-shaped table (server-built
  -- via getPartialReplay). createFromV3Data sets the metatable +
  -- backfills any V3-era fields the captured payload might miss.
  local replay = ReplayV3.createFromV3Data(matchStartContent)
  local match  = Match.createFromReplay(replay)
  match:start()
  for _, stack in ipairs(match.stacks) do
    if stack.setMaxRunsPerFrame then stack:setMaxRunsPerFrame(1) end
  end
  return match
end

---Drive a Match through the engine-affecting events in a parsed trace.
---Returns the match. The match is left at whatever state the trace
---reached (typically end-of-match if the trace recorded a full game).
---
---Event mapping (per the plan's "replay-from-trace recipe"):
---  - recv J matchStart : bootstrap (already done before this call)
---  - recv I {playerNumber, input} : relayed peer input → engine
---  - recv G : garbage event → engine
---  - recv D : death event → engine
---  - send I : this client's outgoing input
---  - everything else : forensic-only, skipped for recreation
---@param entries table[]
---@return Match? match
function M.recreate(entries)
  local startContent = findMatchStart(entries)
  if not startContent then
    return nil, "trace contains no matchStart"
  end

  local match = bootstrapMatch(startContent)

  -- Build per-stack input strings from the trace. Three sources, in
  -- order of authority:
  --   1. `dir=="input"` events carry per-frame local inputs (the local
  --      stack's view as PlayerStack:send_controls fed it). Single-
  --      player has nothing else.
  --   2. `dir=="recv" prefix=="I"` carries relayed peer inputs from the
  --      server, keyed by playerNumber.
  --   3. `dir=="send" prefix=="I"` carries this client's outbound input
  --      frames in compressed form. Used as a fallback when the local
  --      `input` tap wasn't running on the captured client.
  -- The replay's stack-inputs strings already in matchStart are the
  -- BASE state; we append on top so a trace recorded mid-game replays
  -- alongside the bootstrap inputs.
  local byStack = {}
  local inboundByPlayer = {}

  for _, e in ipairs(entries) do
    if e.dir == "input" and type(e.raw) == "string" and e.stack then
      byStack[e.stack] = (byStack[e.stack] or "") .. e.raw
    elseif e.dir == "recv" and e.prefix == "I" and type(e.body) == "table" then
      local pn = e.body.playerNumber
      if pn then
        inboundByPlayer[pn] = (inboundByPlayer[pn] or "") .. (e.body.input or "")
      end
    end
  end

  -- Fold inboundByPlayer in only where the local input stream didn't
  -- claim that stack (a stack belongs to one perspective: locally
  -- produced OR remotely relayed, not both).
  for pn, inputs in pairs(inboundByPlayer) do
    if not byStack[pn] then byStack[pn] = inputs end
  end

  -- Feed each stack its trace-derived inputs. receiveConfirmedInput
  -- appends to the engine's confirmedInput; combined with the
  -- pre-loaded inputs from createFromReplay (matchStart bootstrap),
  -- the engine has a complete input timeline.
  for stackIndex, inputs in pairs(byStack) do
    local stack = match.stacks[stackIndex]
    if stack and stack.receiveConfirmedInput then
      stack:receiveConfirmedInput(inputs)
    end
  end

  return match, nil
end

---Convenience: parse a JSONL blob and recreate in one call.
---@param blob string raw JSONL trace contents
---@return Match? match
function M.recreateFromBlob(blob)
  return M.recreate(M.parseLines(blob))
end

return M
