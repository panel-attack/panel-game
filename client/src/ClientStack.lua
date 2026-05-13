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
---@field garbageTarget GarbageTarget? Convenience alias for garbageTargets[1] (legacy 1v1 paths)
---@field garbageTargets GarbageTarget[]? All targets this stack visually attacks (Telegraph render loops over these)
---@field assets IngameAssetPack
---@field layoutSlot integer determines the position of the stack and how some elements are rendered
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

--------------------------------------------------------------------------------
-- Shared panel component
--
-- Strategy: render every stack as if it were Player 1 (gfxScale = NORMAL), and
-- wrap the HUD draw in a translate+scale transform that maps Player 1's
-- coordinate system onto wherever this stack actually lives on the canvas.
--
-- For Player 1 the transform is identity. For minis the transform translates
-- to that mini's panel origin and scales by gfxScale/NORMAL. The existing draw
-- functions don't have to know whether they're full or mini.
--
-- STACK_X / STACK_Y must equal Player 1's actual screen-pixel frame position
-- so that "Player 1 coords inside the transform" lands at the real stack frame
-- after the transform is applied.
--------------------------------------------------------------------------------
ClientStack.PANEL_LAYOUT = {
  STACK_X = 228,  -- Player 1's frameOriginX * NORMAL_GFX_SCALE  (76 * 3)
  STACK_Y = 108,  -- Player 1's frameOriginY * NORMAL_GFX_SCALE  (baseWidth + panelOriginXOffset)
}

-- Vertical gap between rows of mini stacks; sized so each mini's panel
-- (which extends above and below its stack frame for HUD) doesn't overlap
-- the row above. Used by every multi-row mini layout below.
ClientStack.MINI_LABEL_AREA = 100

-- (panelOriginX, panelOriginY, panelScale) — translate+scale that puts a
-- Player-1-coord HUD draw at the right screen location for THIS stack.
function ClientStack:getPanelTransform()
  local panelScale = self.gfxScale / NORMAL_GFX_SCALE
  local frameScreenX = self.frameOriginX * self.gfxScale
  local frameScreenY = self.frameOriginY * self.gfxScale
  local panelOriginX = frameScreenX - ClientStack.PANEL_LAYOUT.STACK_X * panelScale
  local panelOriginY = frameScreenY - ClientStack.PANEL_LAYOUT.STACK_Y * panelScale
  return panelOriginX, panelOriginY, panelScale
end

-- Wrap fn() so all draw calls inside use Player 1's coordinate system.
-- The stack's positioning state is temporarily swapped to Player 1's values;
-- the panel transform then re-projects everything to this stack's actual
-- screen position and size.
function ClientStack:withPanelTransform(fn)
  local panelOriginX, panelOriginY, panelScale = self:getPanelTransform()

  local saved = {
    gfxScale = self.gfxScale,
    frameOriginX = self.frameOriginX,
    frameOriginY = self.frameOriginY,
    panelOriginX = self.panelOriginX,
    panelOriginY = self.panelOriginY,
    origin_x = self.origin_x,
    mirror_x = self.mirror_x,
    multiplication = self.multiplication,
    layoutSlot = self.layoutSlot,
  }

  -- Pretend to be Player 1.
  self.gfxScale = NORMAL_GFX_SCALE
  self.frameOriginX = ClientStack.PANEL_LAYOUT.STACK_X / NORMAL_GFX_SCALE
  self.frameOriginY = ClientStack.PANEL_LAYOUT.STACK_Y / NORMAL_GFX_SCALE
  self.panelOriginX = self.frameOriginX + self.panelOriginXOffset
  self.panelOriginY = self.frameOriginY + self.panelOriginYOffset
  self.mirror_x = 1
  self.multiplication = 0
  self.layoutSlot = 1
  self.origin_x = self.panelOriginXOffset + self.frameOriginX

  love.graphics.push("transform")
  love.graphics.translate(panelOriginX, panelOriginY)
  love.graphics.scale(panelScale, panelScale)

  fn()

  love.graphics.pop()

  for k, v in pairs(saved) do
    self[k] = v
  end
end

