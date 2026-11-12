local UIElement = require("client.src.ui.UIElement")
local ui = require("client.src.ui")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local MatchRules = require("common.data.MatchRules")
local Puzzle = require("common.engine.Puzzle")

local BACKGROUND_PADDING = 8
local BACKGROUND_PADDING_VERTICAL = 4
local HEADING_HEIGHT = 60
local CARD_SIZE = 48
local CARD_SPACING = 6
local CARDS_PER_LINE = 4
local CARD_STRIP_BOTTOM_MARGIN = 8
local ROW_SPACING = 2
local WRAP_WIDTH = CARDS_PER_LINE * CARD_SIZE + (CARDS_PER_LINE - 1) * CARD_SPACING
local HIGHLIGHT_SECONDS = 3.0
local BADGE_SCALE = 0.8
-- a card that completes darkens quickly while its check animates in: it grows past full size and settles back,
-- glowing green as it grows and fading as it settles
local DIM_SECONDS = 0.12
local CHECK_ANIMATION_SECONDS = 0.4
local CHECK_ANIMATION_START_SCALE = 0.4
local CHECK_ANIMATION_PEAK_SCALE = 1.12
local GLOW_BRIGHTNESS = 1
-- the glow is a green halo behind the check: how much bigger each layer of it is than the check, the widest
-- spilling just past the card at the check animation's peak, and how opaque the layer is at the glow's peak
local GLOW_LAYERS = {
  {spread = 0.24, alpha = 0.2},
  {spread = 0.18, alpha = 0.3},
  {spread = 0.12, alpha = 0.45},
  {spread = 0.06, alpha = 0.65},
}
-- a finished card is darkened to this grey level so the check over it is what stands out
local COMPLETE_CARD_SHADE = 0.35

local COLORS = {
  background = {0.05, 0.05, 0.1, 0.75},
  backgroundHighlight = {0.12, 0.12, 0.2, 0.85},
  border = {1.0, 0.8, 0.1, 0.4},
  heading = {1.0, 0.8, 0.2, 1.0},
  objective = {0.9, 0.7, 0.1, 1.0},
  complete = {0.4, 0.9, 0.4, 1.0},
  white = {1, 1, 1, 1}
}

---@class PuzzleGoalCard one chain or combo card in the box; a goal asked for twice has two
---@field isChain boolean
---@field size integer
---@field complete boolean
---@field checkAnimationElapsed number? seconds into the check animation played when the card completes, nil when none is playing

---@class PuzzleGoalRow one line of objective text
---@field goalKind PuzzleGoalKind | "swaps"
---@field size integer? the chain or combo size the row is about
---@field key string localization key
---@field label Label
---@field complete boolean
---@field lastReplacement string?

---@class PuzzleGoalDisplayOptions : UiElementOptions
---@field puzzle Puzzle The puzzle instance to display goals for
---@field stack Stack The engine stack for dynamic data (move count, etc.)

-- The box beside the stack saying what the puzzle asks for.
-- Everything it shows as done is read from the stack each frame, so it follows a rollback or a reset by itself.
---@class PuzzleGoalDisplay : UiElement
---@field puzzle Puzzle The puzzle instance
---@field stack Stack The player stack
---@field headingLabel Label The heading text label
---@field cards PuzzleGoalCard[]
---@field rows PuzzleGoalRow[]
---@field highlightTimer number seconds the box stays highlighted for
---@field goalCounts table<string, table<integer, integer>> goal kind -> size -> how many of it the puzzle asks for
---@field cardPositions table<boolean, table<integer, integer>> isChain -> size -> cards of it walked so far this refresh
---@field replacements string[] the row text replacements of the row being refreshed
---@field needsLayout boolean set when a row's text or color changed, so update re-lays out the box
---@overload fun(options: PuzzleGoalDisplayOptions): PuzzleGoalDisplay
local PuzzleGoalDisplay = class(
  function(self, options)
    self.puzzle = options.puzzle
    self.stack = options.stack
    self.highlightTimer = HIGHLIGHT_SECONDS

    self.goalCounts = {
      [Puzzle.GOAL_KINDS.chain] = self.puzzle:goalCountsBySize(Puzzle.GOAL_KINDS.chain),
      [Puzzle.GOAL_KINDS.combo] = self.puzzle:goalCountsBySize(Puzzle.GOAL_KINDS.combo)
    }
    -- reused every frame so that following the stack's progress allocates nothing
    self.cardPositions = {[true] = {}, [false] = {}}
    self.replacements = {}

    self.cards = self:createCards()
    self:createLabels()
    self:refreshProgress(false)
    self:layout()
  end,
  UIElement
)
PuzzleGoalDisplay.TYPE = "PuzzleGoalDisplay"

