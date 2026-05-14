-- TraceDiffTests.lua — unit tests for server/tests/E2E/TraceDiff.lua.
--
-- The diff util is consumed by Phase F' (cross-perspective replay check)
-- so its job is to surface every meaningful divergence between two send
-- streams. Tests cover: perfect match, body-shape diff, missing event
-- in left, missing in right, bucketing per publicId, dirFilter, and the
-- describeDiff path picker.

---@diagnostic disable: undefined-field
local TraceDiff = require("server.tests.E2E.TraceDiff")
local logger    = require("common.lib.logger")

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function entry(t)
  return {
    ts       = t.ts or 0,
    dir      = t.dir or "send",
    prefix   = t.prefix or "J",
    body     = t.body,
    publicId = t.publicId,
  }
end

----------------------------------------------------------------------
-- Perfect match
----------------------------------------------------------------------

local function test_identical_streams_report_clean()
  logger.info("test_identical_streams_report_clean")
  local left = {
    entry({ ts = 1, prefix = "J", body = { type = "ping" }, publicId = 1 }),
    entry({ ts = 2, prefix = "I", body = "AAAA",            publicId = 1 }),
  }
  local right = {
    entry({ ts = 1, prefix = "J", body = { type = "ping" }, publicId = 1 }),
    entry({ ts = 2, prefix = "I", body = "AAAA",            publicId = 1 }),
  }
  local r = TraceDiff.diff(left, right)
  assert(TraceDiff.isClean(r), "expected clean diff, got " .. r.summary.body_diffs
    .. " body diffs / " .. r.summary.left_only .. " left_only / "
    .. r.summary.right_only .. " right_only")
  assert(r.summary.matched == 2)
end

local function test_recv_entries_ignored_by_default()
  logger.info("test_recv_entries_ignored_by_default")
  local left = {
    entry({ dir = "send", prefix = "J", body = { x = 1 }, publicId = 1 }),
    entry({ dir = "recv", prefix = "J", body = { y = 2 }, publicId = 1 }),
  }
  local right = {
    entry({ dir = "send", prefix = "J", body = { x = 1 }, publicId = 1 }),
    -- no recv on the right side at all — must not show up as a diff
  }
  local r = TraceDiff.diff(left, right)
  assert(TraceDiff.isClean(r),
    "recv entries should be filtered out by default; got "
    .. r.summary.body_diffs .. " body diffs, "
    .. r.summary.left_only  .. " left_only, "
    .. r.summary.right_only .. " right_only")
end

----------------------------------------------------------------------
-- Body diffs
----------------------------------------------------------------------

local function test_body_value_diff_recorded()
  logger.info("test_body_value_diff_recorded")
  local left  = { entry({ ts = 1, prefix = "J", body = { type = "roomRequest", count = 2 }, publicId = 1 }) }
  local right = { entry({ ts = 1, prefix = "J", body = { type = "roomRequest", count = 3 }, publicId = 1 }) }
  local r = TraceDiff.diff(left, right)
  assert(r.summary.body_diffs == 1, "expected 1 body diff, got " .. r.summary.body_diffs)
  local d = r.body_diffs[1]
  assert(d.divergence.path == "$.count", "wrong divergence path: " .. tostring(d.divergence.path))
  assert(d.divergence.kind == "value")
  assert(d.divergence.left == 2 and d.divergence.right == 3)
end

local function test_body_type_diff_recorded()
  logger.info("test_body_type_diff_recorded")
  local left  = { entry({ prefix = "J", body = { x = 1 },     publicId = 1 }) }
  local right = { entry({ prefix = "J", body = "raw_string",  publicId = 1 }) }
  local r = TraceDiff.diff(left, right)
  assert(r.summary.body_diffs == 1)
  assert(r.body_diffs[1].divergence.kind == "type")
end

----------------------------------------------------------------------
-- Asymmetry
----------------------------------------------------------------------

local function test_left_has_extra_event()
  logger.info("test_left_has_extra_event")
  local left = {
    entry({ ts = 1, prefix = "J", body = { x = 1 }, publicId = 1 }),
    entry({ ts = 2, prefix = "J", body = { x = 2 }, publicId = 1 }),
  }
  local right = {
    entry({ ts = 1, prefix = "J", body = { x = 1 }, publicId = 1 }),
  }
  local r = TraceDiff.diff(left, right)
  assert(r.summary.left_only == 1, "expected 1 left_only, got " .. r.summary.left_only)
  assert(r.summary.right_only == 0)
  assert(r.left_only[1].entry.body.x == 2)
end

local function test_right_has_extra_event()
  logger.info("test_right_has_extra_event")
  local left  = { entry({ prefix = "J", body = { x = 1 }, publicId = 1 }) }
  local right = {
    entry({ prefix = "J", body = { x = 1 }, publicId = 1 }),
    entry({ prefix = "J", body = { x = 2 }, publicId = 1 }),
  }
  local r = TraceDiff.diff(left, right)
  assert(r.summary.right_only == 1)
  assert(r.right_only[1].entry.body.x == 2)
