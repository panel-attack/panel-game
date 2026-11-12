local class = require("common.lib.class")
local NotificationCenter = require("client.src.ui.NotificationCenter")
local Notification = require("client.src.ui.Notification")
local consts = require("common.engine.consts")
local Scene = require("client.src.scenes.Scene")
local InputSource = require("client.src.input.InputSource")

local FRAME = 1 / 60

-- Runs the center frame by frame for the given number of seconds, the way Game:update does
---@param center NotificationCenter
---@param seconds number
local function runFor(center, seconds)
  for _ = 1, math.ceil(seconds / FRAME) do
    center:update(FRAME)
  end
end

-- Seconds a lone notification takes from being shown until it has faded away
local LIFETIME = Notification.ENTER_SECONDS + Notification.HOLD_SECONDS + Notification.LEAVE_SECONDS

local function testANotificationSlidesInFromTheRight()
  local center = NotificationCenter({})
  center:show("Screenshot saved", false)
  local notification = center.notifications[1]

  assert(notification.x + notification.slideOffset >= consts.CANVAS_WIDTH,
         "a new notification should start past the right edge, but its left edge was drawn at "
           .. notification.x + notification.slideOffset)

  runFor(center, Notification.ENTER_SECONDS + 0.1)

  assert(notification.slideOffset == 0,
         "a notification should sit in its place once it has slid in, but was " .. notification.slideOffset .. " pixels off")
end

testANotificationSlidesInFromTheRight()

local function testANotificationStaysForItsHold()
  local center = NotificationCenter({})
  center:show("Screenshot saved", false)
  local notification = center.notifications[1]

  runFor(center, Notification.ENTER_SECONDS + Notification.HOLD_SECONDS - 0.1)

  assert(center.notifications[1] == notification, "a notification should still be shown before its hold is over")
  assert(notification.slideOffset == 0,
         "a notification should stay in its place during its hold, but was " .. notification.slideOffset .. " pixels off")
end

testANotificationStaysForItsHold()

