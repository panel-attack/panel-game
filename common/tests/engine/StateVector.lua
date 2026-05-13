-- StateVector — canonical snapshot of loose-sync engine + server state.
--
-- The motivation: contract / matrix tests assert that two engines (or an
-- engine and the server's view of the world) agree on the things loose-sync
-- is supposed to keep in sync — per-stack incoming garbage counts, death
-- timing, round-robin cursor positions, arbitration deaths. Each side
-- exposes that state at different field names; this module is the single
-- adapter that produces one comparable shape.
--
-- Output shape:
--   {
--     stacks = { [i] = { game_over_clock = int?, incomingGarbageCount = int? } },
--     teamGarbage = { [senderIndex] = { currentTargetIndex = int } },  -- engine only
--     arbitrationDeaths = { { slot = int, senderFrame = int }, ... },  -- server only
--   }
--
-- Three entrypoints:
--   StateVector.fromMatch(match)      love2D-side Match engine (LooseSyncHarness, ClientMatch)
--   StateVector.fromStacks(stacks)    bare-array variant for the makeMatchWithStacks-shaped
--                                     mocks used by existing LooseSyncTests.lua
--   StateVector.fromRoom(room)        server-side Room (E2E Harness)
--
-- Plus:
--   StateVector.hash(vec)             deterministic string for equality assertions
--   StateVector.equal(a, b)           semantic equality
--
-- Tests pick which fields they care about. Cross-shape comparisons
-- (engine vs server) are meaningful for the shared keys: `game_over_clock`
-- and `incomingGarbageCount`. The other tables are scope-specific by design.

local M = {}

-- Stack-shape adapter: engine stacks live behind a wrapper in some test
-- contexts (stack.engine.X) and directly on the table in others (stack.X).
-- Read through whichever owns the loose-sync fields.
local function readStackFields(stack)
  local engine = stack.engine or stack
  local incoming = engine.incomingGarbage
  local incomingCount
  if incoming then
    -- Prefer GarbageQueue.history (the cumulative "everything ever pushed"
    -- log) over stagedGarbage. stagedGarbage drops to 0 once pieces have
    -- landed on the playfield, which would make a state-vector taken after
    -- match:run() falsely show "no garbage received". For loose-sync the
    -- invariant is "did you receive it ever", not "is it still in queue".
    if type(incoming) == "table" and incoming.history then
      incomingCount = #incoming.history
    elseif type(incoming) == "table" and incoming.stagedGarbage then
      incomingCount = #incoming.stagedGarbage
    end
  end
  if incomingCount == nil and engine.receivedGarbage then
    incomingCount = #engine.receivedGarbage
  end
  return {
    game_over_clock = engine.game_over_clock,
    incomingGarbageCount = incomingCount,
  }
end

---Read a state-vector from a love2D-side Match engine.
---@param match table real Match (has match.stacks, match.teamGarbageState?)
function M.fromMatch(match)
  local vec = { stacks = {}, teamGarbage = {} }
  for i, stack in ipairs(match.stacks) do
    vec.stacks[i] = readStackFields(stack)
  end
  if match.teamGarbageState then
    for senderIndex, state in pairs(match.teamGarbageState) do
      vec.teamGarbage[senderIndex] = {
        currentTargetIndex = state.currentTargetIndex,
      }
    end
  end
  return vec
end

---Read a state-vector from a bare stacks array (the LooseSyncTests.lua mock shape).
---@param stacks table[]
function M.fromStacks(stacks)
  local vec = { stacks = {}, teamGarbage = {} }
  for i, stack in ipairs(stacks) do
    vec.stacks[i] = readStackFields(stack)
  end
  return vec
end

---Read a state-vector from a server-side Room. Counts G events per recipient
---from room.game.garbageEvents (the server-side ground truth), surfaces
---eliminatedPlayers as game_over_clock (-1 if alive), and copies the in-flight
---arbitrationDeaths buffer.
---@param room table
function M.fromRoom(room)
  local vec = { stacks = {}, teamGarbage = {}, arbitrationDeaths = {} }

  local game = room.game
  if game then
    -- Initialize a per-slot accumulator. room.players is sparse on mid-match
    -- leaves; iterate via pairs and remember the max slot so we can fill in
    -- the gaps with default rows (incomingGarbageCount = 0, alive).
    local maxSlot = 0
    for slot in pairs(room.players or {}) do
      if slot > maxSlot then maxSlot = slot end
    end
    -- eliminatedPlayers is also keyed by slot.
    for slot in pairs(game.eliminatedPlayers or {}) do
      if slot > maxSlot then maxSlot = slot end
    end
    -- garbage events count toward recipient slots.
    for _, ev in ipairs(game.garbageEvents or {}) do
      if type(ev.recipients) == "table" then
        for _, r in ipairs(ev.recipients) do
          if r > maxSlot then maxSlot = r end
        end
      end
    end

    for i = 1, maxSlot do
      vec.stacks[i] = {
        game_over_clock = -1,
        incomingGarbageCount = 0,
      }
    end

    for _, ev in ipairs(game.garbageEvents or {}) do
      if type(ev.recipients) == "table" then
        for _, r in ipairs(ev.recipients) do
          local s = vec.stacks[r]
          if s then s.incomingGarbageCount = s.incomingGarbageCount + 1 end
        end
      end
    end

    for slot, frame in pairs(game.eliminatedPlayers or {}) do
      local s = vec.stacks[slot]
      if s then
        -- eliminatedPlayers stores the death frame as the value; treat it as
        -- the game_over_clock equivalent so engine-vs-server compares work.
        s.game_over_clock = (type(frame) == "number") and frame or 0
      end
    end
  end

  for i, death in ipairs(room.arbitrationDeaths or {}) do
    vec.arbitrationDeaths[i] = {
      slot = death.slot,
      senderFrame = death.senderFrame,
    }
  end

  return vec
end

---Deterministic string hash of a vector. Walks keys in sorted order so two
---semantically-equal vectors with different table-iteration orders produce
---identical strings. Compare via equality.
---@param vec table state vector as produced by from* above
---@return string
function M.hash(vec)
  local parts = {}

  parts[#parts + 1] = "stacks:"
  for i = 1, #vec.stacks do
    local s = vec.stacks[i]
    parts[#parts + 1] = string.format("[%d goc=%s inc=%s]",
      i,
      tostring(s and s.game_over_clock),
      tostring(s and s.incomingGarbageCount))
  end

  if vec.teamGarbage then
    local senders = {}
    for k in pairs(vec.teamGarbage) do senders[#senders + 1] = k end
    table.sort(senders)
    parts[#parts + 1] = "|tg:"
    for _, k in ipairs(senders) do
      parts[#parts + 1] = string.format("[%d cur=%s]",
        k, tostring(vec.teamGarbage[k].currentTargetIndex))
    end
  end

  if vec.arbitrationDeaths and #vec.arbitrationDeaths > 0 then
    parts[#parts + 1] = "|ad:"
    for _, d in ipairs(vec.arbitrationDeaths) do
      parts[#parts + 1] = string.format("[s=%s sf=%s]",
        tostring(d.slot), tostring(d.senderFrame))
    end
  end

  return table.concat(parts)
end

---@param a table
---@param b table
---@return boolean
function M.equal(a, b)
  return M.hash(a) == M.hash(b)
end

return M
