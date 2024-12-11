local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local PanelGenerator = require("common.engine.PanelGenerator")
local consts = require("common.engine.consts")
local LevelData = require("common.data.LevelData")
local prof = require("common.lib.jprof.jprof")
table.clear = require("table.clear")
table.new = require("table.new")

local COMBO_GARBAGE = {{}, {}, {},
                  --  +4      +5     +6
                      {3},     {4},   {5},
                  --  +7      +8     +9
                      {6},   {3,4}, {4,4},
                  --  +10     +11    +12
                      {5,5}, {5,6}, {6,6},
                  --  +13         +14
                      {6,6,6},  {6,6,6,6},
                 [20]={6,6,6,6,6,6},
                 [27]={6,6,6,6,6,6,6,6}}
for i=1,72 do
  COMBO_GARBAGE[i] = COMBO_GARBAGE[i] or COMBO_GARBAGE[i-1]
end

local function sortByPopOrder(panelList, isGarbage)
  table.sort(panelList, function(a, b)
    if a.row == b.row then
      if isGarbage then
        -- garbage pops right to left
        return a.column > b.column
      else
        -- matches pop left to right
        return a.column < b.column
      end
    else
      if isGarbage then
        -- garbage pops bottom to top
        return a.row < b.row
      else
        -- matches pop top to bottom
        return a.row > b.row
      end
    end
  end)

  return panelList
end

local function getMetalCount(panels)
  local metalCount = 0
  for i = 1, #panels do
    if panels[i].color == 8 then
      metalCount = metalCount + 1
    end
  end
  return metalCount
end

local function isNewChainLink(matchingPanels)
  for _, panel in ipairs(matchingPanels) do
    if panel.chaining then
      return true
    end
  end

  return false
end

local function getOnScreenCount(stackHeight, panels)
  local count = 0
  for i = 1, #panels do
    if panels[i].row <= stackHeight then
      count = count + 1
    end
  end
  return count
end

-- returns true if this panel can be matched
-- false if it cannot be matched
local function canMatch(panel)
  -- panels without colors can't match
  if panel.color == 0 or panel.color == 9 then
    return false
  else
    if panel.state == "normal"
      or panel.state == "landing"
      or (panel.matchAnyway and panel.state == "hovering")  then
      return true
    else
      -- swapping, matched, popping, popped, hover, falling, dimmed, dead
      return false
    end
  end
end

