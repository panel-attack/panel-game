local class = require("common.lib.class")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local fileUtils = require("client.src.FileUtils")
local json = require("common.lib.dkjson")

-- save directories of the mod types the file holds a section for
local SAVE_DIRS = {"characters", "stages", "panels"}

-- Returns an empty section per mod type, marked as objects so an empty one is still written as {}
---@return table<string, table<string, ModSettingsEntry>>
local function emptyEntries()
  local entries = {}
  for _, saveDir in ipairs(SAVE_DIRS) do
    entries[saveDir] = setmetatable({}, {__jsontype = "object"})
  end
  return entries
end

---@alias ModStatus "off" | "hidden" | "shown"

---@class ModSettingsEntry
---@field status ModStatus? the status set for the folder or mod, the default applies without one
---@field order string[]? names of the folder's children in the order they are listed

-- The player's mod management choices, kept in one versioned file in the save directory.
-- Entries are keyed by folder path relative to the mod type's save directory, "@builtin/..." for bundled mods and ""
-- for the top level; see ModFolderTree.settingsKeyForPath. Entries for folders that no longer exist are kept untouched.
---@class ModSettings
---@field directory string folder of the save directory the file and blacklists live in, "" for the top level
---@field entries table<string, table<string, ModSettingsEntry>> entries per mod type save directory
---@field isWritable boolean false when the file comes from a newer build: it is ignored and nothing is written, blacklists included
---@field isFromFile boolean if the entries were read from the file
---@overload fun(directory: string?): ModSettings
local ModSettings = class(
---@param self ModSettings
function(self, directory)
  self.directory = directory or ""
  self.entries = emptyEntries()
  self.isWritable = true
  self.isFromFile = false
end)

ModSettings.VERSION = 1
ModSettings.FILE_NAME = "modSettings.json"
ModSettings.BROKEN_FILE_NAME = "modSettings.broken.json"
ModSettings.SAVE_DIRS = SAVE_DIRS
-- save directories of the mod types older builds read a blacklist.txt for
ModSettings.BLACKLIST_SAVE_DIRS = {characters = true, stages = true}
-- statuses from lowest to highest; a folder caps everything inside it at its own status
ModSettings.STATUS_RANK = {off = 1, hidden = 2, shown = 3}

-- Returns the lower of two statuses
---@param a ModStatus
---@param b ModStatus
---@return ModStatus
function ModSettings.lowerStatus(a, b)
  if ModSettings.STATUS_RANK[a] < ModSettings.STATUS_RANK[b] then
    return a
  end
  return b
end

-- Returns the path of a file in the settings' directory
---@param fileName string
---@return string
function ModSettings:pathTo(fileName)
  if self.directory == "" then
    return fileName
  end
  return self.directory .. "/" .. fileName
end

