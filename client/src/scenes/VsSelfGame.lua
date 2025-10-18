local GameBase = require("client.src.scenes.GameBase")
local class = require("common.lib.class")

-- Scene for an endless mode instance of the game
local VsSelfGame = class(
  function (self, sceneParams)
  end,
  GameBase
)

VsSelfGame.name = "VsSelfGame"

function VsSelfGame:customLoad()
  self.match:connectSignal("matchEnded", self, self.onMatchEnded)
end

---@param match ClientMatch
function VsSelfGame:onMatchEnded(match)
  local P1 = match.players[1].stack
  GAME.scores:saveVsSelfScoreForLevel(P1.analytic.data.sent_garbage_lines, P1.level)
end

return VsSelfGame