-- Provides the X origin to draw an element of the stack
-- cameFromLegacyScoreOffset - set to true if this used to use the "score" position in legacy themes
function ClientStack:elementOriginX(cameFromLegacyScoreOffset, legacyOffsetIsAlreadyScaled)
  assert(cameFromLegacyScoreOffset ~= nil)
  assert(legacyOffsetIsAlreadyScaled ~= nil)
  local x = 546
  if self.layoutSlot == 2 or self.layoutSlot == 4 then
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
  -- Fixed-theme offsets are screen-space values calibrated for NORMAL_GFX_SCALE; scale them so
  -- HUD elements stay correctly positioned relative to mini panels at smaller gfxScale values.
  if themes[config.theme]:offsetsAreFixed() then
    xOffset = xOffset * (self.gfxScale / NORMAL_GFX_SCALE)
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
  -- Fixed-theme offsets are screen-space values calibrated for NORMAL_GFX_SCALE; scale them so
  -- HUD elements stay correctly positioned relative to mini panels at smaller gfxScale values.
  if themes[config.theme]:offsetsAreFixed() then
    yOffset = yOffset * (self.gfxScale / NORMAL_GFX_SCALE)
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
    if self.layoutSlot == 1 then
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

-- Sets up layoutSlot-specific properties and assets
-- Configures stack positioning parameters for a specific render index (1-7)
-- For 2-player: 1=left, 2=right
-- For 3-7 player: 1=left (full size), 2-N=stacked right (smaller)
function ClientStack:setupForLayoutSlot(layoutSlot)
  self.layoutSlot = layoutSlot

  -- odd layoutSlot = left-oriented (mirror_x=1), even = right-oriented (mirror_x=-1)
  if layoutSlot % 2 == 1 then
    self.mirror_x = 1
    self.multiplication = 0
  else
    self.mirror_x = -1
    self.multiplication = 1
  end

  if layoutSlot < 1 or layoutSlot > 7 then
    error("Invalid layoutSlot: " .. tostring(layoutSlot) .. ". Expected 1-7.")
  end

  -- Use modulo to map to one of 2 asset packs
  local assetIndex = ((layoutSlot - 1) % 2) + 1
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

  -- Calculate normal layoutSlot 1 position (no offset)
  local normalLayoutSlot1X = centerX - outerStackXMovement
  
  -- Desired centered position
  local stackWidthUnscaled = self.baseWidth + self.panelOriginXOffset
  local desiredCenterX = (consts.CANVAS_WIDTH - stackWidthUnscaled * self.gfxScale) / 2
  
  -- Calculate and use centering offset instead of provided xOffset
  return centerX - (outerStackXMovement) + (desiredCenterX - normalLayoutSlot1X)
end

-- Positions the stack draw position for the given player
function ClientStack:moveForLayoutSlot(layoutSlot)
  self:setupForLayoutSlot(layoutSlot)
  
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

-- Calculates responsive scale for right-column stacks with both height and width constraints.
-- Keeps the center gap around the local left-side player unchanged.
---@param numStacksOnRight integer
---@param topMargin number
---@param bottomMargin number
---@param gap number
---@param rightMargin number
function ClientStack:calculateResponsiveScaleForRightColumn(numStacksOnRight, topMargin, bottomMargin, gap, rightMargin)
  local canvasWidth = GAME.globalCanvas:getWidth()
  local canvasHeight = GAME.globalCanvas:getHeight()

  local availableHeight = canvasHeight - topMargin - bottomMargin - (numStacksOnRight - 1) * gap
  local heightBoundScale = availableHeight / (self.baseHeight * numStacksOnRight)

  -- Preserve the classic two-player center gutter:
  -- left player right edge at centerX - 100, right column left edge not before centerX + 100.
  local centerX = canvasWidth / 2
  local minRightColumnLeftX = centerX + 100
  local availableWidth = (canvasWidth - rightMargin) - minRightColumnLeftX
  local widthBoundScale = availableWidth / self.baseWidth

  return math.max(0.85, math.min(NORMAL_GFX_SCALE, widthBoundScale, heightBoundScale))
end

