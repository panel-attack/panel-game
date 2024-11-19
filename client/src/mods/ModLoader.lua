local Queue = require("common.lib.Queue")
local tableUtils = require("common.lib.tableUtils")
local logger = require("common.lib.logger")
local fileUtils = require("client.src.FileUtils")

local ModLoader = {}

ModLoader.loading_queue = Queue() -- mods to load
ModLoader.cancellationList = {}
ModLoader.loading_mod = nil -- currently loading mod

-- loads the mod of the specified id
function ModLoader.load(mod)
  logger.debug("Queueing mod " .. mod.id .. ", fullyLoaded: " .. tostring(mod.fullyLoaded))
  if not mod.fullyLoaded then
    ModLoader.loading_queue:push(mod)
  end
end

-- return true if there is still data to load
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
      coroutine.create(
        function()
          mod:load()
        end
      )
    }
  end

  if ModLoader.loading_mod then
    if coroutine.status(ModLoader.loading_mod[2]) == "suspended" then
      coroutine.resume(ModLoader.loading_mod[2])
      return true
    elseif coroutine.status(ModLoader.loading_mod[2]) == "dead" then
      logger.debug("finished loading mod " .. ModLoader.loading_mod[1].id)
      ModLoader.loading_mod = nil
      return ModLoader.loading_queue:len() > 0
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

      -- init stage: 'real' folder
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
function ModLoader.fillModIdList(modsById)
  local invalid = {}
  local modIds = {}

  for modId, mod in pairs(modsById) do
    -- bundle mod, needs to be filtered out if invalid
    if mod:is_bundle() then
      if ModLoader.validateBundle(modsById, mod) then
        modIds[#modIds + 1] = modId
        logger.debug(mod.id .. " (bundle) has been added to the character list!")
      else
        invalid[#invalid + 1] = modId -- mod is invalid
        logger.warn(mod.id .. " (bundle) is being ignored since it's invalid!")
      end
    else
      -- normal character
      modIds[#modIds + 1] = modId
      logger.debug(mod.id .. " has been added to the character list!")
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
    local subCharacter = modsById[mod.subIds[i]]
    if subCharacter and #subCharacter.subIds == 0 then -- inner bundles are prohibited
      logger.trace(mod.id .. " has " .. subCharacter.id .. " as part of its subcharacters.")
    else
      logger.warn(mod.subIds[i] .. " is not a valid sub character of " .. mod.id .. " because it does not  exist or has own sub characters.")
      table.remove(mod.subIds, i)
    end
  end

  return #mod.subIds >= 2
end

local blackLists = {}

-- all mods are default enabled until they're actively disabled upon which they are added to this blacklist
function ModLoader.loadBlacklist(modType)
  local blackList = {}
  local path = modType.SAVE_DIR .. "/blacklist.txt"
  if love.filesystem.getInfo(path, "file") then
    for line in love.filesystem.lines(path) do
      blackList[#blackList+1] = line
    end
  end
  blackLists[modType.TYPE] = blackList
  return blackList
end

-- updates an items blacklist status and writes to disk
function ModLoader.updateBlacklist(mod, enable)
  local blackList = blackLists[mod.TYPE]
  local i = tableUtils.indexOf(blackList, mod.id)

  if enable and i then
    table.remove(blackList, i)
  elseif not enable and not i then
    blackList[#blackList+1] = mod.id
  end

  love.filesystem.write(mod.SAVE_DIR .. "/blacklist.txt", table.concat(blackList, "\n"))
end

function ModLoader.loadAllMods(modType)
  local all = {}

  -- load bundled assets first so they are not ignored in favor of user mods
  ModLoader.addModTypeFromDirectoryRecursively("client/assets/default_data/" .. modType.SAVE_DIR, modType, all)
  -- load user mods
  ModLoader.addModTypeFromDirectoryRecursively(modType.SAVE_DIR, modType, all)

  return all
end

function ModLoader.disableBlacklisted(modType, unfiltered)
  local blackList = ModLoader.loadBlacklist(modType)
  for _, stageId in ipairs(blackList) do
    -- blacklisted characters are removed from the filtered output
    unfiltered[stageId] = nil
  end

  if tableUtils.length(unfiltered) == 0 then
    -- fallback for configurations in which all stages have been disabled
    unfiltered = shallowcpy(unfiltered)
  end

  return unfiltered
end

function ModLoader.filterToVisible(filtered, ids)
  -- holds stages ids for the current theme, those stages will appear in the selection
  local visible = {}

  if love.filesystem.getInfo(themes[config.theme].path .. "/stages.txt") then
    for line in love.filesystem.lines(themes[config.theme].path .. "/stages.txt") do
      line = trim(line) -- remove whitespace
      -- found at least a valid stage in a stages.txt file
      if filtered[line] then
        visible[#visible + 1] = line
      end
    end
  else
    for _, id in ipairs(ids) do
      if filtered[id] and filtered[id].isVisible then
        visible[#visible + 1] = id
      end
    end
  end

  if #visible == 0 then
    -- fallback in case there were no stages left
    visible = shallowcpy(ids)
  end

  return visible
end

-- fix config if it's missing or does not exist
function ModLoader.fixConfigStage(modType, filtered, visible)
  if not config[modType.TYPE] or not filtered[config[modType.TYPE]] then
    -- it's legal to pick a bundle here, no need to go further
    config[modType.TYPE] = tableUtils.getRandomElement(visible)
  end
end

-- locally initializes mod tables for the Mod type and preloads all of its mods
-- returns 4 mod tables:
--   all mods of that type
--   all ids of valid mods
--   all mods that made it through the filter
--   all mods that are supposed to be visible
function ModLoader.initMods(modType)
  local all = ModLoader.loadAllMods(modType)
  local ids = ModLoader.fillModIdList(all)
  local filtered = ModLoader.disableBlacklisted(modType, shallowcpy(all))
  local visible = ModLoader.filterToVisible(filtered, ids)

  modType.loadDefaultMod()

  local random = modType.getRandom(visible)
  ids[#ids+1] = random.id
  filtered[random.id] = random

  ModLoader.fixConfigStage(modType, filtered, visible)

  for _, mod in pairs(all) do
    mod:preload()
  end

  return all, ids, filtered, visible
end



return ModLoader