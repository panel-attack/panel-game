local MainMenu = require("client.src.scenes.MainMenu")
local Theme = require("client.src.mods.Theme")

-- Runs the test with a theme at the given path selected, putting the real theme back afterwards
local function withTheme(path, test)
  local originalTheme = config.theme
  themes.MainMenuTestTheme = setmetatable({path = path, images = themes[originalTheme].images}, {__index = Theme})
  config.theme = "MainMenuTestTheme"
  local ok, err = pcall(test)
  config.theme = originalTheme
  themes.MainMenuTestTheme = nil
  if not ok then
    error(err, 0)
  end
end

-- A theme without a main menu scene only draws its main menu image
local function testHasNoSceneWithoutAMainMenuScene()
  local mainMenu = MainMenu()

  assert(#mainMenu.sceneAnimation.drawables == 0, "There is no main menu scene to draw")
end

-- Switching in the options to a theme with a main menu scene shows it on returning to the main menu
local function testShowsTheSceneAfterSwitchingToAThemeWithOne()
  local mainMenu = MainMenu()

  themes.MainMenuTestTheme.path = Theme.defaultThemeDirectoryPath
  mainMenu:updateAnimations(0)

  assert(#mainMenu.sceneAnimation.drawables > 0, "The new theme's main menu scene should be drawn")
end

-- A theme with a main menu scene loads it to draw in place of its main menu image
local function testLoadsTheMainMenuScene()
  local mainMenu = MainMenu()

  assert(mainMenu.sceneAnimation ~= nil, "The main menu scene should be loaded")
  assert(#mainMenu.sceneAnimation.drawables > 0, "The main menu scene should have something to draw")
end

-- Returns whether drawing the main menu, after it became the active scene again, draws the theme's main menu image
local function drawsTheMainMenuImage(mainMenu)
  local theme = themes.MainMenuTestTheme
  local realImages = theme.images
  local drawn = false
  theme.images = setmetatable({bg_main = {draw = function() drawn = true end}}, {__index = realImages})
  local ok, err = pcall(function()
    mainMenu:refresh()
    mainMenu:drawSelf()
  end)
  theme.images = realImages
  if not ok then
    error(err, 0)
  end
  return drawn
end

-- The main menu scene replaces the main menu image, so the image isn't drawn under it
local function testDoesNotDrawTheImageUnderTheScene()
  assert(not drawsTheMainMenuImage(MainMenu()), "The main menu image should not be drawn under the scene")
end

local function testDrawsTheImageWithoutAScene()
  assert(drawsTheMainMenuImage(MainMenu()), "A theme without a main menu scene should draw its main menu image")
end

-- Switching in the options to a theme without a main menu scene shows its image on the first draw back in the main menu
local function testDrawsTheNewImageRightAfterSwitchingToAThemeWithoutAScene()
  local mainMenu = MainMenu()

  themes.MainMenuTestTheme.path = "client/tests/SceneAnimationTestData/FirstTheme"

  assert(drawsTheMainMenuImage(mainMenu), "The new theme's image should be drawn, not the old theme's scene")
end

withTheme("client/tests/SceneAnimationTestData/FirstTheme", testHasNoSceneWithoutAMainMenuScene)
withTheme(Theme.defaultThemeDirectoryPath, testDoesNotDrawTheImageUnderTheScene)
withTheme("client/tests/SceneAnimationTestData/FirstTheme", testDrawsTheImageWithoutAScene)
withTheme(Theme.defaultThemeDirectoryPath, testLoadsTheMainMenuScene)
withTheme("client/tests/SceneAnimationTestData/FirstTheme", testShowsTheSceneAfterSwitchingToAThemeWithOne)
withTheme(Theme.defaultThemeDirectoryPath, testDrawsTheNewImageRightAfterSwitchingToAThemeWithoutAScene)
