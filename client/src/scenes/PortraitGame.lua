local GameBase = require("client.src.scenes.GameBase")
local class = require("common.lib.class")
local consts = require("common.engine.consts")
local Telegraph = require("client.src.graphics.Telegraph")
local GameModes = require("common.data.GameModes")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local ui = require("client.src.ui")
local input = require("client.src.inputManager")
local system = require("client.src.system")
local DebugSettings = require("client.src.debug.DebugSettings")
local TeamUtils = require("common.data.TeamUtils")

local PortraitGame = class(function(self, sceneParams)

local teamLetter = TeamUtils.teamLetter
local isFFA = TeamUtils.isFFA

local function buildTeamResultText(match, winners)
  local teams = {}
  local winnerTeams = {}
  local maxTeamIndex = 0

  for index, player in ipairs(match.players) do
    local teamIndex = TeamUtils.teamIndexForPlayer(match, player, index)
    if teamIndex then
      teams[teamIndex] = teams[teamIndex] or {}
      teams[teamIndex][#teams[teamIndex] + 1] = player.name
      if teamIndex > maxTeamIndex then maxTeamIndex = teamIndex end
    end
  end

  for _, winner in ipairs(winners) do
    for index, player in ipairs(match.players) do
      if player == winner then
        local teamIndex = TeamUtils.teamIndexForPlayer(match, player, index)
        if teamIndex then
          winnerTeams[teamIndex] = true
        end
        break
      end
    end
  end

  local winnerTeamIndex = nil
  local winnerTeamCount = 0
  for teamIndex, _ in pairs(winnerTeams) do
    winnerTeamIndex = teamIndex
    winnerTeamCount = winnerTeamCount + 1
  end

  local rosterParts = {}
  for i = 1, maxTeamIndex do
    local names = teams[i] and table.concat(teams[i], ", ") or "-"
    rosterParts[#rosterParts + 1] = "Team " .. teamLetter(i) .. ": " .. names
  end
  local roster = table.concat(rosterParts, " | ")

  if winnerTeamCount == 1 and winnerTeamIndex then
    return "Team " .. teamLetter(winnerTeamIndex) .. " wins | " .. roster
  end

  return "Draw | " .. roster
end
end,
GameBase)

PortraitGame.name = "PortraitGame"

---@param match ClientMatch
local function getTimer(match)
  local frames = 0
  local stack = match.stacks[1]
  if stack ~= nil and stack.engine.stopWatch ~= nil and tonumber(stack.engine.stopWatch) ~= nil then
    frames = stack.engine.stopWatch
  end

  if match.engine.timeLimit then
    frames = (match.engine.timeLimit * 60) - frames
    if frames < 0 then
      frames = 0
    end
  end

  return frames_to_time_string(frames, match.engine.ended)
end

function PortraitGame:customLoad()
  self.uiRoot.width = consts.CANVAS_HEIGHT
  self.uiRoot.height = consts.CANVAS_WIDTH

  local communityMessage = ui.Label({
    text = "join_community",
    replacements = {"\ndiscord." .. consts.SERVER_LOCATION},
    translate = true,
    hAlign = "center",
    vAlign = "top",
    y = 10,
  })
  self.uiRoot.communityMessage = communityMessage
  self.uiRoot:addChild(self.uiRoot.communityMessage)

  local timerScale = themes[config.theme].time_Scale
  self.uiRoot.timer = ui.PixelFontLabel({
    text = getTimer(self.match),
    fontMap = themes[config.theme].fontMaps.time,
    hAlign = "center",
    y = 60,
    xScale = timerScale,
    yScale = timerScale,
  })
  self.uiRoot:addChild(self.uiRoot.timer)

  self:flipToPortrait()
end

function PortraitGame:drawBar(stack, image, quad, themePositionOffset, height, yOffset, rotate, scale)
  local imageWidth, imageHeight = image:getDimensions()
  local barYScale = height / imageHeight
  local quadY = 0
  if barYScale < 1 then
    barYScale = 1
    quadY = imageHeight - height
  end
  local x = (stack.frameOriginX + stack.panelOriginXOffset + themePositionOffset[1] / 3) * stack.gfxScale
  local y = (stack.panelOriginY + themePositionOffset[2] / 3) * stack.gfxScale
  quad:setViewport(0, quadY, imageWidth, imageHeight - quadY)
  GraphicsUtil.drawQuad(image, quad, x, y - height - yOffset, rotate, scale * stack.gfxScale / 3, scale * barYScale, 0, 0, 1)
end

-- when using the stack function, the multibar ends up somewhere
-- so just force absolute multibar with a somewhat fixed draw
---@param stack PlayerStack
function PortraitGame:drawMultibar(stack)
  local stop_time = stack.engine.stop_time
  local shake_time = stack.engine.shake_time

  framePos = framePos or themes[config.theme].healthbar_frame_Pos
  barPos = barPos or themes[config.theme].multibar_Pos
  overtimePos = overtimePos or themes[config.theme].multibar_LeftoverTime_Pos

  local scale = themes[config.theme].healthbar_frame_Scale * (stack.gfxScale / 3)

  GraphicsUtil.draw(stack.assets.multibar.frameAbsolute,
                    math.floor((stack.frameOriginX + stack.panelOriginXOffset + framePos[1] / 3) * stack.gfxScale),
                    stack.frameOriginY * stack.gfxScale,
                    0,
                    scale,
                    scale)

  local multiBarFrameCount = stack.multiBarFrameCount
  local multiBarMaxHeight = 589 * (stack.gfxScale / 3) * themes[config.theme].multibar_Scale
  local bottomOffset = 0

  scale = themes[config.theme].multibar_Scale
  local healthHeight = (stack.engine.health / multiBarFrameCount) * multiBarMaxHeight
  self:drawBar(stack, stack.assets.multibar.health, stack.healthQuad, barPos, healthHeight, 0, 0, scale)

  bottomOffset = healthHeight

  local stopHeight = 0
  local preStopHeight = 0

  if shake_time > 0 and shake_time > (stop_time + stack.engine.pre_stop_time) then
    -- shake is only drawn if it is greater than prestop + stop
    -- shake is always guaranteed to fit
    local shakeHeight = (shake_time / multiBarFrameCount) * multiBarMaxHeight
    self:drawBar(stack, stack.assets.multibar.shake, stack.multi_shakeQuad, barPos, shakeHeight, bottomOffset, 0, scale)
  else
    -- stop/prestop are only drawn if greater than shake
    if stop_time > 0 then
      stopHeight = math.min(stop_time, multiBarFrameCount - stack.engine.health) / multiBarFrameCount * multiBarMaxHeight
      self:drawBar(stack, stack.assets.multibar.stop, stack.multi_stopQuad, barPos, stopHeight, bottomOffset, 0, scale)

      bottomOffset = bottomOffset + stopHeight
    end
    if stack.engine.pre_stop_time and stack.engine.pre_stop_time > 0 then
      local totalInvincibility = stack.engine.health + stack.engine.stop_time + stack.engine.pre_stop_time
      local remainingSeconds = 0
      if totalInvincibility > multiBarFrameCount then
        -- total invincibility exceeds what the multibar can display -> fill only the remaining space with prestop
        preStopHeight = (1 - (stack.engine.health + stop_time) / multiBarFrameCount) * multiBarMaxHeight
        remainingSeconds = (totalInvincibility - multiBarFrameCount) / 60
      else
        preStopHeight = stack.engine.pre_stop_time / multiBarFrameCount * multiBarMaxHeight
      end

      self:drawBar(stack, stack.assets.multibar.preStop, stack.multi_prestopQuad, barPos, preStopHeight, bottomOffset, 0, scale)

      if remainingSeconds > 0 then
        local formattedSeconds = string.format("%." .. themes[config.theme].multibar_LeftoverTime_Decimals .. "f", remainingSeconds)
        local x = math.floor((stack.frameOriginX + stack.panelOriginXOffset + overtimePos[1] / 3) * stack.gfxScale)
        local y = stack.panelOriginY * stack.gfxScale

        local limit = GAME.globalCanvas:getWidth() - x
        local alignment = "right"
        limit = x - GraphicsUtil.getGlobalFont():getWidth(formattedSeconds) / 2
        x = 0
        local fontDelta = 20 - GraphicsUtil.fontSize

        GraphicsUtil.printf(formattedSeconds, x, y, limit, alignment, nil, nil, fontDelta)
      end
    end
  end
end

function PortraitGame:draw()
  if self.backgroundImage then
    self.backgroundImage:draw()
  end
  if not self.match.isPaused or self.match.renderDuringPause then
    for _, stack in ipairs(self.match.stacks) do
      if stack.player then
        -- don't render stacks that only have an attack engine
        stack:render()
        if stack.engine.is_local and stack.player.human and stack.inputMethod == "touch" then
          self:drawMultibar(stack)
        end
      end

      if stack.garbageTargets and #stack.garbageTargets > 0 then
        for _, target in ipairs(stack.garbageTargets) do
          Telegraph:render(stack, target)
        end
      elseif stack.garbageTarget then
        Telegraph:render(stack, stack.garbageTarget)
      end
    end
  end

  if self.match.ended then
    local winners = self.match:getWinners()
    local pos = themes[config.theme].gameover_text_Pos
    local message
    if isFFA(self.match.gameMode) then
      if self.match:hasLocalPlayer() then
        local localWon = false
        for _, winner in ipairs(winners) do
          if winner.isLocal then
            localWon = true
            break
          end
        end
        if localWon then
          message = loc("pl_you_win")
        elseif #winners > 0 then
          message = loc("pl_you_lose")
        else
          message = loc("ss_draw")
        end
      elseif #winners == 1 then
        message = loc("ss_p_wins", winners[1].name)
      else
        message = loc("ss_draw")
      end
    elseif self.match.gameMode and self.match.gameMode.stackInteraction == GameModes.StackInteractions.TEAM_VERSUS then
      message = buildTeamResultText(self.match, winners)
    elseif #winners == 1 then
      message = loc("ss_p_wins", winners[1].name)
    else
      message = loc("ss_draw")
    end
    GraphicsUtil.printf(message, pos.x, pos.y, consts.CANVAS_WIDTH, "center")
  end

  if self.match.isPaused then
    self.match:draw_pause()
  end
  self.uiRoot:draw()
end

function PortraitGame:flipToPortrait()
  -- recreate the global canvas in portrait dimensions
  GAME.globalCanvas = love.graphics.newCanvas(consts.CANVAS_HEIGHT, consts.CANVAS_WIDTH, {dpiscale=GAME:newCanvasSnappedScale()})

  local width, height, _ = love.window.getMode()
  if system.isMobileOS() or DebugSettings.simulateMobileOS() then
    -- flip the window dimensions to portrait
    love.window.updateMode(height, width, {})
    love.window.setFullscreen(true)
    --GAME:updateCanvasPositionAndScale(width, height)
  end

  for _, player in ipairs(self.match.players) do
    if player.isLocal and player.human and player.settings.inputMethod == "touch" then
      -- modify the stack to use a higher gfxScale instead of the usual 3
      local stack = player.stack
      stack.gfxScale = 5
      -- force center it horizontally
      local frameX = (GAME.globalCanvas:getWidth() / 2 - stack:canvasWidth() / 2)
      -- and anchor at the bottom
      local frameY = (GAME.globalCanvas:getHeight() - stack:canvasHeight())
      stack:moveToPosition(frameX, frameY)

      -- create a raise button that interacts with the touch controller
      local raiseButton = ui.TextButton({label = ui.Label({text = "raise", fontSize = 20}), hAlign = "right", vAlign = "bottom", height = player.stack:canvasHeight() / 2})
      ---@diagnostic disable-next-line: duplicate-set-field
      raiseButton.onTouch = function(button, x, y)
        button.backgroundColor[4] = 1
        stack.touchInputDetector.touchingRaise = true
      end
      raiseButton.onDrag = function(button, x, y)
        stack.touchInputDetector.touchingRaise = button:inBounds(x, y)
      end
      ---@diagnostic disable-next-line: duplicate-set-field
      raiseButton.onRelease = function(button, x, y, timeHeld)
        button.backgroundColor[4] = 0.7
        stack.touchInputDetector.touchingRaise = false
      end
      raiseButton.width = 70
      self.uiRoot.raiseButton = raiseButton
      self.uiRoot:addChild(raiseButton)
    else
      local stack = player.stack
      stack.gfxScale = 1
      stack.canvas = true
      local frameX = (GAME.globalCanvas:getWidth() - stack:canvasWidth()) - 12
      local frameY = 10
      stack:moveToPosition(frameX, frameY)
    end
  end
end

function PortraitGame:returnToLandscape()
  -- recreate the global canvas in landscape dimensions
  GAME.globalCanvas = love.graphics.newCanvas(consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT, {dpiscale=GAME:newCanvasSnappedScale()})
  -- flip the window dimensions to landscape
  local width, height, _ = love.window.getMode()
  if system.isMobileOS() or DebugSettings.simulateMobileOS() then
    love.window.updateMode(height, width, {})
    love.window.setFullscreen(false)
    --GAME:updateCanvasPositionAndScale(width, height)
  end
  for _, player in ipairs(self.match.players) do
    if player.isLocal and player.human and player.settings.inputMethod == "touch" then
      player.stack.gfxScale = 3
    end
  end
end

function PortraitGame:customRun()
  self.uiRoot.timer:setText(getTimer(self.match))
end

function PortraitGame:startNextScene()
  self:returnToLandscape()
  GAME.navigationStack:pop()
end

return PortraitGame