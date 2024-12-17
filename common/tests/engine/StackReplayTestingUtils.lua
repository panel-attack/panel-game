local logger = require("common.lib.logger")
local GameModes = require("common.engine.GameModes")
local Match = require("common.engine.Match")
local fileUtils = require("client.src.FileUtils")
local Replay = require("common.data.Replay")
local LevelPresets = require("common.data.LevelPresets")
local Stack = require("common.engine.Stack")
require("common.engine.checkMatches")

local StackReplayTestingUtils = {}

function StackReplayTestingUtils:simulateReplayWithPath(path)
  local match = self:setupReplayWithPath(path)
  return self:fullySimulateMatch(match)
end

function StackReplayTestingUtils.createEndlessMatch(speed, difficulty, level, playerCount)
  local endless = GameModes.getPreset("ONE_PLAYER_ENDLESS")
  if playerCount == nil then
    playerCount = 1
  end
  local stacks = {}
  for i = 1, playerCount do
    local args = {
      which = i,
      stackInteraction = endless.stackInteraction,
      gameOverConditions = endless.gameOverConditions,
      is_local = false,
      allowAdjacentColors = true
    }

    if level then
      args.levelData = LevelPresets.getModern(level)
    else
      args.levelData = LevelPresets.getClassic(difficulty)
      args.levelData.startingSpeed = speed
    end
    stacks[i] = Stack(args)
  end

  local match = Match(stacks, endless.doCountdown, endless.stackInteraction, endless.winConditions, endless.gameOverConditions)
  match:setSeed(1)
  match:start()

  for i = 1, #match.stacks do
    match.stacks[i]:setMaxRunsPerFrame(1)
  end

  return match
end

function StackReplayTestingUtils.createSinglePlayerMatch(gameMode)
  local args = {
    which = 1,
    stackInteraction = gameMode.stackInteraction,
    gameOverConditions = gameMode.gameOverConditions,
    is_local = false,
    levelData = LevelPresets.getModern(5),
    allowAdjacentColors = true,
  }
  local stacks = { Stack(args) }

  local match = Match(stacks, gameMode.doCountdown, gameMode.stackInteraction, gameMode.winConditions, gameMode.gameOverConditions)
  match:setSeed(1)
  match:start()

  for i = 1, #match.stacks do
    match.stacks[i]:setMaxRunsPerFrame(1)
  end

  return match
end

function StackReplayTestingUtils:fullySimulateMatch(match)
  local startTime = love.timer.getTime()

  while not match:hasEnded() do
    match:run()
  end
  local endTime = love.timer.getTime()

  return match, endTime - startTime
end

function StackReplayTestingUtils:simulateStack(stack, clockGoal)
  while stack.clock < clockGoal do
    stack:run()
    stack:saveForRollback()
  end
  assert(stack.clock == clockGoal)
end

function StackReplayTestingUtils:simulateMatchUntil(match, clockGoal)
  assert(match.stacks[1].is_local == false, "Don't use 'local' for tests, we might simulate the clock time too much if local")
  while match.stacks[1].clock < clockGoal do
    assert(not match:hasEnded(), "Game isn't expected to end yet")
    assert(#match.stacks[1].input_buffer > 0)
    match:run()
  end
  assert(match.stacks[1].clock == clockGoal)
end

-- Runs the given clock time both with and without rollback
function StackReplayTestingUtils:simulateMatchWithRollbackAtClock(match, clock)
  StackReplayTestingUtils:simulateMatchUntil(match, clock)
  match:debugRollbackAndCaptureState(clock-1)
  StackReplayTestingUtils:simulateMatchUntil(match, clock)
end

function StackReplayTestingUtils:setupReplayWithPath(path)
  GAME.muteSound = true

  local replay = Replay.createFromTable(fileUtils.readJsonFile(path), true)
  local match = Match.createFromReplay(replay)
  match:start()
  -- we want to be able to stop with precision so cap the number of runs
  for i, stack in ipairs(match.stacks) do
    stack:setMaxRunsPerFrame(1)
  end

  assert(GAME ~= nil)
  assert(match ~= nil)
  assert(match.stacks[1])

  return match
end

function StackReplayTestingUtils:cleanup(match)

end

return StackReplayTestingUtils