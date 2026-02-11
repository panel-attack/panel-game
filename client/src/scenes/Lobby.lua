local Scene = require("client.src.scenes.Scene")
local ui = require("client.src.ui")
local class = require("common.lib.class")
local logger = require("common.lib.logger")
local util = require("common.lib.util")
local NetClient = require("client.src.network.NetClient")
local MessageTransition = require("client.src.scenes.Transitions.MessageTransition")
local GameModes = require("common.data.GameModes")

-- expects a serverIp and serverPort as a param (unless already set in GAME.connected_server_ip & GAME.connected_server_port respectively)
local Lobby = class(function(self, sceneParams)
  self.music = "main"

  -- ui
  self.leaderboard = ui.Leaderboard({isVisible = false, x = 200, hAlign = "center", vAlign = "center"})
  self.lobbyMessage = ui.Label({text = "lb_select_player"})
  self.backgroundImg = themes[config.theme].images.bg_main
  self.lobbyMenu = nil
  self.lobbyMenuXoffsetMap = {
    [true] = -200,
    [false] = 0
  }
  -- will be used to make room in case the leaderboard should be shown.
  -- currently unused, need to find a new place to draw this later
  self.notice = {[true] = loc("lb_select_player"), [false] = loc("lb_alone")}

  self:load(sceneParams)
end, Scene)

Lobby.name = "Lobby"

----------
-- exit --
----------

local function exitMenu()
  GAME.theme:playCancelSfx()
  GAME.netClient:logout()
  GAME.navigationStack:pop()
end

-------------
-- startup --
-------------

function Lobby:load(sceneParams)
  if not GAME.netClient:isConnected() and sceneParams.serverIp then
    GAME.netClient:login(sceneParams.serverIp, sceneParams.serverPort)
  end

  GAME.netClient:connectSignal("lobbyStateV2Update", self, self.onLobbyStateUpdate)
  GAME.netClient:connectSignal("clientDisconnected", self, self.onDisconnect)
  GAME.netClient:connectSignal("leaderboardUpdate", self.leaderboard, self.leaderboard.updateData)
  GAME.netClient:connectSignal("loginFinished", self, self.onLoginFinish)

  self:initLobbyMenu()
  self.uiRoot:addChild(self.leaderboard)
end

function Lobby:initLobbyMenu()
  local menuItems = {
    ui.MenuItem.createMenuItem(self.lobbyMessage),
    ui.MenuItem.createButtonMenuItem("mm_1_endless", nil, nil, function()
      GAME.netClient:requestRoom(GameModes.getPreset("ONE_PLAYER_ENDLESS"))
    end),
    ui.MenuItem.createButtonMenuItem("mm_1_time", nil, nil, function()
      GAME.netClient:requestRoom(GameModes.getPreset("ONE_PLAYER_TIME_ATTACK"))
    end),
    ui.MenuItem.createButtonMenuItem("mm_1_vs", nil, nil, function()
      if GAME.localPlayer.settings.style ~= GameModes.Styles.MODERN then
        GAME.localPlayer:setStyle(GameModes.Styles.MODERN)
        GAME.netClient:sendPlayerSettings(GAME.localPlayer)
      end
      GAME.netClient:requestRoom(GameModes.getPreset("ONE_PLAYER_VS_SELF"))
    end),
    ui.MenuItem.createButtonMenuItem("lb_show_board", nil, nil, function()
      if self.leaderboard.hasFocus then
        self.leaderboard:yieldFocus()
      else
        self:toggleLeaderboard()
      end
    end),
    ui.MenuItem.createButtonMenuItem("lb_back", nil, nil, exitMenu)
  }
  self.leaderboardToggleLabel = menuItems[5].textButton.children[1]

  self.lobbyMenuStartingUp = true
  self.lobbyMenu = ui.Menu.createCenteredMenu(menuItems)
  self.lobbyMenu.x = self.lobbyMenuXoffsetMap[false]

  self.uiRoot:addChild(self.lobbyMenu)
end

-----------------
-- leaderboard --
-----------------

