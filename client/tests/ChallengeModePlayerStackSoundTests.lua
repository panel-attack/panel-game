local ChallengeModePlayerStack = require("client.src.ChallengeModePlayerStack")
local AttackEngine = require("common.engine.AttackEngine")
local GarbageQueue = require("common.engine.GarbageQueue")
local consts = require("common.engine.consts")

-- Runs a challenge stack whose attack engine sends the attack patterns for frameCount frames,
-- returning the attack sound the character played on each frame, keyed by the frame
---@param attackPatterns table[]
---@param frameCount integer
---@return table<integer, {type: integer, size: integer}>
local function attackSoundsByFrame(attackPatterns, frameCount)
  local attackSettings = {countdownAdjusted = true, delayBeforeRepeat = 1000, disableQueueLimit = true, attackPatterns = attackPatterns}
  local attackEngine = AttackEngine(attackSettings, GarbageQueue())
  local attackSounds = {}
  local stack = setmetatable({
    engine = {attackEngine = attackEngine},
    character = {playAttackSfx = function(_, attack) attackSounds[attackEngine.stopWatch - 1] = attack end},
    canPlaySfx = function() return true end,
  }, {__index = ChallengeModePlayerStack})
  attackEngine:connectSignal("attackSent", stack, stack.queueAttackSoundEffect)

  for _ = 0, frameCount do
    attackEngine:run()
    stack:onRun()
  end
  return attackSounds
end

local function combo(width, startTime)
  return {width = width, height = 1, startTime = startTime, chain = false, metal = false}
end

---@param sound {type: integer, size: integer}?
---@param typeName string
---@param size integer
local function assertSound(sound, typeName, size)
  assert(sound, "no attack sound played")
  assert(sound.type == consts.ATTACK_TYPE[typeName] and sound.size == size,
         "expected " .. typeName .. " " .. size .. " but played type " .. sound.type .. " size " .. sound.size)
end

local function aComboPlaysItsComboSound()
  assertSound(attackSoundsByFrame({combo(3, 5)}, 5)[5], "combo", 4)
end

local function aComboOverSevenPlaysItsComboSound()
  assertSound(attackSoundsByFrame({combo(3, 5), combo(4, 5)}, 5)[5], "combo", 8)
end

local function eachChainLinkPlaysItsChainSound()
  local sounds = attackSoundsByFrame({{chain = {5, 10}, chainEndTime = 20}}, 20)
  assertSound(sounds[5], "chain", 2)
  assertSound(sounds[10], "chain", 3)
end

local function aComboOnAChainLinkPlaysTheChainSound()
  assertSound(attackSoundsByFrame({{chain = {5, 10}, chainEndTime = 20}, combo(3, 10)}, 20)[10], "chain", 3)
end

local function aShockPlaysTheShockSoundOverItsCombo()
  local metal = {width = 6, height = 1, startTime = 5, chain = false, metal = true}
  assertSound(attackSoundsByFrame({metal, combo(3, 5)}, 5)[5], "shock", 3)
end

aComboPlaysItsComboSound()
aComboOverSevenPlaysItsComboSound()
eachChainLinkPlaysItsChainSound()
aComboOnAChainLinkPlaysTheChainSound()
aShockPlaysTheShockSoundOverItsCombo()
