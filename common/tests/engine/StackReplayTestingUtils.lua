local logger = require("common.lib.logger")
local GameModes = require("common.data.GameModes")
local Match = require("common.engine.Match")
local fileUtils = require("client.src.FileUtils")
local LevelPresets = require("common.data.LevelPresets")
local GeneratorSource = require("common.engine.GeneratorSource")
local ReplayV3 = require("common.data.ReplayV3")

local StackReplayTestingUtils = {}

---@param path string
---@return Match match
---@return number timeElapsed
function StackReplayTestingUtils:simulateReplayWithPath(path)
  local match = self:setupReplayWithPath(path)
  return self:fullySimulateMatch(match)
end

---@return Match
function StackReplayTestingUtils.createEndlessMatch(speed, difficulty, level, playerCount)
  local endless = GameModes.getPreset(GameModes.IDs.ONE_PLAYER_ENDLESS)
  if playerCount == nil then
    playerCount = 1
  end

  local match = Match(GeneratorSource(1, false), endless.matchRules)

  local levelData
  if level then
    levelData = LevelPresets.getModern(level)
  else
    levelData = LevelPresets.getClassic(difficulty)
    levelData.startingSpeed = speed
  end
  for i = 1, playerCount do
    match:createStackWithSettings(levelData, false, "controller")
  end

  match:start()

  for i = 1, #match.stacks do
    match.stacks[i]:setMaxRunsPerFrame(1)
  end

  return match
end

---@return Match
function StackReplayTestingUtils.createSinglePlayerMatch(gameMode, panelSource, inputMethod, levelData)
  if not panelSource then
    local enableShock = (gameMode.stackInteraction ~= GameModes.StackInteractions.NONE)
    panelSource = GeneratorSource(1, enableShock)
  end
  local match = Match(panelSource, gameMode.matchRules)
  match:createStackWithSettings(levelData or LevelPresets.getModern(5), false, inputMethod or "controller")

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
    assert(#match.stacks[1].confirmedInput > match.stacks[1].clock)
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
  local replay = ReplayV3.createFromTable(fileUtils.readJsonFile(path), true)
  local match = Match.createFromReplay(replay)
  match:start()
  -- we want to be able to stop with precision so cap the number of runs
  for i, stack in ipairs(match.stacks) do
    stack:setMaxRunsPerFrame(1)
  end

  assert(match ~= nil)
  assert(match.stacks[1])

  return match
end

function StackReplayTestingUtils:cleanup(match)

end

return StackReplayTestingUtils