function Lobby:toggleLeaderboard()
  GAME.theme:playMoveSfx()
  if not self.leaderboard.isVisible then
    self.leaderboardToggleLabel:setText("lb_hide_board")
    GAME.netClient:requestLeaderboard()
    self.lobbyMenu:setFocus(self.leaderboard, function() self:toggleLeaderboard() end)
  else
    self.leaderboardToggleLabel:setText("lb_show_board")
  end
  self.leaderboard:setVisibility(not self.leaderboard.isVisible)
  self.lobbyMenu.x = self.lobbyMenuXoffsetMap[self.leaderboard.isVisible]
end

--------------------------------
-- Processing server messages --
--------------------------------

function Lobby:playerRatingString(playerName)
  local rating = ""
  local playerData = GAME.netClient.lobbyData.players[playerName]
  if playerData and playerData.rating then
    rating = " (" .. playerData.rating .. ")"
  end
  return rating
end

-- sends a challenge for the opponent with that id
---@param publicId PublicPlayerID
---@param gameModeId GameModeID?
function Lobby:requestGameFunction(publicId, gameModeId)
  return function()
    if GAME.localPlayer.settings.style ~= GameModes.Styles.MODERN then
      GAME.localPlayer:setStyle(GameModes.Styles.MODERN)
      GAME.netClient:sendPlayerSettings(GAME.localPlayer)
    end
    GAME.netClient:challengePlayerById(publicId, gameModeId)
    GAME.theme:playValidationSfx()
  end
end

-- requests to spectate the specified room
function Lobby:requestSpectateFunction(room)
  return function()
    GAME.netClient:requestSpectate(room.roomNumber)
    GAME.theme:playValidationSfx()
  end
end

---@param publicId PublicPlayerID
---@param gameModeId GameModeID?
---@return string
function Lobby.getPlayerNameWithRating(publicId, gameModeId)
  local player = GAME.netClient.lobbyDataV2.players[publicId]

  if not player then
    logger.warn("Tried to get rating for unknown player id " .. publicId)
    return tostring(publicId)
  else
    gameModeId = gameModeId or "TWO_PLAYER_VS"
    if player.ratings[gameModeId] then
      return player.name .. " (" .. player.ratings[gameModeId] .. ")"
    else
      return player.name
    end
  end
end

