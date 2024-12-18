local ClientStack = require("client.src.ClientStack")
local class = require("common.lib.class")
require("common.lib.util")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local TouchDataEncoding = require("common.data.TouchDataEncoding")
local consts = require("common.engine.consts")
local prof = require("common.lib.jprof.jprof")
local EngineStack = require("common.engine.Stack")
require("common.engine.checkMatches")
local tableUtils = require("common.lib.tableUtils")
local GameModes = require("common.engine.GameModes")
local TouchInputDetector = require("client.src.TouchInputDetector")
local Signal = require("common.lib.signal")
local logger = require("common.lib.logger")
require("client.src.analytics")
---@module "common.data.LevelData"

local floor, min, max = math.floor, math.min, math.max

---@class PlayerStack : ClientStack, Signal
---@field engine Stack
---@field garbageTarget PlayerStack
---@field panels_dir string the id of the panel set id used for its shock garbage images
---@field poppedPanelIndex integer
---@field danger boolean panels in the top row (danger); unlike panels_in_top_row I think this does not indicate a top out in all cases
---@field danger_timer integer Decides the bounce frame while the column is in danger, increments and stops according to certain rules
---@field danger_col boolean[] Tracks for each column if it is considered in danger for the danger animation. Danger means high rows being filled in that column. \n
---@field analytic table

-- A client side stack that wraps an engine Stack
-- engine functionality is masked by wrapping the relevant functions and fields Match interfaces with
-- not elegant but the primary purpose is to get Stack clean first; Match should eventually follow and then it can get revisited
---@class PlayerStack
---@overload fun(args: table): PlayerStack
local PlayerStack = class(
function(self, args)
  ---@class PlayerStack
  self = self
  self.player = args.player
  args.which = self.which
  self.stackInteraction = args.stackInteraction

  self.engine = EngineStack(args)
  self.engine:connectSignal("panelLanded", self, self.onPanelLand)
  self.engine:connectSignal("panelPop", self, self.onPanelPop)
  self.engine:connectSignal("matched", self, self.onEngineMatched)
  self.engine:connectSignal("cursorMoved", self, self.onCursorMoved)
  self.engine:connectSignal("panelsSwapped", self, self.onPanelsSwapped)
  self.engine:connectSignal("gameOver", self, self.onGameOver)
  self.engine:connectSignal("newRow", self, self.onNewRow)
  self.engine:connectSignal("finishedRun", self, self.onRun)
  self.engine:connectSignal("rollbackPerformed", self, self.onRollback)
  self.engine:connectSignal("rollbackSaved", self, self.onRollbackSaved)
  -- currently unused
  --self.engine.outgoingGarbage:connectSignal("garbagePushed", self, self.onGarbagePushed)
  --self.engine.outgoingGarbage:connectSignal("newChainLink", self, self.onNewChainLink)
  self.engine.outgoingGarbage:connectSignal("chainEnded", self, self.onChainEnded)

  self.panels_dir = args.panels_dir
  if not self.panels_dir or not panels[self.panels_dir] then
    self.panels_dir = config.panels
  end

  self.analytic = AnalyticsInstance(self.is_local)
  self.drawsAnalytics = true

  -- level and difficulty only for icon display and score saving, all actual data is in levelData
  self.difficulty = args.difficulty
  self.level = args.level

  self.inputMethod = args.inputMethod or "controller"
  if self.inputMethod == "touch" then
    self.touchInputDetector = TouchInputDetector(self)
  end

  self.card_q = Queue()
  self.pop_q = Queue()

  self.danger_col = {false, false, false, false, false, false}
  self.danger_timer = 0

  self.multiBarFrameCount = self:calculateMultibarFrameCount()

  -- sfx
  -- index used for picking a pop sound
  self.poppedPanelIndex = 1
  self.lastPopLevelPlayed = 1
  self.lastPopIndexPlayed = 1
  self.combo_chain_play = nil
  self.sfx_land = false
  self.sfx_garbage_thud = 0
  self.sfxSwap = false
  self.sfxCursorMove = false
  self.sfxGarbageMatch = false
  self.sfxFanfare = 0
  self.sfxPop = true
  self.sfxGarbagePop = 0

  self.taunt_up = nil -- will hold an index
  self.taunt_down = nil -- will hold an index
  self.taunt_queue = Queue()

  Signal.turnIntoEmitter(self)
  self:createSignal("dangerMusicChanged")
end,
ClientStack)


-------------------------------------------
--- Callbacks from engine subscriptions ---
-------------------------------------------

function PlayerStack:onEngineMatched(engine, attackGfxOrigin, isChainLink, comboSize, metalCount, garbagePanelCount)
  self:enqueueCards(attackGfxOrigin, isChainLink, comboSize)
  if isChainLink or comboSize > 3 or metalCount > 0 then
    self:queueAttackSoundEffect(isChainLink, engine.chain_counter, comboSize, metalCount)
  end

  self.analytic:register_destroyed_panels(comboSize)

  for i = 3, metalCount do
    self.analytic:registerShock()
  end
end

function PlayerStack:onGameOver(engine)
  SoundController:playSfx(themes[config.theme].sounds.game_over)

  if self.canvas then
    local popsize = "small"
    local panels = engine.panels
    for row = 1, #panels do
      for col = 1, engine.width do
        local panel = panels[row][col]
        panel.state = "dead"
        if row == #panels then
          self:enqueue_popfx(col, row, popsize)
        end
      end
    end
  end

  self.game_over_clock = self.engine.game_over_clock
end

---@param panel Panel
function PlayerStack:onPanelPop(panel)
  if panel.isGarbage then
    if config.popfx == true then
      self:enqueue_popfx(panel.column, panel.row, self.popSizeThisFrame)
    end
    if self:canPlaySfx() then
      self.sfxGarbagePop = panel.pop_index
    end
  else
    if config.popfx == true then
      if (panel.combo_size > 6) or self.engine.chain_counter > 1 then
        self.popSizeThisFrame = "normal"
      end
      if self.engine.chain_counter > 2 then
        self.popSizeThisFrame = "big"
      end
      if self.engine.chain_counter > 3 then
        self.popSizeThisFrame = "giant"
      end
      self:enqueue_popfx(panel.column, panel.row, self.popSizeThisFrame)
    end

    if self:canPlaySfx() then
      self.sfxPop = true
    end
    self.poppedPanelIndex = panel.combo_index
  end
end

---@param panel Panel
function PlayerStack:onPanelLand(panel)
  if panel.isGarbage then
    if panel.shake_time
    -- only parts of the garbage that are on the visible board can be considered for shake
    and panel.row <= self.engine.height then
    --runtime optimization to not repeatedly update shaketime for the same piece of garbage
    if not tableUtils.contains(self.engine.garbageLandedThisFrame, panel.garbageId) then
      if self:canPlaySfx() then
        if panel.height > 3 then
          self.sfx_garbage_thud = 3
        else
          self.sfx_garbage_thud = panel.height
        end
      end
    end
  end
  else
    if panel.state == "falling" and self:canPlaySfx() then
      self.sfx_land = true
    end
  end
end

function PlayerStack:onCursorMoved(previousRow, previousCol)
  local playMoveSounds = true -- set this to false to disable move sounds for debugging
  local engine = self.engine
  if (playMoveSounds and (engine.cur_timer == 0 or engine.cur_timer == engine.cur_wait_time) and (engine.cur_row ~= previousRow or engine.cur_col ~= previousCol)) then
    if self:canPlaySfx() then
      self.sfxCursorMove = true
    end
    if engine.cur_timer ~= engine.cur_wait_time then
      self.analytic:register_move()
    end
  end
end

function PlayerStack:onGarbagePushed(garbage)
  -- unused but we might want to hook in here for combo cards / attack animation at some point
end

function PlayerStack:onNewChainLink(chainGarbage)
  -- unused but we might want to hook in here for chain cards / attack animation at some point
end

