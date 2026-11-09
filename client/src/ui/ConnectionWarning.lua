local import = require("common.lib.import")
local UiElement = import("./UIElement")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local consts = require("common.engine.consts")
local ImageContainer = import("./ImageContainer")

local ICON_SIZE = 28
local PADDING = 8
local LINE_SPACING = 2
local CARD_ALPHA = 0.9

---@class ConnectionWarningPlayer
---@field publicId PublicPlayerID
---@field name string

---@class ConnectionWarningOptions : UiElementOptions
---@field players ConnectionWarningPlayer[] the players whose connections it watches, in the order it lists them
---@field pingOf (fun(publicId: PublicPlayerID): PingSummary?)? where pings come from, the net client by default

-- A card that shows while any watched connection makes rollback likely: the warning icon at the top and every watched
-- player's current and average ping on a line below it. It sizes itself to its lines, so it is placed by its top left.
---@class ConnectionWarning : UiElement
---@operator call(ConnectionWarningOptions): ConnectionWarning
---@field players ConnectionWarningPlayer[]
---@field pingOf fun(publicId: PublicPlayerID): PingSummary?
---@field icon ImageContainer
---@field lines string[] reused for the lines on every refresh
---@field shownPlayers ConnectionWarningPlayer[]? the players the lines were last built for
---@field shownPings (PingSummary|false)[] each player's ping the lines were last built from, false for an unmeasured one
local ConnectionWarning = class(
function(self, options)
  self.players = options.players
  self.pingOf = options.pingOf or function(publicId)
    return GAME.netClient:pingOf(publicId)
  end
  self.lines = {}
  self.shownPings = {}

  self.icon = ImageContainer({
    image = GAME.theme.images.IMG_connectionWarning,
    width = ICON_SIZE,
    height = ICON_SIZE,
    hAlign = "center",
    y = PADDING,
  })
  self:addChild(self.icon)
  self:refresh()
end,
UiElement)

ConnectionWarning.TYPE = "ConnectionWarning"
ConnectionWarning.ICON_SIZE = ICON_SIZE
-- the space around the card's contents and between it and what it sits beside
ConnectionWarning.PADDING = PADDING
-- How many jitters above the average a round trip can still be expected to reach, as TCP's retransmit timeout assumes
ConnectionWarning.JITTER_MARGIN = 4

-- The likely round trip in milliseconds above which rollback is likely: the opponent's stack runs about one round trip
-- of its player behind, and garbage lands GARBAGE_DELAY_LAND_TIME frames after it leaves the telegraph
---@return number
function ConnectionWarning.rollbackMilliseconds()
  return GARBAGE_DELAY_LAND_TIME * consts.FRAME_RATE * 1000
end

---@param ping PingSummary? a player's ping as a ping update carries it
---@return boolean # true when the player's average plus JITTER_MARGIN jitters passes rollbackMilliseconds
function ConnectionWarning.rollbackLikely(ping)
  if ping == nil then
    return false
  end
  return ping.average + ConnectionWarning.JITTER_MARGIN * ping.jitter > ConnectionWarning.rollbackMilliseconds()
end

---@return boolean # true while a watched connection makes rollback likely
function ConnectionWarning:isWarning()
  for _, player in ipairs(self.players) do
    if ConnectionWarning.rollbackLikely(self.pingOf(player.publicId)) then
      return true
    end
  end
  return false
end

-- Each player's current and average ping, or that it is still being measured
---@return string[] # the same table on every call
function ConnectionWarning:detailLines()
  local lines = self.lines
  for i = #lines, 1, -1 do
    lines[i] = nil
  end
  for _, player in ipairs(self.players) do
    local ping = self.pingOf(player.publicId)
    if ping then
      lines[#lines + 1] = string.format("%s %d ms - %d ms avg", player.name, ping.current, ping.average)
    else
      lines[#lines + 1] = player.name .. " measuring"
    end
  end
  return lines
end

---@return number
local function lineHeight()
  return GraphicsUtil.getGlobalFont():getHeight() + LINE_SPACING
end

---@return number # the y of the first line within the card
local function linesTop()
  return PADDING + ICON_SIZE + PADDING / 2
end

-- Sizes the card to the icon and the current lines
function ConnectionWarning:measure()
  local lines = self:detailLines()
  local font = GraphicsUtil.getGlobalFont()
  local widest = ICON_SIZE
  for _, line in ipairs(lines) do
    widest = math.max(widest, font:getWidth(line))
  end
  self.width = widest + PADDING * 2
  self.height = linesTop() + #lines * lineHeight() + PADDING / 2
end

-- Whether a ping or the watched players changed since the lines were last built, remembering the current ones
---@return boolean
function ConnectionWarning:pingsChanged()
  local changed = self.shownPlayers ~= self.players or #self.shownPings ~= #self.players
  for i = #self.shownPings, #self.players + 1, -1 do
    self.shownPings[i] = nil
  end
  for i, player in ipairs(self.players) do
    local ping = self.pingOf(player.publicId) or false
    if self.shownPings[i] ~= ping then
      self.shownPings[i] = ping
      changed = true
    end
  end
  self.shownPlayers = self.players
  return changed
end

-- Shows the icon while warning and rebuilds and sizes the card's lines when a ping changed
function ConnectionWarning:refresh()
  local warning = self:isWarning()
  self.icon:setVisibility(warning)
  if warning and self:pingsChanged() then
    self:measure()
  end
end

-- Refreshes from the latest pings, then draws the card and its lines while warning
function ConnectionWarning:drawSelf()
  self:refresh()
  if not self.icon.isVisible then
    return
  end
  GraphicsUtil.drawRectangle("fill", self.x, self.y, self.width, self.height, 0, 0, 0, CARD_ALPHA, 4, 4)
  for i, line in ipairs(self.lines) do
    GraphicsUtil.print(line, self.x + PADDING, self.y + linesTop() + (i - 1) * lineHeight())
  end
end

return ConnectionWarning
