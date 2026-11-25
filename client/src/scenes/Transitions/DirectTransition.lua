local class = require("common.lib.class")
local Transition = require("client.src.scenes.Transitions.Transition")

local DirectTransition = class(function(transition, startTime, duration)
  transition.duration = tonumber(1e-12)
end,
Transition)

function DirectTransition:draw()
  local scene = self:getDrawnScene()
  if scene and scene.draw then
    scene:draw()
  end
end

function DirectTransition:getDrawnScene()
  return self.oldScene
end

return DirectTransition
