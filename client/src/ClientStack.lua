local class = require("common.lib.class")
local consts = require("common.engine.consts")
local Signal = require("common.lib.signal")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local ModController = require("client.src.mods.ModController")

-- gfxScale at which theme label sizes are calibrated; also the default scale for a full-size stack
local NORMAL_GFX_SCALE = 3

-- Draws an image at the given spot while scaling all coordinate and scale values with stack.gfxScale
local function drawGfxScaled(stack, img, x, y, rot, xScale, yScale)
  xScale = xScale or 1
  yScale = yScale or 1
  GraphicsUtil.draw(img, x * stack.gfxScale, y * stack.gfxScale, rot, xScale * stack.gfxScale, yScale * stack.gfxScale)
end

---The base class for a client side wrapper around an engine stack
---Supports general properties for positioning and drawing
---@class ClientStack : Signal
---@field is_local boolean if the Stack gets its inputs live from the local client or not
---@field character Character the character to use for drawing and sounds
---@field theme table the theme to determine offsets via theme for multibar and other properties
---@field panels_dir string id of the panel set to use for metal garbage assets and panels
---@field baseWidth integer
---@field baseHeight integer
---@field gfxScale number scale factor for the entire Stack, default: 3
---@field panelOriginXOffset integer how far the panel origin is offset relative to frame at scale 1
---@field panelOriginYOffset integer how far the panel origin is offset relative to frame at scale 1
---@field canvas boolean if the stack is supposed to be drawn
---@field portraitFade number inverse opacity of the character portrait
---@field engine BaseStack the engine actually running the physics
---@field multiBarFrameCount integer at how many frames the BaseStack's multibar tops out
---@field player MatchParticipant
---@field healthQuad love.Quad
---@field multi_prestopQuad love.Quad
---@field multi_stopQuad love.Quad
---@field multi_shakeQuad love.Quad
---@field danger_music boolean
---@field garbageSource ClientStack The stack the garbage assets are used from
---@field assets IngameAssetPack
---@field renderIndex integer determines the position of the stack and how some elements are rendered
---@field player_number integer used for display ordering

---@class ClientStack
local ClientStack = class(
---@param self ClientStack
---@param args table
function(self, args)
  self = self

  assert(args.engine)
  assert(args.characterId)

  self.engine = args.engine
  -- player number according to the multiplayer server, for game outcome reporting 
  self.player_number = args.player_number or args.engine.which
  self.is_local = args.player and args.player.isLocal or args.engine.is_local
  self.character = characters[args.characterId]
  ModController:loadModFor(self.character, self)
  self.theme = args.theme or themes[config.theme]

  self.panels_dir = args.panels_dir
  if not self.panels_dir or not panels[self.panels_dir] then
    self.panels_dir = config.panels
  end

  -- graphics
  -- also relevant for the touch input controller method besides general drawing
  self.baseWidth = 104
  self.baseHeight = 204
  self.panelOriginXOffset = 4
  self.panelOriginYOffset = 4
  self.gfxScale = NORMAL_GFX_SCALE
  -- stacks no longer have a canvas but some functions bool check it to determine whether they should run or not
  -- mostly for tests / not running extra in some scenarios; should be removed once they have been adjusted
  self.canvas = true
  self.portraitFade = 0

  self.danger_music = false

  Signal.turnIntoEmitter(self)
  self:createSignal("dangerMusicChanged")
end)

ClientStack.NORMAL_GFX_SCALE = NORMAL_GFX_SCALE

-- Provides the X origin to draw an element of the stack
-- cameFromLegacyScoreOffset - set to true if this used to use the "score" position in legacy themes
function ClientStack:elementOriginX(cameFromLegacyScoreOffset, legacyOffsetIsAlreadyScaled)
  assert(cameFromLegacyScoreOffset ~= nil)
  assert(legacyOffsetIsAlreadyScaled ~= nil)
  local x = 546
  if self.renderIndex == 2 or self.renderIndex == 4 then
    x = 642
  end
  if cameFromLegacyScoreOffset == false or themes[config.theme]:offsetsAreFixed() then
    x = self.origin_x
    if legacyOffsetIsAlreadyScaled == false or themes[config.theme]:offsetsAreFixed() then
      x = x * self.gfxScale
    end
  end
  return x
