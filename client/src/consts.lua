local clientConstants = {
  CANVAS_WIDTH = 1280,
  CANVAS_HEIGHT = 720,
  DEFAULT_THEME_DIR = "Panel Attack",
  RANDOM_CHARACTER_SPECIAL_VALUE = "__RandomCharacter",
  RANDOM_STAGE_SPECIAL_VALUE = "__RandomStage",
  MOUSE_POINTER_TIMEOUT = 1.5, --seconds
  KEY_NAMES = {"Up", "Down", "Left", "Right", "Swap1", "Swap2", "TauntUp", "TauntDown", "Raise1", "Raise2", "Start"},
  FRAME_RATE = 1 / 60,
  KEY_DELAY = .25,
  KEY_REPEAT_PERIOD = .05,
  MENU_PADDING = 10
}

clientConstants.PUZZLES_SAVE_DIRECTORY = "puzzles"

clientConstants.SERVER_SAVE_DIRECTORY = "servers/"
clientConstants.LEGACY_SERVER_LOCATION = "18.188.43.50"
clientConstants.SERVER_LOCATION = "panelattack.com"
clientConstants.DEFAULT_THEME_DIRECTORY = "Panel Attack Modern"

clientConstants.ATTACK_TYPE = { combo=0, chain=1, shock=2 }

local engineConstants = require("common.engine.consts")

for key, value in pairs(engineConstants) do
  if clientConstants[key] then
    error("key collision between client and engine constants for key " .. key)
  end
  clientConstants[key] = value
end

return clientConstants