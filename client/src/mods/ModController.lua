local tableUtils = require("common.lib.tableUtils")
local ModLoader = require("client.src.mods.ModLoader")
local utils = require("common.lib.util")
local logger = require("common.lib.logger")

-- the mod controller is a global accessor for loading mods
-- internally it keeps tabs on who uses which mod
-- that way it will also internally unload mods once they are no longer in use
local ModController = {
  -- the users table is keyed with the table that the mod was loaded for
  -- each mod user can hold only onto a single mod per type (which can be a bundle)
  -- when mod users request a different mod the old one will get unloaded
  users = utils.getWeaklyKeyedTable()
    --[[ 
    user = {
      character = modObject
      stage = modObject
    }
    ]]
  ,
  toUnload = {}
}

-- unloads the mod and any of its subMods that are not currently in use
local function unloadMod(modController, mod)
  ModLoader.cancelLoad(mod)
  mod:unload()
  local subMods = mod:getSubMods()
  if #subMods > 0 then
    logger.warn("Technically we should never reach here because actually selected mods cannot be bundles")
    for _, subMod in ipairs(subMods) do
      if subMod.fullyLoaded and tableUtils.length(subMod.users) == 0 then
        -- we need to crosscheck:
        -- if multiple players have picked different bundles that have an intersection in subMods,
        --  we don't want to unload the mod in use by both bundles just because one got unselected
        --  this is a bit ugly but the alternative would be to allow users to track more than one mod per type
        --  and that would be ugly in a different way
        if tableUtils.trueForAny(modController.users, function(user)
          logger.debug("Reached the submod bundle crosscheck for mod " .. mod.id)
            local m = user[mod.TYPE]
            if not m then
              return false
            else
              if m == subMod then
                logger.warn("Found a user using a mod that was about to be disabled as part of submod disable routine")
                return true
              elseif tableUtils.contains(m:getSubMods(), subMod) then
                -- this is the main case we check for
                logger.debug("Found a user that may still reroll into this character as part of their separate bundle")
                return true
              else
                return false
              end
            end
          end)
        then
          -- don't unload it cause someone still uses it
        else
          logger.debug("Unloading submod " .. subMod.id)
          subMod:unload()
        end
      end
    end
  end
end

local function clearModForUser(modController, user, type)
  if modController.users[user] then
    local previousMod = modController.users[user][type]
    if previousMod then
      previousMod:unregister(user)
    end
  end
end

local function registerModForUser(modController, user, mod)
  if not modController.users[user] then
    modController.users[user] = {}
  end
  modController.users[user][mod.TYPE] = mod
  mod:register(user)
end

-- loads the mod for a table value
-- pass instantly = true to disregard responsiveness and finish loading all remaining mods on the same frame
function ModController:loadModFor(mod, user, instantly)
  if not self.users[user] or self.users[user][mod.TYPE] ~= mod then
    logger.debug("Registering mod " .. mod.id)
    clearModForUser(self, user, mod.TYPE)
    registerModForUser(self, user, mod)
    -- any mod getting loaded is immediately marked for unloading
    if not tableUtils.contains(self.toUnload, mod) then
      logger.debug("Adding mod " .. mod.id .. " to unload list")
      self.toUnload[#self.toUnload+1] = mod
    end

    ModLoader.load(mod)
    if instantly then
      ModLoader.wait()
    end
  else
    if instantly then
      ModLoader.load(mod)
      ModLoader.wait()
    end
  end
end

function ModController:update()
  ModLoader.update()
  self:unloadUnusedMods()
end

function ModController:unloadUnusedMods()
  for i = #self.toUnload, 1, -1 do
    local mod = self.toUnload[i]
    if tableUtils.length(mod.users) == 0 then
      unloadMod(self, mod)
      table.remove(self.toUnload, i)
    end
  end
end

function ModController:releaseModsFor(user)
  for _, mod in ipairs(self.toUnload) do
    mod:unregister(user)
  end
  self.users[user] = nil
end

return ModController