local UIElement = require("client.src.ui.UIElement")
local ui = require("client.src.ui")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local PuzzleHintHelper = require("common.engine.PuzzleHintHelper")

local BACKGROUND_PADDING = 8
local BACKGROUND_PADDING_VERTICAL = 4
local IDLE_TIME_THRESHOLD = 8.0

local COLORS = {
  background = {0.05, 0.05, 0.15, 0.85},
  border = {0.2, 0.8, 1.0, 0.6},
  white = {1, 1, 1, 1}
}

---@class PuzzleHelpDisplayOptions : UiElementOptions
---@field puzzle Puzzle The puzzle instance to provide help for
---@field puzzleGame table The puzzle game scene for interactions

---@enum PuzzleHelpState
local PuzzleHelpState = {
  HIDDEN = "hidden",
  SHOW_HELP = "show_help",
  HINT_SHOWN = "hint_shown"
}

---@class PuzzleHelpDisplay : UiElement
---@field puzzle Puzzle The puzzle instance
---@field puzzleGame table The puzzle game scene
---@field hintHelper PuzzleHintHelper Helper for hint logic
---@field state PuzzleHelpState Current help system state
---@field idleTimer number Timer tracking user inactivity
---@field contentLabel Label The main content text label
---@field buttonLabel Label The button instruction label
---@field helpContent table Database of help content for different puzzle patterns
---@field playerSwapPositions table[] Tracked positions where player made swaps
---@field tauntDownPressed boolean Whether taunt down button is currently pressed
---@overload fun(options: PuzzleHelpDisplayOptions): PuzzleHelpDisplay
local PuzzleHelpDisplay = class(
  function(self, options)
    self.puzzle = options.puzzle
    assert(options.puzzleGame)
    self.puzzleGame = options.puzzleGame
    self.hintHelper = PuzzleHintHelper(self.puzzle)
    self.state = PuzzleHelpState.HIDDEN
    self.idleTimer = 0.0
    self.playerSwapPositions = {}
    self.tauntDownPressed = false
    
    self:createLabels()
    self:transitionToState(PuzzleHelpState.HIDDEN)
  end,
  UIElement
)
PuzzleHelpDisplay.TYPE = "PuzzleHelpDisplay"


function PuzzleHelpDisplay:createLabels()
  self.contentLabel = ui.Label({
    x = BACKGROUND_PADDING,
    y = BACKGROUND_PADDING_VERTICAL,
    width = 0,
    height = 0,
    text = "",
    fontSize = 14,
    translate = false,
    hAlign = "left",
    vAlign = "top",
    wrapWidth = 220
  })
  
  self.buttonLabel = ui.Label({
    x = BACKGROUND_PADDING,
    y = BACKGROUND_PADDING_VERTICAL + 80,
    width = 0,
    height = 0,
    text = "",
    fontSize = 12,
    translate = false,
    hAlign = "left",
    vAlign = "top",
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

function PuzzleHelpDisplay:trackPlayerSwap(row, column)
  table.insert(self.playerSwapPositions, {row = row, column = column})
end

function PuzzleHelpDisplay:onTauntUp()
  self.tauntDownPressed = false
end

function PuzzleHelpDisplay:onTauntDown()
  if self.tauntDownPressed then
    return
  end
  
  self.tauntDownPressed = true
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

function PuzzleHelpDisplay:updateDimensions()
  if not self.visible then
    self.width = 0
    self.height = 0
    return
  end
  
  -- Calculate width based on the widest content + padding
  local contentWidth = self.contentLabel.drawable and self.contentLabel.drawable:getWidth() or 0
  local buttonWidth = self.buttonLabel.drawable and self.buttonLabel.drawable:getWidth() or 0
  local maxWidth = math.max(contentWidth, buttonWidth)
  
  -- Calculate height based on both labels + spacing + padding
  local contentHeight = self.contentLabel.drawable and self.contentLabel.drawable:getHeight() or 0
  local buttonHeight = self.buttonLabel.drawable and self.buttonLabel.drawable:getHeight() or 0
  local totalHeight = contentHeight + buttonHeight + 20
  
  self.width = maxWidth + (BACKGROUND_PADDING * 2)
  self.height = totalHeight + (BACKGROUND_PADDING_VERTICAL * 2)
  
  -- Update button label position
  self.buttonLabel.y = BACKGROUND_PADDING_VERTICAL + contentHeight + 10
end

function PuzzleHelpDisplay:drawSelf()
  if not self.visible then
    return
  end
  
  GraphicsUtil.setColor(COLORS.background)
  love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)

  GraphicsUtil.setColor(COLORS.border)
  love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
  
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

  if self.hintHelper:isPlayerInSync(self.playerSwapPositions) == false then
    self.puzzleGame:resetPuzzle()
  end
  
  local nextHint = self.hintHelper:getNextHint(#self.playerSwapPositions)
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