end

-- Provides the Y origin to draw an element of the stack
-- cameFromLegacyScoreOffset - set to true if this used to use the "score" position in legacy themes
function ClientStack:elementOriginY(cameFromLegacyScoreOffset, legacyOffsetIsAlreadyScaled)
  assert(cameFromLegacyScoreOffset ~= nil)
  assert(legacyOffsetIsAlreadyScaled ~= nil)
  local y = 208
  if cameFromLegacyScoreOffset == false or themes[config.theme]:offsetsAreFixed() then
    y = self.panelOriginY
    if legacyOffsetIsAlreadyScaled == false or themes[config.theme]:offsetsAreFixed() then
      y = y * self.gfxScale
    end
  end
  return y
end

-- Provides the X position to draw an element of the stack, shifted by the given offset and mirroring
-- themePositionOffset - the theme offset array
-- cameFromLegacyScoreOffset - set to true if this used to use the "score" position in legacy themes
-- legacyOffsetIsAlreadyScaled - set to true if the offset used to be already scaled in legacy themes
function ClientStack:elementOriginXWithOffset(themePositionOffset, cameFromLegacyScoreOffset, legacyOffsetIsAlreadyScaled)
  if legacyOffsetIsAlreadyScaled == nil then
    legacyOffsetIsAlreadyScaled = false
  end
  local xOffset = themePositionOffset[1]
  if cameFromLegacyScoreOffset == false or themes[config.theme]:offsetsAreFixed() then
    xOffset = xOffset * self.mirror_x
  end
  if cameFromLegacyScoreOffset == false and themes[config.theme]:offsetsAreFixed() == false and legacyOffsetIsAlreadyScaled == false then
    xOffset = xOffset * self.gfxScale
  end
  local x = self:elementOriginX(cameFromLegacyScoreOffset, legacyOffsetIsAlreadyScaled) + xOffset
  return x
end

-- Provides the Y position to draw an element of the stack, shifted by the given offset and mirroring
-- themePositionOffset - the theme offset array
-- cameFromLegacyScoreOffset - set to true if this used to use the "score" position in legacy themes
function ClientStack:elementOriginYWithOffset(themePositionOffset, cameFromLegacyScoreOffset, legacyOffsetIsAlreadyScaled)
  if legacyOffsetIsAlreadyScaled == nil then
    legacyOffsetIsAlreadyScaled = false
  end
  local yOffset = themePositionOffset[2]
  if cameFromLegacyScoreOffset == false and themes[config.theme]:offsetsAreFixed() == false and legacyOffsetIsAlreadyScaled == false then
    yOffset = yOffset * self.gfxScale
  end
  local y = self:elementOriginY(cameFromLegacyScoreOffset, legacyOffsetIsAlreadyScaled) + yOffset
  return y
end

-- Provides the X position to draw a label of the stack, shifted by the given offset, mirroring and label width
-- themePositionOffset - the theme offset array
-- cameFromLegacyScoreOffset - set to true if this used to use the "score" position in legacy themes
-- width - width of the drawable
-- percentWidthShift - the percent of the width you want shifted left
function ClientStack:labelOriginXWithOffset(themePositionOffset, scale, cameFromLegacyScoreOffset, width, percentWidthShift, legacyOffsetIsAlreadyScaled)
  local x = self:elementOriginXWithOffset(themePositionOffset, cameFromLegacyScoreOffset, legacyOffsetIsAlreadyScaled)

  if percentWidthShift > 0 then
    x = x - math.floor((percentWidthShift * width * scale))
  end

  return x
end