function PlayerStack:onChainEnded(chainGarbage)
  if self:canPlaySfx() then
    self.sfxFanfare = #chainGarbage.linkTimes + 1
  end
  self.analytic:register_chain(#chainGarbage.linkTimes + 1)
end

function PlayerStack:onPanelsSwapped()
  if self:canPlaySfx() then
    self.sfxSwap = true
  end
  self.analytic:register_swap()
end

function PlayerStack:onGarbageMatched(panelCount, onScreenCount)
  if self:canPlaySfx() then
    self.sfxGarbageMatch = true
  end
end

function PlayerStack:onNewRow(engine)

end

function PlayerStack:onRollback(engine)
  -- other.danger_timer = source.danger_timer

  -- to fool Match without having to wrap everything into getters
  self.clock = engine.clock
  self.game_stopwatch = engine.game_stopwatch

  prof.push("rollback copy analytics")
  self.analytic:rollbackToFrame(self.clock)
  prof.pop("rollback copy analytics")
end

function PlayerStack:onRollbackSaved(frame)
  self.analytic:saveRollbackCopy(frame)
end

--- callback for operations to run after each single run of the engine Stack
function PlayerStack:onRun()
  self:processTaunts()

  self:playSfx()

  prof.push("update popfx")
  self:update_popfxs()
  prof.pop("update popfx")
  prof.push("update cards")
  self:update_cards()
  prof.pop("update cards")

  -- these were previously at the start of Stack:run
  -- so by putting them at the end, order is restored
  self.popSizeThisFrame = "small"
  self:updateDangerBounce()
  self:updateDangerMusic()
end

------------------------------------------------------------------------
--- Wrappers around the engine Stack to access engine info in scenes ---
------------------------------------------------------------------------

function PlayerStack:rewindToFrame(frame)
  self.engine:rewindToFrame(frame)
end

---@return boolean
function PlayerStack:game_ended()
  return self.engine:game_ended()
end

function PlayerStack:runGameOver()
  self:update_popfxs()
  self:update_cards()
end

function PlayerStack:receiveConfirmedInput(inputs)
  self.engine:receiveConfirmedInput(inputs)
end

function PlayerStack:enableCatchup(enable)
  self.engine:enableCatchup(enable)
end

function PlayerStack:setMaxRunsPerFrame(maxRunsPerFrame)
  self.engine:setMaxRunsPerFrame(maxRunsPerFrame)
end

---------------------------------------------
--- Overwrites for parent class functions ---
---------------------------------------------

-- Should be called prior to clearing the stack.
-- Consider recycling any memory that might leave around a lot of garbage.
-- Note: You can just leave the variables to clear / garbage collect on their own if they aren't large.
function PlayerStack:deinit()
  GraphicsUtil:releaseQuad(self.healthQuad)
  GraphicsUtil:releaseQuad(self.multi_prestopQuad)
  GraphicsUtil:releaseQuad(self.multi_stopQuad)
  GraphicsUtil:releaseQuad(self.multi_shakeQuad)
end

---------------------
------ Graphics -----
---------------------


-- The popping particle animation. First number is how far the particles go, second is which frame to show from the spritesheet
local POPFX_BURST_ANIMATION = {{1, 1}, {4, 1}, {7, 1}, {8, 1}, {9, 1}, {9, 1},
                               {10, 1}, {10, 2}, {10, 2}, {10, 3}, {10, 3}, {10, 4},
                               {10, 4}, {10, 5}, {10, 5}, {10, 6}, {10, 6}, {10, 7},
                               {10, 7}, {10, 8}, {10, 8}, {10, 8}}

local POPFX_FADE_ANIMATION = {1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8}

-- Draws an image at the given spot while scaling all coordinate and scale values with stack.gfxScale
local function drawGfxScaled(stack, img, x, y, rot, xScale, yScale)
  xScale = xScale or 1
  yScale = yScale or 1
  GraphicsUtil.draw(img, x * stack.gfxScale, y * stack.gfxScale, rot, xScale * stack.gfxScale, yScale * stack.gfxScale)
end

-- Draws an image at the given position, using the quad for the viewport, scaling all coordinate values and scales by stack.gfxScale
local function drawQuadGfxScaled(stack, image, quad, x, y, rotation, xScale, yScale, xOffset, yOffset, mirror)
  xScale = xScale or 1
  yScale = yScale or 1

  if mirror and mirror == 1 then
    local qX, qY, qW, qH = quad:getViewport()
    x = x - (qW*xScale)
  end

  GraphicsUtil.drawQuad(image, quad, x * stack.gfxScale, y * stack.gfxScale, rotation, xScale * stack.gfxScale, yScale * stack.gfxScale, xOffset, yOffset)
end

-- there were some experiments for different shake animation
-- their stale code was removed with commit 4104c86b3005f8d8c2931767d3d2df5618f2ac15

-- Setup the shake data used for rendering the stack shake animation
local function calculateShakeData(maxShakeFrames, maxAmplitude)

  local shakeData = {}

  local shakeIndex = -6
  for i = 14, 6, -1 do
    local x = -math.pi
    local step = math.pi * 2 / i
    for j = 1, i do
      shakeData[shakeIndex] = (1 + math.cos(x)) / 2
      x = x + step
      shakeIndex = shakeIndex + 1
    end
  end

  -- 1 -> 1
  -- #shake -> 0
  local shakeStep = 1 / (#shakeData - 1)
  local shakeMultiplier = 1
  for i = 1, #shakeData do
    shakeData[i] = shakeData[i] * shakeMultiplier * 13
    -- print(shakeData[i])
    shakeMultiplier = shakeMultiplier - shakeStep
  end

  return shakeData
end

local shakeOffsetData = calculateShakeData()

function PlayerStack:currentShakeOffset()
  return self:shakeOffsetForShakeFrames(self.engine.shake_time, self.engine.prev_shake_time)
end

local function privateShakeOffsetForShakeFrames(frames, shakeIntensity, gfxScale)
  if frames <= 0 then
    return 0
  end

  local lookupIndex = #shakeOffsetData - frames
  local result = shakeOffsetData[lookupIndex] or 0
  if result ~= 0 then
    result = math.integerAwayFromZero(result * shakeIntensity * gfxScale)
  end
  return result
end

function PlayerStack:shakeOffsetForShakeFrames(frames, previousShakeTime, shakeIntensity)

  if shakeIntensity == nil then
    shakeIntensity = config.shakeIntensity
  end

  local result = privateShakeOffsetForShakeFrames(frames, shakeIntensity, self.gfxScale)
  -- If we increased shake time we don't want to hard jump to the new value as its jarring.
  -- Interpolate on the first frame to smooth it out a little bit.
  if previousShakeTime > 0 and previousShakeTime < frames then
    local previousOffset = privateShakeOffsetForShakeFrames(previousShakeTime, shakeIntensity, self.gfxScale)
    result = math.integerAwayFromZero((result + previousOffset) / 2)
  end
  return result
end

function PlayerStack:enqueueCards(attackGfxOrigin, isChainLink, comboSize)
  if comboSize > 3 and isChainLink then
    -- we did a combo AND a chain; cards should not overlap so offset the chain card to one row above the combo card
    self:enqueue_card(false, attackGfxOrigin.column, attackGfxOrigin.row, comboSize)
    self:enqueue_card(true, attackGfxOrigin.column, attackGfxOrigin.row + 1, self.engine.chain_counter)
  elseif comboSize > 3 then
    -- only a combo
    self:enqueue_card(false, attackGfxOrigin.column, attackGfxOrigin.row, comboSize)
  elseif isChainLink then
    -- only a chain
    self:enqueue_card(true, attackGfxOrigin.column, attackGfxOrigin.row, self.engine.chain_counter)
  end
end

-- Enqueue a card animation
function PlayerStack.enqueue_card(self, chain, x, y, n)
  if self.canvas == nil or self.engine.play_to_end then
    return
  end

  local card_burstAtlas = nil
  local card_burstParticle = nil
  if config.popfx == true then
    if self.character.popfx_style == "burst" or self.character.popfx_style == "fadeburst" then
      card_burstAtlas = self.character.images["burst"]
      local card_burstFrameDimension = card_burstAtlas:getWidth() / 9
      card_burstParticle = GraphicsUtil:newRecycledQuad(card_burstFrameDimension, 0, card_burstFrameDimension, card_burstFrameDimension, card_burstAtlas:getDimensions())
    end
  end
  self.card_q:push({frame = 1, chain = chain, x = x, y = y, n = n, burstAtlas = card_burstAtlas, burstParticle = card_burstParticle})
end

-- Update all the card frames used for doing the card animation
function PlayerStack.update_cards(self)
  if self.canvas == nil then
    return
  end

  for i = self.card_q.first, self.card_q.last do
    local card = self.card_q[i]
    if consts.CARD_ANIMATION[card.frame] then
      card.frame = card.frame + 1
      if (consts.CARD_ANIMATION[card.frame] == nil) then
        if config.popfx == true then
          GraphicsUtil:releaseQuad(card.burstParticle)
        end
        self.card_q:pop()
      end
    else
      card.frame = card.frame + 1
    end
  end
end

-- Render the card animations used to show "bursts" when a combo or chain happens
function PlayerStack.drawCards(self)
  for i = self.card_q.first, self.card_q.last do
    local card = self.card_q[i]
    if consts.CARD_ANIMATION[card.frame] then
      local draw_x = (self.panelOriginX) + (card.x - 1) * 16
      local draw_y = (self.panelOriginY) + (11 - card.y) * 16 + self.engine.displacement - consts.CARD_ANIMATION[card.frame]
      -- Draw burst around card
      if card.burstAtlas and card.frame then
        GraphicsUtil.setColor(1, 1, 1, self:opacityForFrame(card.frame, 1, 22))
        --drawQuadGfxScaled(self, card.burstAtlas, card.burstParticle, cardfx_x, cardfx_y, 0, 16 / burstFrameDimension, 16 / burstFrameDimension)
        self:drawRotatingCardBurstEffectGroup(card, draw_x, draw_y)
        GraphicsUtil.setColor(1, 1, 1, 1)
      end
      -- draw card
      local iconSize = 16
      local cardImage = nil
      if card.chain then
        cardImage = self.theme:chainImage(card.n)
      else
        cardImage = self.theme:comboImage(card.n)
      end
      if cardImage then
        local icon_width, icon_height = cardImage:getDimensions()
        GraphicsUtil.setColor(1, 1, 1, self:opacityForFrame(card.frame, 1, 22))
        drawGfxScaled(self, cardImage, draw_x, draw_y, 0, iconSize / icon_width, iconSize / icon_height)
        GraphicsUtil.setColor(1, 1, 1, 1)
      end
    end
  end
end

function PlayerStack:opacityForFrame(frame, startFadeFrame, maxFadeFrame)
  local opacity = 1
  if frame >= startFadeFrame then
    local currentFrame = frame - startFadeFrame
    local maxFrame = maxFadeFrame - startFadeFrame
    local minOpacity = 0.5
    local maxOpacitySubtract = 1 - minOpacity
    opacity = 1 - math.min(maxOpacitySubtract * (currentFrame / maxFrame), maxOpacitySubtract)
  end
  return opacity
end

-- Enqueue a pop animation
function PlayerStack.enqueue_popfx(self, x, y, popsize)
  if self.canvas == nil or self.engine.play_to_end then
    return
  end

  local burstAtlas = nil
  local burstFrameDimension = nil
  local burstParticle = nil
  local bigParticle = nil
  local fadeAtlas = nil
  local fadeFrameDimension = nil
  local fadeParticle = nil
  if self.character.images["burst"] then
    burstAtlas = self.character.images["burst"]
    burstFrameDimension = burstAtlas:getWidth() / 9
    burstParticle = GraphicsUtil:newRecycledQuad(burstFrameDimension, 0, burstFrameDimension, burstFrameDimension, burstAtlas:getDimensions())
    bigParticle = GraphicsUtil:newRecycledQuad(0, 0, burstFrameDimension, burstFrameDimension, burstAtlas:getDimensions())
  end
  if self.character.images["fade"] then
    fadeAtlas = self.character.images["fade"]
    fadeFrameDimension = fadeAtlas:getWidth() / 9
    fadeParticle = GraphicsUtil:newRecycledQuad(fadeFrameDimension, 0, fadeFrameDimension, fadeFrameDimension, fadeAtlas:getDimensions())
  end
  self.pop_q:push(
    {
      frame = 1,
      burstAtlas = burstAtlas,
      burstFrameDimension = burstFrameDimension,
      burstParticle = burstParticle,
      fadeAtlas = fadeAtlas,
      fadeFrameDimension = fadeFrameDimension,
      fadeParticle = fadeParticle,
      bigParticle = bigParticle,
      popsize = popsize,
      x = x,
      y = y
    }
  )
end

-- Update all the pop animations
function PlayerStack.update_popfxs(self)
  if self.canvas == nil then
    return
  end

  for i = self.pop_q.first, self.pop_q.last do
    local popfx = self.pop_q[i]
    if self.character.popfx_style == "burst" or self.character.popfx_style == "fadeburst" then
      popfx_animation = POPFX_BURST_ANIMATION
    end
    if self.character.popfx_style == "fade" then
      popfx_animation = POPFX_FADE_ANIMATION
    end
    if POPFX_BURST_ANIMATION[popfx.frame] then
      popfx.frame = popfx.frame + 1
      if (POPFX_BURST_ANIMATION[popfx.frame] == nil) then
        if self.character.images["burst"] then
          GraphicsUtil:releaseQuad(popfx.burstParticle)
        end
        if self.character.images["fade"] then
          GraphicsUtil:releaseQuad(popfx.fadeParticle)
        end
        if self.character.images["burst"] then
          GraphicsUtil:releaseQuad(popfx.bigParticle)
        end
        self.pop_q:pop()
      end
    else
      popfx.frame = popfx.frame + 1
    end
  end
end

-- Draw the pop animations that happen when matches are made
function PlayerStack.drawPopEffects(self)
  local panelSize = 16
  for i = self.pop_q.first, self.pop_q.last do
    local popfx = self.pop_q[i]
    local drawX = (self.panelOriginX) + (popfx.x - 1) * panelSize
    local drawY = (self.panelOriginY) + (self.engine.height - 1 - popfx.y) * panelSize + self.engine.displacement

    GraphicsUtil.setColor(1, 1, 1, self:opacityForFrame(popfx.frame, 1, 8))

    if self.character.popfx_style == "burst" or self.character.popfx_style == "fadeburst" then
      if self.character.images["burst"] then
        if POPFX_BURST_ANIMATION[popfx.frame] then
          self:drawPopEffectsBurstGroup(popfx, drawX, drawY, panelSize)
        end
      end
    end

    if self.character.popfx_style == "fade" or self.character.popfx_style == "fadeburst" then
      if self.character.images["fade"] then
        local fadeFrame = POPFX_FADE_ANIMATION[popfx.frame]
        if (fadeFrame ~= nil) then
          local fadeSize = 32
          local fadeScale = self.character.popfx_fadeScale
          local fadeParticle_atlas = popfx.fadeAtlas
          local fadeParticle = popfx.fadeParticle
          local fadeFrameDimension = popfx.fadeFrameDimension
          fadeParticle:setViewport(fadeFrame * fadeFrameDimension, 0, fadeFrameDimension, fadeFrameDimension, fadeParticle_atlas:getDimensions())
          drawQuadGfxScaled(self, fadeParticle_atlas, fadeParticle, drawX + panelSize / 2, drawY + panelSize / 2, 0, (fadeSize / fadeFrameDimension) * fadeScale, (fadeSize / fadeFrameDimension) * fadeScale, fadeFrameDimension / 2, fadeFrameDimension / 2)
        end
      end
    end

    GraphicsUtil.setColor(1, 1, 1, 1)
  end
end

-- Draws the group of bursts effects that come out of the panel after it matches
function PlayerStack:drawPopEffectsBurstGroup(popfx, drawX, drawY, panelSize)
  self:drawPopEffectsBurstPiece("TopLeft", popfx, drawX, drawY, panelSize)
  self:drawPopEffectsBurstPiece("TopRight", popfx, drawX, drawY, panelSize)
  self:drawPopEffectsBurstPiece("BottomLeft", popfx, drawX, drawY, panelSize)
  self:drawPopEffectsBurstPiece("BottomRight", popfx, drawX, drawY, panelSize)

  if popfx.popsize == "big" or popfx.popsize == "giant" then
    self:drawPopEffectsBurstPiece("Top", popfx, drawX, drawY, panelSize)
    self:drawPopEffectsBurstPiece("Bottom", popfx, drawX, drawY, panelSize)
  end

  if popfx.popsize == "giant" then
    self:drawPopEffectsBurstPiece("Left", popfx, drawX, drawY, panelSize)
    self:drawPopEffectsBurstPiece("Right", popfx, drawX, drawY, panelSize)
  end
end

-- Draws a particular instance of the bursts effects that come out of the panel after it matches
function PlayerStack:drawPopEffectsBurstPiece(direction, popfx, drawX, drawY, panelSize)

  local burstDistance = POPFX_BURST_ANIMATION[popfx.frame][1]
  local shouldRotate = self.character.popfx_burstRotate
  local x = drawX
  local y = drawY
  local rotation = 0

  if direction == "TopLeft" then
    x = x - burstDistance
    y = y - burstDistance
    if shouldRotate then
      rotation = math.rad(0)
    end
  elseif direction == "TopRight" then
    x = x + panelSize + burstDistance
    y = y - burstDistance
    if shouldRotate then
      rotation = math.rad(90)
    end
  elseif direction == "BottomLeft" then
    x = x - burstDistance
    y = y + panelSize + burstDistance
    if shouldRotate then
      rotation = math.rad(-90)
    end
  elseif direction == "BottomRight" then
    x = x + panelSize + burstDistance
    y = y + panelSize + burstDistance
    if shouldRotate then
      rotation = math.rad(180)
    end
  elseif direction == "Top" then
    x = x + panelSize / 2
    y = y - (burstDistance * 2)
    if shouldRotate then
      rotation = math.rad(45)
    end
  elseif direction == "Bottom" then
    x = x + panelSize / 2
    y = y + panelSize + (burstDistance * 2)
    if shouldRotate then
      rotation = math.rad(-135)
    end
  elseif direction == "Left" then
    x = x - (burstDistance * 2)
    y = y + panelSize / 2
    if shouldRotate then
      rotation = math.rad(-45)
    end
  elseif direction == "Right" then
    x = x + panelSize + (burstDistance * 2)
    y = y + panelSize / 2
    if shouldRotate then
      rotation = math.rad(135)
    end
  else 
    assert(false, "Unhandled popfx direction")
  end

  local atlasDimension = popfx.burstFrameDimension
  local burstFrame = POPFX_BURST_ANIMATION[popfx.frame][2]
  self:drawPopBurstParticle(popfx.burstAtlas, popfx.burstParticle, burstFrame, atlasDimension, x, y, panelSize, rotation)
end

-- Draws the group of burst effects that rotate a combo or chain card
function PlayerStack:drawRotatingCardBurstEffectGroup(card, drawX, drawY)
  local burstFrameDimension = card.burstAtlas:getWidth() / 9

  local radius = -37.6 * math.log(card.frame) + 132.81
  local maxRadius = 8
  if radius < maxRadius then
    radius = maxRadius
  end

  local panelSize = 16
  for i = 0, 5, 1 do
    local degrees = (i * 60)
    local bonusDegrees = (card.frame * 5)
    local totalRadians = math.rad(degrees + bonusDegrees)
    local xOffset = math.cos(totalRadians) * radius
    local yOffset = math.sin(totalRadians) * radius
    local x = drawX + panelSize / 2 + xOffset
    local y = drawY + panelSize / 2 + yOffset
    local rotation = 0
    if self.character.popfx_burstRotate then
      rotation = totalRadians
    end
    
    self:drawPopBurstParticle(card.burstAtlas, card.burstParticle, 0, burstFrameDimension, x, y, panelSize, rotation)
  end
end

-- Draws a burst partical with the given parameters
function PlayerStack:drawPopBurstParticle(atlas, quad, frameIndex, atlasDimension, drawX, drawY, panelSize, rotation)
  
  local burstScale = self.character.popfx_burstScale
  local burstFrameScale = (panelSize / atlasDimension) * burstScale
  local burstOrigin = (atlasDimension * burstScale) / 2

  quad:setViewport(frameIndex * atlasDimension, 0, atlasDimension, atlasDimension, atlas:getDimensions())

  drawQuadGfxScaled(self, atlas, quad, drawX, drawY, rotation, burstFrameScale, burstFrameScale, burstOrigin, burstOrigin)
end

function PlayerStack:drawDebug()
  if config.debug_mode then
    local engine = self.engine

    local x = self.origin_x + 480
    local y = self.frameOriginY + 160

    if self.danger then
      GraphicsUtil.print("danger", x, y + 135)
    end
    if self.danger_music then
      GraphicsUtil.print("danger music", x, y + 150)
    end

    GraphicsUtil.print(loc("pl_cleared", (engine.panels_cleared or 0)), x, y + 165)
    GraphicsUtil.print(loc("pl_metal", (engine.metal_panels_queued or 0)), x, y + 180)

    local input = engine.confirmedInput[engine.clock]

    if input or self.taunt_up or self.taunt_down then
      local iraise, iswap, iup, idown, ileft, iright
      if engine.inputMethod == "touch" then
        iraise, _, _ = TouchDataEncoding.latinStringToTouchData(input, engine.width)
      else
        iraise, iswap, iup, idown, ileft, iright = unpack(base64decode[input])
      end
      local inputs_to_print = "inputs:"
      if iraise then
        inputs_to_print = inputs_to_print .. "\nraise"
      end --◄▲▼►
      if iswap then
        inputs_to_print = inputs_to_print .. "\nswap"
      end
      if iup then
        inputs_to_print = inputs_to_print .. "\nup"
      end
      if idown then
        inputs_to_print = inputs_to_print .. "\ndown"
      end
      if ileft then
        inputs_to_print = inputs_to_print .. "\nleft"
      end
      if iright then
        inputs_to_print = inputs_to_print .. "\nright"
      end
      if self.taunt_down then
        inputs_to_print = inputs_to_print .. "\ntaunt_down"
      end
      if self.taunt_up then
        inputs_to_print = inputs_to_print .. "\ntaunt_up"
      end
      if engine.inputMethod == "touch" then
        inputs_to_print = inputs_to_print .. self.touchInputController:debugString()
      end
      GraphicsUtil.print(inputs_to_print, x, y + 195)
    end

    local drawX = self.frameOriginX + self:canvasWidth() / 2
    local drawY = 10
    local padding = 14

    GraphicsUtil.drawRectangle("fill", drawX - 5, drawY - 5, 1000, 100, 0, 0, 0, 0.5)
    GraphicsUtil.printf("Clock " .. engine.clock, drawX, drawY)

    drawY = drawY + padding
    GraphicsUtil.printf("Confirmed " .. #engine.confirmedInput, drawX, drawY)

    drawY = drawY + padding
    GraphicsUtil.printf("input_buffer " .. #engine.input_buffer, drawX, drawY)

    drawY = drawY + padding
    GraphicsUtil.printf("rollbackCount " .. engine.rollbackCount, drawX, drawY)

    drawY = drawY + padding
    GraphicsUtil.printf("game_over_clock " .. (engine.game_over_clock or 0), drawX, drawY)

    drawY = drawY + padding
      GraphicsUtil.printf("has chain panels " .. tostring(engine:hasChainingPanels()), drawX, drawY)

    drawY = drawY + padding
      GraphicsUtil.printf("has active panels " .. tostring(engine:hasActivePanels()), drawX, drawY)

    drawY = drawY + padding
    GraphicsUtil.printf("riselock " .. tostring(engine.rise_lock), drawX, drawY)

    -- drawY = drawY + padding
    -- GraphicsUtil.printf("P" .. stack.which .." Panels: " .. stack.panel_buffer, drawX, drawY)

    drawY = drawY + padding
    GraphicsUtil.printf("P" .. engine.which .." Ended?: " .. tostring(engine:game_ended()), drawX, drawY)

    -- drawY = drawY + padding
    -- GraphicsUtil.printf("P" .. stack.which .." attacks: " .. #stack.telegraph.attacks, drawX, drawY)

    -- drawY = drawY + padding
    -- GraphicsUtil.printf("P" .. stack.which .." Garbage Q: " .. stack.incomingGarbage:len(), drawX, drawY)
  end
end

function PlayerStack:drawDebugPanels(shakeOffset)
  if not config.debug_mode then
    return
  end

  local engine = self.engine
  local mouseX, mouseY = GAME:transform_coordinates(love.mouse.getPosition())

  for row = 0, math.min(engine.height + 1, #engine.panels) do
    for col = 1, engine.width do
      local panel = engine.panels[row][col]
      local draw_x = (self.panelOriginX + (col - 1) * 16) * self.gfxScale
      local draw_y = (self.panelOriginY + (11 - (row)) * 16 + engine.displacement - shakeOffset) * self.gfxScale

      -- Require hovering over a stack to show details
      if mouseX >= self.panelOriginX * self.gfxScale and mouseX <= (self.panelOriginX + engine.width * 16) * self.gfxScale then
        if not (panel.color == 0 and panel.state == "normal") then
          GraphicsUtil.print(panel.state, draw_x, draw_y)
          if panel.matchAnyway then
            GraphicsUtil.print(tostring(panel.matchAnyway), draw_x, draw_y + 10)
            if panel.debug_tag then
              GraphicsUtil.print(tostring(panel.debug_tag), draw_x, draw_y + 20)
            end
          end
          if panel.chaining then
            GraphicsUtil.print("chaining", draw_x, draw_y + 30)
          end
        end
      end

      if mouseX >= draw_x and mouseX < draw_x + 16 * self.gfxScale and mouseY >= draw_y and mouseY < draw_y + 16 * self.gfxScale then
        local str = loc("pl_panel_info", row, col)
        for k, v in pairsSortedByKeys(panel) do
          str = str .. "\n" .. k .. ": " .. tostring(v)
        end

        local drawX = 30
        local drawY = 10

        GraphicsUtil.drawRectangle("fill", drawX - 5, drawY - 5, 100, 100, 0, 0, 0, 0.5)
        GraphicsUtil.printf(str, drawX, drawY)
      end
    end
  end
end

-- Renders the player's stack on screen
function PlayerStack.render(self)
  prof.push("Stack:render")
  if self.canvas == nil then
    return
  end

  self:setDrawArea()
  self:drawCharacter()
  local garbageImages
  local shockGarbageImages
  -- functionally, the garbage target being the source of the images for garbage landing on this stack is possible but not a given
  -- there is technically no guarantee that the target we're sending towards is also sending to us
  -- at the moment however this is the case so let's take it for granted until then
  if not self.garbageTarget then
    garbageImages = self.character.images
    shockGarbageImages = panels[self.panels_dir].images.metals
  else
    garbageImages = characters[self.garbageTarget.character].images
    shockGarbageImages = panels[self.garbageTarget.panels_dir].images.metals
  end

  local shakeOffset = self:currentShakeOffset() / self.gfxScale

  self:drawPanels(garbageImages, shockGarbageImages, shakeOffset)
  self:drawFrame()
  self:drawWall(shakeOffset, self.engine.height)
  -- Draw the cursor
  if self:game_ended() == false then
    self:render_cursor(shakeOffset)
  end
  self:drawCountdown()
  self:resetDrawArea()

  self:drawPopEffects()
  self:drawCards()

  self:drawDebugPanels(shakeOffset)
  self:drawDebug()
  prof.pop("Stack:render")
end

function PlayerStack:drawRating()
  local rating
  if self.player.rating and tonumber(self.player.rating) then
    rating = self.player.rating
  elseif config.debug_mode then
    rating = 1544 + self.player.playerNumber
  end

  if rating then
    self:drawLabel(self.theme.images["IMG_rating_" .. self.which .. "P"], self.theme.ratingLabel_Pos, self.theme.ratingLabel_Scale, true)
    self:drawNumber(rating, self.theme.rating_Pos, self.theme.rating_Scale, true)
  end
end

-- Draw the stacks cursor
function PlayerStack:render_cursor(shake)
  local engine = self.engine
  if engine.inputMethod == "touch" then
    if engine.cur_row == 0 and engine.cur_col == 0 then
      --no panel is touched, let's not draw the cursor
      return
    end
  end

  if engine.countdown_timer then
    if engine.clock % 2 ~= 0 then
      -- for some reason we want the cursor to blink during countdown
      return
    end
  end

  local cursor = self.theme.images.cursor[(floor(self.engine.clock / 16) % 2) + 1]
  local desiredCursorWidth = 40
  local panelWidth = 16
  local scale_x = desiredCursorWidth / cursor.image:getWidth()
  local scale_y = 24 / cursor.image:getHeight()
  local xPosition = (engine.cur_col - 1) * panelWidth

  if self.inputMethod == "touch" then
    drawQuadGfxScaled(self, cursor.image, cursor.touchQuads[1], xPosition, (11 - (engine.cur_row)) * panelWidth + engine.displacement - shake, 0, scale_x, scale_y)
    drawQuadGfxScaled(self, cursor.image, cursor.touchQuads[2], xPosition + 12, (11 - (engine.cur_row)) * panelWidth + engine.displacement - shake, 0, scale_x, scale_y)
  else
    drawGfxScaled(self, cursor.image, xPosition, (11 - (engine.cur_row)) * panelWidth + engine.displacement - shake, 0, scale_x, scale_y)
  end
end

-- Draw the stop time and healthbars
function PlayerStack:drawMultibar()
  local engine = self.engine
  local stop_time = engine.stop_time
  local shake_time = engine.shake_time

  -- before the first move, display the stop time from the puzzle, not the stack
  if engine.puzzle and engine.puzzle.puzzleType == "clear" and engine.puzzle.moves == engine.puzzle.remaining_moves then
    stop_time = engine.puzzle.stop_time
    shake_time = engine.puzzle.shake_time
  end

  if self.theme.multibar_is_absolute then
    -- absolute multibar is *only* supported for v3 themes
    self:drawAbsoluteMultibar(stop_time, shake_time, engine.pre_stop_time)
  else
    self:drawRelativeMultibar(stop_time, shake_time)
  end
end

function PlayerStack:drawRelativeMultibar(stop_time, shake_time)
  local engine = self.engine
  self:drawLabel(self.theme.images.healthbarFrames.relative[self.which], self.theme.healthbar_frame_Pos, self.theme.healthbar_frame_Scale)

  -- Healthbar
  local healthbar = engine.health * (self.theme.images.IMG_healthbar:getHeight() / engine.levelData.maxHealth)
  self.healthQuad:setViewport(0, self.theme.images.IMG_healthbar:getHeight() - healthbar, self.theme.images.IMG_healthbar:getWidth(), healthbar)
  local x = self:elementOriginXWithOffset(self.theme.healthbar_Pos, false) / self.gfxScale
  local y = self:elementOriginYWithOffset(self.theme.healthbar_Pos, false) + (self.theme.images.IMG_healthbar:getHeight() - healthbar) / self.gfxScale
  drawQuadGfxScaled(self, self.theme.images.IMG_healthbar, self.healthQuad, x, y, self.theme.healthbar_Rotate, self.theme.healthbar_Scale, self.theme.healthbar_Scale, 0, 0, self.multiplication)

  -- Prestop bar
  if engine.pre_stop_time == 0 or self.maxPrestop == nil then
    self.maxPrestop = 0
  end
  if engine.pre_stop_time > self.maxPrestop then
    self.maxPrestop = engine.pre_stop_time
  end

  -- Stop bar
  if stop_time == 0 or self.maxStop == nil then
    self.maxStop = 0
  end
  if stop_time > self.maxStop then
    self.maxStop = stop_time
  end

  -- Shake bar

  local multi_shake_bar, multi_stop_bar, multi_prestop_bar = 0, 0, 0
  if engine.peak_shake_time > 0 and shake_time >= engine.pre_stop_time + stop_time then
    multi_shake_bar = shake_time * (self.theme.images.IMG_multibar_shake_bar:getHeight() / engine.peak_shake_time) * 3
  end
  if self.maxStop > 0 and shake_time < engine.pre_stop_time + stop_time then
    multi_stop_bar = stop_time * (self.theme.images.IMG_multibar_stop_bar:getHeight() / self.maxStop) * 1.5
  end
  if self.maxPrestop > 0 and shake_time < engine.pre_stop_time + stop_time then
    multi_prestop_bar = engine.pre_stop_time * (self.theme.images.IMG_multibar_prestop_bar:getHeight() / self.maxPrestop) * 1.5
  end
  self.multi_shakeQuad:setViewport(0, self.theme.images.IMG_multibar_shake_bar:getHeight() - multi_shake_bar, self.theme.images.IMG_multibar_shake_bar:getWidth(), multi_shake_bar)
  self.multi_stopQuad:setViewport(0, self.theme.images.IMG_multibar_stop_bar:getHeight() - multi_stop_bar, self.theme.images.IMG_multibar_stop_bar:getWidth(), multi_stop_bar)
  self.multi_prestopQuad:setViewport(0, self.theme.images.IMG_multibar_prestop_bar:getHeight() - multi_prestop_bar, self.theme.images.IMG_multibar_prestop_bar:getWidth(), multi_prestop_bar)

  --Shake
  x = self:elementOriginXWithOffset(self.theme.multibar_Pos, false)
  y = self:elementOriginYWithOffset(self.theme.multibar_Pos, false)
  if self.theme.images.IMG_multibar_shake_bar then
    GraphicsUtil.drawQuad(self.theme.images.IMG_multibar_shake_bar, self.multi_shakeQuad, x, y + self.theme.images.IMG_multibar_shake_bar:getHeight() - multi_shake_bar, 0, self.theme.multibar_Scale, self.theme.multibar_Scale, 0, 0, self.multiplication)
  end
  --Stop
  if self.theme.images.IMG_multibar_stop_bar then
    GraphicsUtil.drawQuad(self.theme.images.IMG_multibar_stop_bar, self.multi_stopQuad, x, y - multi_shake_bar + self.theme.images.IMG_multibar_stop_bar:getHeight() - multi_stop_bar, 0, self.theme.multibar_Scale, self.theme.multibar_Scale, 0, 0, self.multiplication)
  end
  -- Prestop
  if self.theme.images.IMG_multibar_prestop_bar then
    GraphicsUtil.drawQuad(self.theme.images.IMG_multibar_prestop_bar, self.multi_prestopQuad, x, y - multi_shake_bar + multi_stop_bar + self.theme.images.IMG_multibar_prestop_bar:getHeight() - multi_prestop_bar, 0, self.theme.multibar_Scale, self.theme.multibar_Scale, 0, 0, self.multiplication)
  end
end

function PlayerStack:drawScore()
  self:drawLabel(self.theme.images["IMG_score_" .. self.which .. "P"], self.theme.scoreLabel_Pos, self.theme.scoreLabel_Scale)
  self:drawNumber(self.engine.score, self.theme.score_Pos, self.theme.score_Scale)
end

function PlayerStack:drawSpeed()
  self:drawLabel(self.theme.images["IMG_speed_" .. self.which .. "P"], self.theme.speedLabel_Pos, self.theme.speedLabel_Scale)
  self:drawNumber(self.engine.speed, self.theme.speed_Pos, self.theme.speed_Scale)
end

function PlayerStack:drawLevel()
  if self.level then
    self:drawLabel(self.theme.images["IMG_level_" .. self.which .. "P"], self.theme.levelLabel_Pos, self.theme.levelLabel_Scale)

    local x = self:elementOriginXWithOffset(self.theme.level_Pos, false)
    local y = self:elementOriginYWithOffset(self.theme.level_Pos, false)
    local levelAtlas = self.theme.images.levelNumberAtlas[self.which]
    GraphicsUtil.drawQuad(levelAtlas.image, levelAtlas.quads[self.level], x, y, 0, 28 / levelAtlas.charWidth * self.theme.level_Scale, 26 / levelAtlas.charHeight * self.theme.level_Scale, 0, 0, self.multiplication)
  end
end

function PlayerStack:drawAnalyticData()
  if not config.enable_analytics or not self.drawsAnalytics then
    return
  end

  local analytic = self.analytic
  local backgroundPadding = 18
  local paddingToAnalytics = 16
  local width = 160
  local height = 600
  local x = paddingToAnalytics + backgroundPadding
  if self.which == 2 then
    x = consts.CANVAS_WIDTH - paddingToAnalytics - width + backgroundPadding
  end
  local y = self.frameOriginY * self.gfxScale + backgroundPadding

  local iconToTextSpacing = 30
  local nextIconIncrement = 30
  local column2Distance = 70

  local fontIncrement = 8
  local iconSize = 24
  local icon_width
  local icon_height

  local font = GraphicsUtil.getGlobalFontWithSize(GraphicsUtil.fontSize + fontIncrement)
  GraphicsUtil.setFont(font)
  -- Background
  GraphicsUtil.drawRectangle("fill", x - backgroundPadding , y - backgroundPadding, width, height, 0, 0, 0, 0.5)

  -- Panels cleared
  panels[self.panels_dir]:drawPanelFrame(1, "face", x, y, iconSize)
  GraphicsUtil.printf(analytic.data.destroyed_panels, x + iconToTextSpacing, y - 2, consts.CANVAS_WIDTH, "left", nil, 1)

  y = y + nextIconIncrement



  -- Garbage sent
  icon_width, icon_height = self.character.images.face:getDimensions()
  GraphicsUtil.draw(self.character.images.face, x, y, 0, iconSize / icon_width, iconSize / icon_height)
  GraphicsUtil.printf(analytic.data.sent_garbage_lines, x + iconToTextSpacing, y - 2, consts.CANVAS_WIDTH, "left", nil, 1)

  y = y + nextIconIncrement

  -- GPM
  if analytic.lastGPM == 0 or math.fmod(self.engine.clock, 60) < self.engine.max_runs_per_frame then
    if self.engine.clock > 0 and (analytic.data.sent_garbage_lines > 0) then
      analytic.lastGPM = analytic:getRoundedGPM(self.engine.clock)
    end
  end
  icon_width, icon_height = self.theme.images.IMG_gpm:getDimensions()
  GraphicsUtil.draw(self.theme.images.IMG_gpm, x, y, 0, iconSize / icon_width, iconSize / icon_height)
  GraphicsUtil.printf(analytic.lastGPM .. "/m", x + iconToTextSpacing, y - 2, consts.CANVAS_WIDTH, "left", nil, 1)

  y = y + nextIconIncrement

  -- Moves
  icon_width, icon_height = self.theme.images.IMG_cursorCount:getDimensions()
  GraphicsUtil.draw(self.theme.images.IMG_cursorCount, x, y, 0, iconSize / icon_width, iconSize / icon_height)
  GraphicsUtil.printf(analytic.data.move_count, x + iconToTextSpacing, y - 2, consts.CANVAS_WIDTH, "left", nil, 1)

  y = y + nextIconIncrement

  -- Swaps
  if self.theme.images.IMG_swap then
    icon_width, icon_height = self.theme.images.IMG_swap:getDimensions()
    GraphicsUtil.draw(self.theme.images.IMG_swap, x, y, 0, iconSize / icon_width, iconSize / icon_height)
  end
  GraphicsUtil.printf(analytic.data.swap_count, x + iconToTextSpacing, y - 2, consts.CANVAS_WIDTH, "left", nil, 1)

  y = y + nextIconIncrement

  -- APM
  if analytic.lastAPM == 0 or math.fmod(self.engine.clock, 60) < self.engine.max_runs_per_frame then
    if self.engine.clock > 0 and (analytic.data.swap_count + analytic.data.move_count > 0) then
      local actionsPerMinute = (analytic.data.swap_count + analytic.data.move_count) / (self.engine.clock / 60 / 60)
      analytic.lastAPM = string.format("%0.0f", math.round(actionsPerMinute, 0))
    end
  end
  if self.theme.images.IMG_apm then
    icon_width, icon_height = self.theme.images.IMG_apm:getDimensions()
    GraphicsUtil.draw(self.theme.images.IMG_apm, x, y, 0, iconSize / icon_width, iconSize / icon_height)
  end
  GraphicsUtil.printf(analytic.lastAPM .. "/m", x + iconToTextSpacing, y - 2, consts.CANVAS_WIDTH, "left", nil, 1)

  y = y + nextIconIncrement



  -- preserve the offset for combos as chains and combos are drawn in columns side by side
  local yCombo = y

  -- Draw the chain images
  local chainCountAboveLimit = analytic:compute_above_chain_card_limit(self.theme.chainCardLimit)

  for i = 2, self.theme.chainCardLimit do
    if analytic.data.reached_chains[i] and analytic.data.reached_chains[i] > 0 then
      local cardImage = self.theme:chainImage(i)
      if cardImage then
        icon_width, icon_height = cardImage:getDimensions()
        GraphicsUtil.draw(cardImage, x, y, 0, iconSize / icon_width, iconSize / icon_height)
        GraphicsUtil.printf(analytic.data.reached_chains[i], x + iconToTextSpacing, y - 2, consts.CANVAS_WIDTH, "left", nil, 1)
        y = y + nextIconIncrement
      end
    end
  end

  if chainCountAboveLimit > 0 then
    local cardImage = self.theme:chainImage(0)
    GraphicsUtil.draw(cardImage, x, y, 0, iconSize / icon_width, iconSize / icon_height)
    GraphicsUtil.printf(chainCountAboveLimit, x + iconToTextSpacing, y - 2, consts.CANVAS_WIDTH, "left", nil, 1)
  end

  -- Draw the combo images
  local xCombo = x + column2Distance

  for i = 4, 72 do
    if analytic.data.used_combos[i] and analytic.data.used_combos[i] > 0 then
      local cardImage = self.theme:comboImage(i)
      if cardImage then
        icon_width, icon_height = cardImage:getDimensions()
        GraphicsUtil.draw(cardImage, xCombo, yCombo, 0, iconSize / icon_width, iconSize / icon_height)
        GraphicsUtil.printf(analytic.data.used_combos[i], xCombo + iconToTextSpacing, yCombo - 2, consts.CANVAS_WIDTH, "left", nil, 1)
        yCombo = yCombo + nextIconIncrement
      end
    end
  end

  GraphicsUtil.setFont(GraphicsUtil.getGlobalFont())
end

function PlayerStack:drawMoveCount()
  -- draw outside of stack's frame canvas
  if self.engine.puzzle then
    self:drawLabel(themes[config.theme].images.IMG_moves, themes[config.theme].moveLabel_Pos, themes[config.theme].moveLabel_Scale, false, true)
    local moveNumber = math.abs(self.engine.puzzle.remaining_moves)
    if self.engine.puzzle.puzzleType == "moves" then
      moveNumber = self.engine.puzzle.remaining_moves
    end
    self:drawNumber(moveNumber, themes[config.theme].move_Pos, themes[config.theme].move_Scale, true)
  end
end

local function shouldFlashForFrame(frame)
  local flashFrames = 1
  flashFrames = 2 -- add config
  return frame % (flashFrames * 2) < flashFrames
end

---@param bottomRightPanel Panel
---@param draw_x number
---@param draw_y number
---@param garbageImages table<string, love.Texture>
function PlayerStack:drawGarbageBlock(bottomRightPanel, draw_x, draw_y, garbageImages)
  local imgs = garbageImages
  local panel = bottomRightPanel
  local height, width = panel.height, panel.width
  local top_y = draw_y - (height - 1) * 16
  local use_1 = ((height - (height % 2)) / 2) % 2 == 0
  local filler_w, filler_h = imgs.filler1:getDimensions()
  for i = 0, height - 1 do
    for j = 0, width - 2 do
      local filler
      if (use_1 or height < 3) then
        filler = imgs.filler1
      else
        filler = imgs.filler2
      end
      drawGfxScaled(self, filler, draw_x - 16 * j - 8, top_y + 16 * i, 0, 16 / filler_w, 16 / filler_h)
      use_1 = not use_1
    end
  end
  if height % 2 == 1 then
    local face
    if imgs.face2 and width % 2 == 1 then
      face = imgs.face2
    else
      face = imgs.face
    end
    local face_w, face_h = face:getDimensions()
    drawGfxScaled(self, face, draw_x - 8 * (width - 1), top_y + 16 * ((height - 1) / 2), 0, 16 / face_w, 16 / face_h)
  else
    local face_w, face_h = imgs.doubleface:getDimensions()
    drawGfxScaled(self, imgs.doubleface, draw_x - 8 * (width - 1), top_y + 16 * ((height - 2) / 2), 0, 16 / face_w, 32 / face_h)
  end
  local corner_w, corner_h = imgs.topleft:getDimensions()
  local lr_w, lr_h = imgs.left:getDimensions()
  local topbottom_w, topbottom_h = imgs.top:getDimensions()
  drawGfxScaled(self, imgs.left, draw_x - 16 * (width - 1), top_y, 0, 8 / lr_w, (1 / lr_h) * height * 16)
  drawGfxScaled(self, imgs.right, draw_x + 8, top_y, 0, 8 / lr_w, (1 / lr_h) * height * 16)
  drawGfxScaled(self, imgs.top, draw_x - 16 * (width - 1), top_y, 0, (1 / topbottom_w) * width * 16, 2 / topbottom_h)
  drawGfxScaled(self, imgs.bot, draw_x - 16 * (width - 1), draw_y + 14, 0, (1 / topbottom_w) * width * 16, 2 / topbottom_h)
  drawGfxScaled(self, imgs.topleft, draw_x - 16 * (width - 1), top_y, 0, 8 / corner_w, 3 / corner_h)
  drawGfxScaled(self, imgs.topright, draw_x + 8, top_y, 0, 8 / corner_w, 3 / corner_h)
  drawGfxScaled(self, imgs.botleft, draw_x - 16 * (width - 1), draw_y + 13, 0, 8 / corner_w, 3 / corner_h)
  drawGfxScaled(self, imgs.botright, draw_x + 8, draw_y + 13, 0, 8 / corner_w, 3 / corner_h)
end

function PlayerStack:drawPanels(garbageImages, shockGarbageImages, shakeOffset)
  prof.push("Stack:drawPanels")
  local panelSet = panels[self.panels_dir]
  panelSet:prepareDraw()

  local metal_w, metal_h = shockGarbageImages.mid:getDimensions()
  local metall_w, metall_h = shockGarbageImages.left:getDimensions()
  local metalr_w, metalr_h = shockGarbageImages.right:getDimensions()

  -- Draw all the panels
  for row = 0, self.engine.height do
    for col = self.engine.width, 1, -1 do
      local panel = self.engine.panels[row][col]
      local draw_x = 4 + (col - 1) * 16
      local draw_y = 4 + (11 - (row)) * 16 + self.engine.displacement - shakeOffset
      if panel.color ~= 0 and panel.state ~= "popped" then
        if panel.isGarbage then

          -- this is the bottom right corner panel, meaning the first that will reappear when popping
          if panel.x_offset == (panel.width - 1) and panel.y_offset == 0 then
            -- we only need to draw the block if it is not matched 
            -- or if the bottom right panel already started popping
            if panel.state ~= "matched" or panel.timer <= panel.pop_time then
              if panel.metal then
                drawGfxScaled(self, shockGarbageImages.left, draw_x - (16 * (panel.width - 1)), draw_y, 0, 8 / metall_w, 16 / metall_h)
                drawGfxScaled(self, shockGarbageImages.right, draw_x + 8, draw_y, 0, 8 / metalr_w, 16 / metalr_h)
                for i = 0, 2 * (panel.width - 1) - 1 do
                  drawGfxScaled(self, shockGarbageImages.mid, draw_x - 8 * i, draw_y, 0, 8 / metal_w, 16 / metal_h)
                end
              else
                self:drawGarbageBlock(panel, draw_x, draw_y, garbageImages)
              end
            end
          end

          if panel.state == "matched" then
            local flash_time = panel.initial_time - panel.timer
            if flash_time >= self.engine.levelData.frameConstants.FLASH then
              if panel.timer > panel.pop_time then
                if panel.metal then
                  drawGfxScaled(self, shockGarbageImages.left, draw_x, draw_y, 0, 8 / metall_w, 16 / metall_h)
                  drawGfxScaled(self, shockGarbageImages.right, draw_x + 8, draw_y, 0, 8 / metalr_w, 16 / metalr_h)
                else
                  local popped_w, popped_h = garbageImages.pop:getDimensions()
                  drawGfxScaled(self, garbageImages.pop, draw_x, draw_y, 0, 16 / popped_w, 16 / popped_h)
                end
              elseif panel.y_offset == -1 then
                panelSet:addToDraw(panel, draw_x, draw_y, self.gfxScale)
              end
            else
              if shouldFlashForFrame(flash_time) == false then
                if panel.metal then
                  drawGfxScaled(self, shockGarbageImages.left, draw_x, draw_y, 0, 8 / metall_w, 16 / metall_h)
                  drawGfxScaled(self, shockGarbageImages.right, draw_x + 8, draw_y, 0, 8 / metalr_w, 16 / metalr_h)
                else
                  local popped_w, popped_h = garbageImages.pop:getDimensions()
                  drawGfxScaled(self, garbageImages.pop, draw_x, draw_y, 0, 16 / popped_w, 16 / popped_h)
                end
              else
                local flashImage
                if panel.metal then
                  flashImage = shockGarbageImages.flash
                else
                  flashImage = garbageImages.flash
                end
                local flashed_w, flashed_h = flashImage:getDimensions()
                drawGfxScaled(self, flashImage, draw_x, draw_y, 0, 16 / flashed_w, 16 / flashed_h)
              end
            end
          end
        else
          panelSet:addToDraw(panel, draw_x, draw_y, self.gfxScale, self.danger_col, self.danger_timer)
        end
      end
    end
  end

  panelSet:drawBatch()
  prof.pop("Stack:drawPanels")
end


----------------------------------------------------------------
--- Functions to be converted to PlayerStack use over engine ---
---   this will primarily consist of SFX related functions   ---
----------------------------------------------------------------

function PlayerStack:queueAttackSoundEffect(isChainLink, chainSize, comboSize, metalCount)
  if self:canPlaySfx() then
    self.combo_chain_play = self.attackSoundInfoForMatch(isChainLink, chainSize, comboSize, metalCount)
  end
end

function PlayerStack:playSfx()
  prof.push("stack sfx")
  -- Update Sound FX
  if self:canPlaySfx() then
    if self.sfxSwap then
      SoundController:playSfx(themes[config.theme].sounds.swap)
      self.sfxSwap = false
    end
    if self.sfxCursorMove then
      -- I have no idea why this makes a distinction for vs, like what?
      -- On scouring historical chats it seems like cursor move sounds did not play during swap sounds ONLY in vs in TA
      -- people suspected a lack in sound channels in TA; might just be sensible to overall keep the amount of SFX low
      if not (self.stackInteraction ~= GameModes.StackInteractions.NONE and themes[config.theme].sounds.swap:isPlaying()) and not self.engine.do_countdown then
        SoundController:playSfx(themes[config.theme].sounds.cur_move)
      end
      self.sfxCursorMove = false
    end
    if self.sfx_land then
      SoundController:playSfx(themes[config.theme].sounds.land)
      self.sfx_land = false
    end
    if self.combo_chain_play then
      -- stop ongoing landing sound
      SoundController:stopSfx(themes[config.theme].sounds.land)
      -- and cancel it because an attack is performed on the exact same frame (takes priority)
      self.sfx_land = false
      SoundController:stopSfx(themes[config.theme].sounds.pops[self.lastPopLevelPlayed][self.lastPopIndexPlayed])
      self.character:playAttackSfx(self.combo_chain_play)
      self.combo_chain_play = nil
    end
    if self.sfxGarbageMatch then
      self.character:playGarbageMatchSfx()
      self.sfxGarbageMatch = false
    end
    if self.sfxFanfare == 0 then
      --do nothing
    elseif self.sfxFanfare >= 6 then
      SoundController:playSfx(themes[config.theme].sounds.fanfare3)
    elseif self.sfxFanfare >= 5 then
      SoundController:playSfx(themes[config.theme].sounds.fanfare2)
    elseif self.sfxFanfare >= 4 then
      SoundController:playSfx(themes[config.theme].sounds.fanfare1)
    end
    self.sfxFanfare = 0
    if self.sfx_garbage_thud >= 1 and self.sfx_garbage_thud <= 3 then
      local interrupted_thud = nil
      for i = 1, 3 do
        if themes[config.theme].sounds.garbage_thud[i]:isPlaying() and self.engine.shake_time > self.engine.prev_shake_time then
          SoundController:stopSfx(themes[config.theme].sounds.garbage_thud[i])
          interrupted_thud = i
        end
      end
      if interrupted_thud and interrupted_thud > self.sfx_garbage_thud then
        SoundController:playSfx(themes[config.theme].sounds.garbage_thud[interrupted_thud])
      else
        SoundController:playSfx(themes[config.theme].sounds.garbage_thud[self.sfx_garbage_thud])
      end
      if interrupted_thud == nil then
        self.character:playGarbageLandSfx()
      end
      self.sfx_garbage_thud = 0
    end
    if self.sfxPop or self.sfxGarbagePop > 0 then
      local popLevel = min(max(self.engine.chain_counter, 1), 4)
      local popIndex = 1
      if self.sfxGarbagePop > 0 then
        popIndex = min(self.sfxGarbagePop + self.poppedPanelIndex, 10)
      else
        popIndex = min(self.poppedPanelIndex, 10)
      end
      --stop the previous pop sound
      SoundController:stopSfx(themes[config.theme].sounds.pops[self.lastPopLevelPlayed][self.lastPopIndexPlayed])
      --play the appropriate pop sound
      SoundController:playSfx(themes[config.theme].sounds.pops[popLevel][popIndex])
      self.lastPopLevelPlayed = popLevel
      self.lastPopIndexPlayed = popIndex
      self.sfxPop = false
      self.sfxGarbagePop = 0
    end
  end
  prof.pop("stack sfx")
end

local MAX_TAUNT_PER_10_SEC = 4

function PlayerStack:can_taunt()
  return self.taunt_queue:len() < MAX_TAUNT_PER_10_SEC or self.taunt_queue:peek() + 10 < love.timer.getTime()
end

function PlayerStack:taunt(taunt_type)
  while self.taunt_queue:len() >= MAX_TAUNT_PER_10_SEC do
    self.taunt_queue:pop()
  end
  self.taunt_queue:push(love.timer.getTime())
end

function PlayerStack:processTaunts()
  prof.push("taunt")
  -- TAUNTING
  if self:canPlaySfx() then
    if self.taunt_up ~= nil then
      self.character:playTauntUpSfx(self.taunt_up)
      self:taunt("taunt_up")
      self.taunt_up = nil
    elseif self.taunt_down ~= nil then
      self.character:playTauntDownSfx(self.taunt_down)
      self:taunt("taunt_down")
      self.taunt_down = nil
    end
  end
  prof.pop("taunt")
end

function PlayerStack:canPlaySfx()
  -- this should be superfluous because there is no code being run that would send signals causing SFX
  -- if self:game_ended() then
  --   return false
  -- end

  -- If we are still catching up from rollback don't play sounds again
  if self.engine:behindRollback() then
    return false
  end

  -- this is catchup mode, don't play sfx during this
  if self.engine.play_to_end then
    return false
  end

  return true
end


-- Target must be able to take calls of
-- receiveGarbage(frameToReceive, garbageList)
-- and provide
-- frameOriginX
-- frameOriginY
-- mirror_x
-- canvasWidth
function PlayerStack.setGarbageTarget(self, newGarbageTarget)
  if newGarbageTarget ~= nil then
    -- the abstract notion of a garbage target
    -- in reality the target will be a stack of course but this is the interface so to speak
    assert(newGarbageTarget.frameOriginX ~= nil)
    assert(newGarbageTarget.frameOriginY ~= nil)
    assert(newGarbageTarget.mirror_x ~= nil)
    assert(newGarbageTarget.canvasWidth ~= nil)
    assert(newGarbageTarget.receiveGarbage ~= nil)
  end
  self.garbageTarget = newGarbageTarget
end

-- calculates at how many frames the stack's multibar tops out
function PlayerStack:calculateMultibarFrameCount()
  -- the multibar needs a realistic height that can encompass the sum of health and a realistic maximum stop time
  local maxStop = 0

  -- for a realistic max stop, let's only compare obtainable stop while topped out - while not topped out, stop doesn't matter after all
  -- x5 chain while topped out (bonus stop from extra chain links is capped at x5)
  maxStop = math.max(maxStop, self.engine:calculateStopTime(3, true, true, 5))

  -- while topped out, stop from combos is capped at 10 combo
  maxStop = math.max(maxStop, self.engine:calculateStopTime(10, true, false))

  -- if we wanted to include stop in non-topped out states:
  -- combo stop is linear with combosize but +27 is a reasonable cutoff (garbage cap for combos)
  -- maxStop = math.max(maxStop, self:calculateStopTime(27, false, false))
  -- ...but this would produce insanely high values on low levels

  -- bonus stop from extra chain links caps out at x13
  -- maxStop = math.max(maxStop, self:calculateStopTime(3, false, true, 13))
  -- this too produces insanely high values on low levels

  -- prestop does not need to be represented fully as there is visual representation via popping panels
  -- we want a fair but not overly large buffer relative to human time perception to represent prestop in maxstop scenarios
  -- this is a first idea going from 2s prestop on 10 to nearly 4s prestop on 1
  --local preStopFrameCount = 30 + (10 - self.level) * 5

  local minFrameCount = maxStop + self.engine.levelData.maxHealth --+ preStopFrameCount

  --return minFrameCount + preStopFrameCount
  return math.max(240, minFrameCount)
end

function PlayerStack:updateDangerMusic()
  local dangerMusic = self:shouldPlayDangerMusic()
  if dangerMusic ~= self.danger_music then
    self.danger_music = dangerMusic
    self:emitSignal("dangerMusicChanged", self)
  end
end

-- determine whether to play danger music
-- Changed this to play danger when something in top 3 rows
-- and to play normal music when nothing in top 3 or 4 rows
function PlayerStack:shouldPlayDangerMusic()
  if not self.danger_music then
    -- currently playing normal music
    for row = self.engine.height - 2, self.engine.height do
      local panelRow = self.engine.panels[row]
      for column = 1, self.engine.width do
        if panelRow[column].color ~= 0 and panelRow[column].state ~= "falling" or panelRow[column]:dangerous() then
          if self.engine.shake_time > 0 then
            return false
          else
            return true
          end
        end
      end
    end
  else
    --currently playing danger
    local minRowForDangerMusic = self.engine.height - 2
    if config.danger_music_changeback_delay then
      minRowForDangerMusic = self.engine.height - 3
    end
    for row = minRowForDangerMusic, self.engine.height do
      local panelRow = self.engine.panels[row]
      for column = 1, self.engine.width do
        if panelRow[column].color ~= 0 then
          return true
        end
      end
    end
  end

  return false
end

function PlayerStack:getAttackPatternData()
  local data, state = self.engine:getAttackPatternData()
  if data then
    data.disableQueueLimit = self.player.human
    data.extraInfo.playerName = self.player.name
    data.extraInfo.gpm = self.analytic:getRoundedGPM(self.engine.clock) or 0
  end

  return data, state
end

function PlayerStack.updateDangerBounce(self)
  -- calculate which columns should bounce
    self.danger = false
    local panelRow = self.engine.panels[self.engine.height - 1]
    for idx = 1, self.engine.width do
      if panelRow[idx]:dangerous() then
        self.danger = true
        self.danger_col[idx] = true
      else
        self.danger_col[idx] = false
      end
    end
    if self.danger then
      if self.engine.panels_in_top_row and self.engine.speed ~= 0 and not self.engine.puzzle then
        -- Player has topped out, panels hold the "flattened" frame
        self.danger_timer = 0
      elseif self.engine.stop_time == 0 then
        self.danger_timer = self.danger_timer + 1
      end
    else
      self.danger_timer = 0
    end
  end

return PlayerStack