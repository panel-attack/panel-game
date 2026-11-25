local logger = require("common.lib.logger")

local FILENAME = "client/assets/localization.csv"

-- Every row of the localization file has a key, a context and one cell per language,
-- so an unquoted comma can't shift a row's translations into the next language's column
local function testEveryRowHasOneCellPerLanguage()
  local header
  local leftover
  local tokens = {}
  for line in love.filesystem.lines(FILENAME) do
    local lineTokens
    lineTokens, leftover = Localization.csv_line(line, leftover)
    if not header then
      header = lineTokens
    else
      -- a quoted cell spanning lines finishes on a later line, which starts with that cell's remainder
      for _, token in ipairs(lineTokens) do
        tokens[#tokens + 1] = token
      end
      if not leftover then
        assert(#tokens == #header, "Row " .. tokens[1] .. " has " .. #tokens .. " cells instead of " .. #header)
        tokens = {}
      end
    end
  end
  logger.trace("passed test testEveryRowHasOneCellPerLanguage")
end

testEveryRowHasOneCellPerLanguage()