function ClientStack:drawLabel(drawable, themePositionOffset, scale, cameFromLegacyScoreOffset, legacyOffsetIsAlreadyScaled)
  if cameFromLegacyScoreOffset == nil then
    cameFromLegacyScoreOffset = false
  end

  local effectiveScale = scale * (self.gfxScale / NORMAL_GFX_SCALE)

  local percentWidthShift = 0
  -- If we are mirroring from the right, move the full width left
  if cameFromLegacyScoreOffset == false or themes[config.theme]:offsetsAreFixed() then
    if self.multiplication > 0 then
      percentWidthShift = 1
    end
  end

  local x = self:labelOriginXWithOffset(themePositionOffset, effectiveScale, cameFromLegacyScoreOffset, drawable:getWidth(), percentWidthShift, legacyOffsetIsAlreadyScaled)
  local y = self:elementOriginYWithOffset(themePositionOffset, cameFromLegacyScoreOffset, legacyOffsetIsAlreadyScaled)

  GraphicsUtil.draw(drawable, x, y, 0, effectiveScale, effectiveScale)
end

function ClientStack:drawBar(image, quad, themePositionOffset, height, yOffset, rotate, scale)
  local imageWidth, imageHeight = image:getDimensions()
  local barYScale = height / imageHeight
  local quadY = 0
  if barYScale < 1 then
    barYScale = 1
    quadY = imageHeight - height
  end
  local x = self:elementOriginXWithOffset(themePositionOffset, false)
  local y = self:elementOriginYWithOffset(themePositionOffset, false)
  quad:setViewport(0, quadY, imageWidth, imageHeight - quadY)
  GraphicsUtil.drawQuad(image, quad, x, y - height - yOffset, rotate, scale, scale * barYScale, 0, 0, self.mirror_x)
end

function ClientStack:drawNumber(number, themePositionOffset, scale, cameFromLegacyScoreOffset)
  if cameFromLegacyScoreOffset == nil then
    cameFromLegacyScoreOffset = false
  end
  local effectiveScale = scale * (self.gfxScale / NORMAL_GFX_SCALE)
  local x = self:elementOriginXWithOffset(themePositionOffset, cameFromLegacyScoreOffset)
  local y = self:elementOriginYWithOffset(themePositionOffset, cameFromLegacyScoreOffset)
  GraphicsUtil.drawPixelFont(number, self.assets.numberPixelFont, x, y, effectiveScale, effectiveScale, "center", 0)
end

function ClientStack:drawString(string, themePositionOffset, cameFromLegacyScoreOffset, fontSize)
  if cameFromLegacyScoreOffset == nil then
    cameFromLegacyScoreOffset = false
  end
  local x = self:elementOriginXWithOffset(themePositionOffset, cameFromLegacyScoreOffset)
  local y = self:elementOriginYWithOffset(themePositionOffset, cameFromLegacyScoreOffset)

  local limit = consts.CANVAS_WIDTH - x
  local alignment = "left"
  if themes[config.theme]:offsetsAreFixed() then
    if self.renderIndex == 1 then
      limit = x
      x = 0
      alignment = "right"
    end
  end

  if fontSize == nil then
    fontSize = GraphicsUtil.fontSize
  end
  local effectiveFontSize = fontSize * (self.gfxScale / NORMAL_GFX_SCALE)
  local fontDelta = effectiveFontSize - GraphicsUtil.fontSize

  GraphicsUtil.printf(string, x, y, limit, alignment, nil, nil, fontDelta)
end

