local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local FileUtils = require("client.src.FileUtils")

---@class SfxGroup
---@field path string
---@field pattern string The pattern to search for as plain text; luaregex disabled
---@field separator string the separator by which alternative copies separate their index, default ""
---@field matchingFiles string[] the files that got matched during the load process of the SfxGroup
local SfxGroup = class(
function(self, path, pattern, separator)
  self.path = path
  self.pattern = pattern
  self.separator = separator or ""
end)

function SfxGroup:load(yields)
  local files = FileUtils.getFilteredDirectoryItems(self.path, "file")
  self.matchingFiles = FileUtils.getMatchingFiles(files, self.pattern, FileUtils.SUPPORTED_SOUND_FORMATS, self.separator)
end

return SfxGroup