-- Positions the stack in a 3-player layout with responsive scaling
-- layoutSlot: 1=left (full size), 2=top-right (smaller), 3=bottom-right (smaller)
-- Uses responsive scaling based on canvas height to ensure both right stacks fit
function ClientStack:moveForLayoutSlot3Player(layoutSlot)
  if layoutSlot == 1 then
    -- Player 1 uses EXACTLY the same positioning as 2-player PvP.
    -- Reset gfxScale to its full size — a stack moving back into the big-left
    -- container (e.g. spectator focus rotated to this player) would otherwise
    -- keep the smaller scale assigned during its previous right-column stint.
    self.gfxScale = NORMAL_GFX_SCALE
    self:moveForLayoutSlot(1)
  else
    -- Players 2 & 3 on the right with responsive scaling
    self:setupForLayoutSlot(layoutSlot)

    local canvasWidth = GAME.globalCanvas:getWidth()
    local topMargin = self.baseWidth + self.panelOriginXOffset
    local bottomMargin = 12
    -- Gap between rows must reserve room for the lower stack's name / WINS / LEVEL labels.
    local gap = ClientStack.MINI_LABEL_AREA
    local rightMargin = 24

    -- Responsive scaling for 2 stacks on the right
    self.gfxScale = self:calculateResponsiveScaleForRightColumn(2, topMargin, bottomMargin, gap, rightMargin)
    local stackWidth = self:canvasWidth()
    local stackHeight = self:canvasHeight()
    local rightX = canvasWidth - stackWidth - rightMargin  -- Right side with margin
    
    if layoutSlot == 2 then
      -- Top-right
      self:moveToPosition(rightX, topMargin)
    elseif layoutSlot == 3 then
      -- Bottom-right
      local bottomY = topMargin + stackHeight + gap
      self:moveToPosition(rightX, bottomY)
    end
  end
end

-- Positions the stack in a 4-player layout with fixed local anchor and right-side matrix.
-- Layout rule: row1 = 2,4 ; row2 = 3 (centered)
-- layoutSlot: 1=left (unchanged), 2=top-left-right-zone, 4=top-right-right-zone, 3=bottom-center-right-zone
function ClientStack:moveForLayoutSlot4PlayerHorizontal(layoutSlot)
  if layoutSlot == 1 then
    -- Player 1 uses EXACTLY the same positioning as 2-player PvP.
    -- Reset gfxScale: a stack returning to the big-left container from a
    -- right-column slot would otherwise stay at the reduced scale.
    self.gfxScale = NORMAL_GFX_SCALE
    self:moveForLayoutSlot(1)
  else
    -- Players 2, 3, 4 in a 2x2-capable zone on the right
    self:setupForLayoutSlot(layoutSlot)

    local canvasWidth = GAME.globalCanvas:getWidth()
    local canvasHeight = GAME.globalCanvas:getHeight()
    local topMargin = self.baseWidth + self.panelOriginXOffset
    local bottomMargin = 12
    -- gapX must fit each mini's analytics column (which sits to the LEFT of its
    -- frame as part of the shared panel component) between adjacent stacks.
    local gapX = 100
    -- Vertical gap reserves the label area above the bottom row's mini stacks.
    local gapY = ClientStack.MINI_LABEL_AREA
    local rightMargin = 24

    -- Keep the center gap around player 1 and fit a 2-column by 2-row right-side zone.
    local minRightColumnLeftX = (canvasWidth / 2) + 100
    local rightZoneWidth = (canvasWidth - rightMargin) - minRightColumnLeftX
    local rightZoneHeight = canvasHeight - topMargin - bottomMargin

    local widthBoundScale = (rightZoneWidth - gapX) / (self.baseWidth * 2)
    local heightBoundScale = (rightZoneHeight - gapY) / (self.baseHeight * 2)
    self.gfxScale = math.max(0.85, math.min(NORMAL_GFX_SCALE, widthBoundScale, heightBoundScale))

    local stackWidth = self:canvasWidth()
    local stackHeight = self:canvasHeight()
    local gridWidth = (stackWidth * 2) + gapX
    local gridHeight = (stackHeight * 2) + gapY

    local startX = minRightColumnLeftX + math.max(0, (rightZoneWidth - gridWidth) / 2)
    local startY = topMargin + math.max(0, (rightZoneHeight - gridHeight) / 2)
    local row2Y = startY + stackHeight + gapY

    if layoutSlot == 2 then
      self:moveToPosition(startX, startY)
    elseif layoutSlot == 3 then
      -- Bottom row has only one stack in 4p rule, left-aligned under the first slot.
      self:moveToPosition(startX, row2Y)
    elseif layoutSlot == 4 then
      self:moveToPosition(startX + stackWidth + gapX, startY)
    end
  end
