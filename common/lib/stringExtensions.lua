local utf8 = require("common.lib.utf8Additions")

---@param self string
---@return string[]
function string.toCharTable(self)
  local t = {}
  for _, codePoint in utf8.codes(self) do
    local character = utf8.char(codePoint)
    t[#t+1] = character
  end
  return t
end

---@param inputstr string
---@param separator string? can be a pattern
---@return string[]?
---@diagnostic disable-next-line: duplicate-set-field
function string.split(inputstr, separator)
  separator = separator or "%s"
  local t = {}
  for field, s in string.gmatch(inputstr, "([^" .. separator .. "]*)(" .. separator .. "?)") do
    t[#t+1] = field
    if s == "" then
      return t
    end
  end
end