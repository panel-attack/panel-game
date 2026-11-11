local class = require("common.lib.class")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local ModSettings = require("client.src.mods.ModSettings")

-- folder that holds the mods bundled with the game in a key
local BUILTIN = "@builtin"

---@class ModFolderNode
---@field key string path relative to the mod type's save directory, "" for the top level
---@field name string last part of the key
---@field parent ModFolderNode? nil for the top level
---@field children ModFolderNode[] in default order
---@field mod table? the mod in this folder, nil for a folder that only holds other mods
---@field defaultStatus ModStatus status without an entry in the settings

-- The folders of one mod type with the status and order the player set for each.
-- The default order of a folder's children is the order their first mod came in; the settings' order for a folder
-- lists children first and the rest follow in default order, so a newly installed mod goes last.
---@class ModFolderTree
---@field root ModFolderNode
---@field saveDir string
---@field settings ModSettings
---@field nodesByKey table<string, ModFolderNode>
---@field nodesByMod table<table, ModFolderNode>
---@field nodesById table<string, ModFolderNode>
---@overload fun(saveDir: string, settings: ModSettings): ModFolderTree
local ModFolderTree = class(
---@param self ModFolderTree
function(self, saveDir, settings)
  self.saveDir = saveDir
  self.settings = settings
  self.root = {key = "", name = "", children = {}, defaultStatus = "shown"}
  self.nodesByKey = {[""] = self.root}
  self.nodesByMod = {}
  self.nodesById = {}
end)

ModFolderTree.BUILTIN = BUILTIN

