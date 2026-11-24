local Scene = require("client.src.scenes.Scene")
local ui = require("client.src.ui")
local Layout = require("client.src.ui.Layout")
local class = require("common.lib.class")
local logger = require("common.lib.logger")
local util = require("common.lib.util")
local NetClient = require("client.src.network.NetClient")
local MessageTransition = require("client.src.scenes.Transitions.MessageTransition")
local GameModes = require("common.data.GameModes")
local tableUtils = require("common.lib.tableUtils")
local InputSource = require("client.src.input.InputSource")
local GraphicsUtil = require("client.src.graphics.graphics_util")

local LOBBY_MENU_WIDTH = 300
local LOBBY_MENU_HEIGHT = 540
-- the gap between a player's button and the line to their challenge menu, and between the line and the menu
local SUB_MENU_LINE_GAP = 8
local SUB_MENU_BUTTON_RULES = {sizing = {horizontal = Layout.fixed(120)}}

---@param publicId PublicPlayerID
---@return string # the layout id of the player's button, which their challenge menu is pinned to
local function playerButtonId(publicId)
  return "lobbyPlayer" .. publicId
end

-- expects a serverIp and serverPort as a param (unless already set in GAME.connected_server_ip & GAME.connected_server_port respectively)
---@class LobbyScene : Scene
---@field lobbyMenu ScrollMenu
---@field lobbyMessage Label
---@field playerSubMenuConnectionWarning ConnectionWarning? beside the challenge menu while it is open
---@field playerSubMenuButton Button? the player's button the open challenge menu is beside
local Lobby = class(
function(self, sceneParams)
  self.music = "main"

  -- ui
  self.leaderboard = ui.Leaderboard({isVisible = false, layoutRules = {floating = Layout.floatAt("centerCenter", 200)}})
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
  local buttonRules = {sizing = {horizontal = Layout.fixed(self.lobbyMenuWidth)}}
  self.onePlayerEndlessButton = ui.TextButton({
    label = ui.Label({text = "mm_1_endless"}),
    layoutRules = buttonRules,
    onClick = function()
      GAME.netClient:requestRoom(GameModes.getPreset(GameModes.IDs.ONE_PLAYER_ENDLESS))
    end
  })
  self.onePlayerTimeAttackButton = ui.TextButton({
    label = ui.Label({text = "mm_1_time"}),
    layoutRules = buttonRules,
    onClick = function()
      GAME.netClient:requestRoom(GameModes.getPreset(GameModes.IDs.ONE_PLAYER_TIME_ATTACK))
    end
  })
  self.onePlayerVsButton = ui.TextButton({
    label = ui.Label({text = "mm_1_vs"}),
    layoutRules = buttonRules,
    onClick = function()
      if GAME.localPlayer.settings.style ~= GameModes.Styles.MODERN then
        GAME.localPlayer:setStyle(GameModes.Styles.MODERN)
        GAME.netClient:sendPlayerSettings(GAME.localPlayer)
      end
      GAME.netClient:requestRoom(GameModes.getPreset(GameModes.IDs.ONE_PLAYER_VS_SELF))
    end
  })
  self.leaderboardToggleLabel = ui.Label({text = "lb_show_board"})
  self.showLeaderboardButton = ui.TextButton({
    label = self.leaderboardToggleLabel,
    layoutRules = buttonRules,
    onClick = function()
      if self.leaderboard:hasFocus(InputSource.anyPlayer) then
        self.lobbyMenu:unfocusChild(InputSource.anyPlayer)
      else
        self:toggleLeaderboard()
      end
    end
  })
  self.backButton = ui.TextButton({
    label = ui.Label({text = "lb_back"}),
    layoutRules = buttonRules,
    onClick = exitMenu
  })

  self.roomPanel = ui.UiElement({
    layoutRules = {sizing = Layout.fixedSize(300, 540), floating = Layout.floatAt("centerCenter", 440)},
    isVisible = false
  })

  self.roomInfo = ui.Label({
    text = "",
    translate = false,
  })

  self.roomTimer = ui.Label({
    text = "00:00",
    translate = false,
    layoutRules = {floating = Layout.floatAt("leftTop", 0, GAME.theme.font.size * 4)}
  })

  self.roomPanel:addChild(self.roomInfo)
  self.roomPanel:addChild(self.roomTimer)

  self.lobbyMenuStartingUp = true
  self.lobbyMenu = ui.ScrollMenu({
    layoutRules = {
      sizing = Layout.fixedSize(LOBBY_MENU_WIDTH, LOBBY_MENU_HEIGHT),
      floating = Layout.floatAt("centerCenter", self.lobbyMenuXoffsetMap[false])
    }
  })

  self.uiRoot:addChild(self.lobbyMenu)
  self.uiRoot:addChild(self.roomPanel)
end

-----------------
-- leaderboard --
-----------------

function Lobby:toggleLeaderboard()
  GAME.theme:playMoveSfx()
  if not self.leaderboard.isVisible then
    self.leaderboardToggleLabel:setText("lb_hide_board")
    GAME.netClient:requestLeaderboard(GameModes.IDs.TWO_PLAYER_VS)
    self.lobbyMenu:focusChild(self.leaderboard, InputSource.anyPlayer, function() self:toggleLeaderboard() end)
  else
    self.leaderboardToggleLabel:setText("lb_show_board")
  end
  self.leaderboard:setVisibility(not self.leaderboard.isVisible)
  self.lobbyMenu:setLayoutRule("floating", Layout.floatAt("centerCenter", self.lobbyMenuXoffsetMap[self.leaderboard.isVisible]))
end

--------------------------------
-- Processing server messages --
--------------------------------

-- sends a challenge for the opponent with that id
---@param publicId PublicPlayerID
---@param gameModeId GameModeID
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
---@param room LobbyRoomV2
---@return function
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
    gameModeId = gameModeId or GameModes.IDs.TWO_PLAYER_VS
    if player.ratings[gameModeId] then
      return player.name .. " (" .. player.ratings[gameModeId] .. ")"
    else
      return player.name
    end
  end
end

---@param gameModeChallengeState table<GameModeID, boolean>
local function challengeActive(gameModeChallengeState)
  for gameMode, challenging in pairs(gameModeChallengeState) do
    if challenging then
      return true
    end
  end
  return false
end

---@param personalizedLobbyData PersonalizedLobbyDataV2
function Lobby:createPlayerButtons(personalizedLobbyData)
  local playerButtons = {}

  for publicId, player in pairs(personalizedLobbyData.players) do
    local isLocalPlayer = (publicId == GAME.localPlayer.publicId)
    local hasRoom = not not player.roomNumber
    if not isLocalPlayer and not hasRoom then
      local playerName
      if personalizedLobbyData.incomingChallenges[publicId] and challengeActive(personalizedLobbyData.incomingChallenges[publicId]) then
        playerName = Lobby.getPlayerNameWithRating(publicId) .. " " .. loc("lb_received")
      elseif personalizedLobbyData.outgoingChallenges[publicId] and challengeActive(personalizedLobbyData.outgoingChallenges[publicId]) then
        playerName = Lobby.getPlayerNameWithRating(publicId) .. " " .. loc("lb_request")
      else
        playerName = Lobby.getPlayerNameWithRating(publicId)
      end

      local button = ui.TextButton({
        label = ui.Label({text = playerName, translate = false}),
        layoutRules = {id = playerButtonId(publicId), sizing = {horizontal = Layout.fixed(self.lobbyMenuWidth)}},
        onClick =
          function(button)
            self:openPlayerSubMenu(publicId, button)
            GAME.theme:playValidationSfx()
          end
        })
      button.lobbyType = "player"
      button.player = player
      playerButtons[#playerButtons+1] = button
    end
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
      roomName = loc("lb_spectate") .. "\n" .. playerStrings[1] .. "\nvs\n" .. playerStrings[2] .. "\n(" .. room.state .. ")"
    end

    local icon
    if room.gameModeId == GameModes.IDs.TWO_PLAYER_VS or room.gameModeId == GameModes.IDs.ONE_PLAYER_VS_SELF then
      icon = GAME.theme:getFightImage()
    elseif room.gameModeId == GameModes.IDs.TWO_PLAYER_TIME_ATTACK or room.gameModeId == GameModes.IDs.ONE_PLAYER_TIME_ATTACK then
      icon = GAME.theme:getStopwatchImage()
    elseif room.gameModeId == GameModes.IDs.ONE_PLAYER_ENDLESS then
      icon = GAME.theme:getEndlessImage()
    else
      icon = GAME.theme:chainImage(0)
    end

    local button = ui.IconTextButton({
      label = ui.Label({text = roomName, translate = false, wrapWidth = LOBBY_MENU_WIDTH - 19}),
      iconSize = 16,
      icon = icon,
      layoutRules = {sizing = {horizontal = Layout.fixed(self.lobbyMenuWidth)}},
      onClick = self:requestSpectateFunction(room)
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
    self.lobbyMenu:unfocusChild(InputSource.anyPlayer)
  end

  local lobbyDataV2 = GAME.netClient.lobbyDataV2

  -- beside the player's button, following it when the list is rebuilt
  local subMenu = ui.ScrollMenu({
    padding = 0,
    childGap = 8,
    layoutRules = {
      id = "playerSubMenu",
      sizing = Layout.fixedSize(120, 88),
      floating = {
        attachTo = "element",
        parentId = playerButtonId(playerId),
        offset = {x = LOBBY_MENU_WIDTH + SUB_MENU_LINE_GAP},
      },
    },
  })

  subMenu.playerId = playerId

  local vsButton = ui.LobbyChallengeButton({
    gameModeId = GameModes.IDs.TWO_PLAYER_VS,
    iconSize = 16,
    playerId = playerId,
    label = ui.Label({text = "vs"}),
    acceptImage = GAME.theme:getFightImage(),
    proposeImage = GAME.theme:getCheckboxImage(false),
    withdrawImage = GAME.theme:getCheckboxImage(true),
    layoutRules = SUB_MENU_BUTTON_RULES
  })
  
  subMenu:addChild(vsButton)

  local timeAttackButton = ui.LobbyChallengeButton({
    gameModeId = GameModes.IDs.TWO_PLAYER_TIME_ATTACK,
    iconSize = 16,
    playerId = playerId,
    label = ui.Label({text = "gm_time_attack"}),
    acceptImage = GAME.theme:getFightImage(),
    proposeImage = GAME.theme:getCheckboxImage(false),
    withdrawImage = GAME.theme:getCheckboxImage(true),
    layoutRules = SUB_MENU_BUTTON_RULES
  })
  subMenu:addChild(timeAttackButton)

  if lobbyDataV2.outgoingChallenges[playerId] then
    if lobbyDataV2.outgoingChallenges[playerId][GameModes.IDs.TWO_PLAYER_VS] == true then
      vsButton:setState(vsButton.challengeStates.PROPOSING)
    end
    if lobbyDataV2.outgoingChallenges[playerId][GameModes.IDs.TWO_PLAYER_TIME_ATTACK] == true then
      timeAttackButton:setState(timeAttackButton.challengeStates.PROPOSING)
    end
  end

  if lobbyDataV2.incomingChallenges[playerId] then
    if lobbyDataV2.incomingChallenges[playerId][GameModes.IDs.TWO_PLAYER_VS] then
      vsButton:setState(vsButton.challengeStates.CHALLENGED)
    end
    if lobbyDataV2.incomingChallenges[playerId][GameModes.IDs.TWO_PLAYER_TIME_ATTACK] then
      timeAttackButton:setState(timeAttackButton.challengeStates.CHALLENGED)
    end
  end

  local backButton = ui.TextButton({
    label = ui.Label({text = "back"}),
    layoutRules = SUB_MENU_BUTTON_RULES,
    onClick = function()
      GAME.theme:playCancelSfx()
      self.lobbyMenu:unfocusChild(InputSource.anyPlayer)
    end})

  subMenu:addChild(backButton)
  subMenu:select(vsButton)
  self.playerSubMenu = subMenu

  -- lies over the whole scene and draws the line from the button to the menu where the last layout put them
  local subMenuLine = ui.UiElement({layoutRules = {floating = Layout.floatAt("leftTop")}})
  -- Intentional override
  ---@diagnostic disable-next-line: duplicate-set-field
  subMenuLine.drawSelf = function()
    self:drawSubMenuLine()
  end
  self.subMenuLine = subMenuLine
  self.playerSubMenuButton = button

  self.playerSubMenuConnectionWarning = self:createChallengeConnectionWarning(playerId)

  self.lobbyMenu:focusChild(subMenu, InputSource.anyPlayer, function()
    self.playerSubMenu:detach()
    self.playerSubMenu = nil
    self.subMenuLine:detach()
    self.subMenuLine = nil
    self.playerSubMenuButton = nil
    self.playerSubMenuConnectionWarning:detach()
    self.playerSubMenuConnectionWarning = nil
  end)

  self.uiRoot:addChild(subMenu)
  self.uiRoot:addChild(subMenuLine)
  self.uiRoot:addChild(self.playerSubMenuConnectionWarning)
end

-- A warning card right of the challenge menu, its top level with the menu's, that shows while your or the challenged
-- player's connection makes rollback likely
---@param playerId PublicPlayerID
---@return ConnectionWarning
function Lobby:createChallengeConnectionWarning(playerId)
  return ui.ConnectionWarning({
    layoutRules = {
      floating = {
        attachTo = "element",
        parentId = "playerSubMenu",
        attachPoints = {element = "leftTop", parent = "rightTop"},
        offset = {x = ui.ConnectionWarning.PADDING},
      },
    },
    players = {
      {publicId = GAME.localPlayer.publicId, name = GAME.localPlayer.name},
      {publicId = playerId, name = GAME.netClient.lobbyDataV2.players[playerId].name},
    },
  })
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
  local found = false

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
            found = true
            break
          end
        end

        if not found then
          if self.playerSubMenu and previousButton.player.publicId == self.playerSubMenu.playerId then
            -- the player left or started to spectate so if there's still a playerSubMenu
            self.lobbyMenu:unfocusChild(InputSource.anyPlayer)
          end
        end
      elseif previousButton.lobbyType == "room" then
        for i, roomButton in ipairs(roomButtons) do
          if previousButton.room.roomNumber == roomButton.room.roomNumber then
            self.lobbyMenu:select(roomButton)
            found = true
            break
          end
        end
      end

      -- if our previous selection disappeared, default to whatever is in its place now or the next selectable element before it
      for index = previousIndex, 2, -1 do
        local newButton = self.lobbyMenu.children[index]
        local success = self.lobbyMenu:select(newButton)
        if success then
          break
        end
      end
    elseif previousIndex == 1 then
      self.lobbyMenu:select(self.onePlayerEndlessButton)
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
        logger.warn("Unexpectedly couldn't find previous non-player/room selection, resetting to first interactable element")
        self.lobbyMenu:select(self.onePlayerEndlessButton)
      end
    end
  end

  if self.playerSubMenu then
    if not lobbyDataV2.players[self.playerSubMenu.playerId] or not found then
      self.lobbyMenu:unfocusChild(InputSource.anyPlayer)
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

      -- the menu and its warning are pinned to the button's id, so they follow the new button on their own
      self.playerSubMenuButton = previousButton
    end
  end

  self:updateRoomPanel(true)
end

------------------------------
-- scene core functionality --
------------------------------
local loginStateLabel = ui.Label({text = loc("lb_login"), translate = false})
function Lobby:updateSelf(dt)
  self.backgroundImg:update(dt)

  self:updateRoomPanel()

  if GAME.netClient.state == NetClient.STATES.LOGIN then
    loginStateLabel:setText(GAME.netClient.loginState or "")
  else
    if GAME.timer > GAME.netClient.loginTime + 5 then
      if tableUtils.length(GAME.netClient.lobbyDataV2.players) == 1 then
        self.lobbyMessage:setText("lb_alone", nil, true)
      else
        self.lobbyMessage:setText("lb_select_player", nil, true)
      end
    end
    self.lobbyMenu:receiveInputs(InputSource.anyPlayer, dt)
  end
end

---@param updateInfo boolean? if the info text should be updated even if the room number did not change
function Lobby:updateRoomPanel(updateInfo)
  local selected = self.lobbyMenu.children[self.lobbyMenu.selectedIndex]
  if not selected or not selected.room then
    if self.roomPanel.isVisible then
      self.roomPanel:setVisibility(false)
    end
  else
    if not self.roomPanel.isVisible then
      self.roomPanel:setVisibility(true)
    end

    local room = selected.room
    if room.roomNumber ~= self.roomPanel.roomNumber or updateInfo then
      self.roomPanel.roomNumber = room.roomNumber
      local text
      if #room.players == 2 then
        local p1Id = room.players[1]
        local p2Id = room.players[2]
        local p1Info = GAME.netClient.lobbyDataV2.players[p1Id]
        local p2Info = GAME.netClient.lobbyDataV2.players[p2Id]
        if p1Info and p2Info then
          local p1Name = p1Info.name
          local p2Name = p2Info.name
          text = string.format("%s %d : %d %s\n%s\n%s %d", p1Name, room.wins[1], room.wins[2], p2Name, room.state, loc("pl_spectators"), #room.spectators)
        else
          logger.warn(string.format("Failed to retrieve data for playerId %d or %d\nLobby data is %s", p1Id, p2Id, table_to_string(GAME.netClient.lobbyDataV2)))
          text = string.format("%d : %d \n%s\n%s %d\n%s", room.wins[1], room.wins[2], room.state, loc("pl_spectators"), #room.spectators, "Failed to retrieve player info")
        end
      elseif #room.players == 1 then
        text = string.format("%s\n%s %d", room.state, loc("pl_spectators"), #room.spectators)
      end
      self.roomInfo:setText(text, nil, false)
    end

    local timer = self.roomTimer.text
    if room.state == "playing" then
      if room.gameStartTime then
        local durationInSeconds = os.difftime(to_UTC(os.time()), os.time(room.gameStartTime)) - 3 - GAME.netClient.serverTimeDelta
        if durationInSeconds < 0 then
          timer = string.format("-00:%02d", math.abs(durationInSeconds))
        else
          timer = string.format("%02d:%02d", math.floor(durationInSeconds / 60), durationInSeconds % 60)
        end
      end
  
      if timer ~= self.roomTimer.text then
        self.roomTimer:setText(timer, nil, false)
      end
    elseif timer ~= "00:00" then
      self.roomTimer:setText("00:00", nil, false)
    end
  end
end

function Lobby:draw()
  self.backgroundImg:draw()
  self:drawCommunityMessage()
  if GAME.netClient.state == NetClient.STATES.LOGIN then
    -- the label is a tree of its own, laid out at the origin
    love.graphics.push("transform")
    love.graphics.translate(500, 350)
    loginStateLabel:draw()
    love.graphics.pop()
  else
    self.uiRoot:draw()
  end
end

-- Draws the line from the open challenge menu's player button to the menu, at their places in the last layout
function Lobby:drawSubMenuLine()
  local button = self.playerSubMenuButton
  local buttonX, buttonY = button:getScreenPos()
  local menuX = self.playerSubMenu:getScreenPos()
  local y = buttonY + button.layoutRect.height / 2
  love.graphics.setColor(1, 1, 1, 0.6)
  love.graphics.setLineWidth(2)
  love.graphics.line(buttonX + button.layoutRect.width + SUB_MENU_LINE_GAP, y, menuX - SUB_MENU_LINE_GAP, y)
  GraphicsUtil.setColor(1, 1, 1, 1)
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
