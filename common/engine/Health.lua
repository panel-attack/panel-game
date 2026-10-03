local logger = require("common.lib.logger")
local consts = require("common.engine.consts")
local class = require("common.lib.class")
local JsonSafePrecision = require("common.data.JsonSafePrecision")

---@class HealthSettings
---@field framesToppedOutToLose number Starting value of framesToppedOutToLose
---@field lineClearGPM number How many "lines" we clear per minute. Essentially how fast we recover.
---@field lineHeightToKill number How many "lines" need to be accumulated before we are "topped" out.
---@field riseSpeed integer The initial speed lines accumulate with passively

---@class HealthEngine : CanRollbackComponent
---@field framesToppedOutToLose number Number of seconds currently remaining of being "topped" out before we are defeated.
---@field maxSecondsToppedOutToLose number Starting value of framesToppedOutToLose
---@field lineClearRate number How many "lines" we clear per second. Essentially how fast we recover.
---@field currentLines number The current number of "lines" simulated
---@field height number How many "lines" need to be accumulated before we are "topped" out.
---@field lastWasFourCombo boolean Tracks if the last combo was a +4. If two +4s hit in a row, it only counts as 1 "line"
---@field clock integer Current clock time, this should match the opponent
---@field initialRiseSpeed integer The initial speed lines accumulate with passively
---@field currentRiseSpeed integer The current speed lines accumulate with passively; speed is just like normal Stacks for now, lines are added faster the longer the match goes
local Health = class(
  function(self, framesToppedOutToLose, lineClearGPM, height, riseSpeed)
    self.framesToppedOutToLose = framesToppedOutToLose
    self.maxSecondsToppedOutToLose = framesToppedOutToLose
    self.lineClearRate = JsonSafePrecision.toSafePrecision(lineClearGPM / 60)
    self.currentLines = 0
    self.height = height
    self.lastWasFourCombo = false
    self.clock = 0
    self.initialRiseSpeed = riseSpeed
    self.currentRiseSpeed = riseSpeed
  end
)

function Health:run()
  -- Increment rise speed if needed
  if self.clock > 0 and self.clock % (15 * 60) == 0 then
    self.currentRiseSpeed = math.min(self.currentRiseSpeed + 1, 99)
  end

  local risenLines = 1.0 / (consts.SPEED_TO_RISE_TIME[self.currentRiseSpeed] * 16)
  self.currentLines = self.currentLines + risenLines

  -- Harder to survive over time, simulating "stamina"
  local staminaPercent = math.max(0.5, 1 - ((self.clock / 60) * (0.01 / 10)))
  local decrementLines = (self.lineClearRate * (1/60.0)) * staminaPercent
  self.currentLines = math.max(0, self.currentLines - decrementLines)
  if self.currentLines >= self.height then
    self.framesToppedOutToLose = math.max(0, self.framesToppedOutToLose - 1)
  end
  self.clock = self.clock + 1
  return self.framesToppedOutToLose
end

function Health:damageForHeight(height)
  if height >= 6 then
    local damage = 5
    for i = 1, height-5 do
      if i > 4 then
        break
      end
      damage = damage + (1 - i * .2)
    end
    return damage
  end
  return height
end

function Health:receiveGarbage(frameToReceive, garbage)
  if garbage.width and garbage.height then
    local countGarbage = true
    if not garbage.isMetal and not garbage.isChain and garbage.width == 3 then
      if self.lastWasFourCombo then
        -- Two four combos in a row, don't count an extra line
        self.lastWasFourCombo = false
        countGarbage = false
      else
        -- First four combo
        self.lastWasFourCombo = true
      end
    else
      -- non four combo
      self.lastWasFourCombo = false
    end

    if countGarbage then
      self.currentLines = self.currentLines + self:damageForHeight(garbage.height)
    end
  end
end

function Health:getTopOutPercentage()
  return math.max(0, self.currentLines) / self.height
end

---Transfers the health state variables from source to destination (bidirectional)
---clock has to travel with the rest of it: run reads it for the rise speed step and the stamina
---curve and then increments it itself, so a health engine that keeps its clock across a rollback
---goes on counting from the frame it was on and scores the same frame differently the second time
---@param destination table
---@param source table
function Health.transferHealthData(destination, source)
  destination.clock = source.clock
  destination.currentRiseSpeed = source.currentRiseSpeed
  destination.currentLines = source.currentLines
  destination.framesToppedOutToLose = source.framesToppedOutToLose
  destination.lastWasFourCombo = source.lastWasFourCombo
end

---Writes the health state into copy
---@param copy table
function Health:saveIntoRollbackCopy(copy)
  Health.transferHealthData(copy, self)
end

---clock and isRewind are the interface's; the saved copy carries everything this needs
---@param copy table
---@param clock integer
---@param isRewind boolean
function Health:restoreFromRollbackCopy(copy, clock, isRewind)
  Health.transferHealthData(self, copy)
end

---@return HealthSettings
function Health:getSettings()
  return {
    framesToppedOutToLose = self.maxSecondsToppedOutToLose,
    lineClearGPM = JsonSafePrecision.toSafePrecision(self.lineClearRate * 60),
    lineHeightToKill = self.height,
    riseSpeed = self.initialRiseSpeed
  }
end

return Health
