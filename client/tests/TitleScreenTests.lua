local TitleScreen = require("client.src.scenes.TitleScreen")
local Theme = require("client.src.mods.Theme")

local TITLE_IMAGE = {}

-- Runs the test with a theme at the given path selected, putting the real theme back afterwards
local function withTheme(path, test)
  local originalTheme = config.theme
  themes.TitleScreenTestTheme = setmetatable({path = path, images = {bg_title = TITLE_IMAGE}}, {__index = Theme})
  config.theme = "TitleScreenTestTheme"
  local ok, err = pcall(test)
  config.theme = originalTheme
  themes.TitleScreenTestTheme = nil
  if not ok then
    error(err, 0)
  end
end

-- A theme without a title scene shows its title image
local function testDrawsTheTitleImageWithoutATitleScene()
  local titleScreen = TitleScreen()

  assert(titleScreen.sceneAnimation == nil, "There is no title scene to animate")
  assert(titleScreen.backgroundImg == TITLE_IMAGE, "The title image should be the background")
end

-- A theme with both draws its title image with the title scene on top, each is optional
local function testDrawsTheTitleImageAndTheTitleScene()
  local titleScreen = TitleScreen()

  assert(titleScreen.sceneAnimation ~= nil, "The title scene should be loaded")
  assert(titleScreen.backgroundImg == TITLE_IMAGE, "The title image should still be the background")
end

-- A theme with only a title scene has no background image to draw
local function testDrawsNoBackgroundImageWithoutATitleImage()
  themes[config.theme].images.bg_title = nil
  local titleScreen = TitleScreen()

  assert(titleScreen.sceneAnimation ~= nil, "The title scene should be loaded")
  assert(titleScreen.backgroundImg == nil, "There is no title image to draw")
end

withTheme("client/tests/SceneAnimationTestData/FirstTheme", testDrawsTheTitleImageWithoutATitleScene)
withTheme(Theme.defaultThemeDirectoryPath, testDrawsTheTitleImageAndTheTitleScene)
withTheme(Theme.defaultThemeDirectoryPath, testDrawsNoBackgroundImageWithoutATitleImage)
