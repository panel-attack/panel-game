-- Renders the pink/purple team banner pair across the top of the screen.
-- Used by ClientMatch (in-game scoreboard) and CharacterSelect (waiting room).

local GraphicsUtil = require("client.src.graphics.graphics_util")
local GameModes = require("common.data.GameModes")
local TeamUtils = require("common.data.TeamUtils")
local tableUtils = require("common.lib.tableUtils")

local TeamBannerHeader = {}

-- Pink + purple palette, mirrored from ClientMatch / GameBase.
local TEAM_COLORS = {
  {1,    0.55, 0.75, 1}, -- pink
  {0.65, 0.4,  0.95, 1}, -- purple
  {0.45, 1,    0.45, 1}, -- green
  {1,    1,    0.45, 1}, -- yellow
  {1,    0.6,  0.2,  1}, -- orange
  {0.45, 0.7,  1,    1}, -- blue
  {0.45, 1,    1,    1}, -- cyan
  {1,    0.45, 0.45, 1}, -- red
}

local function clampTextToWidth(text, maxWidth, font)
  if font:getWidth(text) <= maxWidth then return text end
  local ellipsis = "..."
  local result = text
  while #result > 0 and font:getWidth(result .. ellipsis) > maxWidth do
    result = result:sub(1, #result - 1)
  end
  return (result == "") and ellipsis or (result .. ellipsis)
end

-- True only for "shared team" modes (multiple players per team). FFA is
-- TEAM_VERSUS but every team has size 1 → treated as non-team for this header.
local function isSharedTeamMode(gameMode)
  if not gameMode or gameMode.stackInteraction ~= GameModes.StackInteractions.TEAM_VERSUS then
    return false
  end
  local p = gameMode.playersPerTeam
  if type(p) == "number" then return p > 1 end
  if type(p) == "table" then
    for _, n in ipairs(p) do
      if n > 1 then return true end
    end
  end
  return false
end

-- Build [teamIndex] -> { names = {...}, wins = N } from a player list + gameMode + optional teamWins.
local function buildTeamData(gameMode, players, teamWins)
  local teamCount = gameMode.teamCount or 2
  local data = {}
  for i = 1, teamCount do data[i] = {names = {}, wins = 0} end

  for i, player in ipairs(players) do
    local teamIndex = TeamUtils and gameMode.playersPerTeam and (function()
      local p = gameMode.playersPerTeam
      if type(p) == "number" then return math.floor((i - 1) / p) + 1 end
      if type(p) == "table" then
        local cum = 0
        for idx, n in ipairs(p) do
          if i <= cum + n then return idx end
          cum = cum + n
        end
      end
      return i
    end)() or i

    local entry = data[teamIndex] or {names = {}, wins = 0}
    data[teamIndex] = entry
    entry.names[#entry.names + 1] = player.name or ("P" .. i)
    if not (teamWins and teamWins[teamIndex]) then
      local w = (player.getWinCountForDisplay and player:getWinCountForDisplay()) or player.wins or 0
      if w > entry.wins then entry.wins = w end
    end
  end

  if teamWins then
    for i = 1, teamCount do
      if teamWins[i] and data[i] then data[i].wins = teamWins[i] end
    end
  end

  return data, teamCount
end

-- Draws the two team banners (pink + purple) at the top of the canvas, with
-- the per-team win count printed below each banner. Skips quietly for non-
-- shared-team modes (solo, 2P VS, FFA).
---@param gameMode table the GameMode definition (has stackInteraction, teamCount, playersPerTeam)
---@param players table[] list of player objects (each has .name and .wins / :getWinCountForDisplay())
---@param teamWins integer[]? optional per-team win count (preferred over per-player wins when present)
---@param canvasWidth number screen width
function TeamBannerHeader.draw(gameMode, players, teamWins, canvasWidth)
  if not isSharedTeamMode(gameMode) then return end

  local data, teamCount = buildTeamData(gameMode, players, teamWins)
  if teamCount ~= 2 then return end  -- shared-team layout currently 2-team only

  local centerX = canvasWidth / 2
  local bannerWidth = 280
  local bannerHeight = 40
  local timerHalfGap = 110
  local sideMargin = 16
  local bannerY = 4
  local winY = bannerY + bannerHeight + 2
  local font = GraphicsUtil.getGlobalFont()

  local t1 = data[1] or {names = {}, wins = 0}
  local t2 = data[2] or {names = {}, wins = 0}
  local t1Name = clampTextToWidth(table.concat(t1.names, ", "), bannerWidth - 16, font)
  local t2Name = clampTextToWidth(table.concat(t2.names, ", "), bannerWidth - 16, font)

  local t1X = math.max(sideMargin, centerX - timerHalfGap - bannerWidth)
  GraphicsUtil.drawRectangle("fill", t1X, bannerY, bannerWidth, bannerHeight,
    TEAM_COLORS[1][1], TEAM_COLORS[1][2], TEAM_COLORS[1][3], 0.85)
  GraphicsUtil.printf(t1Name, t1X, bannerY + 10, bannerWidth, "center", nil, nil, 4)
  GraphicsUtil.printf(tostring(t1.wins), t1X, winY, bannerWidth, "center", TEAM_COLORS[1], nil, 4)

  local t2X = math.min(canvasWidth - sideMargin - bannerWidth, centerX + timerHalfGap)
  GraphicsUtil.drawRectangle("fill", t2X, bannerY, bannerWidth, bannerHeight,
    TEAM_COLORS[2][1], TEAM_COLORS[2][2], TEAM_COLORS[2][3], 0.85)
  GraphicsUtil.printf(t2Name, t2X, bannerY + 10, bannerWidth, "center", nil, nil, 4)
  GraphicsUtil.printf(tostring(t2.wins), t2X, winY, bannerWidth, "center", TEAM_COLORS[2], nil, 4)

  GraphicsUtil.setColor(1, 1, 1, 1)
end

-- Short human-readable summary of the team game's garbage rule. Returns nil
-- for non-team modes and for FFA (where every team is size 1 so the "team
-- garbage" concept doesn't apply).
local function garbageModeLabel(gameMode)
  if not gameMode then return nil end
  if not isSharedTeamMode(gameMode) then return nil end
  if gameMode.garbageMode == "shared" then
    return "Shared garbage"
  elseif gameMode.garbageMode == "all" then
    return "All-target garbage"
  end
  return nil
end

-- Draws the garbage-mode label centered just under the banner header. Pass the
-- same gameMode you'd give to TeamBannerHeader.draw. No-op outside shared team
-- modes so it doesn't draw anywhere it shouldn't.
function TeamBannerHeader.drawGarbageModeBelowBanner(gameMode, canvasWidth)
  local label = garbageModeLabel(gameMode)
  if not label then return end
  -- Two-pass shadow + light text so it reads on top of any background.
  GraphicsUtil.printf(label, 0, 50, canvasWidth, "center", {0.1, 0.05, 0.15, 0.85}, nil, 6)
  GraphicsUtil.printf(label, 0, 48, canvasWidth, "center", {1, 0.9, 0.7, 1}, nil, 6)
end

TeamBannerHeader.colors = TEAM_COLORS
TeamBannerHeader.isSharedTeamMode = isSharedTeamMode
TeamBannerHeader.garbageModeLabel = garbageModeLabel

return TeamBannerHeader
