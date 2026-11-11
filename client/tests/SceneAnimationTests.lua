local SceneAnimation = require("client.src.graphics.SceneAnimation")

local TEST_DATA = "client/tests/SceneAnimationTestData/"

local function assertApproxEqual(actual, expected, message)
  if math.abs(actual - expected) > 0.001 then
    error(string.format("%s: Expected %f, got %f", message, expected, actual))
  end
end

-- Runs the test with two test themes registered and the first one selected, putting the real theme and scale back afterwards
local function withTestThemes(test)
  local originalTheme = config.theme
  local originalScale = GAME.canvasXScale
  themes.SceneAnimationFirstTheme = {path = TEST_DATA .. "FirstTheme"}
  themes.SceneAnimationOtherTheme = {path = TEST_DATA .. "OtherTheme"}
  config.theme = "SceneAnimationFirstTheme"
  local ok, err = pcall(test)
  config.theme = originalTheme
  GAME.canvasXScale = originalScale
  themes.SceneAnimationFirstTheme = nil
  themes.SceneAnimationOtherTheme = nil
  if not ok then
    error(err, 0)
  end
end

local function testTracksAnimateWhenUpdated()
  local animation = SceneAnimation("scene.json")

  animation:update(0.5)

  assertApproxEqual(animation.drawables[1].alpha, 0.5, "The track should be half way")
end

local function testKeepsItsDrawablesWhileNothingChanged()
  local animation = SceneAnimation("scene.json")
  local drawables = animation.drawables

  animation:update(0.1)

  assert(animation.drawables == drawables, "The drawables should not be reloaded")
end

local function testReloadsFromTheNewThemeAfterTheThemeChanged()
  local animation = SceneAnimation("scene.json")

  config.theme = "SceneAnimationOtherTheme"
  animation:update(0)

  assertApproxEqual(animation.drawables[1].alpha, 0.25, "The drawable should come from the new theme")
end

local function testReloadsAfterTheScaleChanged()
  local animation = SceneAnimation("scene.json")
  local drawables = animation.drawables

  GAME.canvasXScale = GAME.canvasXScale + 1
  animation:update(0)

  assert(animation.drawables ~= drawables, "The drawables should be reloaded for the new scale")
end

local function testReloadedTracksStartOver()
  local animation = SceneAnimation("scene.json")
  animation:update(0.5)

  GAME.canvasXScale = GAME.canvasXScale + 1
  animation:update(0)

  assertApproxEqual(animation.drawables[1].alpha, 1, "The reloaded track should start from the beginning")
end

withTestThemes(testTracksAnimateWhenUpdated)
withTestThemes(testKeepsItsDrawablesWhileNothingChanged)
withTestThemes(testReloadsFromTheNewThemeAfterTheThemeChanged)
withTestThemes(testReloadsAfterTheScaleChanged)
withTestThemes(testReloadedTracksStartOver)
