local logger = require("common.lib.logger")
local class = require("common.lib.class")
local consts = require("common.engine.consts")
local Queue = require("common.lib.Queue")
local Signal = require("common.lib.signal")
local Stack = require("common.engine.Stack")
require("common.engine.checkMatches")

-- A pattern for sending garbage
---@class AttackPattern
---@field width integer
---@field height integer
---@field startTime integer
---@field endsChain boolean
---@field garbage Garbage
local AttackPattern =
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
---@class AttackEngine : CanRollbackComponent
---@field delayBeforeStart integer How many frame the AttackEngine waits before running. \n
--- Note if this is changed after attack patterns are added their times won't be updated.
---@field delayBeforeRepeat integer How many frames the AttackEngine waits after a full run before starting over
---@field disableQueueLimit boolean Attack patterns that put out a crazy amount of garbage can slow down the game, \n
--- so by default no new attacks start while more than 6 deliveries are in transit in the outgoing garbage queue. \n
--- This flag can be optionally set to disable that.
---@field treatMetalAsCombo boolean whether the metal garbage is treated the same as combo garbage (aka they can mix)
---@field attackPatterns AttackPattern[] The array of AttackPattern objects this engine will run through.
---@field attackSettings table The format for serializing AttackPattern information
---@field stopWatch integer  The stopWatch to control the continuity of the sending process
---@field outgoingGarbage GarbageQueue The garbage queue attacks are added to
---@field chainSizeSent integer the size of the chain the current frame sent a link of, 0 if it sent none
---@field comboWidthsSent integer[] the widths of the combo garbage pieces the current frame sent
---@field metalPiecesSent integer how many pieces of metal garbage the current frame sent
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

    self.stopWatch = 0

    self.outgoingGarbage = garbageQueue
    -- to ensure correct behaviour according to the pattern definition
    -- the garbage queue must be modified to match the attack settings
    self.outgoingGarbage.treatMetalAsCombo = self.treatMetalAsCombo
    self.outgoingGarbage.illegalStuffIsAllowed = true

    self.chainSizeSent = 0
    self.comboWidthsSent = {}
    self.metalPiecesSent = 0

    Signal.turnIntoEmitter(self)
    -- reports each frame's attack with the values a Stack's "matched" signal carries for the same attack
    self:createSignal("attackSent")
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
---@param start integer the stopWatch frame these attacks should start being sent
---@param metal boolean? if this is a metal block
---@param chain boolean? if this is a chain attack
function AttackEngine.addAttackPattern(self, width, height, start, metal, chain)
  assert(width ~= nil and height ~= nil and start ~= nil and metal ~= nil and chain ~= nil)
  local attackPattern = AttackPattern(width, height, self.delayBeforeStart + start, metal, chain, false)
  self.attackPatterns[#self.attackPatterns + 1] = attackPattern
end

---@param chainEnd integer the stopWatch frame the ongoing chain is being finalized
function AttackEngine.addEndChainPattern(self, chainEnd)
  local attackPattern = AttackPattern(0, 0, self.delayBeforeStart + chainEnd, false, false, true)
  self.attackPatterns[#self.attackPatterns + 1] = attackPattern
end

function AttackEngine.run(self)
  self.chainSizeSent = 0
  table.clear(self.comboWidthsSent)
  self.metalPiecesSent = 0

  local highestStartTime = self.attackPatterns[#self.attackPatterns].startTime

  -- Finds the greatest startTime value found from all the attackPatterns
  for i = 1, #self.attackPatterns do
    highestStartTime = math.max(self.attackPatterns[i].startTime, highestStartTime)
  end

  local totalAttackTimeBeforeRepeat = self.delayBeforeRepeat + highestStartTime - self.delayBeforeStart
  -- assumption is that only things like combo storm don't disable the queue limit
  -- as all garbage gets collected to a single timer thanks to the mechanic of the outgoing garbage queue having any value greater than 1 in the queue means
  --  that the recipient is stalling acceptance so we shouldn't push more inside
  if self.disableQueueLimit or Queue.len(self.outgoingGarbage.transitTimers) <= 6 then
    for i = 1, #self.attackPatterns do
      if self.stopWatch >= self.attackPatterns[i].startTime then
        local difference = self.stopWatch - self.attackPatterns[i].startTime
        local remainder = difference % totalAttackTimeBeforeRepeat
        if remainder == 0 then
          if self.attackPatterns[i].endsChain then
            if not self.outgoingGarbage.currentChain then
              break
            end
            self.outgoingGarbage:finalizeCurrentChain(self.stopWatch)
          else
            local garbage = self.attackPatterns[i].garbage
            if garbage.isChain then
              self.outgoingGarbage:addChainLink(self.stopWatch, math.random(1, 11), math.random(1, 6))
              self.chainSizeSent = #self.outgoingGarbage.currentChain.linkTimes + 1
            else
              garbage.frameEarned = self.stopWatch
              -- we need a coordinate for the origin of the attack animation
              garbage.rowEarned = math.random(1, 11)
              garbage.colEarned = math.random(1, 6)
              -- if the attack engine garbage is pushed by ref, the garbage queue would modify the reference
              -- which could also alter the chain flag in case of fake chains
              -- so make sure to deepcpy combos before sending
              self.outgoingGarbage:push(deepcpy(garbage))
              self:recordGarbageSent(garbage)
            end
          end
        end
      end
    end
  end

  self:emitAttackSent()
  self.stopWatch = self.stopWatch + 1
end

-- Records a piece of non-chain garbage as part of the current frame's attack
---@param garbage Garbage
function AttackEngine:recordGarbageSent(garbage)
  if garbage.isMetal then
    self.metalPiecesSent = self.metalPiecesSent + 1
  elseif garbage.height > 1 then
    -- the outgoing garbage queue sends combo garbage taller than a row as a finished chain
    if self.chainSizeSent == 0 then
      self.chainSizeSent = garbage.height + 1
    end
  else
    self.comboWidthsSent[#self.comboWidthsSent + 1] = garbage.width
  end
end

-- Emits the attack the current frame sent, if it sent one
function AttackEngine:emitAttackSent()
  local comboSize = 0
  if #self.comboWidthsSent > 0 then
    table.sort(self.comboWidthsSent)
    comboSize = Stack.getComboSizeForGarbageWidths(self.comboWidthsSent)
  end
  -- a shock sends one metal piece per metal panel past the second
  local metalCount = self.metalPiecesSent > 0 and self.metalPiecesSent + 2 or 0
  if self.chainSizeSent > 0 or comboSize > 0 or metalCount > 0 then
    self:emitSignal("attackSent", self.chainSizeSent > 0, self.chainSizeSent, comboSize, metalCount)
  end
end

-- Transfers the attack engine state variables from source to destination (bidirectional)
---@param destination AttackEngine|table
---@param source AttackEngine|table
function AttackEngine.transferStateVariables(destination, source)
  destination.stopWatch = source.stopWatch
end

-- Writes the attack engine state and its outgoing garbage queue into copy
---@param copy table
function AttackEngine:saveIntoRollbackCopy(copy)
  if copy.outgoingGarbageData == nil then
    copy.outgoingGarbageData = {}
  end

  AttackEngine.transferStateVariables(copy, self)
  self.outgoingGarbage:saveIntoRollbackCopy(copy.outgoingGarbageData)
end

-- Restores the attack engine state and its outgoing garbage queue from copy
---@param copy table
---@param clock integer
---@param isRewind boolean
function AttackEngine:restoreFromRollbackCopy(copy, clock, isRewind)
  AttackEngine.transferStateVariables(self, copy)
  self.outgoingGarbage:restoreFromRollbackCopy(copy.outgoingGarbageData, clock, isRewind)
end

return AttackEngine