-- Shared building blocks for the room-create scenes (Team / FFA).
--
-- Each factory returns a ui.MenuItem that binds a row of the create form to
-- a field on the supplied prefs blob (config.lobbyTeamPrefs or
-- config.lobbyFfaPrefs). Changes flow straight into the blob, so the next
-- time the scene is opened the user's last picks are pre-selected.
--
-- Visual selected state inside a ButtonGroup is handled manually here (set
-- button.selected directly) because ui.ButtonGroup only updates the deprecated
-- backgroundColor field, which ui.Button:drawBackground no longer reads.
--
-- Tooltips: every factory accepts an optional `tooltip` setter. The row
-- updates tooltip text both on initial focus (MenuItem.onSelectedFunction)
-- and on value-change (ButtonGroup.onChange). The owning scene reads
-- self.tooltip in drawSelf to render the bottom hint bar.

local ui = require("client.src.ui")
local tableUtils = require("common.lib.tableUtils")
local GameModes = require("common.data.GameModes")

local RoomCreateRows = {}

-- FFA mode IDs by player count. Mirrored from the FFA cascade in Lobby.lua;
-- keep in sync when modes are added/removed.
RoomCreateRows.FFA_MODES = {
  [3] = { allModeId = "THREE_PLAYER_FFA", sharedModeId = "THREE_PLAYER_FFA_SHARED" },
  [4] = { allModeId = "FOUR_PLAYER_FFA",  sharedModeId = "FOUR_PLAYER_FFA_SHARED" },
  [5] = { allModeId = "FIVE_PLAYER_FFA",  sharedModeId = "FIVE_PLAYER_FFA_SHARED" },
  [7] = { allModeId = "SEVEN_PLAYER_FFA", sharedModeId = "SEVEN_PLAYER_FFA_SHARED" },
}

-- Team composition data, mirrored from Lobby.lua's TEAM_DIVISIONS.
-- The two must stay in sync — keep this small and update both when adding
-- new compositions.
RoomCreateRows.TEAM_DIVISIONS = {
  [3] = {
    { label = "1 vs 2", allModeId = "THREE_PLAYER_VS_ALL",        sharedModeId = "THREE_PLAYER_VS_SHARED" },
    { label = "2 vs 1", allModeId = "THREE_PLAYER_VS_ALL_2V1",    sharedModeId = "THREE_PLAYER_VS_SHARED_2V1" },
  },
  [4] = {
    { label = "2 vs 2", allModeId = "FOUR_PLAYER_TEAM_VS_ALL",    sharedModeId = "FOUR_PLAYER_TEAM_VS_SHARED" },
    { label = "1 vs 3", allModeId = "FOUR_PLAYER_1V3_ALL",        sharedModeId = "FOUR_PLAYER_1V3_SHARED" },
    { label = "3 vs 1", allModeId = "FOUR_PLAYER_3V1_ALL",        sharedModeId = "FOUR_PLAYER_3V1_SHARED" },
  },
  [5] = {
    { label = "1 vs 4", allModeId = "FIVE_PLAYER_1V4_ALL",        sharedModeId = "FIVE_PLAYER_1V4_SHARED" },
    { label = "4 vs 1", allModeId = "FIVE_PLAYER_4V1_ALL",        sharedModeId = "FIVE_PLAYER_4V1_SHARED" },
    { label = "2 vs 3", allModeId = "FIVE_PLAYER_2V3_ALL",        sharedModeId = "FIVE_PLAYER_2V3_SHARED" },
    { label = "3 vs 2", allModeId = "FIVE_PLAYER_3V2_ALL",        sharedModeId = "FIVE_PLAYER_3V2_SHARED" },
  },
  [6] = {
    { label = "3 vs 3", allModeId = "SIX_PLAYER_3V3_ALL",         sharedModeId = "SIX_PLAYER_3V3_SHARED" },
    { label = "1 vs 5", allModeId = "SIX_PLAYER_1V5_ALL",         sharedModeId = "SIX_PLAYER_1V5_SHARED" },
    { label = "5 vs 1", allModeId = "SIX_PLAYER_5V1_ALL",         sharedModeId = "SIX_PLAYER_5V1_SHARED" },
    { label = "2 vs 4", allModeId = "SIX_PLAYER_2V4_ALL",         sharedModeId = "SIX_PLAYER_2V4_SHARED" },
    { label = "4 vs 2", allModeId = "SIX_PLAYER_4V2_ALL",         sharedModeId = "SIX_PLAYER_4V2_SHARED" },
  },
  [7] = {
    { label = "3 vs 4", allModeId = "SEVEN_PLAYER_3V4_ALL",       sharedModeId = "SEVEN_PLAYER_3V4_SHARED" },
    { label = "4 vs 3", allModeId = "SEVEN_PLAYER_4V3_ALL",       sharedModeId = "SEVEN_PLAYER_4V3_SHARED" },
    { label = "2 vs 5", allModeId = "SEVEN_PLAYER_2V5_ALL",       sharedModeId = "SEVEN_PLAYER_2V5_SHARED" },
    { label = "5 vs 2", allModeId = "SEVEN_PLAYER_5V2_ALL",       sharedModeId = "SEVEN_PLAYER_5V2_SHARED" },
    { label = "1 vs 6", allModeId = "SEVEN_PLAYER_1V6_ALL",       sharedModeId = "SEVEN_PLAYER_1V6_SHARED" },
    { label = "6 vs 1", allModeId = "SEVEN_PLAYER_6V1_ALL",       sharedModeId = "SEVEN_PLAYER_6V1_SHARED" },
  },
}

