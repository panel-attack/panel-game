local class = require("common.lib.class")
local UiElement = require("client.src.ui.UIElement")
local Layout = require("client.src.ui.Layout")
local consts = require("common.engine.consts")

-- A transition, or more specifically a scene transition represents an object that handles going from one scene to the next
-- For the duration of handover, the transition is responsible for handling both update and draw calls on the scenes
-- (the general rule of thumb however is that you never want to update the old scene once the transition started, only the draw)
-- Both scenes keep their animations running though, as both are drawn
---@class Transition
---@field startTime number
---@field duration number
---@field timePassed number
---@field progress number
---@field oldScene table
---@field newScene table
---@field uiRoot UiElement
local Transition = class(function(transition, startTime, duration)
  transition.startTime = startTime
  transition.timePassed = 0
  transition.duration = duration
  transition.progress = 0
  -- these are set by the navigationStack
  transition.oldScene = nil
  transition.newScene = nil
  transition.uiRoot = UiElement({layoutRules = {sizing = Layout.fixedSize(consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT)}})

end)

function Transition:update(dt)
  self.timePassed = self.timePassed + dt
  self.progress = self.timePassed / self.duration
  if self.oldScene then
    self.oldScene:updateAnimations(dt)
  end
  if self.newScene then
    self.newScene:updateAnimations(dt)
  end
  self:updateScenes(dt)
end

function Transition:updateScenes(dt)
  -- error("A transition should probably implement an updateScenes function")
end

-- Lays out the transition's ui and both scenes', once a frame between the update and the draw, as it draws them all
function Transition:layOut()
  self.uiRoot:layOut()
  if self.oldScene then
    self.oldScene:layOut()
  end
  if self.newScene then
    self.newScene:layOut()
  end
end

function Transition:draw()
  error("A transition must implement a draw function")
end

return Transition