#!/usr/bin/env luajit
-- server_trace_to_fixture.lua
--
-- Converts SERVER-side TraceWriter output into the fixture envelope that
-- common/tests/engine/CrashReplayRegressionTests already understands —
-- a single ReplayV3 with full per-stack inputs + crossPlayerEvents,
-- runnable via Match.createFromReplay + match:run().
--
-- Engine-only — no TCP, no Server, no login. The earlier bundle approach
-- (replay captured wire bytes through a real Server in tests) hit
-- protocol-shape mismatches between the server's recv tap and what
-- TestClient can re-emit; that's intractable without rebuilding the
-- client-side sanitizer in test code. Engine replay sidesteps it: we
-- only need inputs + cross-player events, and Match.createFromReplay
-- already knows that shape.
--
-- Input  : trace_archive/<publicId>/session_<loginTs>.jsonl  (one per player)
-- Output : common/tests/fixtures/crash_replays/<name>.json  (one fixture)
--
-- Per-player extraction:
--   recv I body=<raw chars>     → appended to that publicId's stack inputs
--   recv D body=<JSON>          → crossPlayerEvents.deaths (sender = stackIndex)
--   recv G body=<JSON>          → crossPlayerEvents.garbage (sender = stackIndex)
--   send J matchStart           → base replay payload (rules, panelSource,
--                                  garbageFlows, stacks, metadata)
--
-- Usage:
--   luajit tools/server_trace_to_fixture.lua \
--     <fixture_name> \
--     <server_trace_path>...
--
-- Example:
--   luajit tools/server_trace_to_fixture.lua wrong_draw_2026_05_13 \
--     trace_archive/5/session_1778717170.jsonl \
--     trace_archive/7/session_1778717165.jsonl \
--     trace_archive/8/session_1778717186.jsonl \
--     trace_archive/11/session_1778717182.jsonl

package.path = package.path .. ";./?.lua;./?/init.lua"

local json = require("common.lib.dkjson")
local lfs  = require("lfs")

local FIXTURE_DIR = "common/tests/fixtures/crash_replays"

----------------------------------------------------------------------
-- Tiny IO helpers
----------------------------------------------------------------------

local function die(fmt, ...)
  io.stderr:write("server_trace_to_fixture: " .. string.format(fmt, ...) .. "\n")
  os.exit(1)
end

local function info(fmt, ...)
  io.stderr:write("server_trace_to_fixture: " .. string.format(fmt, ...) .. "\n")
end

local function readAll(path)
  local f, err = io.open(path, "rb")
  if not f then die("cannot read %s: %s", path, err) end
  local data = f:read("*a")
  f:close()
  return data
end

local function writeAll(path, data)
  local f, err = io.open(path, "wb")
  if not f then die("cannot write %s: %s", path, err) end
  f:write(data)
  f:close()
end

local function mkdirRecursive(path)
  local accum = ""
  for chunk in path:gmatch("[^/]+") do
    accum = accum == "" and chunk or (accum .. "/" .. chunk)
    lfs.mkdir(accum)
  end
end

