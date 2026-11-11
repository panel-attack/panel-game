local import = require("common.lib.import")
local UiElement = import("./UIElement")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local consts = require("common.engine.consts")
local utf8 = require("common.lib.utf8Additions")
local ImageContainer = import("./ImageContainer")

-- a 2x1 element of the character select grid: two 100 units wide and one tall, less its 8 margins
local WIDTH = 184
local HEIGHT = 84
local PADDING = 8
local ICON_SIZE = 16
local PING_GAP = 6
local ICON_GAP = 4
-- font sizes relative to the game's, so the four rows fit in every language's font
local ROW_FONT_DELTA = -1
local SMALL_FONT_DELTA = -2
local ELLIPSIS = "..."
-- a default Button's colors, so the card looks like the change input button beside it
local BACKGROUND_COLOR = {.3, .3, .3, .7}
local OUTLINE_COLOR = {.5, .5, .5, .7}
local TITLE_COLOR = {.8, .8, .8, 1}
local NAME_COLOR = {1, 1, 1, 1}
local WARNING_COLOR = {1, .85, .3, 1}

---@class ConnectionWarningPlayer
---@field publicId PublicPlayerID
---@field name string

---@class ConnectionWarningRow
---@field name string the player's name, shortened with ... to fit beside the ping
---@field ping string the recent average ping, empty until it is measured
---@field slow boolean whether this player's connection makes rollback likely

---@class ConnectionWarningLayout
---@field titleTop number
---@field rowTops number[]
---@field rowHeight number
---@field warningTop number
---@field warningHeight number

---@class ConnectionWarningOptions : UiElementOptions
---@field players ConnectionWarningPlayer[] the players whose connections it watches, in the order it lists them
---@field pingOf (fun(publicId: PublicPlayerID): PingSummary?)? where pings come from, the net client by default
---@field alwaysShown boolean? shows the pings while every connection is fine too, without the warning

-- A card titled Network Latency with a row per watched player: their name and recent average ping. Its bottom
-- row warns that rollback is likely, with the warning icon, while any watched connection makes it so. It shows only
-- then, or always if asked to. It is a 2x1 character select grid element in size, or fills what it is in when told to,
-- and keeps its size whether it warns or not.
---@class ConnectionWarning : UiElement
---@operator call(ConnectionWarningOptions): ConnectionWarning
---@field players ConnectionWarningPlayer[]
---@field pingOf fun(publicId: PublicPlayerID): PingSummary?
---@field alwaysShown boolean
---@field icon ImageContainer
---@field rows ConnectionWarningRow[] reused for the rows on every rebuild
---@field pingColumnWidth number the widest ping
---@field layoutInfo ConnectionWarningLayout reused on every layout
---@field shownPings (PingSummary|false)[] each player's ping the rows were last built from, false for an unmeasured one
local ConnectionWarning = class(
function(self, options)
  self.players = options.players
  self.pingOf = options.pingOf or function(publicId)
    return GAME.netClient:pingOf(publicId)
  end
  self.alwaysShown = options.alwaysShown == true
  self.width = options.hFill and self.width or WIDTH
  self.height = options.vFill and self.height or HEIGHT
  self.rows = {}
  self.pingColumnWidth = 0
  self.layoutInfo = {rowTops = {}}
  self.shownPings = {}

  self.icon = ImageContainer({
    image = GAME.theme.images.IMG_connectionWarning,
    width = ICON_SIZE,
    height = ICON_SIZE,
    x = PADDING,
  })
  self:addChild(self.icon)
  self:refresh()
end,
UiElement)

ConnectionWarning.TYPE = "ConnectionWarning"
ConnectionWarning.WIDTH = WIDTH
ConnectionWarning.HEIGHT = HEIGHT
-- the space around the card's contents and between it and what it sits beside
ConnectionWarning.PADDING = PADDING
-- How many jitters above the average a round trip can still be expected to reach, as TCP's retransmit timeout assumes
ConnectionWarning.JITTER_MARGIN = 4
-- the color of the warning, and of the ping of a player whose connection makes rollback likely
ConnectionWarning.WARNING_COLOR = WARNING_COLOR

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

---@return string # the card's title in the current language
function ConnectionWarning.title()
  return loc("ss_network_latency")
end

---@return string # the warning in the current language
function ConnectionWarning.warningText()
  return loc("ss_rollback_likely")
end

---@param delta integer
---@return love.Font # the game's font, delta points larger
local function fontOfDelta(delta)
  return GraphicsUtil.getGlobalFontWithSize(GraphicsUtil.fontSize + delta)
end

---@param font love.Font
---@param text string
---@param room number
---@return string # the text, cut short and ending in ... if it is wider than room
local function shortened(font, text, room)
  if font:getWidth(text) <= room then
    return text
  end
  for length = utf8.len(text) - 1, 1, -1 do
    local cut = utf8.sub(text, 1, length) .. ELLIPSIS
    if font:getWidth(cut) <= room then
      return cut
    end
  end
  return ELLIPSIS
end

---@return number # how wide a name can be beside the ping column
function ConnectionWarning:nameRoom()
  return self.width - PADDING * 2 - self.pingColumnWidth - PING_GAP
end

---@param row ConnectionWarningRow
---@return number[] # the color of the row's ping: the warning's while it makes rollback likely
function ConnectionWarning.pingColor(row)
  return row.slow and WARNING_COLOR or NAME_COLOR
