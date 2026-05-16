-- Renders the pink/purple team banner pair across the top of the screen.
-- Used by ClientMatch (in-game scoreboard) and CharacterSelect (waiting room).

local GraphicsUtil = require("client.src.graphics.graphics_util")
local GameModes = require("common.data.GameModes")
local TeamUtils = require("common.data.TeamUtils")
local tableUtils = require("common.lib.tableUtils")

local TeamBannerHeader = {}

local TEAM_COLORS = TeamUtils.TEAM_COLORS

local function clampTextToWidth(text, maxWidth, font)
  if font:getWidth(text) <= maxWidth then return text end
  local ellipsis = "..."
  local result = text
  while #result > 0 and font:getWidth(result .. ellipsis) > maxWidth do
    result = result:sub(1, #result - 1)
  end
  return (result == "") and ellipsis or (result .. ellipsis)
end

local isSharedTeamMode = TeamUtils.isSharedTeamMode

-- Build [teamIndex] -> { names = {...}, wins = N } from a player list + context + optional teamWins.
-- context can be a Match (with engine.teams), BattleRoom, or a raw gameMode.
local function buildTeamData(context, players, teamWins)
  local gameMode = (context and (context.gameMode or context.mode)) or context
  local teamCount = (context and context.engine and context.engine.teams and #context.engine.teams)
    or (gameMode and gameMode.teamCount) or 2
  local data = {}
  for i = 1, teamCount do data[i] = {names = {}, wins = 0} end

  for i, player in ipairs(players) do
    local teamIndex = TeamUtils.teamIndexForPlayer(context, player)
    if not teamIndex then break end

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
---@param context table? Match / BattleRoom / gameMode — first hit with engine.teams wins
function TeamBannerHeader.draw(gameMode, players, teamWins, canvasWidth, context)
  if not isSharedTeamMode(gameMode) then return end

  local data, teamCount = buildTeamData(context or gameMode, players, teamWins)
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

-- Short human-readable summary of the garbage routing rule. Returns nil for
-- non-team modes and for 1v1 (where there is only one enemy and the label is
-- meaningless). Shows for both team modes and FFA — round-robin is now a valid
-- FFA option, and showing "Broadcast" in "all" FFA is informative too.
local function garbageModeLabel(gameMode)
  if not gameMode then return nil end
  if gameMode.stackInteraction ~= GameModes.StackInteractions.TEAM_VERSUS then return nil end
  if not gameMode.garbageMode then return nil end
  -- Skip if there's only one possible enemy per sender (no observable
  -- difference between broadcast and round-robin in that case).
  local playerCount = gameMode.playerCount or gameMode.maxPlayers or 0
  if playerCount > 0 and playerCount < 3 then return nil end
  if gameMode.garbageMode == "shared" then
    return "Round Robin"
  elseif gameMode.garbageMode == "all" then
    return "Broadcast"
  end
  return nil
end

-- Draws the garbage-mode label (team modes) and latency tolerance label centered
-- just under the banner header. Two-pass shadow+text so it reads on any background.
function TeamBannerHeader.drawGarbageModeBelowBanner(gameMode, canvasWidth, context)
  if not gameMode then return end

  local gLabel = garbageModeLabel(gameMode)
  local latLabel = gameMode.latencyTolerance
    and (gameMode.latencyTolerance:sub(1,1):upper() .. gameMode.latencyTolerance:sub(2) .. " latency")
    or nil

  if not gLabel and not latLabel then return end

  local y
  if isSharedTeamMode(gameMode) then
    y = 8
  elseif context == "match" then
    y = 80
  else
    y = 4
  end
  if gLabel then
    GraphicsUtil.printf(gLabel, 0, y + 2, canvasWidth, "center", {0.1, 0.05, 0.15, 0.85}, nil, 6)
    GraphicsUtil.printf(gLabel, 0, y,     canvasWidth, "center", {1, 0.9, 0.7, 1},          nil, 6)
    y = y + 16
  end

  if latLabel then
    GraphicsUtil.printf(latLabel, 0, y + 2, canvasWidth, "center", {0.1, 0.05, 0.15, 0.85}, nil, 6)
    GraphicsUtil.printf(latLabel, 0, y,     canvasWidth, "center", {0.75, 0.92, 1, 0.9},     nil, 6)
  end
end

TeamBannerHeader.colors = TEAM_COLORS
TeamBannerHeader.isSharedTeamMode = isSharedTeamMode
TeamBannerHeader.garbageModeLabel = garbageModeLabel

return TeamBannerHeader
