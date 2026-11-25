local PuzzleMenu = require("client.src.scenes.PuzzleMenu")
local PuzzleGame = require("client.src.scenes.PuzzleGame")
local PuzzleSet = require("client.src.PuzzleSet")
local Puzzle = require("common.engine.Puzzle")
local BattleRoom = require("client.src.BattleRoom")
local GameModes = require("common.data.GameModes")
local input = require("client.src.inputManager")

---@param puzzleCount integer
---@return PuzzleSet root a root set holding one set with puzzleCount puzzles
local function rootSetWithPuzzles(puzzleCount)
  local puzzles = {}
  for i = 1, puzzleCount do
    puzzles[i] = Puzzle({puzzleType = "moves", startTiming = "immediately", moves = i, stack = string.rep(tostring(i), 16)})
  end
  return PuzzleSet("pz_puzzles", nil, {}, {PuzzleSet("PuzzleMenuTests", nil, puzzles)})
end

-- runs the test with a puzzle menu opened on a set of puzzleCount puzzles, for a player with an input configuration
---@param puzzleCount integer
---@param test fun(menu: PuzzleMenu, player: Player)
local function withMenuOnSet(puzzleCount, test)
  local battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset(GameModes.IDs.ONE_PLAYER_PUZZLE), PuzzleGame, false)
  assert(battleRoom)
  local player = battleRoom.players[1]
  player:restrictInputs(input.inputConfigurations[1])
  local previousLevel = GAME.localPlayer.settings.level
  local previousLevelData = GAME.localPlayer.settings.levelData
  local menu = PuzzleMenu({battleRoom = battleRoom})
  menu.rootPuzzleSet = rootSetWithPuzzles(puzzleCount)
  menu.currentPuzzleSetIndices = {1}
  menu:refresh()

  local ok, err = pcall(test, menu, player)

  battleRoom:shutdown()
  GAME.localPlayer:setLevel(previousLevel)
  GAME.localPlayer:setLevelData(previousLevelData)
  assert(ok, err)
end

local function press(menu, text)
  for _, menuItem in ipairs(menu.menu.menuItems) do
    if menuItem.textButton and menuItem.textButton.label.text == text then
      menuItem.textButton.onClick()
      return
    end
  end
  error("the menu has no button " .. text)
end

local function puzzleButtonText(index)
  return loc("rp_browser_info_puzzle") .. " " .. index
end

local function trainingButtonText(puzzleCount)
  return loc("puzzle_training") .. " " .. puzzleCount
end

---@return integer[]? indices the puzzle the pending start plays
local function startedPuzzle(menu)
  return menu.battleRoom.sceneParameters.puzzleSetIterator:currentPuzzle()
end

local function assertStartedPuzzle(menu, expectedIndex)
  local indices = startedPuzzle(menu)
  assert(indices and #indices == 2 and indices[1] == 1 and indices[2] == expectedIndex,
    "expected puzzle " .. expectedIndex .. " to start, got " .. (indices and table.concat(indices, ",") or "none"))
end

-- what the end of a match does to the player, which lets the menu start another
local function endMatch(player)
  player:setWantsReady(false)
end

local function pressingAOnePuzzleSetsStartTwiceBeforeTheMatchLoadsStartsItOnce()
  withMenuOnSet(1, function(menu)
    press(menu, loc("start"))
    press(menu, loc("start"))

    assertStartedPuzzle(menu, 1)
  end)
end

local function pressingAPuzzleTwiceBeforeTheMatchLoadsStartsThatPuzzle()
  withMenuOnSet(3, function(menu)
    press(menu, puzzleButtonText(2))
    press(menu, puzzleButtonText(2))

    assertStartedPuzzle(menu, 2)
  end)
end

local function pressingTheLastPuzzleAgainAfterItsMatchEndedStartsItAgain()
  withMenuOnSet(2, function(menu, player)
    press(menu, puzzleButtonText(2))
    endMatch(player)

    press(menu, puzzleButtonText(2))

    assertStartedPuzzle(menu, 2)
  end)
end

local function pressingTrainingTwiceBeforeTheMatchLoadsStartsItOnce()
  withMenuOnSet(1, function(menu)
    press(menu, trainingButtonText(1))
    press(menu, trainingButtonText(1))

    assertStartedPuzzle(menu, 1)
  end)
end

local function pressingTrainingAgainAfterItsMatchEndedStartsItAgain()
  withMenuOnSet(1, function(menu, player)
    press(menu, trainingButtonText(1))
    endMatch(player)

    press(menu, trainingButtonText(1))

    assertStartedPuzzle(menu, 1)
  end)
end

pressingAOnePuzzleSetsStartTwiceBeforeTheMatchLoadsStartsItOnce()
pressingAPuzzleTwiceBeforeTheMatchLoadsStartsThatPuzzle()
pressingTheLastPuzzleAgainAfterItsMatchEndedStartsItAgain()
pressingTrainingTwiceBeforeTheMatchLoadsStartsItOnce()
pressingTrainingAgainAfterItsMatchEndedStartsItAgain()
