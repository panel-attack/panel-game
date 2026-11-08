local handleShortcuts = require("client.src.Shortcuts")
local input = require("client.src.inputManager")
local NotificationCenter = require("client.src.ui.NotificationCenter")

-- Runs test with the given keys held, a fresh notification center and the given stand-ins for love and the game in place, putting all of it back afterwards
---@param keys {allKeys: string[]?, pressed: string[]?} keys in allKeys.isDown and menu keys in isPressed
---@param standIns {target: table, key: string, value: any}[] fields replaced for the test
---@param test fun(center: NotificationCenter)
local function withShortcutState(keys, standIns, test)
  local allKeysDown, pressed = input.allKeys.isDown, input.isPressed
  local notificationCenter = GAME.notificationCenter
  input.allKeys.isDown, input.isPressed = {}, {}
  for _, key in ipairs(keys.allKeys or {}) do
    input.allKeys.isDown[key] = true
  end
  for _, key in ipairs(keys.pressed or {}) do
    input.isPressed[key] = 1
  end
  GAME.notificationCenter = NotificationCenter({})
  local originals = {}
  for i, standIn in ipairs(standIns) do
    originals[i] = standIn.target[standIn.key]
    standIn.target[standIn.key] = standIn.value
  end

  local ok, err = pcall(test, GAME.notificationCenter)

  for i = #standIns, 1, -1 do
    standIns[i].target[standIns[i].key] = originals[i]
  end
  GAME.notificationCenter = notificationCenter
  input.allKeys.isDown, input.isPressed = allKeysDown, pressed
  assert(ok, err)
end

local function testAScreenshotShowsANotification()
  local captured = {}
  local standIns = {
    {target = love.graphics, key = "captureScreenshot", value = function(path) captured[#captured + 1] = path end},
    {target = love.filesystem, key = "createDirectory", value = function() return true end},
  }
  withShortcutState({allKeys = {"f2"}}, standIns, function(center)
    handleShortcuts()

    assert(#captured == 1, "f2 should take one screenshot, but took " .. #captured)
    assert(#center.notifications == 1, "taking a screenshot should show one notification, but showed " .. #center.notifications)
    assert(center.notifications[1].label.text == "notification_screenshot_saved", "the notification should say the screenshot was saved")
  end)
end

testAScreenshotShowsANotification()

local function testAScreenshotLeavesTheNotificationsOutOfItself()
  local standIns = {
    {target = love.graphics, key = "captureScreenshot", value = function() end},
    {target = love.filesystem, key = "createDirectory", value = function() return true end},
  }
  withShortcutState({allKeys = {"f2"}}, standIns, function(center)
    handleShortcuts()

    assert(center.skippingNextDraw, "the frame the screenshot is taken at should be drawn without the notifications")
  end)
end

testAScreenshotLeavesTheNotificationsOutOfItself()

-- A scene with a one player match whose stack can describe itself as a puzzle
local function sceneWithAMatch()
  local engine = {toPuzzleInfo = function() return {Stack = "123456"} end}
  local match = {players = {{name = "Player", stack = {engine = engine}}}}
  match.stacks = {match.players[1].stack}
  return {match = match}
end

local function testCopyingStackInfoShowsANotification()
  local copied = {}
  local scene = sceneWithAMatch()
  local standIns = {
    {target = love.system, key = "setClipboardText", value = function(text) copied[#copied + 1] = text end},
    {target = GAME.navigationStack, key = "getActiveScene", value = function() return scene end},
  }
  withShortcutState({allKeys = {"c"}, pressed = {"Ctrl"}}, standIns, function(center)
    handleShortcuts()

    assert(#copied == 1, "ctrl+c in a match should copy the stack info once, but copied " .. #copied .. " times")
    assert(#center.notifications == 1, "copying the stack info should show one notification, but showed " .. #center.notifications)
    assert(center.notifications[1].label.text == "notification_stack_copied", "the notification should say the stack info was copied")
  end)
end

testCopyingStackInfoShowsANotification()

local function testCopyingOutsideAMatchShowsNoNotification()
  local standIns = {
    {target = love.system, key = "setClipboardText", value = function() end},
    {target = GAME.navigationStack, key = "getActiveScene", value = function() return {} end},
  }
  withShortcutState({allKeys = {"c"}, pressed = {"Ctrl"}}, standIns, function(center)
    handleShortcuts()

    assert(#center.notifications == 0, "ctrl+c outside a match copies nothing and should show no notification")
  end)
end

testCopyingOutsideAMatchShowsNoNotification()
