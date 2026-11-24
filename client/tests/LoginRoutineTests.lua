local LoginRoutine = require("client.src.network.LoginRoutine")

-- A tcp client that connects at once and answers each request with the next of replies, in order
---@param replies table[]
local function fakeTcpClient(replies)
  local tcpClient = {}
  function tcpClient:connectToServer()
    return true
  end
  function tcpClient:sendRequest()
    local reply = table.remove(replies, 1)
    return {tryGetValue = function() return "received", reply end}
  end
  function tcpClient:resetNetwork() end
  return tcpClient
end

-- Runs the login routine against replies to the end and returns its result, putting back the server the game was connected to
---@param replies table[]
---@return table result
local function loginWith(replies)
  local connectedIp, connectedPort = GAME.connected_server_ip, GAME.connected_server_port
  local routine = LoginRoutine(fakeTcpClient(replies), "127.0.0.1", 49569)
  local ok, done, result = pcall(routine.progress, routine)
  GAME.connected_server_ip, GAME.connected_server_port = connectedIp, connectedPort
  assert(ok, done)
  assert(done, "the login should finish once every reply is received")
  return result
end

local function testServerNoticeIsAppendedToTheLoginMessage()
  local result = loginWith({
    {versionCompatible = true},
    {login_successful = true, server_notice = "Maintenance tonight\\nBack soon"},
  })

  assert(result.loggedIn)
  local expected = loc("lb_welcome_back", config.name) .. "\nMaintenance tonight\nBack soon"
  assert(result.message == expected, "expected the message\n" .. expected .. "\nbut got\n" .. result.message)
end

testServerNoticeIsAppendedToTheLoginMessage()
