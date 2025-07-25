local GameBase = require("client.src.scenes.GameBase")
local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local MessageTransition = require("client.src.scenes.Transitions.MessageTransition")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local InputCompression = require("common.data.InputCompression")
local consts = require("common.engine.consts")
local FileUtils = require("client.src.FileUtils")
local ui = require("client.src.ui")
local PuzzleHierarchyDisplay = require("client.src.graphics.PuzzleHierarchyDisplay")
local PuzzleSetIterator = require("client.src.PuzzleSetIterator")
local MatchRules = require("common.data.MatchRules")

-- Scene for a puzzle mode instance of the game
---@class PuzzleGame : GameBase
---@field player Player
---@field puzzleSet PuzzleSet?
---@field puzzleSetIterator PuzzleSetIterator?
---@field puzzleIndex integer?
---@field rootPuzzleSet PuzzleSet?
---@field puzzleHierarchyDisplay PuzzleHierarchyDisplay?
---@field currentPuzzleIndices integer[]?
local PuzzleGame = class(
  function (self, sceneParams)
    self.keepMusic = true
    self.fadeOutMusicOnGameOver = false
    self.saveReplay = false
    assert(sceneParams.puzzleSet)
    assert(sceneParams.puzzleSetIterator)
    self.puzzleSet = sceneParams.puzzleSet
    self.puzzleSetIterator = sceneParams.puzzleSetIterator

    local indices = deepcpy(self.puzzleSetIterator:currentPuzzle())
    local index = indices[#indices]
    indices[#indices] = nil
    self.puzzleHierarchyDisplay = PuzzleHierarchyDisplay({
      puzzleSet = self.puzzleSet,
      puzzleSetIndices = indices,
      puzzleIndex = index,
      width = 0,
      height = 0,
      x = 0,
      y = 18,
      hAlign = "center",
      vAlign = "top"
    })
    self.uiRoot:addChild(self.puzzleHierarchyDisplay)
  end,
  GameBase
)

PuzzleGame.name = "PuzzleGame"

function PuzzleGame:getCurrentPuzzle()
  assert(self.puzzleSetIterator)
  local currentPuzzleIndices = self.puzzleSetIterator:currentPuzzle()

  if currentPuzzleIndices then
    local puzzle = PuzzleSetIterator.getPuzzleFromIndices(self.puzzleSet, currentPuzzleIndices)
    assert(puzzle)
    return puzzle
  end

  return nil
end

function PuzzleGame.setupNextPuzzle(battleRoom, puzzleSetIterator, puzzleSet)
  -- Get the first puzzle from the iterator
  local puzzleIndices = puzzleSetIterator:nextPuzzle()
  if puzzleIndices then
    local puzzle = PuzzleSetIterator.getPuzzleFromIndices(puzzleSet, puzzleIndices)
    if puzzle then
      GAME.battleRoom:setGameMode(puzzle:toGameMode())
      GAME.battleRoom.panelSource = puzzle:toPanelSource(config.puzzle_randomColors)
    end
  end
  return puzzleIndices
end

function PuzzleGame:customLoad()
  -- we cache the player's input configuration here so that only inputs from this config can start the next puzzle
---@diagnostic disable-next-line: assign-type-mismatch
  self.player = self.match.players[1]
  self.inputConfiguration = self.player.inputConfiguration
  
  -- Override drawTimer to prevent elapsed time display in puzzles
  self.match.drawTimer = function() end
  
  -- Center the stack on screen for puzzles
  for _, stack in ipairs(self.match.stacks) do
    -- Calculate center position
    -- Stack frame is typically around 104 pixels wide (baseWidth + panelOriginXOffset)
    local stackWidth = stack.baseWidth + stack.panelOriginXOffset
    local centerX = (consts.CANVAS_WIDTH - stackWidth * stack.gfxScale) / 2
    local centerY = (consts.CANVAS_HEIGHT - stack.baseHeight * stack.gfxScale) / 2
    
    -- Move stack to center
    stack:moveToPosition(centerX, centerY)
  end
end

function PuzzleGame:customRun()
  -- reset level
  if (self.player.inputConfiguration and self.player.inputConfiguration.isDown["TauntUp"]) then
    if not self.match.ended and not self.match.isPaused then
      GAME.theme:playValidationSfx()
      self:savePuzzleRecordResult(false)
      self.match:resetPuzzle()
    end
  end
end

function PuzzleGame:readyToProceedToNextScene()
  if (self.inputConfiguration and self.inputConfiguration.isDown["TauntDown"]) then
    FileUtils.saveReplay(self.match.replay)
  else
    return tableUtils.trueForAny(self.inputConfiguration.isDown, function(key) return key end)
  end
end

function PuzzleGame:startNextScene()
  if self.match.engine.aborted then
    GAME.navigationStack:pop()
  else
    if self.puzzleSetIterator then
      self.player:setWantsReady(true)
    else
      GAME.navigationStack:pop()
    end
  end
end

function PuzzleGame:savePuzzleRecordResult(success)
  local inputs = InputCompression.compressInputString(table.concat(self.match.players[1].stack.engine.confirmedInput))
  local currentPuzzle = self:getCurrentPuzzle()
  if currentPuzzle then
    GAME.scores:savePuzzleRecord(currentPuzzle, inputs, to_UTC(os.time()), success)
  end
end

function PuzzleGame:customGameOverSetup()
  if self.match.stacks[1].engine.game_over_clock <= 0 and not self.match.engine.aborted then -- puzzle has been solved successfully
    self.text = loc("pl_you_win")
    self:savePuzzleRecordResult(true)
    
    local puzzleIndices = PuzzleGame.setupNextPuzzle(GAME.battleRoom, self.puzzleSetIterator, self.puzzleSet)
    if puzzleIndices then
    else
      self.puzzleSetIterator = nil
    end
  else -- puzzle failed or manually reset
    self.text = loc("pl_you_lose")
    if (self.match.aborted == nil or self.match.aborted == false) then
      self:savePuzzleRecordResult(false)
    end
  end
end

function PuzzleGame:drawHUD()
  if not self.match.isPaused then
    for _, stack in ipairs(self.match.stacks) do
      if stack.engine.stackOverConditions[MatchRules.StackOverConditions.SWAPS] then
        stack:drawMoveCount()
      end
      
      stack:drawMultibar()
    end
  end
end

function PuzzleGame:drawBackground()
  if self.backgroundImage then
    self.backgroundImage:draw()
  end
  -- Skip drawing bg_overlay for puzzles
end

-- Disable taunt sounds in puzzle mode
function PuzzleGame:shouldDisableTauntSounds()
  return true
end

return PuzzleGame