-- Sets up renderIndex-specific properties and assets
-- Configures stack positioning parameters for a specific render index (1-5)
-- For 2-player: 1=left, 2=right
-- For 3-5 player: 1=left (full size), 2-N=stacked right (smaller)
function ClientStack:setupForRenderIndex(renderIndex)
  self.renderIndex = renderIndex

  -- odd renderIndex = left-oriented (mirror_x=1), even = right-oriented (mirror_x=-1)
  if renderIndex % 2 == 1 then
    self.mirror_x = 1
    self.multiplication = 0
  else
    self.mirror_x = -1
    self.multiplication = 1
  end

  if renderIndex < 1 or renderIndex > 5 then
    error("Invalid renderIndex: " .. tostring(renderIndex) .. ". Expected 1-5.")
  end

  -- Use modulo to map to one of 2 asset packs
  local assetIndex = ((renderIndex - 1) % 2) + 1
  self:assignAssets(GAME.theme:getIngameAssetPack(assetIndex))
end

-- Calculates the horizontal position for centering a stack around a given coordinate
---@param centerCoordinate number The X coordinate to center around
---@return number The calculated outer edge position for horizontal centering
function ClientStack:calculateHorizontallyCenteredPosition(centerCoordinate)
  local centerX = centerCoordinate
  local stackWidth = self:canvasWidth()
  local innerStackXMovement = 100
  local outerStackXMovement = stackWidth + innerStackXMovement

  -- Calculate normal renderIndex 1 position (no offset)
  local normalRenderIndex1X = centerX - outerStackXMovement
  
  -- Desired centered position
  local stackWidthUnscaled = self.baseWidth + self.panelOriginXOffset
  local desiredCenterX = (consts.CANVAS_WIDTH - stackWidthUnscaled * self.gfxScale) / 2
  
  -- Calculate and use centering offset instead of provided xOffset
  return centerX - (outerStackXMovement) + (desiredCenterX - normalRenderIndex1X)
end

-- Positions the stack draw position for the given player
function ClientStack:moveForRenderIndex(renderIndex)
  self:setupForRenderIndex(renderIndex)
  
  local centerX = (GAME.globalCanvas:getWidth() / 2)
  local stackWidth = self:canvasWidth()
  local innerStackXMovement = 100
  local outerStackXMovement = stackWidth + innerStackXMovement
  local outerNonScaled = centerX - (outerStackXMovement * self.mirror_x)

  local frameOriginNonScaled = outerNonScaled
  if self.mirror_x == -1 then
    frameOriginNonScaled = outerNonScaled - stackWidth
  end
  
  self:moveToPosition(frameOriginNonScaled, self.baseWidth + self.panelOriginXOffset)
end

-- Calculates responsive scale so right-side stacks fit vertically with margins and gaps
---@param numStacksOnRight integer
---@param topMargin number
---@param bottomMargin number
---@param gap number
function ClientStack:calculateResponsiveScale(numStacksOnRight, topMargin, bottomMargin, gap)
  local canvasHeight = GAME.globalCanvas:getHeight()
  local availableHeight = canvasHeight - topMargin - bottomMargin - (numStacksOnRight - 1) * gap
  local maxScale = availableHeight / (self.baseHeight * numStacksOnRight)

  -- allow sub-1 scales for 4-player while preventing tiny unreadable stacks
  return math.max(0.85, math.min(2.5, maxScale))
end

-- Positions the stack in a 3-player layout with responsive scaling
-- renderIndex: 1=left (full size), 2=top-right (smaller), 3=bottom-right (smaller)
-- Uses responsive scaling based on canvas height to ensure both right stacks fit
function ClientStack:moveForRenderIndex3Player(renderIndex)
  if renderIndex == 1 then
    -- Player 1 uses EXACTLY the same positioning as 2-player PvP
    self:moveForRenderIndex(1)
  else
    -- Players 2 & 3 on the right with responsive scaling
    self:setupForRenderIndex(renderIndex)

    local canvasWidth = GAME.globalCanvas:getWidth()
    local topMargin = self.baseWidth + self.panelOriginXOffset
    local bottomMargin = 12
    local gap = 12

    -- Responsive scaling for 2 stacks on the right
    self.gfxScale = self:calculateResponsiveScale(2, topMargin, bottomMargin, gap)
    local stackWidth = self:canvasWidth()
    local stackHeight = self:canvasHeight()
    local rightX = canvasWidth - stackWidth - 24  -- Right side with margin
    
    if renderIndex == 2 then
      -- Top-right
      self:moveToPosition(rightX, topMargin)
    elseif renderIndex == 3 then
      -- Bottom-right
      local bottomY = topMargin + stackHeight + gap
      self:moveToPosition(rightX, bottomY)
    end
  end
