local DirectTransition = require("client.src.scenes.Transitions.DirectTransition")
local logger = require("common.lib.logger")
local UIElement = require("client.src.ui.UIElement")
local Layout = require("client.src.ui.Layout")
local class = require("common.lib.class")
local consts = require("common.engine.consts")
local tableUtils = require("common.lib.tableUtils")

-- The stack of scenes, an element of the game's ui tree. Its children are the ui roots it draws right now, so the scene
-- on screen is laid out and touched as part of that one tree; see attachDrawableRoots.
---@class NavigationStack : UiElement
---@field scenes Scene[]
---@field transition table?
---@field callback function?
local NavigationStack = class(
  function(self)
    self.scenes = {}
    self.transition = nil
    self.callback = nil
    self:setLayoutRule("sizing", Layout.fixedSize(consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT))
  end,
  UIElement
)

function NavigationStack:push(newScene, transition)
  local activeScene = self.scenes[#self.scenes]
  if not transition then
    transition = DirectTransition()
  end
  transition.oldScene = activeScene
  transition.newScene = newScene

  self.transition = transition

  if activeScene and activeScene.name == newScene.name then
    -- a bit of a crutch for puzzlemode:
    -- if the same scene is already on top of the stack
    -- replace the current one instead of pushing on top
    logger.debug("Replacing scene " .. newScene.name .. " on top of stack (caused by push)")
    self.scenes[#self.scenes] = newScene
  else
    logger.debug("Pushing scene " .. newScene.name .. " on top of stack")
    self.scenes[#self.scenes+1] = newScene
  end
  self:attachDrawableRoots()
end

-- transitions to the previous scene optionally using a specified transition
-- an optional callback may be passed that is called when the transition completed
function NavigationStack:pop(transition, callback)
  if #self.scenes > 1 then
    local activeScene = self.scenes[#self.scenes]
    local previousScene = self.scenes[#self.scenes - 1]

    logger.debug("Popping scene " .. activeScene.name .. ", new active scene is " .. previousScene.name)

    if not transition then
      transition = DirectTransition()
    end
    transition.oldScene = activeScene
    transition.newScene = previousScene

    self.transition = transition
    self.callback = callback
    table.remove(self.scenes)
    self:attachDrawableRoots()
  end
end

-- transitions to the bottom most scene in the stack optionally using a specified transition
-- usually this will be MainMenu
-- an optional callback may be passed that is called when the transition completed
function NavigationStack:popToTop(transition, callback)
  if #self.scenes > 1 or transition then
    local activeScene = self.scenes[#self.scenes]
    local top = self.scenes[1]

    logger.debug("Popping from scene " .. activeScene.name .. " to top scene " .. top.name)


    if not transition then
      transition = DirectTransition()
    end
    transition.oldScene = activeScene
    transition.newScene = top

    self.transition = transition
    self.callback = callback

    for i = #self.scenes, 2, -1 do
      self.scenes[i] = nil
    end
    self:attachDrawableRoots()
  end
end

-- transitions to the first scene in the stack with the given name optionally using a specified transition
-- if none is found, this pops to top instead
-- an optional callback may be passed that is called when the transition completed
function NavigationStack:popToName(name, transition, callback)
  local targetScene
  local targetIndex
  -- if we're already at the desired scene, we also just stay
  for i = #self.scenes, 1, -1 do
    if self.scenes[i].name == name then
      targetIndex = i
      targetScene = self.scenes[i]
    end
  end

  if not targetScene then
    self:popToTop(transition, callback)
  else
    local activeScene = self.scenes[#self.scenes]
    logger.debug("Popping scene " .. activeScene.name .. ", down to " .. targetScene.name)


    if not transition then
      transition = DirectTransition()
    end
    transition.oldScene = activeScene
    transition.newScene = targetScene

    self.transition = transition
    self.callback = callback

    for i = #self.scenes, targetIndex + 1, -1 do
      self.scenes[i] = nil
    end
    self:attachDrawableRoots()
  end
end

-- transitions to the newScene, optionally using a specified transition while removing the current scene from the stack
-- an optional callback may be passed that is called when the transition completed
function NavigationStack:replace(newScene, transition, callback)
  local activeScene = self.scenes[#self.scenes]

  if activeScene then
    logger.debug("Replacing scene " .. activeScene.name .. " with scene " .. newScene.name)

    if not transition then
      transition = DirectTransition()
    end
    transition.oldScene = activeScene
    transition.newScene = newScene

    self.transition = transition
    self.callback = callback
    self.scenes[#self.scenes] = newScene
    self:attachDrawableRoots()
  else
    self:push(newScene, transition)
  end
end

function NavigationStack:getActiveScene()
  if self.transition then
    return nil
  else
    return self.scenes[#self.scenes]
  end
end

-- Returns the scene drawn right now: the one the running transition draws, or else the scene on top
---@return Scene?
function NavigationStack:getDrawnScene()
  if self.transition then
    return self.transition:getDrawnScene()
  else
    return self.scenes[#self.scenes]
  end
end

---@param scene Scene?
---@param drawnScene Scene?
local function showIfDrawn(scene, drawnScene)
  if scene then
    scene.uiRoot:setVisibility(scene == drawnScene)
  end
end

-- Shows the ui tree of the scene drawn right now and hides those of the other scenes on the stack or in the transition,
-- so that UIElement:isOnScreen tells whether an element is drawn
function NavigationStack:showOnlyDrawnScene()
  local drawnScene = self:getDrawnScene()
  for _, scene in ipairs(self.scenes) do
    showIfDrawn(scene, drawnScene)
  end
  if self.transition then
    showIfDrawn(self.transition.oldScene, drawnScene)
    showIfDrawn(self.transition.newScene, drawnScene)
  end
end

-- Makes the stack's children the ui roots it can draw: the running transition's and those of its two scenes, or else the
-- root of the scene on top, and shows the one drawn right now. A scene under the top is in no tree, so it is not laid
-- out until it is shown again. Nothing under the stack is touched while a transition runs.
function NavigationStack:attachDrawableRoots()
  local roots = {}
  local transition = self.transition
  if transition then
    roots[#roots + 1] = transition.oldScene and transition.oldScene.uiRoot
    roots[#roots + 1] = transition.newScene and transition.newScene.uiRoot
    roots[#roots + 1] = transition.uiRoot
  elseif #self.scenes > 0 then
    roots[1] = self.scenes[#self.scenes].uiRoot
  end
  for i = #self.children, 1, -1 do
    if not tableUtils.indexOf(roots, self.children[i]) then
      self.children[i]:detach()
    end
  end
  for _, root in ipairs(roots) do
    self:addChild(root)
  end
  self.isEnabled = transition == nil
  self:showOnlyDrawnScene()
end

function NavigationStack:updateSelf(dt)
  if self.transition then
    self.transition:update(dt)

    if self.transition.progress >= 1 then
      -- a popped scene is in neither the stack nor a transition once this one ends
      if self.transition.oldScene then
        self.transition.oldScene.uiRoot:setVisibility(false)
      end
      self.transition = nil
      self:attachDrawableRoots()
      self.scenes[#self.scenes]:applyMusic()
      if self.callback then
        self.callback()
        self.callback = nil
      end
      self.scenes[#self.scenes]:refresh()
    else
      self:showOnlyDrawnScene()
    end
  else
    if #self.scenes == 0 then
      error("There better be an active scene. We bricked.")
    end
    self.scenes[#self.scenes]:updateAnimations(dt)
    self.scenes[#self.scenes]:update(dt)
  end
end

-- Updates nothing here: the scenes and transitions update their own ui roots, in NavigationStack:updateSelf
function NavigationStack:updateChildren(dt)
end

-- Draws nothing here: the scene or transition draws its own ui root, in NavigationStack:drawSelf
function NavigationStack:drawChildren()
end

function NavigationStack:drawSelf()
  if self.transition then
    self.transition:draw()
  else
    if #self.scenes == 0 then
      error("There better be an active scene. We bricked.")
    end
    self.scenes[#self.scenes]:draw()
  end
end

return NavigationStack