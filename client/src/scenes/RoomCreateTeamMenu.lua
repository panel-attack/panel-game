-- Single-screen replacement for the cascading "Create team game" flow.
-- All five picks (Type / Players / Composition / Garbage / Latency) live on
-- one menu with the user's previous picks pre-selected from
-- config.lobbyTeamPrefs. Submit goes straight to NetClient:requestRoom.
-- The legacy cascade in Lobby.lua is left in place as a fallback.

local Scene = require("client.src.scenes.Scene")
local ui = require("client.src.ui")
local class = require("common.lib.class")
local inputManager = require("client.src.inputManager")
local logger = require("common.lib.logger")
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local GameModes = require("common.data.GameModes")
local RoomCreateRows = require("client.src.scenes.components.RoomCreateRows")

-- Lock the menu's width so its hAlign="center" anchor doesn't shift left/right
-- when the composition row's button count changes (the menu itself centers
-- relative to its parent based on its width, so a changing width causes the
-- whole menu to visually slide). The fixed width is wide enough for the
-- biggest expected row (5p composition = 4 buttons + label).
local MENU_FIXED_WIDTH = 720

---@class RoomCreateTeamMenu : Scene
local RoomCreateTeamMenu = class(function(self, sceneParams)
  self.music = "main"
  self.tooltip = ""
  self:load(sceneParams)
end, Scene)

RoomCreateTeamMenu.name = "RoomCreateTeamMenu"

-- Pin the menu width across re-layouts. Menu:layout() recomputes self.width
-- as max(item widths); when the composition row swaps from 2 → 4 buttons,
-- width grows and the centered anchor visibly shifts. Clamp it after each
-- layout pass so the anchor stays put.
local function clampMenuWidth(menu, width)
  local origLayout = menu.layout
  menu.layout = function(m)
    origLayout(m)
    m.width = width
  end
  menu:layout()
end

function RoomCreateTeamMenu:setTooltip(text)
  self.tooltip = text or ""
end

function RoomCreateTeamMenu:rebuildMenu()
  -- Remember the previously focused row so a rebuild driven by changing the
  -- player count keeps the cursor on the Players row (the rebuild is triggered
  -- *from* that row, so jumping focus elsewhere is jarring). On first build
  -- self.menu is nil and we fall through to focusing Create below.
  local prevIndex = self.menu and self.menu.selectedIndex or nil
  if self.menu then
    self.menu:detach()
  end

  local prefs = config.lobbyTeamPrefs
  local tooltipFn = function(text) self:setTooltip(text) end

  -- Composition list depends on playerCount, so on a count change we rebuild
  -- the whole menu. Cheap (a handful of UI objects) and keeps focus
  -- management simple — alternative is in-place row swap which is harder to
  -- keep the keyboard cursor consistent with.
  local items = {
    RoomCreateRows.createTypeRow(prefs, tooltipFn),
    RoomCreateRows.createPlayerCountRow(prefs, {3, 4, 5, 6, 7}, function()
      self:rebuildMenu()
    end, tooltipFn),
    RoomCreateRows.createCompositionRow(prefs, prefs.playerCount, tooltipFn),
    RoomCreateRows.createGarbageRow(prefs, tooltipFn),
    RoomCreateRows.createLatencyRow(prefs, tooltipFn),
    RoomCreateRows.createCreateButton(function() self:submit() end, tooltipFn),
    RoomCreateRows.createCancelButton(tooltipFn),
  }
  -- Index of the Create button — pre-focus this when the menu opens so the
  -- user can press Enter to confirm defaults immediately. Keep in sync with
  -- the items list above; the Create button is always second from last.
  local createIndex = #items - 1

  -- Center each row within the menu's locked column so rows of different
  -- widths (composition row varies 2-4 buttons) stay visually centered
  -- rather than left-stuck to the menu's edge.
  for _, item in ipairs(items) do
    item.hAlign = "center"
  end

  self.menu = ui.Menu.createCenteredMenu(items)
  clampMenuWidth(self.menu, MENU_FIXED_WIDTH)
  self.uiRoot:addChild(self.menu)
  local targetIndex = prevIndex or createIndex
  if targetIndex < 1 or targetIndex > #items then targetIndex = createIndex end
  self.menu:setSelectedIndex(targetIndex)
end

function RoomCreateTeamMenu:submit()
  local prefs = config.lobbyTeamPrefs
  local division = RoomCreateRows.resolveTeamDivision(prefs.playerCount, prefs.composition)
  if not division then
    logger.error("RoomCreateTeamMenu: no division for " .. tostring(prefs.playerCount)
      .. "/" .. tostring(prefs.composition))
    return
  end

  local modeIdName = (prefs.garbage == "shared") and division.sharedModeId or division.allModeId
  local modeId = GameModes.IDs[modeIdName]
  if not modeId then
    logger.error("RoomCreateTeamMenu: unknown GameModes.IDs." .. tostring(modeIdName))
    return
  end

  local openRoom = (prefs.type == "open")
  local gameMode = RoomCreateRows.resolveGameMode(modeId, openRoom)
  if not gameMode then
    logger.error("RoomCreateTeamMenu: failed to resolve gameMode for " .. tostring(modeId))
    return
  end

  -- Set MODERN style for multiplayer (matches the legacy cascade behavior;
  -- the server's leaderboard/style gating expects modern picks).
  if GAME.localPlayer.settings.style ~= GameModes.Styles.MODERN then
    GAME.localPlayer:setStyle(GameModes.Styles.MODERN)
    GAME.netClient:sendPlayerSettings(GAME.localPlayer)
  end

  logger.info(string.format(
    "RoomCreateTeamMenu submit: type=%s players=%d comp=%s garbage=%s latency=%s mode=%s",
    prefs.type, prefs.playerCount, prefs.composition, prefs.garbage, prefs.latency, modeIdName))

  GAME.netClient:requestRoom(gameMode, prefs.latency, openRoom)
  GAME.navigationStack:pop()
end

function RoomCreateTeamMenu:load()
  self.backgroundImage = themes[config.theme].images.bg_main
  self:rebuildMenu()
end

function RoomCreateTeamMenu:updateSelf(dt)
  if self.backgroundImage and self.backgroundImage.update then
    self.backgroundImage:update(dt)
  end
  if self.menu then
    -- Pressing MenuSelect (Enter / gamepad Start) on a settings row submits
    -- the form. Rows are: 1..N=ButtonGroups, N+1=Create, N+2=Cancel — for
    -- index < createIndex we shortcut to submit so the user doesn't have to
    -- scroll to Create just to confirm. Create and Cancel keep their own
    -- onClick handling (Cancel must still cancel, not submit).
    local items = self.menu.menuItems
    local createIndex = #items - 1
    if inputManager.isDown["MenuSelect"] and self.menu.selectedIndex < createIndex then
      self:submit()
      return
    end
    self.menu:receiveInputs(inputManager)
  end
end

function RoomCreateTeamMenu:drawSelf()
  if self.backgroundImage then
    self.backgroundImage:draw()
  end
  if self.tooltip and self.tooltip ~= "" then
    local pad = 12
    local fontSize = GraphicsUtil.fontSize
    local bh = fontSize + pad * 2
    local by = consts.CANVAS_HEIGHT - bh - 8
    love.graphics.setColor(0.10, 0.04, 0.20, 0.88)
    love.graphics.rectangle("fill", 0, by, consts.CANVAS_WIDTH, bh)
    love.graphics.setColor(1, 1, 1, 1)
    GraphicsUtil.printf(self.tooltip, 0, by + pad, consts.CANVAS_WIDTH, "center")
  end
end

return RoomCreateTeamMenu
