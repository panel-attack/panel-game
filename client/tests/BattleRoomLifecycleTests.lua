local Player = require("client.src.Player")
local GameModes = require("common.data.GameModes")
local NetClient = require("client.src.network.NetClient")
local Signal = require("common.lib.signal")
local NotificationCenter = require("client.src.ui.NotificationCenter")
require("client.src.BattleRoom")

-- The tables whose own fields the tests replace or the code under test changes
local function touchedTables()
  local netClient = GAME.netClient
  return {netClient, netClient.tcpClient, netClient.messageListeners, netClient.roomListeners, GAME.navigationStack, GAME}
end

-- A copy of every table's own fields, so they can be put back exactly
local function snapshot(tables)
  local copies = {}
  for i, t in ipairs(tables) do
    local copy = {}
    for key, value in next, t do
      copy[key] = value
    end
    copies[i] = copy
  end
  return copies
end

-- Puts every table's own fields back the way the snapshot found them, removing the ones it didn't have
local function restore(tables, copies)
  for i, t in ipairs(tables) do
    local copy = copies[i]
    local added = {}
    for key in next, t do
      if copy[key] == nil then
        added[#added + 1] = key
      end
    end
    for _, key in ipairs(added) do
      rawset(t, key, nil)
    end
    for key, value in next, copy do
      rawset(t, key, value)
    end
  end
end

local stateBeforeTheTests = snapshot(touchedTables())

-- Runs test as if the net client were connected, recording the requests it sends instead of sending them
-- and the scenes it pops to instead of popping, with the transition each pop would have played.
-- It also shows notifications on a fresh notification center. Everything it replaces is put back afterwards, even if the test fails.
---@param test fun(sent: table[], poppedTo: string[], transitions: table[])
local function whileOnline(test)
  local tables = touchedTables()
  local copies = snapshot(tables)
  local sent, poppedTo, transitions = {}, {}, {}
  GAME.notificationCenter = NotificationCenter({})
  GAME.netClient.isConnected = function() return true end
  GAME.netClient.tcpClient.sendRequest = function(_, request)
    sent[#sent + 1] = request.messageText
  end
  GAME.navigationStack.popToName = function(_, name, transition, callback)
    poppedTo[#poppedTo + 1] = name
    transitions[#poppedTo] = transition
  end

  local ok, err = pcall(test, sent, poppedTo, transitions)

  restore(tables, copies)
  assert(ok, err)
end

---@param sent table[]
---@return integer
local function leaveRequests(sent)
  local count = 0
  for _, message in ipairs(sent) do
    if type(message) == "table" and message.leave_room then
      count = count + 1
    end
  end
  return count
end

-- An online room the net client has joined, the way NetClient sets one up from the server's create_room
---@return BattleRoom
local function joinRoom()
  local room = BattleRoom(GameModes.getPreset(GameModes.IDs.TWO_PLAYER_VS))
  assert(room.online, "the room should consider itself online")
  local localPlayer = Player("LocalPlayer", 1, true)
  localPlayer.playerNumber = 1
  room:addPlayer(localPlayer)
  local remotePlayer = Player("RemotePlayer", 2, false)
  remotePlayer.playerNumber = 2
  room:addPlayer(remotePlayer)
  GAME.netClient:registerPlayerUpdates(room)
  GAME.battleRoom = room
  GAME.netClient.room = room
  GAME.netClient:setState(NetClient.STATES.ROOM)
  return room
end

---@param reason string? why the server closed the room, sent only when a player in it left
local function receiveLeaveRoom(reason)
  for subscriber, callback in pairs(GAME.netClient.messageListeners.leave_room.subscriptionList) do
    callback(subscriber, {leave_room = true, reason = reason})
  end
end

local function testLeavingARoomSendsOneLeaveRoom()
  whileOnline(function(sent, poppedTo)
    local room = joinRoom()

    room:shutdown()
    room:shutdown()

    assert(leaveRequests(sent) == 1, "shutting a room down twice should leave it once, but sent " .. leaveRequests(sent))
    assert(GAME.battleRoom == nil, "the room should no longer be the game's battle room")
  end)
end

testLeavingARoomSendsOneLeaveRoom()

local function testServerConfirmingTheLeaveDoesNotShutTheRoomDownAgain()
  whileOnline(function(sent, poppedTo)
    local room = joinRoom()
    room:shutdown()

    receiveLeaveRoom()

    assert(leaveRequests(sent) == 1, "the server's confirmation should not be answered with another leave, but sent " .. leaveRequests(sent))
    assert(#poppedTo == 0, "the client already left the room's scene, but the confirmation popped to " .. tostring(poppedTo[1]))
    assert(GAME.netClient.room == nil, "the confirmation should clear the net client's room")
    assert(GAME.netClient.state == NetClient.STATES.ONLINE, "the confirmation should put the net client back in the lobby")
  end)
end

testServerConfirmingTheLeaveDoesNotShutTheRoomDownAgain()

local function testServerClosingTheRoomShutsItDown()
  whileOnline(function(sent, poppedTo)
    local room = joinRoom()

    receiveLeaveRoom()

    assert(room.hasShutdown, "the server closing the room should shut it down")
    assert(leaveRequests(sent) == 0, "a room the server closed should not be left again, but sent " .. leaveRequests(sent))
    assert(#poppedTo == 1 and poppedTo[1] == "Lobby", "the server closing the room should return to the lobby")
    assert(GAME.battleRoom == nil, "the closed room should no longer be the game's battle room")
  end)
end

testServerClosingTheRoomShutsItDown()

local function testAPlayerLeavingShowsWhyInANotification()
  whileOnline(function(sent, poppedTo)
    joinRoom()

    receiveLeaveRoom("RemotePlayer left")

    local notifications = GAME.notificationCenter.notifications
    assert(#notifications == 1, "the server saying why the room closed should show one notification, but showed " .. #notifications)
    assert(notifications[1].label.text == "RemotePlayer left", "the notification should give the server's reason, but said " .. notifications[1].label.text)
    assert(notifications[1].label.translate == false, "the server's reason is not a localization key")
  end)
end

testAPlayerLeavingShowsWhyInANotification()

-- A match in progress, standing in for the ClientMatch the room would have going
local function matchInProgress()
  local match = {aborted = false}
  function match:disconnectSignal() end
  function match:abort()
    self.aborted = true
  end
  function match:deinit() end
  return match
end

local function testAPlayerLeavingMidMatchGoesStraightToTheLobby()
  whileOnline(function(sent, poppedTo, transitions)
    local room = joinRoom()
    local match = matchInProgress()
    room.match = match

    receiveLeaveRoom("RemotePlayer left")

    assert(match.aborted, "the match should be aborted when the room closes during it")
    assert(#poppedTo == 1 and poppedTo[1] == "Lobby", "the room closing should return to the lobby")
    assert(transitions[1] == nil, "the reason is shown in a notification, so returning to the lobby should not wait on a message screen")
    assert(#GAME.notificationCenter.notifications == 1, "the reason should be shown in a notification")
  end)
end

testAPlayerLeavingMidMatchGoesStraightToTheLobby()

local function testTheServerClosingTheRoomWithoutAReasonShowsNoNotification()
  whileOnline(function()
    joinRoom()

    receiveLeaveRoom("")

    assert(#GAME.notificationCenter.notifications == 0, "a room closed without a reason should show no notification")
  end)
end

testTheServerClosingTheRoomWithoutAReasonShowsNoNotification()

---@param player Player
---@return integer
local function settingsCallbacks(player)
  local callbacks = player.signalSubscriptions.characterIdChanged[player]
  return callbacks and #callbacks or 0
end

local function testRoomsDoNotPileUpSettingsCallbacks()
  whileOnline(function()
    local player = Player("LocalPlayer", 1, true)
    for i = 1, 3 do
      local room = BattleRoom(GameModes.getPreset(GameModes.IDs.TWO_PLAYER_VS))
      room:addPlayer(player)
      GAME.netClient:registerPlayerUpdates(room)
      assert(settingsCallbacks(player) == 1, "room " .. i .. " should leave one settings callback, found " .. settingsCallbacks(player))
      room:shutdown()
      assert(settingsCallbacks(player) == 0, "room " .. i .. " should take its settings callback with it, found " .. settingsCallbacks(player))
    end
  end)
end

testRoomsDoNotPileUpSettingsCallbacks()

local function testAnOldRoomLeavesTheNewOneAlone()
  whileOnline(function(sent, poppedTo)
    local oldRoom = joinRoom()
    oldRoom:shutdown()
    receiveLeaveRoom()
    local newRoom = joinRoom()

    oldRoom:shutdown()
    assert(GAME.battleRoom == newRoom, "shutting the old room down again should not clear the new room")

    -- what NetClient:disconnect does to the rooms, without closing the test game's connection or touching its local player
    GAME.netClient.room = nil
    GAME.netClient:emitSignal("clientDisconnected", false)
    assert(newRoom.hasShutdown, "losing the connection should shut the current room down")
    assert(#poppedTo == 1, "only the current room should react to losing the connection, but " .. #poppedTo .. " did")
  end)
end

testAnOldRoomLeavesTheNewOneAlone()

local function testDisconnectingAMissingCallbackKeepsTheOthers()
  local emitter = {}
  Signal.turnIntoEmitter(emitter)
  emitter:createSignal("changed")
  local subscriber = {}
  local function kept() end
  local function neverConnected() end
  emitter:connectSignal("changed", subscriber, kept)

  emitter:disconnectSignal("changed", subscriber, neverConnected)

  assert(emitter.signalSubscriptions.changed[subscriber][1] == kept,
         "disconnecting a callback that was never connected should keep the connected one")
end

testDisconnectingAMissingCallbackKeepsTheOthers()

-- The tests above stand in for the connection, the server and the navigation stack. Nothing of that may outlive them:
-- the next test file runs in the same game.
local function testEverythingTheTestsTouchedIsBack()
  local tables = touchedTables()
  for i, t in ipairs(tables) do
    local before = stateBeforeTheTests[i]
    for key, value in next, t do
      assert(before[key] == value, "field " .. tostring(key) .. " of touched table " .. i .. " was left changed")
    end
    for key, value in next, before do
      assert(rawget(t, key) == value, "field " .. tostring(key) .. " of touched table " .. i .. " was left changed")
    end
  end
  assert(GAME.netClient.isConnected == NetClient.isConnected, "the net client should use its own isConnected again")
end

testEverythingTheTestsTouchedIsBack()
