local class = require("common.lib.class")
local ui = require("client.src.ui")
local Layout = require("client.src.ui.Layout")
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local tableUtils = require("common.lib.tableUtils")
local SoundController = require("client.src.music.SoundController")
local DebugSettings = require("client.src.debug.DebugSettings")
local Animator = require("client.src.graphics.Animator")

---@alias sceneMusic ("none" | "main" | "title_screen" | "select_screen")

-- Base class for a container representing a single screen of PanelAttack.
-- Each scene should have a field called <Scene>.name = <Scene> (for identification in errors and debugging)
-- Each scene must add its UiElements as children to its uiRoot property
---@class Scene
---@field uiRoot UiElement
---@field music sceneMusic
---@field fallbackMusic sceneMusic
---@field keepMusic boolean
---@field animator Animator runs everything the scene shows, the navigation stack updates it while the scene is the active one
---@field sceneAnimation SceneAnimation? the scene's animation file, played on the scene's animator
---@overload fun(sceneParams: table): Scene
local Scene = class(
---@param self Scene
  function (self, sceneParams)
    sceneParams = sceneParams or {}
    -- hidden until the navigation stack draws the scene, so a scene loaded before it is pushed is not on screen.
    -- It floats, as the roots the navigation stack holds during a transition lie over each other.
    self.uiRoot = ui.UiElement({
      layoutRules = {sizing = Layout.fixedSize(consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT), floating = Layout.floatAt("leftTop")},
      isVisible = false
    })
    -- scenes may specify theme music to use that is played once they are switched to
    -- eligible labels:
    -- main
    -- select_screen
    -- title_screen
    -- any other labels will be synonymous to nil/none
    self.music = "none"
    self.fallbackMusic = "none"
    -- if no music/fallbackMusic is specified,
    --  the scene can alternatively specify it wants to keep the music that is currently playing
    --  if kept at false, the music will always change at scene switch
    self.keepMusic = false
    self.animator = Animator()
  end
)

local sceneMusicLabels = { "title_screen", "main", "select_screen" }
-- tries to apply the passed music with respect to the current theme's available musics
local function applyMusic(music)
  if music and tableUtils.contains(sceneMusicLabels, music) then
    if GAME.theme.musics[music] and config.enableMenuMusic then
      SoundController:playMusic(GAME.theme.musics[music])
      return true
    end
  end
  return false
end

function Scene:applyMusic()
  if not applyMusic(self.music) then
    if not applyMusic(self.fallbackMusic) then
      if not self.keepMusic then
        SoundController:stopMusic()
      end
    end
  end
end

-- Advances the scene's animator, with its animation file playing on it, the navigation stack calls it while the scene is the active one
---@param dt number seconds since the last update
function Scene:updateAnimations(dt)
  if self.sceneAnimation then
    self.sceneAnimation:play(self.animator)
  end
  self.animator:update(dt)
end

-- abstract functions to be implemented per scene

-- Ran every frame while the scene is active
function Scene:update(dt)
  self:updateSelf(dt)
  self.uiRoot:update(dt)
end

-- Lays out the tree the scene's ui is in: the game's while the navigation stack shows the scene, else the scene's own
function Scene:layOut()
  self.uiRoot:getRoot():layOut()
end

-- Draws the scene, whose ui the layout of its tree placed first
function Scene:draw()
  assert(not self.uiRoot.layoutDirty, "a scene is drawn before its ui is laid out")
  self:drawSelf()
  self.uiRoot:draw()
end

function Scene:updateSelf(dt)
  -- Optional implementation in subclasses
end

function Scene:drawSelf()
  -- Optional implementation in subclasses
end

function Scene:refreshLocalization()
  self.uiRoot:refreshLocalization()
end

function Scene:drawCommunityMessage()
  -- Draw the community message
  if not DebugSettings.showStackDebugInfo() then
    GraphicsUtil.printf(join_community_msg or "", 0, (668 / 720) * GAME.globalCanvas:getHeight(), GAME.globalCanvas:getWidth(), "center")
  end
end

-- Returns whether the scene is drawn right now, rather than under another scene or replaced by a transition's message
---@return boolean
function Scene:isOnScreen()
  return self.uiRoot:isOnScreen()
end

-- The scene's menu sounds, played only while it is on screen
function Scene:playMoveSfx()
  self.uiRoot:playMoveSfx()
end

function Scene:playValidationSfx()
  self.uiRoot:playValidationSfx()
end

function Scene:playCancelSfx()
  self.uiRoot:playCancelSfx()
end

-- Goes back to the previous scene with the cancel sound
function Scene:pop()
  self:playCancelSfx()
  GAME.navigationStack:pop()
end

-- if a scene displays information within UI elements it will often not directly bind to the fields
-- refresh should update all UI elements with potentially updatable information with their most recent values
-- refresh is customarily called whenever a scene becomes the active scene
function Scene:refresh()

end

return Scene