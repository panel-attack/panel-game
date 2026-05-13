-- True-e2e test player: wraps a REAL NetClient instance and the GAME-shaped
-- stub it reads from. Every meaningful action the test takes flows through
-- the same NetClient method a UI button click would call — see Lobby.lua:145
-- ("host room") and the NetClient public-API surface at NetClient.lua:889+.
--
-- The "act" pattern: NetClient (and the modules it pulls in) read state from
-- the process-global `GAME` table. One process can hold at most one `GAME`
-- value at a time, but we want N TestPlayers in one process. So `act(fn)`
-- swaps `GAME` to this player's stub for the duration of `fn`, runs the real
-- NetClient method against that context, then swaps back. The swap is the
-- only test-code-only smell in this design — production code is called as-is.
--
-- Lifecycle:
--   local p = TestPlayer("BotA")
--   p:login(ip, port)            -- kicks off the real LoginRoutine
--   while not p:isLoggedIn() do harness:tick() end
--   p:requestRoom("OPEN_FFA", "relaxed")
--   ...

---@diagnostic disable: invisible, undefined-field

local class = require("common.lib.class")
local NetClient = require("client.src.network.NetClient")
local Player = require("client.src.Player")
local logger = require("common.lib.logger")

-- Local factories for the no-op halves of the GAME stub. Defined before the
-- class so the constructor can call them.
local function makeNoopNavStack()
  return {
    push = function() end,
    pop  = function() end,
    peek = function() return nil end,
    contains = function() return false end,
    transition = function() end,
  }
end

-- Prefer a real Theme object (loaded by theme_init in e2eTestLauncher.lua)
-- so ClientStack:assignAssets has a real getIngameAssetPack to call. Falls
-- back to a no-op table if themes wasn't populated (e.g. unit-testing this
-- module in isolation outside the E2E launcher).
local function makeNoopTheme()
  if _G.themes then
    for _, theme in pairs(_G.themes) do return theme end
  end
  return {
    playSfx        = function() end,
    playCancelSfx  = function() end,
    playValidationSfx = function() end,
    playMoveSfx    = function() end,
    getIngameAssetPack = function() return {} end,
    sounds = setmetatable({}, { __index = function() return function() end end }),
  }
end

