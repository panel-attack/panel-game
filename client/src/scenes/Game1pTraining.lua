local GameBase = require("client.src.scenes.GameBase")
local class = require("common.lib.class")

--@module endlessGame
-- Scene for an endless mode instance of the game
local Game1pTraining = class(
  function (self, sceneParams)
    self.nextScene = "CharacterSelectVsSelf"

    self:load(sceneParams)
  end,
  GameBase
)

Game1pTraining.name = "VsSelfGame"


return Game1pTraining