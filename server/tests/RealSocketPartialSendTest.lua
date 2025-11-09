-- Test using real sockets to demonstrate partial send bugs in both Connection and TcpClient are fixed
-- This test creates actual TCP server and client connections on localhost
--
-- When a partial send occurs on a socket the partialBytesSent were LOST - not tracked, not queued, not retried
-- ## TEST STRATEGY ##
-- To reproduce these bugs:
--   1. Fill TCP buffer by sending large amounts of data
--   2. Read SLOWLY on receiving side to create backpressure
--   3. Trigger a partial send (socket:send returns nil, "timeout", X where X > 0)
--   4. Verify data is not corrupted or lost on the receiving side
--

json = require("common.lib.dkjson")
local Connection = require("server.Connection")
require("client.src.server_queue")
local TcpClient = require("client.src.network.TcpClient")
local NetworkProtocol = require("common.network.NetworkProtocol")
local socket = require("socket")
local logger = require("common.lib.logger")

local SEND_ATTEMPTS_MAX = 100
local READ_TIMEOUT = 9 -- 10 seconds will make connection fail with no ping
local SLOW_READ_SIZE = 100 -- bytes per read
local SLEEP_INTERVAL = 0.0001 -- seconds
local FAST_READ_SLEEP = 0.0001 -- seconds
local RETRY_MAX_ATTEMPTS = 50000
local MESSAGE_COUNT = 50
local LARGE_MESSAGE_PAD_COUNT = 100

-- Helper to create a TCP server on localhost
local function createLocalServer()
  local server = socket.tcp()
  server:bind("127.0.0.1", 0) -- Bind to any available port
  server:listen(1)
  server:settimeout(5) -- 5 second timeout for accept

  local ip, port = server:getsockname()
  logger.trace("Server listening on " .. ip .. ":" .. port)

  return server, ip, port
end

-- Helper to create a TcpClient and connect to server
local function createTcpClient(ip, port)
  local tcpClient = TcpClient()
  local success = tcpClient:connectToServer(ip, port)
  if not success then
    error("Failed to connect TcpClient to " .. ip .. ":" .. port)
  end
  logger.trace("TcpClient connected to " .. ip .. ":" .. port)
  return tcpClient
end

-- Helper to create large message with padding data
local function createLargeMessage()
  local paddingData = {}
  for i = 1, LARGE_MESSAGE_PAD_COUNT do
    paddingData[i] = {
      index = i,
      data = "This is padding data to make the message larger and increase the chance of partial sends. " ..
             "We need to fill the TCP buffer quickly with fewer messages, so each message needs to be substantial. " ..
             "Adding more text here to ensure we reach the buffer limits and trigger partial send scenarios. " ..
             "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore."
    }
  end
  return paddingData
end

-- Helper to process and validate JSON messages from a data buffer
-- Returns messageCount, corruptedCount
local function processMessages(dataBuffer, messageTypePrefix)
  local messageCount = 0
  local corruptedCount = 0

  while true do
    local msgType, message, remaining = NetworkProtocol.getMessageFromString(dataBuffer, true)
    if not msgType then
      break -- No more complete messages
    end

    -- Only process JSON messages
    if msgType == messageTypePrefix then
      messageCount = messageCount + 1

      local decoded = json.decode(message)

      if not decoded then
        corruptedCount = corruptedCount + 1
        logger.error(" Message #" .. messageCount .. " - JSON decode returned nil!")
        logger.error("  Raw data preview: " .. message:sub(1, 100):gsub("\n", "\\n"))
        break
      end
    end

    dataBuffer = remaining
  end

  return messageCount, corruptedCount, dataBuffer
end

