-- traceDiff.lua — CLI runner for the cross-perspective trace diff util.
--
-- Usage:
--   luajit traceDiff.lua <left-bundle-or-file> <right-bundle-or-file> [--filter=send|recv]
--
-- Each argument can be either:
--   - a directory matching the trace_archive bundle layout
--     (`<bundleDir>/<publicId>/match_*/_match.jsonl` + `game_*.jsonl`)
--   - a single .jsonl file (the server-side trace_archive emits one file
--     per session: `trace_archive/<publicId>/session_<ts>.jsonl`)
--
-- Exits 0 when the diff is clean, 1 when there are divergences (so it
-- composes cleanly with shell-pipeline gates).

io.stdout:setvbuf("no")

local util = require("common.lib.util")
util.addToCPath("./common/lib/??")
util.addToCPath("./server/lib/??")

local json        = require("common.lib.dkjson")
local lfs         = require("lfs")
local TraceDiff   = require("server.tests.E2E.TraceDiff")

local function usage()
  io.stderr:write([[
Usage: luajit traceDiff.lua <left> <right> [--filter=send|recv]

  <left>, <right>   trace_archive bundle directory or single .jsonl file
  --filter=send     compare only send events (default; recv differs in
                    ts between perspectives and inflates the noise)
  --filter=recv     compare only recv events (server-vs-server case)

Exit 0 = clean diff, 1 = divergences, 2 = argument error.
]])
end

----------------------------------------------------------------------
-- File I/O — small enough to inline, avoids dragging in TraceReplay's
-- love.filesystem fallbacks for what is a strictly-server-side CLI.
----------------------------------------------------------------------

local function isDir(path)
  local attr = lfs.attributes(path)
  return attr and attr.mode == "directory" or false
end

local function isFile(path)
  local attr = lfs.attributes(path)
  return attr and attr.mode == "file" or false
end

local function readFile(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local data = f:read("*a")
  f:close()
  return data
end

local function parseLines(blob, publicIdHint)
  local out = {}
  for line in blob:gmatch("[^\n]+") do
    if line:match("%S") then
      local ok, entry = pcall(json.decode, line)
      if ok and type(entry) == "table" then
        -- Server-side traces don't embed publicId in each entry (one
        -- file per player), so let the caller stamp it.
        if publicIdHint and not entry.publicId then
          entry.publicId = publicIdHint
        end
        out[#out + 1] = entry
      end
    end
  end
  return out
end

local function loadOne(path)
  -- Single .jsonl file. The publicId hint is the parent directory name
  -- when the file lives under <bundleDir>/<publicId>/...
  if isFile(path) then
    local blob = readFile(path)
    if not blob then return {} end
    local parent = path:match("([^/]+)/[^/]+$") or "_"
    return parseLines(blob, parent)
  end

  -- Directory: assume bundle layout `<root>/<publicId>/<match>/*.jsonl`,
  -- OR the server-side flat-per-session layout `<root>/<publicId>/session_*.jsonl`.
  local entries = {}
  for publicId in lfs.dir(path) do
    if publicId ~= "." and publicId ~= ".." then
      local pidPath = path .. "/" .. publicId
      if isDir(pidPath) then
        -- Walk one level. If we hit subdirectories (match_*), recurse one
        -- more level into them. .jsonl directly under publicId/ is the
        -- server-side layout; .jsonl under publicId/match_*/ is client.
        for inner in lfs.dir(pidPath) do
          if inner ~= "." and inner ~= ".." then
            local innerPath = pidPath .. "/" .. inner
            if isFile(innerPath) and inner:match("%.jsonl$") then
              local blob = readFile(innerPath)
              if blob then
                for _, e in ipairs(parseLines(blob, publicId)) do
                  entries[#entries + 1] = e
                end
              end
            elseif isDir(innerPath) then
              for leaf in lfs.dir(innerPath) do
                if leaf:match("%.jsonl$") then
                  local blob = readFile(innerPath .. "/" .. leaf)
                  if blob then
                    for _, e in ipairs(parseLines(blob, publicId)) do
                      entries[#entries + 1] = e
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  return entries
end

----------------------------------------------------------------------
-- Arg parsing
----------------------------------------------------------------------

if #arg < 2 then
  usage()
  os.exit(2)
end

local leftPath, rightPath, filter = arg[1], arg[2], "send"
for i = 3, #arg do
  local f = arg[i]:match("^%-%-filter=(.+)$")
  if f then filter = f end
end

if filter ~= "send" and filter ~= "recv" then
  io.stderr:write("invalid --filter=" .. tostring(filter)
                  .. "; expected send|recv\n")
  os.exit(2)
end

----------------------------------------------------------------------
-- Diff + emit
----------------------------------------------------------------------

local left  = loadOne(leftPath)
local right = loadOne(rightPath)

local report = TraceDiff.diff(left, right, { dirFilter = filter })

-- Pretty-print the summary, then the JSON-encoded full report on stdout.
-- Tests / pipelines can `jq` the JSON; humans can eyeball the summary.
io.stderr:write(string.format(
  "left  = %s (%d %s events)\nright = %s (%d %s events)\nmatched=%d body_diffs=%d left_only=%d right_only=%d\n",
  leftPath, report.summary.left_count, filter,
  rightPath, report.summary.right_count, filter,
  report.summary.matched, report.summary.body_diffs,
  report.summary.left_only, report.summary.right_only
))

io.write(json.encode(report, { indent = true }))
io.write("\n")

os.exit(TraceDiff.isClean(report) and 0 or 1)
