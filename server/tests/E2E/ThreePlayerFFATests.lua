-- True end-to-end test: 3-player Open FFA, garbage mode "all".
--
-- Drives three real NetClient instances (the same class the LÖVE client uses
-- when you click "Host Online Match") connected via real TCP sockets to a
-- real Server instance. Every protocol exchange runs through production
-- NetClient methods — see TestPlayer.lua for the GAME-swap pattern that
-- lets three NetClients coexist in one process.
--
-- The contract this delivers: if anyone changes NetClient:requestRoom (or any
-- other method a real button calls), this test and the LÖVE client see the
-- change at the same time. They can't silently diverge.

---@diagnostic disable: invisible, undefined-field
local Harness = require("server.tests.E2E.Harness")
local TestPlayer = require("server.tests.E2E.TestPlayer")
local NetworkProtocol = require("common.network.NetworkProtocol")
local KeyDataEncoding = require("common.data.KeyDataEncoding")
local logger = require("common.lib.logger")

local OPEN_FFA_NAME = "open_ffa"
local OPEN_FFA_MODE_ID = "OPEN_FFA"

local function logStep(name)
  logger.info("[E2E 3pFFA] step: " .. name)
end

-- Predicate: all players satisfy `check(p)` (a boolean-returning method).
local function allCheck(players, check)
  return function()
    for _, p in ipairs(players) do
      if not check(p) then return false end
    end
    return true
  end
end

-- Drive every TestPlayer's pump in lockstep with the server. Replaces the
-- harness-level tick when scenarios own TestPlayer objects (the harness only
-- pumps Server + custom TestClient sockets; TestPlayer owns its NetClient).
local function pumpAll(h, players)
  return function()
    h:tick()
    for _, p in ipairs(players) do p:update() end
  end
end

local function waitUntil(h, players, predicate, timeout, message)
  local pump = pumpAll(h, players)
  -- We can't use h:waitUntil here because it doesn't pump TestPlayers. Roll our own.
  local socket = require("common.lib.socket")
  local deadline = socket.gettime() + (timeout or 10)
  while socket.gettime() < deadline do
    pump()
    if predicate() then return true end
    socket.sleep(0.005)
  end
  logger.warn("[E2E 3pFFA] waitUntil timed out" .. (message and (": " .. message) or ""))
  return false
end

--------------------------------------------------------------------------------
-- Shared setup: bring 3 fresh TestPlayers to matchStart.
-- Returns host, joiner1, joiner2, and the {all} list.
--------------------------------------------------------------------------------

local function bringThreeTestPlayersToMatchStart(h)
  logStep("create 3 TestPlayers (real NetClient each)")
  -- Names must fit NAME_LENGTH_LIMIT=16; the harness has its own unique suffix
  -- via run-id, but TestPlayer needs distinct names too. Use short hex.
  local function uname(prefix)
    return prefix .. "_" .. string.format("%04x", math.random(0, 0xffff))
  end
  local a = TestPlayer(uname("BotA"))
  local b = TestPlayer(uname("BotB"))
  local c = TestPlayer(uname("BotC"))
  local all = { a, b, c }

  logStep("login (real LoginRoutine coroutine)")
  for _, p in ipairs(all) do p:login(h.host, h.port) end
  assert(waitUntil(h, all, allCheck(all, TestPlayer.isLoggedIn), 8, "login"),
         "not all players logged in")

  logStep("host A creates Open FFA room (NetClient:requestRoom)")
  a:requestRoom(OPEN_FFA_MODE_ID, "relaxed")
  -- For Open FFA, the host stays in the lobby state while alone (the room
  -- needs >= minPlayers (2) before it activates). So we wait for the SERVER
  -- to know about the room, not for the client to enter ROOM state.
  assert(waitUntil(h, all, function()
    return h:findRoomByGameMode(OPEN_FFA_NAME) ~= nil
  end, 5, "server-side room created"), "server did not create room")
  local serverRoom = h:findRoomByGameMode(OPEN_FFA_NAME)
  assert(serverRoom, "no open_ffa room found on server")
  local serverRoomNumber = serverRoom.roomNumber

  logStep("B and C join via NetClient:requestJoinRoom -> room " .. serverRoomNumber)
  b:joinRoom(serverRoomNumber)
  c:joinRoom(serverRoomNumber)
  -- Once the room hits minPlayers, the server activates it and all clients
  -- transition into the ROOM state (CharacterSelect equivalent).
  assert(waitUntil(h, all, allCheck(all, TestPlayer.isInRoom), 8, "all in ROOM state"),
         "not all clients transitioned to ROOM state")

  logStep("all ready up via NetClient:sendPlayerSettings")
  for _, p in ipairs(all) do p:sendReady() end

  logStep("wait for matchStart (NetClient transitions to INGAME)")
  assert(waitUntil(h, all, allCheck(all, TestPlayer.isInGame), 10, "matchStart"),
         "server did not start match within 10s")

  return a, b, c, all
end

--------------------------------------------------------------------------------
-- Scenario 1: 3 TestPlayers walk the real flow all the way to matchStart
--------------------------------------------------------------------------------