local function parseLines(blob)
  local out = {}
  for line in blob:gmatch("[^\n]+") do
    if line:match("%S") then
      local ok, entry = pcall(json.decode, line)
      if ok and type(entry) == "table" then
        out[#out + 1] = entry
      end
    end
  end
  return out
end

local function publicIdFromPath(path)
  local norm = path:gsub("\\", "/")
  local pid = norm:match("/(%d+)/session_%d+%.jsonl$")
            or norm:match("^(%d+)/session_%d+%.jsonl$")
  if not pid then
    die("cannot extract publicId from %q (expected …/<publicId>/session_*.jsonl)", path)
  end
  return tonumber(pid)
end

----------------------------------------------------------------------
-- Trace inspection
----------------------------------------------------------------------

-- Find the most recent matchStart this player received. Returns the
-- decoded matchStart content (= the partial ReplayV3 payload the server
-- sent at game start), and the index into entries so we can ignore any
-- earlier I/G/D events that belonged to a prior game in the same session.
local function findMatchStart(entries)
  local idx, content
  for i, e in ipairs(entries) do
    if e.dir == "send" and e.prefix == "J" and type(e.body) == "table"
       and e.body.type == "matchStart" then
      idx, content = i, e.body.content
    end
  end
  return idx, content
end

-- Build publicId → stackIndex map from the matchStart's metadata.stacks.
local function slotMapFromMatchStart(matchStart)
  local out = {}
  if not matchStart or type(matchStart.metadata) ~= "table" then
    return out
  end
  for _, s in ipairs(matchStart.metadata.stacks or {}) do
    if s.publicId and s.stackIndex then
      out[s.publicId] = s.stackIndex
    end
  end
  return out
end

----------------------------------------------------------------------
-- Per-player event extraction
----------------------------------------------------------------------

-- Decode a server `recv` body into the canonical engine-side shape:
--   I → raw input string (already what the engine wants)
--   D → decoded table; stamp `sender = stackIndex` since the player who
--       sent the D didn't write their own slot into it (the server adds
--       that field on relay)
--   G → decoded table, same sender stamping
local function decodeRecv(prefix, body, stackIndex)
  if prefix == "I" then
    return type(body) == "string" and body or ""
  end
  if prefix == "D" or prefix == "G" then
    if type(body) == "string" then
      local ok, t = pcall(json.decode, body)
      if ok and type(t) == "table" then
        t.sender = t.sender or stackIndex
        return t
      end
    elseif type(body) == "table" then
      body.sender = body.sender or stackIndex
      return body
    end
  end
  return body
end

