require("common.lib.stringExtensions")
local TouchDataEncoding = require("common.data.TouchDataEncoding")
local consts = require("common.engine.consts")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local util = require("common.lib.util")
local utf8 = require("common.lib.utf8Additions")
local GameModes = require("common.engine.GameModes")
local PanelGenerator = require("common.engine.PanelGenerator")
local BaseStack = require("common.engine.BaseStack")
local class = require("common.lib.class")
local Panel = require("common.engine.Panel")
local prof = require("common.lib.jprof.jprof")
local LevelData = require("common.data.LevelData")
table.clear = require("table.clear")
local ReplayPlayer = require("common.data.ReplayPlayer")
local TouchInputController = require("common.engine.TouchInputController")
local RollbackBuffer = require("common.engine.RollbackBuffer")

-- Stuff defined in this file:
--  . the data structures that store the configuration of
--    the stack of panels
--  . the main game routine
--    (rising, timers, falling, cursor movement, swapping, landing)
--  . the matches-checking routine
local min, pairs = math.min, pairs
local max = math.max

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


---@class Stack : BaseStack
---@field width integer How many columns of panels the stack has
---@field height integer How many rows of panels the stack has
---@field engineVersion string
---@field seed integer
---@field gameOverConditions table Array of enumerated values signifying ways of going game over
---@field gameWinConditions table Array of enumerated values signifying ways of ending the game without going game over
---@field levelData LevelData
---@field allowAdjacentColors boolean if the panel generator is allowed to put panels of the same color next to each other (horizontally only)
---@field allowAdjacentColorsOnStartingBoard boolean if the panel generator is allowed to put panels of the same color next to each other on the starting board
---@field shockEnabled boolean whether shock panels may be queued
---@field behaviours table<string, boolean> a table of toggleable physics behaviours; currently mainly around raise
---@field do_first_row boolean? if the stack still needs to initiate its starting board
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
---@field panel_buffer string alphanumeric string containing a buffer of panels to rise from below; string characters indicate possible metal positions \n
--- will get periodically extended as it gets consumed
---@field gpanel_buffer string numeric string containing a buffer of panels for garbage to turn into upon matching \n
--- will get periodically extended as it gets consumed
---@field inputMethod string "controller" or "touch", determines how inputs are interpreted internally
---@field touchInputController table
---@field confirmedInput string[] All inputs the player has input so far (or ever)
---@field input_state string The input for the current frame
---@field package garbageCreatedCount integer The number of individual garbage blocks created on this stack \n
--- used for giving a unique identifier to each new garbage block
---@field garbageLandedThisFrame integer[] Cache for garbage ids that had panels landing this frame; cleared every frame
---@field highestGarbageIdMatched integer tracks the highest id of garbage matched so far; used for resolving edge cases when matching offscreen garbage
---@field package panelsCreatedCount integer The number of individual panels created on this stack; used for giving new panels their own unique identifier
---@field panels Panel[][] 2 dimensional table for containing all panels \n
--- panel[i] gets the row where i is the index of the row with 1 being the most bottom row that is in play (not dimmed) \n
--- panel[i][j] gets the panel at row i where j is the column index counting from left to right starting from 1 \n
--- the update order for panels is bottom to top and left to right as well
---@field game_stopwatch_running boolean set to false if countdown starts
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
---@field panels_in_top_row boolean If there are panels in the top row of the stack; pre-condition for losing under the NEGATIVE_HEALTH game over condition
---@field n_active_panels integer How many panels are "active" on this frame; active panels prevent the stack from rising
---@field n_prev_active_panels integer How many panels were "active" on the previous frame; previous active panels prevent the stack from rising
---@field manual_raise boolean if true the stack is currently being manually raised; kept true until the raise has been completed
---@field manual_raise_yet boolean if not set, no actual raising has been done yet since manual raise button was pressed \n
--- if a raise is interrupted by rise_lock and the stack has already risen (meaning this is true), manual_raise will stay true and the stack will attempt to raise again even after the raise had been let go \n
--- conversely if the rise_lock happened from the start and the manual_raise never achieved a single tick of displacement of raise, this being false leads to manual_raise being set to false again, effectively cancelling the raise
---@field prevent_manual_raise boolean if set to true it prevents raises initiating another raise; mostly to prevent manual_raise_yet from being overwritten so it can do its cryptic work \n
--- this set of fields can really do with a rework
---@field swap_1 boolean if there was an attempt to initiate a swap via swap1 on this frame
---@field swap_2 boolean if there was an attempt to initiate a swap via swap2 on this frame
---@field cur_wait_time integer DAS delay: number of ticks a movement key has to be held before the cursor begins to move at 1 movement per frame
---@field cur_timer integer number of ticks the current movement key has been held
---@field cur_dir string? direction of the current movement key
---@field cur_row integer row the cursor is on
---@field cur_col integer column the cursor is on
---@field queuedSwapRow integer row in which a swap for next frame has been queued
---@field queuedSwapColumn integer column of the left (or in case of touch the "target") panel for which a swap has been queued for next frame
---@field top_cur_row integer the maximum row index the cursor is allowed to go at the moment
---@field panels_cleared integer How many panels have been cleared on the stack so far; relevant for the occurence of shock panels
---@field metal_panels_queued integer How many shock panels are currently queued up
---@field prev_shake_time integer How many frames of shake time we had last frame; by comparing with the new shake_time it can be determined whether there should be a thud SFX or other things
---@field shake_time integer Invincibility frames earned by a previously off-screen garbage panel transitioning from falling to normal state. Not cumulative. Depletes by 1 each frame.
---@field shake_time_on_frame integer The shake time that would have been earned by falling panels this frame. Overwrites shake_time if greater.
---@field peak_shake_time integer Records the maximum shake time obtained for the current stretch of uninterrupted shake time. \n
--- Any additional shake time gained before shake depletes to 0 will reset shake_time back to this value. Set to 0 when shake_time reaches 0.
---@field panelGenCount integer How many times the panel_buffer was extended; relevant to keep PRNG deterministic for replays
---@field garbageGenCount integer How many times the gpanel_buffer was extended; relevant to keep PRNG deterministic for replays
---@field warningsTriggered table ancient ancient, probably remove
---@field puzzle table? Optional puzzle
---@field game_stopwatch integer? Clock time minus time that swaps were blocked
---@field rollbackBuffer RollbackBuffer
---@field rollbackPanelBuffer Panel[]
---@field panelTemplate (Panel | fun(id: integer, row: integer, column: integer): Panel) A template class based on Panel enriched by tailor made closures containing references to the Stack


