local GameBase = require("client.src.scenes.GameBase")
local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local InputCompression = require("common.data.InputCompression")
local KeyDataEncoding = require("common.data.KeyDataEncoding")
local consts = require("common.engine.consts")
local PuzzleHierarchyDisplay = require("client.src.graphics.PuzzleHierarchyDisplay")
local PuzzleGoalDisplay = require("client.src.graphics.PuzzleGoalDisplay")
local PuzzleHelpDisplay = require("client.src.ui.PuzzleHelpDisplay")
local PuzzleSetIterator = require("client.src.PuzzleSetIterator")
local PuzzleSet = require("client.src.PuzzleSet")

-- Scene for a puzzle mode instance of the game
---@class PuzzleGame : GameBase
---@field player Player
---@field puzzleSet PuzzleSet?
---@field puzzleSetIterator PuzzleSetIterator?
---@field puzzleIndex integer?
---@field rootPuzzleSet PuzzleSet?
---@field puzzleHierarchyDisplay PuzzleHierarchyDisplay?
---@field currentPuzzleIndices integer[]?
---@field puzzleGoalDisplay PuzzleGoalDisplay?
---@field puzzleHelpDisplay PuzzleHelpDisplay?
---@field queuedInputs string[] Queue of inputs to be fed one per frame
---@field inputQueueIndex integer Current position in the input queue
local PuzzleGame = class(
  function (self, sceneParams)
    self.keepMusic = true
    self.fadeOutMusicOnGameOver = false
    self.saveReplay = false
    
    self.queuedInputs = {}
    self.inputQueueIndex = 1
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
  -- Store current stage info for potential preservation
  local currentStageId = battleRoom.match and battleRoom.match.stageId or nil
  
  -- Get the first puzzle from the iterator
  local puzzleIndices = puzzleSetIterator:nextPuzzle()
  if puzzleIndices then
    local puzzle = PuzzleSetIterator.getPuzzleFromIndices(puzzleSet, puzzleIndices)
    if puzzle then
      GAME.battleRoom:setGameMode(puzzle:toGameMode())
      GAME.battleRoom.panelSource = puzzle:toPanelSource(config.puzzle_randomColors)
      battleRoom.preferredStageId = currentStageId
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
    local stackWidth = stack.baseWidth + stack.panelOriginXOffset
    local centerX = (consts.CANVAS_WIDTH - stackWidth * stack.gfxScale) / 2
    local normalY = stack.baseWidth + stack.panelOriginXOffset
    
    -- Move stack to center
    stack:moveToPosition(centerX, normalY)
  end
  
  local currentPuzzle = self:getCurrentPuzzle()
  if currentPuzzle and self.match.stacks[1] and self.match.stacks[1].engine then
    local stack = self.match.stacks[1]
    local stackWidth = stack.baseWidth + stack.panelOriginXOffset
    local centerX = (consts.CANVAS_WIDTH - stackWidth * stack.gfxScale) / 2
    local stackRightEdge = centerX + (stackWidth * stack.gfxScale)
    
    self.puzzleGoalDisplay = PuzzleGoalDisplay({
      x = stackRightEdge + 2,
      y = 358,
      width = 0,
      height = 0,
      puzzle = currentPuzzle,
      stack = stack.engine
    })
    self.uiRoot:addChild(self.puzzleGoalDisplay)
    
    self.puzzleHelpDisplay = PuzzleHelpDisplay({
      x = stackRightEdge + 2,
      y = 490,
      width = 0,
      height = 0,
      puzzle = currentPuzzle,
      puzzleGame = self
    })
    self.uiRoot:addChild(self.puzzleHelpDisplay)
  end
end

function PuzzleGame:runGame(dt)
  self:feedQueuedInput()
  
  if not self.match.isPaused then
    self.match:run()
  end
  
  self:customRun()
  self:handlePause()
end

function PuzzleGame:customRun()
  -- Reset idle timer and track input for help system
  if self.puzzleHelpDisplay and self.player.inputConfiguration then
    local hasInput = tableUtils.trueForAny(self.player.inputConfiguration.isDown, function(key) return key end)
    if hasInput then
      self.puzzleHelpDisplay:resetIdleTimer()
    end
  end
  
  -- reset level
  if (self.player.inputConfiguration and self.player.inputConfiguration.isDown["TauntUp"]) then
    if not self.match.ended and not self.match.isPaused then
      GAME.theme:playValidationSfx()
      self:resetPuzzle()
    end
  end
  
  -- Track swaps for help system
  if (self.player.inputConfiguration and (self.player.inputConfiguration.isDown["Swap1"] or self.player.inputConfiguration.isDown["Swap2"])) then
    self:trackSwapInput()
  end
  
  -- Handle TauntDown for help system
  if (self.player.inputConfiguration and self.player.inputConfiguration.isPressed["TauntDown"]) then
    if self.puzzleHelpDisplay and not self.match.ended and not self.match.isPaused then
      self.puzzleHelpDisplay:onTauntDown()
    end
  end
  
  -- Handle releasing taunt down
  if (self.player.inputConfiguration and not self.player.inputConfiguration.isPressed["TauntDown"]) then
    if self.puzzleHelpDisplay then
      self.puzzleHelpDisplay:onTauntUp()
    end
  end
end

function PuzzleGame:readyToProceedToNextScene()
  return tableUtils.trueForAny(self.inputConfiguration.isDown, function(key) return key end)
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

function PuzzleGame:recordPuzzleSolution()
  local currentPuzzle = self:getCurrentPuzzle()
  if not currentPuzzle or currentPuzzle.solution then
    -- Don't overwrite existing solutions
    return
  end
  
  local engine = self.match.players[1].stack.engine
  if engine.inputMethod ~= "controller" then
    return
  end

  local inputs = InputCompression.compressInputString(table.concat(engine.confirmedInput))
  if not inputs or inputs == "" then
    return
  end
  
  currentPuzzle.solution = inputs
  
  if self.puzzleSetIterator and self.puzzleSet then
    local currentIndices = self.puzzleSetIterator:currentPuzzle()
    if currentIndices then
      local targetIndices = {unpack(currentIndices)} -- copy the indices
      local puzzleIndex = table.remove(targetIndices) -- remove last element (puzzle index)
      
      -- Find the puzzle set with fileSource and get the adjusted path
      local sourceRootPuzzleSet, adjustedPath = PuzzleSet.findPuzzleSetWithFileSource(self.puzzleSet, targetIndices)
      
      -- Navigate to the target puzzle set using the adjusted path
      local targetPuzzleSet = sourceRootPuzzleSet
      for _, index in ipairs(adjustedPath) do
        if targetPuzzleSet.puzzleSets and targetPuzzleSet.puzzleSets[index] then
          targetPuzzleSet = targetPuzzleSet.puzzleSets[index]
        end
      end
      
      -- Save the puzzle with solution using the root puzzle set that has the file source
      if sourceRootPuzzleSet and sourceRootPuzzleSet.saveTargetPuzzleToFile then
        sourceRootPuzzleSet:saveTargetPuzzleToFile(targetPuzzleSet, puzzleIndex, currentPuzzle)
      end
    end
  end
end

function PuzzleGame:customGameOverSetup()
  if self.match.stacks[1].engine.game_over_clock <= 0 and not self.match.engine.aborted then -- puzzle has been solved successfully
    self.text = loc("pl_you_win")
    self:savePuzzleRecordResult(true)
    self:recordPuzzleSolution()
    
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

-- Track player swaps for hint system
function PuzzleGame:trackSwapInput()
  if self.puzzleHelpDisplay and self.match.stacks[1] and self.match.stacks[1].engine and not self.match.isPaused then
    local stack = self.match.stacks[1].engine
    local cursorRow = stack.cur_row
    local cursorColumn = stack.cur_col
    self.puzzleHelpDisplay:trackPlayerSwap(cursorRow, cursorColumn)
  end
end

function PuzzleGame:feedQueuedInput()
  if #self.queuedInputs > 0 and self.inputQueueIndex <= #self.queuedInputs then
    if self.match.stacks[1] and self.match.stacks[1].engine then
      local stack = self.match.stacks[1].engine
      local input = self.queuedInputs[self.inputQueueIndex]
      stack:receiveConfirmedInput(input)
      self.inputQueueIndex = self.inputQueueIndex + 1
    end
  end
end

function PuzzleGame:queueInputs(inputs)
  self.queuedInputs = {}
  self.inputQueueIndex = 1
  
  for _, input in ipairs(inputs) do
    table.insert(self.queuedInputs, input)
  end
end

-- Helper method to add a key input followed by idle inputs
function PuzzleGame:addKeyWithIdles(inputs, key, idleCount)
  table.insert(inputs, key)
  for _ = 1, idleCount do
    table.insert(inputs, KeyDataEncoding.idle)
  end
end

function PuzzleGame:resetPuzzle()
  self:savePuzzleRecordResult(false)
  self.match:resetPuzzle()
  if self.puzzleHelpDisplay then
    self.puzzleHelpDisplay.playerSwapPositions = {}
  end
end

-- Execute a single hint (position cursor and swap)
function PuzzleGame:executePuzzleHint(targetRow, targetColumn)
  if not self.match.stacks[1] or not self.match.stacks[1].engine then
    return false
  end
  
  local stack = self.match.stacks[1].engine
  
  -- Calculate movement needed from current cursor position
  local currentRow = stack.cur_row 
  local currentColumn = stack.cur_col
  
  local inputs = {}
  
  -- Add vertical movement inputs with 10 idle frames per move
  local rowDiff = targetRow - currentRow
  if rowDiff > 0 then
    -- Move up
    for _ = 1, rowDiff do
      self:addKeyWithIdles(inputs, KeyDataEncoding.up, 10)
    end
  elseif rowDiff < 0 then
    -- Move down
    for _ = 1, -rowDiff do
      self:addKeyWithIdles(inputs, KeyDataEncoding.down, 10)
    end
  end
  
  -- Add horizontal movement inputs with 10 idle frames per move
  local colDiff = targetColumn - currentColumn
  if colDiff > 0 then
    -- Move right
    for _ = 1, colDiff do
      self:addKeyWithIdles(inputs, KeyDataEncoding.right, 10)
    end
  elseif colDiff < 0 then
    -- Move left  
    for _ = 1, -colDiff do
      self:addKeyWithIdles(inputs, KeyDataEncoding.left, 10)
    end
  end
  
  -- Add some idle frames before ending
  for _ = 1, 10 do
    table.insert(inputs, KeyDataEncoding.idle)
  end
  -- table.insert(inputs, KeyDataEncoding.swap)
  
  self:queueInputs(inputs)
  
  return true
end

-- Play full puzzle solution
function PuzzleGame:playPuzzleSolution(solutionInputs)
  if not solutionInputs or solutionInputs == "" then
    return false
  end
  
  if not self.match.stacks[1] or not self.match.stacks[1].engine then
    return false
  end
  
  self:resetPuzzle()
  
  self:queueInputs(procat(solutionInputs))
  
  return true
end

return PuzzleGame