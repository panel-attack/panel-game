local class = require("common.lib.class")

-- how many seconds it takes for a request to give up waiting for a response
local REQUEST_TIMEOUT = 5

-- Responses are drained from the queue of the SAME client that sent the
-- request (passed in by Request:send). Dual-socket split means a J-message
-- response lands on lobbyClient and an H-message response lands on whichever
-- client sent the handshake — both clients need their own response routing.
local function createResponseCoroutine(client, responseTypes)
  local startTime = love.timer.getTime()
  local cr = coroutine.create(
    function ()
      local response
      local queue = client and client.receivedMessageQueue
                    or GAME.netClient.tcpClient.receivedMessageQueue

      while not response and love.timer.getTime() < startTime + REQUEST_TIMEOUT do
        coroutine.yield()
        response = queue:pop_next_with(unpack(responseTypes))
      end

      return response
    end
  )

  return cr
end

-- A simple wrapper for responses to client requests to the server
local Response = class(function(response, responseTypes, client)
  response.responseTypes = responseTypes
  response.coroutine = createResponseCoroutine(client, responseTypes)
  response.awaitingResponse = true
  response.given = false
end)

-- try to get a value from the response object
-- returns expired if the response returned its result before
-- returns timeout if no server response arrived within the timeout limit
-- returns waiting if no response has arrived yet but time is still below timeout limit
-- returns received and the response value if a response arrived
function Response:tryGetValue()
  if coroutine.status(self.coroutine) == "dead" then
    return "expired", nil
  else
    -- assuming coroutine status is normal  
    local success, returnValues = coroutine.resume(self.coroutine)
    if not success then
      GAME.crashTrace = debug.traceback(self.coroutine)
      error(returnValues)
    else
      if coroutine.status(self.coroutine) ~= "dead" then
        return "waiting", nil
      else
        self.awaitingResponse = false
        if returnValues == nil then
          -- this means we timed out
          return "timeout", nil
        else
          self.given = true
          return "received", returnValues
        end
      end
    end
  end
end

return Response