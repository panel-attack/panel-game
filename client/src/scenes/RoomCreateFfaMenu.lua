-- Single-screen replacement for the cascading "Create FFA game" flow.
-- Picks (Type / Players / Garbage / Latency) sit on one menu with the user's
-- previous selections pre-loaded from config.lobbyFfaPrefs. Legacy cascade
-- in Lobby.lua is left in place as a fallback.

local Scene = require("client.src.scenes.Scene")
local ui = require("client.src.ui")
local class = require("common.lib.class")
local inputManager = require("client.src.inputManager")
local logger = require("common.lib.logger")
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local GameModes = require("common.data.GameModes")
local RoomCreateRows = require("client.src.scenes.components.RoomCreateRows")

local MENU_FIXED_WIDTH = 720

---@class RoomCreateFfaMenu : Scene
local RoomCreateFfaMenu = class(function(self, sceneParams)
  self.music = "main"
  self.tooltip = ""
  self:load(sceneParams)
end, Scene)

RoomCreateFfaMenu.name = "RoomCreateFfaMenu"

local function clampMenuWidth(menu, width)
  local origLayout = menu.layout
  menu.layout = function(m)
    origLayout(m)
    m.width = width
  end
  menu:layout()
end

function RoomCreateFfaMenu:setTooltip(text)
  self.tooltip = text or ""
end

function RoomCreateFfaMenu:rebuildMenu()
  if self.menu then
    self.menu:detach()
  end

  local prefs = config.lobbyFfaPrefs
  local tooltipFn = function(text) self:setTooltip(text) end

  local items = {
    RoomCreateRows.createTypeRow(prefs, tooltipFn),
    RoomCreateRows.createPlayerCountRow(prefs, {3, 4, 5, 7}, function()
      -- FFA has no composition dependency, so no rebuild needed — kept as a
      -- no-op for symmetry with Team's rebuild-on-count pattern.
    end, tooltipFn),
    RoomCreateRows.createGarbageRow(prefs, tooltipFn),
    RoomCreateRows.createLatencyRow(prefs, tooltipFn),
    RoomCreateRows.createCreateButton(function() self:submit() end, tooltipFn),
    RoomCreateRows.createCancelButton(tooltipFn),
  }
  local createIndex = #items - 1

  -- Center each row within the menu's locked column so rows of different
  -- widths stay visually centered rather than left-stuck.
  for _, item in ipairs(items) do
    item.hAlign = "center"
  end

  self.menu = ui.Menu.createCenteredMenu(items)
  clampMenuWidth(self.menu, MENU_FIXED_WIDTH)
  self.uiRoot:addChild(self.menu)
  self.menu:setSelectedIndex(createIndex)
end

function RoomCreateFfaMenu:submit()
  local prefs = config.lobbyFfaPrefs
  local modes = RoomCreateRows.FFA_MODES[prefs.playerCount]
  if not modes then
    logger.error("RoomCreateFfaMenu: no FFA modes for player count " .. tostring(prefs.playerCount))
    return
  end

  local modeIdName = (prefs.garbage == "shared") and modes.sharedModeId or modes.allModeId
  local modeId = GameModes.IDs[modeIdName]
  if not modeId then
    logger.error("RoomCreateFfaMenu: unknown GameModes.IDs." .. tostring(modeIdName))
    return
  end

  local openRoom = (prefs.type == "open")
  local gameMode = RoomCreateRows.resolveGameMode(modeId, openRoom)
  if not gameMode then
    logger.error("RoomCreateFfaMenu: failed to resolve gameMode for " .. tostring(modeId))
    return
  end

  if GAME.localPlayer.settings.style ~= GameModes.Styles.MODERN then
    GAME.localPlayer:setStyle(GameModes.Styles.MODERN)
    GAME.netClient:sendPlayerSettings(GAME.localPlayer)
  end

  logger.info(string.format(
    "RoomCreateFfaMenu submit: type=%s players=%d garbage=%s latency=%s mode=%s",
    prefs.type, prefs.playerCount, prefs.garbage, prefs.latency, modeIdName))

  GAME.netClient:requestRoom(gameMode, prefs.latency, openRoom)
  GAME.navigationStack:pop()
end

function RoomCreateFfaMenu:load()
  self.backgroundImage = themes[config.theme].images.bg_main
  self:rebuildMenu()
end

function RoomCreateFfaMenu:updateSelf(dt)
  if self.backgroundImage and self.backgroundImage.update then
    self.backgroundImage:update(dt)
  end
  if self.menu then
    self.menu:receiveInputs(inputManager)
  end
end

function RoomCreateFfaMenu:drawSelf()
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

return RoomCreateFfaMenu
