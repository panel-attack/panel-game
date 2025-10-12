local logger = require("common.lib.logger")
local class = require("common.lib.class")
local consts = require("common.engine.consts")

-- A pattern for sending garbage
---@class AttackPattern
---@field width integer
---@field height integer
---@field startTime integer
---@field endsChain boolean
---@field garbage Garbage
AttackPattern =
  class(
  function(self, width, height, startTime, metal, chain, endsChain)
    self.width = width
    self.height = height
    self.startTime = startTime
    self.endsChain = endsChain
    self.garbage = {width = width, height = height, isMetal = metal or false, isChain = chain}
  end
)

-- An attack engine sends attacks based on a set of rules.
---@class AttackEngine : canRollback
---@field delayBeforeStart integer How many frame the AttackEngine waits before running. \n
--- Note if this is changed after attack patterns are added their times won't be updated.
---@field delayBeforeRepeat integer How many frames the AttackEngine waits after a full run before starting over
---@field disableQueueLimit boolean Attack patterns that put out a crazy amount of garbage can slow down the game, so by default we don't queue more than 72 attacks \n
--- This flag can be optionally set to disable that.
---@field treatMetalAsCombo boolean whether the metal garbage is treated the same as combo garbage (aka they can mix)
---@field attackPatterns AttackPattern[] The array of AttackPattern objects this engine will run through.
---@field attackSettings table The format for serializing AttackPattern information
---@field stopwatch integer  The stopwatch to control the continuity of the sending process
---@field outgoingGarbage GarbageQueue The garbage queue attacks are added to
local AttackEngine = class(
  function(self, attackSettings, garbageQueue)
    self.delayBeforeStart = attackSettings.delayBeforeStart or 0
    if not attackSettings.countdownAdjusted then
      self.delayBeforeStart = self.delayBeforeStart - (consts.COUNTDOWN_START + consts.COUNTDOWN_LENGTH)
    end
    self.delayBeforeRepeat = attackSettings.delayBeforeRepeat or 0
    self.disableQueueLimit = attackSettings.disableQueueLimit or false

    -- mergeComboMetalQueue is a reference to an old implementation in which different garbage types
    --  were organised in different queues
    --  we're stuck with the name because it is found in serialized data
    self.treatMetalAsCombo = attackSettings.mergeComboMetalQueue or false

    self.attackPatterns = {}
    self:addAttackPatternsFromTable(attackSettings.attackPatterns)
    self.attackSettings = attackSettings

    self.stopwatch = 0

    self.outgoingGarbage = garbageQueue
    -- to ensure correct behaviour according to the pattern definition
    -- the garbage queue must be modified to match the attack settings
    self.outgoingGarbage.treatMetalAsCombo = self.treatMetalAsCombo
    self.outgoingGarbage.illegalStuffIsAllowed = true
  end
)

function AttackEngine:addAttackPatternsFromTable(attackPatternsTable)
  for _, values in ipairs(attackPatternsTable) do
    if values.chain then
      if type(values.chain) == "number" then
        for i = 1, values.height do
          self:addAttackPattern(6, i, values.startTime + ((i-1) * values.chain), false, true)
        end
        self:addEndChainPattern(values.startTime + ((values.height - 1) * values.chain) + values.chainEndDelta)
      elseif type(values.chain) == "table" then
        for i, chainTime in ipairs(values.chain) do
          self:addAttackPattern(6, i, chainTime, false, true)
        end
        self:addEndChainPattern(values.chainEndTime)
      else
        error("The 'chain' field in your attack file is invalid. It should either be a number or a list of numbers.")
      end
    else
      self:addAttackPattern(values.width, values.height or 1, values.startTime, values.metal or false, false)
    end
  end
end

-- Adds an attack pattern that happens repeatedly on a timer.
---@param width integer? the width of the garbage block in columns
---@param height integer? the height of the garbage block in rows
---@param start integer the stopwatch frame these attacks should start being sent
---@param metal boolean? if this is a metal block
---@param chain boolean? if this is a chain attack
function AttackEngine.addAttackPattern(self, width, height, start, metal, chain)
  assert(width ~= nil and height ~= nil and start ~= nil and metal ~= nil and chain ~= nil)
  local attackPattern = AttackPattern(width, height, self.delayBeforeStart + start, metal, chain, false)
  self.attackPatterns[#self.attackPatterns + 1] = attackPattern
end

---@param chainEnd integer the stopwatch frame the ongoing chain is being finalized
function AttackEngine.addEndChainPattern(self, chainEnd)
  local attackPattern = AttackPattern(0, 0, self.delayBeforeStart + chainEnd, false, false, true)
  self.attackPatterns[#self.attackPatterns + 1] = attackPattern
end

local garbageList = {}
function AttackEngine.run(self)
  table.clear(garbageList)

  local highestStartTime = self.attackPatterns[#self.attackPatterns].startTime

  -- Finds the greatest startTime value found from all the attackPatterns
  for i = 1, #self.attackPatterns do
    highestStartTime = math.max(self.attackPatterns[i].startTime, highestStartTime)
  end

  local totalAttackTimeBeforeRepeat = self.delayBeforeRepeat + highestStartTime - self.delayBeforeStart
  -- assumption is that only things like combo storm don't disable the queue limit
  -- as all garbage gets collected to a single timer thanks to the mechanic of the outgoing garbage queue having any value greater than 1 in the queue means
  --  that the recipient is stalling acceptance so we shouldn't push more inside
  if self.disableQueueLimit or self.outgoingGarbage.transitTimers:len() <= 6 then
    for i = 1, #self.attackPatterns do
      if self.stopwatch >= self.attackPatterns[i].startTime then
        local difference = self.stopwatch - self.attackPatterns[i].startTime
        local remainder = difference % totalAttackTimeBeforeRepeat
        if remainder == 0 then
          if self.attackPatterns[i].endsChain then
            if not self.outgoingGarbage.currentChain then
              break
            end
            self.outgoingGarbage:finalizeCurrentChain(self.stopwatch)
          else
            local garbage = self.attackPatterns[i].garbage
            if garbage.isChain then
              self.outgoingGarbage:addChainLink(self.stopwatch, math.random(1, 11), math.random(1, 6))
            else
              garbage.frameEarned = self.stopwatch
              -- we need a coordinate for the origin of the attack animation
              garbage.rowEarned = math.random(1, 11)
              garbage.colEarned = math.random(1, 6)
              maxCombo = garbage.width + 1
              -- if the attack engine garbage is pushed by ref, the garbage queue would modify the reference
              -- which could also alter the chain flag in case of fake chains
              -- so make sure to deepcpy combos before sending
              self.outgoingGarbage:push(deepcpy(garbage))
            end
          end
        end
      end
    end
  end

  self.stopwatch = self.stopwatch + 1
end

function AttackEngine:saveForRollback(frame)
  self.outgoingGarbage:saveForRollback(frame)
end

function AttackEngine:rollbackToFrame(frame)
  self.outgoingGarbage:rollbackToFrame(frame)
  self.stopwatch = frame
end

function AttackEngine:rewindToFrame(frame)
  self.outgoingGarbage:rewindToFrame(frame)
  self.stopwatch = frame
end

return AttackEngine