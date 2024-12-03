local GameBase = require("client.src.scenes.GameBase")
local class = require("common.lib.class")
local GameModes = require("common.engine.GameModes")

--@module endlessGame
-- Scene for an endless mode instance of the game
local EndlessGame = class(
  function (self, sceneParams)
    self.match:connectSignal("matchEnded", self, self.onMatchEnded)
  end,
  GameBase
)

EndlessGame.name = "EndlessGame"

function EndlessGame:onMatchEnded(match)
  if match.players[1].settings.style == GameModes.Styles.CLASSIC then
    GAME.scores:saveEndlessScoreForLevel(match.players[1].stack.score, match.players[1].stack.difficulty)
  end
end

return EndlessGame