---@class TestPlayer
---@field name string
---@field netClient any                real NetClient instance
---@field localPlayer Player           real Player instance owned by this TestPlayer
---@field gameStub table               { netClient, localPlayer, battleRoom, navigationStack, theme, timer }
---@field roomNumber integer?          set by addToRoom signal; convenience mirror of gameStub.battleRoom.roomNumber
---@field matchStarted boolean         set when the production code transitions NetClient into INGAME state
local TestPlayer = class(function(self, name)
  assert(type(name) == "string" and #name > 0, "TestPlayer requires a name")
  self.name = name

  -- Real Player object so GAME.localPlayer's signal-emitter methods exist —
  -- NetClient calls `:disconnectSubscriber(...)` and reads `.publicId` / `.name`.
  -- publicId is -1 until login fills it in.
  self.localPlayer = Player(name, -1, true)

  -- LoginRoutine reads `config.name` (process global) when building the login
  -- payload, not GAME.localPlayer.name. Three TestPlayers sharing one config
  -- would all log in as the same name. Per-player configStub inherits the
  -- defaults via __index and overrides only the fields LoginRoutine needs.
  self.configStub = setmetatable({
    name = name,
    save_replays_publicly = "not at all",
  }, { __index = _G.config })

  -- The per-player GAME-shaped context. Only the fields NetClient and its
  -- transitive callees touch need to exist — see survey at
  -- server/tests/E2E/Harness.lua / the design discussion in the bugs doc.
  self.gameStub = {
    netClient        = nil,   -- filled in below (forward reference)
    localPlayer      = self.localPlayer,
    battleRoom       = nil,   -- assigned by NetClient when a room is entered
    navigationStack  = makeNoopNavStack(),
    theme            = makeNoopTheme(),
    -- BattleRoom:restoreInputConfigurations reads GAME.input for the input
    -- manager. The test has no real keyboards / joysticks, so an empty
    -- "assignable devices" list is correct — BUT we have to claim there's at
    -- least one for `#getAssignableDevices() < #localPlayers` to be false.
    input = {
      getAssignableDevices = function() return { {} } end,
      assignDevicesToPlayer = function() end,
      releaseDevicesFromPlayer = function() end,
    },
    -- Discord rich presence integration — no-op in tests.
    rich_presence = {
      setPresence = function() end,
      update = function() end,
    },
    -- Production creates this in Game:load() via love.graphics.newCanvas; the
    -- ClientStack reads it to determine viewport scale. Auto-vivifying stub
    -- table is enough for the few methods downstream calls (getDimensions etc.)
    globalCanvas = setmetatable({}, { __index = function(_, k)
      if k == "getDimensions" then return function() return 1280, 720 end end
      if k == "getWidth"      then return function() return 1280 end end
      if k == "getHeight"     then return function() return 720 end end
      return function() return nil end
    end }),
    canvasXScale = 1,
    canvasYScale = 1,
    -- Read at update() for serverTime delta and a few other places. Numeric.
    timer            = 0,
    -- Some scenes peek at GAME.crashTrace on login failure; harmless to leave nil.
  }

  -- Construct NetClient AFTER the stub exists so we can attach it. NetClient's
  -- constructor doesn't read GAME, but downstream methods do — we wire the
  -- back-reference here so a real button-equivalent call lands at this stub.
  self.netClient = NetClient()
  self.gameStub.netClient = self.netClient

  self.roomNumber = nil
  self.matchStarted = false
end)

-- ----------------------------------------------------------------------------
-- The act() context swap — the single test-only piece of plumbing
-- ----------------------------------------------------------------------------

-- Run `fn` with `GAME` swapped to this player's stub. Use this wrapper around
-- every call into client-side code that reads `GAME`. The wrapper is
-- exception-safe via pcall — even if `fn` errors, the previous GAME is restored,
-- so a failing assertion in one player never leaks context into the next.
function TestPlayer:act(fn)
  local previousGame = _G.GAME
  local previousConfig = _G.config
  _G.GAME = self.gameStub
  _G.config = self.configStub
  local ok, err = pcall(fn)
  _G.GAME = previousGame
  _G.config = previousConfig
  if not ok then
    error(self.name .. ": act() failed: " .. tostring(err), 0)
  end
end

-- ----------------------------------------------------------------------------
-- High-level player operations — each is a thin wrapper around a NetClient
-- method that a real UI button would call. Wrapping them here gives scenarios
-- a tidy API but the production method is what actually runs.
-- ----------------------------------------------------------------------------

function TestPlayer:login(ip, port)
  -- NetClient:login is non-blocking; it sets state to LOGIN and runs the
  -- LoginRoutine coroutine forward on each subsequent NetClient:update().
  self:act(function() self.netClient:login(ip, port) end)
end

function TestPlayer:requestRoom(gameModeIdOrName, latencyTolerance)
  -- Lobby.lua:145 button onClick is `GAME.netClient:requestRoom(gameMode, tol)`
  -- — same call site we're hitting here, just with the ID-resolving overload.
  self:act(function() self.netClient:requestRoom(gameModeIdOrName, latencyTolerance) end)
end

function TestPlayer:joinRoom(roomNumber, slotNumber)
  self:act(function() self.netClient:requestJoinRoom(roomNumber, slotNumber) end)
end

-- Production signals ready by toggling the local Player's wantsReady + the
-- hasLoaded flag; NetClient observes those signals and sends sendPlayerSettings.
-- For tests we just push the settings directly — equivalent on the wire to
-- what the CharacterSelect "ready" button drives.
function TestPlayer:sendReady()
  self.localPlayer.settings.wantsReady = true
  self.localPlayer.hasLoaded = true
  self.localPlayer.settings.ready = true
  self.localPlayer.settings.loaded = true
  self:act(function() self.netClient:sendPlayerSettings(self.localPlayer) end)
end

function TestPlayer:sendInput(input)
  self:act(function() self.netClient:sendInput(input) end)
end

-- Loose-sync GarbageEvent — fire-and-forget JSON payload from the local sim.
-- `body` is the table the production sim hands to NetClient:sendGarbageEvent
-- (sender, senderFrame, recipients, garbage). The harness can construct
-- minimal payloads for scenario testing without running the engine.
function TestPlayer:sendGarbageEvent(body)
  self:act(function() self.netClient:sendGarbageEvent(body) end)
end

-- Loose-sync DeathEvent — same shape as the production sim's death notify.
-- Tests pass {sender, senderFrame, reason} (matches Room.lua's expectations).
function TestPlayer:sendDeathEvent(body)
  self:act(function() self.netClient:sendDeathEvent(body) end)
end

-- Notify the server we hit game_over_clock — equivalent of what
-- ClientMatch fires when the local stack dies.
function TestPlayer:sendStackEliminated(frame)
  self:act(function() self.netClient:sendStackEliminated(frame) end)
end

-- Spectate an existing room. The server replies with a spectateGranted JSON
-- message carrying the running match's replay (with crossPlayerEvents on V4+).
-- The reply is delivered through the regular addToRoom / matchStart handlers,
-- so after spectateGranted the gameStub.battleRoom + matchStarted state
-- mirrors what a regular player would see.
function TestPlayer:requestSpectate(roomNumber)
  self:act(function() self.netClient:requestSpectate(roomNumber) end)
end

function TestPlayer:leaveRoom()
  self:act(function() self.netClient:leaveRoom() end)
end

-- ----------------------------------------------------------------------------
-- The per-tick pump — harness calls this on every step
-- ----------------------------------------------------------------------------

-- Drive the NetClient state machine one step. Mirrors what main.lua's update
-- hook does in production: drain incoming messages, advance pending coroutines
-- (LoginRoutine etc.), fire listener callbacks for newly arrived JSON.
function TestPlayer:update()
  self:act(function() self.netClient:update() end)
  -- Mirror state changes the listener callbacks made into our convenience fields.
  if self.gameStub.battleRoom then
    self.roomNumber = self.gameStub.battleRoom.roomNumber
  end
  -- INGAME is set by start2pVsOnlineMatch / equivalent when matchStart fires.
  if self.netClient.state == NetClient.STATES.INGAME then
    self.matchStarted = true
  end
end

-- ----------------------------------------------------------------------------
-- State queries scenarios use as waitUntil predicates
-- ----------------------------------------------------------------------------

function TestPlayer:isLoggedIn()
  return self.netClient.state == NetClient.STATES.ONLINE
      or self.netClient.state == NetClient.STATES.ROOM
      or self.netClient.state == NetClient.STATES.INGAME
end

function TestPlayer:isInRoom()
  return self.roomNumber ~= nil
      and (self.netClient.state == NetClient.STATES.ROOM
        or self.netClient.state == NetClient.STATES.INGAME)
end

function TestPlayer:isInGame()
  return self.matchStarted or self.netClient.state == NetClient.STATES.INGAME
end

function TestPlayer:close()
  -- Best-effort: try to disconnect gracefully so the server clears the player
  -- before the next test. Wrapped because we may already be disconnected.
  pcall(function()
    self:act(function()
      if self.netClient:isConnected() then
        self.netClient.tcpClient:resetNetwork()
      end
    end)
  end)
end

return TestPlayer
