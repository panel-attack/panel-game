local consts = require("common.engine.consts")
local tableUtils = require("common.lib.tableUtils")
local GameModes = require("common.engine.GameModes")
local StackReplayTestingUtils = require("common.tests.engine.StackReplayTestingUtils")
local LevelPresets = require("common.data.LevelPresets")

local testReplayFolder = "common/tests/engine/replays/"

-- Tests a replay doing the following use cases
-- Note this doesn't test the TouchInputController currently because it just executes the already encoded inputs.

-- Touch and drag to swap, then release
-- Expected:
-- Cursor appears, Panels dragged swap, cursor is removed

-- Touch and drag into a matching column and release
-- Cursor should stay
-- Expected:
-- Can tap to insert into the lingering spot
-- Can tap to swap with the opposite spot

-- Touch and drag into a matching column and release
-- Cursor should stay
-- Tap repeatedly until you can insert
-- Expected:
-- Can tap repeatedly and insert if timed right

-- Touch and drag into a matching column, don’t release
-- Expected:
-- No swap (game doesn’t buffer)

-- Touch and drag into a matching column and release
-- Cursor should stay
-- Touch a non adjacent panel
-- Expected:Cursor changes to new spot

-- Touch and drag across a whole row then release
-- Expected:
-- Cursor swaps fast on the first two swaps (stealth) slower on the remaining)

-- Touch and drag a panel so it falls
-- Expected:
-- Panel falls, becomes deselected

-- Setup a chain so a panel is about to match, touch and hold that panel
-- Expected:
-- Panel matches, becomes deselected

local function simpleTouchTest()
  match, _ = StackReplayTestingUtils:simulateReplayWithPath(testReplayFolder .. "v047-2023-02-13-02-07-36-Spd3-Dif1-endless.json")
  assert(match ~= nil)
  assert(match.engineVersion == consts.ENGINE_VERSIONS.TOUCH_COMPATIBLE)
  assert(match.stackInteraction == GameModes.StackInteractions.NONE)
  assert(match.timeLimit == nil)
  assert(tableUtils.length(match.winConditions) == 0)
  assert(match.seed == 2521746)
  assert(match.stacks[1].game_over_clock == 4347)
  -- previously this was comparing difficulty == 1
  -- difficulty was converted to levelData[1] but it turned out endless/time attack used different color counts on 1
  -- so for the preset, the time attack value got picked which means every time we want to do endless, color count needs to be overwritten
  local endlessRef = LevelPresets.getClassic(1)
  endlessRef:setColorCount(5)
  assert(match.stacks[1].levelData == endlessRef)
  assert(tableUtils.count(match.stacks[1].outgoingGarbage.history, function(g) return g.isChain end) == 1)
  assert(tableUtils.count(match.stacks[1].outgoingGarbage.history, function(g) return not g.isChain end) == 3)
  assert(match.stacks[1].panels_cleared == 31)
  StackReplayTestingUtils:cleanup(match)
end

simpleTouchTest()