-- Extract this player's contributions to the canonical replay:
--   inputString — concatenation of every recv I body
--   deaths      — each recv D, sender stamped
--   garbage     — each recv G, sender stamped
local function extractPlayerEvents(entries, startIdx, stackIndex)
  local inputs = {}
  local deaths = {}
  local garbage = {}

  for i = startIdx + 1, #entries do
    local e = entries[i]
    if e.dir == "recv" then
      if e.prefix == "I" then
        local s = decodeRecv("I", e.body, stackIndex)
        if s ~= "" then inputs[#inputs + 1] = s end
      elseif e.prefix == "D" then
        local d = decodeRecv("D", e.body, stackIndex)
        if type(d) == "table" then deaths[#deaths + 1] = d end
      elseif e.prefix == "G" then
        local g = decodeRecv("G", e.body, stackIndex)
        if type(g) == "table" then garbage[#garbage + 1] = g end
      end
    end
  end

  return table.concat(inputs), deaths, garbage
end

----------------------------------------------------------------------
-- Fixture assembly
----------------------------------------------------------------------

local function buildFixture(opts)
  local fixtureName = opts.name
  local tracePaths  = opts.tracePaths

  -- 1) Load every trace, find matchStart in each, validate they agree.
  local perPlayer = {}  -- {[publicId] = {entries, msIdx, matchStart}}
  for _, path in ipairs(tracePaths) do
    local pid = publicIdFromPath(path)
    local entries = parseLines(readAll(path))
    local idx, content = findMatchStart(entries)
    if not content then
      die("trace %s never received a matchStart", path)
    end
    perPlayer[pid] = { path = path, entries = entries, msIdx = idx, matchStart = content }
  end

  -- 2) Pick a canonical matchStart (any player's; they should all match
  -- since the server sends the same payload to everyone).
  local canonicalPid, canonical
  for pid, pp in pairs(perPlayer) do
    canonicalPid, canonical = pid, pp.matchStart
    break
  end

  local slotMap = slotMapFromMatchStart(canonical)
  if not next(slotMap) then
    die("matchStart in %s has no metadata.stacks — cannot map publicIds to slots",
        perPlayer[canonicalPid].path)
  end

  -- 3) Per-stack input collection + cross-player event aggregation.
  local stackInputs = {}  -- [stackIndex] = string
  local allDeaths   = {}
  local allGarbage  = {}

  -- Walk in publicId-sorted order so output is stable across runs.
  local pids = {}
  for pid in pairs(perPlayer) do pids[#pids + 1] = pid end
  table.sort(pids)

  for _, pid in ipairs(pids) do
    local stackIndex = slotMap[pid]
    if not stackIndex then
      die("publicId %d not present in matchStart metadata.stacks (slot map = %s)",
          pid, json.encode(slotMap))
    end
    local pp = perPlayer[pid]
    local input, deaths, garbage =
      extractPlayerEvents(pp.entries, pp.msIdx, stackIndex)
    stackInputs[stackIndex] = input
    for _, d in ipairs(deaths)  do allDeaths[#allDeaths + 1]  = d end
    for _, g in ipairs(garbage) do allGarbage[#allGarbage + 1] = g end
    info("  publicId=%d → slot %d : %d input chars, %d D, %d G",
         pid, stackIndex, #input, #deaths, #garbage)
  end

  -- 4) Build the canonical replay. Start from the matchStart payload
  -- (which is shaped like a partial ReplayV3 already) and fill in inputs
  -- + crossPlayerEvents.
  local replay = canonical
  for i, stack in ipairs(replay.stacks or {}) do
    stack.inputs = stackInputs[i] or ""
  end
  replay.crossPlayerEvents = {
    deaths  = allDeaths,
    garbage = allGarbage,
  }
  -- Match.createFromReplay expects engineVersion and metadata.timestamp at
  -- the top level — both are already in the matchStart payload.

  -- 5) Compute a suspect frame: the highest senderFrame across all D events,
  -- plus a small buffer. That's a sane "by this frame, the match should
  -- definitely have ended" cap for runPerspective's stop loop.
  local lastDeathFrame = 0
  for _, d in ipairs(allDeaths) do
    local f = tonumber(d.senderFrame) or 0
    if f > lastDeathFrame then lastDeathFrame = f end
  end
  local suspectFrame = lastDeathFrame + 600  -- ~10s of slack at 60fps

  -- 6) Wrap in the fixture envelope CrashReplayRegressionTests reads.
  -- One perspective per publicId, all sharing the canonical replay (the
  -- replay IS the canonical truth — there's nothing per-perspective to
  -- diverge here since we already merged the cross-player events).
  local roomNumber = nil
  for _, pp in pairs(perPlayer) do
    -- Walk back through entries to find the most recent addToRoom prior
    -- to matchStart for this player (it carries roomNumber).
    for i = pp.msIdx, 1, -1 do
      local e = pp.entries[i]
      if e.dir == "send" and e.prefix == "J" and type(e.body) == "table"
         and e.body.type == "addToRoom" and type(e.body.content) == "table" then
        roomNumber = e.body.content.roomNumber
        break
      end
    end
    if roomNumber then break end
  end

  local perspectives = {}
  for _, pid in ipairs(pids) do
    perspectives[tostring(pid)] = {
      incidentId = fixtureName,
      publicId   = pid,
      schemaVer  = 1,
      error      = "",
      trace      = "",
      traceHash  = "",
      clientMeta = {
        engineVersion = replay.engineVersion or "000",
        os            = "server-trace-replay",
      },
      gameContext = {
        roomNumber   = roomNumber or 0,
        gameId       = 0,
        frame        = suspectFrame,
        gameModeName = (replay.metadata and replay.metadata.gameModeName) or "VS",
        matchCount   = 1,
      },
      replay  = replay,
      logTail = {},
    }
  end

  return {
    incidentId   = fixtureName,
    schemaVer    = 1,
    reason       = "from_server_trace",
    suspectFrame = suspectFrame,
    perspectives = perspectives,
  }
end

----------------------------------------------------------------------
-- Main
----------------------------------------------------------------------

local function main(args)
  if #args < 2 then
    die("usage: luajit tools/server_trace_to_fixture.lua <fixture_name> <trace_path>...")
  end

  local fixtureName = args[1]
  local tracePaths = {}
  for i = 2, #args do tracePaths[#tracePaths + 1] = args[i] end

  mkdirRecursive(FIXTURE_DIR)
  local outPath = FIXTURE_DIR .. "/" .. fixtureName .. ".json"
  if lfs.attributes(outPath) then
    die("output fixture already exists: %s (delete it first to regenerate)", outPath)
  end

  info("building fixture %q from %d trace(s)", fixtureName, #tracePaths)
  local fixture = buildFixture({ name = fixtureName, tracePaths = tracePaths })

  -- Stable encoding so diffs across regenerations are readable.
  local encoded = json.encode(fixture, { indent = false })
  writeAll(outPath, encoded)
  info("wrote %s (%d bytes)", outPath, #encoded)
end

main(arg or {})
