local class = require("common.lib.class")
local UiElement = require("client.src.ui.UIElement")
local Label = require("client.src.ui.Label")
local GraphicsUtil = require("client.src.graphics.graphics_util")

local ENTER_SECONDS = 0.45
local HOLD_SECONDS = 3
local LEAVE_SECONDS = 0.35
local PADDING_X = 18
local PADDING_Y = 10
-- wide enough for the usual messages, so notifications stacked together line up
local MIN_WIDTH = 240
local CORNER_RADIUS = 10
local RIM_WIDTH = 2
local SHADOW_OFFSET = 3
-- the navy and teal of the match HUD
local CARD_COLOR = {0.137, 0.176, 0.306}
local RIM_COLOR = {0, 0.404, 0.424}

---@class NotificationOptions
---@field text string the raw text or localization key
---@field translate boolean? whether text is a localization key, true if left out
---@field replacements string[]? strings to put into the localized text's placeholders
---@field holdSeconds number? how long the notification stays in place, Notification.HOLD_SECONDS if left out

-- A small message card that slides in from the right edge, holds for a moment and slides back out on its own.
-- A NotificationCenter places it and starts it; subclasses can draw something else in its card.
---@class Notification : UiElement
---@field label Label
---@field holdSeconds number how long the notification stays in place
---@field slideOffset number pixels the notification is drawn right of its place, 0 while it holds
---@field finished boolean true once it has left
---@overload fun(options: NotificationOptions): Notification
local Notification = class(
  ---@param self Notification
  ---@param options NotificationOptions
  function(self, options)
    self.holdSeconds = options.holdSeconds or HOLD_SECONDS
    self.slideOffset = 0
    self.finished = false
    self.label = Label({
      text = options.text,
      translate = options.translate,
      replacements = options.replacements,
      hAlign = "center",
      vAlign = "center",
      textColor = {1, 1, 1, 1}
    })
    self:addChild(self.label)
    self:fitToLabel()
  end,
  UiElement
)

Notification.ENTER_SECONDS = ENTER_SECONDS
Notification.HOLD_SECONDS = HOLD_SECONDS
Notification.LEAVE_SECONDS = LEAVE_SECONDS
Notification.MIN_WIDTH = MIN_WIDTH

-- Sizes the card around its label
function Notification:fitToLabel()
  self.width = math.max(MIN_WIDTH, self.label.width + PADDING_X * 2)
  self.height = self.label.height + PADDING_Y * 2
end

-- Changes the notification's text and resizes its card to fit
---@param text string the raw text or localization key
---@param replacements string[]? strings to put into the localized text's placeholders
function Notification:setText(text, replacements)
  self.label:setText(text, replacements)
  self:fitToLabel()
end

-- Slides the notification in from out of sight after delay seconds, holds it and slides it back out
---@param group table the flux group that runs the notification's animation
---@param delay number seconds to wait before sliding in
---@param distance number pixels right of its place at which the notification is out of sight
function Notification:start(group, delay, distance)
  self.slideOffset = distance
  group:to(self, ENTER_SECONDS, {slideOffset = 0}):delay(delay):ease("backout")
    :after(LEAVE_SECONDS, {slideOffset = distance}):delay(self.holdSeconds):ease("quadin")
    :oncomplete(function()
      self.finished = true
    end)
end

-- Draws the notification moved right by how far it still has to slide in or has slid out
function Notification:draw()
  love.graphics.push("transform")
  love.graphics.translate(self.slideOffset, 0)
  UiElement.draw(self)
  love.graphics.pop()
end

-- Draws the card behind the label
function Notification:drawSelf()
  local x, y, width, height = self.x, self.y, self.width, self.height
  local inset = RIM_WIDTH / 2
  GraphicsUtil.drawRectangle("fill", x, y + SHADOW_OFFSET, width, height, 0, 0, 0, 0.35, CORNER_RADIUS, CORNER_RADIUS)
  GraphicsUtil.drawRectangle("fill", x, y, width, height, CARD_COLOR[1], CARD_COLOR[2], CARD_COLOR[3], 1, CORNER_RADIUS, CORNER_RADIUS)
  local lineWidth = love.graphics.getLineWidth()
  love.graphics.setLineWidth(RIM_WIDTH)
  GraphicsUtil.drawRectangle("line", x + inset, y + inset, width - RIM_WIDTH, height - RIM_WIDTH,
                             RIM_COLOR[1], RIM_COLOR[2], RIM_COLOR[3], 1, CORNER_RADIUS - inset, CORNER_RADIUS - inset)
  love.graphics.setLineWidth(lineWidth)
end

return Notification
