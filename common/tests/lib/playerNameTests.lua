local playerName = require("common.lib.playerName")

local function assertInvalid(name, expectedReason)
  local isValid, reason = playerName.validate(name)
  assert(not isValid, tostring(name) .. " should not be a valid name")
  assert(reason == expectedReason, tostring(name) .. " should be refused with '" .. expectedReason .. "' but got '" .. tostring(reason) .. "'")
end

local function assertValid(name)
  local isValid, reason = playerName.validate(name)
  assert(isValid, name .. " should be a valid name but was refused with '" .. tostring(reason) .. "'")
  assert(reason == nil, name .. " should not come with a reason")
end

assertInvalid(nil, "Name cannot be blank")
assertInvalid("", "Name cannot be blank")
assertInvalid("anonymous", 'Username cannot be "anonymous"')
assertInvalid("Anonymous", 'Username cannot be "anonymous"')
assertInvalid("defaultname", 'Username cannot be "defaultname" or a variation of it')
assertInvalid("DeFaultNam", 'Username cannot be "defaultname" or a variation of it')
assertInvalid("ddeeffaauullttnnaamm", 'Username cannot be "defaultname" or a variation of it')
assertInvalid("L$3t", "Usernames are limited to alphanumeric and underscores")
assertInvalid("two words", "Usernames are limited to alphanumeric and underscores")
assertInvalid(string.rep("a", playerName.LENGTH_LIMIT + 1), "The name length limit is " .. playerName.LENGTH_LIMIT .. " characters")

assertValid("JamBox")
assertValid("player_1")
assertValid("anonymous_fan")
assertValid(string.rep("a", playerName.LENGTH_LIMIT))
