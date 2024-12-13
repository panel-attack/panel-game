local class = require("common.lib.class")
local consts = require("common.engine.consts")
local Signal = require("common.lib.signal")
-- TODO: move graphics related functionality to client
local GraphicsUtil = require("client.src.graphics.graphics_util")

-- Draws an image at the given spot while scaling all coordinate and scale values with stack.gfxScale
local function drawGfxScaled(stack, img, x, y, rot, xScale, yScale)
  xScale = xScale or 1
  yScale = yScale or 1
  GraphicsUtil.draw(img, x * stack.gfxScale, y * stack.gfxScale, rot, xScale * stack.gfxScale, yScale * stack.gfxScale)
end

---The base class for a client side wrapper around an engine stack
---Supports general properties for positioning and drawing
---@class ClientStack
---@field which integer determines the position of the stack like an index but also serves as an id within the match
---@field is_local boolean if the Stack gets its inputs live from the local client or not
---@field character string the id of the character to use for drawing
---@field theme table the theme to determine offsets via theme for multibar and other properties
---@field baseWidth integer
---@field baseHeight integer
---@field gfxScale number scale factor for the entire Stack, default: 3
---@field canvas boolean if the stack is supposed to be drawn
---@field portraitFade number inverse opacity of the character portrait
---@field engine BaseStack the engine actually running the physics
---@field multiBarFrameCount integer at how many frames the BaseStack's multibar tops out
---@field player MatchParticipant
---@field healthQuad love.Quad
---@field multi_prestopQuad love.Quad
---@field multi_stopQuad love.Quad
---@field multi_shakeQuad love.Quad

---@class ClientStack
local ClientStack = class(
function(self, args)
  ---@class ClientStack
  self = self

  assert(args.which)
  assert(args.is_local ~= nil)
  assert(args.character)

  self.which = args.which or 1
  -- player number according to the multiplayer server, for game outcome reporting 
  self.player_number = args.player_number or self.which
  self.is_local = args.is_local
  self.character = args.character
  self.theme = args.theme or themes[config.theme]

  -- graphics
  -- also relevant for the touch input controller method besides general drawing
  self.baseWidth = 104
  self.baseHeight = 204
  self.gfxScale = 3
  -- stacks no longer have a canvas but some functions bool check it to determine whether they should run or not
  -- mostly for tests / not running extra in some scenarios; should be removed once they have been adjusted
  self.canvas = true
  self.portraitFade = config.portrait_darkness / 100 -- will be set back to 0 if count down happens
  self.healthQuad = GraphicsUtil:newRecycledQuad(0, 0, themes[config.theme].images.IMG_healthbar:getWidth(), themes[config.theme].images.IMG_healthbar:getHeight(), themes[config.theme].images.IMG_healthbar:getWidth(), themes[config.theme].images.IMG_healthbar:getHeight())
  self.multi_prestopQuad = GraphicsUtil:newRecycledQuad(0, 0, self.theme.images.IMG_multibar_prestop_bar:getWidth(), self.theme.images.IMG_multibar_prestop_bar:getHeight(), self.theme.images.IMG_multibar_prestop_bar:getWidth(), self.theme.images.IMG_multibar_prestop_bar:getHeight())
  self.multi_stopQuad = GraphicsUtil:newRecycledQuad(0, 0, self.theme.images.IMG_multibar_stop_bar:getWidth(), self.theme.images.IMG_multibar_stop_bar:getHeight(), self.theme.images.IMG_multibar_stop_bar:getWidth(), self.theme.images.IMG_multibar_stop_bar:getHeight())
  self.multi_shakeQuad = GraphicsUtil:newRecycledQuad(0, 0, self.theme.images.IMG_multibar_shake_bar:getWidth(), self.theme.images.IMG_multibar_shake_bar:getHeight(), self.theme.images.IMG_multibar_shake_bar:getWidth(), self.theme.images.IMG_multibar_shake_bar:getHeight())

  self:moveForRenderIndex(self.which)
end)

-- Provides the X origin to draw an element of the stack
-- cameFromLegacyScoreOffset - set to true if this used to use the "score" position in legacy themes
function ClientStack:elementOriginX(cameFromLegacyScoreOffset, legacyOffsetIsAlreadyScaled)
  assert(cameFromLegacyScoreOffset ~= nil)
  assert(legacyOffsetIsAlreadyScaled ~= nil)
  local x = 546
  if self.which == 2 then
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

  local percentWidthShift = 0
  -- If we are mirroring from the right, move the full width left
  if cameFromLegacyScoreOffset == false or themes[config.theme]:offsetsAreFixed() then
    if self.multiplication > 0 then
      percentWidthShift = 1
    end
  end

  local x = self:labelOriginXWithOffset(themePositionOffset, scale, cameFromLegacyScoreOffset, drawable:getWidth(), percentWidthShift, legacyOffsetIsAlreadyScaled)
  local y = self:elementOriginYWithOffset(themePositionOffset, cameFromLegacyScoreOffset, legacyOffsetIsAlreadyScaled)

  GraphicsUtil.draw(drawable, x, y, 0, scale, scale)
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
  local x = self:elementOriginXWithOffset(themePositionOffset, cameFromLegacyScoreOffset)
  local y = self:elementOriginYWithOffset(themePositionOffset, cameFromLegacyScoreOffset)
  GraphicsUtil.drawPixelFont(number, themes[config.theme].fontMaps.numbers[self.which], x, y, scale, scale, "center", 0)
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
    if self.which == 1 then
      limit = x
      x = 0
      alignment = "right"
    end
  end

  if fontSize == nil then
    fontSize = GraphicsUtil.fontSize
  end
  local fontDelta = fontSize - GraphicsUtil.fontSize

  GraphicsUtil.printf(string, x, y, limit, alignment, nil, nil, fontDelta)