end

-- Positions the stack in a 4-player layout with responsive scaling (all right side, vertically stacked)
-- renderIndex: 1=left (full size), 2=top-right, 3=middle-right, 4=bottom-right (smaller)
-- Uses responsive scaling based on canvas height to ensure all 3 right stacks fit
function ClientStack:moveForRenderIndex4PlayerHorizontal(renderIndex)
  if renderIndex == 1 then
    -- Player 1 uses EXACTLY the same positioning as 2-player PvP
    self:moveForRenderIndex(1)
  else
    -- Players 2, 3, 4 on the right with responsive scaling
    self:setupForRenderIndex(renderIndex)

    local canvasWidth = GAME.globalCanvas:getWidth()
    local topMargin = self.baseWidth + self.panelOriginXOffset
    local bottomMargin = 12
    local gap = 8

    -- Responsive scaling for 3 stacks on the right
    self.gfxScale = self:calculateResponsiveScale(3, topMargin, bottomMargin, gap)
    local stackWidth = self:canvasWidth()
    local stackHeight = self:canvasHeight()
    local rightX = canvasWidth - stackWidth - 24  -- Right side with margin
    
    if renderIndex == 2 then
      -- Top-right
      self:moveToPosition(rightX, topMargin)
    elseif renderIndex == 3 then
      -- Middle-right
      local middleY = topMargin + stackHeight + gap
      self:moveToPosition(rightX, middleY)
    elseif renderIndex == 4 then
      -- Bottom-right
      local bottomY = topMargin + (stackHeight + gap) * 2
      self:moveToPosition(rightX, bottomY)
    end
  end
end

-- Positions the stack in a 5-player layout with responsive scaling (all right side, vertically stacked)
-- renderIndex: 1=left (full size), 2=top-right, 3, 4, 5=stacked below (smaller)
function ClientStack:moveForRenderIndex5Player(renderIndex)
  if renderIndex == 1 then
    self:moveForRenderIndex(1)
  else
    self:setupForRenderIndex(renderIndex)

    local canvasWidth = GAME.globalCanvas:getWidth()
    local topMargin = self.baseWidth + self.panelOriginXOffset
    local bottomMargin = 12
    local gap = 8

    -- Responsive scaling for 4 stacks on the right
    self.gfxScale = self:calculateResponsiveScale(4, topMargin, bottomMargin, gap)
    local stackWidth = self:canvasWidth()
    local stackHeight = self:canvasHeight()
    local rightX = canvasWidth - stackWidth - 24

    local slot = renderIndex - 2  -- 0-indexed slot on the right side
    self:moveToPosition(rightX, topMargin + slot * (stackHeight + gap))
  end
end

-- Positions the stack in a 4-player 2x2 grid layout (alternative layout)
-- renderIndex: 1=top-left, 2=top-right, 3=bottom-left, 4=bottom-right
function ClientStack:moveForRenderIndex4Player(renderIndex)
  self:setupForRenderIndex(renderIndex)

  local canvasWidth = GAME.globalCanvas:getWidth()
  local canvasHeight = GAME.globalCanvas:getHeight()
  local stackWidth = self:canvasWidth()

  -- Calculate grid positions
  local leftX = 80  -- Left column
  local rightX = canvasWidth - stackWidth - 80  -- Right column
  local topY = self.baseWidth + self.panelOriginXOffset  -- Same as 2-player top
  local bottomY = canvasHeight / 2 + 20  -- Bottom row

  local positions = {
    {x = leftX, y = topY},      -- 1: top-left
    {x = rightX, y = topY},     -- 2: top-right
    {x = leftX, y = bottomY},   -- 3: bottom-left
    {x = rightX, y = bottomY},  -- 4: bottom-right
  }

  local pos = positions[renderIndex]
  if pos then
    self:moveToPosition(pos.x, pos.y)
  end