-- Returns the settings key for a mod folder: relative to the save directory for the player's mods and under
-- "@builtin" for mods bundled with the game
---@param path string
---@param saveDir string
---@return string
function ModFolderTree.settingsKeyForPath(path, saveDir)
  for _, builtinFolder in ipairs({"client/assets/default_data/" .. saveDir .. "/", "client/assets/" .. saveDir .. "/"}) do
    if path:sub(1, #builtinFolder) == builtinFolder then
      return BUILTIN .. "/" .. path:sub(#builtinFolder + 1)
    end
  end

  local userFolder = saveDir .. "/"
  if path:sub(1, #userFolder) == userFolder then
    return path:sub(#userFolder + 1)
  end
  return path
end

-- Builds the tree of the mods, given in default order
---@param mods table[] mods with a path and id, and an isVisible flag for their default status
---@param saveDir string
---@param settings ModSettings
---@return ModFolderTree
function ModFolderTree.fromMods(mods, saveDir, settings)
  local tree = ModFolderTree(saveDir, settings)
  for _, mod in ipairs(mods) do
    tree:addMod(mod)
  end
  return tree
end

-- Returns the node for the key, creating it and the folders above it
---@param key string
---@return ModFolderNode
function ModFolderTree:getOrCreateNode(key)
  local node = self.nodesByKey[key]
  if not node then
    local parentKey, name = key:match("^(.*)/([^/]*)$")
    local parent = self:getOrCreateNode(parentKey or "")
    node = {key = key, name = name or key, parent = parent, children = {}, defaultStatus = "shown"}
    parent.children[#parent.children + 1] = node
    self.nodesByKey[key] = node
  end
  return node
end

-- Adds the mod at its folder, creating the folders above it
---@param mod table
function ModFolderTree:addMod(mod)
  local node = self:getOrCreateNode(ModFolderTree.settingsKeyForPath(mod.path, self.saveDir))
  node.mod = mod
  if mod.isVisible == false then
    node.defaultStatus = "hidden"
  end
  self.nodesByMod[mod] = node
  self.nodesById[mod.id] = node
end

-- Returns the node for the key, nil if there is none
---@param key string
---@return ModFolderNode?
function ModFolderTree:getNodeByKey(key)
  return self.nodesByKey[key]
end

-- Returns the node the mod is in, nil if it is not in the tree
---@param mod table
---@return ModFolderNode?
function ModFolderTree:getNodeOfMod(mod)
  return self.nodesByMod[mod]
end

-- Returns the status set for the node itself, ignoring its folders
---@param node ModFolderNode
---@return ModStatus
function ModFolderTree:getOwnStatus(node)
  return self.settings:getStatus(self.saveDir, node.key) or node.defaultStatus
end

-- Returns the status the node has in game: its own or the lowest of its folders', whichever is lower
---@param node ModFolderNode
---@return ModStatus
function ModFolderTree:getEffectiveStatus(node)
  local status = self:getOwnStatus(node)
  local folder = node.parent
  while folder do
    status = ModSettings.lowerStatus(status, self:getOwnStatus(folder))
    folder = folder.parent
  end
  return status
end

-- Returns the node's children in the order the player set, followed by the ones the order does not name
---@param node ModFolderNode
---@return ModFolderNode[]
function ModFolderTree:getOrderedChildren(node)
  local entry = self.settings:getEntries(self.saveDir)[node.key]
  if not entry or not entry.order then
    return node.children
  end

  local childrenByName = {}
  for _, child in ipairs(node.children) do
    childrenByName[child.name] = child
  end
  local ordered = {}
  local placed = {}
  for _, name in ipairs(entry.order) do
    local child = childrenByName[name]
    if child and not placed[child] then
      ordered[#ordered + 1] = child
      placed[child] = true
    end
  end
  for _, child in ipairs(node.children) do
    if not placed[child] then
      ordered[#ordered + 1] = child
    end
  end
  return ordered
end

-- Returns every node holding a mod, each folder's mod before the ones inside it, in the player's order
---@return ModFolderNode[]
function ModFolderTree:getModNodesInOrder()
  local nodes = {}
  local function visit(node)
    if node.mod then
      nodes[#nodes + 1] = node
    end
    for _, child in ipairs(self:getOrderedChildren(node)) do
      visit(child)
    end
  end
  visit(self.root)
  return nodes
end

-- Returns whether the node is inside the folder at any depth
---@param node ModFolderNode
---@param folder ModFolderNode
---@return boolean
local function isInside(node, folder)
  local parent = node.parent
  while parent do
    if parent == folder then
      return true
    end
    parent = parent.parent
  end
  return false
end

-- Returns the installed sub mods of the node's bundle that live outside its folder, in the bundle's order
---@param node ModFolderNode
---@return ModFolderNode[]
function ModFolderTree:getSubModNodesOutsideFolder(node)
  local linked = {}
  if node.mod and node.mod.subIds then
    for _, subId in ipairs(node.mod.subIds) do
      local subNode = self.nodesById[subId]
      if subNode and not isInside(subNode, node) then
        linked[#linked + 1] = subNode
      end
    end
  end
  return linked
end

---@class ModFolderRow
---@field node ModFolderNode
---@field depth integer 0 for the top level
---@field linkedFrom ModFolderNode? the bundle a sub mod from another folder is listed under
---@field modCount integer mods listed under the row: those inside it and, for a bundle, its sub mods from other folders
---@field position integer? where the node is among its folder's children in the player's order, nil for a linked row
---@field siblingCount integer? how many children the node's folder has, nil for a linked row

-- Returns a row for every folder and mod in the player's order, leaving out what is inside a collapsed folder.
-- A bundle's sub mods from other folders follow its children, listed again under it.
---@param collapsedKeys table<string, boolean> keys of the collapsed folders
---@return ModFolderRow[]
function ModFolderTree:getDisplayRows(collapsedKeys)
  local rows = {}
  local modCounts = self:countModsInsideEachFolder()
  local function visit(node, depth)
    local children = self:getOrderedChildren(node)
    for position, child in ipairs(children) do
      local linkedNodes = self:getSubModNodesOutsideFolder(child)
      rows[#rows + 1] = {
        node = child,
        depth = depth,
        modCount = modCounts[child] + #linkedNodes,
        position = position,
        siblingCount = #children,
      }
      if not collapsedKeys[child.key] then
        visit(child, depth + 1)
        for _, linkedNode in ipairs(linkedNodes) do
          rows[#rows + 1] = {node = linkedNode, depth = depth + 1, linkedFrom = child, modCount = 0}
        end
      end
    end
  end
  visit(self.root, 0)
  return rows
end

-- Returns how many mods are inside each folder at any depth, not counting a mod in the folder itself, in one pass
---@return table<ModFolderNode, integer>
function ModFolderTree:countModsInsideEachFolder()
  local counts = {}
  local function visit(node)
    local count = 0
    for _, child in ipairs(node.children) do
      count = count + visit(child)
    end
    counts[node] = count
    return count + (node.mod and 1 or 0)
  end
  visit(self.root)
  return counts
end

-- Returns the highest status the node can have in game, the effective status of its folder
---@param node ModFolderNode
---@return ModStatus
function ModFolderTree:getHighestAllowedStatus(node)
  return self:getEffectiveStatus(node.parent)
end

-- Works out which mods are enabled and which are shown from the statuses, without fallbacks.
-- A bundle whose sub mods are all off is off too.
---@return string[] ids every mod's id in the player's order
---@return table<string, table> enabled the mods that are not off by id
---@return string[] visible ids of the enabled mods that are shown, in order
function ModFolderTree:listModsByStatus()
  local nodes = self:getModNodesInOrder()
  local ids = {}
  local enabled = {}
  for _, node in ipairs(nodes) do
    ids[#ids + 1] = node.mod.id
    if self:getEffectiveStatus(node) ~= "off" then
      enabled[node.mod.id] = node.mod
    end
  end

  for _, node in ipairs(nodes) do
    local subIds = node.mod.subIds
    if enabled[node.mod.id] and subIds and #subIds > 0 then
      if tableUtils.trueForAll(subIds, function(subId) return enabled[subId] == nil end) then
        logger.info("Disabling " .. node.mod.id .. " because all its sub mods have been disabled")
        enabled[node.mod.id] = nil
      end
    end
  end

  local visible = {}
  for _, node in ipairs(nodes) do
    if enabled[node.mod.id] and self:getEffectiveStatus(node) == "shown" then
      visible[#visible + 1] = node.mod.id
    end
  end

  return ids, enabled, visible
end

-- Returns the lists of listModsByStatus, enabling every mod if all are off and showing every enabled mod if none is
-- shown, so there is always something to pick
---@return string[] ids every mod's id in the player's order
---@return table<string, table> enabled the mods in use by id
---@return string[] visible ids of the mods offered in selection, in order
function ModFolderTree:listModsByStatusWithFallbacks()
  local ids, enabled, visible = self:listModsByStatus()
  local nodes = self:getModNodesInOrder()
  if next(enabled) == nil then
    for _, node in ipairs(nodes) do
      enabled[node.mod.id] = node.mod
    end
  end
  if #visible == 0 then
    for _, node in ipairs(nodes) do
      if enabled[node.mod.id] then
        visible[#visible + 1] = node.mod.id
      end
    end
  end
  return ids, enabled, visible
end

-- Saves the settings and mirrors the mods that are off into the type's blacklist.txt
function ModFolderTree:saveAndMirrorBlacklist()
  self.settings:save()

  local offIds = {}
  local installedIds = {}
  for _, node in ipairs(self:getModNodesInOrder()) do
    installedIds[node.mod.id] = true
    if self:getEffectiveStatus(node) == "off" then
      offIds[#offIds + 1] = node.mod.id
    end
  end
  self.settings:writeBlacklist(self.saveDir, offIds, installedIds)
end

-- Returns true if a bundle that was enabled got disabled only because its last enabled sub mod went off
---@param tree ModFolderTree
---@param enabledBefore table<string, table>
---@param enabledAfter table<string, table>
---@return boolean
local function turnsOffABundleThroughItsSubMods(tree, enabledBefore, enabledAfter)
  for id, mod in pairs(enabledBefore) do
    if not enabledAfter[id] and tree:getEffectiveStatus(tree:getNodeOfMod(mod)) ~= "off" then
      return true
    end
  end
  return false
end

-- Sets the status of a folder or mod and saves it.
-- Refuses a change that leaves nothing shown or turns off the last enabled sub mod of an enabled bundle.
---@param node ModFolderNode
---@param status ModStatus
---@return boolean changed
function ModFolderTree:setStatusAndSave(node, status)
  local previousEntry = self.settings:copyEntry(self.saveDir, node.key)
  local _, enabledBefore = self:listModsByStatus()

  self.settings:setStatus(self.saveDir, node.key, status)
  local _, enabledAfter, visibleAfter = self:listModsByStatus()

  if #visibleAfter == 0 or turnsOffABundleThroughItsSubMods(self, enabledBefore, enabledAfter) then
    self.settings:restoreEntry(self.saveDir, node.key, previousEntry)
    return false
  end

  self:saveAndMirrorBlacklist()
  return true
end

-- Moves a folder or mod among the children of its folder by offset places and saves the folder's order
---@param node ModFolderNode
---@param offset integer -1 to move up, 1 to move down
---@return boolean moved false if the node is already first or last
function ModFolderTree:moveWithinFolderAndSave(node, offset)
  if not node.parent then
    return false
  end
  local siblings = self:getOrderedChildren(node.parent)
  local index = tableUtils.indexOf(siblings, node)
  local target = index + offset
  if target < 1 or target > #siblings then
    return false
  end

  local names = {}
  for i, sibling in ipairs(siblings) do
    names[i] = sibling.name
  end
  names[index], names[target] = names[target], names[index]

  self.settings:setOrder(self.saveDir, node.parent.key, names, self:getOwnStatus(node.parent))
  self:saveAndMirrorBlacklist()
  return true
end

return ModFolderTree
