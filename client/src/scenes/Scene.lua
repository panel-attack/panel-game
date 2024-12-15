local class = require("common.lib.class")
local UiElement = require("client.src.ui.UIElement")
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local tableUtils = require("common.lib.tableUtils")
local SoundController = require("client.src.music.SoundController")

-- Base class for a container representing a single screen of PanelAttack.
-- Each scene should have a field called <Scene>.name = <Scene> (for identification in errors and debugging)
-- Each scene must add its UiElements as children to its uiRoot property
local Scene = class(
  function (self, sceneParams)
    self.uiRoot = UiElement({x = 0, y = 0, width = consts.CANVAS_WIDTH, height = consts.CANVAS_HEIGHT})
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
  end
)

local sceneMusicLabels = { "title_screen", "main", "select_screen" }
-- tries to apply the passed music with respect to the current theme's available musics
local function applyMusic(music)
  if music and tableUtils.contains(sceneMusicLabels, music) then
    if GAME.theme.stageTracks[music] and config.enableMenuMusic then
      SoundController:playMusic(GAME.theme.stageTracks[music])
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

-- abstract functions to be implemented per scene

-- Ran every frame while the scene is active
function Scene:update(dt)
  error("every scene MUST implement an update function, even " .. self.name)
end

-- main draw
function Scene:draw()
  error("every scene MUST implement a draw function, even " .. self.name)
end

function Scene:refreshLocalization()
  self.uiRoot:refreshLocalization()
end

function Scene:drawCommunityMessage()
  -- Draw the community message
  if not config.debug_mode then
    GraphicsUtil.printf(join_community_msg or "", 0, (668 / 720) * GAME.globalCanvas:getHeight(), GAME.globalCanvas:getWidth(), "center")
  end
end

function Scene.pop()
  GAME.theme:playCancelSfx()
  GAME.navigationStack:pop()
end

-- if a scene displays information within UI elements it will often not directly bind to the fields
-- refresh should update all UI elements with potentially updatable information with their most recent values
-- refresh is customarily called whenever a scene becomes the active scene
function Scene:refresh()

end

return Scene