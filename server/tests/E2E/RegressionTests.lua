-- End-to-end regression tests for the May 12 bug fix (commit ec5dd55d).
--
-- Each scenario reproduces the conditions that triggered one of the
-- B0/B1/B8/B9/B10/D bugs and asserts on the post-fix behavior. If any of
-- those regressions sneak back in, the relevant test goes red instead of
-- the bug shipping to a 3-player session.
--
-- These tests use the same TestPlayer + Harness infrastructure as
-- ThreePlayerFFATests.lua. The "expectErrors = false" default on Harness
-- gives every scenario an implicit "no logger.error fired" check on stop().

---@diagnostic disable: invisible, undefined-field
local Harness = require("server.tests.E2E.Harness")
local TestPlayer = require("server.tests.E2E.TestPlayer")
local logger = require("common.lib.logger")
local socket = require("common.lib.socket")
local tableUtils = require("common.lib.tableUtils")

local OPEN_FFA_NAME = "open_ffa"
local OPEN_FFA_MODE_ID = "OPEN_FFA"

local function uname(prefix)
  return prefix .. "_" .. string.format("%04x", math.random(0, 0xffff))
end

-- Local "wait until predicate(), pumping h + every TestPlayer" helper. We
-- can't reuse Harness:waitUntil because it only pumps the server + TestClients
-- — TestPlayers own their own NetClient that needs explicit update() ticks.
local function waitUntil(h, players, predicate, timeoutSeconds, message)
  local deadline = socket.gettime() + (timeoutSeconds or 10)
  while socket.gettime() < deadline do
    h:tick()
    for _, p in ipairs(players) do p:update() end
    if predicate() then return true end
    socket.sleep(0.005)
  end
  logger.warn("[E2E Regression] waitUntil timed out"
              .. (message and (": " .. message) or ""))
  return false
end

local function allLoggedIn(players)
  return function()
    for _, p in ipairs(players) do
      if not p:isLoggedIn() then return false end
    end
    return true
  end
end

local function countServerPlayers(room)
  if not room or not room.players then return 0 end
  -- room.players is keyed by slot number (player_number) and can be sparse
  -- after a mid-room leave on dynamic-roster modes. Count via pairs, not #.
  local n = 0
  for _ in pairs(room.players) do n = n + 1 end
  return n
end

--------------------------------------------------------------------------------
-- D — sparse-roster compaction at Room:start_match (Open FFA)
--
-- 4 clients join an Open FFA room. One leaves before anyone is ready.
-- The remaining 3 ready up; the server activates and starts the match.
-- The fix ensures Room:start_match compacts the (now sparse) self.players
-- table so the broadcast replay has dense playerNumbers 1/2/3, not 1/2/4.
--
-- Pre-fix symptom: matchStart payload had 4 stack slots with one nil-filled,
-- which tripped Match.createFromReplay's #stacks length check and crashed
-- every joiner. Now: dense roster, no crash.
--------------------------------------------------------------------------------

local function test_open_ffa_compacts_after_pre_match_leave()
  logger.info("[E2E Regression] === test_open_ffa_compacts_after_pre_match_leave ===")
  local h = Harness():start()
  local ok, err = pcall(function()
    local a = TestPlayer(uname("BotA"))
    local b = TestPlayer(uname("BotB"))
    local c = TestPlayer(uname("BotC"))
    local d = TestPlayer(uname("BotD"))
    local all = { a, b, c, d }
    local stayers = { a, c, d }

    for _, p in ipairs(all) do p:login(h.host, h.port) end
    assert(waitUntil(h, all, allLoggedIn(all), 8, "login"),
           "not all 4 players logged in")

    a:requestRoom(OPEN_FFA_MODE_ID, "relaxed")
    assert(waitUntil(h, all, function()
      return h:findRoomByGameMode(OPEN_FFA_NAME) ~= nil
    end, 5, "room created"), "host did not get room")
    local room = h:findRoomByGameMode(OPEN_FFA_NAME)
    local roomNumber = room.roomNumber

    -- All 3 joiners enter, giving 4 players in the room.
    b:joinRoom(roomNumber)
    c:joinRoom(roomNumber)
    d:joinRoom(roomNumber)
    assert(waitUntil(h, all, function()
      return countServerPlayers(room) == 4
    end, 5, "4 players seated"), "did not reach 4 players in room: only "
       .. countServerPlayers(room))

    -- Pre-match leave: B drops without ever being ready.
    b:leaveRoom()
    assert(waitUntil(h, all, function()
      return countServerPlayers(room) == 3
    end, 5, "B departed"), "B's leave didn't take effect; players=" ..
       countServerPlayers(room))

    -- After B leaves, room.players is sparse — slot 2 is gone. Slots 1/3/4
    -- still point at A/C/D respectively until start_match's compaction runs.
    -- This is the exact state D's fix targets.
    local sparseSlotsBefore = {}
    for slot in pairs(room.players) do sparseSlotsBefore[#sparseSlotsBefore + 1] = slot end
    table.sort(sparseSlotsBefore)
    logger.info("[E2E Regression] pre-ready slots: " ..
                table.concat(sparseSlotsBefore, ","))

    -- The 3 stayers ready up; server activates + starts the match.
    for _, p in ipairs(stayers) do p:sendReady() end
    assert(waitUntil(h, stayers, function()
      return room.game ~= nil
    end, 10, "matchStart"), "match did not start within 10s")

    -- After compaction: dense roster. Three assertions cover the fix.
    -- (1) Players table is dense — slot numbers are exactly {1,2,3}.
    local denseSlots = {}
    for slot in pairs(room.players) do denseSlots[#denseSlots + 1] = slot end
    table.sort(denseSlots)
    assert(#denseSlots == 3 and denseSlots[1] == 1
           and denseSlots[2] == 2 and denseSlots[3] == 3,
           "expected slots {1,2,3} after compaction, got {"
           .. table.concat(denseSlots, ",") .. "}")

    -- (2) The replay broadcast has exactly 3 stacks (not 4 with a nil hole).
    local replay = room.game.replay
    assert(replay, "no replay on server game after start_match")
    assert(#replay.stacks == 3,
           "expected 3 stacks in replay, got " .. #replay.stacks)

    -- (3) replay.metadata.stacks playerNumbers are sequential 1/2/3, no gap.
    for i = 1, 3 do
      local meta = replay.metadata.stacks[i]
      assert(meta, "missing metadata.stacks[" .. i .. "]")
      assert(meta.stackIndex == i,
             "metadata.stacks[" .. i .. "].stackIndex == "
             .. tostring(meta.stackIndex) .. ", expected " .. i)
    end

    logger.info("[E2E Regression] PASS — D: open-FFA roster compacted to 3 dense slots")
    for _, p in ipairs(all) do p:close() end
  end)
  h:stop()
  if not ok then error(err, 0) end
end

--------------------------------------------------------------------------------
-- Runner
--------------------------------------------------------------------------------

local function runAll()
  test_open_ffa_compacts_after_pre_match_leave()
end

if not package.loaded["server.tests.E2E.RegressionTests"] then
  runAll()
end

return {
  runAll = runAll,
  test_open_ffa_compacts_after_pre_match_leave = test_open_ffa_compacts_after_pre_match_leave,
}
