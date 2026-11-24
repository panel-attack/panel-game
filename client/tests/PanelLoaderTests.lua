local ModLoader = require("client.src.mods.ModLoader")
local PanelLoader = require("client.src.mods.PanelLoader")
local Panels = require("client.src.mods.Panels")

-- returns the reason the panel set with the id is listed as invalid, if it is
---@param id string
---@return string?
local function invalidReasonOf(id)
  for mod, reason in pairs(ModLoader.invalidMods) do
    if mod.TYPE == Panels.TYPE and mod.id == id then
      return reason
    end
  end
end

-- a sheet panel set in the save directory whose panel-N sheets are missing, as on Android when they are named .PNG
local BROKEN_SET_ID = "panelLoaderTestsBrokenSheet"
local BROKEN_SET_PATH = Panels.SAVE_DIR .. "/" .. BROKEN_SET_ID

local function removeBrokenPanelSet()
  love.filesystem.remove(BROKEN_SET_PATH .. "/config.json")
  love.filesystem.remove(BROKEN_SET_PATH)
end

local function writeBrokenPanelSet()
  love.filesystem.createDirectory(BROKEN_SET_PATH)
  love.filesystem.write(BROKEN_SET_PATH .. "/config.json", '{"id": "' .. BROKEN_SET_ID .. '", "type": "sheet"}')
end

local function testBrokenPanelSetIsSkippedAndTheConfiguredOneFallsBack()
  local previousConfigPanels = config.panels
  writeBrokenPanelSet()
  config.panels = BROKEN_SET_ID

  local success, err = pcall(PanelLoader.initPanels)
  local brokenSet, configured, firstId = allPanels and allPanels[BROKEN_SET_ID], config.panels, visiblePanels[1]
  local reason = invalidReasonOf(BROKEN_SET_ID)

  removeBrokenPanelSet()
  config.panels = previousConfigPanels
  PanelLoader.initPanels()
  local reasonAfterRemoval = invalidReasonOf(BROKEN_SET_ID)
  assert(success, "a broken panel set stops loading: " .. tostring(err))
  assert(brokenSet == nil, "a panel set that fails to load is dropped")
  assert(configured == firstId, "expected the configured broken set to fall back to " .. firstId .. ", got " .. tostring(configured))
  assert(reason and reason:find(BROKEN_SET_PATH .. "/panel-1", 1, true),
    "expected the player to be told panel-1 is missing, got " .. tostring(reason))
  assert(reasonAfterRemoval == nil, "a panel set that is gone on the next load is no longer reported")
end

testBrokenPanelSetIsSkippedAndTheConfiguredOneFallsBack()
