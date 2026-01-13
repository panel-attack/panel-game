local InputConfigMenu = require("client.src.scenes.InputConfigMenu")

---@class SceneCoordinator
---@field joystickAdded boolean
local SceneCoordinator = {
  startupComplete = false
}

-- Called when an unconfigured joystick is added
-- Pushes InputConfigMenu if we're not in the middle of a game
function SceneCoordinator:onUnconfiguredJoystickAdded(joystick)
  -- Check if we're in a game (BattleRoom exists and has an active match)
  local inGame = false
  if GAME.battleRoom and GAME.battleRoom.match ~= nil then
    inGame = true
  end

  if self.startupComplete and not inGame then
    -- Not in a game, so push the InputConfigMenu
    GAME.navigationStack:push(InputConfigMenu({}))
  end
end

return SceneCoordinator