end

-- Positions the stack draw position for the given player
function ClientStack:moveForRenderIndex(renderIndex)
    -- Position of elements should ideally be on even coordinates to avoid non pixel alignment
    if renderIndex == 1 then
      self.mirror_x = 1
      self.multiplication = 0
    elseif renderIndex == 2 then
      self.mirror_x = -1
      self.multiplication = 1
    end
    local centerX = (GAME.globalCanvas:getWidth() / 2)
    local stackWidth = self:canvasWidth()
    local innerStackXMovement = 100
    local outerStackXMovement = stackWidth + innerStackXMovement
    self.panelOriginXOffset = 4
    self.panelOriginYOffset = 4

    local outerNonScaled = centerX - (outerStackXMovement * self.mirror_x)
    self.origin_x = (self.panelOriginXOffset * self.mirror_x) + (outerNonScaled / self.gfxScale) -- The outer X value of the frame

    local frameOriginNonScaled = outerNonScaled
    if self.mirror_x == -1 then
      frameOriginNonScaled = outerNonScaled - stackWidth
    end
    self.frameOriginX = frameOriginNonScaled / self.gfxScale -- The left X value where the frame is drawn
    self.frameOriginY = 108 / self.gfxScale

    self.panelOriginX = self.frameOriginX + self.panelOriginXOffset
    self.panelOriginY = self.frameOriginY + self.panelOriginYOffset
end

-- to be used in conjunction with resetDrawArea
-- sets the draw area for the Stack by defining an area outside of which all draws are cut off
--   and translating following draws to be relative to the top left origin of the area
function ClientStack:setDrawArea()
  -- this used to be a canvas instead but turns out switching between canvases can be quite the overhead
  love.graphics.setScissor(self.frameOriginX * self.gfxScale, self.frameOriginY * self.gfxScale, self.baseWidth * self.gfxScale, self.baseHeight * self.gfxScale)
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
  end

  characters[self.character]:drawPortrait(self.which, self.panelOriginXOffset, self.panelOriginYOffset, self.portraitFade, self.gfxScale)
end

function ClientStack:drawFrame()
  local frameImage = themes[config.theme].images.frames[self.which]

  if frameImage then
    local scaleX = self:canvasWidth() / frameImage:getWidth()
    local scaleY = self:canvasHeight() / frameImage:getHeight()
    GraphicsUtil.draw(frameImage, 0, 0, 0, scaleX, scaleY)
  end
end

function ClientStack:drawWall(displacement, rowCount)
  local wallImage = themes[config.theme].images.walls[self.which]

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

  self:drawLabel(themes[config.theme].images.healthbarFrames.absolute[self.which], framePos, themes[config.theme].healthbar_frame_Scale * (self.gfxScale / 3))

  local multiBarFrameCount = self.multiBarFrameCount
  local multiBarMaxHeight = 589 * (self.gfxScale / 3) * themes[config.theme].multibar_Scale
  local bottomOffset = 0

  local healthHeight = (self.engine.health / multiBarFrameCount) * multiBarMaxHeight
  healthHeight = math.min(healthHeight, multiBarMaxHeight)
  self:drawBar(themes[config.theme].images.IMG_healthbar, self.healthQuad, barPos, healthHeight, 0, 0, themes[config.theme].multibar_Scale)

  bottomOffset = healthHeight

  local stopHeight = 0
  local preStopHeight = 0

  if shake_time > 0 and shake_time > (stop_time + pre_stop_time) then
    -- shake is only drawn if it is greater than prestop + stop
    -- shake is always guaranteed to fit
    local shakeHeight = (shake_time / multiBarFrameCount) * multiBarMaxHeight
    self:drawBar(themes[config.theme].images.IMG_multibar_shake_bar, self.multi_shakeQuad, barPos, shakeHeight, bottomOffset, 0, themes[config.theme].multibar_Scale)
  else
    -- stop/prestop are only drawn if greater than shake
    if stop_time > 0 then
      stopHeight = math.min(stop_time, multiBarFrameCount - self.engine.health) / multiBarFrameCount * multiBarMaxHeight
      self:drawBar(themes[config.theme].images.IMG_multibar_stop_bar, self.multi_stopQuad, barPos, stopHeight, bottomOffset, 0, themes[config.theme].multibar_Scale)

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
      self:drawBar(themes[config.theme].images.IMG_multibar_prestop_bar, self.multi_prestopQuad, barPos, preStopHeight, bottomOffset, 0, themes[config.theme].multibar_Scale)
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
  self:drawLabel(themes[config.theme].images.IMG_wins, themes[config.theme].winLabel_Pos, themes[config.theme].winLabel_Scale, true)
  self:drawNumber(self.player:getWinCountForDisplay(), themes[config.theme].win_Pos, themes[config.theme].win_Scale, true)
end

--------------------------------
------ abstract functions ------
--------------------------------

function ClientStack:runGameOver()
  error("did not implement runGameOver")
end

function ClientStack:deinit()
  error("did not implement deinit")
end

function ClientStack:render()
  error("did not implement render")
end

return ClientStack
