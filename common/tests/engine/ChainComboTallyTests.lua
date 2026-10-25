local ChainComboTally = require("common.engine.ChainComboTally")

local function countsEachSizeSeparately()
  local tally = ChainComboTally()
  tally:addCombo(4)
  tally:addCombo(4)
  tally:addCombo(6)
  tally:addChain(2)

  assert(tally.combos[4] == 2)
  assert(tally.combos[6] == 1)
  assert(tally.combos[5] == nil)
  assert(tally.chains[2] == 1)
end

local function copyToReplacesWhatTheTargetHeld()
  local tally = ChainComboTally()
  tally:addCombo(4)
  tally:addChain(3)
  local target = ChainComboTally()
  target:addCombo(9)
  target:addChain(7)
  local targetCombos = target.combos

  tally:copyTo(target)

  assert(target.combos[4] == 1)
  assert(target.combos[9] == nil, "a size the source never counted should not survive the copy")
  assert(target.chains[3] == 1)
  assert(target.chains[7] == nil)
  assert(target.combos == targetCombos, "the copy reuses the target's tables so readers holding them stay current")
end

countsEachSizeSeparately()
copyToReplacesWhatTheTargetHeld()
