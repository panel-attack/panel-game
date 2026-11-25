local class = require("common.lib.class")
local UiElement = require("client.src.ui.UIElement")
local Notification = require("client.src.ui.Notification")
local Animator = require("client.src.graphics.Animator")
local consts = require("common.engine.consts")
local Layout = require("client.src.ui.Layout")

-- Shows notifications in MAX_SHOWN places stacked downward from the top right of the canvas, above every scene.
-- Game puts it in uiRoot after the navigation stack, so it is drawn over the scenes and lasts across scene changes.
-- A notification keeps its place until it has slid out; the rest wait their turn and slide into the places freed.
-- Each notification floats at the top right, a gap under the notification in the place above it, so it follows that
-- one's height; once that one leaves, it is pinned where the last layout put it.
---@class NotificationCenter : UiElement
---@field notifications Notification[] the shown notifications, oldest first
---@field places table<Notification, integer> the place each shown notification holds, 1 at the top
---@field waiting Notification[] the notifications waiting for a place, first to be shown first
---@field animator Animator runs every notification's animation on the center's clock
---@field clock number seconds the center has run
---@field nextStartTime number clock time the next notification may slide in, so notifications shown together slide in one after another
---@field skippingNextDraw boolean true to leave the notifications out of the next frame
---@overload fun(options: UiElementOptions): NotificationCenter
local NotificationCenter = class(
  ---@param self NotificationCenter
  ---@param options UiElementOptions
  function(self, options)
    local rules = options.layoutRules or {}
    if not rules.sizing then
      self:setLayoutRule("sizing", Layout.fixedSize(consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT))
    end
    -- it lies over the scenes, never beside them
    if not rules.floating then
      self:setLayoutRule("floating", Layout.floatAt("leftTop"))
    end
    self.notifications = {}
    self.places = {}
    self.waiting = {}
    self.animator = Animator()
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
  notification:setLayoutRule("id", "notification" .. notification.id)
  notification:setLayoutRule("floating", self:floatingInPlace(place))
  self:addChild(notification)
  notification:start(self.animator, self:takeStartDelay(), NotificationCenter.RIGHT_MARGIN)
end

---@param place integer
---@return Notification? # the notification shown in the place
function NotificationCenter:notificationIn(place)
  for _, notification in ipairs(self.notifications) do
    if self.places[notification] == place then
      return notification
    end
  end
end

-- Floats a notification at the top right, under the notification in the place above when there is one
---@param place integer
---@return LayoutFloating
function NotificationCenter:floatingInPlace(place)
  local above = self:notificationIn(place - 1)
  if above then
    return {
      attachTo = "element",
      parentId = above.layoutRules.id,
      attachPoints = {element = "rightTop", parent = "rightBottom"},
      offset = {y = NotificationCenter.GAP},
    }
  end
  return Layout.floatAt("rightTop", -NotificationCenter.RIGHT_MARGIN, NotificationCenter.TOP_MARGIN)
end

-- Pins the notification under the one that left where the last layout put it, so it keeps its place
---@param place integer the place of the notification that left
function NotificationCenter:pinNotificationUnder(place)
  local below = self:notificationIn(place + 1)
  if below then
    below:setLayoutRule("floating", Layout.floatAt("rightTop", -NotificationCenter.RIGHT_MARGIN, below.layoutRect.y))
  end
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
---@param dt number seconds since the last update
function NotificationCenter:updateSelf(dt)
  self.clock = self.clock + dt
  self.animator:update(dt)
  self:removeFinished()
end

-- Takes away the notifications that left and shows the waiting notifications in the places freed
function NotificationCenter:removeFinished()
  for i = #self.notifications, 1, -1 do
    local notification = self.notifications[i]
    if notification.finished then
      notification:detach()
      table.remove(self.notifications, i)
      self:pinNotificationUnder(self.places[notification])
      self.places[notification] = nil
    end
  end
  while #self.notifications < NotificationCenter.MAX_SHOWN and #self.waiting > 0 do
    self:showNow(table.remove(self.waiting, 1))
  end
end

-- Never hands a notification input, so showing one never takes it from the scene
---@param inputSource InputSource
---@param dt number seconds since the last update
function NotificationCenter:receiveInputs(inputSource, dt)
end

-- Leaves the notifications out of the next frame, so a screenshot taken at its end doesn't show them
function NotificationCenter:skipNextDraw()
  self.skippingNextDraw = true
end

-- Draws the notifications unless skipNextDraw left them out of this frame
function NotificationCenter:draw()
  if self.skippingNextDraw then
    self.skippingNextDraw = false
  else
    UiElement.draw(self)
  end
end

return NotificationCenter