-- Represents the full panel stack for one player
---@class Stack : Signal
---@overload fun(arguments: table): Stack
local Stack = class(
---@param s Stack
  function(s, arguments)
    assert(arguments.levelData ~= nil)
    assert(arguments.allowAdjacentColors ~= nil)

    s.gameOverConditions = arguments.gameOverConditions or {GameModes.GameOverConditions.NEGATIVE_HEALTH}
    s.gameWinConditions = arguments.gameWinConditions or {}
    s.engineVersion = arguments.engineVersion
    s.levelData = arguments.levelData
    s.allowAdjacentColors = arguments.allowAdjacentColors
    s.seed = arguments.seed

    -- the behaviour table contains a bunch of flags to modify the stack behaviour for custom game modes in broader chunks of functionality
    s.behaviours = {}
    s.behaviours.passiveRaise = true
    s.behaviours.allowManualRaise = true

    if not s.puzzle then
      s.do_first_row = true
    end

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

    s.inputMethod = arguments.inputMethod
    if s.inputMethod == "touch" then
      s.touchInputController = TouchInputController(s)
    end

    s.panel_buffer = ""
    s.gpanel_buffer = ""
    s.confirmedInput = {}
    s.garbageCreatedCount = 0
    s.garbageLandedThisFrame = {}
    s.highestGarbageIdMatched = 0
    s.panelsCreatedCount = 0
    s.panels = {}
    s.width = 6
    s.height = 12
    s.panelTemplate = s:createPanelTemplate()

    for i = 0, s.height do
      s.panels[i] = {}
      for j = 1, s.width do
        s:createPanelAt(i, j)
      end
    end

    s.game_stopwatch_running = true
    s.max_runs_per_frame = 3

    s.displacement = 16

    s.rise_timer = consts.SPEED_TO_RISE_TIME[s.speed]
    s.rise_lock = false
    s.has_risen = false

    s.stop_time = 0
    s.pre_stop_time = 0

    s.score = 0
    s.chain_counter = 0

    s.panels_in_top_row = false

    s.n_active_panels = 0
    s.n_prev_active_panels = 0

    -- Player input stuff:
    s.manual_raise = false
    s.manual_raise_yet = false
    s.prevent_manual_raise = false
    s.swap_1 = false -- attempt to initiate a swap on this frame
    s.swap_2 = false

    -- number of ticks a movement key has to be held before the cursor begins to move at 1 movement per frame
    s.cur_wait_time = consts.DEFAULT_INPUT_REPEAT_DELAY
    s.cur_timer = 0 -- number of ticks for which a new direction's been pressed
    s.cur_dir = nil -- the direction pressed
    s.cur_row = 7 -- the row the cursor's on
    s.cur_col = 3 -- the column the left half of the cursor's on
    s.queuedSwapColumn = 0 -- the left column of the two columns to swap or 0 if no swap queued
    s.queuedSwapRow = 0 -- the row of the queued swap or 0 if no swap queued
    s.top_cur_row = s.height - 1

    s.panels_cleared = s.panels_cleared or 0
    s.metal_panels_queued = s.metal_panels_queued or 0

    s.prev_shake_time = 0
    s.shake_time = 0
    s.shake_time_on_frame = 0
    s.peak_shake_time = 0

    s.panelGenCount = 0
    s.garbageGenCount = 0

    s.rollbackBuffer = RollbackBuffer(MAX_LAG + 1)
    s.rollbackPanelBuffer = {}
    -- this is a bit of an opportunistic thing:
    -- one issue with rollback is that it allocates a ton of memory while it boots up which in turn accelerates the garbage collector
    -- that creates a situation where more memory is allocated, the GC starts running faster and the odds of having to run double updates for the opponent is high
    -- by preallocating memory for the panels (which is responsible for 90% of rollback memory), the load is less concentrated and stacks are generally more "rollback ready"
    for i = 1, ((s.height + 1) * s.width) * MAX_LAG do
      s.rollbackPanelBuffer[#s.rollbackPanelBuffer+1] = table.new(0, 24)
    end

    s.warningsTriggered = {}

    s:createSignal("matched")
    s:createSignal("panelPop")
    s:createSignal("panelLanded")
    s:createSignal("cursorMoved")
    s:createSignal("panelsSwapped")
    s:createSignal("garbageMatched")
    s:createSignal("newRow")
  end,
  BaseStack
)

Stack.TYPE = "Stack"

---@return (Panel | fun(id: integer, row: integer, column: integer): Panel)
function Stack:createPanelTemplate()
  local panelTemplate = class(function(p, id, row, column) end, Panel)
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
  result = result .. "Panel Buffer " .. stackToTest.panel_buffer .. "\n"

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
        if #self.rollbackPanelBuffer > 0 then
          panelCopy = table.remove(self.rollbackPanelBuffer)
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
      self.rollbackPanelBuffer[#self.rollbackPanelBuffer+1] = copy.panels[i]
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
  copy.game_stopwatch = self.game_stopwatch
  copy.game_stopwatch_running = self.game_stopwatch_running
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
  copy.rise_timer = self.rise_timer
  copy.manual_raise = self.manual_raise
  copy.manual_raise_yet = self.manual_raise_yet
  copy.prevent_manual_raise = self.prevent_manual_raise
  copy.cur_timer = self.cur_timer
  copy.cur_dir = self.cur_dir
  copy.cur_row = self.cur_row
  copy.cur_col = self.cur_col
  copy.shake_time = self.shake_time
  copy.peak_shake_time = self.peak_shake_time
  copy.do_countdown = self.do_countdown
  copy.panel_buffer = self.panel_buffer
  copy.gpanel_buffer = self.gpanel_buffer
  copy.panelGenCount = self.panelGenCount
  copy.garbageGenCount = self.garbageGenCount
  copy.panels_in_top_row = self.panels_in_top_row
  copy.has_risen = self.has_risen
  copy.metal_panels_queued = self.metal_panels_queued
  copy.panels_cleared = self.panels_cleared
  copy.game_over_clock = self.game_over_clock
  copy.highestGarbageIdMatched = self.highestGarbageIdMatched

  for garbageWidth = 1, #self.currentGarbageDropColumnIndexes do
    copy.currentGarbageDropColumnIndexes[garbageWidth] = self.currentGarbageDropColumnIndexes[garbageWidth]
  end

  copy.panelsCreatedCount = self.panelsCreatedCount
  prof.push("rollbackCopyPanels")
  copy.panels = self:rollbackCopyPanels(copy)
  prof.pop("rollbackCopyPanels")

  self.rollbackBuffer:saveCopy(self.clock, copy)
end

local function internalRollbackToFrame(stack, frame)
  local copy = stack.rollbackBuffer:rollbackToFrame(frame)

  if not copy then
    return false
  end

  stack.countdown_timer = copy.countdown_timer
  stack.clock = copy.clock
  stack.game_stopwatch = copy.game_stopwatch
  stack.game_stopwatch_running = copy.game_stopwatch_running
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
  stack.rise_timer = copy.rise_timer
  stack.manual_raise = copy.manual_raise
  stack.manual_raise_yet = copy.manual_raise_yet
  stack.prevent_manual_raise = copy.prevent_manual_raise
  stack.cur_timer = copy.cur_timer
  stack.cur_dir = copy.cur_dir
  stack.cur_row = copy.cur_row
  stack.cur_col = copy.cur_col
  stack.shake_time = copy.shake_time
  stack.peak_shake_time = copy.peak_shake_time
  stack.do_countdown = copy.do_countdown
  stack.panel_buffer = copy.panel_buffer
  stack.gpanel_buffer = copy.gpanel_buffer
  stack.panelGenCount = copy.panelGenCount
  stack.garbageGenCount = copy.garbageGenCount
  stack.panels_in_top_row = copy.panels_in_top_row
  stack.has_risen = copy.has_risen
  stack.metal_panels_queued = copy.metal_panels_queued
  stack.panels_cleared = copy.panels_cleared
  stack.game_over_clock = copy.game_over_clock
  stack.highestGarbageIdMatched = copy.highestGarbageIdMatched
  stack.queuedSwapColumn = copy.queuedSwapColumn
  stack.queuedSwapRow = copy.queuedSwapRow
  stack.speed = copy.speed
  stack.health = copy.health

  -- we can just overwrite using the copied table as the rollbackBuffer discards that table from reuse
  stack.currentGarbageDropColumnIndexes = copy.currentGarbageDropColumnIndexes

  -- roll up the panel copies into the table structure
  for i, panelCopy in ipairs(copy.panels) do
    local row = panelCopy.row
    local column = panelCopy.column

    if stack.panels[row][column] then
      table.clear(stack.panels[row][column])
    else
      stack.panels[row][column] = stack.panelTemplate(panelCopy.id, row, column)
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
  if previousData.clock == frame - 1 then
    stack.prev_shake_time = previousData.shake_time
  else
    -- if this is the oldest rollback frame we don't need to interpolate with previous values
    -- because there are no previous values, pretend it just went down smoothly
    -- this can lead to minor differences in display for the same frame when using rewind
    stack.prev_shake_time = stack.shake_time + 1
  end

  return true
end

---@param frame integer the frame to rollback to if possible
---@return boolean success if rolling back succeeded
function Stack.rollbackToFrame(self, frame)
  local currentFrame = self.clock

  if internalRollbackToFrame(self, frame) then
    if self.incomingGarbage then
      self.incomingGarbage:rollbackToFrame(frame)
    end

    if self.outgoingGarbage then
      self.outgoingGarbage:rollbackToFrame(frame)
    end

    self.rollbackCount = self.rollbackCount + 1
    -- match will try to fast forward this stack to that frame
    self.lastRollbackFrame = currentFrame
    self:emitSignal("rollbackPerformed", self)
    return true
  end

  return false
end

---@param frame integer the frame to rewind to if possible
---@return boolean success if rewinding succeeded
function Stack:rewindToFrame(frame)
  if internalRollbackToFrame(self, frame) then
    if self.incomingGarbage then
      self.incomingGarbage:rewindToFrame(frame)
    end

    if self.outgoingGarbage then
      self.outgoingGarbage:rewindToFrame(frame)
    end

    self:emitSignal("rollbackPerformed", self)
    return true
  end

  return false
end

-- Saves state in backups in case its needed for rollback
-- NOTE: the clock time is the save state for simulating right BEFORE that clock time is simulated
function Stack.saveForRollback(self)
  prof.push("Stack:saveForRollback")
  self:remove_extra_rows()
  prof.push("Stack.rollbackCopy")
  self:rollbackCopy()
  prof.pop("Stack.rollbackCopy")
  prof.push("incomingGarbage:rollbackCopy")
  self.incomingGarbage:rollbackCopy(self.clock)
  prof.pop("incomingGarbage:rollbackCopy")
  prof.push("outgoingGarbage:rollbackCopy")
  if self.outgoingGarbage then
    self.outgoingGarbage:rollbackCopy(self.clock)
  end
  prof.pop("outgoingGarbage:rollbackCopy")
  prof.pop("Stack:saveForRollback")
  self:emitSignal("rollbackSaved", self.clock)
end

-- will throw an error if there is no puzzle set
function Stack:resetPuzzle()
  if not self.puzzle then
    error("Tried to reset puzzle but no puzzle was loaded")
  end

  self:setPuzzleState(self.puzzle)
  self.confirmedInput = {}
  self.clock = 0
  self.game_stopwatch = 0
  self.game_stopwatch_running = false
  self.chain_counter = 0
end

function Stack:setPuzzleState(puzzle)
  puzzle.stack = puzzle:fillMissingPanelsInPuzzleString(self.width, self.height)

  self.puzzle = puzzle
  -- by default row 12 is initially blocked so unblock it for puzzles
  self.top_cur_row = self.height
  self:setPanelsForPuzzleString(puzzle.stack)
  self.do_countdown = puzzle.doCountdown or false
  self.puzzle.remaining_moves = puzzle.moves
  self.behaviours.allowManualRaise = false
  self.behaviours.passiveRaise = false
  self.do_first_row = false

  if puzzle.moves > 0 then
    tableUtils.appendIfNotExists(self.gameOverConditions, GameModes.GameOverConditions.NO_MOVES_LEFT)
  end

  if puzzle.puzzleType == "clear" then
    tableUtils.appendIfNotExists(self.gameOverConditions, GameModes.GameOverConditions.NEGATIVE_HEALTH)
    tableUtils.appendIfNotExists(self.gameWinConditions, GameModes.GameWinConditions.NO_MATCHABLE_GARBAGE)
    -- also fill up the garbage queue so that the stack stays topped out even when downstacking
    local comboStorm = {}
    for i = 1, self.height do
                            --  width        height, metal, from chain
      table.insert(comboStorm, {width = self.width - 1,  height = 1, isChain = false, isMetal = false, frameEarned = 0})
    end
    self.incomingGarbage:pushTable(comboStorm)
  elseif puzzle.puzzleType == "chain" then
    tableUtils.appendIfNotExists(self.gameOverConditions, GameModes.GameOverConditions.CHAIN_DROPPED)
    tableUtils.appendIfNotExists(self.gameWinConditions, GameModes.GameWinConditions.NO_MATCHABLE_PANELS)
  elseif puzzle.puzzleType == "moves" then
    tableUtils.appendIfNotExists(self.gameWinConditions, GameModes.GameWinConditions.NO_MATCHABLE_PANELS)
  end

  -- transform any cleared garbage into colorless garbage panels
  self.gpanel_buffer = "9999999999999999999999999999999999999999999999999999999999999999999999999"
  self.panel_buffer = "9999999999999999999999999999999999999999999999999999999999999999999999999"
end

function Stack.setPanelsForPuzzleString(self, puzzleString)
  local panels = self.panels

  local garbageStartRow = nil
  local garbageStartColumn = nil
  local isMetal = false
  local connectedGarbagePanels = {}
  local rowCount = string.len(puzzleString) / 6
  -- chunk the aprilstack into rows
  -- it is necessary to go bottom up because garbage block panels contain the offset relative to their bottom left corner
  for row = 1, rowCount do
      local rowString = string.sub(puzzleString, #puzzleString - 5, #puzzleString)
      puzzleString = string.sub(puzzleString, 1, #puzzleString - 6)
      -- copy the panels into the row
      panels[row] = {}
      for column = 6, 1, -1 do
          local color = string.sub(rowString, column, column)
          if not garbageStartRow and tonumber(color) then
            local panel = self:createPanelAt(row, column)
            panel.color = tonumber(color)
          else
            -- start of a garbage block
            if color == "]" or color == "}" then
              garbageStartRow = row
              garbageStartColumn = column
              connectedGarbagePanels = {}
              -- use the stack prop to avoid collisions in garbage id
              self.garbageCreatedCount = self.garbageCreatedCount + 1
              if color == "}" then
                isMetal = true
              else
                isMetal = false
              end
            end
            local panel = self:createPanelAt(row, column)
            panel.garbageId = self.garbageCreatedCount
            panel.isGarbage = true
            panel.color = 9
            panel.y_offset = row - garbageStartRow
            -- iterating the row right to left to make sure we catch the start of each garbage block
            -- but the offset is expected left to right, therefore we can't know the x_offset before reaching the end of the garbage
            -- instead save the column index in that field to calculate it later
            panel.x_offset = column
            panel.metal = isMetal
            table.insert(connectedGarbagePanels, panel)
            -- garbage ends here
            if color == "[" or color == "{" then
              -- calculate dimensions of the garbage and add it to the relevant width/height properties
              local height = connectedGarbagePanels[#connectedGarbagePanels].y_offset + 1
              -- this is disregarding the possible existence of irregularly shaped garbage
              local width = garbageStartColumn - column + 1
              local shake_time = self:shakeFramesForGarbageSize(width, height)
              for i = 1, #connectedGarbagePanels do
                connectedGarbagePanels[i].x_offset = connectedGarbagePanels[i].x_offset - column
                connectedGarbagePanels[i].height = height
                connectedGarbagePanels[i].width = width
                connectedGarbagePanels[i].shake_time = shake_time
                connectedGarbagePanels[i].garbageId = self.garbageCreatedCount
                -- panels are already in the main table and they should already be updated by reference
              end
              garbageStartRow = nil
              garbageStartColumn = nil
              connectedGarbagePanels = nil
              isMetal = false
            end
          end
      end
  end

  -- add row 0 because it crashes if there is no row 0 for whatever reason
  panels[0] = {}
  for column = 6, 1, -1 do
    local panel = self:createPanelAt(0, column)
    panel.color = 9
    panel.state = "dimmed"
  end

  -- We need to mark all panels as state changed in case they need to match for clear puzzles / active puzzles.
  for row = 1, self.height do
    for col = 1, self.width do
      panels[row][col].stateChanged = true
      panels[row][col].shake_time = nil
    end
  end
end

function Stack.toPuzzleInfo(self)
  local puzzleInfo = {}
  puzzleInfo["Stop"] = self.stop_time
  puzzleInfo["Shake"] = self.shake_time
  puzzleInfo["Pre-Stop"] = self.pre_stop_time
  puzzleInfo["Stack"] = Puzzle.toPuzzleString(self.panels)

  return puzzleInfo
end

function Stack.hasGarbage(self)
  -- garbage is more likely to be found at the top of the stack
  for row = #self.panels, 1, -1 do
    for column = 1, #self.panels[row] do
      if self.panels[row][column].isGarbage
        and self.panels[row][column].state ~= "matched" then
        return true
      end
    end
  end

  return false
end

function Stack.hasActivePanels(self)
  return self.n_active_panels > 0 or self.n_prev_active_panels > 0
end

function Stack.has_falling_garbage(self)
  for i = 1, self.height + 3 do --we shouldn't have to check quite 3 rows above height, but just to make sure...
    local panelRow = self.panels[i]
    for j = 1, self.width do
      if panelRow and panelRow[j].isGarbage and panelRow[j].state == "falling" then
        return true
      end
    end
  end
  return false
end

function Stack:swapQueued()
  if self.queuedSwapColumn ~= 0 and self.queuedSwapRow ~= 0 then
    return true
  end
  return false
end

function Stack:setQueuedSwapPosition(column, row)
  self.queuedSwapColumn = column
  self.queuedSwapRow = row
end

-- Setup the stack at a new starting state
function Stack.starting_state(self, n)
  if self.do_first_row then
    self.do_first_row = nil
    for i = 1, (n or 8) do
      self:new_row()
      self.cur_row = self.cur_row - 1
    end
  end
end

-- relatively sure this is unused because do_first_row is always nilled by either
--   starting_state (directly above) or
--   PuzzleGame overwriting the prop with false
-- commented out the single use for now
function Stack.prep_first_row(self)
  if self.do_first_row then
    self.do_first_row = nil
    self:new_row()
    self.cur_row = self.cur_row - 1
  end
end

-- Takes the control input from input_state and sets up the engine to start using it.
function Stack.controls(self)
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
          local swapColumn = math.min(self.cur_col, cursorColumn)
          if self:canSwap(cursorRow, swapColumn) then
            self:setQueuedSwapPosition(swapColumn, cursorRow)
          end
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
    raise, swap, up, down, left, right = unpack(base64decode[sdata])

    self.swap_1 = swap
    self.swap_2 = swap

    if up then
      new_dir = "up"
    elseif down then
      new_dir = "down"
    elseif left then
      new_dir = "left"
    elseif right then
      new_dir = "right"
    end

    if new_dir == self.cur_dir then
      if self.cur_timer ~= self.cur_wait_time then
        self.cur_timer = self.cur_timer + 1
      end
    else
      self.cur_dir = new_dir
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
function Stack.run(self)
  prof.push("Stack:run")

  if self.is_local == false then
    if self.play_to_end then
      if #self.confirmedInput - self.clock < 4 then
        self.play_to_end = nil
      end
    end
  end

  prof.push("Stack:setupInput")
  self:setupInput()
  prof.pop("Stack:setupInput")
  prof.push("Stack:simulate")
  self:simulate()
  prof.pop("Stack:simulate")
  prof.pop("Stack:run")
  self:emitSignal("finishedRun")
end

local touchIdleInput = TouchDataEncoding.touchDataToLatinString(false, 0, 0, 6)
function Stack.idleInput(self)
  return (self.inputMethod == "touch" and touchIdleInput) or base64encode[1]
end

-- Grabs input from the buffer of inputs or from the controller and sends out to the network if needed.
function Stack.setupInput(self)
  self.input_state = nil

  if self:game_ended() == false then
    self.input_state = self.confirmedInput[self.clock + 1]
  else
    self.input_state = self:idleInput()
  end

  self:controls()
end

function Stack.receiveConfirmedInput(self, input)
  if utf8.len(input) == 1 then
    self.confirmedInput[#self.confirmedInput+1] = input
  else
    local inputs = string.toCharTable(input)
    tableUtils.appendToList(self.confirmedInput, inputs)
  end
  --logger.debug("Player " .. self.which .. " got new input. Total length: " .. #self.confirmedInput)
end

local d_col = {up = 0, down = 0, left = -1, right = 1}
local d_row = {up = 1, down = -1, left = 0, right = 0}

function Stack.hasPanelsInTopRow(self)
  local panelRow = self.panels[self.height]
  for idx = 1, self.width do
    if panelRow[idx]:dangerous() then
      return true
    end
  end
  return false
end

function Stack.updatePanels(self)
  if self.do_countdown then
    return
  end

  self.shake_time_on_frame = 0
  for row = 1, #self.panels do
    for col = 1, self.width do
      local panel = self.panels[row][col]
      panel:update(self.panels)
    end
  end
end

function Stack.shouldDropGarbage(self)
  -- this is legit ugly, these should rather be returned in a parameter table
  -- or even better in a dedicated garbage class table
  local garbage = self.incomingGarbage:peek()

  -- new garbage can't drop if the stack is full
  -- new garbage always drops one by one
  if not self.panels_in_top_row and not self:has_falling_garbage() then
    if not self:hasActivePanels() then
      return true
    elseif garbage.isChain then
      -- drop chain garbage higher than 1 row immediately
      return garbage.height > 1
    else
      -- attackengine garbage higher than 1 (aka chain garbage) is treated as combo garbage
      -- that is to circumvent the garbage queue not allowing to send multiple chains simultaneously
      -- and because of that hack, we need to do another hack here and allow n-height combo garbage
      -- technically garbage should get fixed garbageQueue side though so we should not reach here
      if garbage.height > 1 then
        logger.debug("Reached the cursed path")
        return true
      else
        return false
      end
    end
  end
end

-- One run of the engine routine.
function Stack.simulate(self)
  prof.push("simulate 1")
  -- self:prep_first_row()
  local panels = self.panels
  local swapped_this_frame = nil
  table.clear(self.garbageLandedThisFrame)
  self:runCountDownIfNeeded()

  if self.pre_stop_time ~= 0 then
    self.pre_stop_time = self.pre_stop_time - 1
  elseif self.stop_time ~= 0 then
    self.stop_time = self.stop_time - 1
  end
  prof.pop("simulate 1")

  prof.push("simulate danger updates")
  self.panels_in_top_row = self:hasPanelsInTopRow()
  prof.pop("simulate danger updates")

  prof.push("new row stuff")
  if self.displacement == 0 and self.has_risen then
    self.top_cur_row = self.height
    self:new_row()
  end

  self:updateRiseLock()
  prof.pop("new row stuff")

  prof.push("speed increase")
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
  prof.pop("speed increase")


  prof.push("passive raise")
  -- Phase 0 //////////////////////////////////////////////////////////////
  -- Stack automatic rising
  if self.behaviours.passiveRaise then
    if not self.manual_raise and self.stop_time == 0 and not self.rise_lock then
      if self.panels_in_top_row then
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
    end

    if self:checkGameOver() then
      self:setGameOver()
    end
  end

  prof.pop("passive raise")

  prof.push("reset stuff")
  if not self.panels_in_top_row and not self:has_falling_garbage() then
    self.health = self.levelData.maxHealth
  end

  if self.displacement % 16 ~= 0 then
    self.top_cur_row = self.height - 1
  end
  prof.pop("reset stuff")

  prof.push("old swap")
  -- Begin the swap we input last frame.
  if self:swapQueued() then
    self:swap(self.queuedSwapRow, self.queuedSwapColumn)
    swapped_this_frame = true
    self:setQueuedSwapPosition(0, 0)
  end
  prof.pop("old swap")

  prof.push("Stack:checkMatches")
  self:checkMatches()
  prof.pop("Stack:checkMatches")
  prof.push("Stack:updatePanels")
  self:updatePanels()
  prof.pop("Stack:updatePanels")

  prof.push("shake time updates")
  self.prev_shake_time = self.shake_time
  self.shake_time = self.shake_time - 1
  self.shake_time = max(self.shake_time, self.shake_time_on_frame)
  if self.shake_time == 0 then
    self.peak_shake_time = 0
  end
  prof.pop("shake time updates")

  -- Phase 3. /////////////////////////////////////////////////////////////
  -- Actions performed according to player input

  prof.push("cursor movement")
  -- CURSOR MOVEMENT
  if self.inputMethod == "touch" then
      --with touch, cursor movement happen at stack:control time
  else
    if self.cur_dir and (self.cur_timer == 0 or self.cur_timer == self.cur_wait_time) and self.cursorLock == nil then
      local previousRow = self.cur_row
      local previousCol = self.cur_col
      self:moveCursorInDirection(self.cur_dir)
      self:emitSignal("cursorMoved", previousRow, previousCol)
    else
      self.cur_row = util.bound(1, self.cur_row, self.top_cur_row)
    end
  end

  if self.cur_timer ~= self.cur_wait_time then
    self.cur_timer = self.cur_timer + 1
  end
  prof.pop("cursor movement")

  prof.push("new swap")
  -- Queue Swapping
  -- Note: Swapping is queued in Stack.controls for touch mode
  if self.inputMethod == "controller" then
    if (self.swap_1 or self.swap_2) and not swapped_this_frame then
      local canSwap = self:canSwap(self.cur_row, self.cur_col)
      if canSwap then
        self:setQueuedSwapPosition(self.cur_col, self.cur_row)
      end
      self.swap_1 = false
      self.swap_2 = false
    end
  end
  prof.pop("new swap")

  prof.push("active raise")
  -- MANUAL STACK RAISING
  if self.behaviours.allowManualRaise then
    if self.manual_raise then
      if not self.rise_lock then
        if self.panels_in_top_row then
          if self:checkGameOver() then
            self:setGameOver()
          end
        else
          self.has_risen = true
          self.displacement = self.displacement - 1
          if self.displacement == 1 then
            self.manual_raise = false
            self.rise_timer = 1
            if not self.prevent_manual_raise then
              self.score = self.score + 1
            end
            self.prevent_manual_raise = true
          end
          self.manual_raise_yet = true --ehhhh
          self.stop_time = 0
        end
      elseif not self.manual_raise_yet then
        self.manual_raise = false
      elseif self:has_falling_garbage() then
        self.manual_raise = false
      end
    -- if the stack is rise locked when you press the raise button,
    -- the raising is cancelled
    end
  end
  prof.pop("active raise")

  prof.push("chain update")
  -- if at the end of the routine there are no chain panels, the chain ends.
  if self.chain_counter ~= 0 and not self:hasChainingPanels() then
    self.chain_counter = 0

    if self.outgoingGarbage then
      logger.debug("Player " .. self.which .. " chain ended at " .. self.clock)
      self.outgoingGarbage:finalizeCurrentChain(self.clock)
    end
  end
  prof.pop("chain update")

  if (self.score > 99999) then
    self.score = 99999
  -- lol owned
  end

  prof.push("updateActivePanels")
  self:updateActivePanels()
  prof.pop("updateActivePanels")

  if self.puzzle and self.n_active_panels == 0 and self.n_prev_active_panels == 0 then
    if self:checkGameOver() then
      self:setGameOver()
    end
  end

  prof.push("process staged garbage")
  self.outgoingGarbage:processStagedGarbageForClock(self.clock)
  prof.pop("process staged garbage")

  prof.push("remove_extra_rows")
  self:remove_extra_rows()
  prof.pop("remove_extra_rows")

  prof.push("double-check panels_in_top_row")
  --double-check panels_in_top_row

  self.panels_in_top_row = false
  -- If any dangerous panels are in the top row, garbage should not fall.
  for col_idx = 1, self.width do
    if panels[self.height][col_idx]:dangerous() then
      self.panels_in_top_row = true
    end
  end
  prof.pop("double-check panels_in_top_row")

  prof.push("doublecheck panels above top row")
  -- If any panels (dangerous or not) are in rows above the top row, garbage should not fall.
  for row_idx = self.height + 1, #self.panels do
    for col_idx = 1, self.width do
      if panels[row_idx][col_idx].color ~= 0 then
        self.panels_in_top_row = true
      end
    end
  end
  prof.pop("doublecheck panels above top row")


  prof.push("pop from incoming garbage q")
  if self.incomingGarbage:len() > 0 then
    if self:shouldDropGarbage() then
      self:tryDropGarbage()
    end
  end
  prof.pop("pop from incoming garbage q")

  prof.push("update times")
  self.clock = self.clock + 1

  if self.game_stopwatch_running then
    self.game_stopwatch = (self.game_stopwatch or -1) + 1
  end
  prof.pop("update times")
end

function Stack:runCountDownIfNeeded()
  if self.do_countdown then
    self.game_stopwatch_running = false
    self.rise_lock = true
    if self.clock == 0 then
      self.animatingCursorDuringCountdown = true
      if self.engineVersion == consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE then
        self.cursorLock = true
      end
      self.cur_row = self.height
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
        self.game_stopwatch_running = true
      end
      if self.countdown_timer then
        self.countdown_timer = self.countdown_timer - 1
      end
    end
  end
end

function Stack:moveCursorInDirection(directionString)
  assert(directionString ~= nil and type(directionString) == "string")
  self.cur_row = util.bound(1, self.cur_row + d_row[directionString], self.top_cur_row)
  self.cur_col = util.bound(1, self.cur_col + d_col[directionString], self.width - 1)
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
function Stack.setGameOver(self)

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

-- returns true if the panel in row/column can be swapped with the panel to its right (column + 1)
function Stack.canSwap(self, row, column)
  local panels = self.panels
  -- in order for a swap to occur, one of the two panels in
  -- the cursor must not be a non-panel.
  local do_swap =
    (panels[row][column].color ~= 0 or panels[row][column + 1].color ~= 0) and -- also, both spaces must be swappable.
    panels[row][column]:canSwap() and
    panels[row][column + 1]:canSwap() and -- also, neither space above us can be hovering.
    (row == #panels or (panels[row + 1][column].state ~= "hovering" and panels[row + 1][column + 1].state ~= "hovering")) and --also, we can't swap if the game countdown isn't finished
    not self.do_countdown and --also, don't swap on the first frame
    not (self.clock and self.clock <= 1)
  -- If you have two pieces stacked vertically, you can't move
  -- both of them to the right or left by swapping with empty space.
  -- TODO: This might be wrong if something lands on a swapping panel?
  if panels[row][column].color == 0 or panels[row][column + 1].color == 0 then -- if either panel inside the cursor is air
    do_swap = do_swap -- failing the condition if we already determined we cant swap 
      and not -- one of the next 4 lines must be false in order to swap
        (row ~= self.height -- true if cursor is not at top of stack
        and (panels[row + 1][column].state == "swapping" and panels[row + 1][column + 1].state == "swapping") -- true if BOTH panels above cursor are swapping
        and (panels[row + 1][column].color == 0 or panels[row + 1][column + 1].color == 0) -- true if either panel above the cursor is air
        and (panels[row + 1][column].color ~= 0 or panels[row + 1][column + 1].color ~= 0)) -- true if either panel above the cursor is not air

    do_swap = do_swap  -- failing the condition if we already determined we cant swap 
      and not -- one of the next 4 lines must be false in order to swap
        (row ~= 1 -- true if the cursor is not at the bottom of the stack
        and (panels[row - 1][column].state == "swapping" and panels[row - 1][column + 1].state == "swapping") -- true if BOTH panels below cursor are swapping
        and (panels[row - 1][column].color == 0 or panels[row - 1][column + 1].color == 0) -- true if either panel below the cursor is air
        and (panels[row - 1][column].color ~= 0 or panels[row - 1][column + 1].color ~= 0)) -- true if either panel below the cursor is not air
  end

  do_swap = do_swap and (not self.puzzle or self.puzzle.moves == 0 or self.puzzle.remaining_moves > 0)

  return do_swap
end

-- Swaps panels at the current cursor location
function Stack:swap(row, col)
  local panels = self.panels
  self:processPuzzleSwap()
  local leftPanel = panels[row][col]
  local rightPanel = panels[row][col + 1]
  leftPanel:startSwap(true)
  rightPanel:startSwap(false)
  Panel.switch(leftPanel, rightPanel, panels)

  self:emitSignal("panelsSwapped")

  -- If you're swapping a panel into a position
  -- above an empty space or above a falling piece
  -- then you can't take it back since it will start falling.
  if row ~= 1 then
    if (panels[row][col].color ~= 0) and (panels[row - 1][col].color == 0 or panels[row - 1][col].state == "falling") then
      panels[row][col].dont_swap = true
    end
    if (panels[row][col + 1].color ~= 0) and (panels[row - 1][col + 1].color == 0 or panels[row - 1][col + 1].state == "falling") then
      panels[row][col + 1].dont_swap = true
    end
  end

  -- If you're swapping a blank space under a panel,
  -- then you can't swap it back since the panel should
  -- start falling.
  if row ~= self.height then
    if panels[row][col].color == 0 and panels[row + 1][col].color ~= 0 then
      panels[row][col].dont_swap = true
    end
    if panels[row][col + 1].color == 0 and panels[row + 1][col + 1].color ~= 0 then
      panels[row][col + 1].dont_swap = true
    end
  end
end

function Stack.processPuzzleSwap(self)
  if self.puzzle then
    if self.puzzle.remaining_moves == self.puzzle.moves and self.puzzle.puzzleType == "clear" then
      -- start depleting stop / shake time
      self.behaviours.passiveRaise = true
      self.stop_time = self.puzzle.stop_time
      self.shake_time = self.puzzle.shake_time
      self.peak_shake_time = self.shake_time
    end
    self.puzzle.remaining_moves = self.puzzle.remaining_moves - 1
  end
end

-- Removes unneeded rows
function Stack.remove_extra_rows(self)
  local panels = self.panels
  for row = #panels, self.height + 1, -1 do
    local nonempty = false
    local panelRow = panels[row]
    for col = 1, self.width do
      nonempty = nonempty or (panelRow[col].color ~= 0)
    end
    if nonempty then
      break
    else
      panels[row] = nil
    end
  end
end

-- tries to drop a width x height garbage.
-- returns true if garbage was dropped, false otherwise
function Stack:tryDropGarbage()
  logger.debug("trying to drop garbage at frame "..self.clock)

  -- Do one last check for panels in the way.
  for i = self.height + 1, #self.panels do
    if self.panels[i] then
      for j = 1, self.width do
        if self.panels[i][j] then
          if self.panels[i][j].color ~= 0 then
            logger.trace("Aborting garbage drop: panel found at row " .. tostring(i) .. " column " .. tostring(j))
            return
          end
        end
      end
    end
  end

  local garbage = self.incomingGarbage:pop()
  logger.debug(string.format("%d Dropping garbage on stack %d - height %d  width %d  %s", self.clock, self.which, garbage.height, garbage.width, garbage.isMetal and "Metal" or ""))

  self:dropGarbage(garbage.width, garbage.height, garbage.isMetal)

  return true
end

function Stack.getGarbageSpawnColumn(self, garbageWidth)
  local columns = self.garbageSizeDropColumnMaps[garbageWidth]
  local index = self.currentGarbageDropColumnIndexes[garbageWidth]
  local spawnColumn = columns[index]
  -- the next piece of garbage of that width should fall at a different idx
  self.currentGarbageDropColumnIndexes[garbageWidth] = wrap(1, index + 1, #columns)
  return spawnColumn
end

function Stack.dropGarbage(self, width, height, isMetal)
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
function Stack.new_row(self)
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

  for col = 1, self.width do
    self:createPanelAt(stackHeight, col)
  end

  -- move panels up
  for row = stackHeight, 1, -1 do
    for col = #panels[row], 1, -1 do
      Panel.switch(panels[row][col], panels[row - 1][col], panels)
    end
  end

  -- the new row we created earlier at the top is now at row 0!
  -- while the former row 0 is at row 1 and in play
  -- therefore we need to override dimmed state in row 1
  -- this cannot happen in the regular updatePanels routine as checkMatches is called after
  -- meaning the panels already need to be eligible for matches!
  for col = 1, self.width do
    panels[1][col].state = "normal"
    panels[1][col].stateChanged = true
  end

  if string.len(self.panel_buffer) <= 10 * self.width then
    self.panel_buffer = self:makePanels()
  end

  -- assign colors to the new row 0
  local metal_panels_this_row = 0
  if self.metal_panels_queued > 3 then
    self.metal_panels_queued = self.metal_panels_queued - 2
    metal_panels_this_row = 2
  elseif self.metal_panels_queued > 0 then
    self.metal_panels_queued = self.metal_panels_queued - 1
    metal_panels_this_row = 1
  end

  for col = 1, self.width do
    local panel = panels[0][col]
    ---@type string | integer
    local this_panel_color = string.sub(self.panel_buffer, col, col)
    --a capital letter for the place where the first shock block should spawn (if earned), and a lower case letter is where a second should spawn (if earned).  (color 8 is metal)
    if tonumber(this_panel_color) then
      --do nothing special
    elseif this_panel_color >= "A" and this_panel_color <= "Z" then
      if metal_panels_this_row > 0 then
        this_panel_color = 8
      else
        this_panel_color = PanelGenerator.PANEL_COLOR_TO_NUMBER[this_panel_color]
      end
    elseif this_panel_color >= "a" and this_panel_color <= "z" then
      if metal_panels_this_row > 1 then
        this_panel_color = 8
      else
        this_panel_color = PanelGenerator.PANEL_COLOR_TO_NUMBER[this_panel_color]
      end
    end
    panel.color = this_panel_color + 0
    panel.state = "dimmed"
  end
  self.panel_buffer = string.sub(self.panel_buffer, 7)
  self.displacement = 16
  if self.inputMethod == "touch" and self.touchInputController then
    self.touchInputController:stackIsCreatingNewRow()
  end
  self:emitSignal("newRow", self)
end

function Stack:getAttackPatternData()
  local data = {}
  data.attackPatterns = {}
  data.extraInfo = {}
  data.extraInfo.matchLength = " "
  if self.game_stopwatch and tonumber(self.game_stopwatch) then
    data.extraInfo.matchLength = frames_to_time_string(self.game_stopwatch)
  end
  local now = os.date("*t", to_UTC(os.time()))
  data.extraInfo.dateGenerated = string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec)

  data.mergeComboMetalQueue = false
  data.delayBeforeStart = 0
  data.delayBeforeRepeat = 91
  local defaultEndTime = 70

  for _, garbage in ipairs(self.outgoingGarbage.history) do
    if garbage.isChain then
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

  local state = {keyorder = {"extraInfo", "playerName", "gpm", "matchLength", "dateGenerated", "mergeComboMetalQueue", "delayBeforeStart", "delayBeforeRepeat", "attackPatterns"}}

  return data, state
end

-- creates a new panel at the specified row+column and adds it to the Stack's panels table
---@param self Stack
---@param row integer
---@param column integer
---@return Panel panel New Panel at the specified row+column that has been added to the Stack's panels table and subscribed to for signals
function Stack.createPanelAt(self, row, column)
  self.panelsCreatedCount = self.panelsCreatedCount + 1
  local panel = self.panelTemplate(self.panelsCreatedCount, row, column)
  self.panels[row][column] = panel
  return panel
end

---@param panel Panel
function Stack.onPop(self, panel)
  if not panel.isGarbage then
    self.score = self.score + 10

    self.panels_cleared = self.panels_cleared + 1
    if self.shockEnabled and self.panels_cleared % self.levelData.shockFrequency == 0 then
          self.metal_panels_queued = min(self.metal_panels_queued + 1, self.levelData.shockCap)
    end
  end

  self:emitSignal("panelPop", panel)
end

---@param panel Panel
function Stack.onPopped(self, panel)
  if self.panels_to_speedup then
    self.panels_to_speedup = self.panels_to_speedup - 1
  end
end

---@param panel Panel
function Stack.onLand(self, panel)
  -- need to emit signal before onGarbageLand because the panel is altered by onGarbageLand
  self:emitSignal("panelLanded", panel)

  if panel.isGarbage then
    self:onGarbageLand(panel)
  end
end

---@param panel Panel
function Stack.onGarbageLand(self, panel)
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

function Stack.hasChainingPanels(self)
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

function Stack.updateActivePanels(self)
  self.n_prev_active_panels = self.n_active_panels
  self.n_active_panels = self:getActivePanelCount()
end

function Stack.getActivePanelCount(self)
  local count = 0

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
        end
      end
    end
  end

  return count
end

function Stack.updateRiseLock(self)
  local previousRiseLock = self.rise_lock
  if self.do_countdown then
    self.rise_lock = true
  elseif self:swapQueued()then
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

function Stack:makePanels()
  PanelGenerator:setSeed(self.seed + self.panelGenCount)
  local ret
  if self.panel_buffer == "" then
    ret = self:makeStartingBoardPanels()
  else
    ret = PanelGenerator.privateGeneratePanels(100, self.width, self.levelData.colors, self.panel_buffer, not self.allowAdjacentColors)
    ret = PanelGenerator.assignMetalLocations(ret, self.width)
  end

  self.panelGenCount = self.panelGenCount + 1

  return ret
end

function Stack:makeStartingBoardPanels()
  local allowAdjacentColors = self.allowAdjacentColorsOnStartingBoard

  local ret = PanelGenerator.privateGeneratePanels(7, self.width, self.levelData.colors, self.panel_buffer, not allowAdjacentColors)
  -- technically there can never be metal on the starting board but we need to call it to advance the RNG (compatibility)
  ret = PanelGenerator.assignMetalLocations(ret, self.width)

  -- legacy crutch, the arcane magic for the non-uniform starting board assumes this is there and it really doesn't work without it
  ret = string.rep("0", self.width) .. ret
  -- arcane magic to get a non-uniform starting board
  ret = procat(ret)
  local maxStartingHeight = 7
  local height = tableUtils.map(procat(string.rep(maxStartingHeight, self.width)), function(s) return tonumber(s) end)
  local to_remove = 2 * self.width
  while to_remove > 0 do
    local idx = PanelGenerator:random(1, self.width) -- pick a random column
    if height[idx] > 0 then
      ret[idx + self.width * (-height[idx] + 8)] = "0" -- delete the topmost panel in this column
      height[idx] = height[idx] - 1
      to_remove = to_remove - 1
    end
  end

  ret = table.concat(ret)
  ret = string.sub(ret, self.width + 1)

  return ret
end

local function isCompletedChain(garbage)
  return garbage.isChain and garbage.finalized
end

function Stack:checkGameOver()
  if self.game_over_clock <= 0 then
    for _, gameOverCondition in ipairs(self.gameOverConditions) do
      if gameOverCondition == GameModes.GameOverConditions.NEGATIVE_HEALTH then
        if self.health <= 0 and self.shake_time <= 0 then
          return true
        elseif not self.rise_lock and self.behaviours.allowManualRaise and self.panels_in_top_row and self.manual_raise then
          return true
        end
      elseif gameOverCondition == GameModes.GameOverConditions.NO_MOVES_LEFT then
        if self.puzzle.remaining_moves <= 0 and not self:hasActivePanels() then
          return true
        end
      elseif gameOverCondition == GameModes.GameOverConditions.CHAIN_DROPPED then
        -- not sure if these actually work as intended after removing analytics
        if not tableUtils.first(self.outgoingGarbage.history, isCompletedChain) and self.panels_cleared > 3 then
          -- We finished matching but never made a chain -> fail
          return true
        end
        if tableUtils.first(self.outgoingGarbage.history, isCompletedChain) and not self:hasChainingPanels() then
          -- We achieved a chain, finished chaining, but haven't won yet -> fail
          return true
        end
      end
    end
  else
    return true
  end
end

function Stack:checkGameWin()
  for _, gameWinCondition in ipairs(self.gameWinConditions) do
    if gameWinCondition == GameModes.GameWinConditions.NO_MATCHABLE_PANELS then
      local panels = self.panels
      local matchablePanelFound = false
      for row = 1, self.height do
        for col = 1, self.width do
          local color = panels[row][col].color
          if color ~= 0 and color ~= 9 then
            matchablePanelFound = true
          end
        end
      end
      if not matchablePanelFound then
        return true
      end
    elseif gameWinCondition == GameModes.GameWinConditions.NO_MATCHABLE_GARBAGE then
      if not self:hasGarbage() then
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

---@return ReplayPlayer
function Stack:toReplayPlayer()
  local replayPlayer = ReplayPlayer("Player " .. self.which, - self.which)
  replayPlayer:setLevelData(self.levelData)
  replayPlayer:setInputMethod(self.inputMethod)
  replayPlayer:setAllowAdjacentColors(self.allowAdjacentColors)

  return replayPlayer
end

---@param replayPlayer ReplayPlayer
---@param replay Replay
---@return Stack
function Stack.createFromReplayPlayer(replayPlayer, replay)
  local args = {
    engineVersion = replay.engineVersion,
    gameOverConditions = replay.gameMode.gameOverConditions,
    gameWinConditions = replay.gameMode.gameWinConditions,
    allowAdjacentColors = replayPlayer.settings.allowAdjacentColors,
    levelData = replayPlayer.settings.levelData,
    is_local = false,
    which = tableUtils.indexOf(replay.players, replayPlayer),
    seed = replay.seed,
    inputMethod = replayPlayer.settings.inputMethod,
  }

  local stack = Stack(args)
  stack:receiveConfirmedInput(replayPlayer.settings.inputs)
  return stack
end

---@param allow boolean
function Stack:setAllowAdjacentColorsOnStartingBoard(allow)
  self.allowAdjacentColorsOnStartingBoard = allow
end

---@param enable boolean
function Stack:enableShockPanels(enable)
  self.shockEnabled = enable
end

return Stack