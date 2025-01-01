local MockDB = {}

function MockDB:insertPlayerGameResult(privatePlayerID, gameID, level, placement) return true end

local gameCount = 0
function MockDB:insertGame(ranked)
  gameCount = gameCount + 1
  return gameCount
end

return MockDB