-- Test the partial send bug with real sockets (Connection server->client)
local function testRealSocketPartialSend()
  logger.info("Running testRealSocketPartialSend test")

  -- Setup: Create server and establish connection
  local serverSocket, ip, port = createLocalServer()
  local tcpClient = createTcpClient(ip, port)
  local serverClientSocket, err = serverSocket:accept()
  if not serverClientSocket then
    error("Failed to accept connection: " .. (err or "unknown error"))
  end
  serverClientSocket:settimeout(0)
  local connection = Connection(serverClientSocket, 1)

  -- Create and queue large messages
  local paddingData = createLargeMessage()
  local largeMessage = {
    messageType = NetworkProtocol.serverMessageTypes.jsonMessage,
    messageText = {
      type = "settingsUpdate",
      content = {
        padding = paddingData
      },
      sender = "player",
      senderId = 1
    }
  }

  for _ = 1, MESSAGE_COUNT do
    connection:sendJson(largeMessage)
  end

  -- Phase 1: Send while reading SLOWLY to trigger partial send
  local sendAttempts = 0
  local partialSendDetected = false

  while sendAttempts < SEND_ATTEMPTS_MAX and not partialSendDetected do
    sendAttempts = sendAttempts + 1

    local success = connection:update(os.time(), false, true)
    if not success then
      assert(false, "couldn't keep connection open for test")
      break
    end

    -- Read slowly to create backpressure
    if tcpClient.socket then
      local chunk, _, partial = tcpClient.socket:receive(SLOW_READ_SIZE)
      if chunk or partial then
        tcpClient.data = tcpClient.data .. (chunk or partial)
      end
    end

    if connection.sendRetryCount and connection.sendRetryCount > 0 then
      logger.trace("✓ Partial send detected! (sendRetryCount = " .. connection.sendRetryCount .. ")")
      logger.trace("  Messages still in queue: " .. connection.outgoingMessageQueue:len())
      logger.trace("  Client has buffered: " .. #tcpClient.data .. " bytes so far")
      partialSendDetected = true
      break
    end

    socket.sleep(SLEEP_INTERVAL)
  end
  assert(partialSendDetected)

  -- Phase 2: Read fast to allow retry to succeed
  local retryAttempts = 0
  local resendSucceeded = false

  while retryAttempts < RETRY_MAX_ATTEMPTS do
    retryAttempts = retryAttempts + 1
    local sendRetryCountBefore = connection.sendRetryCount

    connection:update(os.time(), false, true)
    tcpClient:readSocket()

    if sendRetryCountBefore > 0 and connection.sendRetryCount == 0 then
      resendSucceeded = true
      break
    end

    socket.sleep(SLEEP_INTERVAL)
  end
  assert(resendSucceeded)

  logger.trace("Retry phase completed. sendRetryCount = " .. (connection.sendRetryCount or 0))
  logger.trace("Client buffer size: " .. #tcpClient.data .. " bytes\n")

  -- Phase 3: Read remaining data and validate messages
  local startTime = socket.gettime()
  local messageCount = 0
  local corruptedCount = 0

  while socket.gettime() - startTime < READ_TIMEOUT and corruptedCount == 0 do
    connection:update(os.time(), false, true)

    if not tcpClient:readSocket() then
      assert(false, "couldn't keep connection open for test")
    end

    local newMessages, newCorrupted
    newMessages, newCorrupted, tcpClient.data = processMessages(
      tcpClient.data,
      NetworkProtocol.serverMessageTypes.jsonMessage.prefix
    )
    messageCount = messageCount + newMessages
    corruptedCount = corruptedCount + newCorrupted

    if messageCount == MESSAGE_COUNT or corruptedCount > 0 then
      logger.info("Ending early")
      break
    end

    socket.sleep(FAST_READ_SLEEP)
  end

  assert(messageCount > 0 and corruptedCount == 0)
  logger.trace("Total messages received: " .. messageCount)
  logger.trace("Successfully decoded: " .. (messageCount - corruptedCount))
  logger.trace("Corrupted messages: " .. corruptedCount)
  logger.trace("TcpClient buffer remaining: " .. #tcpClient.data .. " bytes")

  -- Cleanup
  connection:close()
  tcpClient:resetNetwork()
  serverSocket:close()
end

-- Test the TcpClient partial send bug (TcpClient client->server)
local function testTcpClientPartialSend()
  logger.info("Running testTcpClientPartialSend test")

  -- Setup: Create server and establish connection
  local serverSocket, ip, port = createLocalServer()
  local tcpClient = createTcpClient(ip, port)
  local serverClientSocket, err = serverSocket:accept()
  if not serverClientSocket then
    error("Failed to accept connection: " .. (err or "unknown error"))
  end
  serverClientSocket:settimeout(0)

  -- Create large message to send from client to server
  local paddingData = createLargeMessage()
  local largeMessage = {
    type = "chatMessage",
    content = {
      padding = paddingData
    },
    sender = "player",
    senderId = 1
  }
  local messageString = NetworkProtocol.markedMessageForTypeAndBody(
    NetworkProtocol.clientMessageTypes.jsonMessage.prefix,
    json.encode(largeMessage)
  )

  -- Phase 1: Send while reading SLOWLY to trigger partial send
  local sendAttempts = 0
  local partialSendDetected = false
  local serverReceivedData = ""

  while sendAttempts < SEND_ATTEMPTS_MAX and not partialSendDetected do
    sendAttempts = sendAttempts + 1

    local success = tcpClient:sendMessage(messageString)
    if not success then
      assert(false, "couldn't keep connection open for test")
      break
    end

    -- Read slowly to create backpressure
    local chunk, _, partial = serverClientSocket:receive(SLOW_READ_SIZE)
    if chunk or partial then
      serverReceivedData = serverReceivedData .. (chunk or partial)
    end

    if tcpClient.sendRetryCount and tcpClient.sendRetryCount > 0 then
      logger.trace("✓ Partial send detected! (sendRetryCount = " .. tcpClient.sendRetryCount .. ")")
      logger.trace("  Messages still in queue: " .. tcpClient.outgoingMessageQueue:len())
      logger.trace("  Server has buffered: " .. #serverReceivedData .. " bytes so far")
      partialSendDetected = true
      break
    end

    socket.sleep(SLEEP_INTERVAL)
  end
  assert(partialSendDetected)

  -- Phase 2: Read fast to allow retry to succeed
  local retryAttempts = 0
  local resendSucceeded = false

  while retryAttempts < RETRY_MAX_ATTEMPTS do
    retryAttempts = retryAttempts + 1
    local sendRetryCountBefore = tcpClient.sendRetryCount

    tcpClient:updateNetwork(0)

    -- Read from server socket
    local chunk, error, partial = serverClientSocket:receive("*a")
    if error == "timeout" then
      chunk = partial
    end
    if chunk and #chunk > 0 then
      serverReceivedData = serverReceivedData .. chunk
    end

    if sendRetryCountBefore > 0 and tcpClient.sendRetryCount == 0 then
      resendSucceeded = true
      break
    end

    socket.sleep(SLEEP_INTERVAL)
  end
  assert(resendSucceeded)

  logger.trace("Retry phase completed. sendRetryCount = " .. (tcpClient.sendRetryCount or 0))
  logger.trace("Server buffer size: " .. #serverReceivedData .. " bytes\n")

  -- Phase 3: Read remaining data and validate messages
  local startTime = socket.gettime()
  local messageCount = 0
  local corruptedCount = 0

  while socket.gettime() - startTime < READ_TIMEOUT and corruptedCount == 0 do
    tcpClient:updateNetwork(0)
    -- Read from server socket
    local chunk, error, partial = serverClientSocket:receive("*a")

    if error == "timeout" then
      chunk = partial
    end

    if chunk and #chunk > 0 then
      serverReceivedData = serverReceivedData .. chunk
    end

    local newMessages, newCorrupted, updatedBuffer
    newMessages, newCorrupted, updatedBuffer = processMessages(
      serverReceivedData,
      NetworkProtocol.clientMessageTypes.jsonMessage.prefix
    )
    serverReceivedData = updatedBuffer or serverReceivedData
    messageCount = messageCount + newMessages
    corruptedCount = corruptedCount + newCorrupted

    if messageCount == sendAttempts or corruptedCount > 0 then
      logger.info("Ending early")
      break
    end

    socket.sleep(FAST_READ_SLEEP)
  end

  assert(messageCount > 0 and corruptedCount == 0)
  logger.info("Total messages received: " .. messageCount)
  logger.info("Corrupted messages: " .. corruptedCount)

  -- Cleanup
  tcpClient:resetNetwork()
  serverClientSocket:close()
  serverSocket:close()
end

-- Run the tests
testRealSocketPartialSend()
testTcpClientPartialSend()
