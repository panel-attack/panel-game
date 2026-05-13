-- TraceReplay — fixture-bundle loader for end-to-end regression tests.
--
-- One bundle directory holds the trace files captured from every
-- client involved in one game/match. Layout per docs/TRACE_LOGS_GUIDE.md:
--
--   common/tests/fixtures/trace_replays/<bug-slug>/
--     <publicId>/match_<room>_<joinedTs>/_match.jsonl
--     <publicId>/match_<room>_<joinedTs>/game_<ts>.jsonl
--     ...
--
-- The test driver reads such a bundle, merges every client's `send`
-- events into a single timeline ordered by `ts`, then plays the merged
-- stream against the E2E Harness via one TestClient per publicId.
-- Replay rides the same TestClient send methods a real client would
-- have used at capture time.
--
-- This module is the file-IO + merge half. The replay machinery lives
-- on TestClient (TestClient:replayTrace / _replaySendEvent).

local json = require("common.lib.dkjson")

local M = {}

---Parse one JSONL blob into an array of decoded entries. Skips empty
---lines and unparseable lines (logs nothing — fixture loading should be
---loud about real syntax errors but resilient to trailing whitespace,
---blank lines, etc.).
---@param blob string
---@return table[]
function M.parseLines(blob)
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

local function isDir(path)
  -- Pure-Lua fallback for when love.filesystem isn't available (server
  -- test process); uses lfs which the server side imports anyway.
  if love and love.filesystem then
    local info = love.filesystem.getInfo(path)
    return info and info.type == "directory" or false
  end
  local lfs = require("lfs")
  local attr = lfs.attributes(path)
  return attr and attr.mode == "directory" or false
end

local function listDir(path)
  if love and love.filesystem then
    return love.filesystem.getDirectoryItems(path) or {}
  end
  local lfs = require("lfs")
  local out = {}
  for name in lfs.dir(path) do
    if name ~= "." and name ~= ".." then out[#out + 1] = name end
  end
  table.sort(out)
  return out
end

local function readFile(path)
  if love and love.filesystem then
    return love.filesystem.read(path)
  end
  local f = io.open(path, "r")
  if not f then return nil end
  local data = f:read("*a")
  f:close()
  return data
end

---Read a bundle directory. Returns `{[publicId] = { blobs = {jsonl, ...} }}`.
---Walks `<bundleDir>/<publicId>/match_*/*.jsonl` and concatenates all
---JSONL bytes per publicId in filename-sorted order — so `_match.jsonl`
---comes before `game_*.jsonl` for the same match, and games appear in
---chronological order.
---@param bundleDir string path to the bundle root
---@return table<string, {blobs: string[]}>
function M.loadBundle(bundleDir)
  local clients = {}
  for _, publicId in ipairs(listDir(bundleDir)) do
    local pidPath = bundleDir .. "/" .. publicId
    if isDir(pidPath) then
      local blobs = {}
      for _, matchDir in ipairs(listDir(pidPath)) do
        local matchPath = pidPath .. "/" .. matchDir
        if isDir(matchPath) then
          for _, file in ipairs(listDir(matchPath)) do
            if file:match("%.jsonl$") then
              local content = readFile(matchPath .. "/" .. file)
              if content then blobs[#blobs + 1] = content end
            end
          end
        end
      end
      if #blobs > 0 then
        clients[publicId] = { blobs = blobs }
      end
    end
  end
  return clients
end

---Merge every `send` event across all clients into one chronologically
---ordered list. Order is the single biggest determinant of whether
---replay reproduces the captured bug — a 1ms swap of two events can
---change which one the server saw first and break the repro.
---@param clients table<string, {blobs: string[]}>
---@return {publicId: string, ts: number, prefix: string, body: any}[]
function M.mergedSendsByTs(clients)
  local merged = {}
  for publicId, client in pairs(clients) do
    for _, blob in ipairs(client.blobs) do
      for _, entry in ipairs(M.parseLines(blob)) do
        if entry.dir == "send" then
          merged[#merged + 1] = {
            publicId = publicId,
            ts       = tonumber(entry.ts) or 0,
            prefix   = entry.prefix,
            body     = entry.body,
          }
        end
      end
    end
  end
  table.sort(merged, function(a, b) return a.ts < b.ts end)
  return merged
end

---Convenience: load + merge in one call. Returns the bundle table
---plus the merged stream.
---@param bundleDir string
---@return table<string, {blobs: string[]}>, {publicId, ts, prefix, body}[]
function M.loadAndMerge(bundleDir)
  local bundle = M.loadBundle(bundleDir)
  return bundle, M.mergedSendsByTs(bundle)
end

return M
