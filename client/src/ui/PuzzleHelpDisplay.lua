local UIElement = require("client.src.ui.UIElement")
local ui = require("client.src.ui")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local PuzzleHintHelper = require("client.src.PuzzleHintHelper")

local BACKGROUND_PADDING = 8
local BACKGROUND_PADDING_VERTICAL = 4
-- between the help and the button prompt, and again under the prompt
local LABEL_GAP = 10
local IDLE_TIME_THRESHOLD = 8.0

local COLORS = {
  background = {0.05, 0.05, 0.15, 0.85},
  border = {0.2, 0.8, 1.0, 0.6},
  white = {1, 1, 1, 1}
}

---@class PuzzleHelpDisplayOptions : UiElementOptions
---@field puzzle Puzzle The puzzle instance to provide help for
---@field puzzleGame table The puzzle game scene for interactions
---@field stack Stack The engine stack the puzzle is played on

---@enum PuzzleHelpState
local PuzzleHelpState = {
  HIDDEN = "hidden",
  SHOW_HELP = "show_help",
  HINT_SHOWN = "hint_shown"
}

-- Displays contextual help and hints for puzzle solving, including automatic hint system after idle time
---@class PuzzleHelpDisplay : UiElement
---@field puzzle Puzzle The puzzle instance
---@field puzzleGame table The puzzle game scene
---@field hintHelper PuzzleHintHelper Helper for hint logic
---@field state PuzzleHelpState Current help system state
---@field idleTimer number Timer tracking user inactivity
---@field contentLabel Label The main content text label
---@field buttonLabel Label The button instruction label
---@field helpContent table Database of help content for different puzzle patterns
---@field tauntDownPressed boolean Whether taunt down button is currently pressed
---@overload fun(options: PuzzleHelpDisplayOptions): PuzzleHelpDisplay
local PuzzleHelpDisplay = class(
  function(self, options)
    self.puzzle = options.puzzle
    assert(options.puzzleGame)
    self.puzzleGame = options.puzzleGame
    self.hintHelper = PuzzleHintHelper(self.puzzle)
    self.hintHelper:followPlayerStack(options.stack)
    self.state = PuzzleHelpState.HIDDEN
    self.idleTimer = 0.0
    self.tauntDownPressed = false
    
    self:createLabels()
    self:transitionToState(PuzzleHelpState.HIDDEN)
  end,
  UIElement
)
PuzzleHelpDisplay.TYPE = "PuzzleHelpDisplay"


-- Lays the panel out as a column of the help and, under it, the button prompt
function PuzzleHelpDisplay:createLabels()
  self:setLayoutRule("layoutDirection", "topToBottom")
  self:setLayoutRule("childGap", LABEL_GAP)
  self:setLayoutRule("padding", {
    left = BACKGROUND_PADDING,
    right = BACKGROUND_PADDING,
    top = BACKGROUND_PADDING_VERTICAL,
    bottom = BACKGROUND_PADDING_VERTICAL + LABEL_GAP
  })

  self.contentLabel = ui.Label({
    text = "",
    fontSize = 14,
    translate = false,
    wrapWidth = 220
  })
  
  self.buttonLabel = ui.Label({
    text = "",
    fontSize = 12,
    translate = false,
    wrapWidth = 220
  })
  
  self:addChild(self.contentLabel)
  self:addChild(self.buttonLabel)
end

function PuzzleHelpDisplay:update(dt)
  self.idleTimer = self.idleTimer + dt
  
  -- Check for state transitions based on idle time
  if (self.state == PuzzleHelpState.HIDDEN or self.state == PuzzleHelpState.HINT_SHOWN) and self.idleTimer >= IDLE_TIME_THRESHOLD then
    self:transitionToState(PuzzleHelpState.SHOW_HELP)
  end
  
  self:updateDimensions()
end

function PuzzleHelpDisplay:resetIdleTimer()
  self.idleTimer = 0.0
end

