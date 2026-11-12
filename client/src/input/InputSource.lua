local class = require("common.lib.class")
local inputManager = require("client.src.inputManager")

-- An InputSource is whoever navigates the UI: it owns one focus chain through the UI tree and supplies the presses that drive it.
-- Every local player owns one for their lifetime; InputSource.anyPlayer drives the UI no single player owns (menus, pause, lobby).
---@class InputSource
---@field player Player? the player this source belongs to; nil only for InputSource.anyPlayer
---@overload fun(player: Player?): InputSource
local InputSource = class(
---@param self InputSource
---@param player Player?
function(self, player)
  self.player = player
end)

InputSource.TYPE = "InputSource"

---The presses to read this frame: the player's claimed device, or for the any-player source the merged global input
---@return InputConfiguration|InputManager
function InputSource:getInputs()
  if self.player then
    assert(self.player.inputConfiguration, "InputSource of player " .. tostring(self.player.name) .. " has no claimed device")
    return self.player.inputConfiguration
  end
  return inputManager
end

InputSource.anyPlayer = InputSource()

return InputSource