end

-- Positions the stack in a 5-player layout with fixed local anchor and right-side matrix.
-- Layout rule: row1 = 2,4 ; row2 = 3,5
-- layoutSlot: 1=left (unchanged), 2/4 top row, 3/5 bottom row
function ClientStack:moveForLayoutSlot5Player(layoutSlot)
  if layoutSlot == 1 then
    -- Reset gfxScale for stacks returning from a right-column slot.
    self.gfxScale = NORMAL_GFX_SCALE
    self:moveForLayoutSlot(1)
  else
    self:setupForLayoutSlot(layoutSlot)

    local canvasWidth = GAME.globalCanvas:getWidth()
    local canvasHeight = GAME.globalCanvas:getHeight()
    local topMargin = self.baseWidth + self.panelOriginXOffset
    local bottomMargin = 12
    -- gapX must fit each mini's analytics column (which sits to the LEFT of its
    -- frame as part of the shared panel component) between adjacent stacks.
    local gapX = 100
    -- Vertical gap reserves the label area above the bottom row's mini stacks.
    local gapY = ClientStack.MINI_LABEL_AREA
    local rightMargin = 24

    local minRightColumnLeftX = (canvasWidth / 2) + 100
    local rightZoneWidth = (canvasWidth - rightMargin) - minRightColumnLeftX
    local rightZoneHeight = canvasHeight - topMargin - bottomMargin

    local widthBoundScale = (rightZoneWidth - gapX) / (self.baseWidth * 2)
    local heightBoundScale = (rightZoneHeight - gapY) / (self.baseHeight * 2)
    self.gfxScale = math.max(0.85, math.min(NORMAL_GFX_SCALE, widthBoundScale, heightBoundScale))

    local stackWidth = self:canvasWidth()
    local stackHeight = self:canvasHeight()
    local gridWidth = (stackWidth * 2) + gapX
    local gridHeight = (stackHeight * 2) + gapY

    local startX = minRightColumnLeftX + math.max(0, (rightZoneWidth - gridWidth) / 2)
    local startY = topMargin + math.max(0, (rightZoneHeight - gridHeight) / 2)
    local row2Y = startY + stackHeight + gapY

    if layoutSlot == 2 then
      self:moveToPosition(startX, startY)
    elseif layoutSlot == 4 then
      self:moveToPosition(startX + stackWidth + gapX, startY)
    elseif layoutSlot == 3 then
      self:moveToPosition(startX, row2Y)
    elseif layoutSlot == 5 then
      self:moveToPosition(startX + stackWidth + gapX, row2Y)
    end
  end
end

-- Positions the stack in a 6-player layout — Player 1 full-size left, plus a
-- 3-column × 2-row mini grid on the right with the last bottom slot empty.
-- Layout rule (col-major top-first, like 4p horizontal):
--   row1 = 2, 4, 6
--   row2 = 3, 5, _
-- Pattern: 11246 / 1135.
function ClientStack:moveForLayoutSlot6Player(layoutSlot)
  if layoutSlot == 1 then
    -- Reset gfxScale for stacks returning from a right-column slot.
    self.gfxScale = NORMAL_GFX_SCALE
    self:moveForLayoutSlot(1)
  else
    self:_positionInRightGrid3x2(layoutSlot)
  end
end

