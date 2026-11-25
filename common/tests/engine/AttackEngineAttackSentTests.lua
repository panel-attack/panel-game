local AttackEngine = require("common.engine.AttackEngine")
local GarbageQueue = require("common.engine.GarbageQueue")

-- Runs an attack engine sending the attack patterns for frameCount frames,
-- returning the attack it reported sending on each frame, keyed by the frame
---@param attackPatterns table[]
---@param frameCount integer
---@return table<integer, {isChainLink: boolean, chainSize: integer, comboSize: integer, metalCount: integer}>
local function attacksSentByFrame(attackPatterns, frameCount)
  local attackSettings = {countdownAdjusted = true, delayBeforeRepeat = 1000, disableQueueLimit = true, attackPatterns = attackPatterns}
  local attackEngine = AttackEngine(attackSettings, GarbageQueue())
  local attacksSent = {}
  attackEngine:connectSignal("attackSent", attacksSent, function(_, isChainLink, chainSize, comboSize, metalCount)
    attacksSent[attackEngine.stopWatch] = {isChainLink = isChainLink, chainSize = chainSize, comboSize = comboSize, metalCount = metalCount}
  end)
  for _ = 0, frameCount do
    attackEngine:run()
  end
  return attacksSent
end

local function combo(width, startTime)
  return {width = width, height = 1, startTime = startTime, chain = false, metal = false}
end

local function metal(startTime)
  return {width = 6, height = 1, startTime = startTime, chain = false, metal = true}
end

---@param attack table?
---@param isChainLink boolean
---@param chainSize integer
---@param comboSize integer
---@param metalCount integer
local function assertAttack(attack, isChainLink, chainSize, comboSize, metalCount)
  assert(attack, "no attack was reported")
  local description = tostring(attack.isChainLink) .. " " .. attack.chainSize .. " " .. attack.comboSize .. " " .. attack.metalCount
  assert(attack.isChainLink == isChainLink and attack.chainSize == chainSize and attack.comboSize == comboSize and attack.metalCount == metalCount,
         "expected " .. tostring(isChainLink) .. " " .. chainSize .. " " .. comboSize .. " " .. metalCount .. " but got " .. description)
end

local function aComboPieceIsReportedAsItsCombo()
  local attacksSent = attacksSentByFrame({combo(3, 5)}, 10)
  assertAttack(attacksSent[5], false, 0, 4, 0)
  assert(attacksSent[4] == nil and attacksSent[6] == nil, "frames without attacks reported one")
end

local function piecesSentTogetherAreReportedAsTheComboThatSendsThem()
  assertAttack(attacksSentByFrame({combo(3, 5), combo(4, 5)}, 5)[5], false, 0, 8, 0)
  assertAttack(attacksSentByFrame({combo(4, 5), combo(3, 5)}, 5)[5], false, 0, 8, 0)
  assertAttack(attacksSentByFrame({combo(4, 5), combo(4, 5)}, 5)[5], false, 0, 9, 0)
  assertAttack(attacksSentByFrame({combo(6, 5), combo(6, 5)}, 5)[5], false, 0, 12, 0)
end

local function piecesNoComboSendsAreReportedByTheWidestPiece()
  assertAttack(attacksSentByFrame({combo(3, 5), combo(3, 5)}, 5)[5], false, 0, 4, 0)
end

local function eachChainLinkIsReportedWithItsChainSize()
  local attacksSent = attacksSentByFrame({{chain = {5, 10}, chainEndTime = 20}}, 20)
  assertAttack(attacksSent[5], true, 2, 0, 0)
  assertAttack(attacksSent[10], true, 3, 0, 0)
end

local function aComboOnAChainLinkIsReportedAsBoth()
  local attacksSent = attacksSentByFrame({{chain = {5, 10}, chainEndTime = 20}, combo(3, 10)}, 20)
  assertAttack(attacksSent[10], true, 3, 4, 0)
end

local function metalPiecesAreReportedAsTheShockThatSendsThem()
  assertAttack(attacksSentByFrame({metal(5), metal(5), combo(3, 5)}, 5)[5], false, 0, 4, 4)
end

local function aTallComboPieceIsReportedAsAChain()
  assertAttack(attacksSentByFrame({{width = 6, height = 3, startTime = 5, chain = false}}, 5)[5], true, 4, 0, 0)
end

aComboPieceIsReportedAsItsCombo()
piecesSentTogetherAreReportedAsTheComboThatSendsThem()
piecesNoComboSendsAreReportedByTheWidestPiece()
eachChainLinkIsReportedWithItsChainSize()
aComboOnAChainLinkIsReportedAsBoth()
metalPiecesAreReportedAsTheShockThatSendsThem()
aTallComboPieceIsReportedAsAChain()