end

-- Positions the stack centered on screen (for puzzle mode)
function ClientStack:moveToCenterPosition()
  local centerX = (GAME.globalCanvas:getWidth() / 2)
  local outerNonScaled = self:calculateHorizontallyCenteredPosition(centerX)

  self:moveToPosition(outerNonScaled, self.baseWidth + self.panelOriginXOffset)
end

---@param x integer in screen coordinates
---@param y integer in screen coordinates
function ClientStack:moveToPosition(x, y)
  self.frameOriginX = x / self.gfxScale
  self.frameOriginY = y / self.gfxScale
  self.panelOriginX = self.frameOriginX + self.panelOriginXOffset
  self.panelOriginY = self.frameOriginY + self.panelOriginYOffset
  local stackWidth = self.mirror_x == -1 and self:canvasWidth() or 0
  local outerNonScaled = x + stackWidth
  self.origin_x = (self.panelOriginXOffset * self.mirror_x) + (outerNonScaled / self.gfxScale)
end

-- to be used in conjunction with resetDrawArea
-- sets the draw area for the Stack by defining an area outside of which all draws are cut off
--   and translating following draws to be relative to the top left origin of the area
---@param xOffset integer? provides an additional x offset e.g. from translation as scissors only operates in screen/canvas coordinates
---@param yOffset integer? provides an additional y offset e.g. from translation as scissors only operates in screen/canvas coordinates
function ClientStack:setDrawArea(xOffset, yOffset)
  xOffset = xOffset or 0
  yOffset = yOffset or 0
  -- this used to be a canvas instead but turns out switching between canvases can be quite the overhead
  love.graphics.setScissor(xOffset + self.frameOriginX * self.gfxScale, yOffset + self.frameOriginY * self.gfxScale, self.baseWidth * self.gfxScale, self.baseHeight * self.gfxScale)
  love.graphics.push("transform")
  love.graphics.translate(self.frameOriginX * self.gfxScale, self.frameOriginY * self.gfxScale)
end

-- to be used in conjunction with setDrawArea
-- resets the draw area and removes the translation
function ClientStack:resetDrawArea()
  love.graphics.pop()
  love.graphics.setScissor()
end

function ClientStack:drawCharacter()
  -- Update portrait fade if needed
  if self.engine.do_countdown then
    -- self.portraitFade starts at 0 (no fade)
    if self.engine.clock and self.engine.clock > 0 then
      local desiredFade = config.portrait_darkness / 100
      local startFrame = 50
      local fadeDuration = 30
      if self.engine.clock <= 50 then
        self.portraitFade = 0
      elseif self.engine.clock > 50 and self.engine.clock <= startFrame + fadeDuration then
        local percent = (self.engine.clock - startFrame) / fadeDuration
        self.portraitFade = desiredFade * percent
      end
    end
  else
    self.portraitFade = config.portrait_darkness / 100 -- Set to desired fade if there's no countdown
  end

  self.character:drawPortrait(self.renderIndex, self.panelOriginXOffset, self.panelOriginYOffset, self.portraitFade, self.gfxScale)
end

function ClientStack:drawFrame()
  local frameImage = self.assets.frame

  if frameImage then
    local scaleX = self:canvasWidth() / frameImage:getWidth()
    local scaleY = self:canvasHeight() / frameImage:getHeight()
    GraphicsUtil.draw(frameImage, 0, 0, 0, scaleX, scaleY)
  end
end

