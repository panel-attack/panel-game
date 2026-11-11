local ModLoader = require("client.src.mods.ModLoader")
local PanelLoader = require("client.src.mods.PanelLoader")
local PanelCarousel = require("client.src.ui.PanelCarousel")
local tableUtils = require("common.lib.tableUtils")

-- sets a panel set's status the way ModManagement does, runs check and puts the settings back even if check fails
---@param panelId string
---@param status ModStatus
---@param check fun(changed: boolean)
local function withPanelStatus(panelId, status, check)
  local tree = PanelLoader.tree
  local node = tree:getNodeOfMod(allPanels[panelId])
  local previousEntry = tree.settings:copyEntry(tree.saveDir, node.key)
  local previousConfigPanels = config.panels

  local changed = ModLoader.setModStatusAndRefresh(PanelLoader, node, status)
  local success, err = pcall(check, changed)

  tree.settings:restoreEntry(tree.saveDir, node.key, previousEntry)
  tree:saveAndMirrorBlacklist()
  PanelLoader.refreshPanels()
  config.panels = previousConfigPanels
  assert(success, err)
end

-- returns a panel set that can be turned off without touching the configured one
local function otherPanelId()
  return tableUtils.first(visiblePanels, function(id) return id ~= config.panels end)
end

local function testDefaultPanelSetComesFirst()
  local firstPath = allPanels[panels_ids[1]].path
  assert(firstPath == "client/assets/panels/__default", "expected the default panel set first, got " .. firstPath)
end

local function testPanelSetThatIsOffIsNotUsed()
  local panelId = otherPanelId()
  withPanelStatus(panelId, "off", function(changed)
    assert(changed, "turning off one panel set is allowed")
    assert(panels[panelId] == nil, "an opponent's panel set that is off is replaced by your own")
    assert(not tableUtils.contains(visiblePanels, panelId), "a panel set that is off is not in the carousel")
  end)
end

local function testHiddenPanelSetIsUsedButNotOffered()
  local panelId = otherPanelId()
  withPanelStatus(panelId, "hidden", function()
    assert(panels[panelId] ~= nil, "a hidden panel set is still used when an opponent picks it")
    assert(not tableUtils.contains(visiblePanels, panelId), "a hidden panel set is not in the carousel")
  end)
end

-- configures the second entry of the carousel, runs check with the set given the status and puts the configuration back
---@param status ModStatus
---@param check fun(panelId: string, firstId: string)
local function withSecondEntryConfigured(status, check)
  local previousConfigPanels = config.panels
  local panelId, firstId = visiblePanels[2], visiblePanels[1]
  config.panels = panelId
  withPanelStatus(panelId, status, function()
    check(panelId, firstId)
  end)
  config.panels = previousConfigPanels
end

local function testTurningOffTheConfiguredPanelSetPicksTheFirstEntry()
  withSecondEntryConfigured("off", function(_, firstId)
    assert(config.panels == firstId, "expected " .. firstId .. ", got " .. tostring(config.panels))
  end)
end

local function testHidingTheConfiguredPanelSetPicksTheFirstEntry()
  withSecondEntryConfigured("hidden", function(_, firstId)
    assert(config.panels == firstId, "expected " .. firstId .. ", got " .. tostring(config.panels))
    local carousel = PanelCarousel({})
    carousel:loadPanels()
    local selected = carousel:getSelectedPassenger()
    assert(selected and selected.id == firstId, "expected " .. firstId .. " selected, got " .. tostring(selected and selected.id))
  end)
end

-- sets the local player's panel set to the carousel's second entry and checks it moves to the first once given the status
---@param status ModStatus
local function assertPlayerPanelSetGoesToTheFirstEntry(status)
  local player = GAME.localPlayer
  local previousPanelId = player.settings.panelId
  local panelId, firstId = visiblePanels[2], visiblePanels[1]
  player:setPanels(panelId)

  local selectedId
  withPanelStatus(panelId, status, function()
    player:refreshDisabledSelections()
    selectedId = player.settings.panelId
  end)
  player:setPanels(previousPanelId)
  assert(selectedId == firstId, "expected " .. firstId .. " once " .. status .. ", got " .. tostring(selectedId))
end

local function testPlayerPanelSetThatGoesOffGoesToTheFirstEntry()
  assertPlayerPanelSetGoesToTheFirstEntry("off")
end

local function testPlayerPanelSetThatGetsHiddenGoesToTheFirstEntry()
  assertPlayerPanelSetGoesToTheFirstEntry("hidden")
end

local function testMissingConfiguredPanelSetPicksTheFirstEntryOverPacci()
  local tree = PanelLoader.tree
  local pacciNode = tree:getNodeOfMod(allPanels["pacci"])
  local folderKey = pacciNode.parent.key
  local previousFolderEntry = tree.settings:copyEntry(tree.saveDir, folderKey)
  local previousConfigPanels = config.panels

  local moved = ModLoader.moveModInDisplayOrder(PanelLoader, pacciNode, 1)
  config.panels = nil
  PanelLoader.refreshPanels()
  local configured, firstId = config.panels, visiblePanels[1]

  tree.settings:restoreEntry(tree.saveDir, folderKey, previousFolderEntry)
  tree:saveAndMirrorBlacklist()
  PanelLoader.refreshPanels()
  config.panels = previousConfigPanels
  assert(moved, "pacci can move down")
  assert(firstId ~= "pacci", "pacci is no longer first")
  assert(configured == firstId, "expected " .. firstId .. ", got " .. tostring(configured))
end

testDefaultPanelSetComesFirst()
testPanelSetThatIsOffIsNotUsed()
testHiddenPanelSetIsUsedButNotOffered()
testTurningOffTheConfiguredPanelSetPicksTheFirstEntry()
testHidingTheConfiguredPanelSetPicksTheFirstEntry()
testPlayerPanelSetThatGoesOffGoesToTheFirstEntry()
testPlayerPanelSetThatGetsHiddenGoesToTheFirstEntry()
testMissingConfiguredPanelSetPicksTheFirstEntryOverPacci()
