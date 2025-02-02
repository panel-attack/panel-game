local class = require("common.lib.class")
local ClientStack = require("client.src.ClientStack")
local SimulatedStack = require("common.engine.SimulatedStack")
local GraphicsUtil = require("client.src.graphics.graphics_util")

---@class ChallengeModePlayerStack : ClientStack
---@field engine SimulatedStack
---@field enableSfx boolean
---@field multiBarFrameCount integer
---@field sfxCombo integer
---@field sfxChain integer
---@field sfxMetal integer
---@field difficultyQuads love.Quad[]
---@field stackHeightQuad love.Quad
---@field player ChallengeModePlayer

---@class ChallengeModePlayerStack
---@overload fun(args: table): ChallengeModePlayerStack
local ChallengeModePlayerStack = class(
function(self, args)
  self.engine = SimulatedStack(args)
  self.engine.outgoingGarbage:connectSignal("garbagePushed", self, self.onGarbagePushed)
  self.engine.outgoingGarbage:connectSignal("newChainLink", self, self.onNewChainLink)
  self.engine.outgoingGarbage:connectSignal("chainEnded", self, self.onChainEnded)
  self.engine:connectSignal("finishedRun", self, self.onRun)

  -- queue limit is set for automated attack settings e.g. combo storm that send garbage every frame
  -- that can cause an annoying buzzing sound depending on the delay of the SFX which we don't want
  -- so only play SFX for attack settings from replays or ones that had the queue limit manually disabled
  self.enableSfx = self.engine.attackEngine.disableQueueLimit

  self.multiBarFrameCount = 240

  self.sfxCombo = 0
  self.sfxChain = 0
  self.sfxMetal = 0

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
  self.sfxCombo = garbage.width + 1
  if self.sfxChain == 0 then
    self.sfxChain = garbage.height + 1
  end

  if garbage.isMetal then
    if self.sfxMetal == 0 then
      self.sfxMetal = 3
    else
      self.sfxMetal = self.sfxMetal + 1
    end
  end
end

function ChallengeModePlayerStack:onNewChainLink(chainGarbage)
  self.sfxChain = #chainGarbage.linkTimes + 1
end

function ChallengeModePlayerStack:onChainEnded(chainGarbage)
  if self:canPlaySfx() then
    local sfxFanfare = #chainGarbage.linkTimes + 1
    if sfxFanfare == 0 then
      --do nothing
    elseif sfxFanfare >= 6 then
      SoundController:playSfx(themes[config.theme].sounds.fanfare3)
    elseif sfxFanfare >= 5 then
      SoundController:playSfx(themes[config.theme].sounds.fanfare2)
    elseif sfxFanfare >= 4 then
      SoundController:playSfx(themes[config.theme].sounds.fanfare1)
    end
  end
end

function ChallengeModePlayerStack:onRun()
  if self:canPlaySfx() then
    local newComboChainInfo = self.attackSoundInfoForMatch(self.sfxChain > 0, self.sfxChain, self.sfxCombo, self.sfxMetal)
    if newComboChainInfo then
      self.character:playAttackSfx(newComboChainInfo)
    end
  end

  self.sfxCombo = 0
  self.sfxChain = 0
  self.sfxMetal = 0

  if self.engine.healthEngine then
    if self.danger_music then
      if self.engine.healthEngine.currentLines < self.engine.healthEngine.height then
        self.danger_music = false
        self:emitSignal("dangerMusicChanged", self)
      end
    else
      if self.engine.healthEngine.currentLines > self.engine.healthEngine.height then
        self.danger_music = true
        self:emitSignal("dangerMusicChanged", self)
      end
    end
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
  local percentage = self.engine.healthEngine:getTopOutPercentage()
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
  if self.engine.healthEngine then
    self:drawLabel(themes[config.theme].images["IMG_speed_" .. self.which .. "P"], themes[config.theme].speedLabel_Pos,
                   themes[config.theme].speedLabel_Scale)
    self:drawNumber(self.engine.healthEngine.currentRiseSpeed, themes[config.theme].speed_Pos, themes[config.theme].speed_Scale)
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
  if self.engine.healthEngine then
    self:drawAbsoluteMultibar(0, 0, 0)
  end
end

function ChallengeModePlayerStack:drawDebug()
  if config.debug_mode then
    local drawX = self.frameOriginX + self:canvasWidth() / 2
    local drawY = 10
    local padding = 14

    GraphicsUtil.drawRectangle("fill", drawX - 5, drawY - 5, 1000, 100, 0, 0, 0, 0.5)
    GraphicsUtil.printf("Clock " .. self.engine.clock, drawX, drawY)

    drawY = drawY + padding
    GraphicsUtil.printf("P" .. self.which .. " Ended?: " .. tostring(self.engine:game_ended()), drawX, drawY)
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