require("common.lib.stringExtensions")
local TouchDataEncoding = require("common.data.TouchDataEncoding")
local consts = require("common.engine.consts")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local util = require("common.lib.util")
local utf8 = require("common.lib.utf8Additions")
local BaseStack = require("common.engine.BaseStack")
local class = require("common.lib.class")
local Panel = require("common.engine.Panel")
local prof = require("common.lib.zoneProfiler")
local LevelData = require("common.data.LevelData")
table.clear = require("table.clear")
local RollbackBuffer = require("common.engine.RollbackBuffer")
local WigglePay = require("common.engine.WigglePay")
local KeyDataEncoding = require("common.data.KeyDataEncoding")
local InputCompression= require("common.data.InputCompression")
local MatchRules = require("common.data.MatchRules")
local StackBehaviours = require("common.data.StackBehaviours")

local rollbackPanelBuffer = {}
-- this is a bit of an opportunistic thing:
-- one issue with rollback is that it allocates a ton of memory while it boots up which in turn accelerates the garbage collector
-- that creates a situation where more memory is allocated, the GC starts running faster and the odds of having to run double updates for the opponent is high
-- by preallocating memory for the panels (which is responsible for 90% of rollback memory), the load is less concentrated and stacks are generally more "rollback ready"
-- as each table gets cleared before reuse it can be shared by all stacks
for i = 1, (15 * 6) * MAX_LAG * 2 do
  rollbackPanelBuffer[#rollbackPanelBuffer+1] = table.new(0, 24)
end

-- Stuff defined in this file:
--  . the data structures that store the configuration of
--    the stack of panels
--  . the main game routine
--    (rising, timers, falling, cursor movement, swapping, landing)
--  . the matches-checking routine
local min, pairs = math.min, pairs
local max = math.max

local DEFAULT_INPUT_REPEAT_DELAY = 20

local GARBAGE_SIZE_TO_SHAKE_FRAMES = {
  18, 18, 18, 18, 24, 42,
  42, 42, 42, 42, 42, 66,
  66, 66, 66, 66, 66, 66,
  66, 66, 66, 66, 66, 76
}

local DT_SPEED_INCREASE = 15 * 60 -- frames it takes to increase the speed level by 1

-- endless and 1P time attack use a speed system in which
-- speed increases based on the number of panels you clear.
-- For example, to get from speed 1 to speed 2, you must
-- clear 9 panels.
local PANELS_TO_NEXT_SPEED =
  {9, 12, 12, 12, 12, 12, 15, 15, 18, 18,
  24, 24, 24, 24, 24, 24, 21, 18, 18, 18,
  36, 36, 36, 36, 36, 36, 36, 36, 36, 36,
  39, 39, 39, 39, 39, 39, 39, 39, 39, 39,
  45, 45, 45, 45, 45, 45, 45, 45, 45, 45,
  45, 45, 45, 45, 45, 45, 45, 45, 45, 45,
  45, 45, 45, 45, 45, 45, 45, 45, 45, 45,
  45, 45, 45, 45, 45, 45, 45, 45, 45, 45,
  45, 45, 45, 45, 45, 45, 45, 45, 45, 45,
  45, 45, 45, 45, 45, 45, 45, 45, math.huge}

---@class PanelSource : canRollback
---@field generateStartingBoard fun(self: PanelSource, stack: Stack): string
---@field generateGarbagePanels fun(self: PanelSource, stack:Stack): string
---@field getStartingBoardHeight fun(self: PanelSource, stack: Stack): integer how many rows are to be generated at the start
---@field createNewRow fun(self: PanelSource, stack: Stack, row: integer) creates a new set of panels for the stack with the specified row index and writes it to the stack's panels array
---@field getGarbagePanelRowString fun(self: PanelSource, stack: Stack): string returns a string of color indices
---@field clone fun(self: PanelSource, stack: Stack): PanelSource creates a PanelSource that is tailored to the Stack's settings based on the template that is cloned from
---@field panelBuffer string alphanumeric string containing a buffer of panels to rise from below; string characters indicate possible metal positions
---@field garbagePanelBuffer string numeric string containing a buffer of panels for garbage to turn into upon matching
---@field toReplaySource fun(self: PanelSource): ReplayPanelSource
---@field TYPE string

---@alias CursorDirection ("up" | "down" | "left" | "right")

---@type table<CursorDirection, integer>
local DIRECTION_COLUMN = {up = 0, down = 0, left = -1, right = 1}
---@type table<CursorDirection, integer>
local DIRECTION_ROW = {up = 1, down = -1, left = 0, right = 0}

---@class Stack : BaseStack
---@field width integer How many columns of panels the stack has
---@field height integer How many rows of panels the stack has
---@field levelData LevelData Frame data to determine Panel physics
---@field behaviours StackBehaviours a table of flags and settings to modify the stack behaviour in chunks of functionality
---@field speed integer Index for accessing the table for the rise_timer, thus indirectly determining how quickly the stack rises
---@field nextSpeedIncreaseClock integer? at which clock time the speed is going to increase the next time; only relevant if the levelData's speedIncreaseMode is 1
---@field panels_to_speedup integer? how many more panels have to be cleared for speed to increase on the next frame; only relevant if the levelData's speedIncreaseMode is 2
---@field health integer Depletes by 1 every time the stack would try to passively raise while topped out \n
--- Reaching 0 typically means game over (depends on the gameOverConditions)
---@field garbageSizeDropColumnMaps integer[][] Which columns each size garbage is allowed to fall in; also defining the repeating sequence. \n
--- This is typically constant but maybe some day we would allow different ones \n
--- for different game modes or need to change it based on board width.
---@field currentGarbageDropColumnIndexes integer[] The current index of the above table we are currently using for the drop column. \n
--- This increases by 1 wrapping every time garbage drops.
---@field inputMethod string "controller" or "touch", determines how inputs are interpreted internally
---@field confirmedInput string[] All inputs the player has input so far (or ever)
---@field input_state string The input for the current frame
---@field package garbageCreatedCount integer The number of individual garbage blocks created on this stack \n
--- used for giving a unique identifier to each new garbage block
---@field garbageLandedThisFrame integer[] Cache for garbage ids that had panels landing this frame; cleared every frame
---@field highestGarbageIdMatched integer tracks the highest id of garbage matched so far; used for resolving edge cases when matching offscreen garbage
---@field package panelsCreatedCount integer The number of individual panels created on this stack; used for giving new panels their own unique identifier
---@field panels Panel[][] 2 dimensional table for containing all panels \n
--- panel[i] gets the row where i is the index of the row with 1 being the bottommost row in play (not dimmed) \n
--- panel[i][j] gets the panel at row i where j is the column index counting from left to right starting from 1 \n
--- the update order for panels is bottom to top and left to right as well
---@field displacement integer This variable indicates how far below the top of the play area the top row of panels actually is. \n
--- This variable being decremented causes the stack to rise. \n
--- During the automatic rising routine, if this variable is 0, it's reset to 15, all the panels are moved up one row, and a new row is generated at the bottom. \n
--- Only when the displacement is 0 are all 12 rows "in play."
---@field rise_timer integer When this value reaches 0, the stack will rise a pixel (or differently said, displacement decreases by 1) \n
--- Resets to varying values according to the Stack's speed
---@field rise_lock boolean If the stack is rise locked, it won't rise until it is unlocked.
---@field has_risen boolean set to true once the stack rises once during the game; I think this is only to prevent the stack from creating a new row right at the start?
---@field pre_stop_time integer Invincibility frames representing the longest remaining pop duration of all current matches (both regular and garbage). Depletes by 1 each frame.
---@field stop_time integer Invincibility frames earned by performing chains and combos. Does not deplete while there is pre_stop. Depletes by 1 each frame otherwise. Resets to 0 on manual raise.
---@field score integer points incrementing on chain, combo, match, pop and manual raise according to certain rules
---@field chain_counter integer Number of the current chain links starting from 2; relevant for scoring and stop_time \n
--- resets to 0 on chain end and sends garbage according to length
---@field n_active_panels integer How many panels are "active" on this frame; active panels prevent the stack from rising
---@field n_prev_active_panels integer How many panels were "active" on the previous frame; previous active panels prevent the stack from rising
---@field manual_raise boolean if true the stack is currently being manually raised; kept true until the raise has been completed
---@field manual_raise_yet boolean if not set, no actual raising has been done yet since manual raise button was pressed \n
--- if a raise is interrupted by rise_lock and the stack has already risen (meaning this is true), manual_raise will stay true and the stack will attempt to raise again even after the raise had been let go \n
--- conversely if the rise_lock happened from the start and the manual_raise never achieved a single tick of displacement of raise, this being false leads to manual_raise being set to false again, effectively cancelling the raise
---@field prevent_manual_raise boolean if set to true it prevents raises initiating another raise; mostly to prevent manual_raise_yet from being overwritten so it can do its cryptic work \n
--- this set of fields can really do with a rework
---@field swapThisFrame boolean if there was an attempt to initiate a swap on this frame
---@field cur_wait_time integer DAS delay: number of ticks a movement key has to be held before the cursor begins to move at 1 movement per frame
---@field cur_timer integer number of ticks the current movement key has been held
---@field cursorDirection CursorDirection? direction of the current movement key
---@field cur_row integer row the cursor is on
---@field cur_col integer the column the left half of the cursor is on (or just the cursor in case of touch)
---@field queuedSwapRow integer row in which a swap for next frame has been queued; 0 if none queued
---@field queuedSwapColumn integer column of the left (or in case of touch the "target") panel for which a swap has been queued for next frame; 0 if none queued
---@field top_cur_row integer the maximum row index the cursor is allowed to go at the moment
---@field panels_cleared integer How many panels have been cleared on the stack so far; relevant for the occurence of shock panels
---@field metalPanelsQueued integer How many shock panels are currently queued up
---@field prev_shake_time integer How many frames of shake time we had last frame; by comparing with the new shake_time it can be determined whether there should be a thud SFX or other things
---@field shake_time integer Invincibility frames earned by a previously off-screen garbage panel transitioning from falling to normal state. Not cumulative. Depletes by 1 each frame.
---@field shake_time_on_frame integer The shake time that would have been earned by falling panels this frame. Overwrites shake_time if greater.
---@field peak_shake_time integer Records the maximum shake time obtained for the current stretch of uninterrupted shake time. \n
--- Any additional shake time gained before shake depletes to 0 will reset shake_time back to this value. Set to 0 when shake_time reaches 0.
---@field warningsTriggered table ancient ancient, probably remove
---@field rollbackBuffer RollbackBuffer A specialized class to manage memory for rollback data
---@field panelTemplate (Panel | fun(row: integer, column: integer, id: integer?): Panel) A template class based on Panel enriched by tailor made closures containing references to the Stack
---@field swapStallingBackLog table tracks swaps that will incur a health cost for stalling if not swapping would have resulted in health loss
---@field swappingPanelCount integer how many panels are swapping on this frame
---@field panelSource PanelSource where the Stack gets its panels from 
---@field swapCount integer
---@field wasToppedOut boolean if the stack was topped out at the start of the frame


-- Represents the full panel stack for one player
---@class Stack
---@overload fun(args: {levelData: LevelData, stackSetupModifications: StackSetupModifications, panelSource: PanelSource, inputMethod: InputMethod, is_local: boolean, stackWinConditions: table<StackWinCondition, any>, stackOverCondition: table<StackOverCondition, any>}): Stack
local Stack = class(
---@param s Stack
---@param args {levelData: LevelData, stackSetupModifications: StackSetupModifications, panelSource: PanelSource, inputMethod: InputMethod, is_local: boolean, stackWinConditions: table<StackWinCondition, any>, stackOverCondition: table<StackOverCondition, any>}
  function(s, args)
    s.width = 6
    s.height = 12
    assert(args.levelData ~= nil)
    assert(args.stackSetupModifications ~= nil)
    assert(args.panelSource)

    s.levelData = args.levelData
    -- the behaviour table contains a bunch of flags to modify the stack behaviour for custom game modes in broader chunks of functionality
    s.behaviours = StackBehaviours.getDefault()
    if args.stackSetupModifications.behaviours then
      for key, value in pairs(args.stackSetupModifications.behaviours) do
        s.behaviours[key] = value
      end
    end
    s.panelSource = args.panelSource:clone(s)
    s.inputMethod = args.inputMethod

    if s.behaviours.delaySimulationUntil then
      s.stopWatchIsRunning = false
    end

    s.swapStallingBackLog = {}

    s.speed = s.levelData.startingSpeed
    if s.levelData.speedIncreaseMode == LevelData.SPEED_INCREASE_MODES.TIME_INTERVAL then
      -- mode 1: increase speed based on fixed intervals
      s.nextSpeedIncreaseClock = DT_SPEED_INCREASE
    else
      s.panels_to_speedup = PANELS_TO_NEXT_SPEED[s.speed]
    end

    s.health = s.levelData.maxHealth

    s.garbageSizeDropColumnMaps = {
      {1, 2, 3, 4, 5, 6},
      {1, 3, 5,},
      {1, 4},
      {1, 2, 3},
      {1, 2},
      {1}
    }

    s.currentGarbageDropColumnIndexes = {1, 1, 1, 1, 1, 1}

    s.confirmedInput = table.new(43200, 0)
    s.garbageCreatedCount = 0
    s.garbageLandedThisFrame = {}
    s.highestGarbageIdMatched = 0
    s.panelsCreatedCount = 0
    s.panels = {}
    s.panelTemplate = s:createPanelTemplate()

    for i = 0, s.height do
      s.panels[i] = {}
      for j = 1, s.width do
        s:createPanelAt(i, j)
      end
    end

    s.max_runs_per_frame = 3

    s.displacement = 16
    s.wasToppedOut = false
    s.rise_timer = consts.SPEED_TO_RISE_TIME[s.speed]
    s.rise_lock = false
    s.has_risen = false

    s.stop_time = args.stackSetupModifications.stopTime or 0
    s.pre_stop_time = 0

    s.score = 0
    s.chain_counter = 0

    s.n_active_panels = 0
    s.n_prev_active_panels = 0
    s.swappingPanelCount = 0

    -- Player input stuff:
    s.manual_raise = false
    s.manual_raise_yet = false
    s.prevent_manual_raise = false
    s.swapThisFrame = false -- attempt to initiate a swap on this frame

    -- number of ticks a movement key has to be held before the cursor begins to move at 1 movement per frame
    s.cur_wait_time = DEFAULT_INPUT_REPEAT_DELAY
    s.cur_timer = 0 -- number of ticks for which a new direction's been pressed
    s.cursorDirection = nil -- the direction pressed
    s.cur_row = args.stackSetupModifications.startingRow or 7
    s.cur_col = args.stackSetupModifications.startingCol or 3
    s.queuedSwapColumn = 0
    s.queuedSwapRow = 0
    if s.behaviours.passiveRaise then
      -- technically it should always start at height but changing it would break replays
      -- see https://github.com/panel-attack/panel-game/issues/634
      -- this is a compromise to make puzzle setup as painless as possible
      s.top_cur_row = s.height - 1
    else
      s.top_cur_row = s.height
    end
    s.swapCount = 0

    s.panels_cleared = s.panels_cleared or 0
    s.metalPanelsQueued = s.metalPanelsQueued or 0

    s.prev_shake_time = 0
    s.shake_time = args.stackSetupModifications.shakeTime or 0
    s.shake_time_on_frame = 0
    s.peak_shake_time = 0

    s.rollbackBuffer = RollbackBuffer(MAX_LAG + 1)

    s.warningsTriggered = {}

    s:createSignal("matched")
    s:createSignal("panelPop")
    s:createSignal("panelLanded")
    s:createSignal("cursorMoved")
    s:createSignal("panelsSwapped")
    s:createSignal("swapDenied")
    s:createSignal("garbageMatched")
    s:createSignal("newRow")
  end,
  BaseStack
)

Stack.TYPE = "Stack"
Stack.supportedStackOverConditions = { MatchRules.StackOverConditions.HEALTH, MatchRules.StackOverConditions.SWAPS, MatchRules.StackOverConditions.CHAIN }
Stack.supportedStackWinConditions = { MatchRules.StackWinConditions.MATCHABLE_PANELS, MatchRules.StackWinConditions.MATCHABLE_GARBAGE_PANELS, MatchRules.StackWinConditions.SCORE }

---@return (Panel | fun(row: integer, column: integer, id: integer?): Panel)
function Stack:createPanelTemplate()
  local panelTemplate = class(function(p, row, column, id)
    if not id then
      self.panelsCreatedCount = self.panelsCreatedCount + 1
      p.id = self.panelsCreatedCount
    end
  end, Panel)
  panelTemplate.frameTimes = self.levelData.frameConstants
  panelTemplate.onPop = function(panel)
    self:onPop(panel)
  end
  panelTemplate.onPopped = function(panel)
    self:onPopped(panel)
  end
  panelTemplate.onLand = function(panel)
    self:onLand(panel)
  end

  return panelTemplate
end

function Stack.divergenceString(stackToTest)
  local result = ""

  local panels = stackToTest.panels

  if panels then
      for i=#panels,1,-1 do
          for j=1,#panels[i] do
            result = result .. (tostring(panels[i][j].color)) .. " "
            if panels[i][j].state ~= "normal" then
              result = result .. (panels[i][j].state) .. " "
            end
          end
          result = result .. "\n"
      end
  end

  result = result .. "Stop " .. stackToTest.stop_time .. "\n"
  result = result .. "Pre Stop " .. stackToTest.pre_stop_time .. "\n"
  result = result .. "Shake " .. stackToTest.shake_time .. "\n"
  result = result .. "Displacement " .. stackToTest.displacement .. "\n"
  result = result .. "Clock " .. stackToTest.clock .. "\n"

  return result
end

function Stack:rollbackCopyPanels(copy)
  local panels = copy.panels or {}

  -- rollback data for panels is saved in an unrolled format to avoid creating dozens of extra tables for storage
  -- panels are saved in a flat table and indexed left to right, going up from row 0
  for i = 0, #self.panels do
    for j = 1, self.width do
      local index = i * self.width + j
      -- if it's a fresh copy or the current stack is higher than the stale copy there may not be any preexisting table at this location
      local panelCopy = panels[index]
      if not panelCopy then
        if #rollbackPanelBuffer > 0 then
          panelCopy = table.remove(rollbackPanelBuffer)
        else
          -- panels have 13 base props and up to 11 garbage specific props OR 7 non-garbage specific props
          panelCopy = table.new(0, 24)
        end
      end
      local sPanel = self.panels[i][j]
      for k, v in pairs(sPanel) do
        panelCopy[k] = v
      end
      panels[index] = panelCopy
    end
  end

  return panels
end

-- saves a copy of the stack with its current clock within its rollback buffer
function Stack:rollbackCopy()
  local copy = self.rollbackBuffer:getOldest()
  if copy then
    -- as we're reusing tables and many panel values can be nil, it's necessary to clear out data to not have false data linger
    for i = 1, #copy.panels do
      table.clear(copy.panels[i])
    end
    -- this is to eliminate offscreen rows of chain garbage higher up from the old copy so they don't linger in the new copy
    for i = #copy.panels, (#self.panels + 1) * self.width + 1, -1 do
      -- but as offscreen rows come and go and we don't want to reallocate them every time, buffer them as well!
      rollbackPanelBuffer[#rollbackPanelBuffer+1] = copy.panels[i]
      copy.panels[i] = nil
    end
  else
    copy = {panels = {}, currentGarbageDropColumnIndexes = {}}
  end

  copy.queuedSwapColumn = self.queuedSwapColumn
  copy.queuedSwapRow = self.queuedSwapRow
  copy.speed = self.speed
  copy.health = self.health
  copy.countdown_timer = self.countdown_timer
  copy.clock = self.clock
  copy.stopWatch = self.stopWatch
  copy.stopWatchIsRunning = self.stopWatchIsRunning
  copy.rise_lock = self.rise_lock
  copy.top_cur_row = self.top_cur_row
  copy.displacement = self.displacement
  copy.nextSpeedIncreaseClock = self.nextSpeedIncreaseClock
  copy.panels_to_speedup = self.panels_to_speedup
  copy.stop_time = self.stop_time
  copy.pre_stop_time = self.pre_stop_time
  copy.score = self.score
  copy.chain_counter = self.chain_counter
  copy.n_active_panels = self.n_active_panels
  copy.n_prev_active_panels = self.n_prev_active_panels
  copy.swappingPanelCount = self.swappingPanelCount
  copy.rise_timer = self.rise_timer
  copy.manual_raise = self.manual_raise
  copy.manual_raise_yet = self.manual_raise_yet
  copy.prevent_manual_raise = self.prevent_manual_raise
  copy.cur_timer = self.cur_timer
  copy.cursorDirection = self.cursorDirection
  copy.cur_row = self.cur_row
  copy.cur_col = self.cur_col
  copy.shake_time = self.shake_time
  copy.peak_shake_time = self.peak_shake_time
  copy.shake_time_on_frame = self.shake_time_on_frame
  copy.do_countdown = self.do_countdown
  copy.has_risen = self.has_risen
  copy.metalPanelsQueued = self.metalPanelsQueued
  copy.panels_cleared = self.panels_cleared
  copy.game_over_clock = self.game_over_clock
  copy.highestGarbageIdMatched = self.highestGarbageIdMatched
  copy.swapCount = self.swapCount

  for garbageWidth = 1, #self.currentGarbageDropColumnIndexes do
    copy.currentGarbageDropColumnIndexes[garbageWidth] = self.currentGarbageDropColumnIndexes[garbageWidth]
  end

  copy.panelsCreatedCount = self.panelsCreatedCount
  prof.push("rollbackCopyPanels")
  copy.panels = self:rollbackCopyPanels(copy)
  prof.pop("rollbackCopyPanels")

  self.rollbackBuffer:saveCopy(self.clock, copy)
end

---@param stack Stack
---@param clock integer
local function internalRollbackToFrame(stack, clock)
  local copy = stack.rollbackBuffer:rollbackToFrame(clock)

  if not copy then
    return false
  end

  stack.countdown_timer = copy.countdown_timer
  stack.clock = copy.clock
  stack.stopWatch = copy.stopWatch
  stack.stopWatchIsRunning = copy.stopWatchIsRunning
  stack.rise_lock = copy.rise_lock
  stack.top_cur_row = copy.top_cur_row
  stack.displacement = copy.displacement
  stack.nextSpeedIncreaseClock = copy.nextSpeedIncreaseClock
  stack.panels_to_speedup = copy.panels_to_speedup
  stack.stop_time = copy.stop_time
  stack.pre_stop_time = copy.pre_stop_time
  stack.score = copy.score
  stack.chain_counter = copy.chain_counter
  stack.n_active_panels = copy.n_active_panels
  stack.n_prev_active_panels = copy.n_prev_active_panels
  stack.swappingPanelCount = copy.swappingPanelCount
  stack.rise_timer = copy.rise_timer
  stack.manual_raise = copy.manual_raise
  stack.manual_raise_yet = copy.manual_raise_yet
  stack.prevent_manual_raise = copy.prevent_manual_raise
  stack.cur_timer = copy.cur_timer
  stack.cursorDirection = copy.cursorDirection
  stack.cur_row = copy.cur_row
  stack.cur_col = copy.cur_col
  stack.shake_time = copy.shake_time
  stack.peak_shake_time = copy.peak_shake_time
  stack.shake_time_on_frame = copy.shake_time_on_frame
  stack.do_countdown = copy.do_countdown
  stack.has_risen = copy.has_risen
  stack.metalPanelsQueued = copy.metalPanelsQueued
  stack.panels_cleared = copy.panels_cleared
  stack.game_over_clock = copy.game_over_clock
  stack.highestGarbageIdMatched = copy.highestGarbageIdMatched
  stack.queuedSwapColumn = copy.queuedSwapColumn
  stack.queuedSwapRow = copy.queuedSwapRow
  stack.speed = copy.speed
  stack.health = copy.health
  stack.swapCount = copy.swapCount

  -- we can just overwrite using the copied table as the rollbackBuffer discards that table from reuse
  stack.currentGarbageDropColumnIndexes = copy.currentGarbageDropColumnIndexes

  -- roll up the panel copies into the table structure
  for i, panelCopy in ipairs(copy.panels) do
    local row = panelCopy.row
    local column = panelCopy.column
    if not stack.panels[row] then
      stack.panels[row] = {}
    end

    if stack.panels[row][column] then
      table.clear(stack.panels[row][column])
    else
      stack.panels[row][column] = stack.panelTemplate(row, column, panelCopy.id)
    end

    for k, v in pairs(panelCopy) do
      stack.panels[row][column][k] = v
    end
  end

  -- we need to cut off any offscreen panels that were not there in the copied data
  -- -1 cause we always have a row 0 at the beginning of copy.panels, +1 because we don't actually want to remove the top most row
  local maxRow = #copy.panels / stack.width -- - 1 + 1
  for i = #stack.panels, maxRow, -1 do
    stack.panels[i] = nil
  end

  -- this is for the interpolation of the shake animation only (not a physics relevant field)
  local previousData = stack.rollbackBuffer:peekPrevious()
  if previousData and previousData.clock == clock - 1 then
    stack.prev_shake_time = previousData.shake_time
  else
    -- if this is the oldest rollback frame we don't need to interpolate with previous values
    -- because there are no previous values, pretend it just went down smoothly
    -- this can lead to minor differences in display for the same frame when using rewind
    stack.prev_shake_time = stack.shake_time + 1
  end

  return true
end

---@param clock integer the frame to rollback to if possible
---@return boolean success if rolling back succeeded
function Stack:rollbackToFrame(clock)
  local currentFrame = self.clock

  if internalRollbackToFrame(self, clock) then
    self.incomingGarbage:rollbackToFrame(self.stopWatch)
    self.outgoingGarbage:rollbackToFrame(self.stopWatch)
    self.panelSource:rollbackToFrame(clock)

    self.rollbackCount = self.rollbackCount + 1
    -- match will try to fast forward this stack to that frame
    self.lastRollbackFrame = currentFrame
    self:emitSignal("rollbackPerformed", self)
    return true
  end

  return false
end

---@param clock integer the frame to rewind to if possible
---@return boolean success if rewinding succeeded
function Stack:rewindToFrame(clock)
  if internalRollbackToFrame(self, clock) then
    self.incomingGarbage:rewindToFrame(self.stopWatch)
    self.outgoingGarbage:rewindToFrame(self.stopWatch)
    self.panelSource:rewindToFrame(clock)

    -- we did roll back but we want to stay here
    self.lastRollbackFrame = clock

    self:emitSignal("rollbackPerformed", self)
    return true
  end

  return false
end

-- Saves state in backups in case its needed for rollback
-- NOTE: the clock time is the save state for simulating right BEFORE that clock time is simulated
function Stack:saveForRollback()
  prof.push("Stack:saveForRollback")
  self:removeExtraRows()
  prof.push("Stack.rollbackCopy")
  self:rollbackCopy()
  prof.pop("Stack.rollbackCopy")
  prof.push("incomingGarbage:saveForRollback")
  self.incomingGarbage:saveForRollback(self.stopWatch)
  prof.pop("incomingGarbage:saveForRollback")
  prof.push("outgoingGarbage:saveForRollback")
  if self.outgoingGarbage then
    self.outgoingGarbage:saveForRollback(self.stopWatch)
  end
  prof.pop("outgoingGarbage:saveForRollback")
  self.panelSource:saveForRollback(self.clock)
  prof.pop("Stack:saveForRollback")
  self:emitSignal("rollbackSaved", self.clock)
end

function Stack:toPuzzleInfo()
  local puzzleInfo = {}
  puzzleInfo["Stop"] = self.stop_time
  puzzleInfo["Shake"] = self.shake_time
  puzzleInfo["Stack"] = Puzzle.toPuzzleString(self.panels)

  return puzzleInfo
end

function Stack:hasMatchableGarbage()
  -- garbage is more likely to be found at the top of the stack
  for row = self.height, 1, -1 do
    for column = 1, #self.panels[row] do
      if self.panels[row][column].isGarbage
        and self.panels[row][column].state ~= "matched" then
        return true
      end
    end
  end

  return false
end

function Stack:hasActivePanels()
  return self.n_active_panels > 0 or self.n_prev_active_panels > 0
end

function Stack:hasFallingGarbage()
  -- iterating top to bottom as finding falling garbage in upper rows is more likely
  -- we shouldn't have to check quite 3 rows above height, but just to make sure...
  for row = math.min(self.height + 3, #self.panels), 1, -1 do
    for col = 1, self.width do
      if self.panels[row][col].isGarbage and self.panels[row][col].state == "falling" then
        return true
      end
    end
  end
  return false
end

function Stack:swapQueued()
  return self.queuedSwapColumn ~= 0 and self.queuedSwapRow ~= 0
end

-- create the initial board
function Stack:starting_state()
  local rowCount = self.panelSource:getStartingBoardHeight(self)
  -- +1 because the new row spawns in row 0 but we want the bottom row of the starting board in row 1
  for i = 1, rowCount + 1 do
    self:new_row()
    self.cur_row = self.cur_row - 1
  end
end

-- Takes the control input from input_state and sets up the engine to start using it.
function Stack:controls()
  local new_dir = nil
  local sdata = self.input_state
  local raise
  if self.inputMethod == "touch" then
    local cursorColumn, cursorRow
    raise, cursorRow, cursorColumn = TouchDataEncoding.latinStringToTouchData(sdata, self.width)
    local canSetCursor = true
    if self.do_countdown then
      if self.animatingCursorDuringCountdown then
        canSetCursor = false
      end
    end

    if canSetCursor then
      if self.cur_col ~= cursorColumn or self.cur_row ~= cursorRow or (cursorColumn == 0 and cursorRow == 0) then
        -- We moved the cursor from a previous column, try to swap
        if self.cur_col ~= 0 and self.cur_row ~= 0 and cursorColumn ~= self.cur_col and cursorRow ~= 0 then
          local panel1 = self.panels[cursorRow][cursorColumn]
          local panel2 = self.panels[self.cur_row][self.cur_col]
          self:tryQueueSwap(panel1, panel2)
        end
        self.cur_col = cursorColumn
        self.cur_row = cursorRow
      end
    end

    -- Make sure we don't set the cursor higher than the top allowed row
    if self.cur_row > 0 and self.cur_row > self.top_cur_row then
      self.cur_row = self.top_cur_row
    end
  else --input method is controller
    local swap, up, down, left, right
    raise, swap, up, down, left, right = unpack(KeyDataEncoding.base64decode[sdata])

    self.swapThisFrame = swap

    if self.swapThisFrame and self:swapQueued() then
      -- swapping is allowed at most every second frame
      -- that is not necessarily a good thing as it can cause stealth attempts to fail due to the swaps being spaced too closely
      --  without the player being aware why it failed, but it's difficult to change at the moment
      -- see https://github.com/panel-attack/panel-game/issues/624
      self.swapThisFrame = false
      self:emitSignal("swapDenied")
    end

    if up then
      new_dir = "up"
    elseif down then
      new_dir = "down"
    elseif left then
      new_dir = "left"
    elseif right then
      new_dir = "right"
    end

    if new_dir == self.cursorDirection then
      if self.cur_timer ~= self.cur_wait_time then
        self.cur_timer = self.cur_timer + 1
      end
    else
      self.cursorDirection = new_dir
      self.cur_timer = 0
    end
  end

  if raise then
    if not self.prevent_manual_raise then
      self.manual_raise = true
      self.manual_raise_yet = false
    end
  end
end

function Stack:shouldRun(runsSoFar)
  if self:game_ended() then
    return false
  end

  if self:behindRollback() then
    return true
  end

  -- Decide how many frames of input we should run.
  local buffer_len = #self.confirmedInput - self.clock

  -- If we are local we always want to catch up and run the new input which is already appended
  if self.is_local then
    return buffer_len > 0
  else
    -- If we are not local, we want to run faster to catch up.
    if buffer_len >= 15 - runsSoFar then
      -- way behind, run at max speed.
      return runsSoFar < self.max_runs_per_frame
    elseif buffer_len >= 10 - runsSoFar then
      -- When we're closer, run fewer times per frame, so things are less choppy.
      -- This might have a side effect of taking a little longer to catch up
      -- since we don't always run at top speed.
      local maxRuns = math.min(2, self.max_runs_per_frame)
      return runsSoFar < maxRuns
    elseif buffer_len >= 1 then
      return runsSoFar == 0
    end
  end

  return false
end

-- Runs one step of the stack.
function Stack:run()
  prof.push("Stack:run")

  if self.is_local == false then
    if self.play_to_end then
      if #self.confirmedInput - self.clock <= 10 then
        self.play_to_end = nil
      end
    end
  end

  --prof.push("Stack:setupInput")
  self:setupInput()
  --prof.pop("Stack:setupInput")


  if self.behaviours.delaySimulationUntil == "countdownEnded" and self.clock <= (consts.COUNTDOWN_START + consts.COUNTDOWN_LENGTH) then
    self:runCountdown()
    if self.clock == (consts.COUNTDOWN_START + consts.COUNTDOWN_LENGTH) then
      self.stopWatchIsRunning = true
    end
  end

  --prof.push("Stack:simulate")
  if self.stopWatchIsRunning then
    self:runPhysics()
  else
    -- these behaviours need to run "half a frame" on their first one to give the first swap the chance to queue to prevent instant game over on the next one
    -- otherwise, if health is 1 and no stop/shake is given and the stack is topped out, passive raise will instakill
    if self.behaviours.delaySimulationUntil == "firstInput" then
      if self.input_state ~= self:idleInput() then
        self.stopWatchIsRunning = true
        -- need to compensate the fact that we increment stopWatch at the end of the frame without having simulated
        self.stopWatch = -1
      end
    elseif self.behaviours.delaySimulationUntil == "firstSwap" then
      if self.swapThisFrame then
        self.stopWatchIsRunning = true
        self.stopWatch = -1
      end
    end
  end

  -- Phase 3. /////////////////////////////////////////////////////////////
  -- Actions performed according to player input

  self:applyCursorDirection(self.cursorDirection)

  --prof.push("new swap")
  -- Queue Swapping
  -- Note: Swapping is queued in Stack.controls for touch mode
  if self.inputMethod == "controller" and self.swapThisFrame then
    local leftPanel = self.panels[self.cur_row][self.cur_col]
    local rightPanel = self.panels[self.cur_row][self.cur_col + 1]
    self:tryQueueSwap(leftPanel, rightPanel)
  end
  --prof.pop("new swap")

  self:handleManualRaise()

  if self.stopWatchIsRunning then
    prof.push("pop from incoming garbage q")
    if self:shouldDropGarbage() then
      self:tryDropGarbage()
    end
    prof.pop("pop from incoming garbage q")
    self.stopWatch = self.stopWatch + 1
  end

  self.clock = self.clock + 1
  --prof.pop("Stack:simulate")
  prof.pop("Stack:run")
  self:emitSignal("finishedRun")
end

local touchIdleInput = TouchDataEncoding.touchDataToLatinString(false, 0, 0, 6)
function Stack:idleInput()
  return (self.inputMethod == "touch" and touchIdleInput) or KeyDataEncoding.base64encode[1]
end

-- Grabs input from the buffer of inputs or from the controller and sends out to the network if needed.
function Stack:setupInput()
  self.input_state = nil

  if self:game_ended() == false then
    self.input_state = self.confirmedInput[self.clock + 1]
  else
    self.input_state = self:idleInput()
  end

  self:controls()
end

function Stack:receiveConfirmedInput(input)
  if utf8.len(input) == 1 then
    self.confirmedInput[#self.confirmedInput+1] = input
  else
    local inputs = string.toCharTable(input)
    tableUtils.appendToList(self.confirmedInput, inputs)
  end
  --logger.debug("Player " .. self.which .. " got new input. Total length: " .. #self.confirmedInput)
end

function Stack:isToppedOut()
  for col = 1, self.width do
    if self.panels[self.height][col]:dangerous() then
      return true
    end
  end
  return false
end

function Stack:updatePanels()
  prof.push("Stack:updatePanels")
  self.shake_time_on_frame = 0
  for row = 1, #self.panels do
    for col = 1, self.width do
      local panel = self.panels[row][col]
      panel:update(self.panels)
    end
  end
  prof.pop("Stack:updatePanels")
end

function Stack:shouldDropGarbage()
  -- this is legit ugly, these should rather be returned in a parameter table
  -- or even better in a dedicated garbage class table
  local garbage = self.incomingGarbage:peek()

  if not garbage then
    return false
  elseif self:isToppedOut() then
    -- new garbage can't drop if the stack is full
    return false
  elseif self:hasFallingGarbage() then
    -- new garbage always drops one by one
    return false
  else
    -- Verify that there are no panels in the way above the stack
    for i = self.height + 1, #self.panels do
      if self.panels[i] then
        for j = 1, self.width do
          if self.panels[i][j] then
            if self.panels[i][j].color ~= 0 then
              -- using warn logging here because of suspicion that this code is never reached
              -- after bulk verification this code was presumably hit for 3 replays out of 18000+ and always found a panel in row 13 column 1
              -- so it has to stay for now but probably worth investigating under which circumstances it does not hit either of the other checks
              logger.warn("Aborting garbage drop: panel found at row " .. tostring(i) .. " column " .. tostring(j))
              return false
            end
          end
        end
      end
    end
  end

  if not self:hasActivePanels() then
    return true
  elseif garbage.isChain then
    -- drop chain garbage higher than 1 row immediately
    return garbage.height > 1
  else
    if garbage.height > 1 then
      -- attackengine garbage higher than 1 (aka chain garbage) is treated as combo garbage
      -- that is to circumvent the garbage queue not allowing to send multiple chains simultaneously
      -- and because of that hack, we need to do another hack here and allow n-height combo garbage
      -- technically garbage should get fixed garbageQueue side though so we should not reach here
      logger.debug("Reached the cursed path")
      return true
    else
      return false
    end
  end
end

-- One run of the engine routine.
function Stack:runPhysics()
  table.clear(self.garbageLandedThisFrame)

  self.wasToppedOut = self:isToppedOut()

  --prof.push("simulate 1")
  self:decrementInvincibilityTimers()
  self:updateRiseLock()
  self:updateSpeed()
  --prof.pop("simulate 1")

  --prof.push("passive raise")
  -- Phase 0 //////////////////////////////////////////////////////////////
  -- Stack automatic rising
  if self.behaviours.passiveRaise then
    if self:advancePassiveRaise() then
      if self:checkGameOver() then
        self:setGameOver()
      end
    end
  end
  --prof.pop("passive raise")

  --prof.push("reset stuff")
  if not self.wasToppedOut and not self:hasFallingGarbage() then
    self.health = self.levelData.maxHealth
  end

  if self.displacement % 16 ~= 0 then
    self.top_cur_row = self.height - 1
  end
  --prof.pop("reset stuff")

  --prof.push("old swap")
  -- Begin the swap we input last frame.
  if self:swapQueued() then
    self:swap(self.queuedSwapRow, self.queuedSwapColumn)
    self.queuedSwapColumn = 0
    self.queuedSwapRow = 0
  end
  --prof.pop("old swap")

  self:checkMatches()
  self:updatePanels()
  self:updateActivePanelCount()
  --prof.push("chain update")
  -- if at the end of the routine there are no chain panels, the chain ends.
  if self.chain_counter ~= 0 and not self:hasChainingPanels() then
    self.chain_counter = 0

    if self.outgoingGarbage then
      logger.debug("Player " .. self.which .. " chain ended at " .. self.stopWatch)
      self.outgoingGarbage:finalizeCurrentChain(self.stopWatch)
    end
  end
  --prof.pop("chain update")

  --prof.push("process staged garbage")
  self.outgoingGarbage:processStagedGarbageForClock(self.stopWatch)
  --prof.pop("process staged garbage")

  self:removeExtraRows()

  if not self:checkGameWin() then
    if self:checkGameOver() then
      self:setGameOver()
    end
  end
end

function Stack:decrementInvincibilityTimers()
  self.prev_shake_time = self.shake_time
  self.shake_time = self.shake_time - 1
  self.shake_time = max(self.shake_time, self.shake_time_on_frame)
  if self.shake_time == 0 then
    self.peak_shake_time = 0
  end

  if self.pre_stop_time ~= 0 then
    self.pre_stop_time = self.pre_stop_time - 1
  elseif self.stop_time ~= 0 then
    self.stop_time = self.stop_time - 1
  end
end

function Stack:handleManualRaise()
  --prof.push("active raise")
  -- MANUAL STACK RAISING
  if self.behaviours.allowManualRaise and self.manual_raise then
    if not self.rise_lock then
      -- no rise lock, the manual raise proceeds in the standard case
      self.stop_time = 0
      if self.wasToppedOut then
        -- why is this game over check needed?
        -- manual raise halts passive raise and only passive raise leads to health reduction
        -- replacing this with health reduction could be a viable alternative
        -- see also: https://github.com/panel-attack/panel-game/issues/437 and comments within checkGameOver itself
        if self:checkGameOver() then
          self:setGameOver()
        end
      else
        self.has_risen = true
        self.displacement = self.displacement - 1
        if self.displacement == 1 then
          if not self.prevent_manual_raise then
            self:addScore(1)
          end
          -- the final decrement of displacement is forcefully deferred to passive raise through these 3 properties
          -- see https://github.com/panel-attack/panel-game/issues/663 for more info
          self.manual_raise = false
          self.rise_timer = 1
          self.prevent_manual_raise = true
        end
        -- this means we started the manual raise and so the manual raise will resume even after a rise lock
        self.manual_raise_yet = true
      end
    elseif not self.manual_raise_yet then
      -- manual raise was pressed but rise lock was already active so the manual raise will never be started
      self.manual_raise = false
    elseif self:hasFallingGarbage() then
      -- the manual raise has been interrupted by falling garbage; in this scenario we don't want the raise to resume afterwards so it is cancelled here
      self.manual_raise = false
      -- falling garbage might result in a topout and trying to finish the raise afterwards would mean instant death the moment shake time runs out
      -- even if there is still stop time or health remaining which is straight up unfair
    end
  -- if the stack is rise locked when you press the raise button,
  -- the raising is suspended
  end
  --prof.pop("active raise")
end

---@param direction CursorDirection?
function Stack:applyCursorDirection(direction)
  --prof.push("cursor movement")
  if self.inputMethod == "touch" then
    --with touch, cursor movement happen at stack:control time
  else
    if direction and (self.cur_timer == 0 or self.cur_timer == self.cur_wait_time) and self.cursorLock == nil then
      local previousRow = self.cur_row
      local previousCol = self.cur_col
      self:moveCursorInDirection(direction)
      self:emitSignal("cursorMoved", previousRow, previousCol)
    else
      self.cur_row = util.bound(1, self.cur_row, self.top_cur_row)
    end
  end

  if self.cur_timer ~= self.cur_wait_time then
    self.cur_timer = self.cur_timer + 1
  end
  --prof.pop("cursor movement")
end

---@param direction CursorDirection
function Stack:moveCursorInDirection(direction)
  self.cur_row = util.bound(1, self.cur_row + DIRECTION_ROW[direction], self.top_cur_row)
  self.cur_col = util.bound(1, self.cur_col + DIRECTION_COLUMN[direction], self.width - 1)
end

function Stack:updateSpeed()
  --prof.push("speed increase")
  -- Increase the speed if applicable
  if self.levelData.speedIncreaseMode == 1 then
    -- increase per interval
    if self.clock == self.nextSpeedIncreaseClock then
      self.speed = min(self.speed + 1, 99)
      self.nextSpeedIncreaseClock = self.nextSpeedIncreaseClock + DT_SPEED_INCREASE
    end
  elseif self.panels_to_speedup <= 0 then
    -- mode 2: increase speed based on cleared panels
    self.speed = min(self.speed + 1, 99)
    self.panels_to_speedup = self.panels_to_speedup + PANELS_TO_NEXT_SPEED[self.speed]
  end
  --prof.pop("speed increase")
end

---@return boolean? # if any raising did indeed happen
function Stack:advancePassiveRaise()
  if self.manual_raise then
    -- handle all of manual raise here sometime in the far future
    -- currently this finishes a raise from the PREVIOUS frame so it may ignore rise_lock
    if self.displacement == 0 and self.has_risen then
      -- edge case that only occurs when manual raise is pressed at displacement = 1 on the previous frame
      -- the addition of the new row is only added on the next frame to guarantee the stack was not topped out at the start of the frame
      -- see https://github.com/panel-attack/panel-game/issues/663 for context why this is exactly here
      self.top_cur_row = self.height
      self:new_row()
    end
  else
    if not self.rise_lock and self.stop_time == 0 then
      if self:isToppedOut() then
        self.health = self.health - 1
      else
        self.rise_timer = self.rise_timer - 1
        if self.rise_timer <= 0 then -- try to rise
          self.displacement = self.displacement - 1
          if self.displacement == 0 then
            self.prevent_manual_raise = false
            self.top_cur_row = self.height
            self:new_row()
          end
          self.rise_timer = self.rise_timer + consts.SPEED_TO_RISE_TIME[self.speed]
        end
      end
      return true
    end
  end
end

function Stack:runCountdown()
  self.do_countdown = true
  self.rise_lock = true
  if self.clock == 0 then
    self.animatingCursorDuringCountdown = true
    if self.engineVersion == consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE then
      self.cursorLock = true
    end
    self.cur_row = self.height - 1
    if self.inputMethod == "touch" then
      self.cur_col = self.width
    elseif self.inputMethod == "controller" then
      self.cur_col = self.width - 1
    end
  elseif self.clock == consts.COUNTDOWN_START then
    self.countdown_timer = consts.COUNTDOWN_LENGTH
  end
  if self.countdown_timer then
    local countDownFrame = consts.COUNTDOWN_LENGTH - self.countdown_timer
    if countDownFrame > 0 and countDownFrame % consts.COUNTDOWN_CURSOR_SPEED == 0 then
      local moveIndex = math.floor(countDownFrame / consts.COUNTDOWN_CURSOR_SPEED)
      if moveIndex <= 4 then
        self:moveCursorInDirection("down")
      elseif moveIndex <= 6 then
        self:moveCursorInDirection("left")

      elseif moveIndex == 10 then
        self.animatingCursorDuringCountdown = nil
        if self.inputMethod == "touch" then
          self.cur_row = 0
          self.cur_col = 0
        end
      end
    elseif countDownFrame == 6 * consts.COUNTDOWN_CURSOR_SPEED + 1 then
      if self.engineVersion == consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE then
        self.cursorLock = nil
      end
    end
    if self.countdown_timer == 0 then
      --we are done counting down
      self.do_countdown = false
      self.countdown_timer = nil
    end
    if self.countdown_timer then
      self.countdown_timer = self.countdown_timer - 1
    end
  end
end

-- Returns true if the stack is simulated past the end of the match.
function Stack:game_ended()
  if self.game_over_clock > 0 then
    return self.clock >= self.game_over_clock
  else
    return self:checkGameWin()
  end
end

-- Sets the current stack as "lost"
-- Also begins drawing game over effects
function Stack:setGameOver()

  if self.game_over_clock > 0 then
    -- it is possible that game over is set twice on the same frame
    -- this happens if someone died to passive raise while holding manual raise
    -- we shouldn't try to set game over again under any other circumstances however
    assert(self.clock == self.game_over_clock, "game over was already set to a different clock time")
    return
  end

  self.game_over_clock = self.clock

  self:emitSignal("gameOver", self)
end

---@param panel1 Panel
---@param panel2 Panel
---@return boolean # if the swap was queued successfully
function Stack:tryQueueSwap(panel1, panel2)
  local canSwap, healthCost = self:canSwap(panel1, panel2)
  if canSwap then
    WigglePay.registerSwap(self, panel1, panel2, healthCost or 0)

    self.swapCount = self.swapCount + 1
    -- by convention, swap column is the left panel
    self.queuedSwapColumn = math.min(panel1.column, panel2.column)
    self.queuedSwapRow = panel1.row
    return true
  else
    self:emitSignal("swapDenied")
    return false
  end
end

---@param panel1 Panel
---@param panel2 Panel
---@return boolean canSwap
---@return integer? healthCost
function Stack:canSwap(panel1, panel2)
  if math.abs(panel1.column - panel2.column) ~= 1 or panel1.row ~= panel2.row then
    -- panels are not horizontally adjacent, can't swap
    return false
  elseif self.do_countdown or self.clock <= 1 then
    -- swapping is not possible during countdown and on the first frame
    return false
  elseif self.stackOverConditions[MatchRules.StackOverConditions.SWAPS] and self.stackOverConditions[MatchRules.StackOverConditions.SWAPS] <= self.swapCount then
    -- used all available moves in a move puzzle
    return false
  elseif panel1.color == 0 and panel2.color == 0 then
    -- can't swap two empty spaces with each other
    return false
  elseif not panel1:allowsSwap() or not panel2:allowsSwap() then
    -- one of the panels can't be swapped based on its state / color / garbage
    return false
  end

  local row = panel1.row

  local panelAbove1
  local panelAbove2

  if row < self.height then
    panelAbove1 = self.panels[row + 1][panel1.column]
    panelAbove2 = self.panels[row + 1][panel2.column]
    -- neither space above us can be hovering
    if panelAbove1.state == "hovering" or panelAbove2.state == "hovering" then
      return false
    end
  end

  --
  -- if either panel inside the cursor is air
  if panel1.color == 0 or panel2.color == 0 then
    if panelAbove1 and panelAbove2
    -- true if BOTH panels above cursor are swapping
    and (panelAbove1.state == "swapping" and panelAbove2.state == "swapping")
    -- these two together are true if 1 panel is air, the other isn't
    and (panelAbove1.color == 0 or panelAbove2.color == 0) and (panelAbove1.color ~= 0 or panelAbove2.color ~= 0) then
      return false
    end
    if row > 1 then
      local panelBelow1 = self.panels[row - 1][panel1.column]
      local panelBelow2 = self.panels[row - 1][panel2.column]
      -- true if BOTH panels below cursor are swapping
      if (panelBelow1.state == "swapping" and panelBelow2.state == "swapping")
      -- these two together are true if 1 panel is air, the other isn't
      and (panelBelow1.color == 0 or panelBelow2.color == 0) and (panelBelow1.color ~= 0 or panelBelow2.color ~= 0) then
        return false
      end
    end
  end

  if self.behaviours.swapStallingMode == 1 then
    return WigglePay.canSwap(self, panel1, panel2)
  else
    return true
  end
end

-- Swaps panels at the current cursor location
function Stack:swap(row, col)
  local panels = self.panels
  local leftPanel = panels[row][col]
  local rightPanel = panels[row][col + 1]
  leftPanel:startSwap(true)
  rightPanel:startSwap(false)
  Panel.switch(leftPanel, rightPanel, panels)
  -- technically they don't have to be reassigned but it makes the code below a bit easier to read
  leftPanel, rightPanel = rightPanel, leftPanel

  self:emitSignal("panelsSwapped")

  -- If you're swapping a panel into a position
  -- above an empty space or above a falling piece
  -- then you can't take it back since it will start falling.
  if row ~= 1 then
    if (leftPanel.color ~= 0) and (panels[row - 1][col].color == 0 or panels[row - 1][col].state == "falling") then
      leftPanel.dont_swap = true
    end
    if (rightPanel.color ~= 0) and (panels[row - 1][col + 1].color == 0 or panels[row - 1][col + 1].state == "falling") then
      rightPanel.dont_swap = true
    end
  end

  -- If you're swapping a blank space under a panel,
  -- then you can't swap it back since the panel should
  -- start falling.
  if row ~= self.height then
    if leftPanel.color == 0 and panels[row + 1][col].color ~= 0 then
      leftPanel.dont_swap = true
    end
    if rightPanel.color == 0 and panels[row + 1][col + 1].color ~= 0 then
      rightPanel.dont_swap = true
    end
  end
end

-- Removes unneeded rows from the top of the stack
function Stack:removeExtraRows()
  --prof.push("removeExtraRows")
  for row = #self.panels, self.height + 1, -1 do
    for col = 1, self.width do
      if self.panels[row][col].color ~= 0 then
        return
      end
    end
    self.panels[row] = nil
  end
  --prof.pop("removeExtraRows")
end

-- tries to drop a width x height garbage.
-- returns true if garbage was dropped, false otherwise
function Stack:tryDropGarbage()
  logger.debug("trying to drop garbage at frame " .. self.stopWatch)

  local garbage = self.incomingGarbage:pop()
  logger.debug(string.format("%d Dropping garbage on stack %d - height %d  width %d  %s", self.stopWatch, self.which, garbage.height, garbage.width, garbage.isMetal and "Metal" or ""))

  self:dropGarbage(garbage.width, garbage.height, garbage.isMetal)

  return true
end

function Stack:getGarbageSpawnColumn(garbageWidth)
  local columns = self.garbageSizeDropColumnMaps[garbageWidth]
  local index = self.currentGarbageDropColumnIndexes[garbageWidth]
  local spawnColumn = columns[index]
  -- the next piece of garbage of that width should fall at a different idx
  self.currentGarbageDropColumnIndexes[garbageWidth] = wrap(1, index + 1, #columns)
  return spawnColumn
end

function Stack:dropGarbage(width, height, isMetal)
  -- garbage always drops in row 13
  local originRow = self.height + 1
  -- combo garbage will alternate it's spawn column
  local originCol = self:getGarbageSpawnColumn(width)
  local function isPartOfGarbage(column)
    return column >= originCol and column < (originCol + width)
  end

  self.garbageCreatedCount = self.garbageCreatedCount + 1
  local shakeTime = self:shakeFramesForGarbageSize(width, height)

  for row = originRow, originRow + height - 1 do
    if not self.panels[row] then
      self.panels[row] = {}
      -- every row that will receive garbage needs to be fully filled up
      -- so iterate from 1 to stack width instead of column to column + width - 1
      for col = 1, self.width do
        local panel = self:createPanelAt(row, col)

        if isPartOfGarbage(col) then
          panel.garbageId = self.garbageCreatedCount
          panel.isGarbage = true
          panel.color = 9
          panel.width = width
          panel.height = height
          panel.y_offset = row - originRow
          panel.x_offset = col - originCol
          panel.shake_time = shakeTime
          panel.state = "falling"
          panel.row = row
          panel.column = col
          if isMetal then
            panel.metal = isMetal
          end
        end
      end
    end
  end
end

-- Adds a new row to the play field
function Stack:new_row()
  local panels = self.panels
  -- move cursor up
  if self.cur_row ~= 0 then
    self.cur_row = util.bound(1, self.cur_row + 1, self.top_cur_row)
  end
  if self.queuedSwapRow > 0 then
    self.queuedSwapRow = self.queuedSwapRow + 1
  end

  -- create new row at the top
  local stackHeight = #panels + 1
  panels[stackHeight] = {}
  self.panelSource:createNewRow(self, stackHeight)

  -- switching the new row downwards for each panel refreshes the properties on all panels to their new row
  for row = stackHeight, 1, -1 do
    for col = #panels[row], 1, -1 do
      Panel.switch(panels[row][col], panels[row - 1][col], panels)
    end
  end

  -- the new row we created earlier at the top is now at row 0!
  -- while the former row 0 is at row 1 and in play, therefore we need to override dimmed state in row 1
  -- this cannot happen in the regular updatePanels routine as checkMatches is called before the update
  -- and the panels already need to be eligible for matches!
  for col = 1, self.width do
    panels[1][col].state = "normal"
    panels[1][col].stateChanged = true
  end

  self.displacement = 16
  self:emitSignal("newRow", self)
end

function Stack:getAttackPatternData()
  local data = {}
  data.attackPatterns = {}
  data.extraInfo = {}
  data.extraInfo.matchLength = " "
  if self.stopWatch > 0 then
    data.extraInfo.matchLength = frames_to_time_string(self.stopWatch)
  else
    -- there is nothing to export!
    return
  end
  local now = os.date("*t", to_UTC(os.time()))
  data.extraInfo.dateGenerated = string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec)

  data.mergeComboMetalQueue = false
  -- TODO: Adjust the export to account for presence of countdown for the delayBeforeStart once it has been moved to a behaviour
  data.delayBeforeStart = 0
  data.delayBeforeRepeat = 91
  local defaultEndTime = 70

  for _, garbage in ipairs(self.outgoingGarbage.history) do
    if garbage.isChain then
      ---@cast garbage ChainGarbage
      if garbage.finalized then
        data.attackPatterns[#data.attackPatterns+1] = {chain = garbage.linkTimes, chainEndTime = garbage.finalizedClock}
      else
        -- chain garbage may not be finalized yet so fake an end time
        data.attackPatterns[#data.attackPatterns+1] = {chain = garbage.linkTimes, chainEndTime = garbage.linkTimes[#garbage.linkTimes] + defaultEndTime}
      end
    else
      data.attackPatterns[#data.attackPatterns+1] = {width = garbage.width, height = garbage.height, startTime = garbage.frameEarned, chain = false, metal = garbage.isMetal}
    end
  end

  if #data.attackPatterns == 0 then
    return
  end

  local state = {keyorder = {"extraInfo", "playerName", "gpm", "matchLength", "dateGenerated", "mergeComboMetalQueue", "delayBeforeStart", "delayBeforeRepeat", "attackPatterns"}}

  return data, state
end

-- creates a new panel at the specified row+column and adds it to the Stack's panels table
---@param row integer
---@param column integer
---@return Panel panel New Panel at the specified row+column that has been added to the Stack's panels table and subscribed to for signals
function Stack:createPanelAt(row, column)
  local panel = self.panelTemplate(row, column)
  self.panels[row][column] = panel
  return panel
end

---@param panel Panel
function Stack:onPop(panel)
  if not panel.isGarbage then
    self:addScore(10)

    self.panels_cleared = self.panels_cleared + 1
    if self.panels_cleared % self.levelData.shockFrequency == 0 then
          self.metalPanelsQueued = min(self.metalPanelsQueued + 1, self.levelData.shockCap)
    end
  end

  self:emitSignal("panelPop", panel)
end

---@param panel Panel
function Stack:onPopped(panel)
  if self.panels_to_speedup then
    self.panels_to_speedup = self.panels_to_speedup - 1
  end
end

---@param panel Panel
function Stack:onLand(panel)
  -- need to emit signal before onGarbageLand because the panel is altered by onGarbageLand
  self:emitSignal("panelLanded", panel)

  if panel.isGarbage then
    self:onGarbageLand(panel)
  end
end

---@param panel Panel
function Stack:onGarbageLand(panel)
  if panel.shake_time
    -- only parts of the garbage that are on the visible board can be considered for shake
    and panel.row <= self.height then
    --runtime optimization to not repeatedly update shaketime for the same piece of garbage
    if not tableUtils.contains(self.garbageLandedThisFrame, panel.garbageId) then
      self.shake_time_on_frame = max(self.shake_time_on_frame, panel.shake_time, self.peak_shake_time or 0)
      --a smaller garbage block landing should renew the largest of the previous blocks' shake times since our shake time was last zero.
      self.peak_shake_time = max(self.shake_time_on_frame, self.peak_shake_time or 0)

      -- to prevent from running this code dozens of time for the same garbage block
      -- all panels of a garbage block have the same id + shake time
      self.garbageLandedThisFrame[#self.garbageLandedThisFrame+1] = panel.garbageId
    end

    -- whether we ran through it or not, the panel should lose its shake time
    panel.shake_time = nil
  end
end

function Stack:hasChainingPanels()
  -- row 0 panels can never chain cause they're dimmed
  for row = 1, #self.panels do
    for col = 1, self.width do
      local panel = self.panels[row][col]
      if panel.chaining and panel.color ~= 0 then
        return true
      end
    end
  end

  return false
end

function Stack:updateActivePanelCount()
  --prof.push("updateActivePanelCount")
  self.n_prev_active_panels = self.n_active_panels
  self.n_active_panels, self.swappingPanelCount = self:getActivePanelCount()
  --prof.pop("updateActivePanelCount")
end

---@return integer activePanelCount
---@return integer swappingPanelCount
function Stack:getActivePanelCount()
  local count = 0
  local swappingCount = 0

  for row = 1, self.height do
    for col = 1, self.width do
      local panel = self.panels[row][col]
      if panel.isGarbage then
        if panel.state ~= "normal" then
          count = count + 1
        end
      else
        if panel.color ~= 0
        -- dimmed is implicitly filtered by only checking in row 1 and up
        and panel.state ~= "normal"
        and panel.state ~= "landing" then
          count = count + 1
          if panel.state == "swapping" then
            swappingCount = swappingCount + 1
          end
        end
      end
    end
  end

  return count, swappingCount
end

function Stack:updateRiseLock()
  local previousRiseLock = self.rise_lock
  if self:swapQueued()then
    self.rise_lock = true
  elseif self.shake_time > 0 then
    self.rise_lock = true
  elseif self:hasActivePanels() then
    self.rise_lock = true
  else
    self.rise_lock = false
  end

  -- prevent manual raise is set true when manually raising
  if previousRiseLock and not self.rise_lock then
    self.prevent_manual_raise = false
  end
end

function Stack:getInfo()
  local info = {}
  info.playerNumber = self.which
  info.inputMethod = self.inputMethod
  info.rollbackCount = self.rollbackCount
  info.rollbackCopyCount = self.rollbackBuffer:getStoredCopyCount()

  return info
end

local function isCompletedChain(garbage)
  return garbage.isChain and garbage.finalized
end

function Stack:checkGameOver()
  if self.game_over_clock <= 0 then
    for stackOverCondition, value in pairs(self.stackOverConditions) do
      if stackOverCondition == MatchRules.StackOverConditions.HEALTH then
        if self.health <= value and self.shake_time <= 0 then
          return true
        elseif not self.rise_lock and self.behaviours.allowManualRaise and self.wasToppedOut and self.manual_raise then
          -- this check is disputable, see https://github.com/panel-attack/panel-game/issues/437
          -- with 1 maxHealth the difference is negligible as clearing out stop time means game over on the next frame if no swap was queued with the raise
          -- but on lower levels it becomes rather easy to accidently kill yourself
          -- this can be viewed as a positive (prepares for level 10 and punishes dangerous use of inputs; one tap -> one entire row, no need to hold down)
          -- but also as a negative (accidently killing yourself in non-threatening circumstances)
          return true
        end
      elseif not self:hasActivePanels() and not self:swapQueued() and self.stopWatchIsRunning then
        if stackOverCondition == MatchRules.StackOverConditions.SWAPS then
          if self.swapCount >= value then
            return true
          end
        elseif stackOverCondition == MatchRules.StackOverConditions.CHAIN then
          if value == false then
            if tableUtils.trueForAny(self.outgoingGarbage.history, isCompletedChain) then
              -- the chain dropped
              return true
            elseif self.panels_cleared > 0 and self.chain_counter == 0 then
              return true
            end
          else
            if self.chain_counter ~= 0 then
              return true
            end
          end
        end
      end
    end
  else
    return true
  end
end

function Stack:checkGameWin()
  for stackWinCondition, value in pairs(self.stackWinConditions) do
    if stackWinCondition == MatchRules.StackWinConditions.MATCHABLE_PANELS then
      local panels = self.panels
      local matchablePanelCount = 0
      for row = 1, self.height do
        for col = 1, self.width do
          local color = panels[row][col].color
          if color ~= 0 and color ~= 9 then
            matchablePanelCount = matchablePanelCount + 1
          end
        end
      end
      if matchablePanelCount <= value then
        return true
      end
    elseif stackWinCondition == MatchRules.StackWinConditions.MATCHABLE_GARBAGE_PANELS then
      if not self:hasMatchableGarbage() then
        return true
      end
    end
  end

  return false
end

-- returns the amount of shake frames for a piece of garbage with the given dimensions
function Stack:shakeFramesForGarbageSize(width, height)
  -- shake time directly scales with the number of panels contained in the garbage
  local panelCount = width * height

  -- sanitization for garbage dimensions has to happen elsewhere (garbage queue?), not here

  if panelCount > #GARBAGE_SIZE_TO_SHAKE_FRAMES then
    return GARBAGE_SIZE_TO_SHAKE_FRAMES[#GARBAGE_SIZE_TO_SHAKE_FRAMES]
  elseif panelCount > 0 then
    return GARBAGE_SIZE_TO_SHAKE_FRAMES[panelCount]
  else
    error("Trying to determine shake time of a garbage block with width " .. width .. " and height " .. height)
  end
end

function Stack:disablePassiveRaise()
  self.behaviours.passiveRaise = false
end

---@return integer
function Stack:getConfirmedInputCount()
  return #self.confirmedInput
end

---@return ReplayStack
function Stack:toReplayStack(stackIndex)
  return {
    stackIndex = stackIndex,
    levelData = self.levelData,
    stackBehaviours = self.behaviours,
    inputMethod = self.inputMethod,
    inputs = InputCompression.compressInputTable(self.confirmedInput),
  }
end

function Stack:deinit()
  -- put allocations used for storing panel information back into the rollbackPanelBuffer
  for i = self.rollbackBuffer.size, 1, -1 do
    if self.rollbackBuffer.buffer[i] then
      for j = #self.rollbackBuffer.buffer[i].panels, 1, -1 do
        rollbackPanelBuffer[#rollbackPanelBuffer+1] = self.rollbackBuffer.buffer[i].panels[j]
      end
    end
  end
end

---@param score integer
function Stack:addScore(score)
  self.score = self.score + score
  if (self.score > 99999) then
    self.score = 99999
  -- lol owned
  end
end

---@param doCountdown boolean
function Stack:setCountdown(doCountdown)
  self.do_countdown = doCountdown
  if doCountdown then
    self.behaviours.delaySimulationUntil = "countdownEnded"
    self.stopWatchIsRunning = false
  else
    if self.behaviours.delaySimulationUntil == "countdownEnded" then
      self.behaviours.delaySimulationUntil = nil
    end
    self.stopWatchIsRunning = not self.behaviours.delaySimulationUntil
  end
end

return Stack