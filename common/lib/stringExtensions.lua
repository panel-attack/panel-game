local utf8 = require("common.lib.utf8Additions")

---@param str string
function string.toCharTable(str)
  local t = {}
  for _, codePoint in utf8.codes(str) do
    local character = utf8.char(codePoint)
    t[#t+1] = character
  end
  return t
end