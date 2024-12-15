local class = require("common.lib.class")
local ClientStack = require("client.src.ClientStack")
local SimulatedStack = require("common.engine.SimulatedStack")
local GraphicsUtil = require("client.src.graphics.graphics_util")

local ChallengeModePlayerStack = class(
function(self, args)
  self.engine = SimulatedStack(args)

  self.multiBarFrameCount = 240
  -- needed for sending shock garbage
  self.panels_dir = config.panels

  self.difficultyQuads = {}

  self.stackHeightQuad = GraphicsUtil:newRecycledQuad(0, 0, themes[config.theme].images.IMG_multibar_shake_bar:getWidth(),
                                                      themes[config.theme].images.IMG_multibar_shake_bar:getHeight(),
                                                      themes[config.theme].images.IMG_multibar_shake_bar:getWidth(),
                                                      themes[config.theme].images.IMG_multibar_shake_bar:getHeight())

  -- somehow bad things happen if this is called in the base class constructor instead
  self:moveForRenderIndex(self.which)
end,
ClientStack)

function ChallengeModePlayerStack:render()
  self:setDrawArea()
  self:drawCharacter()
  self:renderStackHeight()
  self:drawFrame()
  self:drawWall(0, 12)
  self:resetDrawArea()

  self:drawDebug()
end

function ChallengeModePlayerStack:renderStackHeight()
  local percentage = self.healthEngine:getTopOutPercentage()
  local xScale = (self:canvasWidth() - 8) / themes[config.theme].images.IMG_multibar_shake_bar:getWidth()
  local yScale = (self:canvasHeight() - 4) / themes[config.theme].images.IMG_multibar_shake_bar:getHeight() * percentage

  GraphicsUtil.setColor(1, 1, 1, 0.6)
  GraphicsUtil.drawQuad(themes[config.theme].images.IMG_multibar_shake_bar, self.stackHeightQuad, 4, self:canvasHeight(), 0, xScale,
                     -yScale)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

function ChallengeModePlayerStack:setGarbageTarget(garbageTarget)
  if garbageTarget ~= nil then
    assert(garbageTarget.frameOriginX ~= nil)
    assert(garbageTarget.frameOriginY ~= nil)
    assert(garbageTarget.mirror_x ~= nil)
    assert(garbageTarget.canvasWidth ~= nil)
    assert(garbageTarget.incomingGarbage ~= nil)
  end
  self.garbageTarget = garbageTarget
  if self.attackEngine then
    self.attackEngine:setGarbageTarget(garbageTarget)
  end
end

function ChallengeModePlayerStack:drawScore()
  -- no fake score for simulated stacks yet
  -- could be fun for fake 1p time attack vs later on, lol
end

function ChallengeModePlayerStack:drawSpeed()
  if self.healthEngine then
    self:drawLabel(themes[config.theme].images["IMG_speed_" .. self.which .. "P"], themes[config.theme].speedLabel_Pos,
                   themes[config.theme].speedLabel_Scale)
    self:drawNumber(self.healthEngine.currentRiseSpeed, themes[config.theme].speed_Pos, themes[config.theme].speed_Scale)
  end
end

-- rating is substituted for challenge mode difficulty here
function ChallengeModePlayerStack:drawRating()
  if self.player.settings.difficulty then
    self:drawLabel(themes[config.theme].images["IMG_rating_" .. self.which .. "P"], themes[config.theme].ratingLabel_Pos,
                   themes[config.theme].ratingLabel_Scale, true)
    self:drawNumber(self.player.settings.difficulty, themes[config.theme].rating_Pos,
                    themes[config.theme].rating_Scale)
  end
end

function ChallengeModePlayerStack:drawLevel()
  -- no level
  -- thought about drawing stage number here but it would be
  -- a) redundant with human player win count
  -- b) not offset nicely because level is an image, not a number
end

function ChallengeModePlayerStack:drawMultibar()
  if self.health then
    self:drawAbsoluteMultibar(0, 0, 0)
  end
end

function ChallengeModePlayerStack:drawDebug()
  if config.debug_mode then
    local drawX = self.frameOriginX + self:canvasWidth() / 2
    local drawY = 10
    local padding = 14

    GraphicsUtil.drawRectangle("fill", drawX - 5, drawY - 5, 1000, 100, 0, 0, 0, 0.5)
    GraphicsUtil.printf("Clock " .. self.clock, drawX, drawY)

    drawY = drawY + padding
    GraphicsUtil.printf("P" .. self.which .. " Ended?: " .. tostring(self:game_ended()), drawX, drawY)
  end
end

-- in the long run we should have all quads organized in a Stack.quads table
-- that way deinit could be implemented generically in StackBase
function ChallengeModePlayerStack:deinit()
  self.healthQuad:release()
  self.stackHeightQuad:release()
  for _, quad in ipairs(self.difficultyQuads) do
    GraphicsUtil:releaseQuad(quad)
  end
end

return ChallengeModePlayerStack