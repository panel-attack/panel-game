-- TraceDiff — compare two trace streams (client vs server, or original
-- vs replay) and emit a structured divergence report.
--
-- Two streams paired by (publicId, prefix), then matched within each
-- bucket by chronological order. An entry that fails to pair is reported
-- as left_only or right_only. Entries that pair but disagree on body
-- shape go to body_diffs.
--
-- This module is deliberately I/O-free: callers hand it two arrays of
-- {ts, dir, prefix, body, publicId?} entries. TraceReplay handles the
-- bundle-on-disk loading; the CLI runner (tools/trace_diff.lua) glues
-- them together.
--
-- Failure model: errors-by-return-value. Callers can decide how loud to
-- be. No pcall'ing in here — the report is consumed by tests and CLI.

local M = {}

----------------------------------------------------------------------
-- Internal helpers
----------------------------------------------------------------------

-- Stable string key for bucketing. We diff per-(publicId, prefix) so
-- two events with the same prefix but different publicIds never pair.
local function bucketKey(entry)
  return tostring(entry.publicId or "_") .. "|" .. tostring(entry.prefix or "_")
end

-- Group an array of entries into buckets and sort each bucket by ts.
-- Entries with `dir ~= "send"` are dropped — comparing send streams is
-- the load-bearing case; recv streams from two perspectives have
-- inherent ts-skew that swamps the signal.
local function bucketize(entries, dirFilter)
  local buckets = {}
  for _, e in ipairs(entries or {}) do
    if not dirFilter or e.dir == dirFilter then
      local k = bucketKey(e)
      buckets[k] = buckets[k] or {}
      table.insert(buckets[k], e)
    end
  end
  for _, b in pairs(buckets) do
    table.sort(b, function(a, c)
      return (tonumber(a.ts) or 0) < (tonumber(c.ts) or 0)
    end)
  end
  return buckets
end

-- Deep table equality. Tolerates nil vs absent-key (since dkjson
-- round-trips nil values as missing keys). Numbers compare exactly —
-- if you want fuzzy ts compare, normalize before calling.
local function deepEqual(a, b)
  if a == b then return true end
  local ta, tb = type(a), type(b)
  if ta ~= tb then return false end
  if ta ~= "table" then return false end
  for k, v in pairs(a) do
    if not deepEqual(v, b[k]) then return false end
  end
  for k, v in pairs(b) do
    if a[k] == nil and v ~= nil then return false end
  end
  return true
end

-- Compute a small descriptor of where two bodies diverge. Used in
-- body_diffs entries so the test failure message points at the actual
-- field instead of "two big tables differ somewhere".
local function describeDiff(a, b, path)
  path = path or "$"
  local ta, tb = type(a), type(b)
  if ta ~= tb then
    return { path = path, kind = "type",
             left = ta, right = tb }
  end
  if ta ~= "table" then
    if a == b then return nil end
    return { path = path, kind = "value",
             left = a, right = b }
  end
  for k in pairs(a) do
    local sub = describeDiff(a[k], b[k], path .. "." .. tostring(k))
    if sub then return sub end
  end
  for k in pairs(b) do
    if a[k] == nil then
      return { path = path .. "." .. tostring(k), kind = "right_only_key",
               right = b[k] }
    end
  end
  return nil
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

---Diff two arrays of trace entries. By default compares only `send`
---entries (the only stream both sides observe with comparable shape).
---@param left {ts,dir,prefix,body,publicId?}[] expected / original
---@param right {ts,dir,prefix,body,publicId?}[] actual / replay / other
---@param opts {dirFilter: string?, ignoreTs: boolean?}?
---@return {summary: table, body_diffs: table[], left_only: table[], right_only: table[]}
function M.diff(left, right, opts)
  opts = opts or {}
  local dirFilter = opts.dirFilter
  if dirFilter == nil then dirFilter = "send" end

  local L = bucketize(left,  dirFilter)
  local R = bucketize(right, dirFilter)

  local body_diffs, left_only, right_only = {}, {}, {}
  local matched = 0
  local seen = {}

  -- Walk every bucket in L; pair index-by-index against R[key].
  for key, lBucket in pairs(L) do
    seen[key] = true
    local rBucket = R[key] or {}
    local n = math.max(#lBucket, #rBucket)
    for i = 1, n do
      local le, re = lBucket[i], rBucket[i]
      if le and re then
        if deepEqual(le.body, re.body) then
          matched = matched + 1
        else
          body_diffs[#body_diffs + 1] = {
            bucket = key,
            index  = i,
            left   = le,
            right  = re,
            divergence = describeDiff(le.body, re.body),
          }
        end
      elseif le and not re then
        left_only[#left_only + 1] = { bucket = key, index = i, entry = le }
      elseif re and not le then
        right_only[#right_only + 1] = { bucket = key, index = i, entry = re }
      end
    end
  end

  -- Buckets only present in R — every entry is a right_only.
  for key, rBucket in pairs(R) do
    if not seen[key] then
      for i, re in ipairs(rBucket) do
        right_only[#right_only + 1] = { bucket = key, index = i, entry = re }
      end
    end
  end

  -- Stable orderings so the report is deterministic across runs.
  table.sort(left_only,  function(a, b)
    if a.bucket == b.bucket then return a.index < b.index end
    return a.bucket < b.bucket
  end)
  table.sort(right_only, function(a, b)
    if a.bucket == b.bucket then return a.index < b.index end
    return a.bucket < b.bucket
  end)
  table.sort(body_diffs, function(a, b)
    if a.bucket == b.bucket then return a.index < b.index end
    return a.bucket < b.bucket
  end)

  return {
    summary = {
      left_count    = M.countMatching(left,  dirFilter),
      right_count   = M.countMatching(right, dirFilter),
      matched       = matched,
      body_diffs    = #body_diffs,
      left_only     = #left_only,
      right_only    = #right_only,
      dirFilter     = dirFilter,
    },
    body_diffs = body_diffs,
    left_only  = left_only,
    right_only = right_only,
  }
end

---Convenience: returns true iff the two streams matched perfectly
---(no body diffs, no left-only, no right-only).
---@return boolean
function M.isClean(report)
  local s = report.summary
  return s.body_diffs == 0 and s.left_only == 0 and s.right_only == 0
end

---Count send (or filtered-dir) entries in a trace.
function M.countMatching(entries, dirFilter)
  if not dirFilter then return #(entries or {}) end
  local n = 0
  for _, e in ipairs(entries or {}) do
    if e.dir == dirFilter then n = n + 1 end
  end
  return n
end

return M
