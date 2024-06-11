local class = require("common.lib.class")
local logger = require("common.lib.logger")
-- TODO: move graphics related functionality to client
local GraphicsUtil = require("client.src.graphics.graphics_util")

local TELEGRAPH_HEIGHT = 16
local TELEGRAPH_PADDING = 2 --vertical space between telegraph and stack
local TELEGRAPH_BLOCK_WIDTH = 26

-- Sender is the sender of these attacks, must implement clock, frameOriginX, frameOriginY, and character
Telegraph = class(function(self, sender)

  -- A sender can be anything that
  self.sender = sender
  -- has some coordinates to originate the attack animation from
  assert(sender.frameOriginX ~= nil, "telegraph sender invalid")
  assert(sender.frameOriginY ~= nil, "telegraph sender invalid")
  -- has a clock to figure out how far the attacks should have animated relative to when it was sent
  -- (and also that non-cheating senders can only send attacks on the frame they're on)
  assert(sender.clock ~= nil, "telegraph sender invalid")
  -- has a character to source the telegraph images above the stack from
  assert(sender.character ~= nil, "telegraph sender invalid")
  -- has a panel origin to realistically offset coordinates
  assert(sender.panelOriginX ~= nil, "telegraph sender invalid")
  assert(sender.panelOriginY ~= nil, "telegraph sender invalid")
end)

--The telegraph_attack_animation below refers the little loop shape attacks make before they start traveling toward the target.
local telegraph_attack_animation_speed = {
    4,4,4,4,4,2,2,2,2,1,
    1,1,1,.5,.5,.5,.5,1,1,1,
    1,2,2,2,2,4,4,4,4,8}

--the following are angles out of 64, 0 being right, 32 being left, 16 being down, and 48 being up.
local telegraph_attack_animation_angles = {}
--[1] for attacks where the destination is right of the origin

telegraph_attack_animation_angles[1] = {}
for i=24,24+#telegraph_attack_animation_speed-1 do
  telegraph_attack_animation_angles[1][#telegraph_attack_animation_angles[1]+1] = i%64
end
--[-1] for attacks where the destination is left of the origin
telegraph_attack_animation_angles[-1] = {}
local leftward_animation_angle = 8
while #telegraph_attack_animation_angles[-1] <= #telegraph_attack_animation_speed do
  telegraph_attack_animation_angles[-1][#telegraph_attack_animation_angles[-1]+1] = leftward_animation_angle
  leftward_animation_angle = leftward_animation_angle - 1
  if leftward_animation_angle < 0 then
    leftward_animation_angle = 64
  end
end

local telegraph_attack_animation = {}
telegraph_attack_animation[1] = {}
local leftward_or_rightward = {-1, 1}
for k, animation in ipairs(leftward_or_rightward) do
  telegraph_attack_animation[animation] = {}
  for frame=1,#telegraph_attack_animation_speed do
    local distance = telegraph_attack_animation_speed[frame]
    local angle = telegraph_attack_animation_angles[animation][frame]/64

                --[[ use trigonometry to find the change in x and the change in y, given the hypotenuse (telegraph_attack_animation_speed) and the angle we should be traveling (2*math.pi*telegraph_attack_animation_angles[left_or_right][frame]/64)
                
                I think:              
                change in y will be hypotenuse*sin angle
                change in x will be hypotenuse*cos angle
                --]]

    telegraph_attack_animation[animation][frame] = {}
    telegraph_attack_animation[animation][frame].dx = distance * math.cos(angle*2*math.pi)
    telegraph_attack_animation[animation][frame].dy = distance * math.sin(angle*2*math.pi)
  end
end

function Telegraph:updatePositionForGarbageTarget(newGarbageTarget)
  self.stackCanvasWidth = newGarbageTarget:stackCanvasWidth()
  self.mirror_x = newGarbageTarget.mirror_x
  self.originX = newGarbageTarget.frameOriginX
  self.originY = newGarbageTarget.frameOriginY - TELEGRAPH_HEIGHT - TELEGRAPH_PADDING
  self.receiverGfxScale = newGarbageTarget.gfxScale
end

function Telegraph:telegraphRenderXPosition(index)

  local increment = -TELEGRAPH_BLOCK_WIDTH * self.mirror_x

  local result = self.originX
  if self.mirror_x == 1 then
    result = result + self.stackCanvasWidth / self.receiverGfxScale + increment
  end

  result = result + (increment * index)

  return result
end

function Telegraph:attackAnimationStartFrame()
  -- In games PA is inspired by the attack animation only happens after the card_animation
  -- In PA garbage is removed from telegraph early in order to afford the 1 second desync tolerance for online play
  -- to compensate, both attacks and telegraph are shown earlier so they are shown long enough and early enough
  -- their attacks being rendered immediately produces a decent compromise on visuals
  return 2
end

function Telegraph:attackAnimationEndFrame()
  return GARBAGE_TRANSIT_TIME + 1
end

Telegraph.totalTimeAfterLoopToDestination = (Telegraph:attackAnimationEndFrame() - (Telegraph:attackAnimationStartFrame() + #telegraph_attack_animation_speed))
-- TODO:
-- animation seems to start 1 frame early and the loopy part does not spin quite as far outwards it seems
function Telegraph:renderAttack(frameEarned, telegraphIndex, rowOrigin, colOrigin)
  local attackFrame = self.sender.clock - frameEarned
  if attackFrame < self:attackAnimationStartFrame() or attackFrame >= self:attackAnimationEndFrame() then
    return
  end

  local character = characters[self.sender.character]
  local width, height = character.telegraph_garbage_images["attack"]:getDimensions()
  local attackScale = self.receiverGfxScale * 16 / math.max(width, height) -- keep image ratio

  if self.sender.opacityForFrame then
    GraphicsUtil.setColor(1, 1, 1, self.sender:opacityForFrame(attackFrame, 1, 8))
  end

  local destinationX = self:telegraphRenderXPosition(telegraphIndex) + (TELEGRAPH_BLOCK_WIDTH / 2) - ((TELEGRAPH_BLOCK_WIDTH / 16) / 2)

  local attackX = (colOrigin - 1) * 16 + self.sender.panelOriginX
  local attackY = (11 - rowOrigin) * 16 + self.sender.panelOriginY + (self.sender.displacement or 0)
  -- -1 for left, 1 for right
  local horizontalDirection = math.sign(destinationX - attackX)

  -- We can't guarantee every frame was rendered, so we must calculate the exact location regardless of how many frames happened.
  -- TODO make this more performant?
  -- it should be very possible to just precalculate the values although I think performance here isn't truly problematic either way
  for frame = 1, math.min(attackFrame - self:attackAnimationStartFrame(), #telegraph_attack_animation_speed) do
    attackX = attackX + telegraph_attack_animation[horizontalDirection][frame].dx
    attackY = attackY + telegraph_attack_animation[horizontalDirection][frame].dy
  end

  -- at the start of an attack, the attack sprite makes a small half loop around its origin
  --  that is mostly independent of where the attack goes after (except for choosing the side around which to loop)
  if attackFrame <= #telegraph_attack_animation_speed + self:attackAnimationStartFrame() then
    -- if we aren't past the loopy part yet, draw directly
    -- TODO: tween the scale between sender and receiver scale
    GraphicsUtil.draw(character.telegraph_garbage_images["attack"], attackX * self.receiverGfxScale, attackY * self.receiverGfxScale, 0, attackScale, attackScale)
  else
    -- if we are, attackOriginX and attackOriginY are set to the end of the loopy animation now
    -- that means we have to calculate the distance to the desired garbage
    -- and then split up the remaining distance in equal steps across frames
    --
    -- Note that the destination can change after the attack animation started:
    -- According to my insight the destination only ever moves FURTHER AWAY
    -- in that event, the attack animation would skip slightly ahead in that moment; we don't do interpolation for that so far
    attackFrame = attackFrame - (self:attackAnimationStartFrame() + #telegraph_attack_animation_speed)
    local percent =  attackFrame / Telegraph.totalTimeAfterLoopToDestination

    -- fixed y location
    local destinationY = self.originY - TELEGRAPH_PADDING
    attackX = attackX + percent * (destinationX - attackX)
    attackY = attackY + percent * (destinationY - attackY)

    GraphicsUtil.draw(character.telegraph_garbage_images["attack"], attackX * self.receiverGfxScale, attackY * self.receiverGfxScale, 0, attackScale, attackScale)
  end

  GraphicsUtil.setColor(1, 1, 1, 1)
end

function Telegraph:renderAttacks()
  for i = #self.sender.outgoingGarbage.stagedGarbage, 1, -1 do
    local garbage = self.sender.outgoingGarbage.stagedGarbage[i]
    local drawIndex = math.abs(i - #self.sender.outgoingGarbage.stagedGarbage)
    if garbage.isChain then
      for frameEarned, location in pairs(garbage.links) do
        self:renderAttack(frameEarned, drawIndex, location.rowEarned, location.colEarned)
      end
    else
      self:renderAttack(garbage.frameEarned, drawIndex, garbage.rowEarned, garbage.colEarned)
    end
  end
end

local iconHeight = 16
local iconWidth = 24

function Telegraph:renderStageGarbageIcon(garbage, telegraphIndex)
  local character = characters[self.sender.character]
  local y = self.originY * self.receiverGfxScale
  local x = self:telegraphRenderXPosition(telegraphIndex) * self.receiverGfxScale
  local image
  if garbage.isChain then
    if config.renderAttacks then
      -- only display the icon for how many chain links the attack already finished
      local displayHeight = 0
      for frameEarned, _ in pairs(garbage.links) do
        if self.sender.clock - frameEarned > self:attackAnimationEndFrame() then
          displayHeight = displayHeight + 1
        end
      end
      if displayHeight == 0 then
        -- don't display anything if the attack for the first chain link is still underway
        return
      else
        image = character.telegraph_garbage_images[displayHeight][6]
      end
    else
      image = character.telegraph_garbage_images[garbage.height][6]
    end
  else
    if config.renderAttacks then
      if self.sender.clock - garbage.frameEarned < self:attackAnimationEndFrame() then
        -- if attacks are rendered, icon display is delayed until the attack animation finished
        return
      end
    end
    if garbage.isMetal then
    image = character.telegraph_garbage_images["metal"]
    else
      image = character.telegraph_garbage_images[1][garbage.width]
    end
  end

  local width, height = image:getDimensions()
  local xScale = iconWidth / width * self.receiverGfxScale
  local yScale = iconHeight / height * self.receiverGfxScale

  GraphicsUtil.draw(image, x, y, 0, xScale, yScale)
end

function Telegraph:renderStagedGarbageIcons()
  for i = #self.sender.outgoingGarbage.stagedGarbage, 1, -1 do
    local garbage = self.sender.outgoingGarbage.stagedGarbage[i]
    self:renderStageGarbageIcon(garbage, math.abs(i - #self.sender.outgoingGarbage.stagedGarbage))
  end
end

function Telegraph:render()
  if config.renderAttacks then
    self:renderAttacks()
  end

  if config.renderTelegraph then
    self:renderStagedGarbageIcons()
  end
end

return Telegraph