function Stack:checkMatches()
  if self.do_countdown then
    return
  end

  --local reference = self:getMatchingPanels2()
  local matchingPanels = self:getMatchingPanels()
  local comboSize = #matchingPanels

  if comboSize > 0 then
    local frameConstants = self.levelData.frameConstants
    local metalCount = getMetalCount(matchingPanels)
    local isChainLink = isNewChainLink(matchingPanels)
    if isChainLink then
      self:incrementChainCounter()
    end
    -- interrupt any ongoing manual raise
    self.manual_raise = false

    local attackGfxOrigin = self:applyMatchToPanels(matchingPanels, isChainLink, comboSize)
    local garbagePanels = self:getConnectedGarbagePanels2(matchingPanels)
    --local reference = self:getConnectedGarbagePanels(matchingPanels)
    local garbagePanelCountOnScreen = 0
    if garbagePanels then
      logger.debug("Matched " .. comboSize .. " panels, clearing " .. #garbagePanels .. " panels of garbage")
      garbagePanelCountOnScreen = getOnScreenCount(self.height, garbagePanels)
      local garbageMatchTime = frameConstants.FLASH + frameConstants.FACE + frameConstants.POP * (comboSize + garbagePanelCountOnScreen)
      self:matchGarbagePanels(garbagePanels, garbageMatchTime, isChainLink, garbagePanelCountOnScreen)
    end

    local preStopTime = frameConstants.FLASH + frameConstants.FACE + frameConstants.POP * (comboSize + garbagePanelCountOnScreen)
    self.pre_stop_time = math.max(self.pre_stop_time, preStopTime)
    self:awardStopTime(isChainLink, comboSize)
    self:emitSignal("matched", self, attackGfxOrigin, isChainLink, comboSize, metalCount, garbagePanels and #garbagePanels or 0)

    if isChainLink or comboSize > 3 or metalCount > 0 then
      self:pushGarbage(attackGfxOrigin, isChainLink, comboSize, metalCount)
    end
  end

  self:clearChainingFlags()
end

-- getMatchingPanels2 is a reference implementation
-- It is not in use as it is only as fast when jit compiled and slightly slower when not jit compiled in comparison to getMatchingPanels.
-- It is kept around in case we want to try and adopt the meta idea described inside the function.
-- As the new implementation of getConnectedGarbagePanels has proven to be consistently fast,
--  I haven't felt a need to convert the initial panel to garbage match to also use AABB
--  as given the potentially low amount of panels matched each frames it is probably overkill
-- I want to note I don't really get why it is slower as it avoids some double checking 

local candidatePanels2 = table.new(144, 0)

-- gets all panels on the current stack that should match
---@return Panel[] matchingPanels all matchingPanels without duplicates
-----@return Panel[][] matches all individual matches in an array
-----panels in horizontal matches are listed left to right, panels in vertical matches are listed top to bottom
function Stack:getMatchingPanels2()
  local matchingPanels = {}
  local panels = self.panels
  --local matches = {}
  table.clear(candidatePanels2)

  for row = 1, self.height do
    for col = 1, self.width do
      local panel = panels[row][col]
      if panel.stateChanged and canMatch(panel) then
        candidatePanels2[#candidatePanels2 + 1] = panel
      end
    end
  end

  --[[
  idea:
  check the candidate panels for equal counts up and down and left and right
  up+down or left+right >=2 equals a match, the candidatePanel is the third
  to avoid doubles / double checks encode the matching flag whether the panel was matched horizontally or vertically:
  if matching vertically assign 1
  if matching horizontally assign 2
  if matching both vertically and horizontally assign 3
  this way a panel that got marked 1 for a vertical match by another panel does not need to recheck for vertical matches
  that also means we don't need to worry about adding duplicate matches into the matches table

  meta idea:
  we want this function to return individual matches rather than a list of matching panels
  reasoning is that it makes it easier to check for connected garbage because only the box shape without diagonals needs to be checked around each match
  maybe it's unnecessary though and just iterating + distance check is enough because of the finite amount of matched panels
  (or at least I imagine it would already be better than the current flood fill)
  ]]


  local p
  for _, candidatePanel in ipairs(candidatePanels2) do
    -- check vertical match
    local color = candidatePanel.color
    local cRow = candidatePanel.row
    local cCol = candidatePanel.column

    if candidatePanel.matching == nil or (candidatePanel.matching % 2) > 0 then
      local up = 0
      local down = 0

      for row = cRow + 1, self.height do
        p = panels[row][cCol]
        if p.color == color and canMatch(p) then
          up = up + 1
        else
          break
        end
      end

      for row = cRow - 1, 1, -1 do
        p = panels[row][cCol]
        if p.color == color and canMatch(p) then
          down = down + 1
        else
          break
        end
      end

      if up + down >= 2 then
        --local match = {}
        for row = cRow - down, cRow + up do
          local panel = panels[row][cCol]
          --match[#match+1] = panel
          if not panel.matching then
            panel.matching = 1
            matchingPanels[#matchingPanels+1] = panel
          elseif panel.matching == 2 then
            panel.matching = 3
          end
        end
        --matches[#matches + 1] = match
      end
    end


    if not candidatePanel.matching == nil or candidatePanel.matching < 2 then
      local left = 0
      local right = 0

      for col = cCol + 1, self.width do
        p = panels[cRow][col]
        if p.color == color and canMatch(p) then
          right = right + 1
        else
          break
        end
      end

      for col = cCol - 1, 1, -1 do
        p = panels[cRow][col]
        if p.color == color and canMatch(p) then
          left = left + 1
        else
          break
        end
      end

      if left + right >= 2 then
        --local match = {}
        for col = cCol - left, cCol + right do
          local panel = panels[cRow][col]
          --match[#match+1] = panel
          if not panel.matching then
            panel.matching = 2
            matchingPanels[#matchingPanels+1] = panel
          elseif panel.matching == 1 then
            panel.matching = 3
          end
        end
        --matches[#matches + 1] = match
      end
    end

    -- TBD:
    -- if a candidatePanel was found to NOT match mark it with false
    -- that way we can make a distinction between nil == not checked and false == definitely not matching
    -- and define more early exits by abandoning a vertical/horizontal check for another panel of the same color early
    -- if candidatePanel.matching == nil then
    --   candidatePanel.matching = false
    -- end
  end

  for i = 1, #matchingPanels do
    if matchingPanels[i].state == "hovering" then
      -- hovering panels that match can never chain (see Panel.matchAnyway for an explanation)
      matchingPanels[i].chaining = nil
    end
  end

  return matchingPanels--, matches
end

local candidatePanels = table.new(144, 0)
local verticallyConnected = table.new(12, 0)
local horizontallyConnected = table.new(6, 0)

-- returns a table of panels that are forming matches on this frame
function Stack:getMatchingPanels()
  table.clear(candidatePanels)
  local matchingPanels = {}
  local panels = self.panels

  for row = 1, self.height do
    for col = 1, self.width do
      local panel = panels[row][col]
      if panel.stateChanged and canMatch(panel) then
        candidatePanels[#candidatePanels + 1] = panel
      end
    end
  end

  local panel
  for _, candidatePanel in ipairs(candidatePanels) do
    -- check in all 4 directions until we found a panel of a different color
    -- below
    for row = candidatePanel.row - 1, 1, -1 do
      panel = panels[row][candidatePanel.column]
      if panel.color == candidatePanel.color  and canMatch(panel) then
        verticallyConnected[#verticallyConnected + 1] = panel
      else
        break
      end
    end
    -- above
    for row = candidatePanel.row + 1, self.height do
      panel = panels[row][candidatePanel.column]
      if panel.color == candidatePanel.color  and canMatch(panel) then
        verticallyConnected[#verticallyConnected + 1] = panel
      else
        break
      end
    end
    -- to the left
    for column = candidatePanel.column - 1, 1, -1 do
      panel = panels[candidatePanel.row][column]
      if panel.color == candidatePanel.color  and canMatch(panel) then
        horizontallyConnected[#horizontallyConnected + 1] = panel
      else
        break
      end
    end
    -- to the right
    for column = candidatePanel.column + 1, self.width do
      panel = panels[candidatePanel.row][column]
      if panel.color == candidatePanel.color and canMatch(panel) then
        horizontallyConnected[#horizontallyConnected + 1] = panel
      else
        break
      end
    end

    if (#verticallyConnected >= 2 or #horizontallyConnected >= 2) and not candidatePanel.matching then
      matchingPanels[#matchingPanels + 1] = candidatePanel
      candidatePanel.matching = true
    end

    if #verticallyConnected >= 2 then
      -- vertical match
      for j = 1, #verticallyConnected do
        if not verticallyConnected[j].matching then
          verticallyConnected[j].matching = true
          matchingPanels[#matchingPanels + 1] = verticallyConnected[j]
        end
      end
    end
    if #horizontallyConnected >= 2 then
      -- horizontal match
      for j = 1, #horizontallyConnected do
        if not horizontallyConnected[j].matching then
          horizontallyConnected[j].matching = true
          matchingPanels[#matchingPanels + 1] = horizontallyConnected[j]
        end
      end
    end

    -- Clear out the tables for the next iteration
    table.clear(verticallyConnected)
    table.clear(horizontallyConnected)
  end

  for i = 1, #matchingPanels do
    if matchingPanels[i].state == "hovering" then
      -- hovering panels that match can never chain (see Panel.matchAnyway for an explanation)
      matchingPanels[i].chaining = nil
    end
  end

  return matchingPanels
end

function Stack:incrementChainCounter()
  if self.chain_counter ~= 0 then
    self.chain_counter = self.chain_counter + 1
  else
    self.chain_counter = 2
  end
end

function Stack:applyMatchToPanels(matchingPanels, isChain, comboSize)
  matchingPanels = sortByPopOrder(matchingPanels, false)

  for i = 1, comboSize do
    matchingPanels[i]:match(isChain, i, comboSize)
  end

  local firstCellToPop = {row = matchingPanels[1].row, column = matchingPanels[1].column}

  return firstCellToPop
end

---@class AABBGarbage
---@field metal boolean
---@field top integer
---@field left integer
---@field bottom integer
---@field right integer

---@param a AABBGarbage
---@param b AABBGarbage
---@return boolean # if a would match b (or vice versa) if it was matched
--- true if they are both (not) metal and are adjacent to each other,
--- false otherwise
local function matchOnContact(a, b)
  if a.metal == b.metal then
    if a.top == b.bottom - 1 or a.bottom == b.top + 1 then
      -- the matching panel could be vertically touching from below or above
      -- verify vertical contact
        return  (a.left <= b.right and b.left <= a.left) or (b.left <= a.right and a.left <= b.left)
    elseif a.right == b.left - 1 or a.left == b.right + 1 then
      -- the matching panel could be touching horizontally
      -- verify horizontal contact
      return (a.top <= b.bottom and b.top <= a.top) or (b.top <= a.bottom and a.top <= b.top)
    else
      return false
    end
  else
    return false
  end
end

---@param matchingPanels Panel[] non-garbage panels that are matching this frame
---@return Panel[]? matchingGarbagePanels garbage panels that got matched by the matchingPanels; nil if none were matched
function Stack:getConnectedGarbagePanels2(matchingPanels)
  -- array of all garbageIds on the stack
  local garbageIds = {}
  -- records an enum state per garbageId
  local idGarbage = {}
  ---@type AABBGarbage[]
  local garbagePieces = {}

  for row = 1, #self.panels do
    for col = 1, self.width do
      panel = self.panels[row][col]
      if panel.isGarbage and panel.state == "normal" and not idGarbage[panel.garbageId]
      -- we only want to match garbage that is either fully or partially on-screen OR has been on-screen before
      -- example: chain garbage several rows high lands in row 12; by visuals/shake it is clear that it is more than 1 row high
      --   it gets matched, lowest row converts, everything normal until here
      --   if the player manages to make a garbage chain without the chain garbage falling a row it should get matched off-screen
      --   that is because the player KNOWS from the previous match the chain is still there
      -- on the other hand it is also possible to get garbage in row 13 that have contact with a match without ever being seen before:
      -- if garbage spawns in row 13 one frame before the panels in row 11 get elevated to row 12, the garbage "lands" in row 13, becoming matchable
      -- if a match is generated, the match would produce unexpected panels falling with 0 pop time which is unexpected
      --   because there has been no indication the garbage is there
      -- to conclude:
      -- we only want to match the garbage if it either has at least its lowest row on screen OR had been matched by the stack previously
      -- the first part of this condition returns true if any row of the garbage is on-screen
      -- the second part returns true if the garbage was on-screen before due to garbageId only getting generated on spawn
      --   which means there are no higher garbageIds than our offscreen garbage
      --   at the end of this function, self.highestGarbageIdMatched is set to the highest garbageId that was matched
      --   so if the garbage was a repeat match from a chain that got forced off-screen through matching, it will return true and match again
      --  by checking <= it should also take care of training type garbage shapes
      --   where you could possibly push more than 1 piece of narrow high garbage offscreen
      and ((panel.row - panel.y_offset) <= self.height or panel.garbageId <= self.highestGarbageIdMatched) then
        garbageIds[#garbageIds+1] = panel.garbageId
        idGarbage[panel.garbageId] = 1
        garbagePieces[#garbagePieces+1] =
        {
          left = panel.column - panel.x_offset,
          right = panel.column - panel.x_offset + panel.width - 1,
          top = panel.row - panel.y_offset + panel.height - 1,
          bottom = panel.row - panel.y_offset,
          metal = panel.metal
        }
      end
    end
  end

  if #garbageIds > 0 then
    local matchedIds = {}
    local matchedById = {}

    for i, garbageId in ipairs(garbageIds) do
      local garbage = garbagePieces[i]
      for j, matchingPanel in ipairs(matchingPanels) do
        if matchingPanel.row == garbage.bottom - 1 or matchingPanel.row == garbage.top + 1 then
          -- the matching panel could be vertically touching from below or above
          -- verify horizontal contact
          if matchingPanel.column >= garbage.left and matchingPanel.column <= garbage.right then
            -- it's a match!!
            matchedIds[#matchedIds+1] = garbageId
            matchedById[garbageId] = true
          end
        elseif matchingPanel.column == garbage.left - 1 or matchingPanel.column == garbage.right + 1 then
          -- matchingPanel.row >= bottomRow and matchingPanel.row <= topRow
          -- the matching panel is horizontally touching from the left or right
          -- verify horizontal contact
          if matchingPanel.row >= garbage.bottom and matchingPanel.row <= garbage.top then
            -- it's a match!!
            matchedIds[#matchedIds+1] = garbageId
            matchedById[garbageId] = true
          end
        end
      end
    end

    -- early exit in case no garbage was hit
    if #matchedIds > 0 then
      -- defines singular panels
      local garbagePanels = {}
      local garbageMatching = {}

      -- all garbageIds that were matched by non-garbage panels are gathered in matched / matchedById
      -- now we need to tag all garbage in contact with the matched garbage
      -- as garbage touched by our matched garbage will likewise touch other garbage 
      --  we want to know for each piece of garbage to which other piece of garbage it would propagate matched state
      -- so create a reference table for each piece of garbage
      for i = 1, #garbageIds do
        local a = garbagePieces[i]
        local matching = {}
        for j = 1, #garbageIds do
          if j < i then
            -- this collision was already checked for i, just steal it!
            matching[garbageIds[j]] = garbageMatching[garbageIds[j]][garbageIds[i]]
          elseif i ~= j then
            local b = garbagePieces[j]
            matching[garbageIds[j]] = matchOnContact(a, b)
          end
        end
        garbageMatching[garbageIds[i]] = matching
      end

      -- and then use that reference to add pieces referenced by the matched pieces in a self-extending loop until no more can be found
      local i = 1
      local j = #matchedIds
      while i <= j do
        matchedById[matchedIds[i]] = true
        for garbageId, matching in pairs(garbageMatching[matchedIds[i]]) do
          if matching and not matchedById[garbageId] then
            matchedIds[#matchedIds + 1] = garbageId
            matchedById[garbageId] = true
            j = j + 1
          end
        end
        i = i + 1
      end

      -- and then just iterate according to the bounding boxes of each piece of garbage
      for k, garbageId in ipairs(garbageIds) do
        if matchedById[garbageId] then
          local piece = garbagePieces[k]
          for row = piece.bottom, piece.top do
            for col = piece.left, piece.right do
              garbagePanels[#garbagePanels+1] = self.panels[row][col]
            end
          end
        end
      end

      -- finally update the highest garbageId matched so far for the stack
      table.sort(matchedIds)
      if matchedIds[#matchedIds] > self.highestGarbageIdMatched then
        self.highestGarbageIdMatched = matchedIds[#matchedIds]
      end

      return garbagePanels
    end
  end
end

-- returns an integer indexed table of all garbage panels that are connected to the matching panels
-- effectively a more optimized version of the past flood queue approach
function Stack:getConnectedGarbagePanels(matchingPanels)
  local garbagePanels = {}
  local panelsToCheck = Queue()

  local function pushIfNotMatchingAlready(matchingPanel, panelToCheck, matchAll)
    if not panelToCheck.matching then
      if matchAll then
        panelToCheck.matchesMetal = true
        panelToCheck.matchesGarbage = true
      else
        -- We need to "OR" in these flags in case a different path caused a match too
        if matchingPanel.metal then
          panelToCheck.matchesMetal = true
        else
          panelToCheck.matchesGarbage = true
        end
      end

      -- We may add a panel multiple times but it will be "matching" after the first time and skip any work in the loop.
      panelsToCheck:push(panelToCheck)
    end
  end

  for i = 1, #matchingPanels do
    local panel = matchingPanels[i]
    -- Put all panels adjacent to the matching panel into the queue
    -- below
    if panel.row > 1 then
      local panelToCheck = self.panels[panel.row - 1][panel.column]
      pushIfNotMatchingAlready(panel, panelToCheck, true)
    end
    -- above
    if panel.row < #self.panels then
      local panelToCheck = self.panels[panel.row + 1][panel.column]
      pushIfNotMatchingAlready(panel, panelToCheck, true)
    end
    -- to the left
    if panel.column > 1 then
      local panelToCheck = self.panels[panel.row][panel.column - 1]
      pushIfNotMatchingAlready(panel, panelToCheck, true)
    end
    -- to the right
    if panel.column < self.width then
      local panelToCheck = self.panels[panel.row][panel.column + 1]
      pushIfNotMatchingAlready(panel, panelToCheck, true)
    end
  end

  -- any panel in panelsToCheck is guaranteed to be adjacent to a panel that is already matching
  while panelsToCheck:len() > 0 do
    local panel = panelsToCheck:pop()
    -- avoid rechecking a panel already matched
    if not panel.matching then
      if panel.isGarbage and panel.state == "normal"
      -- we only want to match garbage that is either fully or partially on-screen OR has been on-screen before
      -- example: chain garbage several rows high lands in row 12; by visuals/shake it is clear that it is more than 1 row high
      --   it gets matched, lowest row converts, everything normal until here
      --   if the player manages to make a garbage chain without the chain garbage falling a row it should get matched off-screen
      --   that is because the player KNOWS from the previous match the chain is still there
      -- on the other hand it is also possible to get garbage in row 13 that have contact with a match without ever being seen before:
      -- if garbage spawns in row 13 one frame before the panels in row 11 get elevated to row 12, the garbage "lands" in row 13, becoming matchable
      -- if a match is generated, the match would produce unexpected panels falling with 0 pop time which is unexpected
      --   because there has been no indication the garbage is there
      -- to conclude:
      -- we only want to match the garbage if it either has at least its lowest row on screen OR had been matched by the stack previously
      -- the first part of this condition returns true if any row of the garbage is on-screen
      -- the second part returns true if the garbage was on-screen before due to garbageId only getting generated on spawn
      --   which means there are no higher garbageIds than our offscreen garbage
      --   at the end of this function, self.highestGarbageIdMatched is set to the highest garbageId that was matched
      --   so if the garbage was a repeat match from a chain that got forced off-screen through matching, it will return true and match again
      --  by checking <= it should also take care of training type garbage shapes
      --   where you could possibly push more than 1 piece of narrow high garbage offscreen
      and ((panel.row - panel.y_offset) <= self.height or panel.garbageId <= self.highestGarbageIdMatched) then
        if (panel.metal and panel.matchesMetal) or (not panel.metal and panel.matchesGarbage) then
          -- if a panel is adjacent to a matching non-garbage panel or a matching garbage panel of the same type, 
          -- it should match too
          panel.matching = true
          garbagePanels[#garbagePanels + 1] = panel

          -- additionally all non-matching panels adjacent to the new garbage panel get added to the queue
          -- pushIfNotMatchingAlready sets a flag which garbage type can match
          if panel.row > 1 then
            local panelToCheck = self.panels[panel.row - 1][panel.column]
            pushIfNotMatchingAlready(panel, panelToCheck)
          end

          if panel.row < #self.panels then
            local panelToCheck = self.panels[panel.row + 1][panel.column]
            pushIfNotMatchingAlready(panel, panelToCheck)
          end

          if panel.column > 1 then
            local panelToCheck = self.panels[panel.row][panel.column - 1]
            pushIfNotMatchingAlready(panel, panelToCheck)
          end

          if panel.column < self.width then
            local panelToCheck = self.panels[panel.row][panel.column + 1]
            pushIfNotMatchingAlready(panel, panelToCheck)
          end
        end
      end
    end
    -- repeat until we can no longer add new panels to the queue because all adjacent panels to our matching ones
    -- are either matching already or non-garbage panels or garbage panels of the other type
  end

  -- update the highest garbageId matched so far for the stack
  for i, garbagePanel in ipairs(garbagePanels) do
    if garbagePanel.garbageId > self.highestGarbageIdMatched then
      self.highestGarbageIdMatched = garbagePanel.garbageId
    end
  end

  return garbagePanels
end

function Stack:matchGarbagePanels(garbagePanels, garbageMatchTime, isChain, onScreenCount)
  garbagePanels = sortByPopOrder(garbagePanels, true)

  self:emitSignal("garbageMatched", #garbagePanels, onScreenCount)

  for i = 1, #garbagePanels do
    local panel = garbagePanels[i]
    panel.y_offset = panel.y_offset - 1
    panel.height = panel.height - 1
    panel.state = "matched"
    panel:setTimer(garbageMatchTime + 1)
    panel.initial_time = garbageMatchTime
    -- these two may end up with nonsense values for off-screen garbage but it doesn't matter
    panel.pop_time = self.levelData.frameConstants.POP * (onScreenCount - i)
    panel.pop_index = math.min(i, 10)
  end

  self:convertGarbagePanels(isChain)
end

-- checks the stack for garbage panels that have a negative y offset and assigns them a color from the gpanel_buffer
function Stack:convertGarbagePanels(isChain)
  -- color assignments are done per row so we need to iterate the stack properly
  for row = 1, #self.panels do
    local garbagePanelRow = nil
    for column = 1, self.width do
      local panel = self.panels[row][column]
      if panel.y_offset == -1 and panel.color == 9 then
        -- the bottom row of the garbage piece is about to transform into panels
        if garbagePanelRow == nil then
          garbagePanelRow = self:getGarbagePanelRow()
        end
        panel.color = string.sub(garbagePanelRow, column, column) + 0
        if isChain then
          panel.chaining = true
        end
      end
    end
  end
end

function Stack:refillGarbagePanelBuffer()
  PanelGenerator:setSeed(self.match.seed + self.garbageGenCount)
  -- privateGeneratePanels already appends to the existing self.gpanel_buffer
  local garbagePanels = PanelGenerator.privateGeneratePanels(20, self.width, self.levelData.colors, self.gpanel_buffer, not self.allowAdjacentColors)
  -- and then we append that result to the remaining buffer
  self.gpanel_buffer = self.gpanel_buffer .. garbagePanels
  -- that means the next 10 rows of garbage will use the same colors as the 10 rows after
  -- that's a bug but it cannot be fixed without breaking replays
  -- it is also hard to abuse as 
  -- a) players would need to accurately track the 10 row cycles
  -- b) "solve into the same thing" only applies to a limited degree:
  --   a garbage panel row of 123456 solves into 1234 for ====00 but into 3456 for 00====
  --   that means information may be incomplete and partial memorization may prove unreliable
  -- c) garbage panels change every (10 + n * 20 rows) with n>0 in ℕ 
  --    so the player needs to always survive 20 rows to start abusing
  --    and can then only abuse for every 10 rows out of 20
  -- overall it is to be expected that the strain of trying to memorize outweighs the gains
  -- this bug should be fixed with the next breaking change to the engine

  self.garbageGenCount = self.garbageGenCount + 1
end

function Stack:getGarbagePanelRow()
  if string.len(self.gpanel_buffer) <= 10 * self.width then
    self:refillGarbagePanelBuffer()
  end
  local garbagePanelRow = string.sub(self.gpanel_buffer, 1, 6)
  self.gpanel_buffer = string.sub(self.gpanel_buffer, 7)
  return garbagePanelRow
end

function Stack:pushGarbage(coordinate, isChain, comboSize, metalCount)
  logger.debug("P" .. self.which .. "@" .. self.clock .. ": Pushing garbage for " .. (isChain and "chain" or "combo") .. " with " .. comboSize .. " panels")
  for i = 3, metalCount do
    self.outgoingGarbage:push({
      width = 6,
      height = 1,
      isMetal = true,
      isChain = false,
      frameEarned = self.clock,
      rowEarned = coordinate.row,
      colEarned = coordinate.column
    })
  end

  local combo_pieces = COMBO_GARBAGE[comboSize]
  for i = 1, #combo_pieces do
    -- Give out combo garbage based on the lookup table, even if we already made shock garbage,
    self.outgoingGarbage:push({
      width = combo_pieces[i],
      height = 1,
      isMetal = false,
      isChain = false,
      frameEarned = self.clock,
      rowEarned = coordinate.row,
      colEarned = coordinate.column
    })
  end

  if isChain then
    local rowOffset = 0
    if #combo_pieces > 0 then
      -- If we did a combo also, we need to enqueue the attack graphic one row higher cause thats where the chain card will be.
      rowOffset = 1
    end
    self.outgoingGarbage:addChainLink(self.clock, coordinate.column, coordinate.row +  rowOffset)
  end
end

-- calculates the stoptime that would be awarded for a certain chain/combo based on the stack's settings
function Stack:calculateStopTime(comboSize, toppedOut, isChain, chainCounter)
  local stopTime = 0
  local stop = self.levelData.stop
  if comboSize > 3 or isChain then
    if toppedOut and isChain then
      if stop.formula == LevelData.STOP_FORMULAS.MODERN then
        local length = (chainCounter > 4) and 6 or chainCounter
        stopTime = stop.dangerConstant + (length - 1) * stop.dangerCoefficient
      elseif stop.formula == LevelData.STOP_FORMULAS.CLASSIC then
        stopTime = stop.dangerConstant
      end
    elseif toppedOut then
      if stop.formula == LevelData.STOP_FORMULAS.MODERN then
        local length = (comboSize < 9) and 2 or 3
        stopTime = stop.coefficient * length + stop.chainConstant
      elseif stop.formula == LevelData.STOP_FORMULAS.CLASSIC then
        stopTime = stop.dangerConstant
      end
    elseif isChain then
      if stop.formula == LevelData.STOP_FORMULAS.MODERN then
        local length = math.min(chainCounter, 13)
        stopTime = stop.coefficient * length + stop.chainConstant
      elseif stop.formula == LevelData.STOP_FORMULAS.CLASSIC then
        stopTime = stop.chainConstant
      end
    else
      if stop.formula == LevelData.STOP_FORMULAS.MODERN then
        stopTime = stop.coefficient * comboSize + stop.comboConstant
      elseif stop.formula == LevelData.STOP_FORMULAS.CLASSIC then
        stopTime = stop.comboConstant
      end
    end
  end

  return stopTime
end

function Stack:awardStopTime(isChain, comboSize)
  local stopTime = self:calculateStopTime(comboSize, self.panels_in_top_row, isChain, self.chain_counter)
  if stopTime > self.stop_time then
    self.stop_time = stopTime
  end
end

function Stack:clearChainingFlags()
  -- offscreen garbage clearing into chaining panels is support for chains
  -- but as it is chain garbage, the panelgen will prevent any extra RNG garbage chains from occuring beyond self.height + 1
  -- that is because panels in row 13 cannot be swapped by the player to line up with a panel above
  -- which in turn makes the maximum row to encounter chaining panels that may need to be cleared self.height + 2
  for row = 1, math.min(#self.panels, self.height + 2) do
    for column = 1, self.width do
      local panel = self.panels[row][column]
      -- if a chaining panel wasn't matched but was eligible, we have to remove its chain flag
      if not panel.matching and panel.chaining and not panel.matchAnyway and (canMatch(panel) or panel.color == 9) then
        if row > 1 then
          -- no swapping panel below so this panel loses its chain flag
          if self.panels[row - 1][column].state ~= "swapping" then
            panel.chaining = nil
          end
          -- a panel landed on the bottom row, so it surely loses its chain flag.
        else
          panel.chaining = nil
        end
      end
    end
  end
end