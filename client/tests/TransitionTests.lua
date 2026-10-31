local Transition = require("client.src.scenes.Transitions.Transition")
local Scene = require("client.src.scenes.Scene")

local function testBothScenesAnimateDuringTheTransition()
  local oldScene = Scene({})
  local newScene = Scene({})
  local oldTarget = {value = 0}
  local newTarget = {value = 0}
  oldScene.tweens:to(oldTarget, 1, {value = 1}):ease("linear")
  newScene.tweens:to(newTarget, 1, {value = 1}):ease("linear")
  local transition = Transition(0, 2)
  transition.oldScene = oldScene
  transition.newScene = newScene

  transition:update(0.5)

  assert(math.abs(oldTarget.value - 0.5) < 0.0001, "the old scene should keep animating while it is drawn, got " .. oldTarget.value)
  assert(math.abs(newTarget.value - 0.5) < 0.0001, "the new scene should animate while it is drawn, got " .. newTarget.value)
end

testBothScenesAnimateDuringTheTransition()