function ClientStack:drawWall(displacement, rowCount)
  local wallImage = self.assets.wall

  if wallImage then
    local y = (4 - displacement + rowCount * 16) * self.gfxScale
    local width = 96
    local scaleX = width * self.gfxScale / wallImage:getWidth()
    GraphicsUtil.draw(wallImage, 4 * self.gfxScale, y, 0, scaleX, scaleX)
  end
end

function ClientStack:drawCountdown()
  if self.engine.do_countdown and self.engine.countdown_timer and self.engine.countdown_timer > 0 then
    local ready_x = 16
    local initial_ready_y = 4
    local ready_y_drop_speed = 6
    local ready_y = initial_ready_y + (math.min(8, self.engine.clock) - 1) * ready_y_drop_speed
    local countdown_x = 44
    local countdown_y = 68
    if self.engine.clock <= 8 then
      drawGfxScaled(self, themes[config.theme].images.IMG_ready, ready_x, ready_y)
    elseif self.engine.clock >= 9 and self.engine.countdown_timer and self.engine.countdown_timer > 0 then
      if self.engine.countdown_timer >= 100 then
        drawGfxScaled(self, themes[config.theme].images.IMG_ready, ready_x, ready_y)
      end
      local IMG_number_to_draw = themes[config.theme].images.IMG_numbers[math.ceil(self.engine.countdown_timer / 60)]
      if IMG_number_to_draw then
        drawGfxScaled(self, IMG_number_to_draw, countdown_x, countdown_y)
      end
    end
  end
end

function ClientStack:canvasWidth()
  return self.baseWidth * self.gfxScale
end

function ClientStack:canvasHeight()
  return self.baseHeight * self.gfxScale
end

function ClientStack:drawAbsoluteMultibar(stop_time, shake_time, pre_stop_time)
  local framePos = themes[config.theme].healthbar_frame_Pos
  local barPos = themes[config.theme].multibar_Pos
  local overtimePos = themes[config.theme].multibar_LeftoverTime_Pos

  self:drawLabel(self.assets.multibar.frameAbsolute, framePos, themes[config.theme].healthbar_frame_Scale * (self.gfxScale / 3))

  local multiBarFrameCount = self.multiBarFrameCount
  local multiBarMaxHeight = 589 * (self.gfxScale / 3) * themes[config.theme].multibar_Scale
  local bottomOffset = 0

  local healthHeight = (self.engine.health / multiBarFrameCount) * multiBarMaxHeight
  healthHeight = math.min(healthHeight, multiBarMaxHeight)
  self:drawBar(self.assets.multibar.health, self.healthQuad, barPos, healthHeight, 0, 0, themes[config.theme].multibar_Scale)

  bottomOffset = healthHeight

  local stopHeight = 0
  local preStopHeight = 0

  if shake_time > 0 and shake_time > (stop_time + pre_stop_time) then
    -- shake is only drawn if it is greater than prestop + stop
    -- shake is always guaranteed to fit
    local shakeHeight = (shake_time / multiBarFrameCount) * multiBarMaxHeight
    self:drawBar(self.assets.multibar.shake, self.multi_shakeQuad, barPos, shakeHeight, bottomOffset, 0, themes[config.theme].multibar_Scale)
  else
    -- stop/prestop are only drawn if greater than shake
    if stop_time > 0 then
      stopHeight = math.min(stop_time, multiBarFrameCount - self.engine.health) / multiBarFrameCount * multiBarMaxHeight
      self:drawBar(self.assets.multibar.stop, self.multi_stopQuad, barPos, stopHeight, bottomOffset, 0, themes[config.theme].multibar_Scale)

      bottomOffset = bottomOffset + stopHeight
    end

    local totalInvincibility = self.engine.health + stop_time + pre_stop_time
    local remainingSeconds = 0
    if totalInvincibility > multiBarFrameCount then
      -- total invincibility exceeds what the multibar can display -> fill only the remaining space with prestop
      preStopHeight = (1 - (self.engine.health + stop_time) / multiBarFrameCount) * multiBarMaxHeight
      remainingSeconds = (totalInvincibility - multiBarFrameCount) / 60
    else
      preStopHeight = pre_stop_time / multiBarFrameCount * multiBarMaxHeight
    end

    if pre_stop_time and pre_stop_time > 0 then
      self:drawBar(self.assets.multibar.preStop, self.multi_prestopQuad, barPos, preStopHeight, bottomOffset, 0, themes[config.theme].multibar_Scale)
    end

    if remainingSeconds > 0 then
      self:drawString(string.format("%." .. themes[config.theme].multibar_LeftoverTime_Decimals .. "f", remainingSeconds), overtimePos, false, 20)
    end
  end
