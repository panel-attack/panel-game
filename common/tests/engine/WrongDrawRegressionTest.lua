-- WrongDrawRegressionTest.lua
--
-- Regression for the 2026-05-13 incident: a 2v2 team_vs_all match
-- ended with a "draw" UI state even though one team was clearly dead
-- and the other had a survivor.
--
-- Captured trace (slot / publicId / final state):
--   slot 1 / Lala  / publicId  7 — never died
--   slot 2 / Bevy  / publicId 11 — dead at frame 2407
--   slot 3 / Koozie / publicId  5 — dead at frame 3414
--   slot 4 / Amber  / publicId  8 — dead at frame 7531
-- garbageFlows {1,2}↔{3,4} → teams: {Lala,Bevy} vs {Koozie,Amber}.
-- Team {3,4} fully eliminated → team {1,2} should win, not draw.
--
-- This test exercises Match:getWinners() under the GAME_OVER_CLOCK
-- "HIGHEST" rule with a real-game state vector. We don't need to run
-- the engine — getWinners() is a pure function of stack state, and
-- the bug lives in how it handles stacks with negative game_over_clock
-- (i.e. survivors). Build the post-match state directly from the
-- replay's crossPlayerEvents.deaths and assert on the winners.
--
-- Fixture built from real server traces via:
--   luajit tools/server_trace_to_fixture.lua wrong_draw_2026_05_13 \
--     trace_archive/{5,7,8,11}/session_<latest>.jsonl

require("client.src.globals")

local logger    = require("common.lib.logger")
local fileUtils = require("client.src.FileUtils")
local Match     = require("common.engine.Match")
local ReplayV3  = require("common.data.ReplayV3")
local TeamUtils = require("common.data.TeamUtils")

local FIXTURE_PATH = "common/tests/fixtures/crash_replays/wrong_draw_2026_05_13.json"

local function loadReplayFromFixture(path)
  local raw = fileUtils.readJsonFile(path)
  assert(raw, "fixture missing or unreadable: " .. path)
  -- Any perspective works — they all share the canonical replay.
  local _, slice = next(raw.perspectives)
  assert(slice and slice.replay, "fixture has no perspective.replay")
  return ReplayV3.createFromV3Data(slice.replay)
end

