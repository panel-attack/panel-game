local class = require("common.lib.class")
local FileUtils = require("client.src.FileUtils")

---@param filename1 string
---@param filename2 string
---@return string # the filename that won the collision
local function resolveCollision(filename1, filename2)
  -- TODO: establish a consistent priority by something more coherent than string sort?
  -- e.g. going by extension, preferring lossless over lossy, better compression over worse
  -- could also prefer leading 0 over non-leading etc.
  return filename1
end

---@return string[]
local function indexMatchingFiles(matchingFiles, pattern, separator)
  table.sort(matchingFiles)
  local indexed = {}
  local patternLength = pattern:len()
  local separatorLength = separator:len()
  local index
  for i, filename in ipairs(matchingFiles) do
    local cut = FileUtils.getFileNameWithoutExtension(filename)
    cut = cut:sub(patternLength + separatorLength + 1)
    if cut:len() == 0 then
      index = 1
    else
      index = tonumber(cut)
    end
    ---@cast index integer
    if not indexed[index] then
      indexed[index] = filename
    else
      -- oh no, we have a collision
      indexed[index] = resolveCollision(indexed[index], filename)
    end
  end

  return indexed
end

-- A FileGroup is a group of files matching a certain pattern
-- beyond the pattern they are in particular numbered with integers
-- creating a FileGroup makes all file names belonging to the group available in matchingFiles
-- a concrete assignment of indices has happened in indexedFiles; \n
-- in the process, files that have the same index will get eliminated until only one is left for each index
---@class FileGroup
---@field path string
---@field pattern string The pattern to search for as plain text; luaregex disabled
---@field validExtensions string[]
---@field separator string the separator by which alternative copies separate their index, default ""
---@field matchingFiles string[] the files that got matched during the load process of the FileGroup
---@field indexedFiles string[] the files indexed by their suffix; only one file per index guaranteed
---@overload fun(path: string, pattern: string, validExtensions: string[], separator: string?): FileGroup
local FileGroup = class(
function(self, path, pattern, validExtensions, separator)
  self.path = path
  self.pattern = pattern
  self.validExtensions = validExtensions
  self.separator = separator or ""

  local files = FileUtils.getFilteredDirectoryItems(self.path, "file")
  self.matchingFiles = FileUtils.getMatchingFiles(files, self.pattern, self.validExtensions, self.separator)
  self.indexedFiles = indexMatchingFiles(self.matchingFiles, self.pattern, self.separator)
end)

return FileGroup