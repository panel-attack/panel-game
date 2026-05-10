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
---@class LobbyScene : Scene
---@field lobbyMenu ScrollMenu
---@field lobbyMessage Label
local Lobby = class(
function(self, sceneParams)
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
      GAME.netClient:requestRoom(GameModes.getPreset(GameModes.IDs.ONE_PLAYER_ENDLESS))
    end
  })
  self.onePlayerTimeAttackButton = ui.TextButton({
    label = ui.Label({text = "mm_1_time"}),
    width = self.lobbyMenuWidth,
    onClick = function()
      GAME.netClient:requestRoom(GameModes.getPreset(GameModes.IDs.ONE_PLAYER_TIME_ATTACK))
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
      GAME.netClient:requestRoom(GameModes.getPreset(GameModes.IDs.ONE_PLAYER_VS_SELF))
    end
  })
  self.teamCreateButtonLabel = ui.Label({text = "Create team game", translate = false})

  -- Create confirmation overlay for leaving team games
  self.leaveConfirmOverlay = ui.OverlayContainer({})
  local confirmPanel = ui.StackPanel({
    alignment = "center",
    hFill = true,
    childGap = 12,
  })
  confirmPanel:addChild(ui.Label({text = "Leave this team game?", translate = false}))
  local confirmButtonPanel = ui.StackPanel({
    alignment = "center",
    orientation = "horizontal",
    hFill = true,
    childGap = 16,
  })
  confirmButtonPanel:addChild(ui.TextButton({
    label = ui.Label({text = "Yes", translate = false}),
    width = 80,
    onClick = function()
      self.leaveConfirmOverlay:close()
      GAME.netClient:leaveRoom()
    end
  }))
  confirmButtonPanel:addChild(ui.TextButton({
    label = ui.Label({text = "No", translate = false}),
    width = 80,
    onClick = function()
      self.leaveConfirmOverlay:close()
    end
  }))
  confirmPanel:addChild(confirmButtonPanel)
  self.leaveConfirmOverlay:setContent(confirmPanel)

  self.teamCreateButton = ui.TextButton({
    label = self.teamCreateButtonLabel,
    width = self.lobbyMenuWidth,
    onClick = function(button)
      if self:isLocalPlayerInRoom() then
        local playerCount = self:getRoomPlayerCount()
        if playerCount > 1 then
          -- Show confirmation dialog
          self.leaveConfirmOverlay:open()
        else
          -- Leave immediately if alone
          GAME.netClient:leaveRoom()
        end
        return
      end

      -- open team composition options first, then go one level deeper for garbage mode
      if self.teamCreateMenu then
        self.teamCreateMenu:yieldFocus()
        return
      end

      local x, y = button:getScreenPos()
      local subMenu = ui.ScrollMenu({
        x = x + self.lobbyMenu.width + 8,
        y = y,
        hAlign = "left",
        vAlign = "top",
        height = 132,
        width = 220,
        padding = 0,
        childGap = 8,
      })

      local function openGarbageMenu(compositionButton, options)
        if self.teamGarbageMenu then
          self.teamGarbageMenu:yieldFocus()
        end

        local bx, by = compositionButton:getScreenPos()
        local garbageMenu = ui.ScrollMenu({
          x = bx + compositionButton.width + 8,
          y = by,
          hAlign = "left",
          vAlign = "top",
          height = 88,
          width = 260,
          padding = 0,
          childGap = 8,
        })

        local allBtn = ui.TextButton({
          label = ui.Label({text = options.labelPrefix .. " - garbage hits all opponents", translate = false}),
          width = 260,
          onClick = function()
            GAME.netClient:requestRoom(GameModes.getPreset(options.allMode))
            garbageMenu:yieldFocus()
            subMenu:yieldFocus()
          end
        })
        garbageMenu:addChild(allBtn)

        local sharedBtn = ui.TextButton({
          label = ui.Label({text = options.labelPrefix .. " - garbage shared by enemy team", translate = false}),
          width = 260,
          onClick = function()
            GAME.netClient:requestRoom(GameModes.getPreset(options.sharedMode))
            garbageMenu:yieldFocus()
            subMenu:yieldFocus()
          end
        })
        garbageMenu:addChild(sharedBtn)

        if #garbageMenu.children > 0 then
          garbageMenu:select(garbageMenu.children[1])
        end

        self.teamGarbageMenu = garbageMenu
        subMenu:setFocus(garbageMenu, function()
          subMenu:select(compositionButton)
          self.teamGarbageMenu:detach()
          self.teamGarbageMenu = nil
        end)
        self.uiRoot:addChild(garbageMenu)
      end
        subMenu.originButton = button

      local abbBtn = ui.TextButton({
        label = ui.Label({text = "ABB (1v2)", translate = false}),
        width = 220,
        onClick = function(b)
          openGarbageMenu(b, {
            labelPrefix = "ABB",
            allMode = GameModes.IDs.THREE_PLAYER_VS_ALL,
            sharedMode = GameModes.IDs.THREE_PLAYER_VS_SHARED
          })
        end
      })
      subMenu:addChild(abbBtn)

      local aabbBtn = ui.TextButton({
        label = ui.Label({text = "AABB (2v2)", translate = false}),
        width = 220,
        onClick = function(b)
          openGarbageMenu(b, {
            labelPrefix = "AABB",
            allMode = GameModes.IDs.FOUR_PLAYER_TEAM_VS_ALL,
            sharedMode = GameModes.IDs.FOUR_PLAYER_TEAM_VS_SHARED
          })
        end
      })
      subMenu:addChild(aabbBtn)

      local aabBtn = ui.TextButton({
        label = ui.Label({text = "AAB (2v1)", translate = false}),
        width = 220,
        onClick = function(b)
          -- reverse-path variant using the same 3-player team rule set
          openGarbageMenu(b, {
            labelPrefix = "AAB",
            allMode = GameModes.IDs.THREE_PLAYER_VS_ALL,
            sharedMode = GameModes.IDs.THREE_PLAYER_VS_SHARED
          })
        end
      })
      subMenu:addChild(aabBtn)

      if #subMenu.children > 0 then
        subMenu:select(subMenu.children[1])
      end

      self.teamCreateMenu = subMenu
      self.lobbyMenu:setFocus(subMenu, function()
        if self.teamGarbageMenu then
          self.teamGarbageMenu:detach()
          self.teamGarbageMenu = nil
        end
        self.teamCreateMenu:detach()
        self.teamCreateMenu = nil
      end)
      self.uiRoot:addChild(subMenu)
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

  self.roomPanel = ui.UiElement({
    x = 440,
    hAlign = "center",
    vAlign = "center",
    width = 300,
    height = 540,
    isVisible = false
  })

  self.roomInfo = ui.Label({
    text = "",
    translate = false,
    hAlign = "left",
    vAlign = "top",
  })

  self.roomTimer = ui.Label({
    text = "00:00",
    translate = false,
    hAlign = "left",
    vAlign = "top",
    y = GAME.theme.font.size * 4
  })

  self.roomPanel:addChild(self.roomInfo)
  self.roomPanel:addChild(self.roomTimer)

  self.lobbyMenuStartingUp = true
  self.lobbyMenu = ui.ScrollMenu({height = 540, width = 300, hAlign = "center", vAlign = "center"})
  self.lobbyMenu.x = self.lobbyMenuXoffsetMap[false]

  self.uiRoot:addChild(self.lobbyMenu)
  self.uiRoot:addChild(self.roomPanel)
  self.uiRoot:addChild(self.leaveConfirmOverlay)
end

---@param lobbyDataV2 PersonalizedLobbyDataV2?
---@return boolean
function Lobby:isLocalPlayerInRoom(lobbyDataV2)
  if GAME.netClient.room then
    return true
  end

  lobbyDataV2 = lobbyDataV2 or GAME.netClient.lobbyDataV2
  local localData = lobbyDataV2 and lobbyDataV2.players and lobbyDataV2.players[GAME.localPlayer.publicId]
  return localData and localData.roomNumber ~= nil
end

---@param lobbyDataV2 PersonalizedLobbyDataV2?
function Lobby:updateTeamCreateButtonState(lobbyDataV2)
  if self:isLocalPlayerInRoom(lobbyDataV2) then
    self.teamCreateButtonLabel:setText("Leave team game", nil, false)
  else
    self.teamCreateButtonLabel:setText("Create team game", nil, false)
  end
end

-- Gets the number of players in the local player's current room
---@return number
function Lobby:getRoomPlayerCount()
  -- First check the active BattleRoom
  if GAME.netClient.room and GAME.netClient.room.players then
    return #GAME.netClient.room.players
  end

  -- Fall back to lobby data
  local lobbyData = GAME.netClient.lobbyDataV2
  if not lobbyData then
    return 0
  end

  local localData = lobbyData.players and lobbyData.players[GAME.localPlayer.publicId]
  if not localData or not localData.roomNumber then
    return 0
  end

  local room = lobbyData.rooms and lobbyData.rooms[localData.roomNumber]
  if room and room.players then
    return #room.players
  end

  return 0
end

-- Helper to format a slot number into a team label like A1/B2 based on game mode
local function getSlotLabel(room, slotNumber)
  if not room or not room.gameModeId then
    return "Slot " .. tostring(slotNumber)
  end

  local ok, gm = pcall(GameModes.getPreset, room.gameModeId)
  if not ok or not gm then
    return "Slot " .. tostring(slotNumber)
  end

  local playersPerTeam = gm.playersPerTeam
  if type(playersPerTeam) == "number" then
    local n = playersPerTeam
    local teamIndex = math.floor((slotNumber - 1) / n) + 1
    local within = ((slotNumber - 1) % n) + 1
    local teamLetter = (teamIndex == 1) and "A" or "B"
    return teamLetter .. tostring(within)
  elseif type(playersPerTeam) == "table" then
    local cumulative = 0
    for idx, count in ipairs(playersPerTeam) do
      if slotNumber <= cumulative + count then
        local within = slotNumber - cumulative
        local teamLetter = (idx == 1) and "A" or "B"
        return teamLetter .. tostring(within)
      end
      cumulative = cumulative + count
    end
  end

  return "Slot " .. tostring(slotNumber)
end

-----------------
-- leaderboard --
-----------------

function Lobby:toggleLeaderboard()
  GAME.theme:playMoveSfx()
  if not self.leaderboard.isVisible then
    self.leaderboardToggleLabel:setText("lb_hide_board")
    GAME.netClient:requestLeaderboard(GameModes.IDs.TWO_PLAYER_VS)
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

-- requests to join the specified room at a slot
---@param room LobbyRoomV2
---@param slotNumber integer
---@return function
function Lobby:requestJoinRoomFunction(room, slotNumber)
  return function()
    local roomOwnerId = room.ownerId or (room.players and room.players[1])
    logger.info("Requesting approval to join room " .. tostring(room.roomNumber) .. " at slot " .. tostring(slotNumber) .. " from owner " .. tostring(roomOwnerId))
    if roomOwnerId then
      GAME.netClient:invitePlayerToRoom(roomOwnerId, room.roomNumber, slotNumber, room.gameModeId)
    else
      GAME.netClient:requestJoinRoom(room.roomNumber, slotNumber)
    end
    GAME.theme:playValidationSfx()
  end
end

---@param publicId PublicPlayerID
---@param room LobbyRoomV2
---@param slotNumber integer
---@return function
function Lobby:requestInviteFunction(publicId, room, slotNumber)
  return function()
    GAME.netClient:invitePlayerToRoom(publicId, room.roomNumber, slotNumber, room.gameModeId)
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

---@param lobbyData PersonalizedLobbyDataV2
---@param publicId PublicPlayerID
---@return boolean
local function isPlayerInAnyRoom(lobbyData, publicId)
  if not lobbyData or not lobbyData.rooms then
    return false
  end

  for _, room in pairs(lobbyData.rooms) do
    if room.players then
      for _, playerId in ipairs(room.players) do
        if playerId == publicId then
          return true
        end
      end
    end
  end

  return false
end

---@param personalizedLobbyData PersonalizedLobbyDataV2
function Lobby:createPlayerButtons(personalizedLobbyData)
  if self:isLocalPlayerInRoom(personalizedLobbyData) then
    return {}
  end

  local playerButtons = {}

  for publicId, player in pairs(personalizedLobbyData.players) do
    local isLocalPlayer = (publicId == GAME.localPlayer.publicId)
    local hasRoom = (player.roomNumber ~= nil) or isPlayerInAnyRoom(personalizedLobbyData, publicId)
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
  local localPublicId = GAME.localPlayer.publicId
  local localInRoom = self:isLocalPlayerInRoom(personalizedLobbyData)
  local localRoomNumber = personalizedLobbyData.players[localPublicId] and personalizedLobbyData.players[localPublicId].roomNumber

  for _, room in pairs(personalizedLobbyData.rooms) do
    if localInRoom and room.roomNumber ~= localRoomNumber then
      goto continue
    end

    -- Check if local player is in this room
    local isLocalPlayerRoom = false
    for _, playerId in ipairs(room.players) do
      if playerId == localPublicId then
        isLocalPlayerRoom = true
        break
      end
    end

    ---@type table<integer, string>
    local playerStrings = {}
    for i, playerId in ipairs(room.players) do
      playerStrings[i] = Lobby.getPlayerNameWithRating(playerId, room.gameModeId)
    end

    -- Check if room is waiting for players (has open slots)
    local hasOpenSlots = room.openSlots and #room.openSlots > 0
    local roomName
    local onClick

    if isLocalPlayerRoom and hasOpenSlots then
      -- This is the local player's team room - show status
      local slotsText = string.format("[%d/%d]", #room.players, room.maxPlayers or 2)

      -- Build player list with slot labels
      local playerLines = {}
      for i, playerId in ipairs(room.players) do
        local slotLabel = getSlotLabel(room, i)
        local playerName = personalizedLobbyData.players[playerId] and personalizedLobbyData.players[playerId].name or "?"
        if playerId == localPublicId then
          playerLines[#playerLines + 1] = slotLabel .. ": " .. playerName .. " (You)"
        else
          playerLines[#playerLines + 1] = slotLabel .. ": " .. playerName
        end
      end

      -- Build waiting list
      local waitingSlots = {}
      for _, slotNumber in ipairs(room.openSlots) do
        local slotLabel = getSlotLabel(room, slotNumber)
        if room.slotRequests and room.slotRequests[slotNumber] then
          local requester = personalizedLobbyData.players[room.slotRequests[slotNumber]]
          if requester then
            slotLabel = slotLabel .. " ← " .. requester.name
          end
        end
        waitingSlots[#waitingSlots + 1] = slotLabel
      end

      roomName = "Your Team Room " .. slotsText .. "\n" .. table.concat(playerLines, "\n")
      if #waitingSlots > 0 then
        roomName = roomName .. "\nWaiting: " .. table.concat(waitingSlots, ", ")
      end

      -- Clicking the local team's room opens room actions instead of doing nothing
      onClick = function(button)
        self:openLocalRoomSubMenu(room, button)
        GAME.theme:playValidationSfx()
      end
    elseif hasOpenSlots then
      -- Waiting room - show join option
      local slotsText = string.format("%d/%d", #room.players, room.maxPlayers or 2)
      if #room.players == 1 then
        roomName = loc("lb_join") .. " " .. playerStrings[1] .. " [" .. slotsText .. "]"
      else
        roomName = loc("lb_join") .. "\n" .. table.concat(playerStrings, "\nvs\n") .. "\n[" .. slotsText .. "]"
      end
      -- Clicking opens room submenu for joining
      onClick = function(button)
        self:openRoomSubMenu(room, button)
        GAME.theme:playValidationSfx()
      end
    else
      -- Full room - show spectate option
      if #room.players == 1 then
        roomName = loc("lb_spectate") .. " " .. playerStrings[1] .. " (" .. room.state .. ")"
      else
        roomName = loc("lb_spectate") .. "\n" .. playerStrings[1] .. "\nvs\n" .. playerStrings[2] .. "\n(" .. room.state .. ")"
      end
      onClick = self:requestSpectateFunction(room)
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
      label = ui.Label({text = roomName, translate = false, wrapWidth = self.lobbyMenu.width - 19}),
      iconSize = 16,
      icon = icon,
      width = self.lobbyMenuWidth,
      onClick = onClick
    })
    button.lobbyType = "room"
    button.room = room
    button.isLocalPlayerRoom = isLocalPlayerRoom
    roomButtons[#roomButtons+1] = button

    ::continue::
  end

  -- Sort: local player's room first, then by room number
  table.sort(roomButtons, function(a, b)
    if a.isLocalPlayerRoom ~= b.isLocalPlayerRoom then
      return a.isLocalPlayerRoom
    end
    return a.room.roomNumber < b.room.roomNumber
  end)

  return roomButtons
end

---@param room LobbyRoomV2
---@param button Button the button click that opens this submenu originated from
function Lobby:openRoomSubMenu(room, button)
  if self.roomSubMenu then
    self.roomSubMenu:yieldFocus()
  end

  local lobbyDataV2 = GAME.netClient.lobbyDataV2
  local localPlayerInfo = lobbyDataV2 and lobbyDataV2.players and lobbyDataV2.players[GAME.localPlayer.publicId]
  local localRoomNumber = localPlayerInfo and localPlayerInfo.roomNumber or (GAME.netClient.room and GAME.netClient.room.roomNumber)
  local localIsMemberOfRoom = room.players and tableUtils.trueForAny(room.players, function(playerId)
    return playerId == GAME.localPlayer.publicId
  end)

  -- If this is effectively the local player's room, force local room actions only.
  if localIsMemberOfRoom or (localRoomNumber and localRoomNumber == room.roomNumber) then
    self:openLocalRoomSubMenu(room, button)
    return
  end

  if self:isLocalPlayerInRoom(lobbyDataV2) and localRoomNumber ~= room.roomNumber then
    -- Players already in a room cannot request other room slots.
    return
  end

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

  subMenu.roomNumber = room.roomNumber

  -- Add join button for each open slot
  if room.openSlots then
    local roomOwnerId = room.ownerId or (room.players and room.players[1])
    for _, slotNumber in ipairs(room.openSlots) do
      local slotLabel = getSlotLabel(room, slotNumber)
      local joinButton = ui.LobbyChallengeButton({
        playerId = roomOwnerId,
        iconSize = 16,
        roomNumber = room.roomNumber,
        slotNumber = slotNumber,
        gameModeId = room.gameModeId,
        label = ui.Label({text = loc("lb_join") .. " " .. slotLabel, translate = false}),
        acceptImage = GAME.theme:getFightImage(),
        proposeImage = GAME.theme:getCheckboxImage(false),
        withdrawImage = GAME.theme:getCheckboxImage(true),
        width = 120,
      })
      local localOutgoing = lobbyDataV2.outgoingChallenges[roomOwnerId]
      local localIncoming = lobbyDataV2.incomingChallenges[roomOwnerId]
      local inviteKey = "room_" .. room.roomNumber .. "_" .. slotNumber
      if localIncoming and localIncoming[inviteKey] then
        joinButton:setState(joinButton.challengeStates.CHALLENGED)
      elseif localOutgoing and localOutgoing[inviteKey] then
        joinButton:setState(joinButton.challengeStates.PROPOSING)
      end
      subMenu:addChild(joinButton)
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
  if #subMenu.children > 0 then
    subMenu:select(subMenu.children[1])
  end
  self.roomSubMenu = subMenu

  local subMenuLine = ui.Line({
    x = x + button.width + 8,
    y = y + button.height / 2,
    height = button.height,
    points = {x + button.width + 8, y + button.height / 2, subMenu.x - 8, y + button.height / 2}
  })
  self.roomSubMenuLine = subMenuLine

  self.lobbyMenu:setFocus(subMenu, function()
    self.roomSubMenu:detach()
    self.roomSubMenu = nil
    self.roomSubMenuLine:detach()
    self.roomSubMenuLine = nil
  end)

  self.uiRoot:addChild(subMenu)
  self.uiRoot:addChild(subMenuLine)
end

---@param room LobbyRoomV2
---@param button Button the button click that opens this submenu originated from
function Lobby:openLocalRoomSubMenu(room, button)
  if self.localRoomSubMenu then
    self.localRoomSubMenu:yieldFocus()
  end

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

  local leaveButton = ui.TextButton({
    label = ui.Label({text = "Leave team game", translate = false}),
    width = 120,
    onClick = function()
      self.teamCreateButton:onClick(button)
    end
  })
  subMenu:addChild(leaveButton)

  local backButton = ui.TextButton({
    label = ui.Label({text = "back"}),
    width = 120,
    onClick = function()
      GAME.theme:playCancelSfx()
      subMenu:yieldFocus()
    end})

  subMenu:addChild(backButton)
  subMenu:select(subMenu.children[1])
  self.localRoomSubMenu = subMenu

  local subMenuLine = ui.Line({
    x = x + button.width + 8,
    y = y + button.height / 2,
    height = button.height,
    points = {x + button.width + 8, y + button.height / 2, subMenu.x - 8, y + button.height / 2}
  })
  self.localRoomSubMenuLine = subMenuLine

  self.lobbyMenu:setFocus(subMenu, function()
    self.localRoomSubMenu:detach()
    self.localRoomSubMenu = nil
    self.localRoomSubMenuLine:detach()
    self.localRoomSubMenuLine = nil
  end)

  self.uiRoot:addChild(subMenu)
  self.uiRoot:addChild(subMenuLine)
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
  local localPlayerInfo = lobbyDataV2.players[GAME.localPlayer.publicId]
  local localInRoom = self:isLocalPlayerInRoom(lobbyDataV2)
  local myRoom
  if localPlayerInfo and localPlayerInfo.roomNumber then
    myRoom = lobbyDataV2.rooms[localPlayerInfo.roomNumber]
  elseif GAME.netClient.room and GAME.netClient.room.roomNumber then
    myRoom = lobbyDataV2.rooms[GAME.netClient.room.roomNumber]
  end
  local isLocalTeamLeader = myRoom and myRoom.players and myRoom.players[1] == GAME.localPlayer.publicId

  -- If the target player is in a room with open slots, offer quick join-slot buttons
  local playerInfo = lobbyDataV2.players[playerId]
  if (not localInRoom) and playerInfo and playerInfo.roomNumber then
    local targetRoom = lobbyDataV2.rooms[playerInfo.roomNumber]
    if targetRoom and targetRoom.openSlots then
      local roomOwnerId = targetRoom.ownerId or (targetRoom.players and targetRoom.players[1])
      for _, slotNumber in ipairs(targetRoom.openSlots) do
        local slotLabel = getSlotLabel(targetRoom, slotNumber)
        local quickJoin = ui.LobbyChallengeButton({
          playerId = roomOwnerId,
          roomNumber = targetRoom.roomNumber,
          slotNumber = slotNumber,
          gameModeId = targetRoom.gameModeId,
          iconSize = 16,
          label = ui.Label({text = loc("lb_join") .. " " .. slotLabel, translate = false}),
          acceptImage = GAME.theme:getFightImage(),
          proposeImage = GAME.theme:getCheckboxImage(false),
          withdrawImage = GAME.theme:getCheckboxImage(true),
          width = 120,
        })
        local localOutgoing = lobbyDataV2.outgoingChallenges[roomOwnerId]
        local localIncoming = lobbyDataV2.incomingChallenges[roomOwnerId]
        local inviteKey = "room_" .. targetRoom.roomNumber .. "_" .. slotNumber
        if localIncoming and localIncoming[inviteKey] then
          quickJoin:setState(quickJoin.challengeStates.CHALLENGED)
        elseif localOutgoing and localOutgoing[inviteKey] then
          quickJoin:setState(quickJoin.challengeStates.PROPOSING)
        end
        subMenu:addChild(quickJoin)
      end
    end
  end

  -- If LOCAL player leads a partial team room, offer invite buttons
  if isLocalTeamLeader then
    if myRoom and myRoom.openSlots and #myRoom.openSlots > 0 then
      for _, slotNumber in ipairs(myRoom.openSlots) do
        local slotLabel = getSlotLabel(myRoom, slotNumber)
        local inviteKey = "room_" .. myRoom.roomNumber .. "_" .. slotNumber
        local inviteBtn = ui.LobbyChallengeButton({
          roomNumber = myRoom.roomNumber,
          slotNumber = slotNumber,
          gameModeId = myRoom.gameModeId,
          playerId = playerId,
          iconSize = 16,
          label = ui.Label({text = "Invite " .. slotLabel, translate = false}),
          acceptImage = GAME.theme:getFightImage(),
          proposeImage = GAME.theme:getCheckboxImage(false),
          withdrawImage = GAME.theme:getCheckboxImage(true),
          width = 120,
        })
        -- Set initial state
        local outgoing = lobbyDataV2.outgoingChallenges[playerId]
        local incoming = lobbyDataV2.incomingChallenges[playerId]
        if incoming and incoming[inviteKey] then
          inviteBtn:setState(inviteBtn.challengeStates.CHALLENGED)
        elseif outgoing and outgoing[inviteKey] then
          inviteBtn:setState(inviteBtn.challengeStates.PROPOSING)
        end
        subMenu:addChild(inviteBtn)
      end
    end
  end

  -- If local player is already in a room, hide regular VS/Time Attack challenges
  if not localInRoom then
    local vsButton = ui.LobbyChallengeButton({
      gameModeId = GameModes.IDs.TWO_PLAYER_VS,
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
      gameModeId = GameModes.IDs.TWO_PLAYER_TIME_ATTACK,
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
  end

  local backButton = ui.TextButton({
    label = ui.Label({text = "back"}),
    width = 120,
    onClick = function()
      GAME.theme:playCancelSfx()
      subMenu:yieldFocus()
    end})

  subMenu:addChild(backButton)
  if #subMenu.children > 0 then
    subMenu:select(subMenu.children[1])
  end
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
  self:updateTeamCreateButtonState(lobbyDataV2)
  if self.teamCreateButton then
    self.lobbyMenu:addChild(self.teamCreateButton)
  end
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
            self.playerSubMenu:yieldFocus()
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
        self.lobbyMenu:select(self.teamCreateButton)
      elseif reverseOffset == 3 then
        self.lobbyMenu:select(self.onePlayerVsButton)
      elseif reverseOffset == 4 then
        self.lobbyMenu:select(self.onePlayerTimeAttackButton)
      elseif reverseOffset == 5 then
        self.lobbyMenu:select(self.onePlayerEndlessButton)
      else
        logger.warn("Unexpectedly couldn't find previous non-player/room selection, resetting to first interactable element")
        self.lobbyMenu:select(self.onePlayerEndlessButton)
      end
    end
  end

  if self.playerSubMenu then
    if not lobbyDataV2.players[self.playerSubMenu.playerId] or not found then
      self.playerSubMenu:yieldFocus()
    else
      for _, button in ipairs(self.playerSubMenu.children) do
        if button.TYPE == "LobbyRoomInviteButton" then
          ---@cast button LobbyRoomInviteButton
          local inviteKey = button.inviteKey
          local incoming = lobbyDataV2.incomingChallenges[button.playerId]
          local outgoing = lobbyDataV2.outgoingChallenges[button.playerId]
          if incoming and incoming[inviteKey] then
            button:setState(button.challengeStates.CHALLENGED)
          elseif outgoing and outgoing[inviteKey] then
            button:setState(button.challengeStates.PROPOSING)
          else
            button:setState(button.challengeStates.NEUTRAL)
          end
        elseif button.TYPE == "LobbyChallengeButton" and button.roomNumber then
          ---@cast button LobbyChallengeButton
          local inviteKey = "room_" .. button.roomNumber .. "_" .. (button.slotNumber or 0)
          local incoming = lobbyDataV2.incomingChallenges[button.playerId]
          local outgoing = lobbyDataV2.outgoingChallenges[button.playerId]
          if incoming and incoming[inviteKey] then
            button:setState(button.challengeStates.CHALLENGED)
          elseif outgoing and outgoing[inviteKey] then
            button:setState(button.challengeStates.PROPOSING)
          else
            button:setState(button.challengeStates.NEUTRAL)
          end
        elseif button.gameModeId then
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

  -- Handle room submenu: close if room is no longer joinable
  if self.roomSubMenu then
    local room = lobbyDataV2.rooms[self.roomSubMenu.roomNumber]
    local hasOpenSlots = room and room.openSlots and #room.openSlots > 0
    local localMember = room and room.players and tableUtils.trueForAny(room.players, function(playerId)
      return playerId == GAME.localPlayer.publicId
    end)

    if room and localMember then
      local originButton = self.roomSubMenu.originButton
      self.roomSubMenu:yieldFocus()
      if originButton then
        self:openLocalRoomSubMenu(room, originButton)
      end
    elseif not room or not hasOpenSlots then
      -- Room disappeared or is now full
      self.roomSubMenu:yieldFocus()
    else
      local roomOwnerId = room.ownerId or (room.players and room.players[1])
      for _, button in ipairs(self.roomSubMenu.children) do
        if button.TYPE == "LobbyRoomInviteButton" then
          local inviteKey = button.inviteKey
          local incoming = lobbyDataV2.incomingChallenges[button.playerId]
          local outgoing = lobbyDataV2.outgoingChallenges[button.playerId]
          if incoming and incoming[inviteKey] then
            button:setState(button.challengeStates.CHALLENGED)
          elseif outgoing and outgoing[inviteKey] then
            button:setState(button.challengeStates.PROPOSING)
          else
            button:setState(button.challengeStates.NEUTRAL)
          end
        elseif button.TYPE == "LobbyChallengeButton" and button.roomNumber then
          ---@cast button LobbyChallengeButton
          local inviteKey = "room_" .. button.roomNumber .. "_" .. (button.slotNumber or 0)
          local incoming = roomOwnerId and lobbyDataV2.incomingChallenges[roomOwnerId] or nil
          local outgoing = roomOwnerId and lobbyDataV2.outgoingChallenges[roomOwnerId] or nil
          if incoming and incoming[inviteKey] then
            button:setState(button.challengeStates.CHALLENGED)
          elseif outgoing and outgoing[inviteKey] then
            button:setState(button.challengeStates.PROPOSING)
          else
            button:setState(button.challengeStates.NEUTRAL)
          end
        end
      end
    end
  end

  if self.localRoomSubMenu then
    local localData = lobbyDataV2.players[GAME.localPlayer.publicId]
    local room = localData and localData.roomNumber and lobbyDataV2.rooms[localData.roomNumber]
    local isLocalRoom = room and room.players and tableUtils.trueForAny(room.players, function(playerId)
      return playerId == GAME.localPlayer.publicId
    end)
    if not isLocalRoom then
      self.localRoomSubMenu:yieldFocus()
    end
  end

  self:updateRoomPanel(true)
end

------------------------------
-- scene core functionality --
------------------------------
local loginStateLabel = ui.Label({text = loc("lb_login"), translate = false, x = 500, y = 350})
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
    self.lobbyMenu:receiveInputs(GAME.input)
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
      local hasOpenSlots = room.openSlots and #room.openSlots > 0
      local localPublicId = GAME.localPlayer.publicId

      -- Get game mode name
      local gameModeName = ""
      local ok, gm = pcall(GameModes.getPreset, room.gameModeId)
      if ok and gm then
        gameModeName = gm.name or ""
      end

      if hasOpenSlots then
        -- Room is waiting for players - show team slot info
        local lines = {}

        -- Header with game mode
        if gameModeName ~= "" then
          lines[#lines + 1] = gameModeName
        end

        -- Show players in their slots
        for i, playerId in ipairs(room.players) do
          local slotLabel = getSlotLabel(room, i)
          local playerInfo = GAME.netClient.lobbyDataV2.players[playerId]
          local playerName = playerInfo and playerInfo.name or "?"
          if playerId == localPublicId then
            lines[#lines + 1] = slotLabel .. ": " .. playerName .. " (You)"
          else
            lines[#lines + 1] = slotLabel .. ": " .. playerName
          end
        end

        -- Show waiting slots
        if #room.openSlots > 0 then
          local waitingSlots = {}
          for _, slotNumber in ipairs(room.openSlots) do
            waitingSlots[#waitingSlots + 1] = getSlotLabel(room, slotNumber)
          end
          lines[#lines + 1] = "Waiting: " .. table.concat(waitingSlots, ", ")
        end

        text = table.concat(lines, "\n")
      elseif #room.players >= 3 then
        -- Team room in progress (3-4 players)
        local lines = {}

        -- Header with game mode
        if gameModeName ~= "" then
          lines[#lines + 1] = gameModeName
        end

        -- Show all players with their slots
        for i, playerId in ipairs(room.players) do
          local slotLabel = getSlotLabel(room, i)
          local playerInfo = GAME.netClient.lobbyDataV2.players[playerId]
          local playerName = playerInfo and playerInfo.name or "?"
          lines[#lines + 1] = slotLabel .. ": " .. playerName
        end

        -- Show state and spectators
        lines[#lines + 1] = room.state
        lines[#lines + 1] = loc("pl_spectators") .. " " .. #room.spectators

        text = table.concat(lines, "\n")
      elseif #room.players == 2 then
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