end

-- Fills a row per player with their average ping, sizes the ping column to them, then fits the names beside it
---@return ConnectionWarningRow[] # the same table on every call
function ConnectionWarning:buildRows()
  local rows = self.rows
  for i = #rows, #self.players + 1, -1 do
    rows[i] = nil
  end
  local font = fontOfDelta(ROW_FONT_DELTA)
  self.pingColumnWidth = 0
  for i, player in ipairs(self.players) do
    local row = rows[i] or {}
    rows[i] = row
    local ping = self.pingOf(player.publicId)
    row.ping = ping and loc("ss_ping_average", ping.average) or ""
    row.slow = ConnectionWarning.rollbackLikely(ping)
    self.pingColumnWidth = math.max(self.pingColumnWidth, font:getWidth(row.ping))
  end
  for i, player in ipairs(self.players) do
    rows[i].name = shortened(font, player.name, self:nameRoom())
  end
  return rows
end

-- Spreads the title, the players' rows and the warning evenly down the card, the warning ending a padding above the
-- card's bottom
---@return ConnectionWarningLayout # the same table on every call
function ConnectionWarning:layout()
  local layout = self.layoutInfo
  local titleHeight = fontOfDelta(SMALL_FONT_DELTA):getHeight()
  layout.rowHeight = fontOfDelta(ROW_FONT_DELTA):getHeight()
  layout.warningHeight = math.max(ICON_SIZE, fontOfDelta(SMALL_FONT_DELTA):getHeight())
  local playerCount = #self.players
  local contentHeight = titleHeight + playerCount * layout.rowHeight + layout.warningHeight
  local gap = math.max(0, (self.height - PADDING - contentHeight - PADDING / 2) / (playerCount + 1))
  layout.titleTop = PADDING / 2
  for i = #layout.rowTops, playerCount + 1, -1 do
    layout.rowTops[i] = nil
  end
  for i = 1, playerCount do
    layout.rowTops[i] = layout.titleTop + titleHeight + gap + (i - 1) * (layout.rowHeight + gap)
  end
  layout.warningTop = self.height - PADDING / 2 - layout.warningHeight
  self.icon.y = layout.warningTop + (layout.warningHeight - ICON_SIZE) / 2
  return layout
end

-- Rebuilds the rows and lays the card out
function ConnectionWarning:measure()
  self:buildRows()
  self:layout()
end

-- Fits the rows to the size filling what the card is in gave it
function ConnectionWarning:onResize()
  self:measure()
end

-- Whether a ping changed since the rows were last built, remembering the current ones
---@return boolean
function ConnectionWarning:pingsChanged()
  local changed = #self.shownPings ~= #self.players
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
  return changed
end

---@return boolean # true while the card is drawn: always if it was asked to be, otherwise while warning
function ConnectionWarning:isShown()
  return self.alwaysShown or self.icon.isVisible
end

-- Shows the icon while warning and rebuilds the rows when a ping changed
function ConnectionWarning:refresh()
  self.icon:setVisibility(self:isWarning())
  if self:isShown() and self:pingsChanged() then
    self:measure()
  end
end

---@param text string
---@param font love.Font
---@param x number
---@param top number the top of the row the text sits in
---@param rowHeight number
---@param color number[]
local function printInRow(text, font, x, top, rowHeight, color)
  GraphicsUtil.setFont(font)
  GraphicsUtil.print(text, x, top + rowHeight - font:getHeight(), color)
end

-- Draws a player's name on the left and their ping right aligned
---@param row ConnectionWarningRow
---@param top number
---@param rowHeight number
function ConnectionWarning:drawRow(row, top, rowHeight)
  local font = fontOfDelta(ROW_FONT_DELTA)
  printInRow(row.name, font, self.x + PADDING, top, rowHeight, NAME_COLOR)
  printInRow(row.ping, font, self.x + self.width - PADDING - font:getWidth(row.ping), top, rowHeight, ConnectionWarning.pingColor(row))
end

-- Refreshes from the latest pings, then draws the card, its title, its rows and, while warning, the warning
function ConnectionWarning:drawSelf()
  self:refresh()
  if not self:isShown() then
    return
  end
  local layout = self.layoutInfo
  GraphicsUtil.drawRectangle("fill", self.x, self.y, self.width, self.height, unpack(BACKGROUND_COLOR))
  GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height, unpack(OUTLINE_COLOR))
  local smallFont = fontOfDelta(SMALL_FONT_DELTA)
  GraphicsUtil.setFont(smallFont)
  GraphicsUtil.print(ConnectionWarning.title(), self.x + PADDING, self.y + layout.titleTop, TITLE_COLOR)
  for i, row in ipairs(self.rows) do
    self:drawRow(row, self.y + layout.rowTops[i], layout.rowHeight)
  end
  if self.icon.isVisible then
    printInRow(ConnectionWarning.warningText(), smallFont, self.x + PADDING + ICON_SIZE + ICON_GAP,
      self.y + layout.warningTop, layout.warningHeight - (layout.warningHeight - smallFont:getHeight()) / 2, WARNING_COLOR)
  end
  GraphicsUtil.setFont(GraphicsUtil.getGlobalFont())
end

return ConnectionWarning
