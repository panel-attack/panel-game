-- LooseSyncHarness — love2D-side engine-only test rig.
--
-- The E2E harness (server/tests/E2E/Harness.lua) drives the real server +
-- TCP clients to test wire-level scenarios. This harness sits one layer
-- under that: it owns ONE Match engine (the same engine a real client
-- runs) and gives tests the surface area to script garbage / death events
-- straight onto it, then read out a canonical state-vector for assertions.
--
-- Two engines that received the same sequence of events should reach the
-- same state-vector — that's the whole point of "loose sync". Contract /
-- matrix tests construct two LooseSyncHarness instances, drive identical
-- events through both, and assert StateVector.equal(h1:readState(), h2:readState()).
--
-- Why not just use the existing ad-hoc mocks in LooseSyncTests.lua? The
-- mocks bypass real engine arithmetic — they record receiveGarbage calls
-- on a stub. That's fine for "does the dispatcher call receiveGarbage on
-- the right slot", but it can't catch divergence in the engine's queue
-- ordering, rollback interaction, or team-mode cursor drift. This harness
-- runs the real Match.

require("client.src.globals")

local class = require("common.lib.class")
local Match = require("common.engine.Match")
local LevelPresets = require("common.data.LevelPresets")
local GeneratorSource = require("common.engine.GeneratorSource")
local TeamUtils = require("common.data.TeamUtils")
local StateVector = require("common.tests.engine.StateVector")

local DEFAULT_SEED = 12345

---@class LooseSyncHarness
---@field match Match               the engine under test
---@field teams Team[]              team layout (nil for FFA)
---@field playerCount integer
---@field garbageMode string?       "all" or "shared"
local LooseSyncHarness = class(function(self, opts)
  opts = opts or {}
  self.playerCount = opts.playerCount or 2
  self.garbageMode = opts.garbageMode  -- nil for non-team modes
  self.seed = opts.seed or DEFAULT_SEED

  -- Match rules: minimal stack-over conditions so deaths don't trigger
  -- engine-side match end before the test has a chance to assert.
  local matchRules = opts.matchRules or {
    matchEndConditions = { TEAMS_ACTIVE = 1 },
    matchWinRuleset = { { GAME_OVER_CLOCK = "HIGHEST" } },
    stackOverConditions = { HEALTH = 0 },
    stackWinConditions = {},
    stackSetupModifications = {},
    doCountdown = false,
  }

  self.match = Match(GeneratorSource(self.seed, true), matchRules)

  -- Level setup: maxHealth = infinity so test garbage doesn't accidentally
  -- kill a stack we wanted alive. Tests that *want* to kill a stack do it
  -- explicitly via :killStack(slot).
  local levelData = opts.levelData or LevelPresets.getModern(10)
  levelData.maxHealth = math.huge

  for i = 1, self.playerCount do
    local stack = self.match:createStackWithSettings(levelData, false, "controller")
    stack:setMaxRunsPerFrame(1)
    -- Pre-feed a long buffer of "do nothing" inputs so :run can advance
    -- frames without hitting an input shortage. 10k frames is generous —
    -- tests cap at much less.
    stack:receiveConfirmedInput(string.rep("A", 10000))
  end

  if opts.teamCount and opts.teamCount > 1 then
    self.teams = TeamUtils.createTeams(self.playerCount, opts.teamCount, opts.playersPerTeam)
    self.match:setTeams(self.teams)
    if self.garbageMode then
      self.match:setGarbageMode(self.garbageMode)
    end
    self.match:setupTeamGarbageTargets()
  end

  self.match:start()
end)

---Advance the engine by N frames. All stacks tick together.
---@param frames integer
function LooseSyncHarness:step(frames)
  frames = frames or 1
  local stack1 = self.match.stacks[1]
  if not stack1 then return end
  local target = stack1.clock + frames
  while stack1.clock < target do
    self.match:run()
  end
end

---Inject a G event into the engine. Mirrors what ClientMatch:_applyGarbageEventNow
---does for the recipient side of a wire event: drops garbage into each named
---recipient stack's incomingGarbage queue.
---@param body table { sender = int?, senderFrame = int?, recipients = int[], garbage = table[] }
function LooseSyncHarness:applyGarbageEvent(body)
  assert(type(body) == "table", "applyGarbageEvent: body must be table")
  assert(type(body.recipients) == "table", "applyGarbageEvent: body.recipients must be table")
  for _, recipientIndex in ipairs(body.recipients) do
    local stack = self.match.stacks[recipientIndex]
    if stack and stack.receiveGarbage then
      -- Shallow-copy each garbage piece per recipient so any in-engine
      -- mutation by one recipient (e.g. chain-flag rewrite) doesn't leak
      -- into another recipient's queue. Mirrors ClientMatch's behavior.
      local copy = {}
      if type(body.garbage) == "table" then
        for i, g in ipairs(body.garbage) do
          local piece = {}
          for k, v in pairs(g) do piece[k] = v end
          copy[i] = piece
        end
      end
      stack:receiveGarbage(copy)
    end
  end
end

---Mark a stack as game-over at the current clock. Mirrors the "I just lost"
---path so dead-recipient redirect logic + arbitration tests can be exercised
---without simulating actual stack death.
---@param slot integer 1-based stack index
function LooseSyncHarness:killStack(slot)
  local stack = self.match.stacks[slot]
  if not stack then return end
  -- BaseStack: setGameOver pins game_over_clock to self.clock. game_ended()
  -- then gates on `game_over_clock > 0`, so dying at frame 0 doesn't register
  -- as dead. Tick one frame first to push the clock to 1 if needed; tests
  -- usually advance the engine before killing, but harness callers don't
  -- have to remember this.
  if (stack.clock or 0) <= 0 then
    self:step(1)
  end
  if stack.health ~= nil then stack.health = 0 end
  if stack.setGameOver then stack:setGameOver() end
end

---Read a canonical state-vector for this engine.
---@return table state-vector (see StateVector.lua)
function LooseSyncHarness:readState()
  return StateVector.fromMatch(self.match)
end

---@return string deterministic hash of readState()
function LooseSyncHarness:hash()
  return StateVector.hash(self:readState())
end

---Tear down. Currently a no-op (Match has no socket/file handles), but
---tests should call it so future cleanup needs don't require revisiting
---every test site.
function LooseSyncHarness:teardown()
  -- placeholder
end

return LooseSyncHarness
