local Queue = require("common.lib.Queue")
local tableUtils = require("common.lib.tableUtils")
local logger = require("common.lib.logger")
local fileUtils = require("client.src.FileUtils")
local ModSettings = require("client.src.mods.ModSettings")
local ModFolderTree = require("client.src.mods.ModFolderTree")

local ModLoader = {}

---@type Queue<Mod>
ModLoader.loading_queue = Queue() -- mods to load
---@type table<Mod, boolean>
ModLoader.cancellationList = {}
---@type { mod: Mod, loadFunc: fun() }?
ModLoader.loading_mod = nil -- currently loading mod
---@type table<Mod, string>
ModLoader.invalidMods = {}
---@type ModSettings? the player's mod settings, see ModLoader.getModSettings
ModLoader.settings = nil

-- loads the mod of the specified id
---@param mod Mod
function ModLoader.load(mod)
  logger.debug("Queueing mod " .. mod.id .. ", fullyLoaded: " .. tostring(mod.fullyLoaded))
  if not mod.fullyLoaded then
    ModLoader.loading_queue:push(mod)
  end
end

---@return boolean # if there is still data to load
function ModLoader.update()
  if not ModLoader.loading_mod and ModLoader.loading_queue:len() > 0 then
    local mod = ModLoader.loading_queue:pop()
    logger.debug("Preparing to load mod " .. mod.id)
    -- if the load was cancelled, just abort here
    if ModLoader.cancellationList[mod] then
      logger.debug("Mod " .. mod.id .. " was in the cancellation list and has been cancelled")
      ModLoader.cancellationList[mod] = nil
      return true
    end
    logger.debug("Loading mod " .. mod.id)
    ModLoader.loading_mod = {
      mod,
      coroutine.wrap(
        function()
          mod:load()
          return "done"
        end
      )
    }
  end

  if ModLoader.loading_mod then
    if ModLoader.loading_mod[2]() == "done" then
      logger.debug("finished loading mod " .. ModLoader.loading_mod[1].id)
      ModLoader.loading_mod = nil
      return ModLoader.loading_queue:len() > 0
    else
      return true
    end
  end

  return false
end

-- finish loading all remaining mods
function ModLoader.wait()
  logger.debug("finish all mod updates")
  while ModLoader.update() do
  end
end

-- cancels loading the mod if it is currently being loaded or queued for it
---@param mod Mod
function ModLoader.cancelLoad(mod)
  if ModLoader.loading_mod and not ModLoader.cancellationList[mod] then
    logger.debug("cancelling load for mod " .. mod.id)
    if ModLoader.loading_mod[1] == mod then
      ModLoader.loading_mod = nil
      logger.debug("Mod was currently being loaded, directly cancelled")
    elseif ModLoader.loading_queue:peek() == mod then
      ModLoader.loading_queue:pop()
      logger.debug("Mod was next in queue and got removed")
    elseif tableUtils.contains(ModLoader.loading_queue, mod) then
      logger.debug("Mod is somewhere in the loading queue, adding to cancellationList")
      ModLoader.cancellationList[mod] = true
    else
      logger.debug("Mod is not in the process of being loaded")
      -- the mod is currently not even queued to be loaded so there should be no cancel
    end
  else
    logger.debug("ModLoader is either not busy or mod " .. mod.id .. " is already on the cancellationList")
  end
end


--[[
  Topically a bit different the following functions are more geared towards initialization of mod tables.
  They were formerly located in CharacterLoader/StageLoader though so this is the best fit without hairsplitting names
]]

-- Adds all the mods in a folder recursively to the mods table by constructing them with the given constructor
function ModLoader.addModTypeFromDirectoryRecursively(path, modTypeConstructor, modsById)
  local lfs = love.filesystem
  local raw_dir_list = fileUtils.getFilteredDirectoryItems(path)
  for _, v in ipairs(raw_dir_list) do
    local current_path = path .. "/" .. v
    if lfs.getInfo(current_path) and lfs.getInfo(current_path).type == "directory" then
      -- call recursively: facade folder
      ModLoader.addModTypeFromDirectoryRecursively(current_path, modTypeConstructor, modsById)

      -- init mod: 'real' folder
      local mod = modTypeConstructor(current_path, v)
      local success = mod:json_init()

      if success then
        if modsById[mod.id] ~= nil then
          logger.debug(current_path .. " has been ignored since a mod with this id has already been found")
        else
          modsById[mod.id] = mod
        end
      end
    end
  end
end

