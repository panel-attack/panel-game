require("server.server_globals")
local Connection = require("server.Connection")
require("server.PlayerBase")
local Server = require("server.server")

local testServer = {nameToConnectionIndex = {}}

testServer.insertBan = function (ip, reason, completionTime)
  return {} -- might need more details later like reason and completiontime
end


testServer.playerbase = Playerbase("Test", nil)
testServer.playerbase:addPlayer(1, "Jerry")
testServer.playerbase:addPlayer(2, "Ben")

setmetatable(testServer, Server)

function testLoginInvalidName()
  -- blank name
  local approved, _ = testServer:canLogin(2, nil, "1.1.1.1", ENGINE_VERSION)
  assert(not approved)

  -- anonymous
  approved, _ = testServer:canLogin(2, "anonymous", "1.1.1.1", ENGINE_VERSION)
  assert(not approved)

  -- Anonymous
  approved, _ = testServer:canLogin(2, "Anonymous", "1.1.1.1", ENGINE_VERSION)
  assert(not approved)

  -- defaultname
  approved, _ = testServer:canLogin(2, "defaultnam", "1.1.1.1", ENGINE_VERSION)
  assert(not approved)

  -- only alpha numeric and underscores
  approved, _ = testServer:canLogin(2, "L$3t", "1.1.1.1", ENGINE_VERSION)
  assert(not approved)

  -- NAME_LENGTH_LIMIT
  approved, _ = testServer:canLogin(2, "testtesttesttesttesttest", "1.1.1.1", ENGINE_VERSION)
  assert(not approved)
end

testLoginInvalidName()

function testLoginInvalidUserID()
  -- no user ID
  local approved, _ = testServer:canLogin(nil, "Bob", "1.1.1.1", ENGINE_VERSION)
  assert(not approved)

  -- asking for new user, but name alread taken
  approved, _ = testServer:canLogin("need a new user id", "Jerry", "1.1.1.1", ENGINE_VERSION)
  assert(not approved)

  -- fake ID
  approved, _ = testServer:canLogin(42, "Bob", "1.1.1.1", ENGINE_VERSION)
  assert(not approved)

  -- have account, name taken and doesn't match ID
  approved, _ = testServer:canLogin(2, "Jerry", "1.1.1.1", ENGINE_VERSION)
  assert(not approved)
end

testLoginInvalidUserID()

function testLoginDeniedForInvalidVersion()
  local approved, _ = testServer:canLogin(2, "BEN", "1.1.1.1", "XXX")
  assert(not approved)
end

testLoginDeniedForInvalidVersion()

function testLoginAllowed()
  -- can login if have account and username case changed
  local approved, _ = testServer:canLogin(2, "BEN", "1.1.1.1", ENGINE_VERSION)
  assert(approved)

  -- can login if have account and changes name
  approved, _ = testServer:canLogin(2, "Jeremy", "1.1.1.1", ENGINE_VERSION)
  assert(approved)

  -- can login if have account and name isn't changed
  approved, _ = testServer:canLogin(2, "Ben", "1.1.1.1", ENGINE_VERSION)
  assert(approved)

  -- can login with new account if name not taken
  approved, _ = testServer:canLogin("need a new user id", "Joseph", "1.1.1.1", ENGINE_VERSION)
  assert(approved)
end

testLoginAllowed()