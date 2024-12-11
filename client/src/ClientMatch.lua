local Match = require("common.engine.Match")
local class = require("common.lib.class")

local ClientMatch = class(
function(self, players, doCountdown, stackInteraction, winConditions, gameOverConditions, supportsPause, optionalArgs)
  self.match = Match(players, doCountdown, stackInteraction, winConditions, gameOverConditions, supportsPause, optionalArgs)
end)


function ClientMatch:run()
  self.match:run()
end

function ClientMatch:start()

end

function ClientMatch:hasLocalPlayer()

end

function ClientMatch:deinit()

end

function ClientMatch:setStage(stageId)

end

function ClientMatch:connectSignal(signalName, subscriber, callback)

end

function ClientMatch:disconnectSignal(signalName, subscriber)

end

function ClientMatch:abort()

end

function ClientMatch:getWinningPlayerCharacter()

end

function ClientMatch:togglePause()

end

function ClientMatch:setCountdown(doCountdown)

end

function ClientMatch:rewindToFrame(frame)

end

return ClientMatch