function PuzzleHelpDisplay:onTauntUp()
  self.tauntDownPressed = false
end

function PuzzleHelpDisplay:onTauntDown()
  if self.tauntDownPressed then
    return
  end
  
  self.tauntDownPressed = true
  self:requestHint()
end

-- Show the help and give the next hint, for the hint key or the touch hint button
function PuzzleHelpDisplay:requestHint()
  if (self.state == PuzzleHelpState.HIDDEN or self.state == PuzzleHelpState.HINT_SHOWN) then
    self:transitionToState(PuzzleHelpState.SHOW_HELP)
  end

  self:executeHint()
end

function PuzzleHelpDisplay:hasSolution()
  return self.hintHelper:hasSolution()
end

function PuzzleHelpDisplay:transitionToState(newState)
  self.state = newState
  self:updateContent()
  self:updateVisibility()
end

function PuzzleHelpDisplay:updateContent()
  
  if self.puzzle.helpDescription and self.puzzle.helpDescription ~= "" then
    self.contentLabel:setText(self.puzzle.helpDescription, {}, true)
  else
    self.contentLabel:setText("", {}, false)
  end
  
  if self.state == PuzzleHelpState.HINT_SHOWN then
    if self.hintHelper:isMovePuzzle() then
      self.buttonLabel:setText("puzzle_help_hint_given", {}, true)
    else
      self.buttonLabel:setText("puzzle_help_solution_playing", {}, true)
    end
  elseif self.state == PuzzleHelpState.SHOW_HELP then
    if self:hasSolution() then
      if self.hintHelper:isMovePuzzle() then
        self.buttonLabel:setText("puzzle_help_next_prompt", {}, true) -- "Press Taunt Down for Hint"
      else
        self.buttonLabel:setText("puzzle_help_solution_prompt", {}, true) -- "Press Taunt Down to see a Solution"
      end
    else
      if self.hintHelper:isMovePuzzle() then
        self.buttonLabel:setText("puzzle_help_no_hints", {}, true)
      else
        self.buttonLabel:setText("puzzle_help_no_solution", {}, true)
      end
    end
  else
    self.buttonLabel:setText("", {}, false)
  end
end

function PuzzleHelpDisplay:updateVisibility()
  self.visible = (self.state ~= PuzzleHelpState.HIDDEN) or (self.puzzle.helpDescription ~= nil and self.puzzle.helpDescription ~= "")
end

-- Takes no space while hidden, and fits its labels while shown
function PuzzleHelpDisplay:updateDimensions()
  if self.visible then
    self:setLayoutRule("sizing", nil)
  else
    self:setFixedSize(0, 0)
  end
end

function PuzzleHelpDisplay:drawSelf()
  if not self.visible then
    return
  end
  
  GraphicsUtil.setColor(COLORS.background)
  love.graphics.rectangle("fill", 0, 0, self.layoutRect.width, self.layoutRect.height)

  GraphicsUtil.setColor(COLORS.border)
  love.graphics.rectangle("line", 0, 0, self.layoutRect.width, self.layoutRect.height)
  
  GraphicsUtil.setColor(COLORS.white)
end

function PuzzleHelpDisplay:executeHint()
  if self:hasSolution() == false then
    return false
  end

  self:transitionToState(PuzzleHelpState.HINT_SHOWN)

  if self.hintHelper:isMovePuzzle() == false then
    return self:playSolution()
  end

  if self.hintHelper:isPlayerInSync() == false then
    self.puzzleGame:resetPuzzle()
  end

  local nextHint = self.hintHelper:getNextHint()
  if nextHint == nil then
    return false
  end
  return self.puzzleGame:executePuzzleHint(nextHint.row, nextHint.column)
end

function PuzzleHelpDisplay:playSolution()
  if not self.hintHelper:hasSolution() then
    return false
  end
  
  local solutionInputs = self.hintHelper:getSolutionInputString()
  return self.puzzleGame:playPuzzleSolution(solutionInputs)
end

return PuzzleHelpDisplay