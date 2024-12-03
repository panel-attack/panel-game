local GameBase = require("client.src.scenes.GameBase")
local class = require("common.lib.class")

--@module endlessGame
-- Scene for an endless mode instance of the game
local Game2pVs = class(
  function (self, sceneParams)
    self.nextScene = sceneParams.nextScene

    self:load(sceneParams)
  end,
  GameBase
)

Game2pVs.name = "Game2pVs"

return Game2pVs