function RoomCreateRows.resolveTeamDivision(playerCount, label)
  local divisions = RoomCreateRows.TEAM_DIVISIONS[playerCount]
  if not divisions then return nil end
  for _, div in ipairs(divisions) do
    if div.label == label then return div end
  end
  return nil
end

function RoomCreateRows.defaultCompositionFor(playerCount)
  local divisions = RoomCreateRows.TEAM_DIVISIONS[playerCount]
  if divisions and divisions[1] then return divisions[1].label end
  return nil
end

-- Resolve a game-mode ID into the request payload the server expects.
-- Bounds depend on type:
--   * Open FFA: 2 minimum, up to count.
--   * Open Team: teamCount minimum (one body per team). Server uses
--     TeamUtils.createTeamsFromFilledSlots for partial rosters so an Open
--     2v2 can run 1v1 with the remaining seats open for drop-in.
--   * Invite-only: always min == max (fixed roster).
-- Mirrors getRoomModeWithRosterBounds in Lobby.lua.
function RoomCreateRows.resolveGameMode(modeId, openRoom)
  if type(modeId) ~= "string" then return nil end
  local ok, mode = pcall(GameModes.getPreset, modeId)
  if not ok or not mode then return nil end

  local count = tonumber(mode.playerCount) or tonumber(mode.maxPlayers) or tonumber(mode.minPlayers) or 2
  count = math.max(2, math.floor(count))

  local isFfa = (mode.playersPerTeam == 1)
  if openRoom and isFfa then
    mode.minPlayers = 2
    mode.maxPlayers = count
  elseif openRoom then
    mode.minPlayers = tonumber(mode.teamCount) or 2
    mode.maxPlayers = count
  else
    mode.minPlayers = count
    mode.maxPlayers = count
  end
  return mode
end

-- Visually mark which button in the group is selected. ui.ButtonGroup writes
-- to button.backgroundColor (deprecated path); ui.Button:drawBackground reads
-- self.selected to swap between menuSelected and menuDefault theme colors —
-- so flip selected on every button to match the group's selectedIndex.
local function refreshGroupSelectedState(group)
  for i, btn in ipairs(group.buttons) do
    btn:setSelected(i == group.selectedIndex)
  end
end

