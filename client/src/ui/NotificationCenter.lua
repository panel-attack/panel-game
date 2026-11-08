local class = require("common.lib.class")
local UiElement = require("client.src.ui.UIElement")
local Notification = require("client.src.ui.Notification")
local Flux = require("client.lib.flux.flux")
local consts = require("common.engine.consts")

-- Shows notifications in MAX_SHOWN places stacked downward from the top right of the canvas, above every scene.
-- Game puts it in uiRoot after the navigation stack, so it is drawn over the scenes and lasts across scene changes;
-- it never takes touches or input.
-- A notification keeps its place until it has slid out; the rest wait their turn and slide into the places freed.
---@class NotificationCenter : UiElement
---@field notifications Notification[] the shown notifications, oldest first
---@field places table<Notification, integer> the place each shown notification holds, 1 at the top
---@field waiting Notification[] the notifications waiting for a place, first to be shown first
---@field tweens table flux group running every notification's animation
---@field clock number seconds the center has run
---@field nextStartTime number clock time the next notification may slide in, so notifications shown together slide in one after another
---@field skippingNextDraw boolean true to leave the notifications out of the next frame
---@overload fun(options: UiElementOptions): NotificationCenter
local NotificationCenter = class(
  ---@param self NotificationCenter
  ---@param options UiElementOptions
  function(self, options)
    self.width = options.width or consts.CANVAS_WIDTH
    self.height = options.height or consts.CANVAS_HEIGHT
    self.notifications = {}
    self.places = {}
    self.waiting = {}
    self.tweens = Flux.group()
    self.clock = 0
    self.nextStartTime = 0
    self.skippingNextDraw = false
  end,
  UiElement
)

NotificationCenter.MAX_SHOWN = 3
NotificationCenter.STAGGER_SECONDS = 0.4
NotificationCenter.RIGHT_MARGIN = 16
-- clear of the match HUD across the top of the screen
NotificationCenter.TOP_MARGIN = 56
NotificationCenter.GAP = 8

-- Shows a notification with the given text
---@param text string the raw text or localization key
---@param translate boolean? whether text is a localization key, true if left out
---@param replacements string[]? strings to put into the localized text's placeholders
function NotificationCenter:show(text, translate, replacements)
  self:add(Notification({text = text, translate = translate, replacements = replacements}))
end

-- Shows the given notification, or has it wait its turn when MAX_SHOWN are already shown
---@param notification Notification
function NotificationCenter:add(notification)
  if #self.notifications >= NotificationCenter.MAX_SHOWN then
    self.waiting[#self.waiting + 1] = notification
  else
    self:showNow(notification)
  end
end

-- Puts the notification in the topmost free place and slides it in
---@param notification Notification
function NotificationCenter:showNow(notification)
  local place = self:topmostFreePlace()
  self.notifications[#self.notifications + 1] = notification
  self.places[notification] = place
  self:addChild(notification)
  notification.x = self.width - NotificationCenter.RIGHT_MARGIN - notification.width
  notification.y = NotificationCenter.TOP_MARGIN + (place - 1) * (notification.height + NotificationCenter.GAP)
  notification:start(self.tweens, self:takeStartDelay(), self.width - notification.x)
end

-- The topmost place no shown notification holds
---@return integer
function NotificationCenter:topmostFreePlace()
  local taken = {}
  for _, notification in ipairs(self.notifications) do
    taken[self.places[notification]] = true
  end
  local place = 1
  while taken[place] do
    place = place + 1
  end
  return place
end

-- Seconds the next notification waits before sliding in, keeping notifications shown together STAGGER_SECONDS apart
---@return number
function NotificationCenter:takeStartDelay()
  local delay = math.max(0, self.nextStartTime - self.clock)
  self.nextStartTime = self.clock + delay + NotificationCenter.STAGGER_SECONDS
  return delay
end

-- Runs the notifications' animations and takes away the ones that left
function NotificationCenter:updateSelf(dt)
  self.clock = self.clock + dt
  self.tweens:update(dt)
  self:removeFinished()
end

-- Takes away the notifications that left and shows the waiting notifications in the places freed
function NotificationCenter:removeFinished()
  for i = #self.notifications, 1, -1 do
    local notification = self.notifications[i]
    if notification.finished then
      notification:detach()
      table.remove(self.notifications, i)
      self.places[notification] = nil
    end
  end
  while #self.notifications < NotificationCenter.MAX_SHOWN and #self.waiting > 0 do
    self:showNow(table.remove(self.waiting, 1))
  end
end

-- Never takes a touch, so a touch on a notification reaches the scene under it
---@return nil
function NotificationCenter:getTouchedElement(x, y)
  return nil
end

-- Never hands a notification input, so showing one never takes it from the scene
---@return boolean handled always false
function NotificationCenter:handleFocusedInput(inputs, dt)
  return false
end

-- Leaves the notifications out of the next frame, so a screenshot taken at its end doesn't show them
function NotificationCenter:skipNextDraw()
  self.skippingNextDraw = true
end

function NotificationCenter:draw()
  if self.skippingNextDraw then
    self.skippingNextDraw = false
  else
    UiElement.draw(self)
  end
end

return NotificationCenter
