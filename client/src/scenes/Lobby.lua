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
  -- Wider than legacy 140 so consolidated invite labels ("Join Pink Team",
  -- "Invite to Purple Team") and 1-2 player room titles fit on one line.
  -- Single-line guarantee matters here: room-card color stripes are indexed by
  -- logical line, so any wrap visually drifts the team tint off its row.
  self.lobbyMenuWidth = 220
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

  -- Latency tolerance menu — final step for all 3+P games. `openRoom` is the
  -- last bit of intent we still carry: it controls whether the resulting room
  -- accepts direct joiners (open) or requires an invite handshake (invite-only).
  -- It's independent of min/max — Open Team rooms have fixed rosters but still
  -- accept drop-in joins.
  local function openLatencyMenu(parentMenu, parentButton, gameModeOrId, closeAll, openRoom)
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
      width = 160,
      padding = 0,
      childGap = 8,
    })

    local function latButton(text, tolerance, description)
      local btn = ui.TextButton({
        label = ui.Label({text = text, translate = false}),
        onClick = function()
          local gameMode = nil
          local gameModeId = nil
          if type(gameModeOrId) == "string" then
            gameModeId = gameModeOrId
            local ok, resolved = pcall(GameModes.getPreset, gameModeId)
            if ok then
              gameMode = resolved
            end
          elseif type(gameModeOrId) == "table" and type(gameModeOrId.getGameModeJSONData) == "function" then
            gameMode = gameModeOrId
            gameModeId = gameMode.gameModeId or gameMode.id or GameModes.nameToGameModeId[gameMode.name]
          end

          if gameMode then
            logger.warn("latButton onClick: tolerance=" .. tostring(tolerance) .. " gameModeId=" .. tostring(gameModeId) .. " gameMode=" .. tostring(gameMode.name) .. " openRoom=" .. tostring(openRoom == true))
            GAME.netClient:requestRoom(gameMode, tolerance, openRoom == true)
          else
            logger.error("latButton failed to resolve game mode payload")
          end
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

    latMenu:addChild(latButton("Strict",  "strict",
      "Strict: tight timing. 100ms simultaneous-KO window, 500ms reaction floor on incoming garbage, 20-30s before a silent connection is declared dead. Best on stable connections (LAN, same-region fiber)."))
    latMenu:addChild(latButton("Normal",  "normal",
      "Normal: balanced. 200ms simultaneous-KO window, 750ms reaction floor on incoming garbage, 45-60s before a silent connection is declared dead. Sensible default for most matches."))
    latMenu:addChild(latButton("Relaxed", "relaxed",
      "Relaxed: forgiving. 400ms simultaneous-KO window, 1s reaction floor on incoming garbage, 90-120s before a silent connection is declared dead. Best for international or unstable connections."))
    latMenu:addChild(ui.TextButton({
      label = ui.Label({text = "back"}),
      onClick = function()
        GAME.theme:playCancelSfx()
        latMenu:yieldFocus()
      end,
    }))
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

  ---Resolve a game mode and apply lobby-selected roster behavior.
  ---Open: min=2, max=count. Invite-only: min=max=count.
  ---@param gameModeOrId GameMode|GameModeID|string
  ---@param openRoom boolean
  ---@return GameMode?
  local function getRoomModeWithRosterBounds(gameModeOrId, openRoom)
    local modeId = nil
    if type(gameModeOrId) == "string" then
      modeId = gameModeOrId
    elseif type(gameModeOrId) == "table" then
      modeId = gameModeOrId.gameModeId or gameModeOrId.id or (gameModeOrId.name and GameModes.nameToGameModeId[gameModeOrId.name])
    end

    if not modeId then
      return nil
    end

    local ok, mode = pcall(GameModes.getPreset, modeId)
    if not ok or not mode then
      return nil
    end

    local count = tonumber(mode.playerCount) or tonumber(mode.maxPlayers) or tonumber(mode.minPlayers) or 2
    count = math.max(2, math.floor(count))

    -- "Open" relaxes the start threshold so a partial roster can begin:
    --   * FFA: 2 minimum, up to count.
    --   * Team: teamCount minimum (one body per team). Server now uses
    --     TeamUtils.createTeamsFromFilledSlots for partial rosters, so an
    --     Open 2v2 can run as 1v1 with the other two seats open for drop-in.
    -- Invite-only is always fixed-roster (min == max).
    local isFfa = (mode.playersPerTeam == 1)
    if openRoom and isFfa then
      mode.minPlayers = 2
      mode.maxPlayers = count
    elseif openRoom then
      mode.minPlayers = tonumber(mode.teamCount) or 2
      mode.maxPlayers = count
    else
      mode.minPlayers = count
      mode.maxPlayers = count
    end

    return mode
  end

  -- Garbage mode menu (used by both team and FFA flows). Parameterized so each
  -- flow passes its own parent menu and "close everything" chain — the menu's
  -- focus/teardown wiring differs between flows even though the UI is shared.
  ---@param parentButton table button on the parent menu that opened this menu
  ---@param options table { allMode = GameModeID, sharedMode = GameModeID }
  ---@param parentMenu table the parent ScrollMenu that owns parentButton
  ---@param closeChain function called by latency confirm to dismiss every menu
  local function openGarbageMenu(parentButton, options, parentMenu, closeChain)
    if self.teamGarbageMenu then
      self.teamGarbageMenu:yieldFocus()
    end

    local bx, by = parentButton:getScreenPos()
    local garbageMenu = ui.ScrollMenu({
      x = bx + parentButton.width + 3,
      y = by,
      hAlign = "left",
      vAlign = "top",
      height = 160,
      width = 200,
      padding = 0,
      childGap = 8,
    })

    local function garbageButton(text, description, onClick)
      local btn = ui.TextButton({
        label = ui.Label({text = text, translate = false}),
        onClick = onClick,
      })
      local origSetSelected = btn.setSelected
      btn.setSelected = function(b, selected)
        origSetSelected(b, selected)
        self.garbageTooltip = selected and description or ""
      end
      return btn
    end

    garbageMenu:addChild(garbageButton(
      "Broadcast",
      "Your attack is cloned and sent to every enemy simultaneously. Total damage scales with enemy count — in a 2v2 your combos deal twice the total damage of a 1v1.",
      function(b)
        openLatencyMenu(garbageMenu, b, getRoomModeWithRosterBounds(options.allMode, options.openRoom == true), closeChain, options.openRoom == true)
      end
    ))
    garbageMenu:addChild(garbageButton(
      "Round Robin",
      "Attacks rotate through enemies one at a time. Your team shares one rotation counter, so attacks fan out evenly — total output rate stays the same regardless of enemy count.",
      function(b)
        openLatencyMenu(garbageMenu, b, getRoomModeWithRosterBounds(options.sharedMode, options.openRoom == true), closeChain, options.openRoom == true)
      end
    ))
    garbageMenu:addChild(ui.TextButton({
      label = ui.Label({text = "back"}),
      onClick = function()
        GAME.theme:playCancelSfx()
        garbageMenu:yieldFocus()
      end,
    }))
    garbageMenu:select(garbageMenu.children[1])

    self.teamGarbageMenu = garbageMenu
    parentMenu:setFocus(garbageMenu, function()
      self.garbageTooltip = ""
      parentMenu:select(parentButton)
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
      { label = "1 vs 3", allMode = GameModes.IDs.FOUR_PLAYER_1V3_ALL,     sharedMode = GameModes.IDs.FOUR_PLAYER_1V3_SHARED },
      { label = "3 vs 1", allMode = GameModes.IDs.FOUR_PLAYER_3V1_ALL,     sharedMode = GameModes.IDs.FOUR_PLAYER_3V1_SHARED },
    },
    [5] = {
      { label = "1 vs 4", allMode = GameModes.IDs.FIVE_PLAYER_1V4_ALL, sharedMode = GameModes.IDs.FIVE_PLAYER_1V4_SHARED },
      { label = "4 vs 1", allMode = GameModes.IDs.FIVE_PLAYER_4V1_ALL, sharedMode = GameModes.IDs.FIVE_PLAYER_4V1_SHARED },
      { label = "2 vs 3", allMode = GameModes.IDs.FIVE_PLAYER_2V3_ALL, sharedMode = GameModes.IDs.FIVE_PLAYER_2V3_SHARED },
      { label = "3 vs 2", allMode = GameModes.IDs.FIVE_PLAYER_3V2_ALL, sharedMode = GameModes.IDs.FIVE_PLAYER_3V2_SHARED },
    },
  }

  -- Level 2: division menu (e.g. "1 vs 2", "2 vs 1") for a chosen player count.
  local function openCompositionForCount(parentButton, playerCount, openRoom)
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
      height = math.max(160, (#divisions + 1) * (rowHeight + 8) + 8),
      width = 160,
      padding = 0,
      childGap = 8,
    })

    local function closeTeamMenuChain()
      if self.teamGarbageMenu then self.teamGarbageMenu:yieldFocus() end
      if self.teamCompositionMenu then self.teamCompositionMenu:yieldFocus() end
      if self.teamPlayerCountMenu then self.teamPlayerCountMenu:yieldFocus() end
      if self.teamTypeMenu then self.teamTypeMenu:yieldFocus() end
    end

    for _, div in ipairs(divisions) do
      compositionMenu:addChild(ui.TextButton({
        label = ui.Label({text = div.label, translate = false}),
        onClick = function(b)
          openGarbageMenu(b, { allMode = div.allMode, sharedMode = div.sharedMode, openRoom = openRoom },
            compositionMenu, closeTeamMenuChain)
        end
      }))
    end
    compositionMenu:addChild(ui.TextButton({
      label = ui.Label({text = "back"}),
      onClick = function()
        GAME.theme:playCancelSfx()
        compositionMenu:yieldFocus()
      end,
    }))
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
  local function openTeamCompositionMenu(parentButton, openRoom, parentMenu)
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
      width = 80,
      padding = 0,
      childGap = 8,
    })

    for _, n in ipairs({3, 4, 5}) do
      playerCountMenu:addChild(ui.TextButton({
        label = ui.Label({text = tostring(n), translate = false}),
        onClick = function(b) openCompositionForCount(b, n, openRoom) end,
      }))
    end
    playerCountMenu:addChild(ui.TextButton({
      label = ui.Label({text = "back"}),
      onClick = function()
        GAME.theme:playCancelSfx()
        playerCountMenu:yieldFocus()
      end,
    }))
    playerCountMenu:select(playerCountMenu.children[1])

    self.teamPlayerCountMenu = playerCountMenu
    parentMenu = parentMenu or self.lobbyMenu
    parentMenu:setFocus(playerCountMenu, function()
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
      if parentMenu.select then
        parentMenu:select(parentButton)
      end
      self.teamPlayerCountMenu:detach()
      self.teamPlayerCountMenu = nil
    end)
    self.uiRoot:addChild(playerCountMenu)
  end

  local function openTeamTypeMenu(parentButton)
    if self.teamTypeMenu then
      self.teamTypeMenu:yieldFocus()
    end

    local bx, by = parentButton:getScreenPos()
    local typeMenu = ui.ScrollMenu({
      x = bx + parentButton.width + 3,
      y = by,
      hAlign = "left",
      vAlign = "top",
      height = 160,
      width = 200,
      padding = 0,
      childGap = 8,
    })

    local function typeButton(text, description, onClick)
      local btn = ui.TextButton({
        label = ui.Label({text = text, translate = false}),
        onClick = onClick,
      })
      local origSetSelected = btn.setSelected
      btn.setSelected = function(b, selected)
        origSetSelected(b, selected)
        self.garbageTooltip = selected and description or ""
      end
      return btn
    end

    typeMenu:addChild(typeButton(
      "Invite-only",
      "Closed room. You invite specific players to fill every seat. The match only starts once every seat is filled.",
      function(b) openTeamCompositionMenu(b, false, typeMenu) end
    ))
    typeMenu:addChild(typeButton(
      "Open",
      "Public room — anyone in the lobby can drop in. The match starts as soon as 2 players are ready; remaining seats stay open for more to join later.",
      function(b) openTeamCompositionMenu(b, true, typeMenu) end
    ))
    typeMenu:addChild(ui.TextButton({
      label = ui.Label({text = "back"}),
      onClick = function()
        GAME.theme:playCancelSfx()
        typeMenu:yieldFocus()
      end,
    }))
    typeMenu:select(typeMenu.children[1])

    self.teamTypeMenu = typeMenu
    self.lobbyMenu:setFocus(typeMenu, function()
      self.garbageTooltip = ""
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
      if self.teamPlayerCountMenu then
        self.teamPlayerCountMenu:detach()
        self.teamPlayerCountMenu = nil
      end
      self.teamTypeMenu:detach()
      self.teamTypeMenu = nil
    end)
    self.uiRoot:addChild(typeMenu)
  end

  -- FFA player count menu
  local function openFfaMenu(parentButton, openRoom)
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
      width = 240,
      padding = 0,
      childGap = 8,
    })

    local function closeInviteOnlyChain()
      if self.teamGarbageMenu then self.teamGarbageMenu:yieldFocus() end
      if self.ffaPlayerCountMenu then self.ffaPlayerCountMenu:yieldFocus() end
      if self.ffaTypeMenu then self.ffaTypeMenu:yieldFocus() end
    end

    ffaMenu:addChild(ui.TextButton({
      label = ui.Label({text = "3 Players (1v1v1)", translate = false}),
      onClick = function(b)
        openGarbageMenu(b, {
          allMode = GameModes.IDs.THREE_PLAYER_FFA,
          sharedMode = GameModes.IDs.THREE_PLAYER_FFA_SHARED,
          openRoom = openRoom,
        }, ffaMenu, closeInviteOnlyChain)
      end
    }))
    ffaMenu:addChild(ui.TextButton({
      label = ui.Label({text = "4 Players (1v1v1v1)", translate = false}),
      onClick = function(b)
        openGarbageMenu(b, {
          allMode = GameModes.IDs.FOUR_PLAYER_FFA,
          sharedMode = GameModes.IDs.FOUR_PLAYER_FFA_SHARED,
          openRoom = openRoom,
        }, ffaMenu, closeInviteOnlyChain)
      end
    }))
    ffaMenu:addChild(ui.TextButton({
      label = ui.Label({text = "5 Players (1v1v1v1v1)", translate = false}),
      onClick = function(b)
        openGarbageMenu(b, {
          allMode = GameModes.IDs.FIVE_PLAYER_FFA,
          sharedMode = GameModes.IDs.FIVE_PLAYER_FFA_SHARED,
          openRoom = openRoom,
        }, ffaMenu, closeInviteOnlyChain)
      end
    }))
    ffaMenu:addChild(ui.TextButton({
      label = ui.Label({text = "7 Players (1v1v1v1v1v1v1)", translate = false}),
      onClick = function(b)
        openGarbageMenu(b, {
          allMode = GameModes.IDs.SEVEN_PLAYER_FFA,
          sharedMode = GameModes.IDs.SEVEN_PLAYER_FFA_SHARED,
          openRoom = openRoom,
        }, ffaMenu, closeInviteOnlyChain)
      end
    }))
    ffaMenu:addChild(ui.TextButton({
      label = ui.Label({text = "back"}),
      onClick = function()
        GAME.theme:playCancelSfx()
        ffaMenu:yieldFocus()
      end,
    }))
    ffaMenu:select(ffaMenu.children[1])

    self.ffaPlayerCountMenu = ffaMenu
    self.ffaTypeMenu:setFocus(ffaMenu, function()
      if self.latencyMenu then
        self.latencyMenu:detach()
        self.latencyMenu = nil
      end
      self.ffaPlayerCountMenu:detach()
      self.ffaPlayerCountMenu = nil
    end)
    self.uiRoot:addChild(ffaMenu)
  end

  -- Top-level FFA picker: Invite-only (fixed roster, owner invites) vs Open
  -- (public drop-in, 2-7 dynamic roster).
  local function openFfaTypeMenu(parentButton)
    if self.ffaTypeMenu then
      self.ffaTypeMenu:yieldFocus()
    end

    local bx, by = parentButton:getScreenPos()
    local typeMenu = ui.ScrollMenu({
      x = bx + parentButton.width + 3,
      y = by,
      hAlign = "left",
      vAlign = "top",
      height = 160,
      width = 200,
      padding = 0,
      childGap = 8,
    })

    local function typeButton(text, description, onClick)
      local btn = ui.TextButton({
        label = ui.Label({text = text, translate = false}),
        onClick = onClick,
      })
      local origSetSelected = btn.setSelected
      btn.setSelected = function(b, selected)
        origSetSelected(b, selected)
        self.garbageTooltip = selected and description or ""
      end
      return btn
    end

    typeMenu:addChild(typeButton(
      "Invite-only",
      "Closed room. You invite specific players to fill every seat. The match only starts once every seat is filled.",
      function(b) openFfaMenu(b, false) end
    ))
    typeMenu:addChild(typeButton(
      "Open",
      "Public room — anyone in the lobby can drop in. The match starts as soon as 2 players are ready; remaining seats stay open for more to join later.",
      function(b) openFfaMenu(b, true) end
    ))
    typeMenu:addChild(ui.TextButton({
      label = ui.Label({text = "back"}),
      onClick = function()
        GAME.theme:playCancelSfx()
        typeMenu:yieldFocus()
      end,
    }))
    typeMenu:select(typeMenu.children[1])

    self.ffaTypeMenu = typeMenu
    self.lobbyMenu:setFocus(typeMenu, function()
      self.garbageTooltip = ""
      if self.latencyMenu then
        self.latencyMenu:detach()
        self.latencyMenu = nil
      end
      if self.ffaPlayerCountMenu then
        self.ffaPlayerCountMenu:detach()
        self.ffaPlayerCountMenu = nil
      end
      self.ffaTypeMenu:detach()
      self.ffaTypeMenu = nil
    end)
    self.uiRoot:addChild(typeMenu)
  end

  -- New create flow pushes a single-screen scene (RoomCreateTeamMenu /
  -- RoomCreateFfaMenu) where every option is on one page with prior picks
  -- pre-selected from config.lobbyTeamPrefs / config.lobbyFfaPrefs. The
  -- legacy cascade (openTeamTypeMenu / openFfaTypeMenu and friends) is
  -- still in this file unreferenced so it can be wired back if the new
  -- UX needs to be reverted.
  local RoomCreateTeamMenu = require("client.src.scenes.RoomCreateTeamMenu")
  local RoomCreateFfaMenu = require("client.src.scenes.RoomCreateFfaMenu")

  self.teamCreateButtonLabel = ui.Label({text = "Create Team Game", translate = false})
  self.teamCreateButton = ui.TextButton({
    label = self.teamCreateButtonLabel,
    width = self.lobbyMenuWidth,
    onClick = function(button)
      if self:isLocalPlayerInRoom() then
        GAME.netClient:leaveRoom()
        return
      end
      GAME.theme:playValidationSfx()
      GAME.navigationStack:push(RoomCreateTeamMenu({}))
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
      GAME.theme:playValidationSfx()
      GAME.navigationStack:push(RoomCreateFfaMenu({}))
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

-- Display names per team index, in the same order as TEAM_ROW_TINT. The lobby
-- groups invites/joins by team rather than by slot, so these names are what
-- users actually see ("Join Pink Team", "Invite to Purple Team").
local TEAM_NAMES = {
  [1] = "Pink Team",
  [2] = "Purple Team",
  [3] = "Green Team",
  [4] = "Yellow Team",
  [5] = "Orange Team",
  [6] = "Blue Team",
  [7] = "Cyan Team",
  [8] = "Red Team",
}

local function teamDisplayName(teamIndex)
  return TEAM_NAMES[teamIndex] or ("Team " .. tostring(teamIndex))
end

-- FFA modes (playersPerTeam == 1) are treated as one undifferentiated group:
-- a single "Join FFA" / "Invite to FFA" button regardless of how many seats
-- are open. Team modes are bucketed by team so each team gets one consolidated
-- button. Returns a list of groups, each:
--   { isFfa = true,  slots = {...} }                        -- FFA
--   { isFfa = false, teamIndex = N, slots = {...} }         -- team modes
-- with `slots` listing every currently-open absolute slot number in the group,
-- in ascending order. The caller picks slots[1] as the proposal-key
-- representative and scans all of `slots` when reconciling existing
-- pending/incoming invites.
local function groupOpenSlotsByTeam(room)
  if not room or not room.openSlots or #room.openSlots == 0 then
    return {}
  end

  local ok, gm = pcall(GameModes.getPreset, room.gameModeId)
  if not ok or not gm then
    return { { isFfa = true, slots = room.openSlots } }
  end

  local playersPerTeam = gm.playersPerTeam
  local isFfa = playersPerTeam == 1
    or playersPerTeam == nil
    or (type(playersPerTeam) == "number" and playersPerTeam <= 1)

  if isFfa then
    return { { isFfa = true, slots = room.openSlots } }
  end

  local byTeam = {}
  local orderedTeams = {}
  for _, slotNumber in ipairs(room.openSlots) do
    local teamIndex = getTeamIndexForSlot(room, slotNumber)
    if teamIndex then
      if not byTeam[teamIndex] then
        byTeam[teamIndex] = { isFfa = false, teamIndex = teamIndex, slots = {} }
        orderedTeams[#orderedTeams + 1] = teamIndex
      end
      table.insert(byTeam[teamIndex].slots, slotNumber)
    end
  end

  table.sort(orderedTeams)
  local groups = {}
  for _, teamIndex in ipairs(orderedTeams) do
    groups[#groups + 1] = byTeam[teamIndex]
  end
  return groups
end

-- Walk `slots` looking for the first one with an outstanding invite recorded
-- on the given challenge map (incomingChallenges[ownerId] / outgoing[ownerId]).
-- Returns the matching slot so the button's slotNumber binds to the actual
-- proposal key — that way withdraw/accept resolves the same record the server
-- has stored, even though the *visible* label collapsed N slots into one
-- "Invite to Pink Team" button.
local function findExistingInviteSlot(slots, challengeMap, roomNumber)
  if not challengeMap or not slots or not roomNumber then
    return nil
  end
  for _, slotNumber in ipairs(slots) do
    local inviteKey = "room_" .. roomNumber .. "_" .. slotNumber
    if challengeMap[inviteKey] then
      return slotNumber
    end
  end
  return nil
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

  for _, room in pairs(personalizedLobbyData.rooms) do
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

    -- Title:  "Name1, Name2's Room   [n/m]" — or "[n / min-max]" for dynamic-roster (open FFA).
    local minPlayers = room.minPlayers
    local maxPlayers = room.maxPlayers or 2
    local slotsText
    if minPlayers and minPlayers ~= maxPlayers then
      slotsText = string.format("[%d / %d-%d]", #room.players, minPlayers, maxPlayers)
    else
      slotsText = string.format("[%d/%d]", #room.players, maxPlayers)
    end
    if room.pendingJoinerCount and room.pendingJoinerCount > 0 then
      slotsText = slotsText .. " (+" .. room.pendingJoinerCount .. " queued)"
    end
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
    -- Title row is named after the host (room.players[1]); tint it with the host's
    -- team color so the info row matches the per-player rows below it. The host's
    -- real slot is playerSlots[1] (falls back to 1 for pre-flag protocol or 1v1).
    local hostSlot = (room.playerSlots and room.playerSlots[1]) or 1
    local titleTeamIdx = (room.players and room.players[1]) and getTeamSlotInfo(room, hostSlot) or nil
    rowTints[#rowTints + 1] = titleTeamIdx and teamRowTint(titleTeamIdx) or false

    -- Garbage subtitle (only renders something in shared team modes).
    local TeamBannerHeader = require("client.src.graphics.TeamBannerHeader")
    local okGM, gmPreset = pcall(GameModes.getPreset, room.gameModeId)
    local garbageLabel = okGM and gmPreset and TeamBannerHeader.garbageModeLabel(gmPreset) or nil
    if garbageLabel then
      lines[#lines + 1] = garbageLabel
      rowTints[#rowTints + 1] = false
    end

    -- Player rows. Slot numbers are intentionally hidden from the UI; the
    -- per-row color stripe (via rowTints + getTeamSlotInfo) carries the team
    -- identity instead. `playerSlots[i]` is the actual server slot for the
    -- dense-array index i (sparse rooms — e.g. slots {1,3} in a 2v3 — must
    -- map index→slot to color the row by the right team).
    for i, playerId in ipairs(room.players) do
      local name = (personalizedLobbyData.players[playerId] and personalizedLobbyData.players[playerId].name) or "?"
      local suffix = (playerId == localPublicId) and " (You)" or ""
      lines[#lines + 1] = name .. suffix
      local slot = (room.playerSlots and room.playerSlots[i]) or i
      local tIdx = (getTeamSlotInfo(room, slot))
      rowTints[#rowTints + 1] = tIdx and teamRowTint(tIdx) or false
    end

    -- Open-slot rows: still one row per open slot so the visual capacity is
    -- obvious, but with no slot label — only the team-tinted "(waiting...)".
    if hasOpenSlots then
      for _, slotNumber in ipairs(room.openSlots) do
        local line
        if room.slotRequests and room.slotRequests[slotNumber] then
          local requester = personalizedLobbyData.players[room.slotRequests[slotNumber]]
          local requesterName = (requester and requester.name) or "someone"
          line = "<- " .. requesterName .. " wants in"
        else
          line = "(waiting...)"
        end
        lines[#lines + 1] = line
        local tIdx = (getTeamSlotInfo(room, slotNumber))
        rowTints[#rowTints + 1] = tIdx and teamRowTint(tIdx) or false
      end
    end

    -- Held-slot rows: a player left this fixed-roster room pre-match; their
    -- seat is reserved for rejoin and not joinable by anyone else. Render
    -- below the open rows so the layout stays: present players → open seats →
    -- held seats. Non-local held seats use generic "waiting" copy rather than
    -- naming the player who left — the spec says counts are more useful than
    -- names since the room is gated on body-count, not on a specific person.
    if room.heldSlots and #room.heldSlots > 0 then
      for _, held in ipairs(room.heldSlots) do
        local label
        if held.publicId == localPublicId then
          label = "(your seat — click to rejoin)"
        else
          label = "(waiting for player)"
        end
        lines[#lines + 1] = label
        local tIdx = (getTeamSlotInfo(room, held.slotNumber))
        rowTints[#rowTints + 1] = tIdx and teamRowTint(tIdx) or false
      end
    end

    if not hasOpenSlots and not (room.heldSlots and #room.heldSlots > 0) then
      lines[#lines + 1] = "(" .. room.state .. ")"
      rowTints[#rowTints + 1] = false
    end

    -- Bottom "INVITED" marker, mirroring the top one.
    if invitedSlot then
      lines[#lines + 1] = "INVITED"
      rowTints[#rowTints + 1] = false
    end

    local roomName = table.concat(lines, "\n")

    -- Click behavior depends on relationship to the room. For any non-local
    -- room we open a submenu so the user can pick between joining a slot and
    -- spectating; if there are no slots and no match to watch the submenu
    -- still surfaces a "back" option rather than mystery silence.
    local onClick
    if isLocalPlayerRoom then
      onClick = function(button)
        self:openLocalRoomSubMenu(room, button)
        GAME.theme:playValidationSfx()
      end
    else
      onClick = function(button)
        self:openRoomSubMenu(room, button)
        GAME.theme:playValidationSfx()
      end
    end

    -- Each row sits inside its colored stripe (which starts at button.x + 6).
    -- Offset the label x by 16 so text has ~10px of breathing room from the
    -- stripe's left edge; cut wrapWidth to fit so right-side text doesn't
    -- spill past the stripe. After construction we re-set hAlign because
    -- TextButton forces "center" in its ctor.
    local TEXT_LEFT_OFFSET = 16
    local label = ui.Label({
      text = roomName,
      translate = false,
      wrapWidth = self.lobbyMenuWidth - TEXT_LEFT_OFFSET - 8,
    })
    local button = ui.TextButton({
      label = label,
      width = self.lobbyMenuWidth,
      onClick = onClick,
    })
    button.lobbyType = "room"
    button.room = room
    button.isLocalPlayerRoom = isLocalPlayerRoom

    button.label.x = TEXT_LEFT_OFFSET
    button.label:setWrap(self.lobbyMenuWidth - TEXT_LEFT_OFFSET - 8, "left")

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
    -- Players already in a room cannot request other room slots — show a hint
    -- sub-menu instead of silently no-op'ing so the user understands why the
    -- click did nothing.
    self:openCannotJoinHintMenu(button)
    return
  end

  local x, y = button:getScreenPos()

  local subMenu = ui.ScrollMenu({
    x = x + self.lobbyMenu.width + 3,
    y = y,
    hAlign = "left",
    vAlign = "top",
    height = 300,
    width = 220,
    padding = 0,
    childGap = 8,
  })

  subMenu.roomNumber = room.roomNumber

  -- Two distinct paths for filling empty seats:
  --
  --   OPEN room  (min < max, e.g. open_ffa)  → LobbyRoomJoinButton (direct join,
  --                                              no handshake). Any lobby player
  --                                              can grab any open slot.
  --   INVITE room (min == max, e.g. 2v2)     → LobbyChallengeButton (invite
  --                                              handshake). Owner must accept.
  --
  -- A third case lives on top of INVITE: a held slot (someone left pre-match,
  -- their seat is reserved). The holder gets a direct "Rejoin" button — same
  -- path as open join — bypassing the handshake. Everyone else sees no button
  -- at all for that slot (server.lua:791 would reject them anyway).
  --
  -- Slot numbers are intentionally hidden from the UI: groupOpenSlotsByTeam
  -- collapses N open seats per team into one button ("Join Pink Team") and the
  -- server places the joiner at the next-available position regardless.
  local roomOwnerId = room.ownerId or (room.players and room.players[1])
  local localPublicId = GAME.localPlayer.publicId
  -- "Direct-join" rooms accept any lobby player into open slots without an invite
  -- handshake. Two ways to get here:
  --   1. Explicit Open Team / Open FFA room (room.openRoom == true) — works
  --      regardless of whether the roster is dynamic.
  --   2. Dynamic-roster mode (min < max), where the room concept itself implies
  --      drop-in/drop-out — covers older lobby snapshots that pre-date the
  --      openRoom flag, so existing open_ffa rooms keep working.
  -- Everything else still goes through the invite handshake (LobbyChallengeButton).
  local isDynamicRoster = room.minPlayers ~= nil and room.maxPlayers ~= nil and room.minPlayers < room.maxPlayers
  local isDirectJoin = (room.openRoom == true) or isDynamicRoster

  for _, group in ipairs(groupOpenSlotsByTeam(room)) do
    local groupLabel
    local groupTint
    if group.isFfa then
      groupLabel = loc("lb_join") .. " FFA"
      -- FFA: the slot will be assigned dynamically, so tint by the next-open
      -- slot's team index. This still surfaces the correct color in 3p/4p FFA
      -- where each "team" is one seat.
      local repTeamIdx = group.slots[1] and getTeamIndexForSlot(room, group.slots[1])
      groupTint = repTeamIdx and teamRowTint(repTeamIdx) or nil
    else
      groupLabel = loc("lb_join") .. " " .. teamDisplayName(group.teamIndex)
      groupTint = teamRowTint(group.teamIndex)
    end

    -- Representative slot for the invite handshake / proposal key. Defaults to
    -- the lowest open slot in the group; if there's already a proposal in
    -- flight for one of the group's slots, bind to that slot so withdraw/accept
    -- resolves the existing record.
    local repSlot = group.slots[1]
    local localOutgoing = lobbyDataV2.outgoingChallenges[roomOwnerId]
    local localIncoming = lobbyDataV2.incomingChallenges[roomOwnerId]
    local pendingState = nil
    local incomingSlot = findExistingInviteSlot(group.slots, localIncoming, room.roomNumber)
    if incomingSlot then
      repSlot = incomingSlot
      pendingState = "CHALLENGED"
    else
      local outgoingSlot = findExistingInviteSlot(group.slots, localOutgoing, room.roomNumber)
      if outgoingSlot then
        repSlot = outgoingSlot
        pendingState = "PROPOSING"
      end
    end

    local joinButton
    if isDirectJoin then
      joinButton = ui.LobbyRoomJoinButton({
        playerId = roomOwnerId,
        iconSize = 16,
        roomNumber = room.roomNumber,
        slotNumber = repSlot,
        gameModeId = room.gameModeId,
        label = ui.Label({text = groupLabel, translate = false}),
        acceptImage = GAME.theme:getFightImage(),
        proposeImage = GAME.theme:getFightImage(),
        withdrawImage = GAME.theme:getFightImage(),
        teamTint = groupTint,
        width = 200,
      })
    else
      joinButton = ui.LobbyChallengeButton({
        playerId = roomOwnerId,
        iconSize = 16,
        roomNumber = room.roomNumber,
        slotNumber = repSlot,
        gameModeId = room.gameModeId,
        label = ui.Label({text = groupLabel, translate = false}),
        acceptImage = GAME.theme:getFightImage(),
        proposeImage = GAME.theme:getCheckboxImage(false),
        withdrawImage = GAME.theme:getCheckboxImage(true),
        teamTint = groupTint,
        width = 200,
      })
      if pendingState == "CHALLENGED" then
        joinButton:setState(joinButton.challengeStates.CHALLENGED)
      elseif pendingState == "PROPOSING" then
        joinButton:setState(joinButton.challengeStates.PROPOSING)
      end
    end
    subMenu:addChild(joinButton)
  end

  if room.heldSlots then
    for _, held in ipairs(room.heldSlots) do
      if held.publicId == localPublicId then
        -- Held slots are leaver-specific; the team is fixed by the original
        -- seat, so we label by team rather than seat. FFA falls back to a
        -- generic "Rejoin" since no team identity matters.
        local heldTeamIndex = getTeamIndexForSlot(room, held.slotNumber)
        local rejoinLbl
        local okGm, gmPreset = pcall(GameModes.getPreset, room.gameModeId)
        local isFfaRoom = okGm and gmPreset and (gmPreset.playersPerTeam == 1 or gmPreset.playersPerTeam == nil)
        if isFfaRoom or not heldTeamIndex then
          rejoinLbl = "Rejoin"
        else
          rejoinLbl = "Rejoin " .. teamDisplayName(heldTeamIndex)
        end
        local rejoinTint = heldTeamIndex and teamRowTint(heldTeamIndex) or nil
        local rejoinButton = ui.LobbyRoomJoinButton({
          playerId = roomOwnerId,
          iconSize = 16,
          roomNumber = room.roomNumber,
          slotNumber = held.slotNumber,
          gameModeId = room.gameModeId,
          label = ui.Label({text = rejoinLbl, translate = false}),
          acceptImage = GAME.theme:getFightImage(),
          proposeImage = GAME.theme:getFightImage(),
          withdrawImage = GAME.theme:getFightImage(),
          teamTint = rejoinTint,
          width = 200,
        })
        subMenu:addChild(rejoinButton)
      end
    end
  end

  -- Spectate is always offered as an alternative to grabbing a player slot.
  -- Server gates on whether the room actually has a live match to watch.
  local spectateButton = ui.TextButton({
    label = ui.Label({text = "Spectate", translate = false}),
    width = 200,
    onClick = function()
      GAME.netClient:requestSpectate(room.roomNumber)
      subMenu:yieldFocus()
    end,
  })
  subMenu:addChild(spectateButton)

  local backButton = ui.TextButton({
    label = ui.Label({text = "back"}),
    width = 200,
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

---Shown when the local player clicks another room while already in one. Acts
---as a read-only hint — just an explanatory line plus a "back" button.
---@param button Button the room-button the user clicked
function Lobby:openCannotJoinHintMenu(button)
  if self.roomSubMenu then
    self.roomSubMenu:yieldFocus()
  end

  local x, y = button:getScreenPos()
  local subMenu = ui.ScrollMenu({
    x = x + self.lobbyMenu.width + 3,
    y = y,
    hAlign = "left",
    vAlign = "top",
    height = 120,
    width = 200,
    padding = 0,
    childGap = 8,
  })

  subMenu:addChild(ui.TextButton({
    label = ui.Label({text = "Leave current room first", translate = false}),
    width = 200,
    onClick = function()
      subMenu:yieldFocus()
    end,
  }))
  subMenu:addChild(ui.TextButton({
    label = ui.Label({text = "back"}),
    width = 200,
    onClick = function()
      GAME.theme:playCancelSfx()
      subMenu:yieldFocus()
    end,
  }))
  subMenu:select(subMenu.children[1])
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
    width = 220,
    padding = 0,
    childGap = 8,
  })

  local leaveButton = ui.TextButton({
    label = ui.Label({text = "Leave team game", translate = false}),
    width = 200,
    onClick = function()
      self.teamCreateButton:onClick(button)
    end
  })
  subMenu:addChild(leaveButton)

  local backButton = ui.TextButton({
    label = ui.Label({text = "back"}),
    width = 200,
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
    width = 220,
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

  -- If the target player is in a room with open slots, offer one Join button
  -- per team-with-openings (FFA collapses to a single "Join FFA").
  local playerInfo = lobbyDataV2.players[playerId]
  if (not localInRoom) and playerInfo and playerInfo.roomNumber then
    local targetRoom = lobbyDataV2.rooms[playerInfo.roomNumber]
    if targetRoom and targetRoom.openSlots then
      local roomOwnerId = targetRoom.ownerId or (targetRoom.players and targetRoom.players[1])
      local localOutgoing = lobbyDataV2.outgoingChallenges[roomOwnerId]
      local localIncoming = lobbyDataV2.incomingChallenges[roomOwnerId]
      for _, group in ipairs(groupOpenSlotsByTeam(targetRoom)) do
        local quickJoinLabel
        if group.isFfa then
          quickJoinLabel = loc("lb_join") .. " FFA"
        else
          quickJoinLabel = loc("lb_join") .. " " .. teamDisplayName(group.teamIndex)
        end

        local repSlot = group.slots[1]
        local pendingState = nil
        local incomingSlot = findExistingInviteSlot(group.slots, localIncoming, targetRoom.roomNumber)
        if incomingSlot then
          repSlot = incomingSlot
          pendingState = "CHALLENGED"
        else
          local outgoingSlot = findExistingInviteSlot(group.slots, localOutgoing, targetRoom.roomNumber)
          if outgoingSlot then
            repSlot = outgoingSlot
            pendingState = "PROPOSING"
          end
        end

        local quickJoin = ui.LobbyChallengeButton({
          playerId = roomOwnerId,
          roomNumber = targetRoom.roomNumber,
          slotNumber = repSlot,
          gameModeId = targetRoom.gameModeId,
          iconSize = 16,
          label = ui.Label({text = quickJoinLabel, translate = false}),
          acceptImage = GAME.theme:getFightImage(),
          proposeImage = GAME.theme:getCheckboxImage(false),
          withdrawImage = GAME.theme:getCheckboxImage(true),
          width = 200,
        })
        if pendingState == "CHALLENGED" then
          quickJoin:setState(quickJoin.challengeStates.CHALLENGED)
        elseif pendingState == "PROPOSING" then
          quickJoin:setState(quickJoin.challengeStates.PROPOSING)
        end
        subMenu:addChild(quickJoin)
      end
    end
  end

  -- If LOCAL player leads a partial team room, offer one Invite button per
  -- team-with-openings (FFA collapses to a single "Invite to FFA").
  if isLocalTeamLeader then
    if myRoom and myRoom.openSlots and #myRoom.openSlots > 0 then
      local outgoing = lobbyDataV2.outgoingChallenges[playerId]
      local incoming = lobbyDataV2.incomingChallenges[playerId]

      for _, group in ipairs(groupOpenSlotsByTeam(myRoom)) do
        local inviteLabel
        if group.isFfa then
          inviteLabel = "Invite to FFA"
        else
          inviteLabel = "Invite to " .. teamDisplayName(group.teamIndex)
        end

        local repSlot = group.slots[1]
        local pendingState = nil
        local incomingSlot = findExistingInviteSlot(group.slots, incoming, myRoom.roomNumber)
        if incomingSlot then
          repSlot = incomingSlot
          pendingState = "CHALLENGED"
        else
          local outgoingSlot = findExistingInviteSlot(group.slots, outgoing, myRoom.roomNumber)
          if outgoingSlot then
            repSlot = outgoingSlot
            pendingState = "PROPOSING"
          end
        end

        local inviteBtn = ui.LobbyChallengeButton({
          roomNumber = myRoom.roomNumber,
          slotNumber = repSlot,
          gameModeId = myRoom.gameModeId,
          playerId = playerId,
          iconSize = 16,
          label = ui.Label({text = inviteLabel, translate = false}),
          acceptImage = GAME.theme:getFightImage(),
          proposeImage = GAME.theme:getCheckboxImage(false),
          withdrawImage = GAME.theme:getCheckboxImage(true),
          width = 200,
        })
        if pendingState == "CHALLENGED" then
          inviteBtn:setState(inviteBtn.challengeStates.CHALLENGED)
        elseif pendingState == "PROPOSING" then
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
      width = 200
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
      width = 200
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
    width = 200,
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
      -- "You are all alone in the lobby :(" only makes sense when you have
      -- nowhere to be. Sitting in your own open room counts as being busy —
      -- show nothing rather than awkwardly overlapping the room card.
      if self:isLocalPlayerInRoom() then
        self.lobbyMessage:setText("", nil, false)
      elseif tableUtils.length(GAME.netClient.lobbyDataV2.players) == 1 then
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

      local isFfaRoom = gm and (gm.playersPerTeam == 1 or gm.playersPerTeam == nil)

      if hasOpenSlots then
        -- Room is gated on more players showing up. Lead with a count-based
        -- "Waiting for X more" line so the user sees at a glance what the room
        -- needs — naming present players first would bury that fact.
        local lines = {}

        if gameModeName ~= "" then
          lines[#lines + 1] = gameModeName
        end

        local minPlayers = room.minPlayers or room.maxPlayers
        local missing
        if minPlayers then
          missing = math.max(0, minPlayers - #room.players)
        else
          missing = #room.openSlots
        end
        if missing > 0 then
          lines[#lines + 1] = string.format("Waiting for %d more %s to start",
            missing, (missing == 1) and "player" or "players")
        else
          lines[#lines + 1] = "Game not started"
        end

        for i, playerId in ipairs(room.players) do
          local playerInfo = GAME.netClient.lobbyDataV2.players[playerId]
          local playerName = playerInfo and playerInfo.name or "?"
          local suffix = (playerId == localPublicId) and " (You)" or ""
          lines[#lines + 1] = playerName .. suffix
        end

        lines[#lines + 1] = loc("pl_spectators") .. " " .. #room.spectators

        text = table.concat(lines, "\n")
      elseif #room.players >= 3 then
        -- Full N-player room (waiting-room state or actively playing). Lead with
        -- team or per-player scoreboard so users can compare progress at a glance,
        -- mirroring the 1v1 "Alice 0 : 1 Bob" layout below.
        local lines = {}

        if gameModeName ~= "" then
          lines[#lines + 1] = gameModeName
        end

        if isFfaRoom then
          for i, playerId in ipairs(room.players) do
            local playerInfo = GAME.netClient.lobbyDataV2.players[playerId]
            local playerName = playerInfo and playerInfo.name or "?"
            local w = room.wins and room.wins[i] or 0
            lines[#lines + 1] = string.format("%s: %d", playerName, w)
          end
        else
          local teamBuckets = {}
          local maxTeamIndex = 0
          for i, playerId in ipairs(room.players) do
            local playerInfo = GAME.netClient.lobbyDataV2.players[playerId]
            local playerName = playerInfo and playerInfo.name or "?"
            local slot = (room.playerSlots and room.playerSlots[i]) or i
            local teamIndex = getTeamIndexForSlot(room, slot)
            if teamIndex then
              teamBuckets[teamIndex] = teamBuckets[teamIndex] or {}
              teamBuckets[teamIndex][#teamBuckets[teamIndex] + 1] = playerName
              if teamIndex > maxTeamIndex then maxTeamIndex = teamIndex end
            else
              lines[#lines + 1] = playerName
            end
          end
          for i = 1, maxTeamIndex do
            local names = teamBuckets[i]
            if names and #names > 0 then
              local teamScore = room.teamWins and room.teamWins[i] or 0
              lines[#lines + 1] = string.format("%s (%d): %s",
                teamDisplayName(i), teamScore, table.concat(names, ", "))
            end
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