-- Build a ButtonGroup with descriptions and wire up:
--   - prefs[field] = new value on selection
--   - per-button .selected toggling (so the highlight actually shows up)
--   - tooltip update from descriptions[value] (if tooltipFn provided)
-- buttons = { {label, value, description?}, ... }
local function buttonGroup(prefs, field, buttons, tooltipFn)
  local selectedIndex = 1
  for i, b in ipairs(buttons) do
    if prefs[field] == b.value then selectedIndex = i; break end
  end
  local descriptions = {}
  for _, b in ipairs(buttons) do descriptions[b.value] = b.description or "" end

  local btns = tableUtils.map(buttons, function(b)
    return ui.TextButton({label = ui.Label({text = b.label, translate = false})})
  end)
  local group = ui.ButtonGroup({
    buttons = btns,
    values = tableUtils.map(buttons, function(b) return b.value end),
    selectedIndex = selectedIndex,
    onChange = function(g, value)
      GAME.theme:playMoveSfx()
      prefs[field] = value
      refreshGroupSelectedState(g)
      if tooltipFn then tooltipFn(descriptions[value] or "") end
    end,
  })
  refreshGroupSelectedState(group)
  group._descriptions = descriptions
  group._field = field
  group._prefs = prefs
  return group
end

-- Attach an onSelectedFunction to a MenuItem so the tooltip updates when
-- the row gains keyboard focus (mirrors the cascade's setSelected-override
-- pattern). The group inside the row carries the descriptions table the
-- buttonGroup helper stashed there.
local function attachRowTooltip(menuItem, group, tooltipFn)
  if not tooltipFn then return end
  menuItem.onSelectedFunction = function()
    local descriptions = group._descriptions or {}
    local value = group._prefs[group._field]
    tooltipFn(descriptions[value] or "")
  end
end

---@param prefs table
---@param tooltipFn (fun(text: string))?
---@return MenuItem
function RoomCreateRows.createTypeRow(prefs, tooltipFn)
  local group = buttonGroup(prefs, "type", {
    { label = "Invite-only", value = "invite",
      description = "Invite-only: closed room. You invite specific players to fill every seat; the match starts once everyone's seated and ready." },
    { label = "Open",        value = "open",
      description = "Open: public room — anyone in the lobby can drop in. FFA starts when 2 players are ready; team rooms still need the full roster." },
  }, tooltipFn)
  local item = ui.MenuItem.createToggleButtonGroupMenuItem("Room type", nil, false, group)
  attachRowTooltip(item, group, tooltipFn)
  return item
end

---@param prefs table
---@param tooltipFn (fun(text: string))?
---@return MenuItem
function RoomCreateRows.createGarbageRow(prefs, tooltipFn)
  local group = buttonGroup(prefs, "garbage", {
    { label = "Broadcast",   value = "all",
      description = "Broadcast: your attack is cloned to every enemy. Total damage scales with enemy count — combos hit twice in 2v2." },
    { label = "Round Robin", value = "shared",
      description = "Round Robin: attacks rotate through enemies one at a time. Team-wide rotation counter, even fan-out, output rate stays the same regardless of enemy count." },
  }, tooltipFn)
  local item = ui.MenuItem.createToggleButtonGroupMenuItem("Garbage", nil, false, group)
  attachRowTooltip(item, group, tooltipFn)
  return item
end

---@param prefs table
---@param tooltipFn (fun(text: string))?
---@return MenuItem
function RoomCreateRows.createLatencyRow(prefs, tooltipFn)
  local group = buttonGroup(prefs, "latency", {
    { label = "Strict",  value = "strict",
      description = "Strict: tight timing. 100ms simultaneous-KO window, 500ms reaction floor, 20-30s connection timeout. Best on LAN / same-region fiber." },
    { label = "Normal",  value = "normal",
      description = "Normal: balanced. 200ms simultaneous-KO window, 750ms reaction floor, 45-60s connection timeout. Sensible default." },
    { label = "Relaxed", value = "relaxed",
      description = "Relaxed: forgiving. 400ms simultaneous-KO window, 1s reaction floor, 90-120s connection timeout. Best for international / unstable connections." },
  }, tooltipFn)
  local item = ui.MenuItem.createToggleButtonGroupMenuItem("Latency", nil, false, group)
  attachRowTooltip(item, group, tooltipFn)
  return item