local function testANotificationLeavesOnItsOwn()
  local center = NotificationCenter({})
  center:show("Screenshot saved", false)
  local notification = center.notifications[1]

  runFor(center, LIFETIME + 0.1)

  assert(#center.notifications == 0,
         "a notification should be gone after sliding in, holding and leaving, but " .. #center.notifications .. " were left")
  assert(notification.parent == nil, "a notification that left should no longer be drawn by the center")
end

testANotificationLeavesOnItsOwn()

local function testALeavingNotificationSlidesOutTheRightSide()
  local center = NotificationCenter({})
  center:show("Screenshot saved", false)
  local notification = center.notifications[1]

  runFor(center, Notification.ENTER_SECONDS + Notification.HOLD_SECONDS + Notification.LEAVE_SECONDS / 2)
  assert(notification.slideOffset > 0,
         "a leaving notification should slide toward the right edge, but was " .. notification.slideOffset .. " pixels off")

  runFor(center, Notification.LEAVE_SECONDS)
  assert(notification.x + notification.slideOffset >= consts.CANVAS_WIDTH,
         "a notification should have left past the right edge, but its left edge was last drawn at "
           .. notification.x + notification.slideOffset)
end

testALeavingNotificationSlidesOutTheRightSide()

local function testANotificationSitsAtTheTopRight()
  local center = NotificationCenter({})
  center:show("Screenshot saved", false)
  local notification = center.notifications[1]

  assert(notification.x + notification.width == consts.CANVAS_WIDTH - NotificationCenter.RIGHT_MARGIN,
         "a notification should end " .. NotificationCenter.RIGHT_MARGIN .. " pixels from the right edge, but ended at "
           .. notification.x + notification.width)
  assert(notification.y == NotificationCenter.TOP_MARGIN,
         "a lone notification should start below the match HUD at " .. NotificationCenter.TOP_MARGIN .. ", but started at "
           .. notification.y)
end

testANotificationSitsAtTheTopRight()

local function testNotificationsStackDownward()
  local center = NotificationCenter({})
  center:show("first", false)
  center:show("second", false)
  local first, second = center.notifications[1], center.notifications[2]

  assert(second.y == first.y + first.height + NotificationCenter.GAP,
         "a second notification should sit one gap below the first, but started at " .. second.y .. " with the first ending at "
           .. first.y + first.height)
end

testNotificationsStackDownward()

local function testShortNotificationsAreTheStandardWidth()
  local notification = Notification({text = "Saved", translate = false})

  assert(Notification.MIN_WIDTH and notification.width == Notification.MIN_WIDTH,
         "a short notification should be the standard width so stacked notifications line up, but was " .. notification.width .. " wide")
end

testShortNotificationsAreTheStandardWidth()

local function testNotificationsShownTogetherSlideInOneAfterAnother()
  local center = NotificationCenter({})
  center:show("first", false)
  center:show("second", false)
  local first, second = center.notifications[1], center.notifications[2]

  runFor(center, Notification.ENTER_SECONDS + 0.1)

  assert(first.slideOffset == 0, "the first notification should have slid in, but was " .. first.slideOffset .. " pixels off")
  assert(second.slideOffset > 0,
         "the second notification should wait " .. NotificationCenter.STAGGER_SECONDS .. " seconds before sliding in")

  runFor(center, NotificationCenter.STAGGER_SECONDS)

  assert(second.slideOffset == 0,
         "the second notification should have slid in after its wait, but was " .. second.slideOffset .. " pixels off")
end

testNotificationsShownTogetherSlideInOneAfterAnother()

local function testNotificationsKeepTheirPlaceWhenOneAboveLeaves()
  local center = NotificationCenter({})
  center:show("first", false)
  runFor(center, 1)
  center:show("second", false)
  local second = center.notifications[2]
  local secondY = second.y

  runFor(center, LIFETIME - 1 + 0.1)
  assert(#center.notifications == 1 and center.notifications[1] == second,
         "only the second notification should be left after the first leaves")

  runFor(center, Notification.ENTER_SECONDS + 0.1)

  assert(second.y == secondY, "the second notification should stay in its place at " .. secondY .. ", but moved to " .. second.y)
end

testNotificationsKeepTheirPlaceWhenOneAboveLeaves()

local function testANewNotificationTakesTheTopmostFreePlace()
  local center = NotificationCenter({})
  center:show("first", false)
  local topY = center.notifications[1].y
  runFor(center, 1)
  center:show("second", false)
  runFor(center, LIFETIME - 1 + 0.1)

  center:show("third", false)
  local third = center.notifications[#center.notifications]

  assert(third.y == topY, "a new notification should take the free place at the top at " .. topY .. ", but went to " .. third.y)
end

testANewNotificationTakesTheTopmostFreePlace()

local function testNotificationsPastTheLimitWait()
  local center = NotificationCenter({})
  for i = 1, NotificationCenter.MAX_SHOWN + 2 do
    center:show("notification " .. i, false)
  end

  assert(#center.notifications == NotificationCenter.MAX_SHOWN,
         "only " .. NotificationCenter.MAX_SHOWN .. " notifications should be shown, but " .. #center.notifications .. " were")
  assert(#center.children == NotificationCenter.MAX_SHOWN,
         "only the shown notifications should be drawn, but " .. #center.children .. " elements were")
end

testNotificationsPastTheLimitWait()

local function testAWaitingNotificationComesInWhenOneLeaves()
  local center = NotificationCenter({})
  for i = 1, NotificationCenter.MAX_SHOWN + 1 do
    center:show("notification " .. i, false)
  end
  local topY = center.notifications[1].y

  runFor(center, LIFETIME - 0.05)
  assert(#center.children == NotificationCenter.MAX_SHOWN, "the waiting notification should wait until the first one has fully left")

  runFor(center, 0.15)

  local waiting = center.notifications[#center.notifications]
  assert(waiting.label.text == "notification " .. NotificationCenter.MAX_SHOWN + 1,
         "the waiting notification should be shown once the first one left")
  assert(waiting.y == topY, "the waiting notification should take the first one's place at " .. topY .. ", but is at " .. waiting.y)

  runFor(center, Notification.ENTER_SECONDS + 0.1)

  assert(waiting.slideOffset == 0, "the waiting notification should slide in, but was " .. waiting.slideOffset .. " pixels off")
end

testAWaitingNotificationComesInWhenOneLeaves()

local function testAWaitingNotificationGetsItsWholeHold()
  local center = NotificationCenter({})
  for i = 1, NotificationCenter.MAX_SHOWN + 1 do
    center:show("notification " .. i, false)
  end

  runFor(center, LIFETIME + 0.1)
  local waiting = center.notifications[NotificationCenter.MAX_SHOWN]
  runFor(center, Notification.ENTER_SECONDS + Notification.HOLD_SECONDS - 0.2)

  assert(waiting.parent == center and waiting.slideOffset == 0, "a notification that waited should still hold for its whole hold")
end

testAWaitingNotificationGetsItsWholeHold()

local function testACustomNotificationIsShownLikeAnyOther()
  local center = NotificationCenter({})
  local notification = Notification({text = "custom", translate = false, holdSeconds = 1})
  center:add(notification)

  assert(center.notifications[1] == notification, "an added notification should be shown")

  runFor(center, Notification.ENTER_SECONDS + 1 + Notification.LEAVE_SECONDS + 0.1)

  assert(#center.notifications == 0, "a notification should leave after its own hold")
end

testACustomNotificationIsShownLikeAnyOther()

local function testTheCenterCanSkipOneDraw()
  local center = NotificationCenter({})
  center:show("Screenshot saved", false)
  local notification = center.notifications[1]
  local draws = 0
  notification.draw = function()
    draws = draws + 1
  end

  center:skipNextDraw()
  center:draw()
  assert(draws == 0, "the notifications should not be drawn on the skipped frame")

  center:draw()
  assert(draws == 1, "the notifications should be drawn again on the frame after")
end

testTheCenterCanSkipOneDraw()

-- Runs test with a notification shown by the game's own center, taking it back out afterwards even if the test fails
---@param test fun(center: NotificationCenter, notification: Notification)
local function withGameNotification(test)
  local center = GAME.notificationCenter
  local notification = Notification({text = "Screenshot saved", translate = false})
  center:add(notification)

  local ok, err = pcall(test, center, notification)

  for _, shown in ipairs(center.notifications) do
    shown:detach()
  end
  center.notifications, center.places, center.waiting = {}, {}, {}
  assert(ok, err)
end

local function testTheGameShowsNotificationsInItsUiRoot()
  assert(GAME.notificationCenter.parent == GAME.uiRoot, "the game's notification center should be a child of its uiRoot")
end

testTheGameShowsNotificationsInItsUiRoot()

local function testNotificationsAreDrawnAboveTheScenes()
  local sceneIndex, centerIndex
  for i, child in ipairs(GAME.uiRoot.children) do
    if child == GAME.navigationStack then
      sceneIndex = i
    elseif child == GAME.notificationCenter then
      centerIndex = i
    end
  end
  assert(sceneIndex and centerIndex and centerIndex > sceneIndex,
         "the notification center should come after the scenes in uiRoot so it is drawn over them, but was at "
         .. tostring(centerIndex) .. " with the scenes at " .. tostring(sceneIndex))
end

testNotificationsAreDrawnAboveTheScenes()

-- A scene to switch to
---@class OtherScene : Scene
local OtherScene = class(function(self) end, Scene)
OtherScene.name = "OtherScene"

local function testNotificationsLastAcrossSceneChanges()
  local stack = GAME.navigationStack
  local scenes, transition = {unpack(stack.scenes)}, stack.transition
  withGameNotification(function(center, notification)
    local clock = center.clock
    stack:push(OtherScene({}))
    GAME.uiRoot:update(FRAME)
    stack.scenes, stack.transition = scenes, transition

    assert(center.parent == GAME.uiRoot and notification.parent == center, "a notification should still be shown after the scene changed")
    assert(center.clock > clock, "updating uiRoot should run the notifications on through the scene change")
  end)
end

testNotificationsLastAcrossSceneChanges()

local function testNotificationsNeverTakeTouches()
  withGameNotification(function(_, notification)
    notification.onTouch = function() end
    local x, y = notification:getScreenPos()

    local touched = GAME.uiRoot:getTouchedElement(x + notification.width / 2, y + notification.height / 2)

    assert(touched ~= notification, "a touch on a notification should go to the scene under it")
  end)
end

testNotificationsNeverTakeTouches()

local function testNotificationsNeverTakeInput()
  withGameNotification(function(center, notification)
    local received = false
    notification.receiveInputsSelf = function()
      received = true
    end
    center:focusChild(notification, InputSource.anyPlayer)

    center:receiveInputs(InputSource.anyPlayer, FRAME)
    center:unfocusChild(InputSource.anyPlayer)

    assert(not received, "a notification should never be handed input, even one focused for an input source")
  end)
end

testNotificationsNeverTakeInput()

local function testAScreenshotFrameDrawsUiRootWithoutTheNotifications()
  withGameNotification(function(center, notification)
    local draws = 0
    notification.draw = function()
      draws = draws + 1
    end
    local canvas = love.graphics.newCanvas(consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT)
    love.graphics.setCanvas({canvas, stencil = true})

    center:skipNextDraw()
    GAME.uiRoot:draw()
    local skippedDraws = draws
    GAME.uiRoot:draw()
    love.graphics.setCanvas()

    assert(skippedDraws == 0, "the frame a screenshot is taken at should draw uiRoot without the notifications")
    assert(draws == 1, "drawing uiRoot should draw the notifications again on the frame after")
  end)
end

testAScreenshotFrameDrawsUiRootWithoutTheNotifications()