-- Reproduce the exact post-match stack state the live game ended in:
-- each death event recorded in crossPlayerEvents stamps its sender's
-- stack with game_over_clock = senderFrame. Survivors stay at the
-- engine's initial -1 sentinel.
local function applyRecordedDeaths(match, replay)
  local applied = 0
  for _, ev in ipairs(replay.crossPlayerEvents.deaths or {}) do
    local stack = match.stacks[ev.sender]
    assert(stack, "death event names slot " .. tostring(ev.sender)
      .. " but match has only " .. #match.stacks .. " stacks")
    -- recordDeath asserts on game_over_clock collisions; if the engine
    -- has already auto-set one for this stack via Match:start (it
    -- shouldn't, since start doesn't run frames), reset first.
    stack.game_over_clock = -1
    stack:recordDeath(ev.senderFrame)
    applied = applied + 1
  end
  return applied
end

local function teamModeFromReplay(replay)
  -- 4 stacks, 2 teams, 2 per team. Both team_vs_all and team_vs_shared
  -- use this layout — the difference is garbage distribution, which
  -- doesn't affect win determination.
  local mode = replay.metadata.gameModeName
  assert(mode == "team_vs_all" or mode == "team_vs_shared",
    "fixture is " .. tostring(mode) .. ", expected a 2v2 team mode")
  return TeamUtils.createTeams(#replay.stacks, 2, 2)
end

local function test_wrong_draw_should_be_team_1_2_win()
  logger.info("test_wrong_draw_should_be_team_1_2_win")

  local replay = loadReplayFromFixture(FIXTURE_PATH)
  local match  = Match.createFromReplay(replay)

  -- Match.createFromReplay sets fromReplay=true, which makes
  -- evaluateEndConditions require stacks to literally simulate to their
  -- death frame before counting them as "done". The live behavior
  -- (loose-sync bypass: game_over_clock > 0 is enough) is what we want
  -- to mirror — the live match ended via this path, and the bug we're
  -- chasing fired in this regime.
  match.fromReplay = false

  -- Match.createFromReplay doesn't carry team setup; without teams the
  -- TEAMS_ACTIVE end-condition check short-circuits and the wrong-draw
  -- path can't be reached. Restore them from the gameModeName metadata.
  match:setTeams(teamModeFromReplay(replay))

  match:start()

  local applied = applyRecordedDeaths(match, replay)
  assert(applied >= 2, "fixture should carry at least 2 death events; got " .. applied)

  -- Diagnostic: dump the post-death state so a failure message shows
  -- exactly what getWinners() saw.
  for i, stack in ipairs(match.stacks) do
    logger.info(string.format("  slot %d: game_over_clock=%s",
      i, tostring(stack.game_over_clock)))
  end

  -- evaluateEndConditions() is a precondition for getWinners() running
  -- in production. Log its verdict for diagnostic purposes — but DO NOT
  -- assert on it here. evaluateEndConditions has its own clock-catchup
  -- gate ("all stacks past gameOverClock") that won't fire in this
  -- synthetic test since we never simulate forward; that's a separate
  -- concern from the getWinners() bug we're isolating.
  local result = match:evaluateEndConditions()
  logger.info("  evaluateEndConditions: ended=" .. tostring(result.ended)
    .. " reason=" .. tostring(result.reason))

  local winners = match:getWinners()
  local winnerSlots = {}
  for _, w in ipairs(winners) do
    winnerSlots[#winnerSlots + 1] = w.which or w.player_number
  end
  table.sort(winnerSlots)
  local label = "winners: [" .. table.concat(winnerSlots, ",") .. "]"
  logger.info("  " .. label)

  assert(#winners > 0, "no winners — match never resolved")
  assert(#winners < #match.stacks,
    label .. " — every stack listed as a winner means the match was declared "
    .. "a draw. Expected team {1,2} (Lala/Bevy) to win since team {3,4} "
    .. "(Koozie/Amber) is fully dead.")

  for _, slot in ipairs(winnerSlots) do
    assert(slot == 1 or slot == 2,
      label .. " — slot " .. tostring(slot) .. " is on the dead team "
      .. "(team {3,4}) and should not be a winner.")
  end
end

-- ----------------------------------------------------------------------
-- Part 2: GameBase.buildTeamResultText survives every winner shape
--
-- The display layer (`GameBase.buildTeamResultText`) decides the
-- final-screen text from the winners list. Different upstream callers
-- hand it different *shapes* — a Player object (`ClientMatch:getWinners`),
-- a PlayerStack wrapper, or a raw engine Stack (`Match:getWinners` on a
-- bare engine). The original code compared by identity (`player == winner`);
-- only one shape happened to match, the other paths silently fell through
-- to "DRAW". Lock all three shapes here so a future caller-shape change
-- can't reintroduce the wrong-draw UI bug.
-- ----------------------------------------------------------------------

local GameBase = require("client.src.scenes.GameBase")
local GameModes = require("common.data.GameModes")

-- shared with Part 3 below
GameBase = GameBase

-- Build the minimal match-shape buildTeamResultText reads. It only
-- touches gameMode.stackInteraction/playersPerTeam, players[i].playerNumber,
-- players[i].isLocal, and players[i].stack — so we don't need a real
-- ClientMatch.
local function fakeMatchAndPlayers()
  local players = {}
  for slot = 1, 4 do
    players[slot] = {
      playerNumber = slot,
      name = "P" .. slot,
      isLocal = (slot == 1),  -- pretend Lala is the local viewer
      stack = nil,             -- filled below
    }
  end
  -- PlayerStack-shape wrapper: has .player + .engine
  local engineStacks = {}
  for slot = 1, 4 do
    engineStacks[slot] = { which = slot, name = "S" .. slot }
    players[slot].stack = { player = players[slot], engine = engineStacks[slot] }
  end
  local match = {
    players = players,
    gameMode = {
      stackInteraction = GameModes.StackInteractions.TEAM_VERSUS,
      playersPerTeam = 2,
    },
  }
  return match, players, engineStacks
end

local function test_buildTeamResultText_player_winners()
  logger.info("test_buildTeamResultText_player_winners (ClientMatch:getWinners shape)")
  local match, players = fakeMatchAndPlayers()
  -- Lala (slot 1, local) wins — that's a "YOUR TEAM WINS" since Bevy
  -- (slot 2) is on the same team and the local viewer is slot 1.
  local result = GameBase.buildTeamResultText(match, { players[1] })
  assert(result == "YOUR TEAM WINS",
    "Player-shape winner: expected 'YOUR TEAM WINS', got " .. tostring(result))
end

local function test_buildTeamResultText_wrapper_winners()
  logger.info("test_buildTeamResultText_wrapper_winners (PlayerStack wrapper shape)")
  local match, players = fakeMatchAndPlayers()
  local result = GameBase.buildTeamResultText(match, { players[1].stack })
  assert(result == "YOUR TEAM WINS",
    "PlayerStack-shape winner: expected 'YOUR TEAM WINS', got " .. tostring(result))
end

local function test_buildTeamResultText_engine_stack_winners()
  logger.info("test_buildTeamResultText_engine_stack_winners (raw Stack shape)")
  local match, players, engineStacks = fakeMatchAndPlayers()
  local result = GameBase.buildTeamResultText(match, { engineStacks[1] })
  assert(result == "YOUR TEAM WINS",
    "engine-Stack-shape winner: expected 'YOUR TEAM WINS', got " .. tostring(result))
end

local function test_buildTeamResultText_actual_draw()
  logger.info("test_buildTeamResultText_actual_draw")
  local match, players = fakeMatchAndPlayers()
  -- Both teams have a winner — that's a real draw (each team contributed).
  local result = GameBase.buildTeamResultText(match, { players[1], players[3] })
  assert(result == "DRAW",
    "Both teams winning is a draw: expected 'DRAW', got " .. tostring(result))
end

-- ----------------------------------------------------------------------
-- Part 3: full ClientMatch flow — what production actually does
--
-- The synthetic Player/wrapper/Stack tests above only prove the resolver
-- handles all input shapes. They do NOT prove the live "DRAW" UI bug
-- reproduces from the trace. To confirm reproduction, drive the *real*
-- ClientMatch: build it from the replay (gives Players + team setup +
-- pendingHistoricalDeaths preload), drain the historical events as
-- ClientMatch:run does, then call ClientMatch:getWinners — the same
-- shape buildTeamResultText sees in production.
--
-- Goal: this assertion fails IF AND ONLY IF the live UI would also
-- show "DRAW" for this game. If it passes today, that means the trace
-- alone is insufficient to repro — the bug is caused by something the
-- trace doesn't capture (timing race, message-arrival ordering, etc.).
-- That outcome is itself information: it tells us the next step is
-- the instrumented logging in setupGameOver, not more trace work.
-- ----------------------------------------------------------------------

local function test_full_clientmatch_flow_reproduces_or_doesnt()
  logger.info("test_full_clientmatch_flow_reproduces_or_doesnt")

  local ClientMatch = require("client.src.ClientMatch")
  local replay = loadReplayFromFixture(FIXTURE_PATH)

  -- ClientMatch.createFromReplay rebuilds Players from metadata, wires
  -- gameMode + teams from gameModeName, and preloads
  -- pendingHistoricalDeaths/Garbage from crossPlayerEvents. This is the
  -- same path the live spectate/rejoin flow uses.
  local clientMatch = ClientMatch.createFromReplay(replay)
  clientMatch:start()

  -- Drain pending historical events as the engine catches up. We mirror
  -- ClientMatch:run's drainPendingHistoricalEvents behavior in a tight
  -- loop instead of going through the full ClientMatch:run (which pulls
  -- in graphics/sound/render hooks the test env doesn't need).
  --
  -- Use loose-sync semantics so a stack with game_over_clock > 0 counts
  -- as done without requiring its own clock to literally catch up —
  -- matches how live treats a remote stack that stopped sending inputs.
  clientMatch.engine.fromReplay = false

  -- Bound the loop. The captured suspect frame is ~8131; allow 3x as
  -- slack for engine convergence after death events.
  local maxFrames = 8131 * 3
  local frame = 0
  while not clientMatch.engine:isLocallyEnded() do
    -- Apply every pending historical event whose sender's stopWatch has
    -- reached senderFrame, OR whose sender's game_over_clock is already
    -- set (so dead stacks don't deadlock waiting for their own clock).
    -- Same "ready" predicate as ClientMatch:drainPendingHistoricalEvents.
    local kept = {}
    for _, ev in ipairs(clientMatch.pendingHistoricalDeaths or {}) do
      local senderStack = clientMatch.engine.stacks[ev.sender]
      local ready = false
      if not senderStack then
        ready = true
      else
        local senderFrame = ev.senderFrame or 0
        if (senderStack.stopWatch or 0) >= senderFrame then ready = true
        elseif senderStack.game_over_clock and senderStack.game_over_clock > 0 then ready = true
        elseif senderStack.clock and senderStack.clock >= #senderStack.confirmedInput then
          -- Sender ran out of inputs — treat the death as ready so the
          -- match can resolve. Without this the loose-sync deadlock the
          -- ClientMatch:applyDeathEvent comment describes (Amber/Bev/
          -- Koozie) re-fires here.
          ready = true
        end
      end
      if ready then
        local stack = clientMatch.stacks[ev.sender]
        if stack and stack.engine then
          if stack.engine.game_over_clock <= 0 then
            stack.engine:recordDeath(ev.senderFrame)
          end
        end
      else
        kept[#kept + 1] = ev
      end
    end
    clientMatch.pendingHistoricalDeaths = kept

    clientMatch.engine:run()
    frame = frame + 1
    if frame >= maxFrames then break end
  end

  -- Diagnostic dump
  for i, stack in ipairs(clientMatch.engine.stacks) do
    logger.info(string.format("  slot %d: clock=%s game_over_clock=%s",
      i, tostring(stack.clock), tostring(stack.game_over_clock)))
  end

  local engineEnded = clientMatch.engine:isLocallyEnded()
  logger.info("  engine isLocallyEnded after " .. frame .. " frames: "
    .. tostring(engineEnded))

  -- Force-finalize so getWinners has cached state. In live this fires
  -- via shouldFinalize → handleMatchEnd; we mimic it directly because
  -- the test doesn't drive _serverConfirmedEnd.
  clientMatch.engine:handleMatchEnd()
  clientMatch.engine.ended = true   -- so ClientMatch:getWinners' isLocallyEnded gate passes
  local winners = clientMatch:getWinners()

  local winnerLabels = {}
  for i, w in ipairs(winners) do
    winnerLabels[i] = string.format("[%d type=%s name=%s playerNumber=%s which=%s]",
      i, type(w),
      tostring(w.name or (w.player and w.player.name)),
      tostring(w.playerNumber),
      tostring(w.which))
  end
  logger.info("  ClientMatch:getWinners returned " .. #winners
    .. " winner(s): " .. table.concat(winnerLabels, ", "))

  -- Now the actual UI check.
  local resultText = GameBase.buildTeamResultText(clientMatch, winners)
  logger.info("  buildTeamResultText: " .. tostring(resultText))

  if resultText == "DRAW" then
    error("REPRODUCED the live wrong-draw UI bug from the trace — "
      .. "buildTeamResultText returned 'DRAW' even though one team "
      .. "should clearly have won. This is the test that proves the "
      .. "fix actually fixes the live behavior.")
  end

  -- Otherwise: confirm we got SOMETHING sensible (the spectator string
  -- since createFromReplay sets isLocal=false on all reconstructed
  -- Players → no localTeam, so we expect "Team A wins" or "Team B wins").
  assert(resultText == "Team A wins" or resultText == "Team B wins",
    "expected 'Team A wins' or 'Team B wins', got " .. tostring(resultText)
    .. " (winners: " .. #winners .. ")")
end

test_wrong_draw_should_be_team_1_2_win()
test_buildTeamResultText_player_winners()
test_buildTeamResultText_wrapper_winners()
test_buildTeamResultText_engine_stack_winners()
test_buildTeamResultText_actual_draw()
test_full_clientmatch_flow_reproduces_or_doesnt()
logger.info("WrongDrawRegressionTest: passed")
