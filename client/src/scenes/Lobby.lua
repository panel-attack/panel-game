local Scene = require("client.src.scenes.Scene")
local ui = require("client.src.ui")
local class = require("common.lib.class")
local logger = require("common.lib.logger")
local util = require("common.lib.util")
local NetClient = require("client.src.network.NetClient")
local MessageTransition = require("client.src.scenes.Transitions.MessageTransition")
local GameModes = require("common.data.GameModes")
local tableUtils = require("common.lib.tableUtils")

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
  self.lobbyMenuWidth = 140
  self.onePlayerEndlessButton = ui.TextButton({
    label = ui.Label({text = "mm_1_endless"}),
    width = self.lobbyMenuWidth,
    onClick = function()
      GAME.netClient:requestRoom(GameModes.getPreset("ONE_PLAYER_ENDLESS"))
    end
  })
  self.onePlayerTimeAttackButton = ui.TextButton({
    label = ui.Label({text = "mm_1_time"}),
    width = self.lobbyMenuWidth,
    onClick = function()
      GAME.netClient:requestRoom(GameModes.getPreset("ONE_PLAYER_TIME_ATTACK"))
    end
  })
  self.onePlayerVsButton = ui.TextButton({
    label = ui.Label({text = "mm_1_vs"}),
    width = self.lobbyMenuWidth,
    onClick = function()
      if GAME.localPlayer.settings.style ~= GameModes.Styles.MODERN then
        GAME.localPlayer:setStyle(GameModes.Styles.MODERN)
        GAME.netClient:sendPlayerSettings(GAME.localPlayer)
      end
      GAME.netClient:requestRoom(GameModes.getPreset("ONE_PLAYER_VS_SELF"))
    end
  })
  self.leaderboardToggleLabel = ui.Label({text = "lb_show_board"})
  self.showLeaderboardButton = ui.TextButton({
    label = self.leaderboardToggleLabel,
    width = self.lobbyMenuWidth,
    onClick = function()
      if self.leaderboard.hasFocus then
        self.leaderboard:yieldFocus()
      else
        self:toggleLeaderboard()
      end
    end
  })
  self.backButton = ui.TextButton({
    label = ui.Label({text = "lb_back"}),
    width = self.lobbyMenuWidth,
    onClick = exitMenu
  })


  self.lobbyMenuStartingUp = true
  self.lobbyMenu = ui.ScrollMenu({height = 540, width = 300, hAlign = "center", vAlign = "center"})
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

      local button = ui.TextButton({
        label = ui.Label({text = playerName, translate = false}),
        width = self.lobbyMenuWidth,
        onClick =
          function(button)
            self:openPlayerSubMenu(publicId, button)
            GAME.theme:playValidationSfx()
          end
        })
      button.lobbyType = "player"
      button.player = player
      playerButtons[#playerButtons+1] = button
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
    for i, playerId in ipairs(room.players) do
      playerStrings[i] = Lobby.getPlayerNameWithRating(playerId, room.gameModeId)
    end

    local roomName

    if #room.players == 1 then
      roomName = loc("lb_spectate") .. " " .. playerStrings[1] .. " (" .. room.state .. ")"
    else
      roomName = loc("lb_spectate") .. " " .. playerStrings[1] .. " vs " .. playerStrings[2] .. " (" .. room.state .. ")"
    end

    local button = ui.TextButton({
      label = ui.Label({text = roomName, translate = false}),
      width = self.lobbyMenuWidth,
      onClick = function() self:requestSpectateFunction(room) end
    })
    button.lobbyType = "room"
    button.room = room
    roomButtons[#roomButtons+1] = button
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
  end

  local lobbyDataV2 = GAME.netClient.lobbyDataV2

  local x, y = button:getScreenPos()

  local subMenu = ui.ScrollMenu({
    x = x + self.lobbyMenu.width + 8,
    y = y,
    hAlign = "left",
    vAlign = "top",
    height = 88,
    width = 120,
    padding = 0,
    childGap = 8,
  })

  subMenu.playerId = playerId

  local vsButton = ui.LobbyChallengeButton({
    gameModeId = "TWO_PLAYER_VS",
    iconSize = 16,
    playerId = playerId,
    label = ui.Label({text = "vs"}),
    acceptImage = GAME.theme:getFightImage(),
    proposeImage = GAME.theme:getCheckboxImage(false),
    withdrawImage = GAME.theme:getCheckboxImage(true),
    width = 120
  })
  
  subMenu:addChild(vsButton)

  local timeAttackButton = ui.LobbyChallengeButton({
    gameModeId = "TWO_PLAYER_TIME_ATTACK",
    iconSize = 16,
    playerId = playerId,
    label = ui.Label({text = "gm_time_attack"}),
    acceptImage = GAME.theme:getFightImage(),
    proposeImage = GAME.theme:getCheckboxImage(false),
    withdrawImage = GAME.theme:getCheckboxImage(true),
    width = 120
  })
  subMenu:addChild(timeAttackButton)

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

  local backButton = ui.TextButton({
    label = ui.Label({text = "back"}),
    width = 120,
    onClick = function()
      GAME.theme:playCancelSfx()
      subMenu:yieldFocus()
    end})

  subMenu:addChild(backButton)
  subMenu:select(vsButton)
  self.playerSubMenu = subMenu

  local subMenuLine = ui.Line({
    x = x + button.width + 8,
    y = y + button.height / 2,
    height = button.height,
    points = {x + button.width + 8, y + button.height / 2, subMenu.x - 8, y + button.height / 2}
  })
  self.subMenuLine = subMenuLine

  self.lobbyMenu:setFocus(subMenu, function()
    self.playerSubMenu:detach()
    self.playerSubMenu = nil
    self.subMenuLine:detach()
    self.subMenuLine = nil
  end)

  self.uiRoot:addChild(subMenu)
  self.uiRoot:addChild(subMenuLine)
end

-- rebuilds the UI based on the new lobby information
---@param lobbyDataV2 PersonalizedLobbyDataV2
function Lobby:onLobbyStateUpdate(lobbyDataV2)
  local copy = shallowcpy(self.lobbyMenu.children)
  local previousIndex = self.lobbyMenu.selectedIndex

  self.lobbyMenu.selectedIndex = nil

  for i = #self.lobbyMenu.children, 1, -1 do
    self.lobbyMenu.children[i]:detach()
  end

  self.lobbyMenu:addChild(self.lobbyMessage)

  local playerButtons = self:createPlayerButtons(lobbyDataV2)

  for _, button in ipairs(playerButtons) do
    self.lobbyMenu:addChild(button)
  end

  local roomButtons = self:createRoomButtons(lobbyDataV2)

  for _, button in ipairs(roomButtons) do
    self.lobbyMenu:addChild(button)
  end

  self.lobbyMenu:addChild(self.onePlayerEndlessButton)
  self.lobbyMenu:addChild(self.onePlayerTimeAttackButton)
  self.lobbyMenu:addChild(self.onePlayerVsButton)
  self.lobbyMenu:addChild(self.showLeaderboardButton)
  self.lobbyMenu:addChild(self.backButton)

  local previousButton

  if self.lobbyMenuStartingUp then
    self.lobbyMenu:select(self.lobbyMenu.children[2])
    self.lobbyMenuStartingUp = false
  elseif previousIndex then
    if copy[previousIndex].lobbyType then
      previousButton = copy[previousIndex]
      if previousButton.lobbyType == "player" then
        for i, playerButton in ipairs(playerButtons) do
          if previousButton.player.publicId == playerButton.player.publicId then
            self.lobbyMenu:select(playerButton)
            previousButton = playerButton
            break
          end
        end
      elseif previousButton.lobbyType == "room" then
        for i, roomButton in ipairs(roomButtons) do
          if previousButton.room.roomNumber == roomButton.room.roomNumber then
            self.lobbyMenu:select(roomButton)
            break
          end
        end
      end
    elseif previousIndex == 1 then
      self.lobbyMenu:select(self.lobbyMessage)
    else
      local reverseOffset = #copy - previousIndex
      if reverseOffset == 0 then
        self.lobbyMenu:select(self.backButton)
      elseif reverseOffset == 1 then
        self.lobbyMenu:select(self.showLeaderboardButton)
      elseif reverseOffset == 2 then
        self.lobbyMenu:select(self.onePlayerVsButton)
      elseif reverseOffset == 3 then
        self.lobbyMenu:select(self.onePlayerTimeAttackButton)
      elseif reverseOffset == 4 then
        self.lobbyMenu:select(self.onePlayerEndlessButton)
      else
        logger.warn("Unexpectedly couldn't find previous non-player/room selection, resetting to 1")
        self.lobbyMenu:select(self.lobbyMessage)
      end
    end
  end

  if self.playerSubMenu then
    if not lobbyDataV2.players[self.playerSubMenu.playerId] then
      self.playerSubMenu:yieldFocus()
    else
      for _, button in ipairs(self.playerSubMenu.children) do
        if button.gameModeId then
          ---@cast button LobbyChallengeButton
          if lobbyDataV2.incomingChallenges[self.playerSubMenu.playerId] and lobbyDataV2.incomingChallenges[self.playerSubMenu.playerId][button.gameModeId] == true then
            button:setState(button.challengeStates.CHALLENGED)
          elseif lobbyDataV2.outgoingChallenges[self.playerSubMenu.playerId] and lobbyDataV2.outgoingChallenges[self.playerSubMenu.playerId][button.gameModeId] == true then
            button:setState(button.challengeStates.PROPOSING)
          else
            button:setState(button.challengeStates.NEUTRAL)
          end
        end
      end

      local x, y = previousButton:getScreenPos()

      self.subMenuLine.x = x + previousButton.width + 8
      self.subMenuLine.y = y + previousButton.height / 2
      self.subMenuLine:setPoints({self.subMenuLine.x, self.subMenuLine.y, self.playerSubMenu.x - 8, self.subMenuLine.y})
      self.playerSubMenu.y = y
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
    self.lobbyMenu:receiveInputs(GAME.input)
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
