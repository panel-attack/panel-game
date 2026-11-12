local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local fileUtils = require("client.src.FileUtils")
local ModLoader = require("client.src.mods.ModLoader")
local Panels = require("client.src.mods.Panels")

---@class PanelLoader : ModTypeLoader
local PanelLoader = {}

-- Adds the panel set at the given path unless one with its id was already found
---@param path string
---@param folderName string
---@param ids string[] ids in the order they were found
local function addPanelDirectory(path, folderName, ids)
  local panelSet = Panels(path, folderName)
  if panelSet:json_init() then
    if allPanels[panelSet.id] ~= nil then
      logger.trace(path .. " has been ignored since a panel set with this id has already been found")
    else
      allPanels[panelSet.id] = panelSet
      ids[#ids + 1] = panelSet.id
    end
  end
end

-- Adds every panel set inside the folder, at any depth
---@param path string
---@param ids string[] ids in the order they were found
local function addPanelDirectoriesRecursively(path, ids)
  local items = fileUtils.getFilteredDirectoryItems(path)
  for _, item in ipairs(items) do
    local itemPath = path .. "/" .. item
    if love.filesystem.getInfo(itemPath, "directory") then
      -- folders may hold more panel sets
      addPanelDirectoriesRecursively(itemPath, ids)
      addPanelDirectory(itemPath, item, ids)
    end
  end
end

-- (Re)loads every panel set and fills the panel globals from the player's mod settings
function PanelLoader.initPanels()
  ---@type table<string, Panels> every panel set, all of them fully loaded
  allPanels = {}
  local ids = {}

  -- add default panel set manually because it has a "__" in it.
  addPanelDirectory("client/assets/panels/__default", "__default", ids)
  addPanelDirectoriesRecursively("client/assets/default_data/panels", ids)
  addPanelDirectoriesRecursively("panels", ids)

  for _, panelSet in pairs(allPanels) do
    panelSet:load()
  end

  PanelLoader.tree = ModLoader.buildFolderTree(Panels, allPanels, ids)
  PanelLoader.refreshPanels()
end

-- Rebuilds the panel globals from the statuses and order in the mod settings
function PanelLoader.refreshPanels()
  local ids, enabled, visible = PanelLoader.tree:listModsByStatusWithFallbacks()
  ---@type string[] ids of every panel set in the player's order
  panels_ids = ids
  ---@type table<string, Panels> the panel sets that are not off; an opponent's set missing here is drawn with your own
  panels = enabled
  ---@type string[] ids of the panel sets offered in the panel carousel
  visiblePanels = visible

  if not tableUtils.contains(visiblePanels, config.panels) then
    config.panels = visiblePanels[1]
  end
end

PanelLoader.refresh = PanelLoader.refreshPanels

return PanelLoader
