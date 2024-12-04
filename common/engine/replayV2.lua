local GameModes = require("common.engine.GameModes")
local ReplayPlayer = require("common.engine.ReplayPlayer")

local ReplayV2 = {}

function ReplayV2.transform(replay)
  for i, player in ipairs(replay.players) do
    if player.human then
      if player.settings.inputs then
        player.settings.inputs = ReplayPlayer.decompressInputString(player.settings.inputs)
      end

      if player.settings.level then
        player.settings.style = GameModes.Styles.MODERN
      else
        player.settings.style = GameModes.Styles.CLASSIC
      end
    end
  end
  return replay
end

return ReplayV2