end

-- Player-count row. `allowedCounts` is an ordered list (e.g. {3,4,5} for
-- team, {3,4,5,7} for FFA). `onChange(newCount)` is invoked AFTER the prefs
-- blob is updated so callers can rebuild dependent rows (composition list
-- depends on player count).
---@param prefs table
---@param allowedCounts integer[]
---@param onChange fun(newCount: integer)?
---@param tooltipFn (fun(text: string))?
---@return MenuItem
function RoomCreateRows.createPlayerCountRow(prefs, allowedCounts, onChange, tooltipFn)
  local buttons = {}
  for _, n in ipairs(allowedCounts) do
    buttons[#buttons + 1] = { label = tostring(n), value = n,
      description = "Players: " .. tostring(n) .. " — total seats in the room." }
  end
  local group = buttonGroup(prefs, "playerCount", buttons, tooltipFn)
  -- Chain the extra onChange (rebuild dependent rows) after the standard one.
  local origOnChange = group.onChange
  group.onChange = function(g, value)
    origOnChange(g, value)
    if onChange then onChange(value) end
  end
  local item = ui.MenuItem.createToggleButtonGroupMenuItem("Players", nil, false, group)
  attachRowTooltip(item, group, tooltipFn)
  return item
end

-- Composition row. `playerCount` is the current selection; the row offers
-- only divisions valid for that count. If prefs.composition is stale, falls
-- back to the first available division.
---@param prefs table
---@param playerCount integer
---@param tooltipFn (fun(text: string))?
---@return MenuItem
function RoomCreateRows.createCompositionRow(prefs, playerCount, tooltipFn)
  local divisions = RoomCreateRows.TEAM_DIVISIONS[playerCount] or {}
  if not RoomCreateRows.resolveTeamDivision(playerCount, prefs.composition) then
    prefs.composition = RoomCreateRows.defaultCompositionFor(playerCount) or prefs.composition
  end
  local buttons = {}
  for _, div in ipairs(divisions) do
    buttons[#buttons + 1] = { label = div.label, value = div.label,
      description = "Composition: " .. div.label .. " — team sizes for the match." }
  end
  local group = buttonGroup(prefs, "composition", buttons, tooltipFn)
  local item = ui.MenuItem.createToggleButtonGroupMenuItem("Composition", nil, false, group)
  attachRowTooltip(item, group, tooltipFn)
  return item
end

-- "Create" action button. `onClick` is the caller-provided submit handler.
-- Self-explanatory, so no tooltip text — but we still wire onSelectedFunction
-- to *clear* the tooltip when the row gains focus so stale text from the
-- previous row doesn't linger in the bottom bar.
---@param onClick fun()
---@param tooltipFn (fun(text: string))?
---@return MenuItem
function RoomCreateRows.createCreateButton(onClick, tooltipFn)
  local item = ui.MenuItem.createButtonMenuItem("Create", nil, false, function()
    GAME.theme:playValidationSfx()
    onClick()
  end)
  if tooltipFn then
    item.onSelectedFunction = function() tooltipFn("") end
  end
  return item
end

-- Cancel/back button. Same treatment as Create — no tooltip text, but clear
-- the bottom bar on focus.
---@param tooltipFn (fun(text: string))?
---@return MenuItem
function RoomCreateRows.createCancelButton(tooltipFn)
  local item = ui.MenuItem.createButtonMenuItem("Cancel", nil, false, function()
    GAME.theme:playCancelSfx()
    GAME.navigationStack:pop()
  end)
  if tooltipFn then
    item.onSelectedFunction = function() tooltipFn("") end
  end
  return item
end

return RoomCreateRows
