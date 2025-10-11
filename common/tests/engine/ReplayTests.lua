local StackReplayTestingUtils = require("common.tests.engine.StackReplayTestingUtils")
local InputCompression = require("common.data.InputCompression")
local ReplayV3 = require("common.data.ReplayV3")


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