-- Positions the stack in a 7-player layout — Player 1 full-size left, plus a
-- 3-column × 2-row mini grid on the right (all 6 slots filled).
-- Layout rule (col-major top-first, like 5p extended):
--   row1 = 2, 4, 6
--   row2 = 3, 5, 7
-- Pattern: 11246 / 11357
function ClientStack:moveForLayoutSlot7Player(layoutSlot)
  if layoutSlot == 1 then
    -- Reset gfxScale for stacks returning from a right-column slot.
    self.gfxScale = NORMAL_GFX_SCALE
    self:moveForLayoutSlot(1)
  else
    self:_positionInRightGrid3x2(layoutSlot)
  end
end

-- Shared 3-col × 2-row right-side mini grid placement for 6 and 7 player layouts.
-- Caller is responsible for handling layoutSlot==1 (full-size left).
-- Maps layoutSlot 2..7 col-major top-first: 2/3 in col 1, 4/5 in col 2, 6/7 in col 3.
function ClientStack:_positionInRightGrid3x2(layoutSlot)
  self:setupForLayoutSlot(layoutSlot)

  local canvasWidth = GAME.globalCanvas:getWidth()
  local canvasHeight = GAME.globalCanvas:getHeight()
  local topMargin = self.baseWidth + self.panelOriginXOffset
  local bottomMargin = 12
  -- gapX must fit each mini's analytics column (which sits to the LEFT of its
  -- frame as part of the shared panel component) between adjacent stacks.
  local gapX = 100
  -- Vertical gap reserves the label area above the bottom row's mini stacks.
  local gapY = ClientStack.MINI_LABEL_AREA
  local rightMargin = 24

  -- Keep the center gap around player 1 and fit a 3-column by 2-row right-side zone.
  local minRightColumnLeftX = (canvasWidth / 2) + 100
  local rightZoneWidth = (canvasWidth - rightMargin) - minRightColumnLeftX
  local rightZoneHeight = canvasHeight - topMargin - bottomMargin

  -- 3 columns wide → need 2 column gaps; 2 rows tall → 1 row gap.
  local widthBoundScale = (rightZoneWidth - (gapX * 2)) / (self.baseWidth * 3)
  local heightBoundScale = (rightZoneHeight - gapY) / (self.baseHeight * 2)
  self.gfxScale = math.max(0.85, math.min(NORMAL_GFX_SCALE, widthBoundScale, heightBoundScale))

  local stackWidth = self:canvasWidth()
  local stackHeight = self:canvasHeight()
  local gridWidth = (stackWidth * 3) + (gapX * 2)
  local gridHeight = (stackHeight * 2) + gapY

  local startX = minRightColumnLeftX + math.max(0, (rightZoneWidth - gridWidth) / 2)
  local startY = topMargin + math.max(0, (rightZoneHeight - gridHeight) / 2)
  local row2Y = startY + stackHeight + gapY

  local col1X = startX
  local col2X = startX + stackWidth + gapX
  local col3X = startX + (stackWidth + gapX) * 2

  if layoutSlot == 2 then
    self:moveToPosition(col1X, startY)
  elseif layoutSlot == 3 then
    self:moveToPosition(col1X, row2Y)
  elseif layoutSlot == 4 then
    self:moveToPosition(col2X, startY)
  elseif layoutSlot == 5 then
    self:moveToPosition(col2X, row2Y)
  elseif layoutSlot == 6 then
    self:moveToPosition(col3X, startY)
  elseif layoutSlot == 7 then
    self:moveToPosition(col3X, row2Y)
  end
end

