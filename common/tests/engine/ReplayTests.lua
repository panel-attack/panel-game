local StackReplayTestingUtils = require("common.tests.engine.StackReplayTestingUtils")
local InputCompression = require("common.data.InputCompression")
local ReplayV3 = require("common.data.ReplayV3")
local MatchRules = require("common.data.MatchRules")
local Puzzle = require("common.engine.Puzzle")
local json = require("common.lib.dkjson")


local function endlessSaveTest()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10)
  local stack = match.stacks[1]
  assert(stack ~= nil)
  ---@cast stack Stack
  local puzzleString = Puzzle.toPuzzleString(stack.panels):sub(-36)
  assert(puzzleString == "350000540056256135534246123164452652")
  stack:receiveConfirmedInput(string.rep(stack:idleInput(), 909))
  local replay = match:createNewReplay()
  StackReplayTestingUtils:fullySimulateMatch(match)

  assert(match ~= nil)
  assert(match.timeLimit == nil)
  assert(match.panelSource.seed == 1)
  assert(stack.game_over_clock == 908)

  ReplayV3.finalizeReplay(match, replay)
  local replayJSON = json.encode(replay)

  assert(replay ~= nil)
  assert(replay.stacks[1].inputs == "A909")
  assert(replayJSON ~= nil)
  assert(type(replayJSON) == "string")
  StackReplayTestingUtils:cleanup(match)
end

endlessSaveTest()

-- json writes a sparse table whose highest key is over 10 as an object with string keys
local function goalSizesAboveTenSurviveASavedReplay()
  local rules = {
    stackWinConditions = {
      [MatchRules.StackWinConditions.CHAINS] = {[14] = 1},
      [MatchRules.StackWinConditions.COMBOS] = {[4] = 2, [11] = 1},
    },
  }
  local saved = json.encode(ReplayV3("test", rules, {sourceType = ReplayV3.panelSourceTypes.puzzle}))
  local loaded = ReplayV3.createFromTable(json.decode(saved), true)

  local chains = loaded.rules.stackWinConditions[MatchRules.StackWinConditions.CHAINS]
  local combos = loaded.rules.stackWinConditions[MatchRules.StackWinConditions.COMBOS]
  assert(chains[14] == 1, "a x14 chain goal is still asked for by size 14")
  assert(combos[4] == 2 and combos[11] == 1, "combo goals keep their sizes")
end

goalSizesAboveTenSurviveASavedReplay()
