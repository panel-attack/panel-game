require("client.src.analytics")
local ChainComboTally = require("common.engine.ChainComboTally")

local function theInstanceShowsTheStacksTally()
  local tally = ChainComboTally()
  local instance = AnalyticsInstance(false, tally)

  tally:addCombo(5)
  tally:addChain(3)

  assert(instance.data.used_combos[5] == 1)
  assert(instance.data.reached_chains[3] == 1)
end

local function registeringDoesNotCountASecondTime()
  local tally = ChainComboTally()
  local instance = AnalyticsInstance(false, tally)

  tally:addCombo(5)
  instance:register_destroyed_panels(5)
  tally:addChain(3)
  instance:register_chain(3)

  assert(instance.data.used_combos[5] == 1, "the stack already counted the combo")
  assert(instance.data.reached_chains[3] == 1, "the stack already counted the chain")
  assert(instance.data.destroyed_panels == 5)
  assert(instance.data.sent_garbage_lines == 3, "one line for the combo of five and two for the x3 chain")
end

local function theDataStillReadsTheTallyAfterARollback()
  local tally = ChainComboTally()
  local instance = AnalyticsInstance(false, tally)
  instance:saveForRollback(1)
  tally:addCombo(5)
  instance:register_destroyed_panels(5)
  instance:saveForRollback(2)

  instance:rollbackRewindToFrame(1, false)
  -- the stack refills its own tally on rollback
  ChainComboTally():copyTo(tally)

  assert(instance.data.destroyed_panels == 0)
  assert(instance.data.used_combos == tally.combos, "the display reads the stack's tally, not a copy of it")
  assert(instance.data.reached_chains == tally.chains)
end

theInstanceShowsTheStacksTally()
registeringDoesNotCountASecondTime()
theDataStillReadsTheTallyAfterARollback()
