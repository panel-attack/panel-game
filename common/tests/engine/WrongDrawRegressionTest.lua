-- Regression for the 2026-05-13 wrong-draw incident. Built from the
-- captured Bevy/Koozie/Lala/Amber team_vs_all match where one team
-- was fully eliminated but the UI showed "DRAW".
--
-- Fixture is built from server traces:
--   luajit tools/server_trace_to_fixture.lua wrong_draw_2026_05_13 \
--     trace_archive/{5,7,8,11}/session_<latest>.jsonl

require("client.src.globals")

local logger    = require("common.lib.logger")
local fileUtils = require("client.src.FileUtils")
local Match     = require("common.engine.Match")
local ReplayV3  = require("common.data.ReplayV3")
local TeamUtils = require("common.data.TeamUtils")
local GameBase  = require("client.src.scenes.GameBase")
local GameModes = require("common.data.GameModes")

local FIXTURE_PATH = "common/tests/fixtures/crash_replays/wrong_draw_2026_05_13.json"

local function loadReplayFromFixture(path)
  local raw = fileUtils.readJsonFile(path)
  assert(raw, "fixture missing or unreadable: " .. path)
  local _, slice = next(raw.perspectives)
  assert(slice and slice.replay, "fixture has no perspective.replay")
  return ReplayV3.createFromV3Data(slice.replay)
end

local function applyRecordedDeaths(match, replay)
  local applied = 0
  for _, ev in ipairs(replay.crossPlayerEvents.deaths or {}) do
    local stack = match.stacks[ev.sender]
    assert(stack, "death event names slot " .. tostring(ev.sender)
      .. " but match has only " .. #match.stacks .. " stacks")
    stack.game_over_clock = -1
    stack:recordDeath(ev.senderFrame)
    applied = applied + 1
  end
  return applied
end

local function teamModeFromReplay(replay)
  local mode = replay.metadata.gameModeName
  assert(mode == "team_vs_all" or mode == "team_vs_shared",
    "fixture is " .. tostring(mode) .. ", expected a 2v2 team mode")
  return TeamUtils.createTeams(#replay.stacks, 2, 2)
end

----------------------------------------------------------------------
-- Engine getWinners returns the surviving team for the trace state
----------------------------------------------------------------------

local function test_wrong_draw_should_be_team_1_2_win()
  logger.info("test_wrong_draw_should_be_team_1_2_win")

  local replay = loadReplayFromFixture(FIXTURE_PATH)
  local match  = Match.createFromReplay(replay)

  -- Mirror live (non-replay) end-condition semantics so game_over_clock>0
  -- counts as done without requiring engine clock catch-up.
  match.fromReplay = false
  match:setTeams(teamModeFromReplay(replay))
  match:start()

  local applied = applyRecordedDeaths(match, replay)
  assert(applied >= 2, "fixture should carry at least 2 death events; got " .. applied)

  local winners = match:getWinners()
  local winnerSlots = {}
  for _, w in ipairs(winners) do
    winnerSlots[#winnerSlots + 1] = w.which or w.player_number
  end
  table.sort(winnerSlots)
  local label = "winners: [" .. table.concat(winnerSlots, ",") .. "]"

  assert(#winners > 0, "no winners — match never resolved")
  assert(#winners < #match.stacks,
    label .. " — every stack listed as winner means a draw. "
    .. "Expected team {1,2} (Lala/Bevy) to win.")
  for _, slot in ipairs(winnerSlots) do
    assert(slot == 1 or slot == 2,
      label .. " — slot " .. tostring(slot) .. " is on the dead team.")
  end
end

----------------------------------------------------------------------
-- buildTeamResultText accepts every winner shape the codebase produces
----------------------------------------------------------------------

local function fakeMatchAndPlayers()
  local players = {}
  for slot = 1, 4 do
    players[slot] = {
      playerNumber = slot,
      name = "P" .. slot,
      isLocal = (slot == 1),
      stack = nil,
    }
  end
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
  logger.info("test_buildTeamResultText_player_winners")
  local match, players = fakeMatchAndPlayers()
  local result = GameBase.buildTeamResultText(match, { players[1] })
  assert(result == "YOUR TEAM WINS", "got " .. tostring(result))
end

local function test_buildTeamResultText_wrapper_winners()
  logger.info("test_buildTeamResultText_wrapper_winners")
  local match, players = fakeMatchAndPlayers()
  local result = GameBase.buildTeamResultText(match, { players[1].stack })
  assert(result == "YOUR TEAM WINS", "got " .. tostring(result))
end

local function test_buildTeamResultText_engine_stack_winners()
  logger.info("test_buildTeamResultText_engine_stack_winners")
  local match, _, engineStacks = fakeMatchAndPlayers()
  local result = GameBase.buildTeamResultText(match, { engineStacks[1] })
  assert(result == "YOUR TEAM WINS", "got " .. tostring(result))
end

local function test_buildTeamResultText_actual_draw()
  logger.info("test_buildTeamResultText_actual_draw")
  local match, players = fakeMatchAndPlayers()
  local result = GameBase.buildTeamResultText(match, { players[1], players[3] })
  assert(result == "DRAW", "got " .. tostring(result))
end

test_wrong_draw_should_be_team_1_2_win()
test_buildTeamResultText_player_winners()
test_buildTeamResultText_wrapper_winners()
test_buildTeamResultText_engine_stack_winners()
test_buildTeamResultText_actual_draw()
logger.info("WrongDrawRegressionTest: passed")
