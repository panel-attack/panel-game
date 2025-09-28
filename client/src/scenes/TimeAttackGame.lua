local GameBase = require("client.src.scenes.GameBase")
local class = require("common.lib.class")
local GameModes = require("common.engine.GameModes")

-- Scene for an time attack mode instance of the game
local TimeAttackGame = class(
  function (self, sceneParams)
  end,
  GameBase
)

TimeAttackGame.name = "TimeAttackGame"

function TimeAttackGame:customLoad()
  self.match:connectSignal("matchEnded", self, self.onMatchEnded)
end

function TimeAttackGame:onMatchEnded(match)
  if match.players[1].settings.style == GameModes.Styles.CLASSIC then
    GAME.scores:saveTimeAttack1PScoreForLevel(match.players[1].stack.engine.score, match.players[1].stack.difficulty)
  end
end

return TimeAttackGame