end

function ClientStack:drawPlayerName()
  local username = (self.player.name or "")
  self:drawString(username, themes[config.theme].name_Pos, true, themes[config.theme].name_Font_Size)
end

function ClientStack:drawWinCount()
  self:drawLabel(self.assets.wins, themes[config.theme].winLabel_Pos, themes[config.theme].winLabel_Scale, true)
  self:drawNumber(self.player:getWinCountForDisplay(), themes[config.theme].win_Pos, themes[config.theme].win_Scale, true)
end

function ClientStack.attackSoundInfoForMatch(isChainLink, chainSize, comboSize, metalCount)
  if metalCount > 0 then
    -- override SFX with shock sound
    return {type = consts.ATTACK_TYPE.shock, size = metalCount}
  elseif isChainLink then
    return {type = consts.ATTACK_TYPE.chain, size = chainSize}
  elseif comboSize > 3 then
    return {type = consts.ATTACK_TYPE.combo, size = comboSize}
  end
  return nil
end

---@param doCountdown boolean if the stack should have a countdown at the beginning
function ClientStack:setCountdown(doCountdown)
  self.engine:setCountdown(doCountdown)
end

function ClientStack:isCatchingUp()
  return self.engine.play_to_end
end

---@param garbageSource ClientStack
function ClientStack:setGarbageSource(garbageSource)
  self.garbageSource = garbageSource
end

function ClientStack:setMaxRunsPerFrame(maxRunsPerFrame)
  self.engine:setMaxRunsPerFrame(maxRunsPerFrame)
end

---@return boolean
function ClientStack:game_ended()
  return self.engine:game_ended()
end

---@param assetPack IngameAssetPack
function ClientStack:assignAssets(assetPack)
  self.assets = assetPack

  local width, height = self.assets.multibar.health:getDimensions()
  self.healthQuad = GraphicsUtil:newRecycledQuad(0, 0, width, height, width, height)
  width, height = self.assets.multibar.preStop:getDimensions()
  self.multi_prestopQuad = GraphicsUtil:newRecycledQuad(0, 0, width, height, width, height)
  width, height = self.assets.multibar.stop:getDimensions()
  self.multi_stopQuad = GraphicsUtil:newRecycledQuad(0, 0, width, height, width, height)
  width, height = self.assets.multibar.shake:getDimensions()
  self.multi_shakeQuad = GraphicsUtil:newRecycledQuad(0, 0, width, height, width, height)
end

function ClientStack:deinit()
  ModController:releaseModsFor(self)
  GraphicsUtil:releaseQuad(self.healthQuad)
  GraphicsUtil:releaseQuad(self.multi_prestopQuad)
  GraphicsUtil:releaseQuad(self.multi_stopQuad)
  GraphicsUtil:releaseQuad(self.multi_shakeQuad)
end

---@alias GarbageTarget {frameOriginX: number, frameOriginY: number, mirror_x: integer, canvasWidth: number}

---@param garbageTarget GarbageTarget
function ClientStack:setGarbageTarget(garbageTarget)
  self.garbageTarget = garbageTarget
end

--------------------------------
------ abstract functions ------
--------------------------------

function ClientStack:runGameOver()
  error("did not implement runGameOver")
end

---@param matchEnded boolean?
function ClientStack:render(matchEnded)
  error("did not implement render")
end

return ClientStack