-- One card per chain and combo goal, a goal asked for twice getting two
---@return PuzzleGoalCard[]
function PuzzleGoalDisplay:createCards()
  local cards = {}
  for _, goal in ipairs(self.puzzle.goals) do
    if goal.kind == Puzzle.GOAL_KINDS.chain or goal.kind == Puzzle.GOAL_KINDS.combo then
      cards[#cards + 1] = {isChain = goal.kind == Puzzle.GOAL_KINDS.chain, size = goal.size, complete = false}
    end
  end
  return cards
end

-- Whether the puzzle plays as a one-word type, as a version 3 file's puzzles and one-goal Empty Board or Clear lists do
---@return boolean
function PuzzleGoalDisplay:isOldType()
  return self.puzzle.puzzleType ~= Puzzle.GOALS_TYPE
end

-- The localization key of the box's heading, named after the puzzle's type or the kinds of goal it asks for
---@return string
function PuzzleGoalDisplay:getHeadingKey()
  if self.puzzle.puzzleType == Puzzle.PUZZLE_TYPES.moves then
    return "puzzle_goal_move_heading"
  elseif self.puzzle.puzzleType == Puzzle.PUZZLE_TYPES.chain then
    return "puzzle_goal_chain_heading"
  elseif self.puzzle.puzzleType == Puzzle.PUZZLE_TYPES.clear then
    return "puzzle_goal_clear_heading"
  end

  local hasChain = self.puzzle:hasGoal(Puzzle.GOAL_KINDS.chain)
  local hasCombo = self.puzzle:hasGoal(Puzzle.GOAL_KINDS.combo)
  if hasChain and hasCombo then
    return "puzzle_goal_combo_chain_heading"
  elseif hasChain then
    return "puzzle_goal_chain_heading"
  elseif hasCombo then
    return "puzzle_goal_combo_heading"
  elseif self.puzzle:hasGoal(Puzzle.GOAL_KINDS.clear) then
    return "puzzle_goal_clear_heading"
  elseif self.puzzle:hasGoal(Puzzle.GOAL_KINDS.emptyBoard) then
    return "puzzle_goal_move_heading"
  end
  return "puzzle_goal_unknown_heading"
end

-- Adds a line of objective text under the cards
---@param goalKind PuzzleGoalKind | "swaps"
---@param key string
---@param size integer?
function PuzzleGoalDisplay:addRow(goalKind, key, size)
  local label = ui.Label({
    x = BACKGROUND_PADDING,
    y = 0,
    width = 0,
    height = 0,
    text = "",
    fontSize = 16,
    translate = true,
    hAlign = "left",
    vAlign = "top",
    wrapWidth = WRAP_WIDTH
  })
  self:addChild(label)
  self.rows[#self.rows + 1] = {goalKind = goalKind, size = size, key = key, label = label, complete = false}
end

-- one row per size of chain and combo however often it is asked for, the cards show how often
---@param kind PuzzleGoalKind chain or combo
---@param key string
---@param repeatedKey string
function PuzzleGoalDisplay:addTargetRows(kind, key, repeatedKey)
  local counts = self.goalCounts[kind]
  local seen = {}
  for _, goal in ipairs(self.puzzle.goals) do
    if goal.kind == kind and not seen[goal.size] then
      seen[goal.size] = true
      self:addRow(kind, counts[goal.size] > 1 and repeatedKey or key, goal.size)
    end
  end
end

-- Creates the heading and one objective row per goal, plus the swaps left when the puzzle has a swap limit
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
  self.headingLabel:setText(self:getHeadingKey(), {}, true)
  self.headingLabel:setTextColor(COLORS.heading[1], COLORS.heading[2], COLORS.heading[3], COLORS.heading[4])
  self:addChild(self.headingLabel)

  self.rows = {}
  if self.puzzle.puzzleType == Puzzle.PUZZLE_TYPES.moves then
    local key = self.puzzle.moves > 0 and "puzzle_goal_move_objective" or "puzzle_goal_empty_board_objective"
    self:addRow(Puzzle.GOAL_KINDS.emptyBoard, key)
  elseif self.puzzle.puzzleType == Puzzle.PUZZLE_TYPES.chain then
    self:addRow(Puzzle.GOAL_KINDS.legacyChain, "puzzle_goal_chain_objective")
  else
    self:addTargetRows(Puzzle.GOAL_KINDS.chain, "puzzle_goal_chain_target_objective", "puzzle_goal_chain_target_repeated_objective")
    self:addTargetRows(Puzzle.GOAL_KINDS.combo, "puzzle_goal_combo_target_objective", "puzzle_goal_combo_target_repeated_objective")
    if self.puzzle:hasGoal(Puzzle.GOAL_KINDS.emptyBoard) then
      self:addRow(Puzzle.GOAL_KINDS.emptyBoard, "puzzle_goal_empty_board_objective")
    end
    if self.puzzle:hasGoal(Puzzle.GOAL_KINDS.clear) then
      self:addRow(Puzzle.GOAL_KINDS.clear, "puzzle_goal_clear_objective")
    end
    if self.puzzle.moves > 0 then
      self:addRow("swaps", "puzzle_goal_swaps_left")
    end
  end
end

-- How many swaps the stack can still make before the swap limit ends the puzzle
---@return integer
function PuzzleGoalDisplay:swapsLeft()
  local swapLimit = self.stack.stackOverConditions[MatchRules.StackOverConditions.SWAPS] or self.puzzle.moves
  return swapLimit - self.stack.swapCount
end

-- The values filled into a row's text: the goal's size and count, or the swaps left
---@param row PuzzleGoalRow
---@return string[] # the display's one buffer, only good until the next call
function PuzzleGoalDisplay:rowReplacements(row)
  local replacements = self.replacements
  table.clear(replacements)
  if row.goalKind == Puzzle.GOAL_KINDS.chain or row.goalKind == Puzzle.GOAL_KINDS.combo then
    replacements[1] = tostring(row.size)
    replacements[2] = tostring(self.goalCounts[row.goalKind][row.size])
  elseif row.goalKind == "swaps" or row.key == "puzzle_goal_move_objective" then
    replacements[1] = tostring(self:swapsLeft())
  end
  return replacements
end

-- How many chains or combos of exactly the size the stack has made
---@param isChain boolean
---@param size integer
---@return integer # how many of that size the stack has made so far
function PuzzleGoalDisplay:madeCount(isChain, size)
  local made = isChain and self.stack.tally.chains or self.stack.tally.combos
  return made[size] or 0
end

-- Whether a row's goal is met by what the stack has done so far
---@param row PuzzleGoalRow
---@return boolean
function PuzzleGoalDisplay:rowIsComplete(row)
  if row.goalKind == Puzzle.GOAL_KINDS.chain or row.goalKind == Puzzle.GOAL_KINDS.combo then
    local isChain = row.goalKind == Puzzle.GOAL_KINDS.chain
    return self:madeCount(isChain, row.size) >= self.goalCounts[row.goalKind][row.size]
  elseif self:isOldType() then
    -- a puzzle of an old type has the one goal, which ends it the moment it is met
    return false
  elseif row.goalKind == Puzzle.GOAL_KINDS.emptyBoard then
    return self.stack:meetsWinCondition(MatchRules.StackWinConditions.MATCHABLE_PANELS, 0)
  elseif row.goalKind == Puzzle.GOAL_KINDS.clear then
    return self.stack:meetsWinCondition(MatchRules.StackWinConditions.GARBAGE_BUFFER_EXCEEDED, 0)
  end
  return false
end

-- The first cards of a size complete first, as many as the stack has made of it
---@param playEffects boolean whether a card that completes plays its check animation
function PuzzleGoalDisplay:refreshCards(playEffects)
  table.clear(self.cardPositions[true])
  table.clear(self.cardPositions[false])
  for _, card in ipairs(self.cards) do
    local positions = self.cardPositions[card.isChain]
    local position = (positions[card.size] or 0) + 1
    positions[card.size] = position
    local complete = position <= self:madeCount(card.isChain, card.size)
    if complete and not card.complete and playEffects then
      card.checkAnimationElapsed = 0
    end
    card.complete = complete
  end
end

-- Brings the cards and rows up to date with the stack, re-laying out the box when a row's text or color changed
---@param playEffects boolean whether a card that completes plays its check animation
function PuzzleGoalDisplay:refreshProgress(playEffects)
  self:refreshCards(playEffects)

  for _, row in ipairs(self.rows) do
    local complete = self:rowIsComplete(row)
    local replacements = self:rowReplacements(row)
    local replacement = table.concat(replacements, ",")
    if complete ~= row.complete or replacement ~= row.lastReplacement then
      row.complete = complete
      row.lastReplacement = replacement
      -- the label keeps the table it is given and skips a table it already has, so a changed row gets its own copy
      row.label:setText(row.key, {unpack(replacements)}, true)
      local color = complete and COLORS.complete or COLORS.objective
      row.label:setTextColor(color[1], color[2], color[3], color[4])
      self.needsLayout = true
    end
  end
end

-- The height the cards take up, wrapped onto lines of CARDS_PER_LINE
---@return integer
function PuzzleGoalDisplay:cardStripHeight()
  if #self.cards == 0 then
    return 0
  end
  local lines = math.ceil(#self.cards / CARDS_PER_LINE)
  return lines * CARD_SIZE + (lines - 1) * CARD_SPACING + CARD_STRIP_BOTTOM_MARGIN
end

-- Places the rows under the heading and cards and sizes the box to fit its content
function PuzzleGoalDisplay:layout()
  self.needsLayout = false
  local y = BACKGROUND_PADDING_VERTICAL + HEADING_HEIGHT + self:cardStripHeight()
  local contentWidth = self.headingLabel.drawable and self.headingLabel.drawable:getWidth() or 0
  if #self.cards > 0 then
    local cardsInWidestLine = math.min(#self.cards, CARDS_PER_LINE)
    contentWidth = math.max(contentWidth, cardsInWidestLine * CARD_SIZE + (cardsInWidestLine - 1) * CARD_SPACING)
  end

  for _, row in ipairs(self.rows) do
    row.label.y = y
    local drawable = row.label.drawable
    if drawable then
      y = y + drawable:getHeight() + ROW_SPACING
      contentWidth = math.max(contentWidth, drawable:getWidth())
    end
  end

  self.width = contentWidth + (BACKGROUND_PADDING * 2)
  self.height = y + BACKGROUND_PADDING_VERTICAL
end

function PuzzleGoalDisplay:update(dt)
  if self.highlightTimer > 0 then
    self.highlightTimer = self.highlightTimer - dt
  end
  for _, card in ipairs(self.cards) do
    if card.checkAnimationElapsed then
      card.checkAnimationElapsed = card.checkAnimationElapsed + dt
      if card.checkAnimationElapsed >= CHECK_ANIMATION_SECONDS then
        card.checkAnimationElapsed = nil
      end
    end
  end

  self:refreshProgress(true)
  if self.needsLayout then
    self:layout()
  end
end

-- CSS's ease-out, cubic-bezier(0, 0, 0.58, 1), which the check animation was designed with
---@param progress number 0 to 1
---@return number
local function easeOut(progress)
  -- the search below only gets near its ends, and a settled check animation has to land on them exactly
  if progress <= 0 then
    return 0
  elseif progress >= 1 then
    return 1
  end
  local low, high = 0, 1
  local t = progress
  for _ = 1, 20 do
    t = (low + high) / 2
    if 3 * (1 - t) * t * t * 0.58 + t * t * t < progress then
      low = t
    else
      high = t
    end
  end
  return 3 * (1 - t) * t * t + t * t * t
end

-- Eases from one value to another with the check animation's ease-out curve
---@param from number
---@param to number
---@param progress number 0 to 1
---@return number
local function easeBetween(from, to, progress)
  return from + (to - from) * easeOut(progress)
end

-- How a completed card looks a given time into its check animation: it dims while the check grows past full size, and the check
-- settles while its glow fades
---@param elapsed number seconds since the card completed
---@return number dim how far the card has darkened, 0 to 1
---@return number checkScale the check's size as a share of its full size
---@return number checkAlpha
---@return number glow 0 to 1
function PuzzleGoalDisplay.checkAnimationAt(elapsed)
  local dim = easeOut(math.min(1, elapsed / DIM_SECONDS))
  local progress = math.min(1, elapsed / CHECK_ANIMATION_SECONDS)
  if progress < 0.5 then
    local grow = progress * 2
    local checkAlpha = easeOut(grow)
    -- the glow belongs to the check, so it is only as visible as the check is
    return dim, easeBetween(CHECK_ANIMATION_START_SCALE, CHECK_ANIMATION_PEAK_SCALE, grow), checkAlpha, easeOut(grow) * checkAlpha
  end
  local settle = (progress - 0.5) * 2
  return dim, easeBetween(CHECK_ANIMATION_PEAK_SCALE, 1, settle), 1, easeBetween(1, 0, settle)
end

-- The theme's chain or combo card image for the card's size
---@param card PuzzleGoalCard
---@return love.Texture?
local function cardImage(card)
  local theme = themes[config.theme]
  if card.isChain then
    return theme:chainImage(card.size)
  end
  return theme:comboImage(card.size)
end

-- Draws the complete badge centred on a point at the given share of its full size
---@param badge love.Texture
---@param centerX number
---@param centerY number
---@param scale number
local function drawBadge(badge, centerX, centerY, scale)
  local size = CARD_SIZE * BADGE_SCALE * scale
  GraphicsUtil.draw(badge, centerX, centerY, 0, size / badge:getWidth(), size / badge:getHeight(), badge:getWidth() / 2,
                    badge:getHeight() / 2)
end

-- Draws a card, darkened with its check once it is complete
---@param card PuzzleGoalCard
---@param x number
---@param y number
function PuzzleGoalDisplay:drawCard(card, x, y)
  local dim, checkScale, checkAlpha, glow = 0, 1, 1, 0
  if card.complete then
    dim, checkScale, checkAlpha, glow = PuzzleGoalDisplay.checkAnimationAt(card.checkAnimationElapsed or CHECK_ANIMATION_SECONDS)
  end

  local image = cardImage(card)
  if image then
    local shade = 1 + (COMPLETE_CARD_SHADE - 1) * dim
    GraphicsUtil.setColor(shade, shade, shade, 1)
    GraphicsUtil.draw(image, x, y, 0, CARD_SIZE / image:getWidth(), CARD_SIZE / image:getHeight())
  end

  local badge = card.complete and themes[config.theme].images.complete
  if not badge then
    return
  end
  local centerX, centerY = x + CARD_SIZE / 2, y + CARD_SIZE / 2

  local green = COLORS.complete
  for _, layer in ipairs(GLOW_LAYERS) do
    if glow > 0 then
      GraphicsUtil.setColor(green[1], green[2], green[3], glow * layer.alpha)
      drawBadge(badge, centerX, centerY, checkScale * (1 + layer.spread))
    end
  end
  GraphicsUtil.setColor(1, 1, 1, checkAlpha)
  drawBadge(badge, centerX, centerY, checkScale)
  if glow > 0 then
    local previousBlendMode, previousAlphaMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add")
    GraphicsUtil.setColor(1, 1, 1, glow * GLOW_BRIGHTNESS)
    drawBadge(badge, centerX, centerY, checkScale)
    love.graphics.setBlendMode(previousBlendMode, previousAlphaMode)
  end
end

function PuzzleGoalDisplay:drawSelf()
  if self.highlightTimer > 0 then
    GraphicsUtil.setColor(COLORS.backgroundHighlight)
  else
    GraphicsUtil.setColor(COLORS.background)
  end
  love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)

  GraphicsUtil.setColor(COLORS.border)
  love.graphics.rectangle("line", self.x, self.y, self.width, self.height)

  local stripY = self.y + BACKGROUND_PADDING_VERTICAL + HEADING_HEIGHT
  for i, card in ipairs(self.cards) do
    local column = (i - 1) % CARDS_PER_LINE
    local line = math.floor((i - 1) / CARDS_PER_LINE)
    self:drawCard(card, self.x + BACKGROUND_PADDING + column * (CARD_SIZE + CARD_SPACING), stripY + line * (CARD_SIZE + CARD_SPACING))
  end

  GraphicsUtil.setColor(COLORS.white)
end

return PuzzleGoalDisplay