---@param personalizedLobbyData PersonalizedLobbyDataV2
function Lobby:createPlayerButtons(personalizedLobbyData)
  local playerButtons = {}

  for publicId, player in pairs(personalizedLobbyData.players) do
    --if publicId ~= GAME.localPlayer.publicId then
      local playerName
      if personalizedLobbyData.incomingChallenges[publicId] and next(personalizedLobbyData.incomingChallenges[publicId]) then 
        playerName = Lobby.getPlayerNameWithRating(publicId) .. " " .. loc("lb_received")
      elseif personalizedLobbyData.outgoingChallenges[publicId] and next(personalizedLobbyData.outgoingChallenges[publicId]) then
        playerName = Lobby.getPlayerNameWithRating(publicId) .. " " .. loc("lb_request")
      else
        playerName = Lobby.getPlayerNameWithRating(publicId)
      end

      local menuItem = ui.MenuItem.createButtonMenuItem(playerName, nil, false, 
        function(button)
          self:openPlayerSubMenu(publicId, button)
        end
      )
      ui.Focusable(menuItem.textButton)
      ui.FocusDirector(menuItem.textButton)
      menuItem.player = player
      playerButtons[#playerButtons+1] = menuItem
    --end
  end

  table.sort(playerButtons, function(a, b)
    -- a more sensible order could be login time or idle status but the server does not track those at the moment
    -- but we need a consistent order
    return a.player.publicId < b.player.publicId
  end)

  return playerButtons
end

---@param personalizedLobbyData PersonalizedLobbyDataV2
function Lobby:createRoomButtons(personalizedLobbyData)
  local roomButtons = {}

  for _, room in pairs(personalizedLobbyData.rooms) do
    ---@type table<integer, string>
    local playerStrings = {}
    for i, playerId in ipairs(room.playerIds) do
      playerStrings[i] = Lobby.getPlayerNameWithRating(playerId, room.gameModeId)
    end

    local roomName

    if #room.players == 1 then
      roomName = loc("lb_spectate") .. " " .. playerStrings[1] .. " (" .. room.state .. ")"
    else
      roomName = loc("lb_spectate") .. " " .. playerStrings[1] .. " vs " .. playerStrings[2] .. " (" .. room.state .. ")"
    end

    local menuItem = ui.MenuItem.createButtonMenuItem(roomName, nil, false, self:requestSpectateFunction(room))
    menuItem.room = room
    roomButtons[#roomButtons+1] = menuItem
  end

  table.sort(roomButtons, function(a, b)
    return a.room.roomNumber < b.room.roomNumber
  end)

  return roomButtons
end

---@param playerId PublicPlayerID
---@param button Button the button the click that opens this submenu originated from
function Lobby:openPlayerSubMenu(playerId, button)
  if self.playerSubMenu then
    self.playerSubMenu:yieldFocus()
    --self.playerSubMenu:detach()
    self.playerSubMenu = nil
  end

  local lobbyDataV2 = GAME.netClient.lobbyDataV2

  local x, y = button:getScreenPos()

  local subMenu = ui.Menu({
    x = x + button.width + 8,
    y = y,
    hAlign = "left",
    vAlign = "top",
    height = 0,
    width = 120,
    menuItems = {},
  })

  subMenu.playerId = playerId

  local backButton = ui.TextButton({
    label = ui.Label({text = "back"}),
    width = 120,
    onClick = function()
      subMenu:yieldFocus()
      self.playerSubMenu = nil
    end})

  local vsButton = ui.LobbyChallengeButton({
    gameModeId = "TWO_PLAYER_VS",
    iconSize = 16,
    playerId = playerId,
    text = "vs",
    acceptImage = GAME.theme:comboImage(4),
    proposeImage = GAME.theme:comboImage(5),
    withdrawImage = GAME.theme:comboImage(6),
    height = 24,
    width = 120
  })
  
  subMenu:addMenuItem(1, ui.MenuItem.createMenuItem(vsButton))

  local timeAttackButton = ui.LobbyChallengeButton({
    gameModeId = "TWO_PLAYER_TIME_ATTACK",
    iconSize = 16,
    playerId = playerId,
    text = "gm_time_attack",
    acceptImage = GAME.theme:comboImage(4),
    proposeImage = GAME.theme:comboImage(5),
    withdrawImage = GAME.theme:comboImage(6),
    height = 24,
    width = 120
  })
  subMenu:addMenuItem(2, ui.MenuItem.createMenuItem(timeAttackButton))

  if lobbyDataV2.outgoingChallenges[playerId] then
    if lobbyDataV2.outgoingChallenges[playerId]["TWO_PLAYER_VS"] == true then
      vsButton:setState(vsButton.challengeStates.PROPOSING)
    end
    if lobbyDataV2.outgoingChallenges[playerId]["TWO_PLAYER_TIME_ATTACK"] == true then
      timeAttackButton:setState(timeAttackButton.challengeStates.PROPOSING)
    end
  end

  if lobbyDataV2.incomingChallenges[playerId] then
    if lobbyDataV2.incomingChallenges[playerId]["TWO_PLAYER_VS"] then
      vsButton:setState(vsButton.challengeStates.CHALLENGED)
    end
    if lobbyDataV2.incomingChallenges[playerId]["TWO_PLAYER_TIME_ATTACK"] then
      timeAttackButton:setState(timeAttackButton.challengeStates.CHALLENGED)
    end
  end

  subMenu:addMenuItem(3, ui.MenuItem.createMenuItem(backButton))
  self.playerSubMenu = subMenu

  button:setFocus(subMenu, function()
    subMenu:detach()
    button:yieldFocus()
  end)

  self.uiRoot:addChild(subMenu)
end

-- rebuilds the UI based on the new lobby information
---@param lobbyDataV2 PersonalizedLobbyDataV2
function Lobby:onLobbyStateUpdate(lobbyDataV2)
  local previousText
  if self.lobbyMenu.menuItems[self.lobbyMenu.selectedIndex].textButton then
    previousText = self.lobbyMenu.menuItems[self.lobbyMenu.selectedIndex].textButton.children[1].text
  end
  local desiredIndex = self.lobbyMenu.selectedIndex

  -- cleanup previous lobby menu
  while #self.lobbyMenu.menuItems > 6 do
    self.lobbyMenu:removeMenuItemAtIndex(2)
  end
  self.lobbyMenu:setSelectedIndex(1)

  local playerButtons = self:createPlayerButtons(lobbyDataV2)

  for _, button in ipairs(playerButtons) do
    self.lobbyMenu:addMenuItem(2, button)
  end

  local roomButtons = self:createRoomButtons(lobbyDataV2)

  for _, button in ipairs(roomButtons) do
    self.lobbyMenu:addMenuItem(2, button)
  end

  if self.lobbyMenuStartingUp then
    self.lobbyMenu:setSelectedIndex(2)
    self.lobbyMenuStartingUp = false
  else
    for i = 1, #self.lobbyMenu.menuItems do
      if self.lobbyMenu.menuItems[i].textButton and self.lobbyMenu.menuItems[i].textButton.children[1].text == previousText then
        desiredIndex = i
        break
      end
    end
    self.lobbyMenu:setSelectedIndex(util.bound(2, desiredIndex, #self.lobbyMenu.menuItems))
  end

  if self.playerSubMenu then
    if not lobbyDataV2.players[self.playerSubMenu.playerId] then
      self.playerSubMenu:yieldFocus()
      self.playerSubMenu = nil
    else
      for _, menuItem in ipairs(self.playerSubMenu.children) do
        for _, item in ipairs(menuItem.children) do
          if item.gameModeId then
            ---@cast item LobbyChallengeButton
            if lobbyDataV2.incomingChallenges[self.playerSubMenu.playerId] and lobbyDataV2.incomingChallenges[self.playerSubMenu.playerId][item.gameModeId] == true then
              item:setState(item.challengeStates.CHALLENGED)
            elseif lobbyDataV2.outgoingChallenges[self.playerSubMenu.playerId] and lobbyDataV2.outgoingChallenges[self.playerSubMenu.playerId][item.gameModeId] == true then
              item:setState(item.challengeStates.PROPOSING)
            else
              item:setState(item.challengeStates.NEUTRAL)
            end
          end
          
        end
      end
    end
  end
end

------------------------------
-- scene core functionality --
------------------------------
local loginStateLabel = ui.Label({text = loc("lb_login"), translate = false, x = 500, y = 350})
function Lobby:updateSelf(dt)
  self.backgroundImg:update(dt)

  if GAME.netClient.state == NetClient.STATES.LOGIN then
    loginStateLabel:setText(GAME.netClient.loginState or "")
  else
    if GAME.timer > GAME.netClient.loginTime + 5 then
      if #GAME.netClient.lobbyData.players == 1 then
        self.lobbyMessage:setText("lb_alone", nil, true)
      else
        self.lobbyMessage:setText("lb_select_player", nil, true)
      end
    end
    self.lobbyMenu:receiveInputs()
  end
end

function Lobby:draw()
  self.backgroundImg:draw()
  self:drawCommunityMessage()
  if GAME.netClient.state == NetClient.STATES.LOGIN then
    loginStateLabel:draw()
  else
    self.uiRoot:draw()
  end
end

function Lobby:onDisconnect(voluntary)
  if not GAME.navigationStack.transition and not voluntary then
    -- automatic reconnect if we're not about to switch scene
    GAME.netClient:login(GAME.connected_server_ip, GAME.connected_server_port)
  end
end

function Lobby:onLoginFinish(result)
  if result.loggedIn then
    self.lobbyMessage:setText(result.message, nil, false)
  else
    local messageTransition = MessageTransition(love.timer.getTime(), 5, result.message)
    GAME.navigationStack:pop(messageTransition)
  end
end

return Lobby