-- Positions the stack in a 4-player 2x2 grid layout (alternative layout)
-- layoutSlot: 1=top-left, 2=top-right, 3=bottom-left, 4=bottom-right
function ClientStack:moveForLayoutSlot4Player(layoutSlot)
  self:setupForLayoutSlot(layoutSlot)

  local canvasWidth = GAME.globalCanvas:getWidth()
  local canvasHeight = GAME.globalCanvas:getHeight()
  local topMargin = self.baseWidth + self.panelOriginXOffset
  local bottomMargin = 12
  local sideMargin = 24
  local gapX = 20
  -- Vertical gap reserves the label area above the bottom row's mini stacks.
  local gapY = ClientStack.MINI_LABEL_AREA

  -- Fit a 2x2 stack grid inside the drawable area by constraining scale on both axes.
  local availableWidth = canvasWidth - (sideMargin * 2) - gapX
  local availableHeight = canvasHeight - topMargin - bottomMargin - gapY
  local widthBoundScale = availableWidth / (self.baseWidth * 2)
  local heightBoundScale = availableHeight / (self.baseHeight * 2)
  self.gfxScale = math.max(0.85, math.min(NORMAL_GFX_SCALE, widthBoundScale, heightBoundScale))

  local stackWidth = self:canvasWidth()
  local stackHeight = self:canvasHeight()
  local gridWidth = (stackWidth * 2) + gapX
  local gridHeight = (stackHeight * 2) + gapY

  local startX = (canvasWidth - gridWidth) / 2
  local startY = topMargin + math.max(0, (availableHeight - gridHeight) / 2)

  local positions = {
    {x = startX, y = startY},
    {x = startX + stackWidth + gapX, y = startY},
    {x = startX, y = startY + stackHeight + gapY},
    {x = startX + stackWidth + gapX, y = startY + stackHeight + gapY},
  }

  local pos = positions[layoutSlot]
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

  self.character:drawPortrait(self.layoutSlot, self.panelOriginXOffset, self.panelOriginYOffset, self.portraitFade, self.gfxScale)
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

-- Default team color used when no team assignment is available (e.g. solo / non-team modes).
ClientStack.DEFAULT_TEAM_COLOR = {0.2, 0.2, 0.25, 0.85}

-- Drawn inside withPanelTransform → coordinates are panel-local at scale 1.
-- Renders a team-colored chip with the player's name centered above the stack.
function ClientStack:drawPlayerName()
  local username = (self.player.name or "")
  local layout = ClientStack.PANEL_LAYOUT
  local stackWidth = self.baseWidth * NORMAL_GFX_SCALE      -- 312 at NORMAL scale
  local centerX = layout.STACK_X + stackWidth / 2

  local chipWidth = 240
  local chipHeight = 36
  local chipY = layout.STACK_Y - chipHeight - 6              -- sits just above the frame top
  local chipX = centerX - chipWidth / 2

  local color = self._teamColor or ClientStack.DEFAULT_TEAM_COLOR
  GraphicsUtil.drawRectangle("fill", chipX, chipY, chipWidth, chipHeight, color[1], color[2], color[3], color[4] or 0.85)

  local fontDelta = 8                                          -- bump default font size
  GraphicsUtil.printf(username, chipX, chipY + 6, chipWidth, "center", nil, nil, fontDelta)

  local deathClock = self.engine and self.engine.game_over_clock
  if deathClock and deathClock > 0 then
    local seconds = math.floor(deathClock / 60)
    local marker = string.format("OUT %d:%02d", math.floor(seconds / 60), seconds % 60)
    local markerHeight = 20
    local markerY = chipY - markerHeight - 2
    GraphicsUtil.drawRectangle("fill", chipX, markerY, chipWidth, markerHeight, 0, 0, 0, 0.7)
    GraphicsUtil.printf(marker, chipX, markerY + 2, chipWidth, "center", {1, 0.4, 0.4, 1}, nil, 2)
  end
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

---Replace the target list with a single target (legacy 1v1 caller).
---@param garbageTarget GarbageTarget
function ClientStack:setGarbageTarget(garbageTarget)
  self.garbageTargets = { garbageTarget }
  self.garbageTarget = garbageTarget
end

---Replace the target list with an array of targets (N-target FFA/team modes).
---@param garbageTargets GarbageTarget[]
function ClientStack:setGarbageTargets(garbageTargets)
  self.garbageTargets = garbageTargets or {}
  self.garbageTarget = self.garbageTargets[1]
end

---Append a single target to the existing list.
---@param garbageTarget GarbageTarget
function ClientStack:addGarbageTarget(garbageTarget)
  self.garbageTargets = self.garbageTargets or {}
  self.garbageTargets[#self.garbageTargets + 1] = garbageTarget
  self.garbageTarget = self.garbageTargets[1]
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