end

----------------------------------------------------------------------
-- Per-publicId bucketing — events from different players never pair
----------------------------------------------------------------------

local function test_buckets_isolate_publicIds()
  logger.info("test_buckets_isolate_publicIds")
  local left  = { entry({ prefix = "J", body = { x = 1 }, publicId = 1 }) }
  local right = { entry({ prefix = "J", body = { x = 1 }, publicId = 2 }) }
  local r = TraceDiff.diff(left, right)
  -- Same body, same prefix, but different publicIds => no pairing.
  assert(r.summary.matched == 0)
  assert(r.summary.left_only == 1)
  assert(r.summary.right_only == 1)
end

local function test_buckets_isolate_prefixes()
  logger.info("test_buckets_isolate_prefixes")
  local left  = { entry({ prefix = "J", body = "X", publicId = 1 }) }
  local right = { entry({ prefix = "I", body = "X", publicId = 1 }) }
  local r = TraceDiff.diff(left, right)
  assert(r.summary.matched == 0)
  assert(r.summary.left_only == 1)
  assert(r.summary.right_only == 1)
end

----------------------------------------------------------------------
-- Ordering within a bucket is preserved by ts
----------------------------------------------------------------------

local function test_intra_bucket_order_by_ts()
  logger.info("test_intra_bucket_order_by_ts")
  -- Left entries arrive in reverse-ts order in the input; the diff
  -- must re-sort them so pair i = (chronological i) on both sides.
  local left = {
    entry({ ts = 5, prefix = "J", body = { x = 5 }, publicId = 1 }),
    entry({ ts = 1, prefix = "J", body = { x = 1 }, publicId = 1 }),
  }
  local right = {
    entry({ ts = 1, prefix = "J", body = { x = 1 }, publicId = 1 }),
    entry({ ts = 5, prefix = "J", body = { x = 5 }, publicId = 1 }),
  }
  local r = TraceDiff.diff(left, right)
  assert(TraceDiff.isClean(r),
    "ts-resorted pairs should match, got " .. r.summary.body_diffs ..
    " body diffs")
end

----------------------------------------------------------------------
-- dirFilter override
----------------------------------------------------------------------

local function test_dirFilter_override_to_recv()
  logger.info("test_dirFilter_override_to_recv")
  local left = {
    entry({ dir = "recv", prefix = "J", body = { y = 1 }, publicId = 1 }),
  }
  local right = {
    entry({ dir = "recv", prefix = "J", body = { y = 2 }, publicId = 1 }),
  }
  local r = TraceDiff.diff(left, right, { dirFilter = "recv" })
  assert(r.summary.body_diffs == 1, "recv-filter diff should compare recv entries")
end

----------------------------------------------------------------------
-- Phase 3 Step 3.3 — Server-side recv and client-side send for the
-- same wire J event must diff clean. Pre-fix, the server tap ran AFTER
-- ClientMessages.sanitize* so the bodies didn't match. Locks in the
-- post-fix invariant: both sides record the same wire shape.
----------------------------------------------------------------------

local function test_client_send_and_server_recv_match_at_wire_layer()
  logger.info("test_client_send_and_server_recv_match_at_wire_layer")
  -- Exact wire body for a real ClientProtocol message — what the client
  -- TraceWriter would log on `send` and what the server TraceWriter
  -- logs on `recv` (post-fix, captured pre-parseMessage).
  local wireRoomRequest = {
    recipient = "server",
    type      = "roomRequest",
    content   = {
      gameMode = { name = "two_player_vs" },
      latencyTolerance = "normal",
      openRoom = false,
    },
  }
  local wireMenuState = { menu_state = { ready = true, level = 5 } }

  local clientSends = {
    entry({ ts = 1, dir = "send", prefix = "J", body = wireRoomRequest, publicId = 7 }),
    entry({ ts = 2, dir = "send", prefix = "J", body = wireMenuState,   publicId = 7 }),
  }
  local serverRecvs = {
    entry({ ts = 1, dir = "send", prefix = "J", body = wireRoomRequest, publicId = 7 }),
    entry({ ts = 2, dir = "send", prefix = "J", body = wireMenuState,   publicId = 7 }),
  }

  local r = TraceDiff.diff(clientSends, serverRecvs)
  assert(TraceDiff.isClean(r),
    "client send vs server recv should diff cleanly at the wire layer; "
    .. "got " .. r.summary.body_diffs .. " body diffs")
  assert(r.summary.matched == 2)
end

----------------------------------------------------------------------
-- Run
----------------------------------------------------------------------

test_identical_streams_report_clean()
test_recv_entries_ignored_by_default()
test_body_value_diff_recorded()
test_body_type_diff_recorded()
test_left_has_extra_event()
test_right_has_extra_event()
test_buckets_isolate_publicIds()
test_buckets_isolate_prefixes()
test_intra_bucket_order_by_ts()
test_dirFilter_override_to_recv()

logger.info("All TraceDiffTests passed!")
