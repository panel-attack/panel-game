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

function SfxGroup.getMatchingFiles(files, pattern, separator)
  local stringLen = string.len(pattern)
  local matchedFiles = tableUtils.filter(files,
  function(file)
    local startIndex, endIndex = string.find(file, pattern, nil, true)
    if not startIndex then
      return false
    elseif startIndex > 1 then
      -- this means the name is prefixed with something else
      return false
    else
      local goodExtension
      -- this check is doubly good because it enforces lower case extensions even on windows
      for i, extension in ipairs(FileUtils.SUPPORTED_SOUND_FORMATS) do
        local length = extension:len()
        if file:sub(-length) == extension then
          goodExtension = extension
          break
        end
      end
      if not goodExtension then
        return false
      else
        -- now check for actual exact matching:
        local middlePart = file:sub(- goodExtension:len()):sub(1, stringLen)
        if middlePart:len() == 0 then
          -- this is just the exact pattern + file extension
          return true
        else
          local sepLen = separator:len()
          if middlePart:sub(sepLen) ~= separator then
            return false
          else
            local numberPart = middlePart:sub(sepLen + 1)
            if string.match(numberPart, "%d+") == numberPart and tonumber(numberPart) then
              -- there are really only digits that form a number in the number part
              return true
            else
              return false
            end
          end
        end
      end
    end
  end)

  return matchedFiles
end

function SfxGroup:load(yields)
  local files = FileUtils.getFilteredDirectoryItems(self.path, "file")
  self.matchingFiles = SfxGroup.getMatchingFiles(files, self.pattern, self.separator)
end

return SfxGroup