-- Iterates through the modsById table and adds the ids of all valid mods to a new modIds table
-- returns: 
--   modIds table
--   table of invalid mod bundles
function ModLoader.fillModIdList(modType, modsById)
  local invalid = {}
  local modIds = {}

  for modId, mod in pairs(modsById) do
    -- bundle mod, needs to be filtered out if invalid
    if mod:isBundle() then
      if ModLoader.validateBundle(modsById, mod) then
        modIds[#modIds + 1] = modId
        logger.debug(mod.id .. " (bundle) has been added to the " .. modType.TYPE .. " list!")
      else
        invalid[#invalid + 1] = modId -- mod is invalid
        logger.warn(mod.id .. " (bundle) is being ignored since it's invalid!")
      end
    else
      -- non-bundle mod
      modIds[#modIds + 1] = modId
      logger.debug(mod.id .. " has been added to the " .. modType.TYPE .. " list!")
    end
  end

  -- for consistency while manual sorting is not possible
  table.sort(modIds, function(a, b)
    return modsById[a].path < modsById[b].path
  end)

  return modIds, invalid
end

function ModLoader.validateBundle(modsById, mod)
  for i = #mod.subIds, 1, -1 do
    local subMod = modsById[mod.subIds[i]]
    if subMod and #subMod.subIds == 0 then -- inner bundles are prohibited
      logger.trace(mod.id .. " has " .. subMod.id .. " as part of its sub " .. mod.TYPE .. "s.")
    else
      logger.warn(mod.subIds[i] .. " is not a valid sub " .. mod.TYPE .. " of " .. mod.id .. " because it does not exist or has own sub " .. mod.TYPE .. "s.")
      table.remove(mod.subIds, i)
    end
  end

  return #mod.subIds >= 2
end

function ModLoader.loadAllMods(modType)
  local all = {}

  -- load bundled assets first so they are not ignored in favor of user mods
  ModLoader.addModTypeFromDirectoryRecursively("client/assets/default_data/" .. modType.SAVE_DIR, modType, all)
  -- load user mods
  ModLoader.addModTypeFromDirectoryRecursively(modType.SAVE_DIR, modType, all)

  return all
end

-- Returns the player's mod settings, reading them on first use
---@return ModSettings
function ModLoader.getModSettings()
  if not ModLoader.settings then
    ModLoader.settings = ModSettings()
    ModLoader.settings:load()
  end
  return ModLoader.settings
end

-- Builds the folder tree of the valid mods with the player's settings, importing blacklist.txt if there are none yet
---@param modType table the class table of the mod type
---@param modsById table<string, table>
---@param ids string[] ids of the valid mods in default order
---@return ModFolderTree
function ModLoader.buildFolderTree(modType, modsById, ids)
  local settings = ModLoader.getModSettings()
  local mods = {}
  local keysById = {}
  for _, id in ipairs(ids) do
    mods[#mods + 1] = modsById[id]
    keysById[id] = ModFolderTree.settingsKeyForPath(modsById[id].path, modType.SAVE_DIR)
  end
  settings:importBlacklist(modType.SAVE_DIR, keysById)
  return ModFolderTree.fromMods(mods, modType.SAVE_DIR, settings)
end

-- Returns the lists of a mod type that has a random mod, with the random mod last in the ids and enabled, choosing
-- from the visible mods
---@param modType table the class table of the mod type
---@param tree ModFolderTree
---@return string[] ids
---@return table<string, table> enabled
---@return string[] visible
function ModLoader.listModsWithRandomEntry(modType, tree)
  local ids, enabled, visible = tree:listModsByStatusWithFallbacks()

  local random = modType.getRandom()
  ids[#ids + 1] = random.id
  enabled[random.id] = random
  random.subIds = visible

  return ids, enabled, visible
end

---@class ModTypeLoader
---@field tree ModFolderTree the folders of the mod type with the player's settings
---@field refresh fun() rebuilds the mod type's globals from the tree

-- Sets the status of one of the loader's folders or mods and rebuilds its globals, see ModFolderTree:setStatusAndSave
---@param loader ModTypeLoader
---@param node ModFolderNode
---@param status ModStatus
---@return boolean changed
function ModLoader.setModStatusAndRefresh(loader, node, status)
  local changed = loader.tree:setStatusAndSave(node, status)
  if changed then
    loader.refresh()
  end
  return changed
end

-- Moves one of the loader's folders or mods within its folder and rebuilds its globals, see ModFolderTree:moveWithinFolderAndSave
---@param loader ModTypeLoader
---@param node ModFolderNode
---@param offset integer
---@return boolean moved
function ModLoader.moveModInDisplayOrder(loader, node, offset)
  local moved = loader.tree:moveWithinFolderAndSave(node, offset)
  if moved then
    loader.refresh()
  end
  return moved
end

-- fix config if it's missing or does not exist
function ModLoader.fixConfigMod(modType, filtered, visible)
  if not config[modType.TYPE] or not filtered[config[modType.TYPE]] then
    -- it's legal to pick a bundle here, no need to go further
    config[modType.TYPE] = tableUtils.getRandomElement(visible)
  end
end

function ModLoader.removeInvalid(unfiltered)
  local invalid = {}

  for id, mod in pairs(unfiltered) do
    local valid, reason = mod:validate()
    if not valid then
      invalid[mod] = reason
      unfiltered[id] = nil
    end
  end

  return invalid
end

-- locally initializes mod tables for the Mod type and preloads all of its mods
---@param modType any the class table of the mod type
---@return table<string, Mod> all all valid mods of that type
---@return string[] ids ids of all valid mods in the player's order, the random mod last
---@return table<string, Mod> filtered all mods that are not off
---@return string[] visible ids of the mods shown in selection menus
---@return ModFolderTree tree the folders of the mods with the player's settings
function ModLoader.initMods(modType)
  local all = ModLoader.loadAllMods(modType)
  local invalid = ModLoader.removeInvalid(all)
  local validIds = ModLoader.fillModIdList(modType, all)

  -- in case of a previous init, we should make sure to have cleared old entries for this mod type
  for _, mod in pairs(all) do
    ModLoader.invalidMods[mod] = nil
  end

  for mod, reason in pairs(invalid) do
    ModLoader.invalidMods[mod] = reason
  end

  modType.loadDefaultMod()
  modType.loadRandomMod()

  local tree = ModLoader.buildFolderTree(modType, all, validIds)
  local ids, filtered, visible = ModLoader.listModsWithRandomEntry(modType, tree)

  ModLoader.fixConfigMod(modType, filtered, visible)

  for _, mod in pairs(all) do
    mod:preload()
  end

  return all, ids, filtered, visible, tree
end

return ModLoader
