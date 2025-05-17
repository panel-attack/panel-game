local class = require("common.lib.class")
require("common.lib.util")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local EngineStack = require("common.engine.Stack")
local tableUtils = require("common.lib.tableUtils")
local logger = require("common.lib.logger")
local UIElement = require("client.src.ui.UIElement")


-- A class for rendering the engines current panels at the given location
---@class PanelBoardElement
---@field danger boolean panels in the top row (danger); unlike panels_in_top_row I think this does not indicate a top out in all cases
---@field danger_timer integer Decides the bounce frame while the column is in danger, increments and stops according to certain rules
---@field danger_col boolean[] Tracks for each column if it is considered in danger for the danger animation. Danger means high rows being filled in that column. \n
local PanelBoardElement = class(
function(self, engine, theme, panelSet, width, height, scale)
  ---@class PanelBoardElement
  self = self
  self.engine = engine
  self.theme = theme
  self.panelSet = panelSet
  self.width = width
  self.height = height
  self.scale = scale
  self.danger = false
  self.danger_col = {false, false, false, false, false, false}
  self.danger_timer = 0
end,
UIElement)

-- calculate which columns should bounce
function PanelBoardElement:updateDangerBounce()
  if not self.engine.behaviours.passiveRaise then
    -- no passive raise, no danger
    return
  end

  -- reset state
  self.danger = false
  for column = 1, self.engine.width do
    self.danger_col[column] = false
  end

  for row = self.engine.height - 1, self.engine.height do
    local panelRow = self.engine.panels[row]
    if panelRow then
      for idx = 1, self.engine.width do
        if panelRow[idx]:dangerous() then
          self.danger = true
          self.danger_col[idx] = true
        end
      end
    end
  end

  if self.danger then
    if self.engine.panels_in_top_row and self.engine.speed ~= 0 then
      -- Player has topped out, panels hold the "flattened" frame
      self.danger_timer = 0
    elseif self.engine.stop_time == 0 then
      self.danger_timer = self.danger_timer + 1
    end
  else
    self.danger_timer = 0
  end
end

-- Draws an image at the given spot while scaling all coordinate and scale values with stack.scale
local function drawGfxScaled(stack, img, x, y, rot, xScale, yScale)
  xScale = xScale or 1
  yScale = yScale or 1
  GraphicsUtil.draw(img, x * stack.scale, y * stack.scale, rot, xScale * stack.scale, yScale * stack.scale)
end

-- Draws an image at the given position, using the quad for the viewport, scaling all coordinate values and scales by stack.scale
local function drawQuadGfxScaled(stack, image, quad, x, y, rotation, xScale, yScale, xOffset, yOffset, mirror)
  xScale = xScale or 1
  yScale = yScale or 1

  if mirror and mirror == 1 then
    local qX, qY, qW, qH = quad:getViewport()
    x = x - (qW*xScale)
  end

  GraphicsUtil.drawQuad(image, quad, x * stack.scale, y * stack.scale, rotation, xScale * stack.scale, yScale * stack.scale, xOffset, yOffset)
end

