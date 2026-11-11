local utf8 = require("common.lib.utf8Additions")

-- The rules a player name has to follow to log in, shared so the client can check a name before the server refuses it
local playerName = {}

playerName.LENGTH_LIMIT = 16

-- returns whether the name may be used to log in, and if not, why
---@param name string?
---@return boolean isValid
---@return string? reason English explanation of why the name is not allowed, nil if it is
function playerName.validate(name)
  if not name or name == "" then
    return false, "Name cannot be blank"
  elseif string.lower(name) == "anonymous" then
    return false, 'Username cannot be "anonymous"'
  elseif name:lower():match("d+e+f+a+u+l+t+n+a+m+e?") then
    return false, 'Username cannot be "defaultname" or a variation of it'
  elseif name:find("[^_%w]") then
    return false, "Usernames are limited to alphanumeric and underscores"
  elseif utf8.len(name) > playerName.LENGTH_LIMIT then
    return false, "The name length limit is " .. playerName.LENGTH_LIMIT .. " characters"
  end

  return true
end

return playerName
