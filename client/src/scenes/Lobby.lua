local Scene = require("client.src.scenes.Scene")
local ui = require("client.src.ui")
local class = require("common.lib.class")
local logger = require("common.lib.logger")
local util = require("common.lib.util")
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
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

local function drawUnofficialHeader()
  local headerWidth = consts.CANVAS_WIDTH
  local y = 26

  GraphicsUtil.printf("Unofficial Team & FFA Mode", 0, y + 2, headerWidth, "center", {0.12, 0.06, 0.18, 0.85}, nil, 26)
  GraphicsUtil.printf("Unofficial Team & FFA Mode", 0, y, headerWidth, "center", {0.88, 0.72, 1, 1}, nil, 26)
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

  -- Latency tolerance menu — final step for all 3+P games
  local function openLatencyMenu(parentMenu, parentButton, gameMode, closeAll)
    if self.latencyMenu then
      self.latencyMenu:yieldFocus()
      return
    end

    local bx, by = parentButton:getScreenPos()
    local latMenu = ui.ScrollMenu({
      x = bx + parentButton.width + 3,
      y = by,
      hAlign = "left",
      vAlign = "top",
      height = 160,
      width = 220,
      padding = 0,
      childGap = 8,
    })

    local function latButton(text, tolerance, description)
      local btn = ui.TextButton({
        label = ui.Label({text = text, translate = false}),
        width = 220,
        onClick = function()
          GAME.netClient:requestRoom(gameMode, tolerance)
          latMenu:yieldFocus()
          if closeAll then closeAll() end
        end,
      })
      local origSetSelected = btn.setSelected
      btn.setSelected = function(b, selected)
        origSetSelected(b, selected)
        self.garbageTooltip = selected and description or ""
      end
      return btn
    end

    latMenu:addChild(latButton("Strict",  "strict",  "Strict: 30s disconnect timeout, 140-frame input gap (~2s) before abort."))
    latMenu:addChild(latButton("Normal",  "normal",  "Normal: 60s disconnect timeout, 220-frame input gap (~3.5s) before abort."))
    latMenu:addChild(latButton("Relaxed", "relaxed", "Relaxed: 120s disconnect timeout, 320-frame input gap (~5s) before abort."))
    latMenu:select(latMenu.children[2])

    self.latencyMenu = latMenu
    parentMenu:setFocus(latMenu, function()
      self.garbageTooltip = ""
      parentMenu:select(parentButton)
      self.latencyMenu:detach()
      self.latencyMenu = nil
    end)
    self.uiRoot:addChild(latMenu)
  end

  -- Garbage mode menu (team only)
  local function openGarbageMenu(compositionButton, options)
    if self.teamGarbageMenu then
      self.teamGarbageMenu:yieldFocus()
    end

    local bx, by = compositionButton:getScreenPos()
    local garbageMenu = ui.ScrollMenu({
      x = bx + compositionButton.width + 3,
      y = by,
      hAlign = "left",
      vAlign = "top",
      height = 160,
      width = 260,
      padding = 0,
      childGap = 8,
    })

    local function garbageButton(text, description, onClick)
      local btn = ui.TextButton({
        label = ui.Label({text = text, translate = false}),
        width = 260,
        onClick = onClick,
      })
      local origSetSelected = btn.setSelected
      btn.setSelected = function(b, selected)
        origSetSelected(b, selected)
        self.garbageTooltip = selected and description or ""
      end
      return btn
    end

    local function closeTeamMenuChain()
      if self.teamGarbageMenu then self.teamGarbageMenu:yieldFocus() end
      if self.teamCompositionMenu then self.teamCompositionMenu:yieldFocus() end
      if self.teamPlayerCountMenu then self.teamPlayerCountMenu:yieldFocus() end
    end

    garbageMenu:addChild(garbageButton(
      "Garbage hits all opponents",
      "Each attack hits every enemy player individually — great for aggressive solo play.",
      function(b)
        openLatencyMenu(garbageMenu, b, GameModes.getPreset(options.allMode), closeTeamMenuChain)
      end
    ))
    garbageMenu:addChild(garbageButton(
      "Garbage shared by enemy team",
      "Attacks are pooled and split evenly across the enemy team — rewards coordinated team play.",
      function(b)
        openLatencyMenu(garbageMenu, b, GameModes.getPreset(options.sharedMode), closeTeamMenuChain)
      end
    ))
    garbageMenu:select(garbageMenu.children[1])

    self.teamGarbageMenu = garbageMenu
    self.teamCompositionMenu:setFocus(garbageMenu, function()
      self.garbageTooltip = ""
      self.teamCompositionMenu:select(compositionButton)
      self.teamGarbageMenu:detach()
      self.teamGarbageMenu = nil
    end)
    self.uiRoot:addChild(garbageMenu)
  end

  -- Divisions available per player count. Each entry feeds openGarbageMenu.
  local TEAM_DIVISIONS = {
    [3] = {
      { label = "1 vs 2", allMode = GameModes.IDs.THREE_PLAYER_VS_ALL,     sharedMode = GameModes.IDs.THREE_PLAYER_VS_SHARED },
      { label = "2 vs 1", allMode = GameModes.IDs.THREE_PLAYER_VS_ALL_2V1, sharedMode = GameModes.IDs.THREE_PLAYER_VS_SHARED_2V1 },
    },
    [4] = {
      { label = "2 vs 2", allMode = GameModes.IDs.FOUR_PLAYER_TEAM_VS_ALL, sharedMode = GameModes.IDs.FOUR_PLAYER_TEAM_VS_SHARED },
    },
    [5] = {
      { label = "1 vs 4", allMode = GameModes.IDs.FIVE_PLAYER_1V4_ALL, sharedMode = GameModes.IDs.FIVE_PLAYER_1V4_SHARED },
      { label = "4 vs 1", allMode = GameModes.IDs.FIVE_PLAYER_4V1_ALL, sharedMode = GameModes.IDs.FIVE_PLAYER_4V1_SHARED },
      { label = "2 vs 3", allMode = GameModes.IDs.FIVE_PLAYER_2V3_ALL, sharedMode = GameModes.IDs.FIVE_PLAYER_2V3_SHARED },
      { label = "3 vs 2", allMode = GameModes.IDs.FIVE_PLAYER_3V2_ALL, sharedMode = GameModes.IDs.FIVE_PLAYER_3V2_SHARED },
    },
  }

  -- Level 2: division menu (e.g. "1 vs 2", "2 vs 1") for a chosen player count.
  local function openCompositionForCount(parentButton, playerCount)
    if self.teamCompositionMenu then
      self.teamCompositionMenu:yieldFocus()
    end

    local bx, by = parentButton:getScreenPos()
    local divisions = TEAM_DIVISIONS[playerCount] or {}
    local rowHeight = 32  -- TextButton default + childGap budget
    local compositionMenu = ui.ScrollMenu({
      x = bx + parentButton.width + 3,
      y = by,
      hAlign = "left",
      vAlign = "top",
      height = math.max(160, #divisions * (rowHeight + 8) + 8),
      width = 180,
      padding = 0,
      childGap = 8,
    })

    for _, div in ipairs(divisions) do
      compositionMenu:addChild(ui.TextButton({
        label = ui.Label({text = div.label, translate = false}),
        width = 180,
        onClick = function(b)
          openGarbageMenu(b, { allMode = div.allMode, sharedMode = div.sharedMode })
        end
      }))
    end
    if compositionMenu.children[1] then
      compositionMenu:select(compositionMenu.children[1])
    end

    self.teamCompositionMenu = compositionMenu
    self.teamPlayerCountMenu:setFocus(compositionMenu, function()
      if self.latencyMenu then
        self.latencyMenu:detach()
        self.latencyMenu = nil
      end
      if self.teamGarbageMenu then
        self.teamGarbageMenu:detach()
        self.teamGarbageMenu = nil
      end
      self.teamPlayerCountMenu:select(parentButton)
      self.teamCompositionMenu:detach()
      self.teamCompositionMenu = nil
    end)
    self.uiRoot:addChild(compositionMenu)
  end

  -- Level 1: player count menu (3 / 4 / 5).
  local function openTeamCompositionMenu(parentButton)
    if self.teamPlayerCountMenu then
      self.teamPlayerCountMenu:yieldFocus()
    end

    local bx, by = parentButton:getScreenPos()
    local playerCountMenu = ui.ScrollMenu({
      x = bx + parentButton.width + 3,
      y = by,
      hAlign = "left",
      vAlign = "top",
      height = 160,
      width = 180,
      padding = 0,
      childGap = 8,
    })

    for _, n in ipairs({3, 4, 5}) do
      playerCountMenu:addChild(ui.TextButton({
        label = ui.Label({text = n .. " Players", translate = false}),
        width = 180,
        onClick = function(b) openCompositionForCount(b, n) end,
      }))
    end
    playerCountMenu:select(playerCountMenu.children[1])

    self.teamPlayerCountMenu = playerCountMenu
    self.lobbyMenu:setFocus(playerCountMenu, function()
      if self.latencyMenu then
        self.latencyMenu:detach()
        self.latencyMenu = nil
      end
      if self.teamGarbageMenu then
        self.teamGarbageMenu:detach()
        self.teamGarbageMenu = nil
      end
      if self.teamCompositionMenu then
        self.teamCompositionMenu:detach()
        self.teamCompositionMenu = nil
      end
      self.teamPlayerCountMenu:detach()
      self.teamPlayerCountMenu = nil
    end)
    self.uiRoot:addChild(playerCountMenu)
  end

  -- FFA player count menu
  local function openFfaMenu(parentButton)
    if self.ffaPlayerCountMenu then
      self.ffaPlayerCountMenu:yieldFocus()
    end

    local bx, by = parentButton:getScreenPos()
    local ffaMenu = ui.ScrollMenu({
      x = bx + parentButton.width + 3,
      y = by,
      hAlign = "left",
      vAlign = "top",
      height = 160,
      width = 180,
      padding = 0,
      childGap = 8,
    })

    ffaMenu:addChild(ui.TextButton({
      label = ui.Label({text = "3 Players (1v1v1)", translate = false}),
      width = 180,
      onClick = function(b)
        openLatencyMenu(ffaMenu, b, GameModes.getPreset(GameModes.IDs.THREE_PLAYER_FFA), function()
          if self.ffaPlayerCountMenu then self.ffaPlayerCountMenu:yieldFocus() end
        end)
      end
    }))
    ffaMenu:addChild(ui.TextButton({
      label = ui.Label({text = "4 Players (1v1v1v1)", translate = false}),
      width = 180,
      onClick = function(b)
        openLatencyMenu(ffaMenu, b, GameModes.getPreset(GameModes.IDs.FOUR_PLAYER_FFA), function()
          if self.ffaPlayerCountMenu then self.ffaPlayerCountMenu:yieldFocus() end
        end)
      end
    }))
    ffaMenu:addChild(ui.TextButton({
      label = ui.Label({text = "5 Players (1v1v1v1v1)", translate = false}),
      width = 180,
      onClick = function(b)
        openLatencyMenu(ffaMenu, b, GameModes.getPreset(GameModes.IDs.FIVE_PLAYER_FFA), function()
          if self.ffaPlayerCountMenu then self.ffaPlayerCountMenu:yieldFocus() end
        end)
      end
    }))
    ffaMenu:select(ffaMenu.children[1])

    self.ffaPlayerCountMenu = ffaMenu
    self.lobbyMenu:setFocus(ffaMenu, function()
      if self.latencyMenu then
        self.latencyMenu:detach()
        self.latencyMenu = nil
      end
      self.ffaPlayerCountMenu:detach()
      self.ffaPlayerCountMenu = nil
    end)
    self.uiRoot:addChild(ffaMenu)
  end

  self.teamCreateButtonLabel = ui.Label({text = "Create Team Game", translate = false})
  self.teamCreateButton = ui.TextButton({
    label = self.teamCreateButtonLabel,
    width = self.lobbyMenuWidth,
    onClick = function(button)
      if self:isLocalPlayerInRoom() then
        GAME.netClient:leaveRoom()
        return
      end
      if self.teamCompositionMenu then
        self.teamCompositionMenu:yieldFocus()
        return
      end
      openTeamCompositionMenu(button)
    end
  })

  self.ffaCreateButton = ui.TextButton({
    label = ui.Label({text = "Create FFA", translate = false}),
    width = self.lobbyMenuWidth,
    onClick = function(button)
      if self:isLocalPlayerInRoom() then
        GAME.netClient:leaveRoom()
        return
      end
      if self.ffaPlayerCountMenu then
        self.ffaPlayerCountMenu:yieldFocus()
        return
      end
      openFfaMenu(button)
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
    self.teamCreateButtonLabel:setText("Leave game", nil, false)
  else
    self.teamCreateButtonLabel:setText("Create Team Game", nil, false)
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
local function getTeamLetter(teamIndex)
  if type(teamIndex) ~= "number" or teamIndex < 1 then
    return "T?"
  end

  -- A-Z for the first 26 teams, then T27, T28, ... as fallback.
  if teamIndex <= 26 then
    return string.char(string.byte("A") + teamIndex - 1)
  end

  return "T" .. tostring(teamIndex)
end

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
    local teamLetter = getTeamLetter(teamIndex)
    return teamLetter .. tostring(within)
  elseif type(playersPerTeam) == "table" then
    local cumulative = 0
    for idx, count in ipairs(playersPerTeam) do
      if slotNumber <= cumulative + count then
        local within = slotNumber - cumulative
        local teamLetter = getTeamLetter(idx)
        return teamLetter .. tostring(within)
      end
      cumulative = cumulative + count
    end
  end

  return "Slot " .. tostring(slotNumber)
end

local function getTeamIndexForSlot(room, slotNumber)
  if not room or not room.gameModeId then
    return nil
  end

  local ok, gm = pcall(GameModes.getPreset, room.gameModeId)
  if not ok or not gm then
    return nil
  end

  local playersPerTeam = gm.playersPerTeam
  if type(playersPerTeam) == "number" then
    local n = playersPerTeam
    return math.floor((slotNumber - 1) / n) + 1
  elseif type(playersPerTeam) == "table" then
    local cumulative = 0
    for idx, count in ipairs(playersPerTeam) do
      if slotNumber <= cumulative + count then
        return idx
      end
      cumulative = cumulative + count
    end
  end

  return nil
end

-- ASCII team tags so we never depend on font glyphs. Each team gets its own
-- letter; position-within-team is appended (e.g. [A1], [A2] for 2v2; [A1] [B1]
-- [C1] [D1] for 4-player FFA where every team has size 1).
local function teamLetter(teamIndex)
  -- A, B, C, D, ... E, F, ...  (covers any reasonable team count)
  return string.char(string.byte("A") + (teamIndex - 1))
end

local function teamFilledShape(teamIndex)
  if not teamIndex then return "[?]" end
  return "[" .. teamLetter(teamIndex) .. "1]"
end

local function teamSlotShape(teamIndex, positionWithinTeam)
  if not teamIndex then return "[?]" end
  return "[" .. teamLetter(teamIndex) .. tostring(positionWithinTeam or 1) .. "]"
end

-- (teamIndex, positionWithinTeam) for a given absolute slot number.
local function getTeamSlotInfo(room, slotNumber)
  if not room or not room.gameModeId then return nil, nil end
  local ok, gm = pcall(GameModes.getPreset, room.gameModeId)
  if not ok or not gm then return nil, nil end

  local p = gm.playersPerTeam
  if type(p) == "number" then
    local teamIndex = math.floor((slotNumber - 1) / p) + 1
    local pos = ((slotNumber - 1) % p) + 1
    return teamIndex, pos
  elseif type(p) == "table" then
    local cumulative = 0
    for idx, count in ipairs(p) do
      if slotNumber <= cumulative + count then
        return idx, slotNumber - cumulative
      end
      cumulative = cumulative + count
    end
  end
  return nil, nil
end

-- Filled-row prefix: ♥ / ♡ / ★ / ☆ depending on team + slot position.
local function teamFilledPrefix(room, slotNumber)
  local teamIndex, pos = getTeamSlotInfo(room, slotNumber)
  if not teamIndex then return "" end
  return teamSlotShape(teamIndex, pos)
end

-- Empty/waiting prefix: keeps the per-position shape so an empty A2 still
-- reads "A2" (not "A1") — necessary in shared-team 2v2 where teammates
-- otherwise look identical.
local function teamEmptyPrefix(room, slotNumber)
  local teamIndex, pos = getTeamSlotInfo(room, slotNumber)
  if not teamIndex then return "[?]" end
  return teamSlotShape(teamIndex, pos)
end

-- RGBA for the per-team background tint behind a row. Covers up to 8 teams
-- so FFA (3p/4p) gets distinct colors per slot, not just pink/purple.
-- Alpha pushed up + slight saturation so the stripes assert against a darker
-- button background (orange + pink shared R/G channels — they couldn't visually
-- separate at lower alpha).
local TEAM_ROW_TINT = {
  [1] = {1,    0.45, 0.7,  0.92},  -- pink
  [2] = {0.55, 0.3,  0.95, 0.92},  -- purple
  [3] = {0.35, 0.85, 0.4,  0.92},  -- green
  [4] = {0.95, 0.85, 0.3,  0.92},  -- yellow
  [5] = {1,    0.55, 0.15, 0.92},  -- orange
  [6] = {0.3,  0.6,  1,    0.92},  -- blue
  [7] = {0.35, 0.95, 0.95, 0.92},  -- cyan
  [8] = {1,    0.35, 0.35, 0.92},  -- red
}

local function teamRowTint(teamIndex)
  return TEAM_ROW_TINT[teamIndex] or TEAM_ROW_TINT[1]
end

-- Dark navy button background — neutral so any team color reads cleanly on top.
-- (Tried orange — pink/orange share R/G channels, so pink barely registered.)
local TEAM_ROOM_BUTTON_BG = {0.12, 0.15, 0.24, 0.95}
-- Gold background for rooms where the local player has been invited — makes
-- the inbox-worthy room obvious in the lobby list.
local TEAM_ROOM_BUTTON_BG_INVITED = {0.55, 0.45, 0.1, 0.95}
-- Solid-color accent down the left edge of each tinted row, full alpha. Doubles
-- the readability win on top of the row fill.
local TEAM_ROW_ACCENT_W = 6


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
  local playerButtons = {}

  for publicId, player in pairs(personalizedLobbyData.players) do
    local isLocalPlayer = (publicId == GAME.localPlayer.publicId)
    local hasRoom = (player.roomNumber ~= nil) or isPlayerInAnyRoom(personalizedLobbyData, publicId)
    local hasIncoming = personalizedLobbyData.incomingChallenges[publicId] and challengeActive(personalizedLobbyData.incomingChallenges[publicId])
    local hasOutgoing = personalizedLobbyData.outgoingChallenges[publicId] and challengeActive(personalizedLobbyData.outgoingChallenges[publicId])

    -- Players in rooms are not shown in the lobby player list.
    if not isLocalPlayer and not hasRoom then
      local playerName
      if hasIncoming then
        playerName = Lobby.getPlayerNameWithRating(publicId) .. " " .. loc("lb_received")
      elseif hasOutgoing then
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

    local hasOpenSlots = room.openSlots and #room.openSlots > 0

    -- Detect an incoming invite to this room (someone in the room has invited
    -- the local player to one of its open slots). When present, the button
    -- gets a highlighted header line so it stands out from every other room.
    local roomOwnerId = room.ownerId or (room.players and room.players[1])
    local invitedSlot = nil
    if not isLocalPlayerRoom and roomOwnerId
        and personalizedLobbyData.incomingChallenges[roomOwnerId]
        and room.openSlots then
      for _, slotNumber in ipairs(room.openSlots) do
        if personalizedLobbyData.incomingChallenges[roomOwnerId]["room_" .. room.roomNumber .. "_" .. slotNumber] then
          invitedSlot = slotNumber
          break
        end
      end
    end

    -- One render path for every room. Each row builds its tint alongside its
    -- text so the drawSelf override below can paint per-row team stripes.
    local rowTints = {}
    local lines = {}

    -- Top "INVITED" marker (matched by a bottom one below) when this room has
    -- an open invite for the local player.
    if invitedSlot then
      lines[#lines + 1] = "INVITED"
      rowTints[#rowTints + 1] = false
    end

    -- Title:  "Name1, Name2's Room   [n/m]"  (or "Empty Room" if vacant)
    local slotsText = string.format("[%d/%d]", #room.players, room.maxPlayers or 2)
    local presentNames = {}
    for _, playerId in ipairs(room.players) do
      local info = personalizedLobbyData.players[playerId]
      presentNames[#presentNames + 1] = (info and info.name) or "?"
    end
    local roomTitle
    if #presentNames == 0 then
      roomTitle = "Empty Room"
    elseif #presentNames == 1 then
      roomTitle = presentNames[1] .. "'s Room"
    else
      roomTitle = table.concat(presentNames, ", ") .. "'s Room"
    end
    lines[#lines + 1] = roomTitle .. "  " .. slotsText
    rowTints[#rowTints + 1] = false

    -- Garbage subtitle (only renders something in shared team modes).
    local TeamBannerHeader = require("client.src.graphics.TeamBannerHeader")
    local okGM, gmPreset = pcall(GameModes.getPreset, room.gameModeId)
    local garbageLabel = okGM and gmPreset and TeamBannerHeader.garbageModeLabel(gmPreset) or nil
    if garbageLabel then
      lines[#lines + 1] = garbageLabel
      rowTints[#rowTints + 1] = false
    end

    -- Player rows
    for i, playerId in ipairs(room.players) do
      local prefix = teamFilledPrefix(room, i)
      local name = (personalizedLobbyData.players[playerId] and personalizedLobbyData.players[playerId].name) or "?"
      local suffix = (playerId == localPublicId) and " (You)" or ""
      lines[#lines + 1] = prefix .. " " .. name .. suffix
      local tIdx = (getTeamSlotInfo(room, i))
      rowTints[#rowTints + 1] = tIdx and teamRowTint(tIdx) or false
    end

    -- Open-slot rows
    if hasOpenSlots then
      for _, slotNumber in ipairs(room.openSlots) do
        local prefix = teamEmptyPrefix(room, slotNumber)
        local line
        if room.slotRequests and room.slotRequests[slotNumber] then
          local requester = personalizedLobbyData.players[room.slotRequests[slotNumber]]
          local requesterName = (requester and requester.name) or "someone"
          line = prefix .. " <- " .. requesterName .. " wants in"
        else
          line = prefix .. " (waiting...)"
        end
        lines[#lines + 1] = line
        local tIdx = (getTeamSlotInfo(room, slotNumber))
        rowTints[#rowTints + 1] = tIdx and teamRowTint(tIdx) or false
      end
    else
      lines[#lines + 1] = "(" .. room.state .. ")"
      rowTints[#rowTints + 1] = false
    end

    -- Bottom "INVITED" marker, mirroring the top one.
    if invitedSlot then
      lines[#lines + 1] = "INVITED"
      rowTints[#rowTints + 1] = false
    end

    local roomName = table.concat(lines, "\n")

    -- Click behavior depends on relationship to the room.
    local onClick
    if isLocalPlayerRoom then
      onClick = function(button)
        self:openLocalRoomSubMenu(room, button)
        GAME.theme:playValidationSfx()
      end
    elseif invitedSlot or hasOpenSlots then
      onClick = function(button)
        self:openRoomSubMenu(room, button)
        GAME.theme:playValidationSfx()
      end
    else
      onClick = self:requestSpectateFunction(room)
    end

    local label = ui.Label({text = roomName, translate = false, wrapWidth = self.lobbyMenuWidth - 16})
    local button = ui.TextButton({
      label = label,
      width = self.lobbyMenuWidth,
      onClick = onClick,
    })
    button.lobbyType = "room"
    button.room = room
    button.isLocalPlayerRoom = isLocalPlayerRoom

    -- Every room renders with the same panel: dark navy background, team-color
    -- stripes per row, label on top. Invited rooms swap the background to a
    -- gold glow so they stand out at a glance.
    button._rowTints = rowTints
    button._invited = invitedSlot ~= nil
    button.drawSelf = function(self)
      local bg = self._invited and TEAM_ROOM_BUTTON_BG_INVITED or TEAM_ROOM_BUTTON_BG
      GraphicsUtil.drawRectangle("fill", self.x, self.y, self.width, self.height,
        bg[1], bg[2], bg[3], bg[4],
        self.CORNER_RADIUS, self.CORNER_RADIUS)
      self:drawOutline()

      local stripeX = self.x + 6
      local stripeW = self.width - 12
      local rowCount = #self._rowTints
      local lineHeight
      if rowCount > 0 and self.label.height and self.label.height > 0 then
        lineHeight = self.label.height / rowCount
      else
        lineHeight = self.label.drawable:getFont():getHeight()
      end
      local labelTopY = self.y + (self.height - self.label.height) / 2
      for i, tint in ipairs(self._rowTints) do
        if tint then
          local stripeY = labelTopY + (i - 1) * lineHeight
          GraphicsUtil.drawRectangle("fill", stripeX, stripeY, stripeW, lineHeight,
                                     tint[1], tint[2], tint[3], tint[4])
          GraphicsUtil.drawRectangle("fill", stripeX, stripeY, TEAM_ROW_ACCENT_W, lineHeight,
                                     tint[1], tint[2], tint[3], 1)
        end
      end
      GraphicsUtil.setColor(1, 1, 1, 1)
    end

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
    x = x + self.lobbyMenu.width + 3,
    y = y,
    hAlign = "left",
    vAlign = "top",
    height = 300,
    width = 120,
    padding = 0,
    childGap = 8,
  })

  subMenu.roomNumber = room.roomNumber

  -- Add join button for each open slot
  if room.openSlots then
    local roomOwnerId = room.ownerId or (room.players and room.players[1])
    for _, slotNumber in ipairs(room.openSlots) do
      -- "Join 🩷" / "Join 🟣" — color = team you'd be filling.
      local joinLbl = loc("lb_join") .. " " .. teamEmptyPrefix(room, slotNumber)
      local joinButton = ui.LobbyChallengeButton({
        playerId = roomOwnerId,
        iconSize = 16,
        roomNumber = room.roomNumber,
        slotNumber = slotNumber,
        gameModeId = room.gameModeId,
        label = ui.Label({text = joinLbl, translate = false}),
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
    x = x + button.width + 3,
    y = y + button.height / 2,
    height = button.height,
    points = {x + button.width + 3, y + button.height / 2, subMenu.x - 3, y + button.height / 2}
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
    x = x + self.lobbyMenu.width + 3,
    y = y,
    hAlign = "left",
    vAlign = "top",
    height = 300,
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
    x = x + button.width + 3,
    y = y + button.height / 2,
    height = button.height,
    points = {x + button.width + 3, y + button.height / 2, subMenu.x - 3, y + button.height / 2}
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
    x = x + self.lobbyMenu.width + 3,
    y = y,
    hAlign = "left",
    vAlign = "top",
    height = 300,
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
        -- "Join 🟣" — show the team color of the seat you'd fill.
        local quickJoinLabel = loc("lb_join") .. " " .. teamEmptyPrefix(targetRoom, slotNumber)
        local quickJoin = ui.LobbyChallengeButton({
          playerId = roomOwnerId,
          roomNumber = targetRoom.roomNumber,
          slotNumber = slotNumber,
          gameModeId = targetRoom.gameModeId,
          iconSize = 16,
          label = ui.Label({text = quickJoinLabel, translate = false}),
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
      local outgoing = lobbyDataV2.outgoingChallenges[playerId]
      local incoming = lobbyDataV2.incomingChallenges[playerId]

      for _, slotNumber in ipairs(myRoom.openSlots) do
        -- "Invite to 🩷" / "Invite to 🟣" — show which team's seat would be filled.
        local inviteLabel = "Invite to " .. teamEmptyPrefix(myRoom, slotNumber)
        local inviteKey = "room_" .. myRoom.roomNumber .. "_" .. slotNumber
        local inviteBtn = ui.LobbyChallengeButton({
          roomNumber = myRoom.roomNumber,
          slotNumber = slotNumber,
          gameModeId = myRoom.gameModeId,
          playerId = playerId,
          iconSize = 16,
          label = ui.Label({text = inviteLabel, translate = false}),
          acceptImage = GAME.theme:getFightImage(),
          proposeImage = GAME.theme:getCheckboxImage(false),
          withdrawImage = GAME.theme:getCheckboxImage(true),
          width = 120,
        })
        -- Set initial state
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
    x = x + button.width + 3,
    y = y + button.height / 2,
    height = button.height,
    points = {x + button.width + 3, y + button.height / 2, subMenu.x - 3, y + button.height / 2}
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

  self:updateTeamCreateButtonState(lobbyDataV2)
  if self.teamCreateButton then
    self.lobbyMenu:addChild(self.teamCreateButton)
  end
  if self.ffaCreateButton then
    self.lobbyMenu:addChild(self.ffaCreateButton)
  end
  self.lobbyMenu:addChild(self.onePlayerEndlessButton)
  self.lobbyMenu:addChild(self.onePlayerTimeAttackButton)
  self.lobbyMenu:addChild(self.onePlayerVsButton)
  self.lobbyMenu:addChild(self.showLeaderboardButton)
  self.lobbyMenu:addChild(self.backButton)

  local previousButton
  local found = false

  if self.lobbyMenuStartingUp then
    for _, child in ipairs(self.lobbyMenu.children) do
      if child.onClick then
        self.lobbyMenu:select(child)
        break
      end
    end
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
        self.lobbyMenu:select(self.ffaCreateButton)
      elseif reverseOffset == 3 then
        self.lobbyMenu:select(self.teamCreateButton)
      elseif reverseOffset == 4 then
        self.lobbyMenu:select(self.onePlayerVsButton)
      elseif reverseOffset == 5 then
        self.lobbyMenu:select(self.onePlayerTimeAttackButton)
      elseif reverseOffset == 6 then
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
      local localPlayerInfo = lobbyDataV2.players[GAME.localPlayer.publicId]
      local myRoom = localPlayerInfo and localPlayerInfo.roomNumber and lobbyDataV2.rooms[localPlayerInfo.roomNumber]
      local openSlotSet = {}
      if myRoom and myRoom.openSlots then
        for _, s in ipairs(myRoom.openSlots) do openSlotSet[s] = true end
      end

      local toDetach = {}
      for _, button in ipairs(self.playerSubMenu.children) do
        if button.TYPE == "LobbyRoomInviteButton" then
          ---@cast button LobbyRoomInviteButton
          if not openSlotSet[button.slotNumber] then
            toDetach[#toDetach + 1] = button
          else
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

      for _, button in ipairs(toDetach) do
        button:detach()
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
          local prefix = teamFilledPrefix(room, i)
          local playerInfo = GAME.netClient.lobbyDataV2.players[playerId]
          local playerName = playerInfo and playerInfo.name or "?"
          local suffix = (playerId == localPublicId) and " (You)" or ""
          lines[#lines + 1] = prefix .. " " .. playerName .. suffix
        end

        -- Show waiting slots:  🩷 (waiting...)  /  🟣 (waiting...)
        if #room.openSlots > 0 then
          for _, slotNumber in ipairs(room.openSlots) do
            lines[#lines + 1] = teamEmptyPrefix(room, slotNumber) .. " (waiting...)"
          end
        end

        text = table.concat(lines, "\n")
      elseif #room.players >= 3 then
        -- Team room in progress (3-5 players, team or FFA).
        local lines = {}

        if gameModeName ~= "" then
          lines[#lines + 1] = gameModeName
        end

        -- Bucket players by team and emit one "[X] name1, name2" row per team.
        -- Works for shared-team (1v2/2v2/1v4/2v3) and FFA (1-per-team) alike.
        local teamBuckets = {}
        local maxTeamIndex = 0
        for i, playerId in ipairs(room.players) do
          local playerInfo = GAME.netClient.lobbyDataV2.players[playerId]
          local playerName = playerInfo and playerInfo.name or "?"
          local teamIndex = getTeamIndexForSlot(room, i)
          if teamIndex then
            teamBuckets[teamIndex] = teamBuckets[teamIndex] or {}
            teamBuckets[teamIndex][#teamBuckets[teamIndex] + 1] = playerName
            if teamIndex > maxTeamIndex then maxTeamIndex = teamIndex end
          else
            lines[#lines + 1] = teamFilledPrefix(room, i) .. " " .. playerName
          end
        end
        for i = 1, maxTeamIndex do
          local names = teamBuckets[i]
          if names and #names > 0 then
            local letter = string.char(string.byte("A") + (i - 1))
            lines[#lines + 1] = "[" .. letter .. "] " .. table.concat(names, ", ")
          end
        end

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
  drawUnofficialHeader()
  self:drawCommunityMessage()
  if GAME.netClient.state == NetClient.STATES.LOGIN then
    loginStateLabel:draw()
  else
    self.uiRoot:draw()
  end
  if self.garbageTooltip and self.garbageTooltip ~= "" then
    local pad = 12
    local fontSize = GraphicsUtil.fontSize
    local bh = fontSize + pad * 2
    local by = consts.CANVAS_HEIGHT - bh - 8
    love.graphics.setColor(0.10, 0.04, 0.20, 0.88)
    love.graphics.rectangle("fill", 0, by, consts.CANVAS_WIDTH, bh)
    love.graphics.setColor(1, 1, 1, 1)
    GraphicsUtil.printf(self.garbageTooltip, 0, by + pad, consts.CANVAS_WIDTH, "center")
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
