#!/usr/bin/env luajit
-- server_trace_to_bundle.lua
--
-- Converts SERVER-side TraceWriter output into the CLIENT-side trace
-- bundle layout that server/tests/E2E/TraceReplayTests sweeps. Replays
-- the captured wire events back through a real Server (Harness) via
-- TestClients — one per publicId — so the server arrives at the same
-- internal state it had during the live game.
--
-- The Whole Point: prove a captured bug reproduces *through the real
-- code path*, not just through a synthetic engine-only fixture. The
-- engine-only fixture (tools/server_trace_to_fixture.lua) is good for
-- pure-engine outcome bugs (getWinners, end-conditions). UI-layer bugs,
-- timing races, and anything that depends on ClientMatch/Server message
-- ordering need the full bundle replay.
--
-- ---------------------------------------------------------------------
-- Translation: server-side trace tap historical caveat
-- ---------------------------------------------------------------------
-- Older trace captures (before server.lua moved the J tap above
-- ClientMessages.parseMessage) recorded the *sanitized* form of J
-- bodies — fields had already been renamed by the server's
-- sanitization pass. The sanitizer doesn't round-trip: re-emitting a
-- sanitized {playerSettings={...}} as a wire message lands in the
-- "Received an unexpected message" branch.
--
-- Two specific renames need to be undone for old traces:
--   (a) {playerSettings = X}                    →  {menu_state = X}
--   (b) {roomRequest = true,
--        gameMode, latencyTolerance,
--        openRoom, seed}                        →  {type    = "roomRequest",
--                                                  content = {gameMode,
--                                                              latencyTolerance,
--                                                              openRoom,
--                                                              seed}}
--
-- Other shapes (joinRoomRequest, leave_room, logout, challengeUpdate,
-- spectate_request, taunt, game_over, stackEliminated, flagGame,
-- error_report) pass through unchanged — the sanitizer routes them by
-- top-level key and the wire & sanitized shapes match for those.
--
-- For new traces tapped pre-sanitize, the translation is a no-op
-- (the input already matches the wire shape).
--
-- ---------------------------------------------------------------------
-- Input  : trace_archive/<publicId>/session_<loginTs>.jsonl
-- Output : common/tests/fixtures/trace_replays/<name>/<publicId>/match_<room>_<joinedTs>/_match.jsonl
--
-- Per-publicId conversion: server `recv` lines become client `send`
-- lines (each player's trace contains the bytes THEY sent to the
-- server; that's what they need to re-send during replay). Server
-- `send` lines (relayed peer traffic) are dropped — peers contribute
-- those events from their own traces. Pre-handshake H/E and login
-- messages are filtered (the harness owns its own login).
--
-- Usage:
--   luajit tools/server_trace_to_bundle.lua \
--     <bundle_name> <server_trace_path>...
--
-- Example:
--   luajit tools/server_trace_to_bundle.lua wrong_draw_2026_05_13 \
--     trace_archive/5/session_1778717170.jsonl  \
--     trace_archive/7/session_1778717165.jsonl  \
--     trace_archive/8/session_1778717186.jsonl  \
--     trace_archive/11/session_1778717182.jsonl
--
-- After: zsh run_e2e_tests.sh   # TraceReplayTests sweeps the bundle.

package.path = package.path .. ";./?.lua;./?/init.lua"

local json = require("common.lib.dkjson")
local lfs  = require("lfs")

local FIXTURE_ROOT = "common/tests/fixtures/trace_replays"

----------------------------------------------------------------------
-- IO helpers
----------------------------------------------------------------------

local function die(fmt, ...)
  io.stderr:write("server_trace_to_bundle: " .. string.format(fmt, ...) .. "\n")
  os.exit(1)
end

local function info(fmt, ...)
  io.stderr:write("server_trace_to_bundle: " .. string.format(fmt, ...) .. "\n")
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
-- Translation: undo sanitization renames so re-emitted bodies route
-- through the server's dispatcher on replay.
----------------------------------------------------------------------

local function isSanitizedRoomRequest(body)
  -- Sanitized roomRequest is identifiable by {roomRequest = true} as a
  -- BOOLEAN top-level key. The wire form uses {type = "roomRequest"} —
  -- so anything that already has a `.type` field is wire-shaped and
  -- should pass through unchanged.
  return type(body) == "table"
     and body.roomRequest == true
     and body.type == nil
end

local function isSanitizedMenuState(body)
  return type(body) == "table"
     and body.playerSettings ~= nil
     and body.menu_state == nil
end

local function translateBodyToWireShape(body)
  if type(body) ~= "table" then return body end

  if isSanitizedRoomRequest(body) then
    -- {roomRequest=true, gameMode, latencyTolerance, openRoom, seed}
    --   → {type="roomRequest", content={gameMode, latencyTolerance, openRoom, seed}}
    local content = {
      gameMode         = body.gameMode,
      latencyTolerance = body.latencyTolerance,
      openRoom         = body.openRoom,
      seed             = body.seed,
    }
    return { type = "roomRequest", content = content }
  end

  if isSanitizedMenuState(body) then
    -- The sanitizer renamed `ranked` → `wants_ranked_match` inside the
    -- table. Reverse it so the re-sanitization on replay reads the same
    -- value. Other inner field names (ready, loaded, wants_ready,
    -- character, stage, level, inputMethod, levelData, panels_dir,
    -- cursor) match the wire shape — pass through.
    local inner = body.playerSettings
    local copy  = {}
    for k, v in pairs(inner) do copy[k] = v end
    if copy.wants_ranked_match ~= nil and copy.ranked == nil then
      copy.ranked = copy.wants_ranked_match
      copy.wants_ranked_match = nil
    end
    return { menu_state = copy }
  end

  return body
end

----------------------------------------------------------------------
-- Per-trace extraction
----------------------------------------------------------------------

-- Locate the gameKey (roomNumber + the ts of the addToRoom that
-- enrolled this player). roomNumber comes from the matchStart
-- metadata (it's broadcast as a J send to every member).
local function findGameContext(entries)
  local roomNumber, joinedTs
  for _, e in ipairs(entries) do
    if e.dir == "send" and e.prefix == "J" and type(e.body) == "table" then
      local mtype = e.body.type
      local content = e.body.content
      if mtype == "addToRoom" and type(content) == "table" and content.roomNumber then
        roomNumber = content.roomNumber
        joinedTs = joinedTs or e.ts
        if roomNumber and joinedTs then break end
      end
    end
  end
  return roomNumber, joinedTs
end

-- Drop pre-handshake / login traffic. Harness performs its own login
-- per TestClient before replaying the bundle, so a captured login
-- request would attempt to log in twice.
local function shouldKeepRecv(entry)
  if entry.prefix == "H" or entry.prefix == "E" then return false end
  if entry.prefix == "J" and type(entry.body) == "table" then
    if entry.body.login_request then return false end
  end
  return true
end

----------------------------------------------------------------------
-- Per-player conversion
----------------------------------------------------------------------

local function convertTrace(srcPath, outDir)
  info("processing %s", srcPath)
  local entries = parseLines(readAll(srcPath))
  if #entries == 0 then die("no entries in %s", srcPath) end

  local publicId = publicIdFromPath(srcPath)
  local roomNumber, joinedTs = findGameContext(entries)
  if not roomNumber then
    die("trace %s never received an addToRoom; cannot derive roomNumber", srcPath)
  end

  local matchDirName = string.format("match_%d_%d", roomNumber, math.floor(joinedTs))
  local matchDir     = outDir .. "/" .. tostring(publicId) .. "/" .. matchDirName
  local matchFile    = matchDir .. "/_match.jsonl"

  mkdirRecursive(matchDir)

  local outLines = {}
  local kept, dropped, translated = 0, 0, 0

  for _, e in ipairs(entries) do
    if e.dir == "recv" then
      if shouldKeepRecv(e) then
        local body = e.body
        if e.prefix == "J" then
          local before = body
          body = translateBodyToWireShape(body)
          if body ~= before then translated = translated + 1 end
        elseif e.prefix == "D" or e.prefix == "G" then
          -- Server tap stores G/D bodies as raw JSON strings. TestClient's
          -- _replaySendEvent dispatches G/D only when body is a TABLE
          -- (sendGarbageEvent/sendDeathEvent both json.encode internally).
          -- Decode here so the bundle round-trips through the dispatcher.
          if type(body) == "string" then
            local ok, decoded = pcall(json.decode, body)
            if ok and type(decoded) == "table" then body = decoded end
          end
        end
        local converted = {
          ts     = e.ts,
          dir    = "send",
          prefix = e.prefix,
          body   = body,
        }
        outLines[#outLines + 1] = json.encode(converted)
        kept = kept + 1
      else
        dropped = dropped + 1
      end
    end
  end

  writeAll(matchFile, table.concat(outLines, "\n") .. "\n")
  info("  publicId=%d roomNumber=%d → %s (kept %d, dropped %d, J-translated %d)",
       publicId, roomNumber, matchFile, kept, dropped, translated)
  return publicId, roomNumber
end

----------------------------------------------------------------------
-- Main
----------------------------------------------------------------------

local function main(args)
  if #args < 2 then
    die("usage: luajit tools/server_trace_to_bundle.lua <bundle_name> <trace_path>...")
  end

  local bundleName = args[1]
  local outDir = FIXTURE_ROOT .. "/" .. bundleName

  if lfs.attributes(outDir) then
    die("output bundle already exists: %s (delete it first to regenerate)", outDir)
  end

  mkdirRecursive(outDir)

  local roomByPid = {}
  for i = 2, #args do
    local pid, room = convertTrace(args[i], outDir)
    roomByPid[pid] = room
  end

  local seenRoom
  for pid, room in pairs(roomByPid) do
    if seenRoom and seenRoom ~= room then
      die("traces span multiple rooms (publicId %d → room %d, expected %d).",
          pid, room, seenRoom)
    end
    seenRoom = room
  end

  local n = 0
  for _ in pairs(roomByPid) do n = n + 1 end
  info("bundle %s built (room %d, %d players)", bundleName, seenRoom or -1, n)
end

main(arg or {})
