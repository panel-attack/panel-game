-- End-to-end harness: orchestrates a real Server + N scripted TCP clients
-- inside a single LuaJIT process, with cooperative pumping.
--
-- Architecture:
--   * Bind a real Server on a test port (default 49580, distinct from the
--     dev server's 49569 so an already-running dev server doesn't conflict).
--   * Use MockPersistence so no file I/O hits leaderboard.csv / players.txt.
--     The SQLite player table will still pick up rows from the test run —
--     that's accepted; tests use unique names per run to avoid stale-row noise.
--   * Each tick: Server:update() then poll() every client. Clients are
--     non-blocking sockets, so tick is bounded.
--   * waitUntil(predicate, timeoutSeconds) is the test's primary primitive —
--     tick until the predicate flips or the budget runs out.

---@diagnostic disable-next-line: different-requires
local socket = require("common.lib.socket")
local class = require("common.lib.class")
local logger = require("common.lib.logger")
local TestClient = require("server.tests.E2E.TestClient")

local DEFAULT_HOST = "127.0.0.1"
local DEFAULT_TIMEOUT = 10
local TICK_SLEEP = 0.005 -- 5ms per idle tick keeps CPU sane without adding latency

-- Each Harness instance picks its own port in the high-ephemeral range so
-- back-to-back tests in the same process don't fight TIME_WAIT on a fixed
-- port. The counter ensures monotonic increment across multiple Harness
-- objects in one process; the os.time() seed gives separation across
-- back-to-back test-script invocations.
local _portCounter = (os.time() % 1000)

---@class E2EHarness
---@field host string
---@field port integer
---@field server Server                real Server instance bound to host:port
---@field clients TestClient[]
local Harness = class(function(self, opts)
  opts = opts or {}
  self.host = opts.host or DEFAULT_HOST
  -- Picks a fresh port per Harness instance so the second test in a run doesn't
  -- collide with the first's TIME_WAIT. Range 49600-50599 is safely above the
  -- dev server's 49569 and below the ephemeral-port pool most systems use.
  if opts.port then
    self.port = opts.port
  else
    _portCounter = _portCounter + 1
    self.port = 49600 + (_portCounter % 1000)
  end
  self.clients = {}
  self.server = nil
  -- Names are capped at NAME_LENGTH_LIMIT (16) chars by the server, so keep the
  -- per-run suffix small. 6 hex chars from a random 24-bit number is plenty to
  -- avoid collisions on the sqlite Player table across back-to-back runs.
  self._uniqueSuffix = opts.uniqueSuffix
                       or string.format("%06x", math.random(0, 0xffffff))

  -- Server-side error capture (set up in start(), drained in stop()).
  -- `serverErrorCount` and `serverErrors[]` are public — scenarios can
  -- inspect them mid-test for fine-grained assertions; stop() asserts on
  -- them implicitly unless opts.expectErrors == true.
  self.serverErrorCount = 0
  self.serverErrors = {}
  self.expectErrors = opts.expectErrors == true
  self._origLoggerError = nil

  -- Optional wall-clock injection for arbitration-window tests. nil = use
  -- the real socket.gettime in Server/Room. Pass a callable returning a
  -- monotonically-increasing seconds value to drive arbitration determini-
  -- stically (e.g. a closure over a mutable t that the test advances).
  self.clock = opts.clock
end)

-- Build a Server with real socket/DB but stubbed persistence, bound to our test port.
function Harness:start()
  -- Server-side imports are deferred until start() so importing the harness
  -- module doesn't drag in DB schema initialization for callers that just
  -- want to spawn TestClients.
  local Server = require("server.server")
  local PADatabase = require("server.PADatabase")
  local MockPersistence = require("server.tests.MockPersistence")
  local GameModes = require("common.data.GameModes")

  -- Override the SERVER_PORT global before Server:start() reads it.
  -- We can't change the binding after the fact.
  SERVER_PORT = self.port
  -- The server otherwise enforces ENGINE_VERSION match at login. For e2e tests
  -- we don't care which build the harness picks up — version-skew testing is a
  -- separate concern. Letting any version in keeps the test resilient to the
  -- engine being bumped in the future.
  ANY_ENGINE_VERSION_ENABLED = true

  self.server = Server(PADatabase, MockPersistence)
  if self.clock then
    -- Override BEFORE start() so any room created during the run picks up
    -- the fake clock via create_room's self.clock plumbing.
    self.server.clock = self.clock
  end

  -- MockPersistence ignores both of these, but the constructor calls
  -- through to it and expects valid paths/data shapes.
  self.server:initializePlayerData("", {})
  self.server:initializeLeaderboard(GameModes.getPreset(GameModes.IDs.TWO_PLAYER_VS), "")

  self.server:start()
  logger.info("[E2E Harness] Server listening on " .. self.host .. ":" .. self.port)

  -- Hook logger.error so every server-side error produced during the test
  -- gets captured on the harness. The original handler is still called so
  -- the error continues to flow to logs/e2e.log; we just also record it.
  -- Without this every test would have to manually grep logs for errors.
  self._origLoggerError = logger.error
  local capture = self
  logger.error = function(msg, ...)
    capture.serverErrorCount = capture.serverErrorCount + 1
    table.insert(capture.serverErrors, tostring(msg))
    return capture._origLoggerError(msg, ...)
  end

  return self
