local UIElement = require("client.src.ui.UIElement")
local ui = require("client.src.ui")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local MatchRules = require("common.data.MatchRules")
local tableUtils = require("common.lib.tableUtils")

local BACKGROUND_PADDING = 8
local BACKGROUND_PADDING_VERTICAL = 4

local COLORS = {
  background = {0.05, 0.05, 0.1, 0.75},
  backgroundHighlight = {0.05, 0.05, 0.1, 0.75},
  border = {1.0, 0.8, 0.1, 0.4},
  white = {1, 1, 1, 1}
}

---@class PuzzleGoalDisplayOptions : UiElementOptions
---@field puzzle Puzzle The puzzle instance to display goals for
---@field stack Stack The engine stack for dynamic data (move count, etc.)

---@class PuzzleGoalDisplay : UiElement
---@field puzzle Puzzle The puzzle instance
---@field stack Stack The player stack
---@field headingLabel Label The heading text label
---@field objectiveLabel Label The objective text label
---@field highlightTimer number Timer for initial highlight effect
---@field isHighlighted boolean Whether we are currently in highlight state
---@field normalHeadingColor table Normal heading color
---@field highlightHeadingColor table Highlighted heading color
---@field normalObjectiveColor table Normal objective color
---@field highlightObjectiveColor table Highlighted objective color
---@overload fun(options: PuzzleGoalDisplayOptions): PuzzleGoalDisplay
local PuzzleGoalDisplay = class(
  function(self, options)
    self.puzzle = options.puzzle
    self.stack = options.stack
    self.highlightTimer = 3.0
    self.isHighlighted = true
    self.lastObjectiveReplacements = {}

    self.normalHeadingColor = {1.0, 0.8, 0.2, 1.0}
    self.highlightHeadingColor = {1.0, 0.8, 0.2, 1.0}
    self.normalObjectiveColor = {0.9, 0.7, 0.1, 1.0}
    self.highlightObjectiveColor = {0.9, 0.7, 0.1, 1.0}
    
    self:createLabels()
    self:updateContent()
    self:updateDimensions()
  end,
  UIElement
)
PuzzleGoalDisplay.TYPE = "PuzzleGoalDisplay"

function PuzzleGoalDisplay:createLabels()
  
  self.headingLabel = ui.Label({
    x = BACKGROUND_PADDING,
    y = BACKGROUND_PADDING_VERTICAL,
    width = 0,
    height = 0,
    text = "",
    fontSize = 40,
    translate = true,
    hAlign = "left",
    vAlign = "top"
  })
  
  self.objectiveLabel = ui.Label({
    x = BACKGROUND_PADDING,
    y = BACKGROUND_PADDING_VERTICAL + 60,
    width = 0,
    height = 0,
    text = "",
    fontSize = 16,
    translate = true,
    hAlign = "left",
    vAlign = "top",
    wrapWidth = 200
  })
  
  self:addChild(self.headingLabel)
  self:addChild(self.objectiveLabel)
end

function PuzzleGoalDisplay:getHeadingKey()
  if self.puzzle.puzzleType == "moves" then
    return "puzzle_goal_move_heading"
  elseif self.puzzle.puzzleType == "chain" then
    return "puzzle_goal_chain_heading"
  elseif self.puzzle.puzzleType == "clear" then
    return "puzzle_goal_clear_heading"
  else
    return "puzzle_goal_unknown_heading"
  end
end

function PuzzleGoalDisplay:getObjectiveKey()
  if self.puzzle.puzzleType == "moves" then
    return "puzzle_goal_move_objective"
  elseif self.puzzle.puzzleType == "chain" then
    return "puzzle_goal_chain_objective"
  elseif self.puzzle.puzzleType == "clear" then
    return "puzzle_goal_clear_objective"
  else
    return "puzzle_goal_unknown_objective"
  end
end

function PuzzleGoalDisplay:getObjectiveReplacements()
  if self.puzzle.puzzleType == "moves" and self.stack then
    local moveNumber
    if self.stack.stackOverConditions[MatchRules.StackOverConditions.SWAPS] then
      moveNumber = self.stack.stackOverConditions[MatchRules.StackOverConditions.SWAPS] - self.stack.swapCount
    else
      moveNumber = self.stack.swapCount
    end
    return {tostring(moveNumber)}
  else
    return {}
  end
end

function PuzzleGoalDisplay:updateContent()
  self.headingLabel:setText(self:getHeadingKey(), {}, true)
  
  local replacements = self:getObjectiveReplacements()
  self.lastObjectiveReplacements = replacements
  self.objectiveLabel:setText(self:getObjectiveKey(), replacements, true)
  
  -- Apply text colors based on highlight state
  if self.isHighlighted then
    self.headingLabel:setTextColor(
      self.highlightHeadingColor[1],
      self.highlightHeadingColor[2], 
      self.highlightHeadingColor[3],
      self.highlightHeadingColor[4]
    )
    self.objectiveLabel:setTextColor(
      self.highlightObjectiveColor[1],
      self.highlightObjectiveColor[2],
      self.highlightObjectiveColor[3], 
      self.highlightObjectiveColor[4]
    )
  else
    self.headingLabel:setTextColor(
      self.normalHeadingColor[1],
      self.normalHeadingColor[2],
      self.normalHeadingColor[3],
      self.normalHeadingColor[4]
    )
    self.objectiveLabel:setTextColor(
      self.normalObjectiveColor[1],
      self.normalObjectiveColor[2],
      self.normalObjectiveColor[3],
      self.normalObjectiveColor[4]
    )
  end
  
  -- Update dimensions when content changes
  self:updateDimensions()
end

function PuzzleGoalDisplay:update(dt)
  if self.isHighlighted and self.highlightTimer > 0 then
    self.highlightTimer = self.highlightTimer - dt
    if self.isHighlighted and self.highlightTimer <= 0 then
      self.isHighlighted = false
      self:updateContent()
    end
  end
  
  if self.puzzle.puzzleType == "moves" then
    if tableUtils.deep_content_equal(self:getObjectiveReplacements(), self.lastObjectiveReplacements) == false then
      self:updateContent()
    end
  end
end

function PuzzleGoalDisplay:updateDimensions()
  -- Calculate width based on the widest content + padding
  local headingWidth = self.headingLabel.drawable and self.headingLabel.drawable:getWidth() or 0
  local objectiveWidth = self.objectiveLabel.drawable and self.objectiveLabel.drawable:getWidth() or 0
  local contentWidth = math.max(headingWidth, objectiveWidth)
  
  -- Calculate height based on both labels + spacing + padding
  local headingHeight = self.headingLabel.drawable and self.headingLabel.drawable:getHeight() or 0
  local objectiveHeight = self.objectiveLabel.drawable and self.objectiveLabel.drawable:getHeight() or 0
  local contentHeight = headingHeight + objectiveHeight + 10
  
  self.width = contentWidth + (BACKGROUND_PADDING * 2)
  self.height = contentHeight + (BACKGROUND_PADDING_VERTICAL * 2)
end

function PuzzleGoalDisplay:drawSelf()
  if self.isHighlighted then
    GraphicsUtil.setColor(COLORS.backgroundHighlight)
  else
    GraphicsUtil.setColor(COLORS.background)
  end
  love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)

  GraphicsUtil.setColor(COLORS.border)
  love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
  
  GraphicsUtil.setColor(COLORS.white)
end

return PuzzleGoalDisplay