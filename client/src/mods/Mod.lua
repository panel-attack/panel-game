local class = require("common.lib.class")
local utils = require("common.lib.util")

---@class Mod
---@field path string Path to the mod folder content
---@field fullyLoaded boolean if the mod is fully loaded
---@field isVisible boolean if the mod is flagged for display in selection menus
---@field id string? the unique identifier of the mod
---@field subIds string[] contains sub mods if the mod is a bundle
---@field users table tracking table for who currently uses this mod; used for automatic mod load balancing

---@class Mod
---@overload fun(fullPath: string, folderName: string): Mod
---@protected
local Mod = class(
---@param mod Mod
function(mod, fullPath, folderName)
  mod.path = fullPath
  mod.fullyLoaded = false
  mod.isVisible = true

  -- every mod needs to be assigned an id
  mod.id = nil

  mod.subIds = {}

  -- the users table is to track who uses this mod currently
  -- the weak key is a safety net so that users that get garbage collected don't stay listed as using the mod
  -- explicitly unregistering via Mod:unregister(user) is encouraged however
  mod.users = utils.getWeaklyKeyedTable()
end)

Mod.TYPE = "Mod"

function Mod:json_init()
  error("All mods need to implement the function json_init()")
end

function Mod:preload()
  error("All mods need to implement a preload function")
end

function Mod:load(instant)
  error("All mods need to implement a load function")
end

function Mod:unload()
  error("All mods need to implement an unload function")
end

function Mod.isBundle(self)
  return #self.subIds > 0
end

function Mod:getSubMods()
  if self:isBundle() then
    error("All mods that support bundles need to implement a getSubMods function, even if it just returns nil")
  end
end

function Mod.getRandom(visible)
  error("All mods need to implement a getRandom function")
end

function Mod.loadDefaultMod()
  error("All mods need to implement a loadDefaultMod function")
end

function Mod:enable(enable)
  error("All mods need to implement a disable function")
end

function Mod:register(user)
  self.users[user] = true
end

function Mod:unregister(user)
  self.users[user] = nil
end

return Mod