end

-- Stop the server and close every client socket. Idempotent; safe in cleanup
-- paths even when start() failed partway. Restores logger.error to whatever
-- it was before start(). Asserts no server-side errors were captured during
-- the test unless the scenario opted into errors via Harness({expectErrors=true}).
function Harness:stop()
  for _, c in ipairs(self.clients) do
    pcall(function() c:close() end)
  end
  self.clients = {}
  if self.server then
    pcall(function() self.server:stop() end)
    self.server = nil
  end
  if self._origLoggerError then
    logger.error = self._origLoggerError
    self._origLoggerError = nil
  end
  if not self.expectErrors and self.serverErrorCount > 0 then
    local sample = self.serverErrors[1] or "(unknown)"
    error("[E2E Harness] " .. self.serverErrorCount
          .. " server-side error(s) logged during scenario; first: "
          .. sample, 0)
  end
end

-- Spawn and connect a new client. The name is suffixed with the harness's
-- unique run-id so back-to-back test runs don't collide on names already in
-- the SQLite Player table.
function Harness:addClient(baseName)
  local name = (baseName or "Bot") .. "_" .. self._uniqueSuffix
  local c = TestClient(name):connect(self.host, self.port)
  table.insert(self.clients, c)
  return c
end

-- One cooperative-scheduler step. Drives the server forward and lets every
-- client drain its receive buffer. Tests rarely call this directly — use
-- waitUntil instead.
function Harness:tick()
  if self.server then self.server:update() end
  for _, c in ipairs(self.clients) do c:poll() end
end

-- Spin the harness until predicate() returns truthy, or the timeout elapses.
-- Returns true if predicate fired, false if we timed out. Tests should always
-- assert on the return value so a failure surfaces as a clear error rather
-- than a downstream nil-deref later in the scenario.
function Harness:waitUntil(predicate, timeoutSeconds, message)
  timeoutSeconds = timeoutSeconds or DEFAULT_TIMEOUT
  local deadline = socket.gettime() + timeoutSeconds
  while socket.gettime() < deadline do
    self:tick()
    if predicate() then return true end
    socket.sleep(TICK_SLEEP)
  end
  logger.warn("[E2E Harness] waitUntil timed out after " .. timeoutSeconds
              .. "s" .. (message and (": " .. message) or ""))
  return false
end

-- Pump the harness for a fixed duration. Useful for "let the match run a bit"
-- or "give the server time to broadcast pending events" idle waits.
function Harness:tickFor(seconds)
  local deadline = socket.gettime() + seconds
  while socket.gettime() < deadline do
    self:tick()
    socket.sleep(TICK_SLEEP)
  end
end

-- Walk every Server.rooms entry and return the most recently created one whose
-- mode name matches gameModeName. Useful for "the host just sent roomRequest,
-- what's the room number?" without subscribing to lobbyState broadcasts.
function Harness:findRoomByGameMode(gameModeName)
  if not self.server or not self.server.rooms then return nil end
  local found
  for _, room in pairs(self.server.rooms) do
    local roomMode = room.gameMode and (room.gameMode.name or room.gameMode.gameModeId)
    if roomMode == gameModeName then
      found = room -- last wins => most recently created
    end
  end
  return found
end

-- Get the i-th room by room number ascending. Sometimes simpler than name lookup.
function Harness:firstRoom()
  if not self.server or not self.server.rooms then return nil end
  local lowest, found
  for n, room in pairs(self.server.rooms) do
    if not lowest or n < lowest then lowest, found = n, room end
  end
  return found
end

return Harness