-- Returns the entry with every field that does not fit the format left out, or nil if nothing is left
---@param entry any
---@return ModSettingsEntry?
local function sanitizeEntry(entry)
  if type(entry) ~= "table" then
    return nil
  end

  local clean = {}
  if ModSettings.STATUS_RANK[entry.status] then
    clean.status = entry.status
  end
  if type(entry.order) == "table" then
    clean.order = {}
    for _, name in ipairs(entry.order) do
      if type(name) == "string" then
        clean.order[#clean.order + 1] = name
      end
    end
  end

  if next(clean) == nil then
    return nil
  end
  return clean
end

-- Moves a file that cannot be used out of the way so the next save starts fresh without losing it.
-- The file stays where it is if the copy cannot be written.
---@param content string
---@param reason string
function ModSettings:setAsideBrokenFile(content, reason)
  local path = self:pathTo(ModSettings.FILE_NAME)
  local written, err = love.filesystem.write(self:pathTo(ModSettings.BROKEN_FILE_NAME), content)
  if not written then
    logger.warn(path .. " " .. reason .. " and could not be kept as " .. ModSettings.BROKEN_FILE_NAME .. ": " .. tostring(err))
    return
  end
  logger.warn(path .. " " .. reason .. ", keeping it as " .. ModSettings.BROKEN_FILE_NAME)
  love.filesystem.remove(path)
end

-- Reads one mod type's section of the file into the entries, leaving out what does not fit the format
---@param entries table<string, ModSettingsEntry>
---@param section any
local function readModTypeSection(entries, section)
  if type(section) ~= "table" then
    return
  end
  for key, entry in pairs(section) do
    if type(key) == "string" then
      entries[key] = sanitizeEntry(entry)
    end
  end
end

-- Reads the file; a missing, broken or newer file leaves no entries
function ModSettings:load()
  self.entries = emptyEntries()
  self.isWritable = true
  self.isFromFile = false

  local path = self:pathTo(ModSettings.FILE_NAME)
  if not fileUtils.exists(path) then
    return
  end

  local content = love.filesystem.read(path)
  local data = json.decode(content)
  if type(data) ~= "table" then
    self:setAsideBrokenFile(content, "could not be read")
    return
  elseif type(data.version) ~= "number" then
    self:setAsideBrokenFile(content, "has no version")
    return
  elseif data.version > ModSettings.VERSION then
    logger.warn(path .. " is from a newer version of the game, ignoring it and saving no mod settings")
    self.isWritable = false
    return
  end

  for _, saveDir in ipairs(ModSettings.SAVE_DIRS) do
    readModTypeSection(self.entries[saveDir], data[saveDir])
  end
  self.isFromFile = true
end

-- Returns the entries of one mod type by folder key
---@param saveDir string
---@return table<string, ModSettingsEntry>
function ModSettings:getEntries(saveDir)
  return self.entries[saveDir]
end

-- Returns a copy of the entry for the key that later changes leave alone, to put back with restoreEntry
---@param saveDir string
---@param key string
---@return ModSettingsEntry?
function ModSettings:copyEntry(saveDir, key)
  local entry = self.entries[saveDir][key]
  return entry and shallowcpy(entry)
end

-- Returns the status set for the key, nil if none is set
---@param saveDir string
---@param key string
---@return ModStatus?
function ModSettings:getStatus(saveDir, key)
  local entry = self.entries[saveDir][key]
  return entry and entry.status
end

-- Sets the status for the key, keeping its order
---@param saveDir string
---@param key string
---@param status ModStatus
function ModSettings:setStatus(saveDir, key, status)
  local entry = self.entries[saveDir][key] or {}
  entry.status = status
  self.entries[saveDir][key] = entry
end

-- Puts back an entry exactly as it was before, used to undo a refused change
---@param saveDir string
---@param key string
---@param entry ModSettingsEntry?
function ModSettings:restoreEntry(saveDir, key, entry)
  self.entries[saveDir][key] = entry
end

-- Sets the order of the folder's children for the key, keeping its status
---@param saveDir string
---@param key string
---@param order string[] names of the folder's children
---@param currentStatus ModStatus status to record for a folder that has none yet, so every entry holds one
function ModSettings:setOrder(saveDir, key, order, currentStatus)
  local entry = self.entries[saveDir][key] or {}
  entry.status = entry.status or currentStatus
  entry.order = order
  self.entries[saveDir][key] = entry
end

-- Writes the file straight over the old one unless it belongs to a newer build
function ModSettings:save()
  if not self.isWritable then
    return
  end

  -- entry keys are written sorted so a save only changes the lines that changed
  local entryKeys = {}
  ---@type table<string, any>
  local data = {version = ModSettings.VERSION}
  for _, saveDir in ipairs(ModSettings.SAVE_DIRS) do
    data[saveDir] = self.entries[saveDir]
    for key, _ in pairs(self.entries[saveDir]) do
      entryKeys[#entryKeys + 1] = key
    end
  end
  table.sort(entryKeys)
  local keyOrder = {"version", "status", "order"}
  tableUtils.appendToList(keyOrder, ModSettings.SAVE_DIRS)
  tableUtils.appendToList(keyOrder, entryKeys)

  fileUtils.writeJson(self.directory, ModSettings.FILE_NAME, data, {indent = true, pretty = true, keyorder = keyOrder})
  self.isFromFile = true
end

-- Returns the ids in the mod type's blacklist.txt
---@param saveDir string
---@return string[] ids listed in the type's blacklist.txt
function ModSettings:readBlacklist(saveDir)
  local ids = {}
  local path = self:pathTo(saveDir .. "/blacklist.txt")
  if fileUtils.exists(path) then
    for line in love.filesystem.lines(path) do
      if line ~= "" then
        ids[#ids + 1] = line
      end
    end
  end
  return ids
end

-- Turns the ids in blacklist.txt into off entries while there is no file yet, and not when a newer build's file is ignored
---@param saveDir string
---@param keysById table<string, string> folder key of each installed mod by id
function ModSettings:importBlacklist(saveDir, keysById)
  if self.isFromFile or not self.isWritable then
    return
  end
  for _, id in ipairs(self:readBlacklist(saveDir)) do
    local key = keysById[id]
    if key and not self.entries[saveDir][key] then
      self.entries[saveDir][key] = {status = "off"}
    end
  end
end

-- Mirrors the mods that are off into blacklist.txt so older builds sharing the save directory leave them off too.
-- Ids of mods that are not installed stay listed. Nothing is written while a newer build's file is ignored.
---@param saveDir string
---@param offIds string[] ids of the installed mods that are off
---@param installedIds table<string, boolean> ids of every installed mod
function ModSettings:writeBlacklist(saveDir, offIds, installedIds)
  if not self.isWritable or not ModSettings.BLACKLIST_SAVE_DIRS[saveDir] then
    return
  end
  local lines = {}
  for _, id in ipairs(self:readBlacklist(saveDir)) do
    if not installedIds[id] then
      lines[#lines + 1] = id
    end
  end
  for _, id in ipairs(offIds) do
    lines[#lines + 1] = id
  end
  fileUtils.write(self:pathTo(saveDir), "blacklist.txt", table.concat(lines, "\n"))
end

return ModSettings
