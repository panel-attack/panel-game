local GameBase = require("client.src.scenes.GameBase")
local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local InputCompression = require("common.data.InputCompression")
local KeyDataEncoding = require("common.data.KeyDataEncoding")
local LevelPresets = require("common.data.LevelPresets")
local consts = require("common.engine.consts")
local PuzzleHierarchyDisplay = require("client.src.graphics.PuzzleHierarchyDisplay")
local PuzzleGoalDisplay = require("client.src.graphics.PuzzleGoalDisplay")
local PuzzleHelpDisplay = require("client.src.ui.PuzzleHelpDisplay")
local PuzzleSetIterator = require("client.src.PuzzleSetIterator")
local PuzzleSet = require("client.src.PuzzleSet")
local MultibarElement = require("client.src.ui.MultibarElement")

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
---@field hintUsed boolean Whether a hint has been used for this puzzle
---@field multibarElement MultibarElement? Relative multibar component
---@field playerStack PlayerStack? Player stack associated with the current puzzle run
local PuzzleGame = class(
  function (self, sceneParams)
    self.keepMusic = true
    self.fadeOutMusicOnGameOver = false
    self.saveReplay = false
    
    self.queuedInputs = {}
    self.inputQueueIndex = 1
    self.hintUsed = false
    assert(sceneParams.puzzleSet)
    assert(sceneParams.puzzleSetIterator)
    self.puzzleSet = sceneParams.puzzleSet
    self.puzzleSetIterator = sceneParams.puzzleSetIterator

    -- Pick up queued solution inputs if passed from previous scene
    if sceneParams.queuedSolutionInputs then
      self.queuedInputs = sceneParams.queuedSolutionInputs
      self.hintUsed = sceneParams.hintWasUsed or false
      -- Clear from battleRoom parameters so it doesn't persist
      GAME.battleRoom.sceneParameters.queuedSolutionInputs = nil
      GAME.battleRoom.sceneParameters.hintWasUsed = nil
    end

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

function PuzzleGame.setupNextPuzzle(battleRoom, puzzleSetIterator, puzzleSet, advance)
  -- Get puzzle indices - either advance to next or stay on current
  local puzzleIndices
  if advance == false then
    puzzleIndices = puzzleSetIterator:currentPuzzle()
  else
    puzzleIndices = puzzleSetIterator:nextPuzzle()
  end

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
  local firstPlayer = self.match.players[1]
  assert(firstPlayer, "PuzzleGame requires a player")
  assert(firstPlayer.human, "PuzzleGame expects a human-controlled player")
  ---@cast firstPlayer Player
  self.player = firstPlayer
  self.inputConfiguration = self.player.inputConfiguration
  local playerStack = self.player.stack
  assert(playerStack, "PuzzleGame requires an associated player stack")
  self.playerStack = playerStack

  -- Restore level if it was temporarily changed for solution playback
  if GAME.battleRoom.sceneParameters.restoreLevelAfterCreation then
    local restoreLevel = GAME.battleRoom.sceneParameters.restoreLevelAfterCreation
    GAME.localPlayer:setLevel(restoreLevel)
    GAME.localPlayer:setLevelData(LevelPresets.getModern(restoreLevel))
    GAME.battleRoom.sceneParameters.restoreLevelAfterCreation = nil
  end

  -- Override drawTimer to prevent elapsed time display in puzzles
  ---@diagnostic disable-next-line: duplicate-set-field
  self.match.drawTimer = function() end
  
  local stack = playerStack

  stack:moveToCenterPosition()
  
  local framePos = themes[config.theme].healthbar_frame_Pos
  local frameScale = themes[config.theme].healthbar_frame_Scale * (stack.gfxScale / 3)
  
  local percentWidthShift = 0
  if stack.multiplication > 0 then
    percentWidthShift = 1
  end
  
  local baseX = stack:labelOriginXWithOffset(framePos, frameScale, false, stack.assets.multibar.frameAbsolute:getWidth(), percentWidthShift, false)
  local baseY = stack:elementOriginYWithOffset(framePos, false)
  local barPos = themes[config.theme].multibar_Pos
  local overtimePos = themes[config.theme].multibar_LeftoverTime_Pos
  local barAbsoluteX = stack:elementOriginXWithOffset(barPos, false)
  local barAbsoluteY = stack:elementOriginYWithOffset(barPos, false)
  local overtimeAbsoluteX = stack:elementOriginXWithOffset(overtimePos, false)
  local overtimeAbsoluteY = stack:elementOriginYWithOffset(overtimePos, false)
  
  local relativeBarPos = {barAbsoluteX - baseX, barAbsoluteY - baseY}
  local relativeOvertimePos = {overtimeAbsoluteX - baseX, overtimeAbsoluteY - baseY}
  
  self.multibarElement = MultibarElement({
    x = baseX,
    y = baseY,
    stack = stack,
    framePos = {0, 0}, -- Frame is at element origin
    barPos = relativeBarPos,
    overtimePos = relativeOvertimePos,
    frameScale = themes[config.theme].healthbar_frame_Scale,
    barScale = themes[config.theme].multibar_Scale,
    overtimeDecimals = themes[config.theme].multibar_LeftoverTime_Decimals
  })
  
  
  self.uiRoot:addChild(self.multibarElement)
  
  -- Connect to pause signal to handle multibar visibility
  self.match:connectSignal("pauseChanged", self, function(subscriber, match)
    if self.multibarElement then
      self.multibarElement:setVisibility(not match.isPaused)
    end
  end)
  
  local currentPuzzle = self:getCurrentPuzzle()
  local activeStack = self.playerStack
  if currentPuzzle and activeStack then
    local stack = activeStack
    local stackWidth = stack.baseWidth + stack.panelOriginXOffset
    local stackRightEdge = stack.frameOriginX * stack.gfxScale + (stackWidth * stack.gfxScale)
    
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

    -- If solution is playing (non-move puzzle with hint used), show the hint state
    if self.hintUsed and currentPuzzle.puzzleType ~= "moves" then
      self.puzzleHelpDisplay:transitionToState("hint_shown")
    end
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
  local shouldPop = self.match.engine.aborted or not self.puzzleSetIterator

  if shouldPop then
    -- Clear the character/stage lock when returning to puzzle menu
    if self.player then
      self.player.settings.lockCharacterAndStage = nil
    end
    GAME.navigationStack:pop()
  else
    self.player:setWantsReady(true)
  end
end

function PuzzleGame:savePuzzleRecordResult(success)
  local playerStack = self.playerStack
  if not playerStack then
    return
  end
  local inputs = InputCompression.compressInputString(table.concat(playerStack.engine.confirmedInput))
  local currentPuzzle = self:getCurrentPuzzle()
  if currentPuzzle then
    GAME.scores:savePuzzleRecord(currentPuzzle, inputs, to_UTC(os.time()), success)
  end
end

function PuzzleGame:recordPuzzleSolution()
  local playerStack = self.playerStack
  if not playerStack then
    return
  end

  local currentPuzzle = self:getCurrentPuzzle()
  if not currentPuzzle or currentPuzzle.solution then
    -- Don't overwrite existing solutions
    return
  end

  -- Only record solutions when playing at level 10
  if GAME.localPlayer.settings.level ~= 10 then
    return
  end

  local engine = playerStack.engine
  if engine.inputMethod ~= "controller" then
    return
  end

  local inputs = InputCompression.compressInputString(table.concat(engine.confirmedInput))
  if not inputs or inputs == "" then
    return
  end
  
  currentPuzzle.solution = inputs
  
  if self.puzzleSetIterator and self.puzzleSet then
    local puzzleSet = self.puzzleSet
    ---@cast puzzleSet PuzzleSet
    local currentIndices = self.puzzleSetIterator:currentPuzzle()
    if currentIndices then
      local targetIndices = {unpack(currentIndices)} -- copy the indices
      local puzzleIndex = table.remove(targetIndices) -- remove last element (puzzle index)
      
      -- Find the puzzle set with fileSource and get the adjusted path
      local sourceRootPuzzleSet, adjustedPath = PuzzleSet.findPuzzleSetWithFileSource(puzzleSet, targetIndices)
      
      -- Navigate to the target puzzle set using the adjusted path
      local targetPuzzleSet = sourceRootPuzzleSet
      for _, index in ipairs(adjustedPath) do
        if targetPuzzleSet.puzzleSets and targetPuzzleSet.puzzleSets[index] then
          targetPuzzleSet = targetPuzzleSet.puzzleSets[index]
        end
      end
      
      -- Save the puzzle with solution using the root puzzle set that has the file source
      if sourceRootPuzzleSet and sourceRootPuzzleSet.saveTargetPuzzleToFile and targetPuzzleSet then
        ---@cast targetPuzzleSet PuzzleSet
        sourceRootPuzzleSet:saveTargetPuzzleToFile(targetPuzzleSet, puzzleIndex, currentPuzzle)
      end
    end
  end
end

function PuzzleGame:drawEndGameText()
  if self.isResetting or self.hintUsed then
    return
  end

  -- Call parent implementation first
  GameBase.drawEndGameText(self)
end

function PuzzleGame:customGameOverSetup()
  if self.isResetting then
    self.text = nil
    return
  end

  local playerStack = self.playerStack
  if playerStack and playerStack.engine.game_over_clock <= 0 and not self.match.engine.aborted then -- puzzle has been solved successfully
    self.text = loc("pl_you_win")
    self:savePuzzleRecordResult(not self.hintUsed)
    self:recordPuzzleSolution()

    -- If hint/solution was used, stay on the same puzzle; otherwise advance to next
    local puzzleIndices = PuzzleGame.setupNextPuzzle(GAME.battleRoom, self.puzzleSetIterator, self.puzzleSet, not self.hintUsed)
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
  -- HUD elements are drawn via normal element hierarchy in puzzle game
  -- Draw level display
  if not self.match.isPaused and self.match.stacks[1] then
    self.match.stacks[1]:drawLevel()
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
  local playerStack = self.playerStack
  if self.puzzleHelpDisplay and playerStack and not self.match.isPaused then
    local stack = playerStack.engine
    local cursorRow = stack.cur_row
    local cursorColumn = stack.cur_col
    self.puzzleHelpDisplay:trackPlayerSwap(cursorRow, cursorColumn)
  end
end

function PuzzleGame:feedQueuedInput()
  if #self.queuedInputs > 0 and self.inputQueueIndex <= #self.queuedInputs then
    local playerStack = self.playerStack
    if playerStack then
      local stack = playerStack.engine
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

  -- Mark that we're resetting to avoid showing "you lose" text
  self.isResetting = true

  -- Abort the current match to properly end it and reset BattleRoom state to Setup
  self.match:abort()

  -- Setup the puzzle (same as losing does in customGameOverSetup)
  PuzzleGame.setupNextPuzzle(GAME.battleRoom, self.puzzleSetIterator, self.puzzleSet, false)

  GAME.battleRoom.sceneParameters.useInstantTransition = true

  -- Re-claim the player's last used input configuration before setting ready
  -- This is needed because onMatchEnded unrestricted inputs, and setWantsReady
  -- requires an input to be actively pressed to claim, which may not be the case
  if self.player.lastUsedInputConfiguration then
    self.player:restrictInputs(self.player.lastUsedInputConfiguration)
  end

  -- Trigger new match creation (same as startNextScene does after game over)
  self.player:setWantsReady(true)
end

-- Execute a single hint (position cursor and swap)
function PuzzleGame:executePuzzleHint(targetRow, targetColumn)
  local playerStack = self.playerStack
  if not playerStack then
    return false
  end
  
  local stack = playerStack.engine
  
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
  
  self.hintUsed = true
  self:queueInputs(inputs)
  
  return true
end

-- Play full puzzle solution
function PuzzleGame:playPuzzleSolution(solutionInputs)
  if not solutionInputs or solutionInputs == "" then
    return false
  end
  
  if not self.playerStack then
    return false
  end

  local currentPuzzle = self:getCurrentPuzzle()
  local isMovePuzzle = currentPuzzle and currentPuzzle.puzzleType == "moves"

  -- Store solution inputs for the new scene to pick up
  GAME.battleRoom.sceneParameters.queuedSolutionInputs = procat(solutionInputs)
  GAME.battleRoom.sceneParameters.hintWasUsed = true

  -- For non-move puzzles, temporarily set to level 10 for faster panels
  -- Store the original level to restore after match is created
  if not isMovePuzzle then
    GAME.battleRoom.sceneParameters.restoreLevelAfterCreation = config.puzzle_level
    GAME.localPlayer:setLevel(10)
    GAME.localPlayer:setLevelData(LevelPresets.getModern(10))
  end

  -- Reset puzzle (creates new scene via resetPuzzle)
  self:resetPuzzle()

  return true
end

return PuzzleGame