local function test_3p_open_ffa_match_starts()
  logger.info("[E2E 3pFFA] === test_3p_open_ffa_match_starts ===")
  local h = Harness():start()
  local ok, err = pcall(function()
    local a, b, c, all = bringThreeTestPlayersToMatchStart(h)

    -- battleRoom is the production-side representation of a match in progress.
    -- It carries the engine, players, gameMode, etc. NetClient assigns it
    -- when the matchStart message arrives.
    assert(a.gameStub.battleRoom, "host A has no battleRoom after matchStart")
    assert(a.gameStub.battleRoom.match, "host A's battleRoom has no match")
    -- Stack count comes from the replay payload broadcast by the server.
    local stacks = a.gameStub.battleRoom.match.stacks
                 or (a.gameStub.battleRoom.match.engine
                     and a.gameStub.battleRoom.match.engine.stacks)
    if stacks then
      assert(#stacks == 3, "expected 3 stacks, got " .. #stacks)
    end

    logger.info("[E2E 3pFFA] PASS — 3p Open FFA reached match start via production NetClient")
    for _, p in ipairs(all) do p:close() end
  end)
  h:stop()
  if not ok then error(err, 0) end
end

--------------------------------------------------------------------------------
-- Scenario 2: input streaming through NetClient:sendInput, relay verified
--------------------------------------------------------------------------------

local INPUT_BURSTS = 5

local function test_3p_open_ffa_input_relay()
  logger.info("[E2E 3pFFA] === test_3p_open_ffa_input_relay ===")
  local h = Harness():start()
  local ok, err = pcall(function()
    local a, b, c, all = bringThreeTestPlayersToMatchStart(h)

    -- NetClient buffers incoming peer inputs on its tcpClient queues. We
    -- count by the slot-tagged prefixes the server uses for relays — same
    -- accounting the production engine does via tcpClient:processIncomingMessages.
    local function inputCountFor(player, prefix)
      local q = player.netClient.tcpClient.receivedInputQueues
            or player.netClient.tcpClient.opponentInputQueues
      if not q then return 0 end
      local slot = NetworkProtocol.playerIndexForInputPrefix[prefix]
      local bucket = q[slot] or q[prefix]
      if not bucket then return 0 end
      return (type(bucket.len) == "function" and bucket:len()) or #bucket
    end

    logStep("each player streams " .. INPUT_BURSTS .. " input frames via NetClient:sendInput")
    for _ = 1, INPUT_BURSTS do
      a:sendInput(KeyDataEncoding.idle)
      b:sendInput(KeyDataEncoding.swap)
      c:sendInput(KeyDataEncoding.right)
      h:tick()
      for _, p in ipairs(all) do p:update() end
    end

    -- Relay properties (server-side, in Room:broadcastInput at Room.lua:660):
    --   * Tags each frame with the SENDER's slot prefix
    --   * Skip-self: sender doesn't get its own input echoed back
    --   * All other room members receive
    -- In 3p: A(slot1)->U,V; B(slot2)->I,V; C(slot3)->I,U from each other's view.
    local SLOT_A = NetworkProtocol.getInputPrefixForPlayer(1)
    local SLOT_B = NetworkProtocol.getInputPrefixForPlayer(2)
    local SLOT_C = NetworkProtocol.getInputPrefixForPlayer(3)

    logStep("wait for relays to drain into each TestPlayer's NetClient")
    local function eachGotBothPeers()
      return inputCountFor(a, SLOT_B) >= INPUT_BURSTS
         and inputCountFor(a, SLOT_C) >= INPUT_BURSTS
         and inputCountFor(b, SLOT_A) >= INPUT_BURSTS
         and inputCountFor(b, SLOT_C) >= INPUT_BURSTS
         and inputCountFor(c, SLOT_A) >= INPUT_BURSTS
         and inputCountFor(c, SLOT_B) >= INPUT_BURSTS
    end
    assert(waitUntil(h, all, eachGotBothPeers, 5, "relay drain"),
           "input relay incomplete; counts: "
           .. "A<-B=" .. inputCountFor(a, SLOT_B)
           .. " A<-C=" .. inputCountFor(a, SLOT_C)
           .. " B<-A=" .. inputCountFor(b, SLOT_A)
           .. " B<-C=" .. inputCountFor(b, SLOT_C)
           .. " C<-A=" .. inputCountFor(c, SLOT_A)
           .. " C<-B=" .. inputCountFor(c, SLOT_B))

    logger.info("[E2E 3pFFA] PASS — input relay verified through production NetClient")
    for _, p in ipairs(all) do p:close() end
  end)
  h:stop()
  if not ok then error(err, 0) end
end

--------------------------------------------------------------------------------
-- Runner
--------------------------------------------------------------------------------

local function runAll()
  test_3p_open_ffa_match_starts()
  test_3p_open_ffa_input_relay()
end

if not package.loaded["server.tests.E2E.ThreePlayerFFATests"] then
  runAll()
end

return {
  runAll = runAll,
  test_3p_open_ffa_match_starts = test_3p_open_ffa_match_starts,
  test_3p_open_ffa_input_relay = test_3p_open_ffa_input_relay,
}
