local Connection = require("server.Connection")
local NetworkProtocol = require("common.network.NetworkProtocol")

local PING = NetworkProtocol.serverMessageTypes.ping.prefix
local PING_REPLY = NetworkProtocol.clientMessageTypes.acknowledgedPing.prefix

-- A socket that hands over whatever the test put in `unread` and accepts every send
local function fakeSocket()
  local socket = {unread = ""}
  function socket:receive()
    local data = self.unread
    self.unread = ""
    return nil, "timeout", data
  end
  function socket:send(message)
    return #message
  end
  function socket:getpeername()
    return "127.0.0.1"
  end
  return socket
end

local function connectionWithClock()
  local clock = {now = 100}
  local socket = fakeSocket()
  local connection = Connection(socket, 1, function()
    return clock.now
  end)
  return connection, clock, socket
end

local function queuedPingCount(connection)
  local count = 0
  while connection.outgoingMessageQueue:len() > 0 do
    if connection.outgoingMessageQueue:pop() == PING then
      count = count + 1
    end
  end
  return count
end

local function testTheServerPingsEveryIntervalWhileTheClientKeepsTalking()
  local connection, clock, socket = connectionWithClock()
  connection:update(100, false, false)
  assert(queuedPingCount(connection) == 1, "a new connection should be pinged right away")

  clock.now = 100 + Connection.PING_INTERVAL - 0.1
  socket.unread = NetworkProtocol.markedMessageForTypeAndBody("J", "{}")
  connection:update(101, true, false)
  assert(queuedPingCount(connection) == 0, "the next ping should wait for the interval")

  clock.now = 100 + Connection.PING_INTERVAL
  socket.unread = NetworkProtocol.markedMessageForTypeAndBody("J", "{}")
  connection:update(102, true, false)
  assert(queuedPingCount(connection) == 1, "a talking client should still be pinged every interval")
end

testTheServerPingsEveryIntervalWhileTheClientKeepsTalking()

local function testAPingReplyIsARoundTripSample()
  local connection, clock, socket = connectionWithClock()
  connection:update(100, false, false)

  clock.now = 100.0625
  socket.unread = PING_REPLY
  connection:update(100, true, false)

  local sample = connection.pingStats.latest
  assert(sample == 62.5, "a reply 62.5 ms after the ping should be a 62.5 ms sample, got " .. tostring(sample))
end

testAPingReplyIsARoundTripSample()

local function testRepliesAreMatchedToPingsInOrder()
  local connection, clock, socket = connectionWithClock()
  connection:update(100, false, false)
  clock.now = 102
  connection:update(102, false, false)

  clock.now = 102.25
  socket.unread = PING_REPLY .. PING_REPLY
  connection:update(102, true, false)

  local samples = connection.pingStats.recent.content
  assert(samples[1] == 2250, "the first reply should answer the first ping, got " .. tostring(samples[1]))
  assert(samples[2] == 250, "the second reply should answer the second ping, got " .. tostring(samples[2]))
end

testRepliesAreMatchedToPingsInOrder()

local function testAReplyWithoutAPingIsIgnored()
  local connection, _, socket = connectionWithClock()
  socket.unread = PING_REPLY
  connection:update(100, true, false)

  assert(connection.pingStats.latest == nil, "a reply nobody asked for should not be a sample")
end

testAReplyWithoutAPingIsIgnored()

