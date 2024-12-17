local class = require("common.lib.class")
local ClientStack = require("client.src.ClientStack")
local SimulatedStack = require("common.engine.SimulatedStack")
local GraphicsUtil = require("client.src.graphics.graphics_util")

local ChallengeModePlayerStack = class(
function(self, args)
  self.engine = SimulatedStack(args)
  self.engine.outgoingGarbage:connectSignal("garbagePushed", self, self.onGarbagePushed)
  self.engine.outgoingGarbage:connectSignal("newChainLink", self, self.onNewChainLink)
  self.engine.outgoingGarbage:connectSignal("chainEnded", self, self.onChainEnded)

  self.enableSfx = not self.engine.attackEngine.disableQueueLimit

  self.multiBarFrameCount = 240
  -- needed for sending shock garbage
  self.panels_dir = config.panels
  self.sfxFanfare = 0

  self.difficultyQuads = {}

  self.stackHeightQuad = GraphicsUtil:newRecycledQuad(0, 0, themes[config.theme].images.IMG_multibar_shake_bar:getWidth(),
                                                      themes[config.theme].images.IMG_multibar_shake_bar:getHeight(),
                                                      themes[config.theme].images.IMG_multibar_shake_bar:getWidth(),
                                                      themes[config.theme].images.IMG_multibar_shake_bar:getHeight())

  -- somehow bad things happen if this is called in the base class constructor instead
  self:moveForRenderIndex(self.which)
end,
ClientStack)

function ChallengeModePlayerStack:onGarbagePushed(garbage)
  -- TODO: Handle combos SFX greather than 7
  local maxCombo = garbage.width + 1
  local chainCounter = garbage.height + 1
  local metalCount = 0
  if garbage.isMetal then
    metalCount = 3
  end
  local newComboChainInfo = self.attackSoundInfoForMatch(chainCounter > 0, chainCounter, maxCombo, metalCount)
  if newComboChainInfo and self:canPlaySfx() then
      -- TODO:
      -- Instead of playing the SFX directly, cache it on the stack
      --   then decide what to play in onRun based on all the garbage we got this frame
    self.character:playAttackSfx(newComboChainInfo)
  end
end

function ChallengeModePlayerStack:onNewChainLink(chainGarbage)
  local chainCounter = #chainGarbage.linkTimes + 1
  local newComboChainInfo = self.attackSoundInfoForMatch(true, chainCounter, 3, 0)
  if newComboChainInfo and self:canPlaySfx() then
    -- TODO:
    -- Instead of playing the SFX directly, cache it on the stack
    --   then decide what to play in onRun based on all the garbage we got this frame
    self.character:playAttackSfx(newComboChainInfo)
  end
end

function ChallengeModePlayerStack:onChainEnded(chainGarbage)
  if self:canPlaySfx() then
    self.sfxFanfare = #chainGarbage.linkTimes + 1
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
  end
end

function ChallengeModePlayerStack:canPlaySfx()
   -- If we are still catching up from rollback don't play sounds again
   if self.engine:behindRollback() then
    return false
  end

  -- this is catchup mode, don't play sfx during this
  if self.engine.play_to_end then
    return false
  end

  if not self.character or not self.enableSfx then
    return false
  end

  return true
end

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
  end
  self.garbageTarget = garbageTarget
  if self.engine.attackEngine then
    -- the target needs to match the settings about shock garbage being sorted with 
    self.engine.attackEngine:setGarbageTarget(garbageTarget)
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

function ChallengeModePlayerStack:runGameOver()
end

return ChallengeModePlayerStack