function PanelBoardElement:drawDebugPanels(shakeOffset)
  if not config.debug_mode then
    return
  end

  local engine = self.engine
  local mouseX, mouseY = GAME:transform_coordinates(love.mouse.getPosition())

  for row = 0, math.min(engine.height + 1, #engine.panels) do
    for col = 1, engine.width do
      local panel = engine.panels[row][col]
      local draw_x = (4 + (col - 1) * 16) * self.scale
      local draw_y = (4 + (11 - (row)) * 16 + engine.displacement - shakeOffset) * self.scale

      -- Require hovering over a stack to show details
      if mouseX >= self.x * self.scale and mouseX <= (self.x + engine.width * 16) * self.scale then
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

      if mouseX >= draw_x and mouseX < draw_x + 16 * self.scale and mouseY >= draw_y and mouseY < draw_y + 16 * self.scale then
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

function PanelBoardElement:render(renderCursor, garbageImages, shockGarbageImages, shakeOffset)
  self:drawPanels(garbageImages, shockGarbageImages, shakeOffset)
  -- Draw the cursor
  if renderCursor then
    self:renderCursor(shakeOffset)
  end

  self:drawDebugPanels(shakeOffset)
end

-- Draw the stacks cursor
function PanelBoardElement:renderCursor(shake)
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

  local cursor = self.theme.images.cursor[(math.floor(self.engine.clock / 16) % 2) + 1]
  local desiredCursorWidth = 40
  local panelWidth = 16
  local scale_x = desiredCursorWidth / cursor.image:getWidth()
  local scale_y = 24 / cursor.image:getHeight()
  local xPosition = (engine.cur_col - 1) * panelWidth

  if engine.inputMethod == "touch" then
    drawQuadGfxScaled(self, cursor.image, cursor.touchQuads[1], xPosition, (11 - (engine.cur_row)) * panelWidth + engine.displacement - shake, 0, scale_x, scale_y)
    drawQuadGfxScaled(self, cursor.image, cursor.touchQuads[2], xPosition + 12, (11 - (engine.cur_row)) * panelWidth + engine.displacement - shake, 0, scale_x, scale_y)
  else
    drawGfxScaled(self, cursor.image, xPosition, (11 - (engine.cur_row)) * panelWidth + engine.displacement - shake, 0, scale_x, scale_y)
  end
end

local function shouldFlashForFrame(frame)
  local flashFrames = 1
  flashFrames = 2 -- add config
  return frame % (flashFrames * 2) < flashFrames
end

---@param bottomRightPanel Panel the bottom right panel of the garbage block we want to draw
---@param drawX integer the position of the bottom left panel
---@param drawY integer the position of the bottom left panel
---@param garbageImages table<string, love.Texture> the garbage images to use
function PanelBoardElement:drawGarbageBlock(bottomRightPanel, drawX, drawY, garbageImages)
  local imgs = garbageImages
  local panel = bottomRightPanel
  local panelSize = 16
  local halfPanelSize = panelSize / 2
  local garbageHeight, garbageWidth = panel.height, panel.width
  local leftX = drawX - (garbageWidth - 1) * panelSize
  local topY = drawY - (garbageHeight - 1) * panelSize
  local cornerWidth = halfPanelSize
  local cornerHeight = 3
  local useFiller1 = ((garbageHeight - (garbageHeight % 2)) / 2) % 2 == 0
  local filler_w, filler_h = imgs.filler1:getDimensions()
  for i = 0, garbageHeight - 1 do
    for j = 0, garbageWidth - 2 do
      local filler
      if (useFiller1 or garbageHeight < 3) then
        filler = imgs.filler1
      else
        filler = imgs.filler2
      end
      drawGfxScaled(self, filler, drawX - panelSize * j - halfPanelSize, topY + panelSize * i, 0, panelSize / filler_w, panelSize / filler_h)
      useFiller1 = not useFiller1
    end
  end
  if garbageHeight % 2 == 1 then
    local face
    if imgs.face2 and garbageWidth % 2 == 1 then
      face = imgs.face2
    else
      face = imgs.face
    end
    local face_w, face_h = face:getDimensions()
    drawGfxScaled(self, face, drawX - halfPanelSize * (garbageWidth - 1), topY + panelSize * ((garbageHeight - 1) / 2), 0, panelSize / face_w, panelSize / face_h)
  else
    local face_w, face_h = imgs.doubleface:getDimensions()
    drawGfxScaled(self, imgs.doubleface, drawX - halfPanelSize * (garbageWidth - 1), topY + panelSize * ((garbageHeight - 2) / 2), 0, panelSize / face_w, 32 / face_h)
  end
  local corner_w, corner_h = imgs.topleft:getDimensions()
  local lr_w, lr_h = imgs.left:getDimensions()
  local topbottom_w, topbottom_h = imgs.top:getDimensions()
  drawGfxScaled(self, imgs.left, leftX, topY + cornerHeight, 0, halfPanelSize / lr_w, (1 / lr_h) * (garbageHeight * panelSize - (cornerHeight*2)))
  drawGfxScaled(self, imgs.right, drawX + halfPanelSize, topY + cornerHeight, 0, halfPanelSize / lr_w, (1 / lr_h) * (garbageHeight * panelSize - (cornerHeight*2)))
  drawGfxScaled(self, imgs.top, leftX + cornerWidth, topY, 0, (1 / topbottom_w) * (garbageWidth * panelSize - (cornerWidth*2)), 2 / topbottom_h)
  drawGfxScaled(self, imgs.bot, leftX + cornerWidth, drawY + panelSize - 2, 0, (1 / topbottom_w) * (garbageWidth * panelSize - (cornerWidth*2)), 2 / topbottom_h)
  drawGfxScaled(self, imgs.topleft, leftX, topY, 0, cornerWidth / corner_w, cornerHeight / corner_h)
  drawGfxScaled(self, imgs.topright, drawX + halfPanelSize, topY, 0, cornerWidth / corner_w, cornerHeight / corner_h)
  drawGfxScaled(self, imgs.botleft, leftX, drawY + panelSize - 3, 0, cornerWidth / corner_w, cornerHeight / corner_h)
  drawGfxScaled(self, imgs.botright, drawX + halfPanelSize, drawY + panelSize - 3, 0, cornerWidth / corner_w, cornerHeight / corner_h)
end

function PanelBoardElement:drawPanels(garbageImages, shockGarbageImages, shakeOffset)
  local panelSet = self.panelSet
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
                panelSet:addToDraw(panel, draw_x, draw_y, self.scale, self.danger_col, self.danger_timer, self.engine.stop_time)
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
          panelSet:addToDraw(panel, draw_x, draw_y, self.scale, self.danger_col, self.danger_timer, self.engine.stop_time)
        end
      end
    end
  end

  panelSet:drawBatch()
end

return PanelBoardElement